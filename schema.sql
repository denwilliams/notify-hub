CREATE TABLE IF NOT EXISTS events (
  id          INTEGER PRIMARY KEY AUTOINCREMENT,
  title       TEXT    NOT NULL,
  message     TEXT    NOT NULL,
  source      TEXT    NOT NULL,
  level       TEXT    NOT NULL DEFAULT 'info',
  urgent      INTEGER NOT NULL DEFAULT 0,
  url         TEXT,
  task_id     TEXT,
  pushed      INTEGER NOT NULL DEFAULT 0,
  read_at     TEXT,
  created_at  TEXT    NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_events_id_desc ON events(id DESC);
CREATE INDEX IF NOT EXISTS idx_events_pushed ON events(pushed, created_at);
CREATE INDEX IF NOT EXISTS idx_events_source ON events(source);
CREATE UNIQUE INDEX IF NOT EXISTS idx_events_task_id ON events(task_id) WHERE task_id IS NOT NULL;
