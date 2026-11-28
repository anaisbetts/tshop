import {
  createHash,
  createPrivateKey,
  createPublicKey,
  sign,
  verify,
} from "node:crypto";
import type { KeyObject } from "node:crypto";
import type { Pointer } from "./types";

export const DEV_KEY_ID = "tshop-dev-1";
export const DEV_PRIVATE_SEED_BASE64 =
  "QxwgC6bZWRcSx08SH0gGahfSp+aNGBQoGMRrbbKBJWI=";
export const DEV_PUBLIC_KEY_BASE64 =
  "PG5qENnTcJnK4l2/yE8TMIH2W6ElxZ/b8OdNDdd3EF8=";

const ED25519_PKCS8_PREFIX = hexToBytes("302e020100300506032b657004220420");
const ED25519_SPKI_PREFIX = hexToBytes("302a300506032b6570032100");
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
  const signature = bytesToBase64(sign(null, payload, privateKey));

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
  const spkiDer = new Uint8Array(
    createPublicKey(privateKey).export({
      format: "der",
      type: "spki",
    }),
  );

  const expectedLength =
    ED25519_SPKI_PREFIX.byteLength + ED25519_PUBLIC_KEY_BYTES;
  if (
    spkiDer.byteLength !== expectedLength ||
    !bytesEqual(
      spkiDer.subarray(0, ED25519_SPKI_PREFIX.byteLength),
      ED25519_SPKI_PREFIX,
    )
  ) {
    throw new Error("Unexpected Ed25519 SPKI DER output.");
  }

  return bytesToBase64(spkiDer.subarray(ED25519_SPKI_PREFIX.byteLength));
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
  const pkcs8Der = concatBytes(ED25519_PKCS8_PREFIX, seed);
  return createPrivateKey({ key: pkcs8Der, format: "der", type: "pkcs8" });
}

function tryImportEd25519PublicKey(publicKeyBase64: string): KeyObject | null {
  const rawKey = decodeFixedBase64(publicKeyBase64, ED25519_PUBLIC_KEY_BYTES);
  if (rawKey === null) {
    return null;
  }
  const spkiDer = concatBytes(ED25519_SPKI_PREFIX, rawKey);
  return createPublicKey({ key: spkiDer, format: "der", type: "spki" });
}

function decodeFixedBase64(
  encoded: string,
  expectedLength: number,
): Uint8Array | null {
  if (encoded.length === 0 || !BASE64_PATTERN.test(encoded)) {
    return null;
  }
  const binary = atob(encoded);
  if (binary.length !== expectedLength) {
    return null;
  }
  const decoded = new Uint8Array(binary.length);
  for (let i = 0; i < binary.length; i++) {
    decoded[i] = binary.charCodeAt(i);
  }
  return decoded;
}

function bytesToBase64(bytes: Uint8Array): string {
  let binary = "";
  for (const byte of bytes) {
    binary += String.fromCharCode(byte);
  }
  return btoa(binary);
}

function hexToBytes(hex: string): Uint8Array {
  const bytes = new Uint8Array(hex.length / 2);
  for (let i = 0; i < bytes.byteLength; i++) {
    bytes[i] = Number.parseInt(hex.slice(i * 2, i * 2 + 2), 16);
  }
  return bytes;
}

function concatBytes(first: Uint8Array, second: Uint8Array): Uint8Array {
  const combined = new Uint8Array(first.byteLength + second.byteLength);
  combined.set(first, 0);
  combined.set(second, first.byteLength);
  return combined;
}

function bytesEqual(a: Uint8Array, b: Uint8Array): boolean {
  if (a.byteLength !== b.byteLength) {
    return false;
  }
  for (let i = 0; i < a.byteLength; i++) {
    if (a[i] !== b[i]) {
      return false;
    }
  }
  return true;
}
