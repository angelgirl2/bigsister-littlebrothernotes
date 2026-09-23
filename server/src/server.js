import http from 'node:http';
import crypto from 'node:crypto';
import fs from 'node:fs/promises';
import path from 'node:path';
import process from 'node:process';
import express from 'express';
import cors from 'cors';
import bcrypt from 'bcryptjs';
import helmet from 'helmet';
import jwt from 'jsonwebtoken';
import multer from 'multer';
import pg from 'pg';
import { Server as SocketIOServer } from 'socket.io';

const { Pool } = pg;
const PORT = Number(process.env.PORT || 3000);
const ROOM_CODE_TTL_HOURS = Number(process.env.ROOM_CODE_TTL_HOURS || 24);
const JWT_SECRET = String(process.env.JWT_SECRET || '').trim();
const MEDIA_DIR = process.env.MEDIA_DIR || '/data/media';
const MAX_UPLOAD_MB = Number(process.env.MAX_UPLOAD_MB || 25);
const SHARED_ROOM_KEY = process.env.SHARED_ROOM_KEY || 'big-sister-private-room';
const ME_PASSWORD = process.env.ME_PASSWORD || '';
const SISTER_PASSWORD = process.env.SISTER_PASSWORD || '';
const ME_LABEL = process.env.ME_LABEL || 'من';
const SISTER_LABEL = process.env.SISTER_LABEL || 'آبجی';
const DATABASE_URL = String(process.env.DATABASE_URL || '').trim();
const pool = new Pool({
  connectionString: DATABASE_URL || undefined,
  connectionTimeoutMillis: 5000,
  idleTimeoutMillis: 30000,
  max: 10,
});
let dbReady = false;
let dbInitError = null;

const app = express();
const server = http.createServer(app);
const io = new SocketIOServer(server, {
  cors: { origin: process.env.CORS_ORIGIN || '*', methods: ['GET', 'POST', 'PUT', 'PATCH', 'DELETE'] },
  maxHttpBufferSize: 30 * 1024 * 1024,
});

app.use(helmet({ crossOriginResourcePolicy: false }));
app.use(cors({ origin: process.env.CORS_ORIGIN || '*' }));
app.use(express.json({ limit: '120mb' }));
app.use(express.urlencoded({ extended: true }));

await fs.mkdir(MEDIA_DIR, { recursive: true });

const upload = multer({
  dest: MEDIA_DIR,
  limits: { fileSize: MAX_UPLOAD_MB * 1024 * 1024 },
});

function randomCode(length = 8) {
  const alphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  const bytes = crypto.randomBytes(length);
  return Array.from(bytes, b => alphabet[b % alphabet.length]).join('');
}

function randomPin() {
  return String(crypto.randomInt(100000, 999999));
}

function signToken(device) {
  return jwt.sign(
    { deviceId: device.id, roomId: device.room_id, role: device.role, label: device.label },
    JWT_SECRET,
    { expiresIn: '365d', issuer: 'big-sister-notes' },
  );
}

function auth(req, res, next) {
  const header = req.headers.authorization || '';
  const token = header.startsWith('Bearer ') ? header.slice(7) : null;
  if (!token) return res.status(401).json({ error: 'unauthorized' });
  try {
    req.user = jwt.verify(token, JWT_SECRET);
    return next();
  } catch {
    return res.status(401).json({ error: 'invalid_token' });
  }
}

async function getDevice(deviceId) {
  const { rows } = await pool.query(
    'SELECT id, room_id, role, label FROM devices WHERE id = $1',
    [deviceId],
  );
  return rows[0] || null;
}

async function touchDevice(deviceId) {
  await pool.query('UPDATE devices SET last_seen_at = now() WHERE id = $1', [deviceId]);
}

function validateRole(role) {
  return role === 'me' || role === 'sister';
}

function chooseNewer(localItem, remoteItem) {
  const localUpdated = Date.parse(localItem?.updatedAt || localItem?.createdAt || 0);
  const remoteUpdated = Date.parse(remoteItem?.updatedAt || remoteItem?.createdAt || 0);
  if (remoteUpdated > localUpdated) return remoteItem;
  if (remoteUpdated < localUpdated) return localItem;
  return remoteItem;
}

