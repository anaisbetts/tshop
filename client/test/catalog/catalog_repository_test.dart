import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:cryptography/cryptography.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:tshop/src/catalog/catalog_cache_store.dart';
import 'package:tshop/src/catalog/catalog_cache_store_io.dart';
import 'package:tshop/src/catalog/catalog_models.dart';
import 'package:tshop/src/catalog/catalog_provider.dart';
import 'package:tshop/src/catalog/catalog_repository.dart';
import 'package:tshop/src/catalog/catalog_verifier.dart';
import 'package:tshop/src/config/tshop_config.dart';

const String _devSeedBase64 = 'QxwgC6bZWRcSx08SH0gGahfSp+aNGBQoGMRrbbKBJWI=';

class _FakeHttpClientAdapter implements HttpClientAdapter {
  _FakeHttpClientAdapter(this.handler);

  Future<ResponseBody> Function(RequestOptions options) handler;
  final List<RequestOptions> requests = <RequestOptions>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    return handler(options);
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  group('CatalogRepository', () {
    late SimpleKeyPair devKeyPair;
    late TshopConfig config;
    late CatalogVerifier verifier;

    setUp(() async {
      devKeyPair = await Ed25519().newKeyPairFromSeed(
        base64Decode(_devSeedBase64),
      );
      config = TshopConfig(catalogBaseUrl: Uri.parse('http://127.0.0.1:8787'));
      verifier = CatalogVerifier();
    });

    test(
      'fetches 200 pointer + catalog, verifies, and resolves URLs',
      () async {
        final fixture = await _buildSignedFixture(
          keyPair: devKeyPair,
          generatedAtRaw: '2026-11-27T10:00:00Z',
          entryName: 'Thor Wayfinder',
        );
        final adapter = _FakeHttpClientAdapter((options) async {
          if (options.uri.path == '/pointer.json') {
            return ResponseBody.fromBytes(
              utf8.encode(fixture.pointerJson),
              200,
              headers: <String, List<String>>{
                'content-type': <String>['application/json'],
                'etag': <String>['"etag-v1"'],
              },
            );
          }
          if (options.uri.path == fixture.pointer.catalogUrl) {
            return ResponseBody.fromBytes(
              fixture.catalogBytes,
              200,
              headers: <String, List<String>>{
                'content-type': <String>['application/json'],
              },
            );
          }
          fail('Unexpected URL requested: ${options.uri}');
        });
        final dio = Dio()..httpClientAdapter = adapter;
        final repository = CatalogRepository(
          dio: dio,
          config: config,
          verifier: verifier,
          clock: () => DateTime.utc(2026, 11, 27, 10, 5),
        );

        final result = await repository.fetchCatalog();

        expect(result.fromCache, isFalse);
        expect(result.notModified, isFalse);
        expect(result.isOfflineFallback, isFalse);
        expect(result.pointer.catalogSha256, fixture.catalogSha256);
        expect(
          result.catalog.entries.single.tile.iconUrl,
          'http://127.0.0.1:8787/art/icon.webp',
        );
        expect(repository.cachedEtag, '"etag-v1"');
        expect(adapter.requests.length, 2);
      },
    );

    test('sends If-None-Match and reuses cached catalog on 304', () async {
      final fixture = await _buildSignedFixture(
        keyPair: devKeyPair,
        generatedAtRaw: '2026-11-27T10:00:00Z',
        entryName: 'Thor Wayfinder',
      );
      var pointerCalls = 0;
      final adapter = _FakeHttpClientAdapter((options) async {
        if (options.uri.path == '/pointer.json') {
          pointerCalls++;
          if (pointerCalls == 1) {
            return ResponseBody.fromBytes(
              utf8.encode(fixture.pointerJson),
              200,
              headers: <String, List<String>>{
                'etag': <String>['"etag-v1"'],
              },
            );
          }
          expect(options.headers['If-None-Match'], '"etag-v1"');
          return ResponseBody.fromBytes(const <int>[], 304);
        }
        return ResponseBody.fromBytes(fixture.catalogBytes, 200);
      });
      final dio = Dio()..httpClientAdapter = adapter;
      final repository = CatalogRepository(
        dio: dio,
        config: config,
        verifier: verifier,
      );

      final first = await repository.fetchCatalog();
      final second = await repository.fetchCatalog();

      expect(first.fromCache, isFalse);
      expect(second.fromCache, isTrue);
      expect(second.notModified, isTrue);
      expect(second.isOfflineFallback, isFalse);
      expect(second.catalog, first.catalog);
      expect(adapter.requests.length, 3);
    });

    test('falls back to last verified catalog when offline', () async {
      final fixture = await _buildSignedFixture(
        keyPair: devKeyPair,
        generatedAtRaw: '2026-11-27T10:00:00Z',
        entryName: 'Thor Wayfinder',
      );
      var failNetwork = false;
      final adapter = _FakeHttpClientAdapter((options) async {
        if (failNetwork) {
          throw DioException(
            requestOptions: options,
            type: DioExceptionType.connectionError,
            message: 'No route to host',
          );
        }
        if (options.uri.path == '/pointer.json') {
          return ResponseBody.fromBytes(utf8.encode(fixture.pointerJson), 200);
        }
        return ResponseBody.fromBytes(fixture.catalogBytes, 200);
      });
      final dio = Dio()..httpClientAdapter = adapter;
      final repository = CatalogRepository(
        dio: dio,
        config: config,
        verifier: verifier,
      );

      final online = await repository.fetchCatalog();
      failNetwork = true;
      final offline = await repository.fetchCatalog();

      expect(offline.fromCache, isTrue);
      expect(offline.notModified, isFalse);
      expect(offline.isOfflineFallback, isTrue);
      expect(offline.error, isA<DioException>());
      expect(offline.catalog, online.catalog);
    });

    test('hydrates persisted cache on cold start when offline', () async {
      final fixture = await _buildSignedFixture(
        keyPair: devKeyPair,
        generatedAtRaw: '2026-11-27T10:00:00Z',
        entryName: 'Cached Entry',
      );
      final tempDir = await Directory.systemTemp.createTemp(
        'tshop_catalog_cache_test_',
      );
      addTearDown(() async {
        if (tempDir.existsSync()) {
          await tempDir.delete(recursive: true);
        }
      });

      final cacheStore = FileCatalogCacheStore(
        directoryProvider: () async => tempDir,
      );
      await cacheStore.write(
        CachedCatalogSnapshot(
          pointerJson: fixture.pointerJson,
          catalogBytes: fixture.catalogBytes,
          savedAt: DateTime.utc(2026, 11, 27, 10),
          etag: '"etag-disk"',
        ),
      );

      final adapter = _FakeHttpClientAdapter((options) async {
        throw DioException(
          requestOptions: options,
          type: DioExceptionType.connectionError,
          message: 'Offline',
        );
      });
      final dio = Dio()..httpClientAdapter = adapter;
      final repository = CatalogRepository(
        dio: dio,
        config: config,
        verifier: verifier,
        cacheStore: cacheStore,
      );

      final result = await repository.fetchCatalog();

      expect(result.isOfflineFallback, isTrue);
      expect(result.catalog.entries.single.name.resolve(), 'Cached Entry');
      expect(repository.cachedEtag, '"etag-disk"');
    });

    test('throws when offline with no cached catalog', () async {
      final adapter = _FakeHttpClientAdapter((options) async {
        throw DioException(
          requestOptions: options,
          type: DioExceptionType.connectionError,
          message: 'Offline',
        );
      });
      final dio = Dio()..httpClientAdapter = adapter;
      final repository = CatalogRepository(
        dio: dio,
        config: config,
        verifier: verifier,
      );

      await expectLater(
        repository.fetchCatalog(),
        throwsA(isA<DioException>()),
      );
    });

    test('never swallows verification errors even when cache exists', () async {
      final good = await _buildSignedFixture(
        keyPair: devKeyPair,
        generatedAtRaw: '2026-11-27T10:00:00Z',
        entryName: 'Good Entry',
      );
      final older = await _buildSignedFixture(
        keyPair: devKeyPair,
        generatedAtRaw: '2026-11-26T10:00:00Z',
        entryName: 'Downgraded Entry',
      );
      var serveOlder = false;
      final adapter = _FakeHttpClientAdapter((options) async {
        final active = serveOlder ? older : good;
        if (options.uri.path == '/pointer.json') {
          return ResponseBody.fromBytes(utf8.encode(active.pointerJson), 200);
        }
        return ResponseBody.fromBytes(active.catalogBytes, 200);
      });
      final dio = Dio()..httpClientAdapter = adapter;
      final repository = CatalogRepository(
        dio: dio,
        config: config,
        verifier: verifier,
      );

      await repository.fetchCatalog();
      serveOlder = true;

      await expectLater(
        repository.fetchCatalog(),
        throwsA(
          isA<CatalogVerificationException>().having(
            (e) => e.failure,
            'failure',
            CatalogVerificationFailure.downgradeDetected,
          ),
        ),
      );
      expect(
        repository.cachedCatalog?.entries.single.name.resolve(),
        'Good Entry',
      );
    });
  });

