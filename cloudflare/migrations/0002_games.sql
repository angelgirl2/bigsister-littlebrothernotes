-- One shared, revisioned game session for the two members of a private room.
CREATE TABLE IF NOT EXISTS game_states (
  room_id TEXT PRIMARY KEY REFERENCES rooms(id) ON DELETE CASCADE,
  state TEXT NOT NULL DEFAULT '{}',
  revision INTEGER NOT NULL DEFAULT 0,
  updated_at TEXT NOT NULL,
  updated_by TEXT REFERENCES devices(id) ON DELETE SET NULL
);