function mergeSnapshots(current, incoming) {
  const currentNotes = Array.isArray(current?.notes) ? current.notes : [];
  const incomingNotes = Array.isArray(incoming?.notes) ? incoming.notes : [];
  const deletedIds = new Set([
    ...(Array.isArray(current?.deletedIds) ? current.deletedIds : []),
    ...(Array.isArray(incoming?.deletedIds) ? incoming.deletedIds : []),
  ]);
  const incomingLiveIds = new Set(
    incomingNotes
      .filter((n) => n?.id && !n?.deletedAt)
      .map((n) => n.id),
  );
  // A newer local restore clears this device's old permanent-delete tombstone.
  for (const id of incomingLiveIds) deletedIds.delete(id);

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


async function ensureSharedRoom() {
  let result = await pool.query('SELECT id, code, pair_pin FROM rooms WHERE room_key = $1 LIMIT 1', [SHARED_ROOM_KEY]);
  if (result.rows[0]) return result.rows[0];

  // Reuse the first existing room from an older pairing-based installation when possible.
  result = await pool.query('SELECT id, code, pair_pin FROM rooms ORDER BY created_at LIMIT 1');
  if (result.rows[0]) {
    await pool.query('UPDATE rooms SET room_key = $2, updated_at = now() WHERE id = $1', [result.rows[0].id, SHARED_ROOM_KEY]);
    return result.rows[0];
  }

  const code = randomCode(8);
  const pairPin = randomPin();
  const created = await pool.query(
    'INSERT INTO rooms (code, pair_pin, room_key) VALUES ($1, $2, $3) RETURNING id, code, pair_pin',
    [code, pairPin, SHARED_ROOM_KEY],
  );
  return created.rows[0];
}

async function ensureAccount(roomId, role, password, label) {
  if (!password) throw new Error(`${role.toUpperCase()}_PASSWORD must be set`);
  const hash = await bcrypt.hash(password, 12);
  await pool.query(
    `INSERT INTO accounts(room_id, role, password_hash) VALUES ($1,$2,$3)
     ON CONFLICT(room_id, role) DO UPDATE SET password_hash=EXCLUDED.password_hash, updated_at=now()`,
    [roomId, role, hash],
  );
  let device = await pool.query('SELECT id, room_id, role, label FROM devices WHERE room_id = $1 AND role = $2 LIMIT 1', [roomId, role]);
  if (!device.rows[0]) {
    device = await pool.query(
      'INSERT INTO devices(room_id, role, label) VALUES ($1,$2,$3) RETURNING id, room_id, role, label',
      [roomId, role, label],
    );
  } else if (device.rows[0].label !== label) {
    await pool.query('UPDATE devices SET label = $2 WHERE id = $1', [device.rows[0].id, label]);
    device.rows[0].label = label;
  }
  return device.rows[0];
}

app.post('/api/auth/login', async (req, res) => {
  const role = String(req.body?.role || '');
  const password = String(req.body?.password || '');
  if (!validateRole(role) || password.length < 4) {
    return res.status(400).json({ error: 'invalid_login' });
  }
  try {
    const room = await ensureSharedRoom();
    const label = role === 'me' ? ME_LABEL : SISTER_LABEL;
    const expected = role === 'me' ? ME_PASSWORD : SISTER_PASSWORD;
    if (!expected) throw new Error('missing_password');
    const account = await pool.query('SELECT password_hash FROM accounts WHERE room_id = $1 AND role = $2', [room.id, role]);
    const hash = account.rows[0]?.password_hash || await bcrypt.hash(expected, 12);
    if (!(await bcrypt.compare(password, hash))) {
      return res.status(401).json({ error: 'invalid_login' });
    }
    const device = await ensureAccount(room.id, role, expected, label);
    return res.json({
      token: signToken(device),
      roomId: room.id,
      deviceId: device.id,
      role,
      label,
    });
  } catch (e) {
    if (String(e.message).includes('PASSWORD must be set')) return res.status(500).json({ error: 'server_credentials_missing' });
    return res.status(500).json({ error: 'login_failed' });
  }
});

app.get('/', (_req, res) => res.json({ service: 'big-sister-sync', health: '/api/health' }));

app.get('/api/health', async (_req, res) => {
  if (!dbReady) {
    return res.status(503).json({
      ok: false,
      service: 'big-sister-sync',
      status: 'starting',
      error: dbInitError || 'database_not_ready',
    });
  }
  try {
    await pool.query('SELECT 1');
    return res.json({ ok: true, service: 'big-sister-sync', time: new Date().toISOString() });
  } catch (e) {
    dbReady = false;
    dbInitError = 'database_unavailable';
    return res.status(503).json({ ok: false, service: 'big-sister-sync', status: 'database_unavailable' });
  }
});

app.post('/api/pair/create', async (req, res) => {
  const role = String(req.body?.role || '');
  if (!validateRole(role)) return res.status(400).json({ error: 'invalid_role' });
  const code = randomCode(8);
  const pairPin = randomPin();
  const label = role === 'me' ? 'من' : 'آبجی';
  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    const room = await client.query(
      'INSERT INTO rooms (code, pair_pin) VALUES ($1, $2) RETURNING id, code, pair_pin',
      [code, pairPin],
    );
    const device = await client.query(
      'INSERT INTO devices (room_id, role, label) VALUES ($1, $2, $3) RETURNING id, room_id, role, label',
      [room.rows[0].id, role, label],
    );
    await client.query(
      'INSERT INTO room_snapshots (room_id, payload, revision, updated_by) VALUES ($1, $2, 0, $3)',
      [room.rows[0].id, JSON.stringify({ version: 4, notes: [], deletedIds: [] }), device.rows[0].id],
    );
    await client.query('COMMIT');
    return res.json({
      token: signToken(device.rows[0]),
      roomId: room.rows[0].id,
      deviceId: device.rows[0].id,
      role,
      label,
      code,
      pairPin,
    });
  } catch (e) {
    await client.query('ROLLBACK');
    return res.status(500).json({ error: 'create_failed' });
  } finally {
    client.release();
  }
});

