import { Database } from "bun:sqlite";
import { describe, expect, it } from "bun:test";
import { generateKeyPairSync } from "node:crypto";
import { readFileSync } from "node:fs";
import { resolve } from "node:path";
import {
  buildSignedArtifacts,
  compileCatalog,
  type CatalogQueryDb,
  type SqlParam,
} from "../src/compiler";
import {
  canonicalPointerBytes,
  derivePublicKeyBase64,
  DEV_KEY_ID,
  DEV_PRIVATE_SEED_BASE64,
  DEV_PUBLIC_KEY_BASE64,
  sha256Hex,
  signPointer,
  verifyPointer,
  type UnsignedPointer,
} from "../src/signing";

const CATALOG_MIGRATION_PATH = resolve(
  import.meta.dir,
  "../migrations/catalog/0001_init.sql",
);
const CATALOG_SCHEMA_SQL = readFileSync(CATALOG_MIGRATION_PATH, "utf8");

const SAMPLE_CATALOG_SHA =
  "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa";
const SAMPLE_ICON_SHA =
  "1111111111111111111111111111111111111111111111111111111111111111";
const SAMPLE_SHOT_1_SHA =
  "2222222222222222222222222222222222222222222222222222222222222222";
const SAMPLE_SHOT_2_SHA =
  "3333333333333333333333333333333333333333333333333333333333333333";
const WAYFINDER_CERT =
  "21d1272b5116449056206037600171702c6d4ad5897cf4e9be192a4cd1a2913b";
const STABLE_APK_SHA =
  "ac3061f83dfdd17e4f6ad6e595789c30c35f1fb5f66df16fb37840f6748138b5";
const BETA_APK_SHA =
  "06f5044423ab52164f761ffa21ae711dda54e94bd7ccc1137f68283dc3a0730c";

const SAMPLE_UNSIGNED_POINTER: UnsignedPointer = {
  schemaVersion: 1,
  minClientVersionCode: 1,
  generatedAt: "2026-11-27T23:00:00.000Z",
  keyId: DEV_KEY_ID,
  catalogUrl: `/catalog/catalog-${SAMPLE_CATALOG_SHA}.json`,
  catalogSha256: SAMPLE_CATALOG_SHA,
  catalogSize: 2048,
  statsUrl: "https://stats.tshop.local/",
};

describe("signing.ts", () => {
  it("derives DEV_PUBLIC_KEY_BASE64 exactly from DEV_PRIVATE_SEED_BASE64", () => {
    expect(derivePublicKeyBase64(DEV_PRIVATE_SEED_BASE64)).toBe(
      DEV_PUBLIC_KEY_BASE64,
    );
  });

  it("serializes canonical pointer bytes with lexicographically sorted keys and no whitespace", () => {
    const bytes = canonicalPointerBytes(SAMPLE_UNSIGNED_POINTER);
    const decoded = new TextDecoder().decode(bytes);
    expect(decoded).toBe(
      `{"catalogSha256":"${SAMPLE_CATALOG_SHA}","catalogSize":2048,"catalogUrl":"/catalog/catalog-${SAMPLE_CATALOG_SHA}.json","generatedAt":"2026-11-27T23:00:00.000Z","keyId":"tshop-dev-1","minClientVersionCode":1,"schemaVersion":1,"statsUrl":"https://stats.tshop.local/"}`,
    );

    const signed = signPointer(SAMPLE_UNSIGNED_POINTER, DEV_PRIVATE_SEED_BASE64);
    expect(canonicalPointerBytes(signed)).toEqual(bytes);
  });

  it("round-trips signPointer and verifyPointer cleanly", () => {
    const signed = signPointer(SAMPLE_UNSIGNED_POINTER, DEV_PRIVATE_SEED_BASE64);
    expect(signed.keyId).toBe(DEV_KEY_ID);
    expect(signed.signature.length).toBeGreaterThan(0);
    expect(verifyPointer(signed, DEV_PUBLIC_KEY_BASE64)).toBe(true);
  });

  it("rejects tampered fields, wrong public keys, and malformed signatures", () => {
    const signed = signPointer(SAMPLE_UNSIGNED_POINTER, DEV_PRIVATE_SEED_BASE64);

    expect(
      verifyPointer(
        { ...signed, catalogSize: signed.catalogSize + 1 },
        DEV_PUBLIC_KEY_BASE64,
      ),
    ).toBe(false);
    expect(
      verifyPointer(
        { ...signed, generatedAt: "2026-11-27T23:00:01.000Z" },
        DEV_PUBLIC_KEY_BASE64,
      ),
    ).toBe(false);
    expect(
      verifyPointer(
        { ...signed, minClientVersionCode: 2 },
        DEV_PUBLIC_KEY_BASE64,
      ),
    ).toBe(false);

    const otherKeyPair = generateKeyPairSync("ed25519");
    const otherSpki = otherKeyPair.publicKey.export({
      format: "der",
      type: "spki",
    });
    const otherPublicBase64 = otherSpki.subarray(otherSpki.byteLength - 32).toString("base64");
    expect(verifyPointer(signed, otherPublicBase64)).toBe(false);

    expect(
      verifyPointer({ ...signed, signature: "not-valid-base64!!!" }, DEV_PUBLIC_KEY_BASE64),
    ).toBe(false);
    expect(verifyPointer(signed, "shortkey")).toBe(false);
  });

  it("computes lowercase hex SHA-256 digests", () => {
    expect(sha256Hex(new TextEncoder().encode("abc"))).toBe(
      "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad",
    );
  });
});

