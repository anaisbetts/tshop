import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tshop/src/catalog/catalog_models.dart';
import 'package:tshop/src/catalog/catalog_verifier.dart';

const String _devSeedBase64 = 'QxwgC6bZWRcSx08SH0gGahfSp+aNGBQoGMRrbbKBJWI=';

void main() {
  group('CatalogVerifier', () {
    test(
      'dev seed matches shipped tshop-dev-1 public key and verifies',
      () async {
        final algorithm = Ed25519();
        final keyPair = await algorithm.newKeyPairFromSeed(
          base64Decode(_devSeedBase64),
        );
        final publicKey = await keyPair.extractPublicKey();
        expect(base64Encode(publicKey.bytes), devSigningPublicKeyBase64);

        final catalogBytes = Uint8List.fromList(utf8.encode('{"entries":[]}'));
        final catalogHash = sha256.convert(catalogBytes).toString();
        final pointer = await _signPointer(
          keyPair: keyPair,
          keyId: devSigningKeyId,
          catalogSha256: catalogHash,
          catalogSize: catalogBytes.length,
          generatedAtRaw: '2026-11-27T12:00:00Z',
        );

        final verifier = CatalogVerifier();
        await expectLater(verifier.verifyPointer(pointer), completes);
        expect(
          () => verifier.verifyCatalogBytes(
            catalogBytes,
            catalogHash,
            expectedSize: catalogBytes.length,
          ),
          returnsNormally,
        );
      },
    );

    test('verifies a freshly generated Ed25519 keypair', () async {
      final algorithm = Ed25519();
      final keyPair = await algorithm.newKeyPair();
      final publicKey = await keyPair.extractPublicKey();

      final pointer = await _signPointer(
        keyPair: keyPair,
        keyId: 'tshop-prod-2026',
        catalogSha256: 'a' * 64,
        catalogSize: 42,
        generatedAtRaw: '2026-11-27T12:30:00.000Z',
      );

      final verifier = CatalogVerifier(
        trustedKeys: <String, String>{
          'tshop-prod-2026': base64Encode(publicKey.bytes),
        },
      );
      await expectLater(verifier.verifyPointer(pointer), completes);
    });

    test('rejects pointer when any signed field is tampered', () async {
      final keyPair = await Ed25519().newKeyPairFromSeed(
        base64Decode(_devSeedBase64),
      );
      final validPointer = await _signPointer(
        keyPair: keyPair,
        keyId: devSigningKeyId,
        catalogSha256: 'b' * 64,
        catalogSize: 512,
        generatedAtRaw: '2026-11-27T12:00:00Z',
      );
      final verifier = CatalogVerifier();

      final tamperedSha = CatalogPointer(
        schemaVersion: validPointer.schemaVersion,
        minClientVersionCode: validPointer.minClientVersionCode,
        generatedAt: validPointer.generatedAt,
        generatedAtRaw: validPointer.generatedAtRaw,
        keyId: validPointer.keyId,
        catalogUrl: validPointer.catalogUrl,
        catalogSha256: 'c' * 64,
        catalogSize: validPointer.catalogSize,
        statsUrl: validPointer.statsUrl,
        signature: validPointer.signature,
      );

      await expectLater(
        verifier.verifyPointer(tamperedSha),
        throwsA(
          isA<CatalogVerificationException>().having(
            (e) => e.failure,
            'failure',
            CatalogVerificationFailure.invalidSignature,
          ),
        ),
      );

      final tamperedMinClient = CatalogPointer(
        schemaVersion: validPointer.schemaVersion,
        minClientVersionCode: validPointer.minClientVersionCode + 1,
        generatedAt: validPointer.generatedAt,
        generatedAtRaw: validPointer.generatedAtRaw,
        keyId: validPointer.keyId,
        catalogUrl: validPointer.catalogUrl,
        catalogSha256: validPointer.catalogSha256,
        catalogSize: validPointer.catalogSize,
        statsUrl: validPointer.statsUrl,
        signature: validPointer.signature,
      );

      await expectLater(
        verifier.verifyPointer(tamperedMinClient),
        throwsA(
          isA<CatalogVerificationException>().having(
            (e) => e.failure,
            'failure',
            CatalogVerificationFailure.invalidSignature,
          ),
        ),
      );
    });

    test('rejects unsupported schemaVersion', () async {
      final keyPair = await Ed25519().newKeyPairFromSeed(
        base64Decode(_devSeedBase64),
      );
      final pointer = await _signPointer(
        keyPair: keyPair,
        keyId: devSigningKeyId,
        schemaVersion: 2,
        catalogSha256: 'a' * 64,
        catalogSize: 10,
        generatedAtRaw: '2026-11-27T12:00:00Z',
      );

      final verifier = CatalogVerifier();
      await expectLater(
        verifier.verifyPointer(pointer),
        throwsA(
          isA<CatalogVerificationException>().having(
            (e) => e.failure,
            'failure',
            CatalogVerificationFailure.unsupportedSchemaVersion,
          ),
        ),
      );
    });

    test('rejects unknown keyId and omits dev key in release mode', () async {
      final keyPair = await Ed25519().newKeyPairFromSeed(
        base64Decode(_devSeedBase64),
      );
      final pointer = await _signPointer(
        keyPair: keyPair,
        keyId: 'unknown-key',
        catalogSha256: 'a' * 64,
        catalogSize: 10,
        generatedAtRaw: '2026-11-27T12:00:00Z',
      );

      final verifier = CatalogVerifier();
      await expectLater(
        verifier.verifyPointer(pointer),
        throwsA(
          isA<CatalogVerificationException>().having(
            (e) => e.failure,
            'failure',
            CatalogVerificationFailure.unknownKeyId,
          ),
        ),
      );

      final releaseKeys = defaultTrustedCatalogKeys(isReleaseMode: true);
      expect(releaseKeys.containsKey(devSigningKeyId), isFalse);
    });

    test('rejects anti-downgrade older generatedAt but allows equal', () async {
      final keyPair = await Ed25519().newKeyPairFromSeed(
        base64Decode(_devSeedBase64),
      );
      final pointer = await _signPointer(
        keyPair: keyPair,
        keyId: devSigningKeyId,
        catalogSha256: 'a' * 64,
        catalogSize: 10,
        generatedAtRaw: '2026-11-27T12:00:00Z',
      );
      final verifier = CatalogVerifier();

      await expectLater(
        verifier.verifyPointer(
          pointer,
          previousGeneratedAt: DateTime.utc(2026, 11, 27, 12),
        ),
        completes,
      );

      await expectLater(
        verifier.verifyPointer(
          pointer,
          previousGeneratedAt: DateTime.utc(2026, 11, 27, 12, 1),
        ),
        throwsA(
          isA<CatalogVerificationException>().having(
            (e) => e.failure,
            'failure',
            CatalogVerificationFailure.downgradeDetected,
          ),
        ),
      );
    });

    test('rejects mismatched catalogSha256', () {
      final verifier = CatalogVerifier();
      final bytes = Uint8List.fromList(utf8.encode('{"schemaVersion":1}'));

      expect(
        () => verifier.verifyCatalogBytes(bytes, '0' * 64),
        throwsA(
          isA<CatalogVerificationException>().having(
            (e) => e.failure,
            'failure',
            CatalogVerificationFailure.checksumMismatch,
          ),
        ),
      );
    });
  });
}

