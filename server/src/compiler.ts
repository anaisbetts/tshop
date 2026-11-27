import {
  DEV_KEY_ID,
  DEV_PRIVATE_SEED_BASE64,
  sha256Hex,
  signPointer,
  type UnsignedPointer,
} from "./signing";
import type {
  CapabilityTag,
  Catalog,
  CategoryFrame,
  CategoryId,
  Changelog,
  ClientRelease,
  Entry,
  LandingInfo,
  Localized,
  Pointer,
  RehostMode,
  Release,
  Screenshot,
  Variant,
} from "./types";

const DEFAULT_APK_BASE_URL = "/apk";
const DEFAULT_MIN_CLIENT_VERSION_CODE = 1;
const DEFAULT_STATS_URL = "https://stats.tshop.local/";
const MAX_CHANGELOGS_PER_ENTRY = 5;
const CATEGORY_ORDER: readonly CategoryId[] = [
  "Emulators",
  "Frontends",
  "Games",
  "Utilities",
];
const ART_FILENAME_PATTERN = /^[a-f0-9]{64}\.(webp|png|jpg|jpeg)$/;
const SHA256_HEX_PATTERN = /^[a-f0-9]{64}$/;

const SELECT_PUBLISHED_APPS_SQL = `SELECT
  package_name,
  slug,
  rehost_mode,
  landing_reason_i18n,
  landing_url,
  name_i18n,
  summary_i18n,
  description_i18n,
  compat_notes_i18n,
  publisher,
  homepage_url,
  primary_category,
  search_tags,
  capabilities,
  backdrop_colors,
  backdrop_angle,
  icon_scale,
  seed_rank,
  editorial_pin,
  approved_release_id
FROM apps
WHERE status = 'published'
ORDER BY
  CASE WHEN editorial_pin IS NULL THEN 1 ELSE 0 END ASC,
  editorial_pin ASC,
  seed_rank ASC,
  slug ASC`;

const SELECT_ACTIVE_CERTS_SQL = `SELECT package_name, sha256_fingerprint
FROM app_certs
WHERE active = 1
ORDER BY id ASC`;

const SELECT_CAPABILITY_TAGS_SQL = `SELECT tag, label_i18n
FROM capability_tags
ORDER BY tag ASC`;

const SELECT_RELEASES_SQL = `SELECT
  id,
  package_name,
  version_code,
  version_name,
  released_at,
  changelog_i18n,
  state,
  variants_are_user_choice
FROM releases
WHERE state IN ('approved', 'superseded')
ORDER BY
  package_name ASC,
  CASE WHEN version_code IS NULL THEN 1 ELSE 0 END ASC,
  version_code DESC,
  released_at DESC,
  id DESC`;

const SELECT_VARIANTS_SQL = `SELECT
  release_id,
  sha256,
  size_bytes,
  abis,
  min_sdk,
  target_sdk,
  label_i18n,
  note_i18n,
  upstream_url
FROM release_variants
ORDER BY id ASC`;

const SELECT_ASSETS_SQL = `SELECT
  package_name,
  kind,
  sort_order,
  webp_sha256,
  thumb_webp_sha256,
  width,
  height
FROM app_assets
ORDER BY sort_order ASC, id ASC`;

const SELECT_CURRENT_CLIENT_RELEASE_SQL = `SELECT
  version_code,
  version_name,
  released_at,
  changelog_i18n,
  sha256,
  size_bytes,
  min_sdk,
  upstream_url
FROM client_releases
WHERE is_current = 1
ORDER BY version_code DESC
LIMIT 1`;

export type SqlParam = string | number | bigint | Uint8Array | null;

export interface CatalogQueryDb {
  all<T>(sql: string, params?: readonly SqlParam[]): T[] | Promise<T[]>;
}

export interface CompileCatalogOptions {
  generatedAt?: string;
  apkBaseUrl?: string;
}

export interface BuildSignedArtifactsOptions {
  keyId?: string;
  privateSeedBase64?: string;
  minClientVersionCode?: number;
  statsUrl?: string;
}

export interface SignedArtifacts {
  catalogBytes: Uint8Array;
  catalogSha256: string;
  catalogUrl: string;
  pointer: Pointer;
  pointerJson: string;
}