  group('catalogProvider & catalogEntryProvider', () {
    test('loads catalog, looks up entry, and refreshes cleanly', () async {
      final devKeyPair = await Ed25519().newKeyPairFromSeed(
        base64Decode(_devSeedBase64),
      );
      final v1 = await _buildSignedFixture(
        keyPair: devKeyPair,
        generatedAtRaw: '2026-11-27T10:00:00Z',
        entryName: 'Thor Wayfinder v1',
      );
      final v2 = await _buildSignedFixture(
        keyPair: devKeyPair,
        generatedAtRaw: '2026-11-27T11:00:00Z',
        entryName: 'Thor Wayfinder v2',
      );

      var active = v1;
      final adapter = _FakeHttpClientAdapter((options) async {
        if (options.uri.path == '/pointer.json') {
          return ResponseBody.fromBytes(utf8.encode(active.pointerJson), 200);
        }
        return ResponseBody.fromBytes(active.catalogBytes, 200);
      });
      final dio = Dio()..httpClientAdapter = adapter;
      final config = TshopConfig(
        catalogBaseUrl: Uri.parse('http://127.0.0.1:8787'),
      );
      final repository = CatalogRepository(
        dio: dio,
        config: config,
        verifier: CatalogVerifier(),
      );

      final container = ProviderContainer(
        overrides: [
          catalogRepositoryProvider.overrideWithValue(repository),
        ],
      );
      addTearDown(container.dispose);

      final initialState = await container.read(catalogProvider.future);
      expect(initialState.isOffline, isFalse);
      expect(initialState.isRefreshing, isFalse);
      expect(
        container
            .read(catalogEntryProvider('dev.anais.thorwayfinder'))
            ?.name
            .resolve(),
        'Thor Wayfinder v1',
      );
      expect(container.read(catalogEntryProvider('missing.pkg')), isNull);

      active = v2;
      await container.read(catalogProvider.notifier).refresh();

      final refreshedState = container.read(catalogProvider).requireValue;
      expect(refreshedState.isRefreshing, isFalse);
      expect(
        container
            .read(catalogEntryProvider('dev.anais.thorwayfinder'))
            ?.name
            .resolve(),
        'Thor Wayfinder v2',
      );
    });
  });
}

