import { Database } from "bun:sqlite";
import { existsSync, mkdirSync, readdirSync, readFileSync, writeFileSync } from "node:fs";
import { join, resolve } from "node:path";
import { deflateSync } from "node:zlib";
import {
  buildSignedArtifacts,
  compileCatalog,
  type CatalogQueryDb,
  type SqlParam,
} from "../src/compiler";
import { DEV_KEY_ID, sha256Hex } from "../src/signing";

const SERVER_ROOT = resolve(import.meta.dir, "..");
const SEED_CACHE_DIR = join(SERVER_ROOT, ".seed-cache");
const APK_CACHE_DIR = join(SEED_CACHE_DIR, "apks");
const ART_CACHE_DIR = join(SEED_CACHE_DIR, "art");
const OUT_CACHE_DIR = join(SEED_CACHE_DIR, "out");
const WRANGLER_D1_DIR = join(
  SERVER_ROOT,
  ".wrangler/state/v3/d1/miniflare-D1DatabaseObject",
);

const WAYFINDER_PACKAGE = "app.wayfinder";
const WAYFINDER_SLUG = "wayfinder";
const WAYFINDER_NAME = "Wayfinder";
const WAYFINDER_PUBLISHER = "Thor-Wayfinder";
const WAYFINDER_CATEGORY = "Utilities";
const WAYFINDER_HOMEPAGE = "https://github.com/Thor-Wayfinder/thor-wayfinder";
const WAYFINDER_LICENSE_SPDX = "PolyForm-Strict-1.0.0";
// Note: PolyForm Strict 1.0.0 restricts redistribution and would use 'landing'
// in production; seeded as 'rehost' locally for dev-mode download & install testing.
const WAYFINDER_REHOST_MODE = "rehost";
const WAYFINDER_CERT_SHA256 =
  "21d1272b5116449056206037600171702c6d4ad5897cf4e9be192a4cd1a2913b";
const WAYFINDER_SUMMARY =
  "Two screens, one controller — move apps, per-game controls, and quick panel for the AYN Thor.";
const WAYFINDER_DESCRIPTION = [
  "Wayfinder brings seamless dual-screen workflow tools to the AYN Thor without requiring root or Shizuku. Move or swap apps between the top and bottom displays directly from your controller using quick Hold Home shortcuts.",
  "Configure per-game control profiles, screen dimming, and hardware overlays so every emulator and Android title launches with the layout and input behaviour you expect.",
  "Includes a controller-friendly Quick panel and Keyboard & mouse deck so you can tweak brightness, audio, saturation, and text input from either screen without reaching for touch controls.",
];
const WAYFINDER_SEARCH_TAGS = [
  "thor",
  "ayn",
  "dual-screen",
  "controller",
  "utility",
  "quick-panel",
  "wayfinder",
];
const WAYFINDER_BACKDROP_COLORS = ["#1E3A5F", "#0F172A"];
const WAYFINDER_BACKDROP_ANGLE = 155;
const WAYFINDER_ICON_SCALE = 1.0;

const STABLE_RELEASE_SPEC: ReleaseSpec = {
  versionCode: 8,
  versionName: "1.4.1",
  releasedAt: "2026-10-02T08:27:25Z",
  upstreamUrl:
    "https://github.com/Thor-Wayfinder/thor-wayfinder/releases/download/v1.4.1/wayfinder-1.4.1.apk",
  sha256: "ac3061f83dfdd17e4f6ad6e595789c30c35f1fb5f66df16fb37840f6748138b5",
  minSdk: 30,
  targetSdk: 34,
  changelog: [
    "Fixed Backspace at start of text fields closing Wayfinder",
    "Fixed cursor placement when editing filled text fields",
    "Fixed colour saturation resetting to 110% after reboot",
  ],
};

const BETA_RELEASE_SPEC: ReleaseSpec = {
  versionCode: 10,
  versionName: "1.5-beta2",
  releasedAt: "2026-11-24T14:53:25Z",
  upstreamUrl:
    "https://github.com/Thor-Wayfinder/thor-wayfinder/releases/download/v1.5-beta2/wayfinder-1.5-beta2.apk",
  sha256: "06f5044423ab52164f761ffa21ae711dda54e94bd7ccc1137f68283dc3a0730c",
  minSdk: 30,
  targetSdk: 34,
  changelog: [
    "Bluetooth and USB controller handling",
    "Controller navigation for Keyboard & mouse deck",
    "Custom A/B/X/Y button colours and docked TV Quick panel",
  ],
};

const SCREENSHOT_SPECS: readonly ScreenshotSpec[] = [
  {
    id: "d19e4cc4-f3bb-48d2-b82d-f45442e1722a",
    label: "Hub & combos",
    url: "https://github.com/user-attachments/assets/d19e4cc4-f3bb-48d2-b82d-f45442e1722a",
  },
  {
    id: "cdb46e4f-8801-416a-845a-bf10fad5c8a2",
    label: "Quick panel",
    url: "https://github.com/user-attachments/assets/cdb46e4f-8801-416a-845a-bf10fad5c8a2",
  },
  {
    id: "fdbb368b-1626-4194-aa18-561e16a4c5bd",
    label: "Game controls",
    url: "https://github.com/user-attachments/assets/fdbb368b-1626-4194-aa18-561e16a4c5bd",
  },
  {
    id: "a969331a-c9a8-4cd9-90c8-7c5a96afcc0a",
    label: "Hold Home combo sheet",
    url: "https://github.com/user-attachments/assets/a969331a-c9a8-4cd9-90c8-7c5a96afcc0a",
  },
];

