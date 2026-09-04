CREATE TABLE IF NOT EXISTS completions (
  object_key TEXT NOT NULL,
  utc_day TEXT NOT NULL,
  n INTEGER NOT NULL DEFAULT 0,
  PRIMARY KEY (object_key, utc_day)
);