describe("compiler.ts", () => {
  it("compiles a stable Wayfinder catalog matching the client contract and builds verified signed artifacts", async () => {
    const db = createCatalogDb();
    seedWayfinder(db, { includeBeta: false });

    const generatedAt = "2026-11-27T23:15:00.000Z";
    const catalog = await compileCatalog(asQueryDb(db), { generatedAt });

    expect(catalog.schemaVersion).toBe(1);
    expect(catalog.generatedAt).toBe(generatedAt);
    expect(catalog.apkBaseUrl).toBe("/apk");
    expect(catalog.client).toBeNull();
    expect(catalog.capabilityTags).toEqual([]);
    expect(catalog.categories).toEqual([
      {
        id: "Utilities",
        name: { en: "Utilities" },
        entries: ["app.wayfinder"],
      },
    ]);
    expect(catalog.entries).toHaveLength(1);

    const entry = catalog.entries[0];
    expect(entry).toEqual({
      packageName: "app.wayfinder",
      slug: "wayfinder",
      rank: 1,
      name: { en: "Wayfinder" },
      publisher: "Thor-Wayfinder",
      category: "Utilities",
      searchTags: ["thor", "ayn", "dual-screen"],
      summary: {
        en: "Two screens, one controller — move apps, per-game controls, and quick panel for the AYN Thor.",
      },
      description: {
        en: ["Paragraph one.", "Paragraph two."],
      },
      compatNotes: null,
      homepageUrl: "https://github.com/Thor-Wayfinder/thor-wayfinder",
      rehostMode: "rehost",
      landing: null,
      allowedSigningCerts: [WAYFINDER_CERT],
      capabilities: [],
      tile: {
        iconUrl: `/art/${SAMPLE_ICON_SHA}.png`,
        backdropColors: ["#1E3A5F", "#0F172A"],
        backdropAngle: 155,
        iconScale: 1.0,
      },
      featureUrl: `/art/${SAMPLE_SHOT_1_SHA}.webp`,
      screenshots: [
        {
          thumbUrl: `/art/${SAMPLE_SHOT_1_SHA}.webp`,
          fullUrl: `/art/${SAMPLE_SHOT_1_SHA}.webp`,
          width: 1280,
          height: 720,
        },
        {
          thumbUrl: `/art/${SAMPLE_SHOT_2_SHA}.jpg`,
          fullUrl: `/art/${SAMPLE_SHOT_2_SHA}.jpg`,
          width: 1920,
          height: 1080,
        },
      ],
      release: {
        versionCode: 8,
        versionName: "1.4.1",
        releasedAt: "2026-10-02T08:27:25Z",
        variantsAreUserChoice: false,
        variants: [
          {
            sha256: STABLE_APK_SHA,
            sizeBytes: 1234567,
            abis: [],
            minSdk: 30,
            targetSdk: 34,
            label: null,
            note: null,
            upstreamUrl:
              "https://github.com/Thor-Wayfinder/thor-wayfinder/releases/download/v1.4.1/wayfinder-1.4.1.apk",
          },
        ],
      },
      changelogs: [
        {
          versionCode: 8,
          versionName: "1.4.1",
          releasedAt: "2026-10-02T08:27:25Z",
          notes: {
            en: ["Fixed Backspace bug"],
          },
        },
      ],
    });

    const artifacts = buildSignedArtifacts(catalog);
    expect(sha256Hex(artifacts.catalogBytes)).toBe(artifacts.catalogSha256);
    expect(artifacts.catalogUrl).toBe(
      `/catalog/catalog-${artifacts.catalogSha256}.json`,
    );
    expect(artifacts.pointer.catalogSha256).toBe(artifacts.catalogSha256);
    expect(artifacts.pointer.catalogSize).toBe(artifacts.catalogBytes.byteLength);
    expect(artifacts.pointer.generatedAt).toBe(generatedAt);
    expect(verifyPointer(artifacts.pointer, DEV_PUBLIC_KEY_BASE64)).toBe(true);
    expect(JSON.parse(artifacts.pointerJson)).toEqual(artifacts.pointer);

    db.close();
  });

  it("emits beta approved release with superseded stable release in changelogs ordered by versionCode DESC", async () => {
    const db = createCatalogDb();
    seedWayfinder(db, { includeBeta: true });

    const catalog = await compileCatalog(asQueryDb(db), {
      generatedAt: "2026-11-27T23:20:00.000Z",
    });

    const entry = catalog.entries[0];
    expect(entry.release?.versionCode).toBe(10);
    expect(entry.release?.versionName).toBe("1.5-beta2");
    expect(entry.release?.variants[0]?.sha256).toBe(BETA_APK_SHA);
    expect(entry.changelogs.map((c) => c.versionName)).toEqual([
      "1.5-beta2",
      "1.4.1",
    ]);
    expect(entry.changelogs.map((c) => c.versionCode)).toEqual([10, 8]);

    db.close();
  });

  it("sorts entries by editorial_pin then seed_rank then slug, filters draft apps, and keeps fixed category order", async () => {
    const db = createCatalogDb();
    const now = "2026-11-27T23:00:00Z";

    db.query(
      "INSERT INTO capability_tags (tag, label_i18n, min_client_version_code, created_at) VALUES (?, ?, 1, ?)",
    ).run("vulkan:1.1", JSON.stringify({ en: "Vulkan 1.1" }), now);

    insertMinimalApp(db, {
      packageName: "org.example.util",
      slug: "util-b",
      status: "published",
      category: "Utilities",
      seedRank: 1,
      editorialPin: null,
      rehostMode: "rehost",
    });
    insertMinimalApp(db, {
      packageName: "org.example.emu",
      slug: "emu-pinned",
      status: "published",
      category: "Emulators",
      seedRank: 5,
      editorialPin: 1,
      rehostMode: "landing",
    });
    insertMinimalApp(db, {
      packageName: "org.example.alpha",
      slug: "alpha",
      status: "published",
      category: "Utilities",
      seedRank: 1,
      editorialPin: null,
      rehostMode: "rehost",
    });
    insertMinimalApp(db, {
      packageName: "org.example.draft",
      slug: "draft-app",
      status: "draft",
      category: "Games",
      seedRank: 1,
      editorialPin: 1,
      rehostMode: "rehost",
    });

    const catalog = await compileCatalog(asQueryDb(db), {
      generatedAt: now,
    });

    expect(catalog.capabilityTags).toEqual([
      { tag: "vulkan:1.1", label: { en: "Vulkan 1.1" } },
    ]);
    expect(catalog.entries.map((e) => [e.rank, e.slug])).toEqual([
      [1, "emu-pinned"],
      [2, "alpha"],
      [3, "util-b"],
    ]);
    expect(catalog.categories.map((c) => c.id)).toEqual([
      "Emulators",
      "Utilities",
    ]);
    expect(catalog.categories[1]?.entries).toEqual([
      "org.example.alpha",
      "org.example.util",
    ]);

    const landingEntry = catalog.entries[0];
    expect(landingEntry.rehostMode).toBe("landing");
    expect(landingEntry.landing).toEqual({
      reason: { en: "Publisher hosts downloads directly." },
      url: "https://example.org/download",
    });
    expect(landingEntry.allowedSigningCerts).toEqual([]);

    db.close();
  });
});

