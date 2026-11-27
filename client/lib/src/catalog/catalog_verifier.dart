import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:cryptography/cryptography.dart';
import 'package:flutter/foundation.dart';
import 'package:tshop/src/catalog/catalog_models.dart';

/// Supported pointer schema version.
const int supportedPointerSchemaVersion = 1;

/// Development Ed25519 key identifier trusted in non-release builds.
const String devSigningKeyId = 'tshop-dev-1';

/// Base64 raw 32-byte Ed25519 public key for [devSigningKeyId].
const String devSigningPublicKeyBase64 =
    'PG5qENnTcJnK4l2/yE8TMIH2W6ElxZ/b8OdNDdd3EF8=';

const int _ed25519PublicKeyLength = 32;
const int _ed25519SignatureLength = 64;

/// Failure reasons raised by [CatalogVerifier].
enum CatalogVerificationFailure {
  /// Pointer `schemaVersion` is unsupported by this client.
  unsupportedSchemaVersion,

  /// Pointer `keyId` is not present in the trusted public key map.
  unknownKeyId,

  /// Trusted public key could not be decoded as a 32-byte Ed25519 key.
  invalidKeyEncoding,

  /// Pointer signature could not be decoded as a 64-byte Ed25519 signature.
  invalidSignatureEncoding,

  /// Ed25519 signature did not verify against canonical pointer bytes.
  invalidSignature,

  /// Pointer `generatedAt` is older than the previously verified catalog.
  downgradeDetected,

  /// Catalog payload SHA-256 digest does not match `catalogSha256`.
  checksumMismatch,

  /// Catalog payload length does not match expected byte size.
  sizeMismatch,
}

/// Exception thrown when pointer or catalog verification fails.
class CatalogVerificationException implements Exception {
  /// Creates a [CatalogVerificationException] with [failure] and [message].
  const CatalogVerificationException(this.failure, this.message);

  /// Categorized verification failure reason.
  final CatalogVerificationFailure failure;

  /// Human-readable diagnostic message.
  final String message;

  @override
  String toString() =>
      'CatalogVerificationException(${failure.name}): $message';
}

/// Verifies signed `pointer.json` documents and catalog payload digests.
class CatalogVerifier {
  /// Creates a [CatalogVerifier] with [trustedKeys] (`keyId` -> base64 raw
  /// 32-byte Ed25519 public key).
  ///
  /// Defaults to [defaultTrustedCatalogKeys].
  CatalogVerifier({Map<String, String>? trustedKeys})
    : trustedKeys = Map<String, String>.unmodifiable(
        trustedKeys ?? defaultTrustedCatalogKeys(),
      );

  /// Trusted signing keys keyed by `keyId`.
  final Map<String, String> trustedKeys;

  static final Ed25519 _ed25519 = Ed25519();

  /// Produces the canonical UTF-8 JSON bytes signed by `pointer.json`.
  ///
  /// Keys are sorted lexicographically excluding `signature`, using
  /// [CatalogPointer.generatedAtRaw] verbatim.
  static Uint8List canonicalPointerBytes(CatalogPointer pointer) {
    final canonicalMap = <String, Object>{
      'catalogSha256': pointer.catalogSha256,
      'catalogSize': pointer.catalogSize,
      'catalogUrl': pointer.catalogUrl,
      'generatedAt': pointer.generatedAtRaw,
      'keyId': pointer.keyId,
      'minClientVersionCode': pointer.minClientVersionCode,
      'schemaVersion': pointer.schemaVersion,
      'statsUrl': pointer.statsUrl,
    };
    return Uint8List.fromList(utf8.encode(jsonEncode(canonicalMap)));
  }