type AssetKind = "icon" | "feature" | "screenshot";

interface AppRow {
  package_name: string;
  slug: string;
  rehost_mode: RehostMode;
  landing_reason_i18n: string | null;
  landing_url: string | null;
  name_i18n: string;
  summary_i18n: string;
  description_i18n: string;
  compat_notes_i18n: string | null;
  publisher: string;
  homepage_url: string;
  primary_category: CategoryId;
  search_tags: string;
  capabilities: string;
  backdrop_colors: string;
  backdrop_angle: number;
  icon_scale: number;
  seed_rank: number;
  editorial_pin: number | null;
  approved_release_id: number | null;
}

interface CertRow {
  package_name: string;
  sha256_fingerprint: string;
}

interface CapabilityTagRow {
  tag: string;
  label_i18n: string;
}

interface ReleaseRow {
  id: number;
  package_name: string;
  version_code: number | null;
  version_name: string;
  released_at: string;
  changelog_i18n: string | null;
  state: string;
  variants_are_user_choice: number;
}

interface VariantRow {
  release_id: number;
  sha256: string;
  size_bytes: number;
  abis: string;
  min_sdk: number;
  target_sdk: number;
  label_i18n: string | null;
  note_i18n: string | null;
  upstream_url: string;
}

interface AssetRow {
  package_name: string;
  kind: AssetKind;
  sort_order: number;
  webp_sha256: string;
  thumb_webp_sha256: string | null;
  width: number;
  height: number;
}

interface ClientReleaseRow {
  version_code: number;
  version_name: string;
  released_at: string;
  changelog_i18n: string;
  sha256: string;
  size_bytes: number;
  min_sdk: number;
  upstream_url: string;
}

interface GroupedAssets {
  iconUrl: string | null;
  featureUrl: string | null;
  screenshots: Screenshot[];
}

export async function compileCatalog(
  db: CatalogQueryDb,
  options: CompileCatalogOptions = {},
): Promise<Catalog> {
  const generatedAt = options.generatedAt ?? new Date().toISOString();
  const apkBaseUrl = options.apkBaseUrl ?? DEFAULT_APK_BASE_URL;

  const [
    appRows,
    certRows,
    capabilityTagRows,
    releaseRows,
    variantRows,
    assetRows,
    clientReleaseRows,
  ] = await Promise.all([
    db.all<AppRow>(SELECT_PUBLISHED_APPS_SQL),
    db.all<CertRow>(SELECT_ACTIVE_CERTS_SQL),
    db.all<CapabilityTagRow>(SELECT_CAPABILITY_TAGS_SQL),
    db.all<ReleaseRow>(SELECT_RELEASES_SQL),
    db.all<VariantRow>(SELECT_VARIANTS_SQL),
    db.all<AssetRow>(SELECT_ASSETS_SQL),
    db.all<ClientReleaseRow>(SELECT_CURRENT_CLIENT_RELEASE_SQL),
  ]);

  const certsByPackage = groupCertsByPackage(certRows);
  const releasesByPackage = groupReleasesByPackage(releaseRows);
  const releasesById = indexReleasesById(releaseRows);
  const variantsByReleaseId = groupVariantsByReleaseId(variantRows);
  const assetsByPackage = groupAssetsByPackage(assetRows);

  const sortedApps = [...appRows].sort(compareAppRows);
  const entries = sortedApps.map((app, index) =>
    buildEntry(
      app,
      index + 1,
      certsByPackage.get(app.package_name) ?? [],
      releasesById,
      releasesByPackage.get(app.package_name) ?? [],
      variantsByReleaseId,
      assetsByPackage.get(app.package_name),
    ),
  );

  const capabilityTags: CapabilityTag[] = capabilityTagRows.map((row) => ({
    tag: row.tag,
    label: parseJson<Localized>(row.label_i18n, `capability_tags.${row.tag}`),
  }));

  const categories = buildCategoryFrames(entries);
  const client = buildClientRelease(clientReleaseRows[0] ?? null);

  return {
    schemaVersion: 1,
    generatedAt,
    apkBaseUrl,
    client,
    capabilityTags,
    categories,
    entries,
  };
}

