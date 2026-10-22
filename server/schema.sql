CREATE EXTENSION IF NOT EXISTS pgcrypto;

CREATE TABLE IF NOT EXISTS rooms (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  code VARCHAR(8) UNIQUE NOT NULL,
  room_key VARCHAR(128) UNIQUE,
  pair_pin VARCHAR(6) NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  revision BIGINT NOT NULL DEFAULT 0
);

CREATE TABLE IF NOT EXISTS devices (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  room_id UUID NOT NULL REFERENCES rooms(id) ON DELETE CASCADE,
  role VARCHAR(16) NOT NULL CHECK (role IN ('me','sister')),
  label VARCHAR(32) NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  last_seen_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE(room_id, role)
);

CREATE TABLE IF NOT EXISTS room_snapshots (
  room_id UUID PRIMARY KEY REFERENCES rooms(id) ON DELETE CASCADE,
  payload JSONB NOT NULL DEFAULT '{"version":1,"notes":[]}',
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  revision BIGINT NOT NULL DEFAULT 0,
  updated_by UUID REFERENCES devices(id) ON DELETE SET NULL
);

CREATE TABLE IF NOT EXISTS messages (
  id UUID PRIMARY KEY,
  room_id UUID NOT NULL REFERENCES rooms(id) ON DELETE CASCADE,
  sender_id UUID NOT NULL REFERENCES devices(id) ON DELETE CASCADE,
  type VARCHAR(16) NOT NULL CHECK (type IN ('text','image','audio','file')),
  body TEXT NOT NULL DEFAULT '',
  attachment_id UUID,
  attachment_name TEXT,
  reply_to UUID REFERENCES messages(id) ON DELETE SET NULL,
  reaction VARCHAR(16),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  delivered_at TIMESTAMPTZ,
  read_at TIMESTAMPTZ
);

ALTER TABLE messages DROP CONSTRAINT IF EXISTS messages_type_check;
ALTER TABLE messages ADD CONSTRAINT messages_type_check CHECK (type IN ('text','image','video','video_note','audio','file'));

CREATE INDEX IF NOT EXISTS idx_messages_room_created ON messages(room_id, created_at DESC);

CREATE TABLE IF NOT EXISTS media (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  room_id UUID NOT NULL REFERENCES rooms(id) ON DELETE CASCADE,
  uploader_id UUID NOT NULL REFERENCES devices(id) ON DELETE CASCADE,
  kind VARCHAR(16) NOT NULL CHECK (kind IN ('image','video','audio','file')),
  original_name TEXT NOT NULL,
  mime TEXT NOT NULL,
  bytes BIGINT NOT NULL,
  disk_name TEXT NOT NULL,
  content_hash TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
ALTER TABLE media DROP CONSTRAINT IF EXISTS media_kind_check;
ALTER TABLE media ADD CONSTRAINT media_kind_check CHECK (kind IN ('image','video','video_note','audio','file'));

CREATE INDEX IF NOT EXISTS idx_media_room ON media(room_id);
CREATE UNIQUE INDEX IF NOT EXISTS uq_media_room_hash ON media(room_id, content_hash) WHERE content_hash IS NOT NULL;

ALTER TABLE messages ADD COLUMN IF NOT EXISTS attachment_name TEXT;
ALTER TABLE media ADD COLUMN IF NOT EXISTS content_hash TEXT;
CREATE UNIQUE INDEX IF NOT EXISTS uq_media_room_hash ON media(room_id, content_hash) WHERE content_hash IS NOT NULL;


CREATE TABLE IF NOT EXISTS accounts (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  room_id UUID NOT NULL REFERENCES rooms(id) ON DELETE CASCADE,
  role VARCHAR(16) NOT NULL CHECK (role IN ('me', 'sister')),
  password_hash TEXT NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE(room_id, role)
);


CREATE TABLE IF NOT EXISTS letters (
  id UUID PRIMARY KEY,
  room_id UUID NOT NULL REFERENCES rooms(id) ON DELETE CASCADE,
  sender_id UUID NOT NULL REFERENCES devices(id) ON DELETE CASCADE,
  title TEXT NOT NULL,
  body TEXT NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  read_at TIMESTAMPTZ
);
CREATE INDEX IF NOT EXISTS idx_letters_room_created ON letters(room_id, created_at ASC);


-- Chat reliability features: edited messages and pinned messages.
ALTER TABLE messages ADD COLUMN IF NOT EXISTS edited_at TIMESTAMPTZ;
ALTER TABLE messages ADD COLUMN IF NOT EXISTS is_pinned BOOLEAN NOT NULL DEFAULT FALSE;
ALTER TABLE messages ADD COLUMN IF NOT EXISTS reactions JSONB NOT NULL DEFAULT '{}'::jsonb;
CREATE INDEX IF NOT EXISTS idx_messages_room_pinned ON messages(room_id, is_pinned) WHERE is_pinned = TRUE;
CREATE INDEX IF NOT EXISTS idx_messages_room_edited ON messages(room_id, edited_at DESC);

-- Persistent call history shared only by authenticated members of the room.
CREATE TABLE IF NOT EXISTS call_history (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  call_id VARCHAR(80) UNIQUE NOT NULL,
  room_id UUID NOT NULL REFERENCES rooms(id) ON DELETE CASCADE,
  caller_device_id UUID NOT NULL REFERENCES devices(id) ON DELETE CASCADE,
  callee_device_id UUID REFERENCES devices(id) ON DELETE SET NULL,
  call_type VARCHAR(8) NOT NULL CHECK (call_type IN ('audio','video')),
  status VARCHAR(16) NOT NULL DEFAULT 'ringing'
    CHECK (status IN ('ringing','answered','missed','declined','cancelled','ended','busy','failed')),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  answered_at TIMESTAMPTZ,
  ended_at TIMESTAMPTZ,
  duration_seconds INTEGER NOT NULL DEFAULT 0,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_call_history_room_created ON call_history(room_id, created_at DESC);
