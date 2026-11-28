import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:talker/talker.dart';
import 'package:tshop/src/catalog/catalog_cache_store.dart';
import 'package:tshop/src/catalog/catalog_models.dart';
import 'package:tshop/src/catalog/catalog_verifier.dart';
import 'package:tshop/src/config/tshop_config.dart';

/// Clock callback returning the current time.
typedef CatalogClock = DateTime Function();

/// Result of a [CatalogRepository.fetchCatalog] call.
@immutable
class CatalogFetchResult {
  /// Creates a [CatalogFetchResult].
  const CatalogFetchResult({
    required this.pointer,
    required this.catalog,
    required this.fromCache,
    required this.notModified,
    required this.checkedAt,
    this.error,
  });

  /// Verified catalog pointer for [catalog].
  final CatalogPointer pointer;

  /// Verified catalog document with relative URLs resolved.
  final CatalogDocument catalog;

  /// Whether [catalog] was served from the last verified cached copy.
  final bool fromCache;

  /// Whether the server responded with HTTP 304 Not Modified.
  final bool notModified;

  /// Timestamp of this fetch or fallback check.
  final DateTime checkedAt;

  /// Network error encountered when falling back to cached catalog data.
  final Object? error;

  /// Whether this result represents an offline fallback after a network error.
  bool get isOfflineFallback => fromCache && !notModified && error != null;
}

/// Fetches, verifies, resolves, and caches the tShop catalog.
class CatalogRepository {
  /// Creates a [CatalogRepository] with explicit dependencies.
  CatalogRepository({
    required this._dio,
    required this._config,
    required this._verifier,
    CatalogCacheStore? cacheStore,
    this._talker,
    CatalogClock? clock,
  }) : _cacheStore = cacheStore ?? InMemoryCatalogCacheStore(),
       _clock = clock ?? DateTime.now;

  final Dio _dio;
  final TshopConfig _config;
  final CatalogVerifier _verifier;
  final CatalogCacheStore _cacheStore;
  final Talker? _talker;
  final CatalogClock _clock;

  CatalogPointer? _lastPointer;
  CatalogDocument? _lastCatalog;
  Uint8List? _lastCatalogBytes;
  String? _lastEtag;
  DateTime? _lastCheckedAt;
  bool _cacheHydrated = false;

  /// Last verified [CatalogPointer] held in memory, if any.
  CatalogPointer? get cachedPointer => _lastPointer;

  /// Last verified [CatalogDocument] held in memory, if any.
  CatalogDocument? get cachedCatalog => _lastCatalog;

  /// Last cached HTTP ETag for `pointer.json`, if any.
  String? get cachedEtag => _lastEtag;

  /// Timestamp of the last completed check or hydrated cache snapshot.
  DateTime? get lastCheckedAt => _lastCheckedAt;

  /// Fetches and verifies the latest catalog from [TshopConfig.catalogBaseUrl].
  ///
  /// Uses conditional GET (`If-None-Match`) when an ETag is cached unless
  /// [forceRefresh] is `true`. Falls back to the last verified catalog if a
  /// network error occurs after at least one verified catalog has been loaded.
  /// Verification errors ([CatalogVerificationException]) are never suppressed.
  Future<CatalogFetchResult> fetchCatalog({bool forceRefresh = false}) async {
    await _hydrateCacheIfNeeded();

    final now = _clock().toUtc();
    final pointerHeaders = _buildHeaders(
      ifNoneMatch: !forceRefresh && _lastCatalog != null ? _lastEtag : null,
    );

    try {
      final pointerResponse = await _dio.get<List<int>>(
        _config.pointerUri.toString(),
        options: Options(
          responseType: ResponseType.bytes,
          headers: pointerHeaders,
          validateStatus: (status) => status == 200 || status == 304,
        ),
      );

      final statusCode = pointerResponse.statusCode;
      if (statusCode == 304) {
        if (_lastPointer != null && _lastCatalog != null) {
          _lastCheckedAt = now;
          return CatalogFetchResult(
            pointer: _lastPointer!,
            catalog: _lastCatalog!,
            fromCache: true,
            notModified: true,
            checkedAt: now,
          );
        }
        return await _fetchUnconditional(now);
      }

      return await _handlePointerResponse(
        pointerResponse,
        checkedAt: now,
        forceRefresh: forceRefresh,
      );
    } on DioException catch (error) {
      if (_lastPointer != null && _lastCatalog != null) {
        _talker?.warning(
          'Catalog refresh failed; falling back to last verified catalog: '
          '${error.message ?? error.type.name}',
        );
        return CatalogFetchResult(
          pointer: _lastPointer!,
          catalog: _lastCatalog!,
          fromCache: true,
          notModified: false,
          checkedAt: now,
          error: error,
        );
      }
      rethrow;
    }
  }

  /// Clears both the in-memory and persisted catalog caches.
  Future<void> clearCache() async {
    _lastPointer = null;
    _lastCatalog = null;
    _lastCatalogBytes = null;
    _lastEtag = null;
    _lastCheckedAt = null;
    _cacheHydrated = true;
    await _cacheStore.clear();
  }

  Future<CatalogFetchResult> _fetchUnconditional(DateTime checkedAt) async {
    final pointerResponse = await _dio.get<List<int>>(
      _config.pointerUri.toString(),
      options: Options(
        responseType: ResponseType.bytes,
        headers: _buildHeaders(),
        validateStatus: (status) => status == 200,
      ),
    );
    return _handlePointerResponse(
      pointerResponse,
      checkedAt: checkedAt,
      forceRefresh: true,
    );
  }

