import { createHash } from "node:crypto";
import { readFileSync } from "node:fs";
import { resolve } from "node:path";
import { DatabaseSync } from "node:sqlite";
import type { SQLInputValue } from "node:sqlite";
import type { Env } from "../src/types";

const ANALYTICS_MIGRATION_PATH = resolve(
  import.meta.dirname,
  "../migrations/analytics/0001_completions.sql",
);
const CATALOG_MIGRATION_PATH = resolve(
  import.meta.dirname,
  "../migrations/catalog/0001_init.sql",
);
const SINGLE_RANGE_PATTERN = /^bytes=(\d*)-(\d*)$/;

export interface CompletionRow {
  sha256: string;
  utc_day: string;
  intent: string;
  n: number;
}

interface StoredR2Entry {
  body: Uint8Array;
  etag: string;
  httpEtag: string;
  httpMetadata: R2HTTPMetadata;
}

export interface TestHarness {
  env: Env;
  ctx: MockExecutionContext;
  apksBucket: MockR2Bucket;
  assetsBucket: MockR2Bucket;
  analyticsDb: MockD1Database;
  catalogDb: MockD1Database;
}

interface GlobalWithFixedLengthStream {
  FixedLengthStream?: typeof PolyfillFixedLengthStream;
}

export function createTestHarness(): TestHarness {
  installFixedLengthStreamPolyfill();

  const apksBucket = new MockR2Bucket();
  const assetsBucket = new MockR2Bucket();
  const analyticsDb = new MockD1Database(
    readFileSync(ANALYTICS_MIGRATION_PATH, "utf8"),
  );
  const catalogDb = new MockD1Database(
    readFileSync(CATALOG_MIGRATION_PATH, "utf8"),
  );
  const ctx = new MockExecutionContext();

  const env: Env = {
    CATALOG_DB: asD1Database(catalogDb),
    ANALYTICS_DB: asD1Database(analyticsDb),
    APKS_BUCKET: asR2Bucket(apksBucket),
    ASSETS_BUCKET: asR2Bucket(assetsBucket),
  };

  return { env, ctx, apksBucket, assetsBucket, analyticsDb, catalogDb };
}

export class MockR2Bucket {
  private readonly store = new Map<string, StoredR2Entry>();

  seed(
    key: string,
    body: Uint8Array | string,
    etag?: string,
    httpMetadata: R2HTTPMetadata = {},
  ): StoredR2Entry {
    const bytes =
      typeof body === "string" ? new TextEncoder().encode(body) : body;
    const rawEtag = etag ?? computeEtag(bytes);
    const entry: StoredR2Entry = {
      body: bytes,
      etag: rawEtag,
      httpEtag: `"${rawEtag}"`,
      httpMetadata,
    };
    this.store.set(key, entry);
    return entry;
  }

  async head(key: string): Promise<R2Object | null> {
    const entry = this.store.get(key);
    if (!entry) {
      return null;
    }
    return buildR2Object(key, entry, undefined);
  }

  async get(key: string, options?: R2GetOptions): Promise<R2ObjectBody | null> {
    const entry = this.store.get(key);
    if (!entry) {
      return null;
    }

    const range = extractRange(options?.range, entry.body.byteLength);
    const slice = sliceForRange(entry.body, range);
    return buildR2ObjectBody(key, entry, range, slice);
  }
}

export class MockD1Database {
  private readonly db: DatabaseSync;

  constructor(schemaSql?: string) {
    this.db = new DatabaseSync(":memory:");
    if (schemaSql) {
      this.db.exec(schemaSql);
    }
  }

  prepare(query: string): MockD1PreparedStatement {
    return new MockD1PreparedStatement(this.db, query);
  }

  queryCompletions(): Array<CompletionRow> {
    const rows = this.db
      .prepare(
        "SELECT sha256, utc_day, intent, n FROM completions ORDER BY sha256, utc_day, intent",
      )
      .all();
    return rows.map((row) => ({
      sha256: String(row.sha256),
      utc_day: String(row.utc_day),
      intent: String(row.intent),
      n: Number(row.n),
    }));
  }
}

export class MockExecutionContext {
  private readonly pending: Array<Promise<unknown>> = [];

  waitUntil(promise: Promise<unknown>): void {
    this.pending.push(promise);
  }

  passThroughOnException(): void {}

  asExecutionContext(): ExecutionContext {
    return this as unknown as ExecutionContext;
  }

  async flush(): Promise<void> {
    await Promise.all(this.pending);
    this.pending.length = 0;
  }
}

class MockD1PreparedStatement {
  private params: Array<SQLInputValue> = [];

  constructor(
    private readonly db: DatabaseSync,
    private readonly sql: string,
  ) {}

  bind(...values: Array<SQLInputValue>): this {
    this.params = values;
    return this;
  }

  async run(): Promise<D1Result> {
    const stmt = this.db.prepare(this.sql);
    stmt.run(...this.params);
    return {
      success: true,
      results: [],
      meta: {
        duration: 0,
        size_after: 0,
        rows_read: 0,
        rows_written: 1,
        last_row_id: 0,
        changed_db: true,
        changes: 1,
      },
    };
  }

  async all<T = Record<string, SQLInputValue>>(): Promise<D1Result<T>> {
    const stmt = this.db.prepare(this.sql);
    const results = stmt.all(...this.params).map((row) => ({ ...row }) as T);
    return {
      success: true,
      results,
      meta: {
        duration: 0,
        size_after: 0,
        rows_read: results.length,
        rows_written: 0,
        last_row_id: 0,
        changed_db: false,
        changes: 0,
      },
    };
  }
}