app.post('/api/pair/join', async (req, res) => {
  const code = String(req.body?.code || '').trim().toUpperCase();
  const pairPin = String(req.body?.pairPin || '').trim();
  const requestedRole = String(req.body?.role || '');
  if (!code || !/^\d{6}$/.test(pairPin) || !validateRole(requestedRole)) {
    return res.status(400).json({ error: 'invalid_pairing' });
  }
  const { rows } = await pool.query('SELECT * FROM rooms WHERE code = $1', [code]);
  const room = rows[0];
  if (!room) return res.status(404).json({ error: 'room_not_found' });
  if (Date.now() - Date.parse(room.created_at) > ROOM_CODE_TTL_HOURS * 3600 * 1000) {
    return res.status(410).json({ error: 'pairing_expired' });
  }
  const ok = pairPin === room.pair_pin;
  if (!ok) return res.status(403).json({ error: 'wrong_pair_pin' });
  const members = await pool.query('SELECT id, role, label FROM devices WHERE room_id = $1', [room.id]);
  if (members.rowCount >= 2) return res.status(409).json({ error: 'room_full' });
  if (members.rows.some(d => d.role === requestedRole)) return res.status(409).json({ error: 'role_taken' });
  const label = requestedRole === 'me' ? 'من' : 'آبجی';
  const device = await pool.query(
    'INSERT INTO devices (room_id, role, label) VALUES ($1, $2, $3) RETURNING id, room_id, role, label',
    [room.id, requestedRole, label],
  );
  await pool.query('UPDATE rooms SET updated_at = now() WHERE id = $1', [room.id]);
  io.to(`room:${room.id}`).emit('pair:completed', { label });
  return res.json({
    token: signToken(device.rows[0]), roomId: room.id, deviceId: device.rows[0].id,
    role: requestedRole, label, code, pairPin,
  });
});

app.get('/api/pair/status', auth, async (req, res) => {
  await touchDevice(req.user.deviceId);
  const members = await pool.query(
    'SELECT id, role, label, last_seen_at FROM devices WHERE room_id = $1 ORDER BY created_at',
    [req.user.roomId],
  );
  return res.json({ roomId: req.user.roomId, members: members.rows });
});

app.get('/api/sync/snapshot', auth, async (req, res) => {
  await touchDevice(req.user.deviceId);
  const snap = await pool.query('SELECT payload, revision, updated_at FROM room_snapshots WHERE room_id = $1', [req.user.roomId]);
  const row = snap.rows[0] || { payload: { version: 4, notes: [], deletedIds: [] }, revision: 0 };
  return res.json({ revision: row.revision, updatedAt: row.updated_at, payload: row.payload });
});

