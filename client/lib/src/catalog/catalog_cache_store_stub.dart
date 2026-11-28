import 'package:tshop/src/catalog/catalog_cache_store.dart';

/// Web-safe fallback cache store backed by memory.
CatalogCacheStore createPlatformCatalogCacheStore() =>
    InMemoryCatalogCacheStore();
