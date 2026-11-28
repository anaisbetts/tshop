CREATE TABLE IF NOT EXISTS completions (
  sha256 TEXT NOT NULL,
  utc_day TEXT NOT NULL,
  intent TEXT NOT NULL CHECK(intent IN ('install', 'update', 'unknown')),
  n INTEGER NOT NULL DEFAULT 0,
  PRIMARY KEY (sha256, utc_day, intent)
);

CREATE INDEX IF NOT EXISTS idx_completions_utc_day ON completions(utc_day);