app.put('/api/sync/snapshot', auth, async (req, res) => {
  await touchDevice(req.user.deviceId);
  const incoming = req.body?.payload;
  if (!incoming || typeof incoming !== 'object' || !Array.isArray(incoming.notes)) {
    return res.status(400).json({ error: 'invalid_snapshot' });
  }
  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    const existing = await client.query('SELECT payload, revision FROM room_snapshots WHERE room_id = $1 FOR UPDATE', [req.user.roomId]);
    const currentPayload = existing.rows[0]?.payload || { version: 4, notes: [], deletedIds: [] };
    const merged = mergeSnapshots(currentPayload, incoming);
    const nextRevision = Number(existing.rows[0]?.revision || 0) + 1;
    await client.query(
      `INSERT INTO room_snapshots(room_id, payload, revision, updated_at, updated_by)
       VALUES ($1, $2, $3, now(), $4)
       ON CONFLICT(room_id) DO UPDATE SET payload=EXCLUDED.payload, revision=EXCLUDED.revision, updated_at=now(), updated_by=EXCLUDED.updated_by`,
      [req.user.roomId, JSON.stringify(merged), nextRevision, req.user.deviceId],
    );
    await client.query('UPDATE rooms SET revision = $2, updated_at = now() WHERE id = $1', [req.user.roomId, nextRevision]);
    await client.query('COMMIT');
    io.to(`room:${req.user.roomId}`).emit('content:changed', { revision: nextRevision, updatedBy: req.user.deviceId });
    return res.json({ revision: nextRevision, payload: merged });
  } catch {
    await client.query('ROLLBACK');
    return res.status(500).json({ error: 'sync_failed' });
  } finally {
    client.release();
  }
});

app.get('/api/chat/messages', auth, async (req, res) => {
  await touchDevice(req.user.deviceId);
  const limit = Math.min(Math.max(Number(req.query.limit || 50), 1), 100);
  const before = req.query.before ? new Date(String(req.query.before)) : null;
  const params = [req.user.roomId, limit];
  let q = `SELECT id, sender_id, type, body, attachment_id, attachment_name, reply_to, reaction, created_at, delivered_at, read_at
           FROM messages WHERE room_id = $1`;
  if (before && !Number.isNaN(before.getTime())) { q += ' AND created_at < $3'; params.push(before); }
  q += ' ORDER BY created_at DESC LIMIT $2';
  const result = await pool.query(q, params);
  return res.json({ messages: result.rows.reverse() });
});

async function sha256File(filePath) {
  const bytes = await fs.readFile(filePath);
  return crypto.createHash('sha256').update(bytes).digest('hex');
}

async function saveMediaRecord({ roomId, uploaderId, kind, file, contentHash }) {
  const originalName = file.originalname || 'file';
  const mime = file.mimetype || 'application/octet-stream';
  const existing = contentHash
    ? await pool.query(
        'SELECT id, kind, original_name, mime, bytes FROM media WHERE room_id = $1 AND content_hash = $2 LIMIT 1',
        [roomId, contentHash],
      )
    : { rows: [] };

  if (existing.rows[0]) {
    await fs.rm(file.path, { force: true });
    const row = existing.rows[0];
    return {
      id: row.id,
      kind: row.kind,
      originalName: row.original_name,
      mime: row.mime,
      bytes: Number(row.bytes),
      reused: true,
      url: `/api/media/${row.id}`,
    };
  }

  const id = crypto.randomUUID();
  const ext = path.extname(originalName).replace(/[^a-zA-Z0-9._-]/g, '').slice(0, 12);
  const diskName = `${id}${ext}`;
  const target = path.join(MEDIA_DIR, diskName);
  await fs.rename(file.path, target);
  await pool.query(
    `INSERT INTO media(id, room_id, uploader_id, kind, original_name, mime, bytes, disk_name, content_hash)
     VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9)`,
    [id, roomId, uploaderId, kind, originalName, mime, file.size, diskName, contentHash || null],
  );
  return { id, kind, originalName, mime, bytes: file.size, reused: false, url: `/api/media/${id}` };
}