const ICON_SIZE = 256;
const PNG_SIGNATURE = new Uint8Array([
  0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a,
]);
const ZIP_EOCD_SIGNATURE = 0x06054b50;
const ZIP_CEN_SIGNATURE = 0x02014b50;
const APK_LIB_ABI_PATTERN = /^lib\/([^/]+)\/[^/]+$/;
const CRC32_TABLE = buildCrc32Table();

type SeedChannel = "stable" | "beta";
type ImageExtension = "png" | "jpg" | "webp";

interface ReleaseSpec {
  versionCode: number;
  versionName: string;
  releasedAt: string;
  upstreamUrl: string;
  sha256: string;
  minSdk: number;
  targetSdk: number;
  changelog: readonly string[];
}

interface PreparedRelease {
  spec: ReleaseSpec;
  state: "approved" | "superseded";
  apkPath: string;
  sizeBytes: number;
  abis: string[];
}

interface ScreenshotSpec {
  id: string;
  label: string;
  url: string;
}

interface PreparedImage {
  kind: "icon" | "screenshot";
  label: string;
  sourceUrl: string;
  rightsBasis: string;
  ext: ImageExtension;
  sha256: string;
  filename: string;
  filePath: string;
  width: number;
  height: number;
}

interface ImageDimensions {
  ext: ImageExtension;
  width: number;
  height: number;
}

async function main(): Promise<void> {
  const channel = parseSeedChannel(process.argv.slice(2));
  ensureCacheDirs();

  console.log(`Seeding local tShop storefront (channel: ${channel})...`);

  const releases = await prepareReleases(channel);
  const icon = prepareWayfinderIcon();
  const screenshots = await prepareScreenshots();

  console.log("Applying local D1 migrations...");
  runCommand(["bun", "run", "db:migrate"]);

  const catalogDbPath = findCatalogSqlitePath();
  const generatedAt = new Date().toISOString();

  console.log(`Populating local D1 catalog (${catalogDbPath})...`);
  const db = new Database(catalogDbPath);
  let artifacts: ReturnType<typeof buildSignedArtifacts>;
  let entryCount: number;
  try {
    seedCatalogDatabase(db, releases, icon, screenshots, generatedAt);
    const catalog = await compileCatalog(createSqliteCatalogDb(db), {
      generatedAt,
    });
    entryCount = catalog.entries.length;
    artifacts = buildSignedArtifacts(catalog);
    recordPublishHistory(db, generatedAt, artifacts.catalogSha256, entryCount);
    db.exec("PRAGMA wal_checkpoint(TRUNCATE);");
  } finally {
    db.close();
  }

  const catalogFileName = `catalog-${artifacts.catalogSha256}.json`;
  const catalogOutPath = join(OUT_CACHE_DIR, catalogFileName);
  const pointerOutPath = join(OUT_CACHE_DIR, "pointer.json");
  writeFileSync(catalogOutPath, artifacts.catalogBytes);
  writeFileSync(pointerOutPath, artifacts.pointerJson, "utf8");

  console.log("Uploading APKs and static assets to local Wrangler R2...");
  for (const release of releases) {
    uploadToLocalR2(
      "tshop-apks",
      `${release.spec.sha256}.apk`,
      release.apkPath,
      "application/vnd.android.package-archive",
    );
  }

  uploadToLocalR2(
    "tshop-assets",
    `public/art/${icon.filename}`,
    icon.filePath,
    imageContentType(icon.ext),
  );
  for (const shot of screenshots) {
    uploadToLocalR2(
      "tshop-assets",
      `public/art/${shot.filename}`,
      shot.filePath,
      imageContentType(shot.ext),
    );
  }
  uploadToLocalR2(
    "tshop-assets",
    `public/catalog/${catalogFileName}`,
    catalogOutPath,
    "application/json; charset=utf-8",
  );
  uploadToLocalR2(
    "tshop-assets",
    "public/pointer.json",
    pointerOutPath,
    "application/json; charset=utf-8",
  );

  const activeRelease = releases.find((r) => r.state === "approved");
  if (!activeRelease) {
    throw new Error("Expected an approved release after seeding.");
  }

  printSummary(
    channel,
    activeRelease,
    releases,
    icon,
    screenshots,
    artifacts,
  );
}

async function prepareReleases(
  channel: SeedChannel,
): Promise<PreparedRelease[]> {
  switch (channel) {
    case "stable":
      return [await downloadAndInspectApk(STABLE_RELEASE_SPEC, "approved")];
    case "beta":
      return [
        await downloadAndInspectApk(STABLE_RELEASE_SPEC, "superseded"),
        await downloadAndInspectApk(BETA_RELEASE_SPEC, "approved"),
      ];
    default:
      return assertNever(channel);
  }
}

