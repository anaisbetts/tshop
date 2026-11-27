import {
  createHash,
  createPrivateKey,
  createPublicKey,
  sign,
  verify,
  type KeyObject,
} from "node:crypto";
import type { Pointer } from "./types";

export const DEV_KEY_ID = "tshop-dev-1";
export const DEV_PRIVATE_SEED_BASE64 =
  "QxwgC6bZWRcSx08SH0gGahfSp+aNGBQoGMRrbbKBJWI=";
export const DEV_PUBLIC_KEY_BASE64 =
  "PG5qENnTcJnK4l2/yE8TMIH2W6ElxZ/b8OdNDdd3EF8=";

const ED25519_PKCS8_PREFIX = Buffer.from(
  "302e020100300506032b657004220420",
  "hex",
);
const ED25519_SPKI_PREFIX = Buffer.from("302a300506032b6570032100", "hex");
const ED25519_SEED_BYTES = 32;
const ED25519_PUBLIC_KEY_BYTES = 32;
const ED25519_SIGNATURE_BYTES = 64;
const BASE64_PATTERN =
  /^(?:[A-Za-z0-9+/]{4})*(?:[A-Za-z0-9+/]{2}==|[A-Za-z0-9+/]{3}=)?$/;

export type UnsignedPointer = Omit<Pointer, "signature">;

export function signPointer(
  unsignedPointer: UnsignedPointer,
  privateSeedBase64: string,
): Pointer {
  const privateKey = importEd25519PrivateKey(privateSeedBase64);
  const payload = canonicalPointerBytes(unsignedPointer);
  const signature = sign(null, payload, privateKey).toString("base64");

  return {
    schemaVersion: unsignedPointer.schemaVersion,
    minClientVersionCode: unsignedPointer.minClientVersionCode,
    generatedAt: unsignedPointer.generatedAt,
    keyId: unsignedPointer.keyId,
    catalogUrl: unsignedPointer.catalogUrl,
    catalogSha256: unsignedPointer.catalogSha256,
    catalogSize: unsignedPointer.catalogSize,
    statsUrl: unsignedPointer.statsUrl,
    signature,
  };
}

export function verifyPointer(
  pointer: Pointer,
  publicKeyBase64: string,
): boolean {
  const publicKey = tryImportEd25519PublicKey(publicKeyBase64);
  if (publicKey === null) {
    return false;
  }

  const signatureBytes = decodeFixedBase64(
    pointer.signature,
    ED25519_SIGNATURE_BYTES,
  );
  if (signatureBytes === null) {
    return false;
  }

  const payload = canonicalPointerBytes(pointer);
  return verify(null, payload, publicKey, signatureBytes);
}

export function canonicalPointerBytes(
  pointer: UnsignedPointer | Pointer,
): Uint8Array {
  // Keys are strictly ordered lexicographically, excluding `signature`,
  // matching client CatalogVerifier.canonicalPointerBytes verbatim.
  const canonical = {
    catalogSha256: pointer.catalogSha256,
    catalogSize: pointer.catalogSize,
    catalogUrl: pointer.catalogUrl,
    generatedAt: pointer.generatedAt,
    keyId: pointer.keyId,
    minClientVersionCode: pointer.minClientVersionCode,
    schemaVersion: pointer.schemaVersion,
    statsUrl: pointer.statsUrl,
  };
  return new TextEncoder().encode(JSON.stringify(canonical));
}

export function derivePublicKeyBase64(privateSeedBase64: string): string {
  const privateKey = importEd25519PrivateKey(privateSeedBase64);
  const spkiDer = createPublicKey(privateKey).export({
    format: "der",
    type: "spki",
  });

  const expectedLength = ED25519_SPKI_PREFIX.byteLength + ED25519_PUBLIC_KEY_BYTES;
  if (
    spkiDer.byteLength !== expectedLength ||
    !spkiDer.subarray(0, ED25519_SPKI_PREFIX.byteLength).equals(ED25519_SPKI_PREFIX)
  ) {
    throw new Error("Unexpected Ed25519 SPKI DER output.");
  }

  return spkiDer.subarray(ED25519_SPKI_PREFIX.byteLength).toString("base64");
}

export function sha256Hex(bytes: Uint8Array | string): string {
  return createHash("sha256").update(bytes).digest("hex");
}

function importEd25519PrivateKey(privateSeedBase64: string): KeyObject {
  const seed = decodeFixedBase64(privateSeedBase64, ED25519_SEED_BYTES);
  if (seed === null) {
    throw new Error(
      `Invalid Ed25519 private seed: expected ${ED25519_SEED_BYTES} base64-encoded bytes.`,
    );
  }
  const pkcs8Der = Buffer.concat([ED25519_PKCS8_PREFIX, seed]);
  return createPrivateKey({ key: pkcs8Der, format: "der", type: "pkcs8" });
}

function tryImportEd25519PublicKey(publicKeyBase64: string): KeyObject | null {
  const rawKey = decodeFixedBase64(publicKeyBase64, ED25519_PUBLIC_KEY_BYTES);
  if (rawKey === null) {
    return null;
  }
  const spkiDer = Buffer.concat([ED25519_SPKI_PREFIX, rawKey]);
  return createPublicKey({ key: spkiDer, format: "der", type: "spki" });
}

function decodeFixedBase64(
  encoded: string,
  expectedLength: number,
): Buffer | null {
  if (encoded.length === 0 || !BASE64_PATTERN.test(encoded)) {
    return null;
  }
  const decoded = Buffer.from(encoded, "base64");
  if (decoded.byteLength !== expectedLength) {
    return null;
  }
  return decoded;
}