app.post('/api/media', auth, upload.single('file'), async (req, res) => {
  await touchDevice(req.user.deviceId);
  if (!req.file) return res.status(400).json({ error: 'file_required' });
  const kind = ['image', 'audio', 'file'].includes(req.body?.kind) ? req.body.kind : 'file';
  try {
    const contentHash = await sha256File(req.file.path);
    const saved = await saveMediaRecord({
      roomId: req.user.roomId,
      uploaderId: req.user.deviceId,
      kind,
      file: req.file,
      contentHash,
    });
    return res.json(saved);
  } catch (e) {
    await fs.rm(req.file.path, { force: true }).catch(() => {});
    return res.status(500).json({ error: 'media_upload_failed' });
  }
});

app.post('/api/sync/media', auth, upload.single('file'), async (req, res) => {
  await touchDevice(req.user.deviceId);
  if (!req.file) return res.status(400).json({ error: 'file_required' });
  const kind = ['image', 'audio'].includes(req.body?.kind) ? req.body.kind : 'file';
  try {
    const contentHash = String(req.body?.sha256 || '').trim().toLowerCase() || await sha256File(req.file.path);
    if (!/^[a-f0-9]{64}$/.test(contentHash)) {
      await fs.rm(req.file.path, { force: true });
      return res.status(400).json({ error: 'invalid_sha256' });
    }
    const saved = await saveMediaRecord({
      roomId: req.user.roomId,
      uploaderId: req.user.deviceId,
      kind,
      file: req.file,
      contentHash,
    });
    return res.json(saved);
  } catch {
    await fs.rm(req.file.path, { force: true }).catch(() => {});
    return res.status(500).json({ error: 'sync_media_upload_failed' });
  }
});

app.get('/api/media/:id', auth, async (req, res) => {
  const result = await pool.query('SELECT * FROM media WHERE id = $1 AND room_id = $2', [req.params.id, req.user.roomId]);
  const row = result.rows[0];
  if (!row) return res.status(404).end();
  const target = path.join(MEDIA_DIR, row.disk_name);
  try {
    await fs.access(target);
    res.setHeader('Content-Type', row.mime);
    res.setHeader('Content-Disposition', `inline; filename*=UTF-8''${encodeURIComponent(row.original_name)}`);
    res.setHeader('Cache-Control', 'private, max-age=86400');
    return res.sendFile(path.resolve(target));
  } catch {
    return res.status(404).end();
  }
});

app.post('/api/chat/messages', auth, async (req, res) => {
  await touchDevice(req.user.deviceId);
  const requestedId = String(req.body?.id || '');
  const id = /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i.test(requestedId)
    ? requestedId
    : crypto.randomUUID();
  const type = ['text','image','audio','file'].includes(req.body?.type) ? req.body.type : 'text';
  const body = String(req.body?.body || '').slice(0, 20000);
  const attachmentId = req.body?.attachmentId || null;
  const attachmentName = req.body?.attachmentName ? String(req.body.attachmentName).slice(0, 255) : null;
  const replyTo = req.body?.replyTo || null;
  const reaction = req.body?.reaction || null;
  if (attachmentId) {
    const attachment = await pool.query(
      'SELECT id FROM media WHERE id = $1 AND room_id = $2',
      [attachmentId, req.user.roomId],
    );
    if (!attachment.rows[0]) return res.status(400).json({ error: 'attachment_not_found' });
  }
  const result = await pool.query(
    `INSERT INTO messages(id, room_id, sender_id, type, body, attachment_id, attachment_name, reply_to, reaction)
     VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9)
     RETURNING id, sender_id, type, body, attachment_id, attachment_name, reply_to, reaction, created_at, delivered_at, read_at`,
    [id, req.user.roomId, req.user.deviceId, type, body, attachmentId, attachmentName, replyTo, reaction],
  );
  const message = result.rows[0];
  io.to(`room:${req.user.roomId}`).emit('chat:message', message);
  return res.status(201).json({ message });
});

app.patch('/api/chat/messages/:id/read', auth, async (req, res) => {
  const updated = await pool.query(
    `UPDATE messages SET delivered_at = COALESCE(delivered_at, now()), read_at = now()
     WHERE id = $1 AND room_id = $2 RETURNING id, read_at`,
    [req.params.id, req.user.roomId],
  );
  if (!updated.rows[0]) return res.status(404).json({ error: 'message_not_found' });
  io.to(`room:${req.user.roomId}`).emit('chat:read', { id: req.params.id, readAt: updated.rows[0].read_at });
  return res.json(updated.rows[0]);
});

