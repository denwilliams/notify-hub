ALTER TABLE events ADD COLUMN task_id TEXT;
CREATE UNIQUE INDEX IF NOT EXISTS idx_events_task_id ON events(task_id) WHERE task_id IS NOT NULL;