export function buildSignedArtifacts(
  catalog: Catalog,
  options: BuildSignedArtifactsOptions = {},
): SignedArtifacts {
  const keyId = options.keyId ?? DEV_KEY_ID;
  const privateSeedBase64 =
    options.privateSeedBase64 ?? DEV_PRIVATE_SEED_BASE64;
  const minClientVersionCode =
    options.minClientVersionCode ?? DEFAULT_MIN_CLIENT_VERSION_CODE;
  const statsUrl = options.statsUrl ?? DEFAULT_STATS_URL;

  const catalogJson = JSON.stringify(catalog);
  const catalogBytes = new TextEncoder().encode(catalogJson);
  const catalogSha256 = sha256Hex(catalogBytes);
  const catalogUrl = `/catalog/catalog-${catalogSha256}.json`;

  const unsignedPointer: UnsignedPointer = {
    schemaVersion: 1,
    minClientVersionCode,
    generatedAt: catalog.generatedAt,
    keyId,
    catalogUrl,
    catalogSha256,
    catalogSize: catalogBytes.byteLength,
    statsUrl,
  };

  const pointer = signPointer(unsignedPointer, privateSeedBase64);
  const pointerJson = JSON.stringify(pointer, null, 2);

  return {
    catalogBytes,
    catalogSha256,
    catalogUrl,
    pointer,
    pointerJson,
  };
}

function buildEntry(
  app: AppRow,
  rank: number,
  activeCerts: readonly string[],
  releasesById: ReadonlyMap<number, ReleaseRow>,
  packageReleases: readonly ReleaseRow[],
  variantsByReleaseId: ReadonlyMap<number, Variant[]>,
  assets: GroupedAssets | undefined,
): Entry {
  if (assets?.iconUrl === undefined || assets.iconUrl === null) {
    throw new Error(
      `Published app "${app.package_name}" is missing an icon asset.`,
    );
  }

  const rehostMode = validateRehostMode(app.rehost_mode);
  const landing = buildLandingInfo(app, rehostMode);
  const allowedSigningCerts =
    rehostMode === "landing" ? [] : [...activeCerts];

  const approvedReleaseRow =
    app.approved_release_id === null
      ? null
      : (releasesById.get(app.approved_release_id) ?? null);

  const release = buildRelease(
    approvedReleaseRow,
    rehostMode,
    variantsByReleaseId,
  );
  const changelogs = buildChangelogs(packageReleases);

  return {
    packageName: app.package_name,
    slug: app.slug,
    rank,
    name: parseJson<Localized>(app.name_i18n, `${app.package_name}.name_i18n`),
    publisher: app.publisher,
    category: validateCategoryId(app.primary_category),
    searchTags: parseJson<string[]>(
      app.search_tags,
      `${app.package_name}.search_tags`,
    ),
    summary: parseJson<Localized>(
      app.summary_i18n,
      `${app.package_name}.summary_i18n`,
    ),
    description: parseJson<Localized<string[]>>(
      app.description_i18n,
      `${app.package_name}.description_i18n`,
    ),
    compatNotes:
      app.compat_notes_i18n === null
        ? null
        : parseJson<Localized<string[]>>(
            app.compat_notes_i18n,
            `${app.package_name}.compat_notes_i18n`,
          ),
    homepageUrl: app.homepage_url,
    rehostMode,
    landing,
    allowedSigningCerts,
    capabilities: parseJson<string[]>(
      app.capabilities,
      `${app.package_name}.capabilities`,
    ),
    tile: {
      iconUrl: assets.iconUrl,
      backdropColors: parseBackdropColors(
        app.backdrop_colors,
        app.package_name,
      ),
      backdropAngle: app.backdrop_angle,
      iconScale: app.icon_scale,
    },
    featureUrl: assets.featureUrl,
    screenshots: assets.screenshots,
    release,
    changelogs,
  };
}

function buildLandingInfo(
  app: AppRow,
  rehostMode: RehostMode,
): LandingInfo | null {
  switch (rehostMode) {
    case "rehost":
      return null;
    case "landing": {
      if (app.landing_reason_i18n === null || app.landing_url === null) {
        throw new Error(
          `Landing app "${app.package_name}" is missing landing_reason_i18n or landing_url.`,
        );
      }
      return {
        reason: parseJson<Localized>(
          app.landing_reason_i18n,
          `${app.package_name}.landing_reason_i18n`,
        ),
        url: app.landing_url,
      };
    }
    default:
      return assertNever(rehostMode);
  }
}