async function downloadAndInspectApk(
  spec: ReleaseSpec,
  state: "approved" | "superseded",
): Promise<PreparedRelease> {
  const apkPath = join(APK_CACHE_DIR, `wayfinder-${spec.versionName}.apk`);
  let bytes: Uint8Array;

  if (existsSync(apkPath)) {
    const cached = new Uint8Array(readFileSync(apkPath));
    if (sha256Hex(cached) === spec.sha256) {
      console.log(`Using cached APK: ${apkPath}`);
      bytes = cached;
    } else {
      console.log(`Cached APK checksum mismatch; re-downloading ${spec.versionName}...`);
      bytes = await fetchBinary(spec.upstreamUrl);
      writeFileSync(apkPath, bytes);
    }
  } else {
    console.log(`Downloading ${spec.upstreamUrl}...`);
    bytes = await fetchBinary(spec.upstreamUrl);
    writeFileSync(apkPath, bytes);
  }

  const actualSha = sha256Hex(bytes);
  if (actualSha !== spec.sha256) {
    throw new Error(
      `APK SHA-256 mismatch for ${spec.versionName}: expected ${spec.sha256}, got ${actualSha}`,
    );
  }

  const abis = inspectApkAbis(bytes);
  return {
    spec,
    state,
    apkPath,
    sizeBytes: bytes.byteLength,
    abis,
  };
}

function prepareWayfinderIcon(): PreparedImage {
  const bytes = renderWayfinderIconPng(ICON_SIZE);
  const info = parseImageMetadata(bytes, "generated Wayfinder icon");
  const sha256 = sha256Hex(bytes);
  const filename = `${sha256}.${info.ext}`;
  const filePath = join(ART_CACHE_DIR, filename);
  writeFileSync(filePath, bytes);

  return {
    kind: "icon",
    label: "Wayfinder emblem",
    sourceUrl: "generated://tshop-dev-seed/wayfinder-icon",
    rightsBasis: "Generated placeholder emblem for local dev storefront",
    ext: info.ext,
    sha256,
    filename,
    filePath,
    width: info.width,
    height: info.height,
  };
}

async function prepareScreenshots(): Promise<PreparedImage[]> {
  const prepared: PreparedImage[] = [];

  for (const spec of SCREENSHOT_SPECS) {
    const rawCachePath = join(ART_CACHE_DIR, `src-${spec.id}.bin`);
    let bytes: Uint8Array;

    if (existsSync(rawCachePath)) {
      bytes = new Uint8Array(readFileSync(rawCachePath));
    } else {
      console.log(`Downloading screenshot (${spec.label})...`);
      bytes = await fetchBinary(spec.url);
      writeFileSync(rawCachePath, bytes);
    }

    const info = parseImageMetadata(bytes, spec.label);
    const sha256 = sha256Hex(bytes);
    const filename = `${sha256}.${info.ext}`;
    const filePath = join(ART_CACHE_DIR, filename);
    if (!existsSync(filePath)) {
      writeFileSync(filePath, bytes);
    }

    prepared.push({
      kind: "screenshot",
      label: spec.label,
      sourceUrl: spec.url,
      rightsBasis: "Upstream GitHub README screenshot (Thor-Wayfinder)",
      ext: info.ext,
      sha256,
      filename,
      filePath,
      width: info.width,
      height: info.height,
    });
  }

  return prepared;
}