class _SignedFixture {
  const _SignedFixture({
    required this.pointer,
    required this.pointerJson,
    required this.catalogBytes,
    required this.catalogSha256,
  });

  final CatalogPointer pointer;
  final String pointerJson;
  final Uint8List catalogBytes;
  final String catalogSha256;
}

Future<_SignedFixture> _buildSignedFixture({
  required SimpleKeyPair keyPair,
  required String generatedAtRaw,
  required String entryName,
}) async {
  final catalogMap = <String, dynamic>{
    'schemaVersion': 1,
    'generatedAt': generatedAtRaw,
    'apkBaseUrl': '/apk',
    'client': null,
    'capabilityTags': <Map<String, dynamic>>[],
    'categories': <Map<String, dynamic>>[
      <String, dynamic>{
        'id': 'Frontends',
        'name': <String, dynamic>{'en': 'Frontends'},
        'entries': <String>['dev.anais.thorwayfinder'],
      },
    ],
    'entries': <Map<String, dynamic>>[
      <String, dynamic>{
        'packageName': 'dev.anais.thorwayfinder',
        'slug': 'thor-wayfinder',
        'rank': 1,
        'name': <String, dynamic>{'en': entryName},
        'publisher': 'Anais Betts',
        'category': 'Frontends',
        'searchTags': <String>['launcher'],
        'summary': <String, dynamic>{'en': 'Dual-screen launcher'},
        'description': <String, dynamic>{
          'en': <String>['Built for AYN Thor.'],
        },
        'compatNotes': null,
        'homepageUrl': 'https://github.com/anaisbetts/thor-wayfinder',
        'rehostMode': 'rehost',
        'landing': null,
        'allowedSigningCerts': <String>['aa:bb'],
        'capabilities': <String>[],
        'tile': <String, dynamic>{
          'iconUrl': '/art/icon.webp',
          'backdropColors': <String>['#1a365d'],
          'backdropAngle': 160,
          'iconScale': 0.9,
        },
        'featureUrl': null,
        'screenshots': <Map<String, dynamic>>[],
        'release': null,
        'changelogs': <Map<String, dynamic>>[],
      },
    ],
  };

  final catalogBytes = Uint8List.fromList(utf8.encode(jsonEncode(catalogMap)));
  final catalogSha256 = sha256.convert(catalogBytes).toString();
  final unsigned = CatalogPointer(
    schemaVersion: 1,
    minClientVersionCode: 100,
    generatedAt: DateTime.parse(generatedAtRaw),
    generatedAtRaw: generatedAtRaw,
    keyId: devSigningKeyId,
    catalogUrl: '/catalog/catalog-$catalogSha256.json',
    catalogSha256: catalogSha256,
    catalogSize: catalogBytes.length,
    statsUrl: 'https://stats.tshop.example/',
    signature: '',
  );
  final sig = await Ed25519().sign(
    CatalogVerifier.canonicalPointerBytes(unsigned),
    keyPair: keyPair,
  );
  final pointer = CatalogPointer(
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
  return _SignedFixture(
    pointer: pointer,
    pointerJson: jsonEncode(pointer.toJson()),
    catalogBytes: catalogBytes,
    catalogSha256: catalogSha256,
  );
}