function buildRelease(
  row: ReleaseRow | null,
  rehostMode: RehostMode,
  variantsByReleaseId: ReadonlyMap<number, Variant[]>,
): Release | null {
  if (row === null) {
    return null;
  }

  const variants =
    rehostMode === "landing"
      ? []
      : [...(variantsByReleaseId.get(row.id) ?? [])];

  return {
    versionCode: row.version_code,
    versionName: row.version_name,
    releasedAt: row.released_at,
    variantsAreUserChoice: row.variants_are_user_choice === 1,
    variants,
  };
}

function buildChangelogs(packageReleases: readonly ReleaseRow[]): Changelog[] {
  return [...packageReleases]
    .sort(compareReleaseRowsDesc)
    .slice(0, MAX_CHANGELOGS_PER_ENTRY)
    .map((row) => ({
      versionCode: row.version_code,
      versionName: row.version_name,
      releasedAt: row.released_at,
      notes:
        row.changelog_i18n === null
          ? { en: [] }
          : parseJson<Localized<string[]>>(
              row.changelog_i18n,
              `releases.${row.id}.changelog_i18n`,
            ),
    }));
}

function buildCategoryFrames(entries: readonly Entry[]): CategoryFrame[] {
  const frames: CategoryFrame[] = [];
  for (const categoryId of CATEGORY_ORDER) {
    const matching = entries
      .filter((entry) => entry.category === categoryId)
      .map((entry) => entry.packageName);
    if (matching.length > 0) {
      frames.push({
        id: categoryId,
        name: { en: categoryId },
        entries: matching,
      });
    }
  }
  return frames;
}

function buildClientRelease(
  row: ClientReleaseRow | null,
): ClientRelease | null {
  if (row === null) {
    return null;
  }
  return {
    versionCode: row.version_code,
    versionName: row.version_name,
    releasedAt: row.released_at,
    notes: parseJson<Localized<string[]>>(
      row.changelog_i18n,
      `client_releases.${row.version_code}.changelog_i18n`,
    ),
    sha256: row.sha256,
    sizeBytes: row.size_bytes,
    minSdk: row.min_sdk,
    upstreamUrl: row.upstream_url,
  };
}

function groupCertsByPackage(
  rows: readonly CertRow[],
): Map<string, string[]> {
  const map = new Map<string, string[]>();
  for (const row of rows) {
    const list = map.get(row.package_name);
    if (list) {
      list.push(row.sha256_fingerprint);
    } else {
      map.set(row.package_name, [row.sha256_fingerprint]);
    }
  }
  return map;
}

function groupReleasesByPackage(
  rows: readonly ReleaseRow[],
): Map<string, ReleaseRow[]> {
  const map = new Map<string, ReleaseRow[]>();
  for (const row of rows) {
    const list = map.get(row.package_name);
    if (list) {
      list.push(row);
    } else {
      map.set(row.package_name, [row]);
    }
  }
  return map;
}

function indexReleasesById(
  rows: readonly ReleaseRow[],
): Map<number, ReleaseRow> {
  const map = new Map<number, ReleaseRow>();
  for (const row of rows) {
    map.set(row.id, row);
  }
  return map;
}

function groupVariantsByReleaseId(
  rows: readonly VariantRow[],
): Map<number, Variant[]> {
  const map = new Map<number, Variant[]>();
  for (const row of rows) {
    const variant: Variant = {
      sha256: row.sha256,
      sizeBytes: row.size_bytes,
      abis: parseJson<string[]>(row.abis, `release_variants.${row.sha256}.abis`),
      minSdk: row.min_sdk,
      targetSdk: row.target_sdk,
      label:
        row.label_i18n === null
          ? null
          : parseJson<Localized>(
              row.label_i18n,
              `release_variants.${row.sha256}.label_i18n`,
            ),
      note:
        row.note_i18n === null
          ? null
          : parseJson<Localized>(
              row.note_i18n,
              `release_variants.${row.sha256}.note_i18n`,
            ),
      upstreamUrl: row.upstream_url,
    };
    const list = map.get(row.release_id);
    if (list) {
      list.push(variant);
    } else {
      map.set(row.release_id, [variant]);
    }
  }
  return map;
}