  Future<CatalogFetchResult> _handlePointerResponse(
    Response<List<int>> pointerResponse, {
    required DateTime checkedAt,
    required bool forceRefresh,
  }) async {
    final pointerRawJson = utf8.decode(pointerResponse.data ?? const <int>[]);
    final pointerMap = _decodeJsonObject(pointerRawJson, label: 'pointer.json');
    final pointer = CatalogPointer.fromJson(pointerMap);

    await _verifier.verifyPointer(
      pointer,
      previousGeneratedAt: _lastPointer?.generatedAt,
    );

    final newEtag = pointerResponse.headers.value('etag');
    final sameCatalogHash =
        _lastPointer != null &&
        _lastCatalog != null &&
        _lastPointer!.catalogSha256.toLowerCase() ==
            pointer.catalogSha256.toLowerCase();

    if (!forceRefresh && sameCatalogHash) {
      _lastPointer = pointer;
      _lastEtag = newEtag ?? _lastEtag;
      _lastCheckedAt = checkedAt;
      if (_lastCatalogBytes != null) {
        await _persistSnapshot(
          CachedCatalogSnapshot(
            pointerJson: pointerRawJson,
            catalogBytes: _lastCatalogBytes!,
            savedAt: checkedAt,
            etag: _lastEtag,
          ),
        );
      }
      return CatalogFetchResult(
        pointer: pointer,
        catalog: _lastCatalog!,
        fromCache: false,
        notModified: false,
        checkedAt: checkedAt,
      );
    }

    final catalogUri = _config.resolveUrl(pointer.catalogUrl);
    final catalogResponse = await _dio.get<List<int>>(
      catalogUri.toString(),
      options: Options(
        responseType: ResponseType.bytes,
        headers: _buildHeaders(),
      ),
    );
    final catalogBytes = Uint8List.fromList(
      catalogResponse.data ?? const <int>[],
    );

    _verifier.verifyCatalogBytes(catalogBytes, pointer.catalogSha256);

    final catalogMap = _decodeJsonObject(
      utf8.decode(catalogBytes),
      label: pointer.catalogUrl,
    );
    final catalog = CatalogDocument.fromJson(
      catalogMap,
    ).resolveUrls(_config.catalogBaseUrl);

    _lastPointer = pointer;
    _lastCatalog = catalog;
    _lastCatalogBytes = catalogBytes;
    _lastEtag = newEtag;
    _lastCheckedAt = checkedAt;

    await _persistSnapshot(
      CachedCatalogSnapshot(
        pointerJson: pointerRawJson,
        catalogBytes: catalogBytes,
        savedAt: checkedAt,
        etag: newEtag,
      ),
    );

    return CatalogFetchResult(
      pointer: pointer,
      catalog: catalog,
      fromCache: false,
      notModified: false,
      checkedAt: checkedAt,
    );
  }

  Future<void> _hydrateCacheIfNeeded() async {
    if (_cacheHydrated) {
      return;
    }
    _cacheHydrated = true;

    CachedCatalogSnapshot? snapshot;
    try {
      snapshot = await _cacheStore.read();
    } on Object catch (error) {
      _talker?.warning('Failed to read cached catalog snapshot: $error');
      return;
    }
    if (snapshot == null) {
      return;
    }

    try {
      final pointerMap = _decodeJsonObject(
        snapshot.pointerJson,
        label: 'cached pointer.json',
      );
      final pointer = CatalogPointer.fromJson(pointerMap);
      await _verifier.verifyPointer(pointer);
      _verifier.verifyCatalogBytes(
        snapshot.catalogBytes,
        pointer.catalogSha256,
      );
      final catalogMap = _decodeJsonObject(
        utf8.decode(snapshot.catalogBytes),
        label: 'cached catalog.json',
      );
      final catalog = CatalogDocument.fromJson(
        catalogMap,
      ).resolveUrls(_config.catalogBaseUrl);

      _lastPointer = pointer;
      _lastCatalog = catalog;
      _lastCatalogBytes = snapshot.catalogBytes;
      _lastEtag = snapshot.etag;
      _lastCheckedAt = snapshot.savedAt;
    } on Object catch (error) {
      _talker?.warning('Discarding invalid cached catalog snapshot: $error');
      try {
        await _cacheStore.clear();
      } on Object {
        // Ignore cleanup failure while discarding corrupt cache.
      }
    }
  }

  Future<void> _persistSnapshot(CachedCatalogSnapshot snapshot) async {
    try {
      await _cacheStore.write(snapshot);
    } on Object catch (error) {
      _talker?.warning('Failed to persist verified catalog snapshot: $error');
    }
  }

  Map<String, String> _buildHeaders({String? ifNoneMatch}) {
    return <String, String>{
      if (!kIsWeb) 'User-Agent': _config.userAgent,
      'If-None-Match': ?ifNoneMatch,
    };
  }
}

Map<String, dynamic> _decodeJsonObject(String raw, {required String label}) {
  final decoded = jsonDecode(raw);
  if (decoded is! Map<String, dynamic>) {
    throw FormatException('Expected JSON object for $label.');
  }
  return decoded;
}
