const encoder = new TextEncoder();
const decoder = new TextDecoder();
const DEFAULT_SNAPSHOT = { version: 4, notes: [], deletedIds: [] };
const VALID_ROLE = (role) => role === 'me' || role === 'sister';
const VALID_MEDIA = new Set(['image', 'video', 'video_note', 'audio', 'file']);
const VALID_MESSAGE = new Set(['text', 'image', 'video', 'video_note', 'audio', 'file']);

function json(data, status = 200, request, env) {
  const headers = new Headers({ 'content-type': 'application/json; charset=utf-8', 'cache-control': 'no-store' });
  headers.set('access-control-allow-origin', env?.CORS_ORIGIN || '*');
  headers.set('access-control-allow-methods', 'GET,POST,PUT,PATCH,DELETE,OPTIONS');
  headers.set('access-control-allow-headers', 'authorization,content-type,x-content-sha256');
  headers.set('access-control-max-age', '86400');
  if (request?.headers.get('origin')) headers.set('vary', 'Origin');
  return new Response(status === 204 ? null : JSON.stringify(data), { status, headers });
}

function withCors(response, request, env) {
  // Preserve the platform-specific WebSocket response object during upgrades.
  if (response.webSocket) return response;
  const headers = new Headers(response.headers);
  headers.set('access-control-allow-origin', env?.CORS_ORIGIN || '*');
  headers.set('access-control-allow-methods', 'GET,POST,PUT,PATCH,DELETE,OPTIONS');
  headers.set('access-control-allow-headers', 'authorization,content-type,x-content-sha256');
  headers.set('access-control-max-age', '86400');
  if (request?.headers.get('origin')) headers.set('vary', 'Origin');
  return new Response(response.body, { status: response.status, statusText: response.statusText, headers });
}