function groupAssetsByPackage(
  rows: readonly AssetRow[],
): Map<string, GroupedAssets> {
  const map = new Map<string, GroupedAssets>();
  const sorted = [...rows].sort((a, b) => a.sort_order - b.sort_order);

  for (const row of sorted) {
    let grouped = map.get(row.package_name);
    if (!grouped) {
      grouped = { iconUrl: null, featureUrl: null, screenshots: [] };
      map.set(row.package_name, grouped);
    }

    const fullUrl = formatArtUrl(row.webp_sha256);
    switch (row.kind) {
      case "icon":
        if (grouped.iconUrl === null) {
          grouped.iconUrl = fullUrl;
        }
        break;
      case "feature":
        if (grouped.featureUrl === null) {
          grouped.featureUrl = fullUrl;
        }
        break;
      case "screenshot": {
        const thumbUrl =
          row.thumb_webp_sha256 === null
            ? fullUrl
            : formatArtUrl(row.thumb_webp_sha256);
        grouped.screenshots.push({
          thumbUrl,
          fullUrl,
          width: row.width,
          height: row.height,
        });
        break;
      }
      default:
        assertNever(row.kind);
    }
  }

  return map;
}

function formatArtUrl(assetRef: string): string {
  if (ART_FILENAME_PATTERN.test(assetRef)) {
    return `/art/${assetRef}`;
  }
  if (SHA256_HEX_PATTERN.test(assetRef)) {
    return `/art/${assetRef}.webp`;
  }
  throw new Error(
    `Invalid app_assets reference "${assetRef}": expected 64-char lowercase hex sha256 or <sha256>.(webp|png|jpg|jpeg).`,
  );
}

function compareAppRows(a: AppRow, b: AppRow): number {
  if (a.editorial_pin !== null && b.editorial_pin === null) {
    return -1;
  }
  if (a.editorial_pin === null && b.editorial_pin !== null) {
    return 1;
  }
  if (
    a.editorial_pin !== null &&
    b.editorial_pin !== null &&
    a.editorial_pin !== b.editorial_pin
  ) {
    return a.editorial_pin - b.editorial_pin;
  }
  if (a.seed_rank !== b.seed_rank) {
    return a.seed_rank - b.seed_rank;
  }
  return a.slug.localeCompare(b.slug);
}

function compareReleaseRowsDesc(a: ReleaseRow, b: ReleaseRow): number {
  if (a.version_code !== null && b.version_code === null) {
    return -1;
  }
  if (a.version_code === null && b.version_code !== null) {
    return 1;
  }
  if (
    a.version_code !== null &&
    b.version_code !== null &&
    a.version_code !== b.version_code
  ) {
    return b.version_code - a.version_code;
  }
  if (a.released_at !== b.released_at) {
    return b.released_at.localeCompare(a.released_at);
  }
  return b.id - a.id;
}

function parseBackdropColors(
  raw: string,
  packageName: string,
): [string] | [string, string] {
  const parsed = parseJson<string[]>(raw, `${packageName}.backdrop_colors`);
  if (parsed.length === 1) {
    return [parsed[0]];
  }
  if (parsed.length === 2) {
    return [parsed[0], parsed[1]];
  }
  throw new Error(
    `Invalid backdrop_colors for "${packageName}": expected 1 or 2 colors, got ${parsed.length}.`,
  );
}

function validateCategoryId(value: CategoryId): CategoryId {
  switch (value) {
    case "Emulators":
    case "Frontends":
    case "Games":
    case "Utilities":
      return value;
    default:
      return assertNever(value);
  }
}

function validateRehostMode(value: RehostMode): RehostMode {
  switch (value) {
    case "rehost":
    case "landing":
      return value;
    default:
      return assertNever(value);
  }
}

function parseJson<T>(raw: string, context: string): T {
  try {
    return JSON.parse(raw) as T;
  } catch (error) {
    const message = error instanceof Error ? error.message : String(error);
    throw new Error(`Failed to parse JSON for ${context}: ${message}`);
  }
}

function assertNever(value: never): never {
  throw new Error(`Unexpected value: ${String(value)}`);
}