Future<CatalogPointer> _signPointer({
  required SimpleKeyPair keyPair,
  required String keyId,
  required String catalogSha256,
  required int catalogSize,
  required String generatedAtRaw,
  int schemaVersion = 1,
}) async {
  final unsigned = CatalogPointer(
    schemaVersion: schemaVersion,
    minClientVersionCode: 100,
    generatedAt: DateTime.parse(generatedAtRaw),
    generatedAtRaw: generatedAtRaw,
    keyId: keyId,
    catalogUrl: '/catalog/catalog-$catalogSha256.json',
    catalogSha256: catalogSha256,
    catalogSize: catalogSize,
    statsUrl: 'https://stats.tshop.example/',
    signature: '',
  );
  final sig = await Ed25519().sign(
    CatalogVerifier.canonicalPointerBytes(unsigned),
    keyPair: keyPair,
  );
  return CatalogPointer(
    schemaVersion: unsigned.schemaVersion,
    minClientVersionCode: unsigned.minClientVersionCode,
    generatedAt: unsigned.generatedAt,
    generatedAtRaw: unsigned.generatedAtRaw,
    keyId: unsigned.keyId,
    catalogUrl: unsigned.catalogUrl,
    catalogSha256: unsigned.catalogSha256,
    catalogSize: unsigned.catalogSize,
    statsUrl: unsigned.statsUrl,
    signature: base64Encode(sig.bytes),
  );
}
