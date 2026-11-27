/** `en` is required; other keys are BCP-47 tags. */
export type Localized<T = string> = { en: T } & Record<string, T>;

export type CategoryId = "Emulators" | "Frontends" | "Games" | "Utilities";

export type RehostMode = "rehost" | "landing";

export type DownloadIntent = "install" | "update" | "unknown";

export interface Env {
  CATALOG_DB: D1Database;
  ANALYTICS_DB: D1Database;
  APKS_BUCKET: R2Bucket;
  ASSETS_BUCKET: R2Bucket;
}

export interface Pointer {
  schemaVersion: 1;
  minClientVersionCode: number;
  generatedAt: string;
  keyId: string;
  catalogUrl: string;
  catalogSha256: string;
  catalogSize: number;
  statsUrl: string;
  signature: string;
}

export interface Catalog {
  schemaVersion: 1;
  /** ISO-8601 UTC. Shown as the catalog date in Settings and About. */
  generatedAt: string;
  /** Normally `https://dl.tshop.../apk`; flipped to `https://cdn.tshop...` by the degrade lever. */
  apkBaseUrl: string;
  /** Current tShop build, for self-update. Null when no client release is published yet. */
  client: ClientRelease | null;
  /** Labels for every tag used by any entry. */
  capabilityTags: CapabilityTag[];
  /** Browse frames in fixed curator order; empty categories are omitted. */
  categories: CategoryFrame[];
  /** Every published entry, in global popularity order (rank 1 first). */
  entries: Entry[];
}

export interface CapabilityTag {
  tag: string;
  label: Localized;
}

export interface CategoryFrame {
  id: CategoryId;
  name: Localized;
  /** Package names in frame order: global order filtered to this category, then editorial pins applied. */
  entries: string[];
}

export interface Entry {
  packageName: string;
  slug: string;
  /** 1-based position in the global popularity order. */
  rank: number;
  name: Localized;
  publisher: string;
  category: CategoryId;
  /** Matched by on-device search together with name, summary, and description. */
  searchTags: string[];
  summary: Localized;
  /** Paragraphs. */
  description: Localized<string[]>;
  compatNotes: Localized<string[]> | null;
  /** Detail's Upstream page action. */
  homepageUrl: string;
  rehostMode: RehostMode;
  /** Set if and only if `rehostMode === 'landing'`. */
  landing: LandingInfo | null;
  /** Active publisher cert SHA-256 fingerprints; empty for landing entries. */
  allowedSigningCerts: string[];
  /** Tags from `capabilityTags`. */
  capabilities: string[];
  /** Composited live by the client; never pre-baked. */
  tile: Tile;
  /** Null makes Detail fall back to the tile backdrop wash. */
  featureUrl: string | null;
  screenshots: Screenshot[];
  /** Latest approved release. Null only for landing entries with no known release. */
  release: Release | null;
  /** Up to the last 5 approved releases, newest first; `changelogs[0]` is `release`. */
  changelogs: Changelog[];
}

export interface LandingInfo {
  reason: Localized;
  url: string;
}

export interface Tile {
  iconUrl: string;
  backdropColors: [string] | [string, string];
  backdropAngle: number;
  iconScale: number;
}

export interface Screenshot {
  thumbUrl: string;
  fullUrl: string;
  width: number;
  height: number;
}

export interface Release {
  /** Null only for metadata-only Landing Page releases. */
  versionCode: number | null;
  versionName: string;
  releasedAt: string;
  variantsAreUserChoice: boolean;
  /** Empty for landing entries. */
  variants: Variant[];
}

export interface Variant {
  sha256: string;
  sizeBytes: number;
  abis: string[];
  minSdk: number;
  targetSdk: number;
  /** Present when `variantsAreUserChoice`; shown in the variant dialog. */
  label: Localized | null;
  note: Localized | null;
  /** Used instead of the tShop URL when Privacy Mode is on. */
  upstreamUrl: string;
}

export interface Changelog {
  versionCode: number | null;
  versionName: string;
  releasedAt: string;
  /** Bullets. */
  notes: Localized<string[]>;
}

export interface ClientRelease {
  versionCode: number;
  versionName: string;
  releasedAt: string;
  notes: Localized<string[]>;
  sha256: string;
  sizeBytes: number;
  minSdk: number;
  upstreamUrl: string;
}