  /// Verifies [pointer]'s schema version, signing key, Ed25519 signature, and
  /// anti-downgrade timestamp against [previousGeneratedAt].
  Future<void> verifyPointer(
    CatalogPointer pointer, {
    DateTime? previousGeneratedAt,
  }) async {
    if (pointer.schemaVersion != supportedPointerSchemaVersion) {
      throw CatalogVerificationException(
        CatalogVerificationFailure.unsupportedSchemaVersion,
        'Unsupported pointer schemaVersion: ${pointer.schemaVersion}.',
      );
    }

    final encodedPublicKey = trustedKeys[pointer.keyId];
    if (encodedPublicKey == null) {
      throw CatalogVerificationException(
        CatalogVerificationFailure.unknownKeyId,
        'Untrusted signing keyId: ${pointer.keyId}.',
      );
    }

    final publicKeyBytes = _decodeBase64Fixed(
      encodedPublicKey,
      expectedLength: _ed25519PublicKeyLength,
      failure: CatalogVerificationFailure.invalidKeyEncoding,
      label: 'public key for ${pointer.keyId}',
    );
    final signatureBytes = _decodeBase64Fixed(
      pointer.signature,
      expectedLength: _ed25519SignatureLength,
      failure: CatalogVerificationFailure.invalidSignatureEncoding,
      label: 'pointer signature',
    );

    final publicKey = SimplePublicKey(
      publicKeyBytes,
      type: KeyPairType.ed25519,
    );
    final signature = Signature(signatureBytes, publicKey: publicKey);
    final isValid = await _ed25519.verify(
      canonicalPointerBytes(pointer),
      signature: signature,
    );
    if (!isValid) {
      throw const CatalogVerificationException(
        CatalogVerificationFailure.invalidSignature,
        'Ed25519 signature verification failed for pointer.json.',
      );
    }

    if (previousGeneratedAt != null &&
        pointer.generatedAt.isBefore(previousGeneratedAt)) {
      throw CatalogVerificationException(
        CatalogVerificationFailure.downgradeDetected,
        'Pointer generatedAt (${pointer.generatedAtRaw}) is older than '
        'last verified catalog '
        '(${previousGeneratedAt.toUtc().toIso8601String()}).',
      );
    }
  }

  /// Verifies that raw catalog [bytes] match [expectedSha256] (case-insensitive
  /// hex) and optional [expectedSize].
  void verifyCatalogBytes(
    Uint8List bytes,
    String expectedSha256, {
    int? expectedSize,
  }) {
    if (expectedSize != null && bytes.length != expectedSize) {
      throw CatalogVerificationException(
        CatalogVerificationFailure.sizeMismatch,
        'Catalog size mismatch: expected $expectedSize bytes, '
        'got ${bytes.length}.',
      );
    }
    final actualSha256 = sha256.convert(bytes).toString().toLowerCase();
    final normalizedExpected = expectedSha256.toLowerCase();
    if (actualSha256 != normalizedExpected) {
      throw CatalogVerificationException(
        CatalogVerificationFailure.checksumMismatch,
        'Catalog SHA-256 mismatch: expected $normalizedExpected, '
        'got $actualSha256.',
      );
    }
  }
}

/// Returns the default trusted Ed25519 signing keys for this build mode.
///
/// Includes [devSigningKeyId] when not running in release mode.
Map<String, String> defaultTrustedCatalogKeys({bool? isReleaseMode}) {
  final release = isReleaseMode ?? kReleaseMode;
  return Map<String, String>.unmodifiable(<String, String>{
    if (!release) devSigningKeyId: devSigningPublicKeyBase64,
  });
}

Uint8List _decodeBase64Fixed(
  String encoded, {
  required int expectedLength,
  required CatalogVerificationFailure failure,
  required String label,
}) {
  try {
    final decoded = base64Decode(encoded);
    if (decoded.length != expectedLength) {
      throw CatalogVerificationException(
        failure,
        'Invalid $label length: expected $expectedLength bytes, '
        'got ${decoded.length}.',
      );
    }
    return decoded;
  } on FormatException catch (error) {
    throw CatalogVerificationException(
      failure,
      'Invalid base64 encoding for $label: ${error.message}',
    );
  }
}