function createCatalogDb(): Database {
  const db = new Database(":memory:");
  db.exec(CATALOG_SCHEMA_SQL);
  return db;
}

function asQueryDb(db: Database): CatalogQueryDb {
  return {
    all<T>(sql: string, params: readonly SqlParam[] = []): T[] {
      const stmt = db.query(sql);
      return stmt.all(...(params as Parameters<typeof stmt.all>)) as T[];
    },
  };
}

function seedWayfinder(db: Database, options: { includeBeta: boolean }): void {
  const now = "2026-11-27T23:00:00Z";
  db.query(
    `INSERT INTO apps (
      package_name, slug, status, rehost_mode, name_i18n, summary_i18n,
      description_i18n, publisher, homepage_url, primary_category, search_tags,
      capabilities, backdrop_colors, backdrop_angle, icon_scale, seed_rank,
      editorial_pin, source_type, source_config, license_spdx, created_at, updated_at
    ) VALUES (
      'app.wayfinder', 'wayfinder', 'published', 'rehost', ?, ?, ?, 'Thor-Wayfinder',
      'https://github.com/Thor-Wayfinder/thor-wayfinder', 'Utilities', ?, '[]',
      ?, 155, 1.0, 1, NULL, 'github_release', '{}', 'PolyForm-Strict-1.0.0', ?, ?
    )`,
  ).run(
    JSON.stringify({ en: "Wayfinder" }),
    JSON.stringify({
      en: "Two screens, one controller — move apps, per-game controls, and quick panel for the AYN Thor.",
    }),
    JSON.stringify({ en: ["Paragraph one.", "Paragraph two."] }),
    JSON.stringify(["thor", "ayn", "dual-screen"]),
    JSON.stringify(["#1E3A5F", "#0F172A"]),
    now,
    now,
  );

  db.query(
    `INSERT INTO app_certs (
      package_name, sha256_fingerprint, label, active, added_reason, added_by, created_at
    ) VALUES ('app.wayfinder', ?, 'GitHub key', 1, 'seed', 'test', ?)`,
  ).run(WAYFINDER_CERT, now);

  // Inactive cert must be omitted from allowedSigningCerts.
  db.query(
    `INSERT INTO app_certs (
      package_name, sha256_fingerprint, label, active, added_reason, added_by, created_at
    ) VALUES ('app.wayfinder', '0000000000000000000000000000000000000000000000000000000000000000', 'Old key', 0, 'rotated', 'test', ?)`,
  ).run(now);

  const stableState = options.includeBeta ? "superseded" : "approved";
  const stableId = Number(
    db
      .query(
        `INSERT INTO releases (
          package_name, version_code, version_name, released_at, changelog_i18n,
          state, variants_are_user_choice, validation_report, created_at
        ) VALUES ('app.wayfinder', 8, '1.4.1', '2026-10-02T08:27:25Z', ?, ?, 0, '{}', ?)`,
      )
      .run(JSON.stringify({ en: ["Fixed Backspace bug"] }), stableState, now)
      .lastInsertRowid,
  );

  db.query(
    `INSERT INTO release_variants (
      release_id, sha256, size_bytes, abis, min_sdk, target_sdk, upstream_url, r2_key, r2_present
    ) VALUES (?, ?, 1234567, '[]', 30, 34, 'https://github.com/Thor-Wayfinder/thor-wayfinder/releases/download/v1.4.1/wayfinder-1.4.1.apk', ?, 1)`,
  ).run(stableId, STABLE_APK_SHA, `${STABLE_APK_SHA}.apk`);

  let approvedId = stableId;
  let previousId: number | null = null;

  if (options.includeBeta) {
    const betaId = Number(
      db
        .query(
          `INSERT INTO releases (
            package_name, version_code, version_name, released_at, changelog_i18n,
            state, variants_are_user_choice, validation_report, created_at
          ) VALUES ('app.wayfinder', 10, '1.5-beta2', '2026-11-24T14:53:25Z', ?, 'approved', 0, '{}', ?)`,
        )
        .run(
          JSON.stringify({ en: ["Bluetooth and USB controller handling"] }),
          now,
        ).lastInsertRowid,
    );

    db.query(
      `INSERT INTO release_variants (
        release_id, sha256, size_bytes, abis, min_sdk, target_sdk, upstream_url, r2_key, r2_present
      ) VALUES (?, ?, 1456789, '[]', 30, 34, 'https://github.com/Thor-Wayfinder/thor-wayfinder/releases/download/v1.5-beta2/wayfinder-1.5-beta2.apk', ?, 1)`,
    ).run(betaId, BETA_APK_SHA, `${BETA_APK_SHA}.apk`);

    approvedId = betaId;
    previousId = stableId;
  }

  db.query(
    "UPDATE apps SET approved_release_id = ?, previous_release_id = ? WHERE package_name = 'app.wayfinder'",
  ).run(approvedId, previousId);

  // Verify both <sha>.<ext> and bare <sha> (implying .webp) plus sort_order ordering.
  const insertAsset = db.query(
    `INSERT INTO app_assets (
      package_name, kind, sort_order, raw_r2_key, webp_sha256, thumb_webp_sha256,
      width, height, source_url, rights_basis, created_at
    ) VALUES ('app.wayfinder', ?, ?, 'raw/a', ?, ?, ?, ?, 'https://example.org', 'test', ?)`,
  );
  insertAsset.run("icon", 0, `${SAMPLE_ICON_SHA}.png`, null, 256, 256, now);
  insertAsset.run("feature", 0, SAMPLE_SHOT_1_SHA, null, 1280, 720, now);
  insertAsset.run(
    "screenshot",
    1,
    `${SAMPLE_SHOT_2_SHA}.jpg`,
    `${SAMPLE_SHOT_2_SHA}.jpg`,
    1920,
    1080,
    now,
  );
  insertAsset.run("screenshot", 0, SAMPLE_SHOT_1_SHA, null, 1280, 720, now);
}

