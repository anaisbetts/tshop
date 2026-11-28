import 'package:flutter/foundation.dart';
import 'package:tshop/src/catalog/catalog_cache_store_stub.dart'
    if (dart.library.io) 'package:tshop/src/catalog/catalog_cache_store_io.dart'
    as cache_impl;

/// Serialized last-verified catalog snapshot stored for offline fallback.
@immutable
class CachedCatalogSnapshot {
  /// Creates a [CachedCatalogSnapshot].
  const CachedCatalogSnapshot({
    required this.pointerJson,
    required this.catalogBytes,
    required this.savedAt,
    this.etag,
  });

  /// Raw `pointer.json` text (kept verbatim for signature re-verification).
  final String pointerJson;

  /// Raw `catalog-<sha256>.json` bytes (kept for SHA-256 re-verification).
  final Uint8List catalogBytes;

  /// Timestamp when this snapshot was persisted.
  final DateTime savedAt;

  /// Optional HTTP ETag received for `pointer.json`.
  final String? etag;
}

/// Persistence abstraction for the last verified catalog snapshot.
abstract interface class CatalogCacheStore {
  /// Reads the cached snapshot, or returns `null` if none is available.
  Future<CachedCatalogSnapshot?> read();

  /// Persists [snapshot], replacing any previous cached snapshot.
  Future<void> write(CachedCatalogSnapshot snapshot);

  /// Clears any cached snapshot.
  Future<void> clear();
}

/// Ephemeral in-memory [CatalogCacheStore] used on web and in unit tests.
class InMemoryCatalogCacheStore implements CatalogCacheStore {
  CachedCatalogSnapshot? _snapshot;

  @override
  Future<CachedCatalogSnapshot?> read() async => _snapshot;

  @override
  Future<void> write(CachedCatalogSnapshot snapshot) async {
    _snapshot = snapshot;
  }

  @override
  Future<void> clear() async {
    _snapshot = null;
  }
}

/// Creates the platform-appropriate [CatalogCacheStore].
///
/// Uses local app-support storage on native platforms and an in-memory store on
/// web.
CatalogCacheStore createDefaultCatalogCacheStore() =>
    cache_impl.createPlatformCatalogCacheStore();
