-- tshop-catalog authoritative D1 schema (specs/05-server-architecture.md)

CREATE TABLE IF NOT EXISTS apps (
  package_name TEXT PRIMARY KEY,
  slug TEXT NOT NULL UNIQUE,
  status TEXT NOT NULL DEFAULT 'draft' CHECK (status IN ('draft', 'published', 'delisted')),
  rehost_mode TEXT NOT NULL CHECK (rehost_mode IN ('rehost', 'landing')),
  landing_reason_i18n TEXT,
  landing_url TEXT,
  name_i18n TEXT NOT NULL,
  summary_i18n TEXT NOT NULL,
  description_i18n TEXT NOT NULL,
  compat_notes_i18n TEXT,
  publisher TEXT NOT NULL,
  homepage_url TEXT NOT NULL,
  primary_category TEXT NOT NULL CHECK (primary_category IN ('Emulators', 'Frontends', 'Games', 'Utilities')),
  search_tags TEXT NOT NULL DEFAULT '[]',
  capabilities TEXT NOT NULL DEFAULT '[]',
  backdrop_colors TEXT NOT NULL,
  backdrop_angle REAL NOT NULL DEFAULT 160,
  icon_scale REAL NOT NULL DEFAULT 1.0,
  seed_rank INTEGER NOT NULL,
  editorial_pin INTEGER,
  source_type TEXT NOT NULL CHECK (source_type IN ('github_release', 'json_feed', 'html_links', 'direct_url', 'custom', 'none')),
  source_config TEXT NOT NULL DEFAULT '{}',
  license_spdx TEXT NOT NULL,
  license_notes TEXT,
  approved_release_id INTEGER REFERENCES releases(id),
  previous_release_id INTEGER REFERENCES releases(id),
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS app_certs (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  package_name TEXT NOT NULL REFERENCES apps(package_name),
  sha256_fingerprint TEXT NOT NULL,
  label TEXT NOT NULL,
  active INTEGER NOT NULL DEFAULT 1 CHECK (active IN (0, 1)),
  added_reason TEXT NOT NULL,
  added_by TEXT NOT NULL,
  created_at TEXT NOT NULL,
  revoked_at TEXT,
  revoked_reason TEXT
);

CREATE TABLE IF NOT EXISTS capability_tags (
  tag TEXT PRIMARY KEY,
  label_i18n TEXT NOT NULL,
  min_client_version_code INTEGER NOT NULL,
  created_at TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS releases (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  package_name TEXT NOT NULL REFERENCES apps(package_name),
  version_code INTEGER,
  version_name TEXT NOT NULL,
  released_at TEXT NOT NULL,
  changelog_i18n TEXT,
  state TEXT NOT NULL CHECK (state IN ('candidate', 'approved', 'quarantined', 'superseded', 'rejected', 'rolled_back')),
  variants_are_user_choice INTEGER NOT NULL DEFAULT 0 CHECK (variants_are_user_choice IN (0, 1)),
  validation_report TEXT NOT NULL DEFAULT '{}',
  quarantine_reasons TEXT,
  promoted_by TEXT,
  superseded_at TEXT,
  created_at TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS release_variants (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  release_id INTEGER NOT NULL REFERENCES releases(id),
  sha256 TEXT NOT NULL,
  size_bytes INTEGER NOT NULL,
  abis TEXT NOT NULL,
  min_sdk INTEGER NOT NULL,
  target_sdk INTEGER NOT NULL,
  label_i18n TEXT,
  note_i18n TEXT,
  upstream_url TEXT NOT NULL,
  r2_key TEXT NOT NULL,
  r2_present INTEGER NOT NULL DEFAULT 1 CHECK (r2_present IN (0, 1)),
  r2_gc_after TEXT
);

CREATE TABLE IF NOT EXISTS app_assets (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  package_name TEXT NOT NULL REFERENCES apps(package_name),
  kind TEXT NOT NULL CHECK (kind IN ('icon', 'feature', 'screenshot')),
  sort_order INTEGER NOT NULL DEFAULT 0,
  raw_r2_key TEXT NOT NULL,
  webp_sha256 TEXT NOT NULL,
  thumb_webp_sha256 TEXT,
  width INTEGER NOT NULL,
  height INTEGER NOT NULL,
  source_url TEXT NOT NULL,
  rights_basis TEXT NOT NULL,
  created_at TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS source_state (
  package_name TEXT PRIMARY KEY REFERENCES apps(package_name),
  last_checked_at TEXT,
  last_success_at TEXT,
  etag TEXT,
  last_modified TEXT,
  consecutive_failures INTEGER NOT NULL DEFAULT 0,
  last_error TEXT
);

CREATE TABLE IF NOT EXISTS client_releases (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  version_code INTEGER NOT NULL UNIQUE,
  version_name TEXT NOT NULL,
  released_at TEXT NOT NULL,
  changelog_i18n TEXT NOT NULL,
  sha256 TEXT NOT NULL,
  size_bytes INTEGER NOT NULL,
  min_sdk INTEGER NOT NULL,
  upstream_url TEXT NOT NULL,
  r2_key TEXT NOT NULL,
  is_current INTEGER NOT NULL DEFAULT 0 CHECK (is_current IN (0, 1)),
  min_supported_version_code INTEGER NOT NULL
);

CREATE TABLE IF NOT EXISTS jobs (
  id TEXT PRIMARY KEY,
  kind TEXT NOT NULL CHECK (kind IN ('ingest', 'watch_batch', 'validate_app', 'process_art', 'repair_adapter', 'publish')),
  target_package TEXT REFERENCES apps(package_name),
  status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'running', 'succeeded', 'failed', 'cancelled')),
  boat_sandbox_id TEXT,
  token_hash TEXT,
  token_expires_at TEXT,
  payload_json TEXT NOT NULL DEFAULT '{}',
  result_json TEXT,
  created_by TEXT NOT NULL,
  created_at TEXT NOT NULL,
  finished_at TEXT
);

CREATE TABLE IF NOT EXISTS ops_alerts (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  severity TEXT NOT NULL CHECK (severity IN ('critical', 'warning', 'info')),
  kind TEXT NOT NULL,
  package_name TEXT REFERENCES apps(package_name),
  summary TEXT NOT NULL,
  details_json TEXT NOT NULL DEFAULT '{}',
  status TEXT NOT NULL DEFAULT 'open' CHECK (status IN ('open', 'acknowledged', 'resolved')),
  emailed_at TEXT,
  created_at TEXT NOT NULL,
  resolved_at TEXT
);

CREATE TABLE IF NOT EXISTS audit_log (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  actor TEXT NOT NULL,
  action TEXT NOT NULL,
  target_type TEXT NOT NULL,
  target_id TEXT NOT NULL,
  reason TEXT,
  diff_json TEXT NOT NULL DEFAULT '{}',
  created_at TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS publish_history (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  generated_at TEXT NOT NULL,
  schema_version INTEGER NOT NULL,
  min_client_version_code INTEGER NOT NULL,
  key_id TEXT NOT NULL,
  catalog_sha256 TEXT NOT NULL,
  pages_deployment_id TEXT,
  apk_base_url TEXT NOT NULL,
  entry_count INTEGER NOT NULL,
  trigger TEXT NOT NULL,
  created_at TEXT NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_apps_status ON apps(status);
CREATE INDEX IF NOT EXISTS idx_apps_category_status ON apps(primary_category, status);
CREATE INDEX IF NOT EXISTS idx_app_certs_package_active ON app_certs(package_name, active);
CREATE INDEX IF NOT EXISTS idx_app_certs_package_fingerprint ON app_certs(package_name, sha256_fingerprint);
CREATE INDEX IF NOT EXISTS idx_releases_package_state ON releases(package_name, state);
CREATE INDEX IF NOT EXISTS idx_releases_package_version_code ON releases(package_name, version_code DESC);
CREATE INDEX IF NOT EXISTS idx_release_variants_release_id ON release_variants(release_id);
CREATE INDEX IF NOT EXISTS idx_release_variants_sha256 ON release_variants(sha256);
CREATE INDEX IF NOT EXISTS idx_release_variants_gc ON release_variants(r2_present, r2_gc_after);
CREATE INDEX IF NOT EXISTS idx_app_assets_package_kind ON app_assets(package_name, kind, sort_order);
CREATE INDEX IF NOT EXISTS idx_client_releases_current ON client_releases(is_current);
CREATE INDEX IF NOT EXISTS idx_jobs_status_created ON jobs(status, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_jobs_target_package ON jobs(target_package);
CREATE INDEX IF NOT EXISTS idx_ops_alerts_status_severity ON ops_alerts(status, severity, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_ops_alerts_package ON ops_alerts(package_name, status);
CREATE INDEX IF NOT EXISTS idx_audit_log_target ON audit_log(target_type, target_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_publish_history_generated_at ON publish_history(generated_at DESC);