function insertMinimalApp(
  db: Database,
  spec: {
    packageName: string;
    slug: string;
    status: "draft" | "published" | "delisted";
    category: "Emulators" | "Frontends" | "Games" | "Utilities";
    seedRank: number;
    editorialPin: number | null;
    rehostMode: "rehost" | "landing";
  },
): void {
  const now = "2026-11-27T23:00:00Z";
  db.query(
    `INSERT INTO apps (
      package_name, slug, status, rehost_mode, landing_reason_i18n, landing_url,
      name_i18n, summary_i18n, description_i18n, publisher, homepage_url,
      primary_category, search_tags, capabilities, backdrop_colors, backdrop_angle,
      icon_scale, seed_rank, editorial_pin, source_type, source_config,
      license_spdx, created_at, updated_at
    ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, 'Pub', 'https://example.org', ?, '[]', '[]', '["#000000"]', 160, 1.0, ?, ?, 'none', '{}', 'MIT', ?, ?)`,
  ).run(
    spec.packageName,
    spec.slug,
    spec.status,
    spec.rehostMode,
    spec.rehostMode === "landing"
      ? JSON.stringify({ en: "Publisher hosts downloads directly." })
      : null,
    spec.rehostMode === "landing" ? "https://example.org/download" : null,
    JSON.stringify({ en: spec.slug }),
    JSON.stringify({ en: "Summary" }),
    JSON.stringify({ en: ["Desc"] }),
    spec.category,
    spec.seedRank,
    spec.editorialPin,
    now,
    now,
  );

  db.query(
    `INSERT INTO app_assets (
      package_name, kind, sort_order, raw_r2_key, webp_sha256, thumb_webp_sha256,
      width, height, source_url, rights_basis, created_at
    ) VALUES (?, 'icon', 0, 'raw/icon', ?, NULL, 256, 256, 'https://example.org', 'test', ?)`,
  ).run(spec.packageName, SAMPLE_ICON_SHA, now);
}