app.patch('/api/chat/messages/:id/reaction', auth, async (req, res) => {
  const reaction = String(req.body?.reaction || '').slice(0, 8);
  const updated = await pool.query(
    `UPDATE messages SET reaction = $3
     WHERE id = $1 AND room_id = $2 RETURNING id, reaction`,
    [req.params.id, req.user.roomId, reaction || null],
  );
  if (!updated.rows[0]) return res.status(404).json({ error: 'message_not_found' });
  io.to(`room:${req.user.roomId}`).emit('chat:reaction', { id: req.params.id, reaction: updated.rows[0].reaction });
  return res.json(updated.rows[0]);
});

io.use((socket, next) => {
  try {
    const header = socket.handshake.auth?.token || socket.handshake.headers?.authorization || '';
    const token = String(header).startsWith('Bearer ') ? String(header).slice(7) : String(header);
    socket.user = jwt.verify(token, JWT_SECRET);
    return next();
  } catch {
    return next(new Error('unauthorized'));
  }
});

io.on('connection', async (socket) => {
  const { roomId, deviceId } = socket.user;
  socket.join(`room:${roomId}`);
  await touchDevice(deviceId);
  io.to(`room:${roomId}`).emit('presence', { deviceId, online: true, at: new Date().toISOString() });

  socket.on('typing', (value) => {
    socket.to(`room:${roomId}`).emit('typing', { deviceId, typing: Boolean(value) });
  });

  socket.on('message:delivered', async (messageId) => {
    await pool.query('UPDATE messages SET delivered_at = COALESCE(delivered_at, now()) WHERE id = $1 AND room_id = $2', [messageId, roomId]);
    socket.to(`room:${roomId}`).emit('chat:delivered', { id: messageId, deliveredAt: new Date().toISOString() });
  });

  socket.on('message:read', async (messageId) => {
    await pool.query('UPDATE messages SET read_at = now(), delivered_at = COALESCE(delivered_at, now()) WHERE id = $1 AND room_id = $2', [messageId, roomId]);
    socket.to(`room:${roomId}`).emit('chat:read', { id: messageId, readAt: new Date().toISOString() });
  });

  socket.on('disconnect', async () => {
    await touchDevice(deviceId);
    io.to(`room:${roomId}`).emit('presence', { deviceId, online: false, at: new Date().toISOString() });
  });
});

server.listen(PORT, '0.0.0.0', () => {
  console.log(`Big Sister sync server listening on ${PORT}`);
  void initDbWithRetry();
});

async function initDb() {
  if (!DATABASE_URL) {
    throw new Error('DATABASE_URL is missing');
  }
  if (!ME_PASSWORD) {
    throw new Error('ME_PASSWORD is missing');
  }
  if (!SISTER_PASSWORD) {
    throw new Error('SISTER_PASSWORD is missing');
  }
  if (!JWT_SECRET) {
    throw new Error('JWT_SECRET is missing');
  }
  const sql = await fs.readFile(new URL('../schema.sql', import.meta.url), 'utf8');
  await pool.query(sql);
  const room = await ensureSharedRoom();
  await ensureAccount(room.id, 'me', ME_PASSWORD, ME_LABEL);
  await ensureAccount(room.id, 'sister', SISTER_PASSWORD, SISTER_LABEL);
}

async function initDbWithRetry() {
  const maxAttempts = 30;
  for (let attempt = 1; attempt <= maxAttempts; attempt += 1) {
    try {
      await initDb();
      dbReady = true;
      dbInitError = null;
      console.log('PostgreSQL is ready and the shared room is initialized.');
      return;
    } catch (error) {
      dbReady = false;
      dbInitError = error instanceof Error ? error.message : String(error);
      console.error(`Database initialization attempt ${attempt}/${maxAttempts} failed: ${dbInitError}`);
      if (attempt < maxAttempts) {
        await new Promise((resolve) => setTimeout(resolve, 5000));
      }
    }
  }
  console.error('Database initialization did not succeed. The service will stay alive and health checks will remain 503 until a redeploy/restart with valid database configuration.');
}