const b64url = (bytes) => btoa(String.fromCharCode(...bytes)).replace(/=/g, '').replace(/\+/g, '-').replace(/\//g, '_');
const fromB64url = (value) => Uint8Array.from(atob(value.replace(/-/g, '+').replace(/_/g, '/') + '='.repeat((4 - value.length % 4) % 4)), c => c.charCodeAt(0));

async function jwtKey(env) {
  const secret = String(env.JWT_SECRET || '');
  if (secret.length < 32) throw new Error('JWT_SECRET must contain at least 32 characters');
  return crypto.subtle.importKey('raw', encoder.encode(secret), { name: 'HMAC', hash: 'SHA-256' }, false, ['sign', 'verify']);
}

async function signToken(device, env) {
  const now = Math.floor(Date.now() / 1000);
  const header = b64url(encoder.encode(JSON.stringify({ alg: 'HS256', typ: 'JWT' })));
  const payload = b64url(encoder.encode(JSON.stringify({
    deviceId: device.id, roomId: device.room_id, role: device.role, label: device.label,
    iss: 'big-sister-notes', iat: now, exp: now + 365 * 24 * 60 * 60,
  })));
  const signingInput = `${header}.${payload}`;
  const signature = await crypto.subtle.sign('HMAC', await jwtKey(env), encoder.encode(signingInput));
  return `${signingInput}.${b64url(new Uint8Array(signature))}`;
}

async function verifyToken(token, env) {
  const parts = String(token || '').split('.');
  if (parts.length !== 3) return null;
  try {
    const ok = await crypto.subtle.verify('HMAC', await jwtKey(env), fromB64url(parts[2]), encoder.encode(`${parts[0]}.${parts[1]}`));
    if (!ok) return null;
    const claims = JSON.parse(decoder.decode(fromB64url(parts[1])));
    if (claims.iss !== 'big-sister-notes' || !claims.exp || claims.exp <= Math.floor(Date.now() / 1000) ||
        !VALID_ROLE(claims.role) || !claims.deviceId || !claims.roomId) return null;
    return claims;
  } catch { return null; }
}

async function readBody(request) {
  try { return await request.json(); } catch { return {}; }
}

function parseJson(value, fallback) {
  if (value == null) return fallback;
  if (typeof value === 'object') return value;
  try { return JSON.parse(value); } catch { return fallback; }
}

function randomCode(length = 8) {
  const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  const bytes = crypto.getRandomValues(new Uint8Array(length));
  return Array.from(bytes, b => chars[b % chars.length]).join('');
}
function randomPin() { return String(crypto.getRandomValues(new Uint32Array(1))[0] % 900000 + 100000); }
function nowIso() { return new Date().toISOString(); }
function validUuid(value) { return /^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i.test(String(value || '')); }
function chooseNewer(localItem, remoteItem) {
  const l = Date.parse(localItem?.updatedAt || localItem?.createdAt || 0);
  const r = Date.parse(remoteItem?.updatedAt || remoteItem?.createdAt || 0);
  if (r > l) return remoteItem;
  if (r < l) return localItem;
  return remoteItem;
}
function mergeSnapshots(current, incoming) {
  const currentNotes = Array.isArray(current?.notes) ? current.notes : [];
  const incomingNotes = Array.isArray(incoming?.notes) ? incoming.notes : [];
  const deletedIds = new Set([
    ...(Array.isArray(current?.deletedIds) ? current.deletedIds : []),
    ...(Array.isArray(incoming?.deletedIds) ? incoming.deletedIds : []),
  ]);
  for (const n of incomingNotes.filter(n => n?.id && !n?.deletedAt)) deletedIds.delete(n.id);
  const map = new Map();
  for (const n of currentNotes) if (n?.id && !deletedIds.has(n.id)) map.set(n.id, n);
  for (const n of incomingNotes) {
    if (!n?.id || deletedIds.has(n.id)) continue;
    map.set(n.id, chooseNewer(map.get(n.id), n));
  }
  return {
    version: 4,
    notes: Array.from(map.values()).sort((a, b) => Date.parse(b?.updatedAt || b?.createdAt || 0) - Date.parse(a?.updatedAt || a?.createdAt || 0)),
    deletedIds: Array.from(deletedIds),
  };
}

async function ensureSharedRoom(env) {
  const roomKey = String(env.SHARED_ROOM_KEY || 'big-sister-private-room');
  let room = await env.DB.prepare('SELECT id, code, pair_pin FROM rooms WHERE room_key = ? LIMIT 1').bind(roomKey).first();
  if (room) return room;
  room = await env.DB.prepare('SELECT id, code, pair_pin FROM rooms ORDER BY created_at LIMIT 1').first();
  if (room) {
    await env.DB.prepare('UPDATE rooms SET room_key = ?, updated_at = ? WHERE id = ?').bind(roomKey, nowIso(), room.id).run();
    return room;
  }
  const row = { id: crypto.randomUUID(), code: randomCode(), pair_pin: randomPin() };
  const now = nowIso();
  try {
    await env.DB.prepare('INSERT INTO rooms(id,code,room_key,pair_pin,created_at,updated_at,revision) VALUES(?,?,?,?,?,?,0)')
      .bind(row.id, row.code, roomKey, row.pair_pin, now, now).run();
    return row;
  } catch (error) {
    // Two first-time logins can arrive together; re-read the room created by
    // the winning request instead of failing one of the two family devices.
    const concurrentlyCreated = await env.DB.prepare('SELECT id, code, pair_pin FROM rooms WHERE room_key = ? LIMIT 1').bind(roomKey).first();
    if (concurrentlyCreated) return concurrentlyCreated;
    throw error;
  }
}

async function ensureDevice(env, roomId, role) {
  let device = await env.DB.prepare('SELECT id, room_id, role, label FROM devices WHERE room_id = ? AND role = ? LIMIT 1').bind(roomId, role).first();
  const label = String(role === 'me' ? env.LITTLE_BROTHER_LABEL || 'داداش کوچیکه' : env.BIG_SISTER_LABEL || 'آبجی بزرگ').slice(0, 32);
  const now = nowIso();
  if (!device) {
    device = { id: crypto.randomUUID(), room_id: roomId, role, label };
    await env.DB.prepare('INSERT INTO devices(id,room_id,role,label,created_at,last_seen_at) VALUES(?,?,?,?,?,?)')
      .bind(device.id, roomId, role, label, now, now).run();
  } else if (device.label !== label) {
    await env.DB.prepare('UPDATE devices SET label = ?, last_seen_at = ? WHERE id = ?').bind(label, now, device.id).run();
    device.label = label;
  } else {
    await env.DB.prepare('UPDATE devices SET last_seen_at = ? WHERE id = ?').bind(now, device.id).run();
  }
  return device;
}

async function auth(request, env) {
  const header = request.headers.get('authorization') || '';
  const token = header.startsWith('Bearer ') ? header.slice(7) : '';
  const claims = await verifyToken(token, env);
  if (!claims) return { error: json({ error: 'unauthorized' }, 401, request, env) };
  const device = await env.DB.prepare('SELECT id, room_id, role, label FROM devices WHERE id = ? AND room_id = ? AND role = ?')
    .bind(claims.deviceId, claims.roomId, claims.role).first();
  if (!device) return { error: json({ error: 'invalid_token_role' }, 401, request, env) };
  await env.DB.prepare('UPDATE devices SET last_seen_at = ? WHERE id = ?').bind(nowIso(), device.id).run();
  return { user: { ...claims, label: device.label } };
}

async function broadcast(env, roomId, event, data, excludeDeviceId = null) {
  if (!env.REALTIME || !roomId) return;
  try {
    const stub = env.REALTIME.get(env.REALTIME.idFromName(String(roomId)));
    await stub.fetch('https://realtime.internal/broadcast', {
      method: 'POST', headers: { 'content-type': 'application/json' },
      body: JSON.stringify({ event, data, excludeDeviceId }),
    });
  } catch (error) { console.error('realtime_broadcast_failed', String(error?.message || error)); }
}

function messageRow(row) {
  if (!row) return row;
  return { ...row, reactions: parseJson(row.reactions, {}), is_pinned: Boolean(row.is_pinned) };
}
async function getRoomMedia(env, mediaId, roomId) {
  return env.DB.prepare('SELECT * FROM media WHERE id = ? AND room_id = ?').bind(mediaId, roomId).first();
}

async function sha256Hex(bytes) {
  const digest = await crypto.subtle.digest('SHA-256', bytes);
  return Array.from(new Uint8Array(digest), b => b.toString(16).padStart(2, '0')).join('');
}
async function uploadMedia(request, env, user, isSync) {
  let form;
  try { form = await request.formData(); } catch { return json({ error: 'file_required' }, 400, request, env); }
  const file = form.get('file');
  if (!file || typeof file.arrayBuffer !== 'function') return json({ error: 'file_required' }, 400, request, env);
  const maxBytes = Math.max(1, Number(env.MAX_UPLOAD_MB || 25)) * 1024 * 1024;
  if (file.size > maxBytes) return json({ error: 'file_too_large', maxUploadMb: Number(env.MAX_UPLOAD_MB || 25) }, 413, request, env);
  const kindRaw = String(form.get('kind') || 'file');
  const kind = VALID_MEDIA.has(kindRaw) ? kindRaw : 'file';
  const bytes = await file.arrayBuffer();
  const suppliedHash = String(form.get('sha256') || request.headers.get('x-content-sha256') || '').trim().toLowerCase();
  if (isSync && suppliedHash && !/^[a-f0-9]{64}$/.test(suppliedHash)) return json({ error: 'invalid_sha256' }, 400, request, env);
  // Avoid spending the Workers Free CPU budget hashing every large chat attachment.
  // Note uploads normally supply the SHA-256 from Flutter; a small unsupplied item
  // may be hashed as a convenience, while large unsupplied files are stored uniquely.
  const contentHash = suppliedHash || (bytes.byteLength <= 2 * 1024 * 1024 ? await sha256Hex(bytes) : null);
  const duplicate = contentHash
    ? await env.DB.prepare('SELECT id,kind,original_name,mime,bytes FROM media WHERE room_id = ? AND content_hash = ? LIMIT 1').bind(user.roomId, contentHash).first()
    : null;
  if (duplicate) {
    return json({ id: duplicate.id, kind: duplicate.kind, originalName: duplicate.original_name, mime: duplicate.mime,
      bytes: Number(duplicate.bytes), reused: true, url: `/api/media/${duplicate.id}` }, 200, request, env);
  }
  const id = crypto.randomUUID();
  const originalName = String(file.name || 'file').replace(/[\r\n\0]/g, '_').slice(0, 255);
  const mime = String(file.type || 'application/octet-stream').slice(0, 255);
  const diskName = `${user.roomId}/${id}`;
  try {
    // Use D1 itself for media so the default deployment does not require an R2
    // subscription/payment method. Files are chunked below SQLite row-size limits.
    await env.DB.prepare('INSERT INTO media(id,room_id,uploader_id,kind,original_name,mime,bytes,disk_name,content_hash,created_at) VALUES(?,?,?,?,?,?,?,?,?,?)')
      .bind(id, user.roomId, user.deviceId, kind, originalName, mime, file.size, diskName, contentHash, nowIso()).run();
    const chunkSize = 200 * 1024;
    const chunkStatements = [];
    for (let offset = 0, index = 0; offset < bytes.byteLength; offset += chunkSize, index += 1) {
      const length = Math.min(chunkSize, bytes.byteLength - offset);
      const chunk = new Uint8Array(bytes, offset, length);
      chunkStatements.push(env.DB.prepare('INSERT INTO media_chunks(media_id,chunk_index,data) VALUES(?,?,?)').bind(id, index, chunk));
    }
    // Small batches avoid large D1 payloads when an attachment approaches 25 MB.
    for (let i = 0; i < chunkStatements.length; i += 10) await env.DB.batch(chunkStatements.slice(i, i + 10));
  } catch (error) {
    await env.DB.prepare('DELETE FROM media_chunks WHERE media_id = ?').bind(id).run().catch(() => {});
    await env.DB.prepare('DELETE FROM media WHERE id = ? AND room_id = ?').bind(id, user.roomId).run().catch(() => {});
    console.error('media_upload_failed', String(error?.message || error));
    return json({ error: 'media_upload_failed' }, 500, request, env);
  }
  return json({ id, kind, originalName, mime, bytes: file.size, reused: false, url: `/api/media/${id}` }, 201, request, env);
}

async function createMessage(env, user, body) {
  const id = validUuid(body?.id) ? String(body.id) : crypto.randomUUID();
  const type = VALID_MESSAGE.has(String(body?.type)) ? String(body.type) : 'text';
  const text = String(body?.body || '').slice(0, 20000);
  const attachmentId = body?.attachmentId ? String(body.attachmentId) : null;
  const attachmentName = body?.attachmentName ? String(body.attachmentName).slice(0, 255) : null;
  const replyTo = body?.replyTo ? String(body.replyTo) : null;
  if (attachmentId) {
    const item = await env.DB.prepare('SELECT id FROM media WHERE id = ? AND room_id = ?').bind(attachmentId, user.roomId).first();
    if (!item) throw new Error('attachment_not_found');
  }
  if (replyTo) {
    const item = await env.DB.prepare('SELECT id FROM messages WHERE id = ? AND room_id = ?').bind(replyTo, user.roomId).first();
    if (!item) throw new Error('reply_target_not_found');
  }
  const createdAt = nowIso();
  await env.DB.prepare(`INSERT OR IGNORE INTO messages(id,room_id,sender_id,type,body,attachment_id,attachment_name,reply_to,reaction,reactions,is_pinned,created_at,delivered_at)
    VALUES(?,?,?,?,?,?,?,?,NULL,'{}',0,?,?)`).bind(id, user.roomId, user.deviceId, type, text, attachmentId, attachmentName, replyTo, createdAt, createdAt).run();
  const row = await env.DB.prepare(`SELECT id, sender_id, type, body, attachment_id, attachment_name, reply_to, reaction, reactions, is_pinned, edited_at, created_at, delivered_at, read_at
    FROM messages WHERE id = ? AND room_id = ?`).bind(id, user.roomId).first();
  return messageRow(row);
}

async function handleApi(request, env) {
  const url = new URL(request.url);
  const method = request.method.toUpperCase();
  const path = url.pathname;
  if (method === 'OPTIONS') return json({}, 204, request, env);
  if (method === 'GET' && path === '/') return json({ service: 'big-sister-sync-cloudflare', provider: 'cloudflare-workers', health: '/api/health' }, 200, request, env);
  if (method === 'GET' && path === '/api/health') {
    try {
      await env.DB.prepare('SELECT 1 AS ok').first();
      return json({ ok: true, service: 'big-sister-sync', provider: 'cloudflare-workers', storage: ['D1', 'D1-BLOB-CHUNKS'], realtime: 'Durable Objects WebSocket', time: nowIso() }, 200, request, env);
    } catch (error) {
      console.error('health_failed', String(error?.message || error));
      return json({ ok: false, service: 'big-sister-sync', provider: 'cloudflare-workers', error: 'database_unavailable' }, 503, request, env);
    }
  }

  if (method === 'POST' && path === '/api/auth/login') {
    const body = await readBody(request);
    const password = String(body.password || '');
    const requestedRole = body.role == null ? null : String(body.role);
    if ((requestedRole !== null && !VALID_ROLE(requestedRole)) || password.length < 4) return json({ error: 'invalid_login' }, 400, request, env);
    const brotherPass = String(env.LITTLE_BROTHER_PASSWORD || '');
    const sisterPass = String(env.BIG_SISTER_PASSWORD || '');
    if (brotherPass.length < 4 || sisterPass.length < 4 || !env.JWT_SECRET || String(env.JWT_SECRET).length < 32) return json({ error: 'server_credentials_missing' }, 500, request, env);
    let role = requestedRole;
    if (!role) {
      const sisterMatch = password === sisterPass;
      const brotherMatch = password === brotherPass;
      if (sisterMatch === brotherMatch) return json({ error: sisterMatch ? 'duplicate_passwords' : 'invalid_login' }, 401, request, env);
      role = sisterMatch ? 'sister' : 'me';
    }
    const expected = role === 'me' ? brotherPass : sisterPass;
    if (password !== expected) return json({ error: 'invalid_login' }, 401, request, env);
    try {
      const room = await ensureSharedRoom(env);
      const device = await ensureDevice(env, room.id, role);
      return json({ token: await signToken(device, env), roomId: room.id, deviceId: device.id, role: device.role, label: device.label }, 200, request, env);
    } catch (error) {
      console.error('login_failed', String(error?.message || error));
      return json({ error: 'login_failed' }, 500, request, env);
    }
  }

  // WebSocket upgrade is handled by the Durable Object; do not expose internal broadcasts.
  if (path === '/api/realtime') {
    if (method !== 'GET' || request.headers.get('upgrade')?.toLowerCase() !== 'websocket') return json({ error: 'websocket_upgrade_required' }, 426, request, env);
    const userResult = await auth(request, env);
    if (userResult.error) return userResult.error;
    const user = userResult.user;
    const urlForObject = new URL(request.url); urlForObject.pathname = '/connect';
    const headers = new Headers(request.headers);
    headers.set('x-room-id', user.roomId); headers.set('x-device-id', user.deviceId);
    headers.set('x-role', user.role); headers.set('x-label', user.label || '');
    const stub = env.REALTIME.get(env.REALTIME.idFromName(String(user.roomId)));
    // Preserve Upgrade and Authorization headers while forwarding to the DO.
    // WebSocket upgrades are GET requests and do not carry a request body.
    const realtimeRequest = new Request(urlForObject.toString(), {
      method: request.method,
      headers,
      redirect: request.redirect,
    });
    return stub.fetch(realtimeRequest);
  }

  const isPublicPairingRoute = path === '/api/pair/create' || path === '/api/pair/join';
  const authResult = path.startsWith('/api/') && !isPublicPairingRoute ? await auth(request, env) : null;
  if (authResult?.error) return authResult.error;
  const user = authResult?.user;

  if (method === 'POST' && path === '/api/pair/create') {
    const body = await readBody(request); const role = String(body.role || '');
    if (!VALID_ROLE(role)) return json({ error: 'invalid_role' }, 400, request, env);
    const code = randomCode(8), pairPin = randomPin(), roomId = crypto.randomUUID(), deviceId = crypto.randomUUID(), now = nowIso();
    const label = String(role === 'me' ? env.LITTLE_BROTHER_LABEL || 'داداش کوچیکه' : env.BIG_SISTER_LABEL || 'آبجی بزرگ').slice(0,32);
    await env.DB.batch([
      env.DB.prepare('INSERT INTO rooms(id,code,pair_pin,created_at,updated_at,revision) VALUES(?,?,?,?,?,0)').bind(roomId, code, pairPin, now, now),
      env.DB.prepare('INSERT INTO devices(id,room_id,role,label,created_at,last_seen_at) VALUES(?,?,?,?,?,?)').bind(deviceId, roomId, role, label, now, now),
      env.DB.prepare('INSERT INTO room_snapshots(room_id,payload,updated_at,revision,updated_by) VALUES(?,?,?,?,?)').bind(roomId, JSON.stringify(DEFAULT_SNAPSHOT), now, 0, deviceId),
    ]);
    const device = { id: deviceId, room_id: roomId, role, label };
    return json({ token: await signToken(device, env), roomId, deviceId, role, label, code, pairPin }, 200, request, env);
  }

  if (method === 'POST' && path === '/api/pair/join') {
    const body = await readBody(request); const code = String(body.code || '').trim().toUpperCase();
    const pin = String(body.pairPin || '').trim(); const role = String(body.role || '');
    if (!code || !/^\d{6}$/.test(pin) || !VALID_ROLE(role)) return json({ error: 'invalid_pairing' }, 400, request, env);
    const room = await env.DB.prepare('SELECT * FROM rooms WHERE code = ?').bind(code).first();
    if (!room) return json({ error: 'room_not_found' }, 404, request, env);
    if (Date.now() - Date.parse(room.created_at) > Number(env.ROOM_CODE_TTL_HOURS || 24) * 3600000) return json({ error: 'pairing_expired' }, 410, request, env);
    if (pin !== room.pair_pin) return json({ error: 'wrong_pair_pin' }, 403, request, env);
    const members = await env.DB.prepare('SELECT id,role,label FROM devices WHERE room_id = ?').bind(room.id).all();
    if ((members.results || []).length >= 2) return json({ error: 'room_full' }, 409, request, env);
    if ((members.results || []).some(d => d.role === role)) return json({ error: 'role_taken' }, 409, request, env);
    const device = await ensureDevice(env, room.id, role);
    await broadcast(env, room.id, 'pair:completed', { label: device.label });
    return json({ token: await signToken(device, env), roomId: room.id, deviceId: device.id, role, label: device.label, code, pairPin: pin }, 200, request, env);
  }

  if (method === 'GET' && path === '/api/pair/status') {
    const { results = [] } = await env.DB.prepare('SELECT id,role,label,last_seen_at FROM devices WHERE room_id = ? ORDER BY created_at').bind(user.roomId).all();
    return json({ roomId: user.roomId, members: results }, 200, request, env);
  }

  if (method === 'GET' && path === '/api/sync/snapshot') {
    const row = await env.DB.prepare('SELECT payload,revision,updated_at FROM room_snapshots WHERE room_id = ?').bind(user.roomId).first();
    const payload = parseJson(row?.payload, DEFAULT_SNAPSHOT);
    // Revision 0 is only the initial placeholder. Protect local notes if a room
    // has been created but no real snapshot has been synced yet.
    const hasSnapshot = Boolean(row && (Number(row.revision || 0) > 0 || payload.notes?.length || payload.deletedIds?.length));
    return json({ hasSnapshot, revision: Number(row?.revision || 0), updatedAt: row?.updated_at || null, payload }, 200, request, env);
  }
  if (method === 'PUT' && path === '/api/sync/snapshot') {
    const body = await readBody(request); const incoming = body?.payload;
    if (!incoming || typeof incoming !== 'object' || !Array.isArray(incoming.notes)) return json({ error: 'invalid_snapshot' }, 400, request, env);
    // Serialize merge/write through the room Durable Object so simultaneous syncs
    // from the two phones cannot overwrite each other with stale snapshots.
    const stub = env.REALTIME.get(env.REALTIME.idFromName(String(user.roomId)));
    const mergedResponse = await stub.fetch('https://realtime.internal/snapshot/merge', {
      method: 'POST', headers: { 'content-type': 'application/json' },
      body: JSON.stringify({ roomId: user.roomId, deviceId: user.deviceId, payload: incoming }),
    });
    if (!mergedResponse.ok) return json({ error: 'sync_failed' }, 500, request, env);
    const mergedResult = await mergedResponse.json();
    await broadcast(env, user.roomId, 'content:changed', { revision: mergedResult.revision, updatedBy: user.deviceId }, user.deviceId);
    return json(mergedResult, 200, request, env);
  }

  if (method === 'GET' && path === '/api/chat/messages') {
    const limit = Math.min(Math.max(Number(url.searchParams.get('limit') || 50), 1), 100);
    const before = url.searchParams.get('before');
    const query = before
      ? env.DB.prepare(`SELECT id,sender_id,type,body,attachment_id,attachment_name,reply_to,reaction,reactions,is_pinned,edited_at,created_at,delivered_at,read_at FROM messages WHERE room_id = ? AND created_at < ? ORDER BY created_at DESC LIMIT ?`).bind(user.roomId, before, limit)
      : env.DB.prepare(`SELECT id,sender_id,type,body,attachment_id,attachment_name,reply_to,reaction,reactions,is_pinned,edited_at,created_at,delivered_at,read_at FROM messages WHERE room_id = ? ORDER BY created_at DESC LIMIT ?`).bind(user.roomId, limit);
    const { results = [] } = await query.all();
    return json({ messages: results.reverse().map(messageRow) }, 200, request, env);
  }
  if (method === 'GET' && path === '/api/chat/search') {
    const q = String(url.searchParams.get('q') || '').trim().slice(0, 160);
    if (!q) return json({ messages: [] }, 200, request, env);
    const limit = Math.min(Math.max(Number(url.searchParams.get('limit') || 80), 1), 100);
    const { results = [] } = await env.DB.prepare(`SELECT id,sender_id,type,body,attachment_id,attachment_name,reply_to,reaction,reactions,is_pinned,edited_at,created_at,delivered_at,read_at
      FROM messages WHERE room_id = ? AND (body LIKE ? OR COALESCE(attachment_name,'') LIKE ?) ORDER BY created_at DESC LIMIT ?`)
      .bind(user.roomId, `%${q}%`, `%${q}%`, limit).all();
    return json({ messages: results.reverse().map(messageRow) }, 200, request, env);
  }

  if (method === 'POST' && (path === '/api/media' || path === '/api/sync/media')) return uploadMedia(request, env, user, path === '/api/sync/media');
  const mediaMatch = path.match(/^\/api\/media\/([^/]+)$/);
  if (mediaMatch && method === 'GET') {
    const row = await getRoomMedia(env, mediaMatch[1], user.roomId);
    if (!row) return new Response(null, { status: 404, headers: { 'access-control-allow-origin': env.CORS_ORIGIN || '*' } });
    const headers = new Headers();
    headers.set('content-type', row.mime || 'application/octet-stream');
    headers.set('content-length', String(row.bytes));
    headers.set('content-disposition', `inline; filename*=UTF-8''${encodeURIComponent(row.original_name || 'file')}`);
    headers.set('cache-control', 'private, max-age=86400');
    headers.set('access-control-allow-origin', env.CORS_ORIGIN || '*');
    headers.set('access-control-allow-headers', 'authorization,content-type');
    const totalChunks = Math.ceil(Number(row.bytes) / (200 * 1024));
    const stream = new ReadableStream({
      async start(controller) {
        try {
          // Fetch small groups instead of one D1 query per chunk. This stays
          // under the Workers Free per-invocation query cap for a 25 MB file.
          const chunksPerQuery = 8;
          for (let start = 0; start < totalChunks; start += chunksPerQuery) {
            const end = Math.min(totalChunks, start + chunksPerQuery);
            const { results = [] } = await env.DB.prepare(`SELECT chunk_index,data FROM media_chunks
              WHERE media_id = ? AND chunk_index >= ? AND chunk_index < ? ORDER BY chunk_index`)
              .bind(row.id, start, end).all();
            const byIndex = new Map(results.map(item => [Number(item.chunk_index), item.data]));
            for (let index = start; index < end; index += 1) {
              const data = byIndex.get(index);
              if (!data) throw new Error('media_chunk_missing');
              const chunk = data instanceof ArrayBuffer ? new Uint8Array(data) : new Uint8Array(data);
              controller.enqueue(chunk);
            }
          }
          controller.close();
        } catch (error) {
          console.error('media_download_failed', String(error?.message || error));
          controller.error(error);
        }
      },
    });
    return new Response(stream, { headers });
  }

  if (method === 'POST' && path === '/api/chat/messages') {
    try {
      const message = await createMessage(env, user, await readBody(request));
      await broadcast(env, user.roomId, 'chat:message', message);
      return json({ message }, 201, request, env);
    } catch (error) {
      if (['attachment_not_found', 'reply_target_not_found'].includes(error?.message)) return json({ error: error.message }, 400, request, env);
      console.error('message_create_failed', String(error?.message || error));
      return json({ error: 'message_create_failed' }, 500, request, env);
    }
  }

  const chatMatch = path.match(/^\/api\/chat\/messages\/([^/]+)(?:\/(read|reaction|edit|pin))?$/);
  if (chatMatch) {
    const id = chatMatch[1], action = chatMatch[2];
    if (method === 'PATCH' && action === 'read') {
      const readAt = nowIso();
      const update = await env.DB.prepare('UPDATE messages SET delivered_at = COALESCE(delivered_at, ?), read_at = ? WHERE id = ? AND room_id = ?').bind(readAt, readAt, id, user.roomId).run();
      if (!update.meta?.changes) return json({ error: 'message_not_found' }, 404, request, env);
      await broadcast(env, user.roomId, 'chat:read', { id, readAt }, user.deviceId);
      return json({ id, read_at: readAt }, 200, request, env);
    }
    if (method === 'PATCH' && action === 'reaction') {
      const body = await readBody(request); const reaction = String(body.reaction || '').trim().slice(0, 16);
      const row = await env.DB.prepare('SELECT reactions FROM messages WHERE id = ? AND room_id = ?').bind(id, user.roomId).first();
      if (!row) return json({ error: 'message_not_found' }, 404, request, env);
      const reactions = parseJson(row.reactions, {});
      if (reaction) reactions[user.deviceId] = reaction; else delete reactions[user.deviceId];
      const latest = Object.values(reactions).at(-1) || null;
      await env.DB.prepare('UPDATE messages SET reactions = ?, reaction = ? WHERE id = ? AND room_id = ?').bind(JSON.stringify(reactions), latest, id, user.roomId).run();
      const result = { id, reaction: latest, reactions };
      await broadcast(env, user.roomId, 'chat:reaction', { ...result, fromDeviceId: user.deviceId }, user.deviceId);
      return json(result, 200, request, env);
    }
    if (method === 'PATCH' && action === 'edit') {
      const body = await readBody(request); const text = String(body.body ?? '').trim().slice(0, 20000);
      if (!text) return json({ error: 'message_body_required' }, 400, request, env);
      const editedAt = nowIso();
      const row = await env.DB.prepare(`UPDATE messages SET body = ?, edited_at = ? WHERE id = ? AND room_id = ? AND sender_id = ?
        AND julianday(created_at) >= julianday('now','-15 minutes') RETURNING id,sender_id,type,body,attachment_id,attachment_name,reply_to,reaction,reactions,is_pinned,edited_at,created_at,delivered_at,read_at`)
        .bind(text, editedAt, id, user.roomId, user.deviceId).first();
      if (!row) return json({ error: 'message_not_editable' }, 409, request, env);
      const message = messageRow(row); await broadcast(env, user.roomId, 'chat:edited', message, user.deviceId);
      return json({ message }, 200, request, env);
    }
    if (method === 'PATCH' && action === 'pin') {
      const body = await readBody(request); const pinned = body.pinned === true ? 1 : 0;
      const row = await env.DB.prepare('UPDATE messages SET is_pinned = ? WHERE id = ? AND room_id = ? RETURNING id,sender_id,type,body,attachment_id,attachment_name,reply_to,reaction,reactions,is_pinned,edited_at,created_at,delivered_at,read_at')
        .bind(pinned, id, user.roomId).first();
      if (!row) return json({ error: 'message_not_found' }, 404, request, env);
      const message = messageRow(row); await broadcast(env, user.roomId, 'chat:pinned', message, user.deviceId);
      return json({ message }, 200, request, env);
    }
    if (method === 'DELETE' && !action) {
      const row = await env.DB.prepare('SELECT attachment_id FROM messages WHERE id = ? AND room_id = ?').bind(id, user.roomId).first();
      if (!row) return json({ error: 'message_not_found' }, 404, request, env);
      if (row.attachment_id) {
        // Media bytes live in D1 chunks in this zero-billing setup (not an R2 binding).
        await env.DB.batch([
          env.DB.prepare('DELETE FROM messages WHERE id = ? AND room_id = ?').bind(id, user.roomId),
          env.DB.prepare('DELETE FROM media_chunks WHERE media_id = ?').bind(row.attachment_id),
          env.DB.prepare('DELETE FROM media WHERE id = ? AND room_id = ?').bind(row.attachment_id, user.roomId),
        ]);
      } else await env.DB.prepare('DELETE FROM messages WHERE id = ? AND room_id = ?').bind(id, user.roomId).run();
      await broadcast(env, user.roomId, 'chat:deleted', { id }, user.deviceId);
      return json({ ok: true, id }, 200, request, env);
    }
  }

  if (method === 'GET' && path === '/api/calls/history') {
    // Finalize calls left in the ringing state if the caller disappeared.
    await env.DB.prepare(`UPDATE call_history SET status='missed', ended_at=COALESCE(ended_at, ?), updated_at=?
      WHERE room_id=? AND status='ringing' AND julianday(created_at) < julianday('now','-45 seconds')`)
      .bind(nowIso(), nowIso(), user.roomId).run();
    const limit = Math.min(Math.max(Number(url.searchParams.get('limit') || 40), 1), 100);
    const { results = [] } = await env.DB.prepare(`SELECT c.call_id,c.caller_device_id,c.callee_device_id,c.call_type,c.status,c.created_at,c.answered_at,c.ended_at,c.duration_seconds,
       caller.role AS caller_role,callee.role AS callee_role FROM call_history c LEFT JOIN devices caller ON caller.id=c.caller_device_id
       LEFT JOIN devices callee ON callee.id=c.callee_device_id WHERE c.room_id = ? ORDER BY c.created_at DESC LIMIT ?`).bind(user.roomId, limit).all();
    return json({ calls: results }, 200, request, env);
  }

  if (method === 'GET' && path === '/api/letters') {
    const limit = Math.min(Math.max(Number(url.searchParams.get('limit') || 100), 1), 200);
    const { results = [] } = await env.DB.prepare('SELECT id,sender_id,title,body,created_at,read_at FROM letters WHERE room_id = ? ORDER BY created_at ASC LIMIT ?').bind(user.roomId, limit).all();
    return json({ letters: results }, 200, request, env);
  }
  if (method === 'POST' && path === '/api/letters') {
    const body = await readBody(request); const title = String(body.title || '').trim().slice(0, 255) || 'نامه';
    const text = String(body.body || '').trim().slice(0, 50000);
    if (!text) return json({ error: 'letter_body_required' }, 400, request, env);
    const letter = { id: crypto.randomUUID(), sender_id: user.deviceId, title, body: text, created_at: nowIso(), read_at: null };
    await env.DB.prepare('INSERT INTO letters(id,room_id,sender_id,title,body,created_at) VALUES(?,?,?,?,?,?)').bind(letter.id, user.roomId, letter.sender_id, title, text, letter.created_at).run();
    await broadcast(env, user.roomId, 'letter:new', letter);
    return json({ letter }, 201, request, env);
  }
  const letterRead = path.match(/^\/api\/letters\/([^/]+)\/read$/);
  if (method === 'PATCH' && letterRead) {
    const id = letterRead[1]; const readAt = nowIso();
    const row = await env.DB.prepare('UPDATE letters SET read_at = COALESCE(read_at, ?) WHERE id = ? AND room_id = ? RETURNING id,read_at').bind(readAt, id, user.roomId).first();
    if (!row) return json({ error: 'letter_not_found' }, 404, request, env);
    await broadcast(env, user.roomId, 'letter:read', row, user.deviceId);
    return json(row, 200, request, env);
  }

  return json({ error: 'not_found' }, 404, request, env);
}

export class RealtimeRoom {
  constructor(state, env) { this.state = state; this.env = env; this.snapshotQueue = Promise.resolve(); }

  sockets() { return this.state.getWebSockets(); }
  attachment(ws) { try { return ws.deserializeAttachment() || {}; } catch { return {}; } }
  send(ws, event, data) { try { ws.send(JSON.stringify({ event, data })); } catch {} }
  broadcast(event, data, excludeDeviceId = null) {
    for (const ws of this.sockets()) {
      const identity = this.attachment(ws);
      if (excludeDeviceId && identity.deviceId === excludeDeviceId) continue;
      this.send(ws, event, data);
    }
  }

  async fetch(request) {
    const url = new URL(request.url);
    if (url.pathname === '/snapshot/merge' && request.method === 'POST') {
      const body = await readBody(request);
      const roomId = String(body.roomId || '');
      const deviceId = String(body.deviceId || '');
      const incoming = body.payload;
      if (!roomId || !deviceId || !incoming || !Array.isArray(incoming.notes)) return new Response(JSON.stringify({ error: 'invalid_snapshot' }), { status: 400, headers: { 'content-type': 'application/json' } });
      const operation = this.snapshotQueue.then(async () => {
        const existing = await this.env.DB.prepare('SELECT payload,revision FROM room_snapshots WHERE room_id = ?').bind(roomId).first();
        const merged = mergeSnapshots(parseJson(existing?.payload, DEFAULT_SNAPSHOT), incoming);
        const revision = Number(existing?.revision || 0) + 1;
        const now = nowIso();
        await this.env.DB.batch([
          this.env.DB.prepare(`INSERT INTO room_snapshots(room_id,payload,updated_at,revision,updated_by) VALUES(?,?,?,?,?)
            ON CONFLICT(room_id) DO UPDATE SET payload=excluded.payload,updated_at=excluded.updated_at,revision=excluded.revision,updated_by=excluded.updated_by`)
            .bind(roomId, JSON.stringify(merged), now, revision, deviceId),
          this.env.DB.prepare('UPDATE rooms SET revision = ?, updated_at = ? WHERE id = ?').bind(revision, now, roomId),
        ]);
        return { revision, payload: merged };
      });
      this.snapshotQueue = operation.then(() => undefined, () => undefined);
      try {
        return new Response(JSON.stringify(await operation), { headers: { 'content-type': 'application/json; charset=utf-8' } });
      } catch (error) {
        console.error('snapshot_merge_failed', String(error?.message || error));
        return new Response(JSON.stringify({ error: 'sync_failed' }), { status: 500, headers: { 'content-type': 'application/json' } });
      }
    }
    if (url.pathname === '/broadcast' && request.method === 'POST') {
      const body = await readBody(request);
      this.broadcast(String(body.event || ''), body.data, body.excludeDeviceId || null);
      return new Response('ok');
    }
    if (url.pathname !== '/connect' || request.headers.get('upgrade')?.toLowerCase() !== 'websocket') return new Response('not found', { status: 404 });
    const identity = {
      roomId: request.headers.get('x-room-id'), deviceId: request.headers.get('x-device-id'),
      role: request.headers.get('x-role'), label: request.headers.get('x-label') || '',
    };
    if (!identity.roomId || !identity.deviceId || !VALID_ROLE(identity.role)) return new Response('unauthorized', { status: 401 });
    const previouslyConnected = Array.from(new Set(this.sockets().map(ws => this.attachment(ws).deviceId).filter(Boolean)));
    const pair = new WebSocketPair();
    const client = pair[0], server = pair[1];
    this.state.acceptWebSocket(server);
    server.serializeAttachment(identity);
    const deviceIds = Array.from(new Set([...previouslyConnected, identity.deviceId]));
    this.send(server, 'presence:state', { deviceIds, at: nowIso() });
    const alreadyOnline = previouslyConnected.includes(identity.deviceId);
    if (!alreadyOnline) this.broadcast('presence', { deviceId: identity.deviceId, online: true, at: nowIso() }, identity.deviceId);
    return new Response(null, { status: 101, webSocket: client });
  }

  async webSocketMessage(ws, message) {
    const identity = this.attachment(ws);
    let parsed;
    try { parsed = JSON.parse(typeof message === 'string' ? message : decoder.decode(message)); } catch { return; }
    const event = String(parsed.event || ''); const data = parsed.data;
    if (event === 'ping') { this.send(ws, 'pong', { at: nowIso() }); return; }
    if (event === 'typing') {
      this.broadcast('typing', { deviceId: identity.deviceId, typing: Boolean(data) }, identity.deviceId); return;
    }
    if (event === 'message:delivered' || event === 'message:read') {
      const id = String(data?.id || data || ''); if (!id) return;
      const stamp = nowIso();
      if (event === 'message:read') {
        await this.env.DB.prepare('UPDATE messages SET delivered_at=COALESCE(delivered_at,?),read_at=? WHERE id=? AND room_id=?').bind(stamp, stamp, id, identity.roomId).run();
        this.broadcast('chat:read', { id, readAt: stamp }, identity.deviceId);
      } else {
        await this.env.DB.prepare('UPDATE messages SET delivered_at=COALESCE(delivered_at,?) WHERE id=? AND room_id=?').bind(stamp, id, identity.roomId).run();
        this.broadcast('chat:delivered', { id, deliveredAt: stamp }, identity.deviceId);
      }
      return;
    }
    if (event === 'call:signal' && data && typeof data === 'object') {
      const type = String(data.type || ''); const callId = String(data.callId || '').slice(0, 80);
      if (!['offer','answer','candidate','hangup','decline','busy'].includes(type) || !callId) return;
      const safe = { type, callId, fromDeviceId: identity.deviceId };
      if (type === 'offer') {
        safe.video = data.video === true; safe.sdp = String(data.sdp || '').slice(0, 100000); safe.sdpType = String(data.sdpType || 'offer').slice(0, 20);
        const other = await this.env.DB.prepare('SELECT id FROM devices WHERE room_id=? AND id<>? ORDER BY created_at LIMIT 1').bind(identity.roomId, identity.deviceId).first();
        const now = nowIso();
        await this.env.DB.prepare(`INSERT OR IGNORE INTO call_history(id,call_id,room_id,caller_device_id,callee_device_id,call_type,status,created_at,updated_at)
          VALUES(?,?,?,?,?,?, 'ringing',?,?)`).bind(crypto.randomUUID(), callId, identity.roomId, identity.deviceId, other?.id || null, safe.video ? 'video' : 'audio', now, now).run();
      } else if (type === 'answer') {
        safe.sdp = String(data.sdp || '').slice(0, 100000); safe.sdpType = String(data.sdpType || 'answer').slice(0, 20);
        await this.env.DB.prepare(`UPDATE call_history SET status='answered',answered_at=COALESCE(answered_at,?),updated_at=? WHERE call_id=? AND room_id=?`).bind(nowIso(), nowIso(), callId, identity.roomId).run();
      } else if (type === 'candidate') {
        safe.candidate = String(data.candidate || '').slice(0, 4000); safe.sdpMid = data.sdpMid == null ? null : String(data.sdpMid).slice(0,100);
        safe.sdpMLineIndex = Number.isInteger(data.sdpMLineIndex) ? data.sdpMLineIndex : null;
      } else {
        const row = await this.env.DB.prepare('SELECT caller_device_id,status,answered_at,call_type FROM call_history WHERE call_id=? AND room_id=?').bind(callId, identity.roomId).first();
        if (row) {
          let status = type === 'decline' ? 'declined' : type === 'busy' ? 'busy' : 'ended';
          if (type === 'hangup' && row.status === 'ringing') {
            const missed = data.missed === true && identity.deviceId === row.caller_device_id;
            status = missed ? 'missed' : 'cancelled'; safe.missed = missed; safe.video = row.call_type === 'video';
          }
          const endedAt = nowIso();
          await this.env.DB.prepare(`UPDATE call_history SET status=?,ended_at=COALESCE(ended_at,?),duration_seconds=CASE WHEN answered_at IS NULL THEN 0 ELSE MAX(0,CAST((julianday(?) - julianday(answered_at))*86400 AS INTEGER)) END,updated_at=? WHERE call_id=? AND room_id=?`)
            .bind(status, endedAt, endedAt, endedAt, callId, identity.roomId).run();
        }
      }
      this.broadcast('call:signal', safe, identity.deviceId);
    }
  }

  async webSocketClose(ws) {
    const identity = this.attachment(ws);
    const stillOnline = this.sockets().some(item => item !== ws && this.attachment(item).deviceId === identity.deviceId);
    if (identity.deviceId && !stillOnline) this.broadcast('presence', { deviceId: identity.deviceId, online: false, at: nowIso() });
  }
  async webSocketError(ws) { await this.webSocketClose(ws); }
}

export default {
  async fetch(request, env) {
    try {
      if (request.method === 'OPTIONS') return json({}, 204, request, env);
      return withCors(await handleApi(request, env), request, env);
    } catch (error) {
      console.error('request_failed', String(error?.stack || error?.message || error));
      return json({ error: 'internal_error' }, 500, request, env);
    }
  },
};
