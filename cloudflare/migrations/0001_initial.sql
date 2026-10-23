CREATE TABLE IF NOT EXISTS rooms (
  id TEXT PRIMARY KEY,
  code TEXT NOT NULL UNIQUE,
  room_key TEXT UNIQUE,
  pair_pin TEXT NOT NULL,
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL,
  revision INTEGER NOT NULL DEFAULT 0
);

CREATE TABLE IF NOT EXISTS devices (
  id TEXT PRIMARY KEY,
  room_id TEXT NOT NULL REFERENCES rooms(id) ON DELETE CASCADE,
  role TEXT NOT NULL CHECK (role IN ('me','sister')),
  label TEXT NOT NULL,
  created_at TEXT NOT NULL,
  last_seen_at TEXT NOT NULL,
  UNIQUE(room_id, role)
);

CREATE TABLE IF NOT EXISTS room_snapshots (
  room_id TEXT PRIMARY KEY REFERENCES rooms(id) ON DELETE CASCADE,
  payload TEXT NOT NULL DEFAULT '{"version":1,"notes":[]}',
  updated_at TEXT NOT NULL,
  revision INTEGER NOT NULL DEFAULT 0,
  updated_by TEXT REFERENCES devices(id) ON DELETE SET NULL
);

CREATE TABLE IF NOT EXISTS messages (
  id TEXT PRIMARY KEY,
  room_id TEXT NOT NULL REFERENCES rooms(id) ON DELETE CASCADE,
  sender_id TEXT NOT NULL REFERENCES devices(id) ON DELETE CASCADE,
  type TEXT NOT NULL CHECK (type IN ('text','image','video','video_note','audio','file')),
  body TEXT NOT NULL DEFAULT '',
  attachment_id TEXT,
  attachment_name TEXT,
  reply_to TEXT REFERENCES messages(id) ON DELETE SET NULL,
  reaction TEXT,
  reactions TEXT NOT NULL DEFAULT '{}',
  is_pinned INTEGER NOT NULL DEFAULT 0,
  edited_at TEXT,
  created_at TEXT NOT NULL,
  delivered_at TEXT,
  read_at TEXT
);
CREATE INDEX IF NOT EXISTS idx_messages_room_created ON messages(room_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_messages_room_pinned ON messages(room_id, is_pinned);
CREATE INDEX IF NOT EXISTS idx_messages_room_edited ON messages(room_id, edited_at DESC);

CREATE TABLE IF NOT EXISTS media (
  id TEXT PRIMARY KEY,
  room_id TEXT NOT NULL REFERENCES rooms(id) ON DELETE CASCADE,
  uploader_id TEXT NOT NULL REFERENCES devices(id) ON DELETE CASCADE,
  kind TEXT NOT NULL CHECK (kind IN ('image','video','video_note','audio','file')),
  original_name TEXT NOT NULL,
  mime TEXT NOT NULL,
  bytes INTEGER NOT NULL,
  disk_name TEXT NOT NULL,
  content_hash TEXT,
  created_at TEXT NOT NULL
);
CREATE INDEX IF NOT EXISTS idx_media_room ON media(room_id);
CREATE UNIQUE INDEX IF NOT EXISTS uq_media_room_hash ON media(room_id, content_hash) WHERE content_hash IS NOT NULL;

CREATE TABLE IF NOT EXISTS letters (
  id TEXT PRIMARY KEY,
  room_id TEXT NOT NULL REFERENCES rooms(id) ON DELETE CASCADE,
  sender_id TEXT NOT NULL REFERENCES devices(id) ON DELETE CASCADE,
  title TEXT NOT NULL,
  body TEXT NOT NULL,
  created_at TEXT NOT NULL,
  read_at TEXT
);
CREATE INDEX IF NOT EXISTS idx_letters_room_created ON letters(room_id, created_at ASC);

CREATE TABLE IF NOT EXISTS call_history (
  id TEXT PRIMARY KEY,
  call_id TEXT NOT NULL UNIQUE,
  room_id TEXT NOT NULL REFERENCES rooms(id) ON DELETE CASCADE,
  caller_device_id TEXT NOT NULL REFERENCES devices(id) ON DELETE CASCADE,
  callee_device_id TEXT REFERENCES devices(id) ON DELETE SET NULL,
  call_type TEXT NOT NULL CHECK (call_type IN ('audio','video')),
  status TEXT NOT NULL DEFAULT 'ringing',
  created_at TEXT NOT NULL,
  answered_at TEXT,
  ended_at TEXT,
  duration_seconds INTEGER NOT NULL DEFAULT 0,
  updated_at TEXT NOT NULL
);
CREATE INDEX IF NOT EXISTS idx_call_history_room_created ON call_history(room_id, created_at DESC);


-- Free-tier media storage: split files into small SQLite BLOB chunks instead of requiring an R2 billing subscription.
CREATE TABLE IF NOT EXISTS media_chunks (
  media_id TEXT NOT NULL REFERENCES media(id) ON DELETE CASCADE,
  chunk_index INTEGER NOT NULL,
  data BLOB NOT NULL,
  PRIMARY KEY(media_id, chunk_index)
);