function seedCatalogDatabase(
  db: Database,
  releases: readonly PreparedRelease[],
  icon: PreparedImage,
  screenshots: readonly PreparedImage[],
  now: string,
): void {
  const tx = db.transaction(() => {
    db.query(
      "UPDATE apps SET approved_release_id = NULL, previous_release_id = NULL WHERE package_name = ?",
    ).run(WAYFINDER_PACKAGE);

    db.query(
      "DELETE FROM release_variants WHERE release_id IN (SELECT id FROM releases WHERE package_name = ?)",
    ).run(WAYFINDER_PACKAGE);
    db.query("DELETE FROM releases WHERE package_name = ?").run(WAYFINDER_PACKAGE);
    db.query("DELETE FROM app_assets WHERE package_name = ?").run(
      WAYFINDER_PACKAGE,
    );
    db.query("DELETE FROM app_certs WHERE package_name = ?").run(
      WAYFINDER_PACKAGE,
    );
    db.query("DELETE FROM apps WHERE package_name = ?").run(WAYFINDER_PACKAGE);

    db.query(
      `INSERT INTO apps (
        package_name,
        slug,
        status,
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
        source_type,
        source_config,
        license_spdx,
        license_notes,
        approved_release_id,
        previous_release_id,
        created_at,
        updated_at
      ) VALUES (?, ?, 'published', ?, NULL, NULL, ?, ?, ?, NULL, ?, ?, ?, ?, '[]', ?, ?, ?, 1, NULL, 'github_release', ?, ?, ?, NULL, NULL, ?, ?)`,
    ).run(
      WAYFINDER_PACKAGE,
      WAYFINDER_SLUG,
      WAYFINDER_REHOST_MODE,
      JSON.stringify({ en: WAYFINDER_NAME }),
      JSON.stringify({ en: WAYFINDER_SUMMARY }),
      JSON.stringify({ en: WAYFINDER_DESCRIPTION }),
      WAYFINDER_PUBLISHER,
      WAYFINDER_HOMEPAGE,
      WAYFINDER_CATEGORY,
      JSON.stringify(WAYFINDER_SEARCH_TAGS),
      JSON.stringify(WAYFINDER_BACKDROP_COLORS),
      WAYFINDER_BACKDROP_ANGLE,
      WAYFINDER_ICON_SCALE,
      JSON.stringify({
        repo: "Thor-Wayfinder/thor-wayfinder",
        includePrereleases: false,
      }),
      WAYFINDER_LICENSE_SPDX,
      "PolyForm Strict 1.0.0 would use landing mode in production; seeded as rehost locally for dev-mode download & install testing.",
      now,
      now,
    );

    db.query(
      `INSERT INTO app_certs (
        package_name,
        sha256_fingerprint,
        label,
        active,
        added_reason,
        added_by,
        created_at
      ) VALUES (?, ?, ?, 1, ?, 'seed-script', ?)`,
    ).run(
      WAYFINDER_PACKAGE,
      WAYFINDER_CERT_SHA256,
      "Thor-Wayfinder GitHub release key",
      "Local dev seed from official GitHub release APK",
      now,
    );

    let approvedReleaseId: number | null = null;
    let previousReleaseId: number | null = null;

    for (const release of releases) {
      const insertResult = db
        .query(
          `INSERT INTO releases (
            package_name,
            version_code,
            version_name,
            released_at,
            changelog_i18n,
            state,
            variants_are_user_choice,
            validation_report,
            quarantine_reasons,
            promoted_by,
            superseded_at,
            created_at
          ) VALUES (?, ?, ?, ?, ?, ?, 0, ?, NULL, 'seed-script', ?, ?)`,
        )
        .run(
          WAYFINDER_PACKAGE,
          release.spec.versionCode,
          release.spec.versionName,
          release.spec.releasedAt,
          JSON.stringify({ en: release.spec.changelog }),
          release.state,
          JSON.stringify({ seeded: true, abis: release.abis }),
          release.state === "superseded" ? now : null,
          now,
        );

      const releaseId = Number(insertResult.lastInsertRowid);
      if (release.state === "approved") {
        approvedReleaseId = releaseId;
      } else {
        previousReleaseId = releaseId;
      }

      db.query(
        `INSERT INTO release_variants (
          release_id,
          sha256,
          size_bytes,
          abis,
          min_sdk,
          target_sdk,
          label_i18n,
          note_i18n,
          upstream_url,
          r2_key,
          r2_present,
          r2_gc_after
        ) VALUES (?, ?, ?, ?, ?, ?, NULL, NULL, ?, ?, 1, NULL)`,
      ).run(
        releaseId,
        release.spec.sha256,
        release.sizeBytes,
        JSON.stringify(release.abis),
        release.spec.minSdk,
        release.spec.targetSdk,
        release.spec.upstreamUrl,
        `${release.spec.sha256}.apk`,
      );
    }

    db.query(
      "UPDATE apps SET approved_release_id = ?, previous_release_id = ? WHERE package_name = ?",
    ).run(approvedReleaseId, previousReleaseId, WAYFINDER_PACKAGE);

    const insertAssetStmt = db.query(
      `INSERT INTO app_assets (
        package_name,
        kind,
        sort_order,
        raw_r2_key,
        webp_sha256,
        thumb_webp_sha256,
        width,
        height,
        source_url,
        rights_basis,
        created_at
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
    );

    insertAssetStmt.run(
      WAYFINDER_PACKAGE,
      "icon",
      0,
      `raw/${icon.filename}`,
      icon.filename,
      null,
      icon.width,
      icon.height,
      icon.sourceUrl,
      icon.rightsBasis,
      now,
    );

    const featureShot = screenshots[0];
    if (featureShot) {
      insertAssetStmt.run(
        WAYFINDER_PACKAGE,
        "feature",
        0,
        `raw/${featureShot.filename}`,
        featureShot.filename,
        null,
        featureShot.width,
        featureShot.height,
        featureShot.sourceUrl,
        featureShot.rightsBasis,
        now,
      );
    }

    for (let index = 0; index < screenshots.length; index++) {
      const shot = screenshots[index];
      insertAssetStmt.run(
        WAYFINDER_PACKAGE,
        "screenshot",
        index,
        `raw/${shot.filename}`,
        shot.filename,
        shot.filename,
        shot.width,
        shot.height,
        shot.sourceUrl,
        shot.rightsBasis,
        now,
      );
    }
  });

  tx();
}

function recordPublishHistory(
  db: Database,
  generatedAt: string,
  catalogSha256: string,
  entryCount: number,
): void {
  db.query(
    `INSERT INTO publish_history (
      generated_at,
      schema_version,
      min_client_version_code,
      key_id,
      catalog_sha256,
      pages_deployment_id,
      apk_base_url,
      entry_count,
      trigger,
      created_at
    ) VALUES (?, 1, 1, ?, ?, 'local-seed', '/apk', ?, 'seed-script', ?)`,
  ).run(generatedAt, DEV_KEY_ID, catalogSha256, entryCount, generatedAt);
}

function createSqliteCatalogDb(db: Database): CatalogQueryDb {
  return {
    all<T>(sql: string, params: readonly SqlParam[] = []): T[] {
      const stmt = db.query(sql);
      return stmt.all(...(params as Parameters<typeof stmt.all>)) as T[];
    },
  };
}

function findCatalogSqlitePath(): string {
  if (!existsSync(WRANGLER_D1_DIR)) {
    throw new Error(
      `Local Wrangler D1 directory not found at ${WRANGLER_D1_DIR}.`,
    );
  }

  const candidates = readdirSync(WRANGLER_D1_DIR)
    .filter((name) => name.endsWith(".sqlite") && name !== "metadata.sqlite")
    .map((name) => join(WRANGLER_D1_DIR, name));

  for (const candidate of candidates) {
    const db = new Database(candidate, { readonly: true });
    try {
      const row = db
        .query(
          "SELECT name FROM sqlite_master WHERE type = 'table' AND name = 'apps'",
        )
        .get();
      if (row !== null) {
        return candidate;
      }
    } finally {
      db.close();
    }
  }

  throw new Error(
    `Could not locate tshop-catalog SQLite database in ${WRANGLER_D1_DIR}.`,
  );
}

function uploadToLocalR2(
  bucket: string,
  key: string,
  filePath: string,
  contentType: string,
): void {
  runCommand([
    "bunx",
    "wrangler",
    "r2",
    "object",
    "put",
    `${bucket}/${key}`,
    "--file",
    filePath,
    "--content-type",
    contentType,
    "--local",
  ]);
}

function runCommand(cmd: string[]): void {
  const result = Bun.spawnSync(cmd, {
    cwd: SERVER_ROOT,
    stdout: "pipe",
    stderr: "pipe",
  });
  if (result.exitCode !== 0) {
    const stdout = new TextDecoder().decode(result.stdout).trim();
    const stderr = new TextDecoder().decode(result.stderr).trim();
    throw new Error(
      `Command failed (${result.exitCode}): ${cmd.join(" ")}\n${stdout}\n${stderr}`,
    );
  }
}

async function fetchBinary(url: string): Promise<Uint8Array> {
  const response = await fetch(url, {
    redirect: "follow",
    headers: {
      "User-Agent": "tShop-Dev-Seed/1.0",
    },
  });
  if (!response.ok) {
    throw new Error(`HTTP ${response.status} fetching ${url}`);
  }
  return new Uint8Array(await response.arrayBuffer());
}

function inspectApkAbis(apkBytes: Uint8Array): string[] {
  const view = new DataView(
    apkBytes.buffer,
    apkBytes.byteOffset,
    apkBytes.byteLength,
  );
  const minEocdOffset = Math.max(0, apkBytes.byteLength - 65557);
  let eocdOffset = -1;

  for (let offset = apkBytes.byteLength - 22; offset >= minEocdOffset; offset--) {
    if (view.getUint32(offset, true) === ZIP_EOCD_SIGNATURE) {
      eocdOffset = offset;
      break;
    }
  }

  if (eocdOffset === -1) {
    throw new Error("Invalid APK/ZIP archive: End of Central Directory not found.");
  }

  const totalEntries = view.getUint16(eocdOffset + 10, true);
  const centralDirOffset = view.getUint32(eocdOffset + 16, true);
  const decoder = new TextDecoder();
  const abis = new Set<string>();

  let pos = centralDirOffset;
  for (let i = 0; i < totalEntries; i++) {
    if (pos + 46 > apkBytes.byteLength) {
      break;
    }
    if (view.getUint32(pos, true) !== ZIP_CEN_SIGNATURE) {
      throw new Error("Invalid APK/ZIP archive: corrupt Central Directory entry.");
    }
    const nameLen = view.getUint16(pos + 28, true);
    const extraLen = view.getUint16(pos + 30, true);
    const commentLen = view.getUint16(pos + 32, true);
    const name = decoder.decode(apkBytes.subarray(pos + 46, pos + 46 + nameLen));
    const match = APK_LIB_ABI_PATTERN.exec(name);
    if (match !== null) {
      abis.add(match[1]);
    }
    pos += 46 + nameLen + extraLen + commentLen;
  }

  return [...abis].sort();
}

function parseImageMetadata(bytes: Uint8Array, label: string): ImageDimensions {
  const ext = detectImageExtension(bytes, label);
  switch (ext) {
    case "png":
      return { ext, ...parsePngDimensions(bytes, label) };
    case "jpg":
      return { ext, ...parseJpegDimensions(bytes, label) };
    case "webp":
      return { ext, ...parseWebpDimensions(bytes, label) };
    default:
      return assertNever(ext);
  }
}

function detectImageExtension(bytes: Uint8Array, label: string): ImageExtension {
  if (
    bytes.byteLength >= 8 &&
    PNG_SIGNATURE.every((byte, idx) => bytes[idx] === byte)
  ) {
    return "png";
  }
  if (bytes.byteLength >= 2 && bytes[0] === 0xff && bytes[1] === 0xd8) {
    return "jpg";
  }
  if (
    bytes.byteLength >= 12 &&
    bytes[0] === 0x52 &&
    bytes[1] === 0x49 &&
    bytes[2] === 0x46 &&
    bytes[3] === 0x46 &&
    bytes[8] === 0x57 &&
    bytes[9] === 0x45 &&
    bytes[10] === 0x42 &&
    bytes[11] === 0x50
  ) {
    return "webp";
  }
  throw new Error(`Unsupported or unrecognized image format for "${label}".`);
}

function parsePngDimensions(
  bytes: Uint8Array,
  label: string,
): { width: number; height: number } {
  if (bytes.byteLength < 24) {
    throw new Error(`Truncated PNG header for "${label}".`);
  }
  const view = new DataView(bytes.buffer, bytes.byteOffset, bytes.byteLength);
  const chunkType = String.fromCharCode(
    bytes[12],
    bytes[13],
    bytes[14],
    bytes[15],
  );
  if (chunkType !== "IHDR") {
    throw new Error(`Expected PNG IHDR chunk for "${label}", found "${chunkType}".`);
  }
  return {
    width: view.getUint32(16, false),
    height: view.getUint32(20, false),
  };
}

function parseJpegDimensions(
  bytes: Uint8Array,
  label: string,
): { width: number; height: number } {
  const view = new DataView(bytes.buffer, bytes.byteOffset, bytes.byteLength);
  let pos = 2;

  while (pos < bytes.byteLength) {
    if (bytes[pos] !== 0xff) {
      throw new Error(`Malformed JPEG marker stream for "${label}".`);
    }
    while (pos < bytes.byteLength && bytes[pos] === 0xff) {
      pos++;
    }
    if (pos >= bytes.byteLength) {
      break;
    }

    const marker = bytes[pos++];
    if (marker === 0xd9 || marker === 0xda) {
      break;
    }
    if (marker === 0x01 || (marker >= 0xd0 && marker <= 0xd7)) {
      continue;
    }
    if (pos + 2 > bytes.byteLength) {
      break;
    }

    const segmentLength = view.getUint16(pos, false);
    if (isJpegSofMarker(marker) && pos + 7 <= bytes.byteLength) {
      return {
        height: view.getUint16(pos + 3, false),
        width: view.getUint16(pos + 5, false),
      };
    }
    pos += segmentLength;
  }

  throw new Error(`Could not find JPEG SOF frame dimensions for "${label}".`);
}

function isJpegSofMarker(marker: number): boolean {
  return (
    (marker >= 0xc0 && marker <= 0xc3) ||
    (marker >= 0xc5 && marker <= 0xc7) ||
    (marker >= 0xc9 && marker <= 0xcb) ||
    (marker >= 0xcd && marker <= 0xcf)
  );
}

function parseWebpDimensions(
  bytes: Uint8Array,
  label: string,
): { width: number; height: number } {
  if (bytes.byteLength < 30) {
    throw new Error(`Truncated WebP header for "${label}".`);
  }
  const view = new DataView(bytes.buffer, bytes.byteOffset, bytes.byteLength);
  const fourcc = String.fromCharCode(
    bytes[12],
    bytes[13],
    bytes[14],
    bytes[15],
  );

  if (fourcc === "VP8X") {
    const width = (bytes[24] | (bytes[25] << 8) | (bytes[26] << 16)) + 1;
    const height = (bytes[27] | (bytes[28] << 8) | (bytes[29] << 16)) + 1;
    return { width, height };
  }

  if (fourcc === "VP8L") {
    if (bytes[20] !== 0x2f) {
      throw new Error(`Invalid WebP VP8L signature for "${label}".`);
    }
    const bits = view.getUint32(21, true);
    return {
      width: (bits & 0x3fff) + 1,
      height: ((bits >> 14) & 0x3fff) + 1,
    };
  }

  if (fourcc === "VP8 ") {
    if (bytes[23] !== 0x9d || bytes[24] !== 0x01 || bytes[25] !== 0x2a) {
      throw new Error(`Invalid WebP VP8 keyframe header for "${label}".`);
    }
    return {
      width: view.getUint16(26, true) & 0x3fff,
      height: view.getUint16(28, true) & 0x3fff,
    };
  }

  throw new Error(`Unsupported WebP chunk "${fourcc}" for "${label}".`);
}

function renderWayfinderIconPng(size: number): Uint8Array {
  const rgba = new Uint8Array(size * size * 4);
  const half = size / 2;

  for (let y = 0; y < size; y++) {
    for (let x = 0; x < size; x++) {
      const nx = (x + 0.5 - half) / half;
      const ny = (y + 0.5 - half) / half;
      const [r, g, b, a] = sampleWayfinderEmblem(nx, ny);
      const offset = (y * size + x) * 4;
      rgba[offset] = r;
      rgba[offset + 1] = g;
      rgba[offset + 2] = b;
      rgba[offset + 3] = a;
    }
  }

  return encodeRgbaPng(size, size, rgba);
}

function sampleWayfinderEmblem(
  nx: number,
  ny: number,
): [number, number, number, number] {
  const pixelWidth = 2 / ICON_SIZE;
  let r = 0;
  let g = 0;
  let b = 0;
  let a = 0;

  // Top display frame (dual-screen motif)
  const topScreen = sdRoundedBox(nx, ny + 0.42, 0.56, 0.25, 0.08);
  const topBorder = Math.abs(topScreen) - 0.032;
  const topFillAlpha = smoothstep(pixelWidth, -pixelWidth, topScreen) * 0.2;
  [r, g, b, a] = blendOver(r, g, b, a, 56, 189, 248, topFillAlpha);
  const topStrokeAlpha = smoothstep(pixelWidth, -pixelWidth, topBorder) * 0.9;
  [r, g, b, a] = blendOver(r, g, b, a, 125, 211, 252, topStrokeAlpha);

  // Bottom display frame
  const bottomScreen = sdRoundedBox(nx, ny - 0.42, 0.46, 0.22, 0.07);
  const bottomBorder = Math.abs(bottomScreen) - 0.032;
  const bottomFillAlpha =
    smoothstep(pixelWidth, -pixelWidth, bottomScreen) * 0.16;
  [r, g, b, a] = blendOver(r, g, b, a, 56, 189, 248, bottomFillAlpha);
  const bottomStrokeAlpha =
    smoothstep(pixelWidth, -pixelWidth, bottomBorder) * 0.78;
  [r, g, b, a] = blendOver(r, g, b, a, 125, 211, 252, bottomStrokeAlpha);

  // Compass ring centered between both screens
  const radius = Math.hypot(nx, ny);
  const badgeDisc = radius - 0.38;
  const badgeAlpha = smoothstep(pixelWidth, -pixelWidth, badgeDisc) * 0.94;
  [r, g, b, a] = blendOver(r, g, b, a, 15, 23, 42, badgeAlpha);

  const ring = Math.abs(radius - 0.34) - 0.028;
  const ringAlpha = smoothstep(pixelWidth, -pixelWidth, ring);
  [r, g, b, a] = blendOver(r, g, b, a, 226, 232, 240, ringAlpha);

  // Tilted compass diamond needle (north cyan, south crisp white)
  const cos = Math.cos(Math.PI / 4);
  const sin = Math.sin(Math.PI / 4);
  const rx = nx * cos - ny * sin;
  const ry = nx * sin + ny * cos;
  const needle = Math.abs(rx) / 0.11 + Math.abs(ry) / 0.27 - 1;
  const needleAlpha = smoothstep(pixelWidth * 4, -pixelWidth * 4, needle);
  if (ry < 0) {
    [r, g, b, a] = blendOver(r, g, b, a, 56, 189, 248, needleAlpha);
  } else {
    [r, g, b, a] = blendOver(r, g, b, a, 248, 250, 252, needleAlpha);
  }

  // Center pivot dot
  const pivot = radius - 0.055;
  const pivotAlpha = smoothstep(pixelWidth, -pixelWidth, pivot);
  [r, g, b, a] = blendOver(r, g, b, a, 15, 23, 42, pivotAlpha);

  return [
    Math.round(r),
    Math.round(g),
    Math.round(b),
    Math.round(Math.max(0, Math.min(1, a)) * 255),
  ];
}

function sdRoundedBox(
  px: number,
  py: number,
  halfW: number,
  halfH: number,
  radius: number,
): number {
  const qx = Math.abs(px) - halfW + radius;
  const qy = Math.abs(py) - halfH + radius;
  return (
    Math.hypot(Math.max(qx, 0), Math.max(qy, 0)) +
    Math.min(Math.max(qx, qy), 0) -
    radius
  );
}

function smoothstep(edge0: number, edge1: number, x: number): number {
  const t = Math.max(0, Math.min(1, (x - edge0) / (edge1 - edge0)));
  return t * t * (3 - 2 * t);
}

function blendOver(
  dstR: number,
  dstG: number,
  dstB: number,
  dstA: number,
  srcR: number,
  srcG: number,
  srcB: number,
  srcA: number,
): [number, number, number, number] {
  const outA = srcA + dstA * (1 - srcA);
  if (outA <= 0) {
    return [0, 0, 0, 0];
  }
  const outR = (srcR * srcA + dstR * dstA * (1 - srcA)) / outA;
  const outG = (srcG * srcA + dstG * dstA * (1 - srcA)) / outA;
  const outB = (srcB * srcA + dstB * dstA * (1 - srcA)) / outA;
  return [outR, outG, outB, outA];
}

function encodeRgbaPng(
  width: number,
  height: number,
  rgba: Uint8Array,
): Uint8Array {
  const stride = width * 4;
  const raw = new Uint8Array((stride + 1) * height);
  for (let y = 0; y < height; y++) {
    raw[y * (stride + 1)] = 0;
    raw.set(
      rgba.subarray(y * stride, (y + 1) * stride),
      y * (stride + 1) + 1,
    );
  }

  const ihdr = new Uint8Array(13);
  const ihdrView = new DataView(ihdr.buffer);
  ihdrView.setUint32(0, width, false);
  ihdrView.setUint32(4, height, false);
  ihdr[8] = 8; // bit depth
  ihdr[9] = 6; // RGBA
  ihdr[10] = 0;
  ihdr[11] = 0;
  ihdr[12] = 0;

  const idat = new Uint8Array(deflateSync(raw));
  const chunks = [
    PNG_SIGNATURE,
    pngChunk("IHDR", ihdr),
    pngChunk("IDAT", idat),
    pngChunk("IEND", new Uint8Array(0)),
  ];

  const totalLength = chunks.reduce((sum, part) => sum + part.byteLength, 0);
  const out = new Uint8Array(totalLength);
  let offset = 0;
  for (const part of chunks) {
    out.set(part, offset);
    offset += part.byteLength;
  }
  return out;
}

function pngChunk(type: string, data: Uint8Array): Uint8Array {
  const chunk = new Uint8Array(12 + data.byteLength);
  const view = new DataView(chunk.buffer);
  view.setUint32(0, data.byteLength, false);
  for (let i = 0; i < 4; i++) {
    chunk[4 + i] = type.charCodeAt(i);
  }
  chunk.set(data, 8);
  const crc = crc32(chunk.subarray(4, 8 + data.byteLength));
  view.setUint32(8 + data.byteLength, crc, false);
  return chunk;
}

function buildCrc32Table(): Uint32Array {
  const table = new Uint32Array(256);
  for (let i = 0; i < 256; i++) {
    let c = i;
    for (let bit = 0; bit < 8; bit++) {
      c = (c & 1) !== 0 ? 0xedb88320 ^ (c >>> 1) : c >>> 1;
    }
    table[i] = c >>> 0;
  }
  return table;
}

function crc32(bytes: Uint8Array): number {
  let crc = 0xffffffff;
  for (let i = 0; i < bytes.byteLength; i++) {
    crc = CRC32_TABLE[(crc ^ bytes[i]) & 0xff] ^ (crc >>> 8);
  }
  return (crc ^ 0xffffffff) >>> 0;
}

function imageContentType(ext: ImageExtension): string {
  switch (ext) {
    case "png":
      return "image/png";
    case "jpg":
      return "image/jpeg";
    case "webp":
      return "image/webp";
    default:
      return assertNever(ext);
  }
}

function parseSeedChannel(args: readonly string[]): SeedChannel {
  if (args.includes("--beta")) {
    return "beta";
  }
  return "stable";
}

function ensureCacheDirs(): void {
  mkdirSync(APK_CACHE_DIR, { recursive: true });
  mkdirSync(ART_CACHE_DIR, { recursive: true });
  mkdirSync(OUT_CACHE_DIR, { recursive: true });
}

function printSummary(
  channel: SeedChannel,
  activeRelease: PreparedRelease,
  allReleases: readonly PreparedRelease[],
  icon: PreparedImage,
  screenshots: readonly PreparedImage[],
  artifacts: ReturnType<typeof buildSignedArtifacts>,
): void {
  const abiLabel =
    activeRelease.abis.length === 0
      ? "universal (no native lib/ entries)"
      : activeRelease.abis.join(", ");

  console.log("");
  console.log("=== tShop Local Dev Seed Complete ===");
  console.log(`Channel:        ${channel}`);
  console.log(
    `Active release: ${WAYFINDER_NAME} ${activeRelease.spec.versionName} (versionCode ${activeRelease.spec.versionCode})`,
  );
  console.log(`Seeded history: ${allReleases.map((r) => `${r.spec.versionName} (${r.state})`).join(", ")}`);
  console.log(`APK SHA-256:    ${activeRelease.spec.sha256}`);
  console.log(`APK size:       ${activeRelease.sizeBytes} bytes`);
  console.log(`APK ABIs:       ${abiLabel}`);
  console.log(`Icon art:       /art/${icon.filename} (${icon.width}x${icon.height})`);
  for (const shot of screenshots) {
    console.log(
      `Screenshot:     /art/${shot.filename} (${shot.width}x${shot.height}, ${shot.label})`,
    );
  }
  console.log(`Catalog SHA256: ${artifacts.catalogSha256}`);
  console.log(`Catalog URL:    ${artifacts.catalogUrl} (${artifacts.catalogBytes.byteLength} bytes)`);
  console.log(`Pointer URL:    http://localhost:8787/pointer.json (keyId: ${artifacts.pointer.keyId})`);
  console.log("");
  console.log("Start the local dev server with:");
  console.log("  bun run dev");
}

function assertNever(value: never): never {
  throw new Error(`Unexpected value: ${String(value)}`);
}

await main();