class PolyfillFixedLengthStream extends TransformStream<
  Uint8Array,
  Uint8Array
> {
  constructor(expectedLength: number) {
    let bytesWritten = 0;
    super({
      transform(chunk, controller) {
        bytesWritten += chunk.byteLength;
        if (bytesWritten > expectedLength) {
          controller.error(
            new TypeError(
              `Attempt to write too many bytes through a FixedLengthStream: expected ${expectedLength}, got ${bytesWritten}`,
            ),
          );
          return;
        }
        controller.enqueue(chunk);
      },
      flush(controller) {
        if (bytesWritten !== expectedLength) {
          controller.error(
            new TypeError(
              `Premature end of FixedLengthStream: expected ${expectedLength}, got ${bytesWritten}`,
            ),
          );
        }
      },
    });
  }
}

function installFixedLengthStreamPolyfill(): void {
  const globalObj = globalThis as unknown as GlobalWithFixedLengthStream;
  if (globalObj.FixedLengthStream === undefined) {
    Object.defineProperty(globalThis, "FixedLengthStream", {
      value: PolyfillFixedLengthStream,
      configurable: true,
      writable: true,
    });
  }
}

function asD1Database(db: MockD1Database): D1Database {
  return db as unknown as D1Database;
}

function asR2Bucket(bucket: MockR2Bucket): R2Bucket {
  return bucket as unknown as R2Bucket;
}

function buildR2Object(
  key: string,
  entry: StoredR2Entry,
  range: R2Range | undefined,
): R2Object {
  const object: Partial<R2Object> = {
    key,
    version: "1",
    size: entry.body.byteLength,
    etag: entry.etag,
    httpEtag: entry.httpEtag,
    checksums: { toJSON: () => ({}) },
    uploaded: new Date("2026-04-01T00:00:00Z"),
    httpMetadata: entry.httpMetadata,
    customMetadata: {},
    range,
    storageClass: "Standard",
    writeHttpMetadata(headers: Headers): void {
      if (entry.httpMetadata.contentType) {
        headers.set("Content-Type", entry.httpMetadata.contentType);
      }
      if (entry.httpMetadata.cacheControl) {
        headers.set("Cache-Control", entry.httpMetadata.cacheControl);
      }
    },
  };
  return object as R2Object;
}

function buildR2ObjectBody(
  key: string,
  entry: StoredR2Entry,
  range: R2Range | undefined,
  slice: Uint8Array,
): R2ObjectBody {
  const base = buildR2Object(key, entry, range);
  const bodyObj: Partial<R2ObjectBody> = {
    key: base.key,
    version: base.version,
    size: base.size,
    etag: base.etag,
    httpEtag: base.httpEtag,
    checksums: base.checksums,
    uploaded: base.uploaded,
    httpMetadata: base.httpMetadata,
    customMetadata: base.customMetadata,
    range: base.range,
    storageClass: base.storageClass,
    writeHttpMetadata: (headers: Headers) => base.writeHttpMetadata(headers),
    body: createByteStream(slice),
    bodyUsed: false,
    async arrayBuffer(): Promise<ArrayBuffer> {
      const copy = new Uint8Array(slice.byteLength);
      copy.set(slice);
      return copy.buffer;
    },
    async bytes(): Promise<Uint8Array> {
      return slice;
    },
    async text(): Promise<string> {
      return new TextDecoder().decode(slice);
    },
    async json<T>(): Promise<T> {
      return JSON.parse(new TextDecoder().decode(slice)) as T;
    },
    async blob(): Promise<Blob> {
      return new Blob([slice]);
    },
  };
  return bodyObj as R2ObjectBody;
}

function extractRange(
  rangeOption: R2Range | Headers | undefined,
  size: number,
): R2Range | undefined {
  if (!rangeOption) {
    return undefined;
  }
  if (!isHeaders(rangeOption)) {
    return rangeOption;
  }
  const header = rangeOption.get("Range");
  if (!header) {
    return undefined;
  }
  const match = SINGLE_RANGE_PATTERN.exec(header.trim());
  if (!match) {
    return undefined;
  }
  const startStr = match[1];
  const endStr = match[2];
  if (startStr === "" && endStr !== "") {
    return { suffix: Number(endStr) };
  }
  const start = Number(startStr);
  if (endStr === "") {
    return { offset: start, length: Math.max(0, size - start) };
  }
  const end = Math.min(Number(endStr), size - 1);
  return { offset: start, length: Math.max(0, end - start + 1) };
}

function isHeaders(value: R2Range | Headers): value is Headers {
  return "get" in value && typeof value.get === "function";
}

function sliceForRange(
  body: Uint8Array,
  range: R2Range | undefined,
): Uint8Array {
  if (!range) {
    return body;
  }
  if (isSuffixRange(range)) {
    const length = Math.min(range.suffix, body.byteLength);
    return body.subarray(body.byteLength - length);
  }
  const start = range.offset ?? 0;
  const remaining = Math.max(0, body.byteLength - start);
  const length =
    range.length === undefined ? remaining : Math.min(range.length, remaining);
  return body.subarray(start, start + length);
}

function isSuffixRange(range: R2Range): range is { suffix: number } {
  return "suffix" in range && typeof range.suffix === "number";
}

function createByteStream(bytes: Uint8Array): ReadableStream<Uint8Array> {
  return new ReadableStream<Uint8Array>({
    start(controller) {
      if (bytes.byteLength > 0) {
        controller.enqueue(bytes);
      }
      controller.close();
    },
  });
}

function computeEtag(bytes: Uint8Array): string {
  return createHash("sha256").update(bytes).digest("hex").slice(0, 32);
}
