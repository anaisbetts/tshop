import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:hooks_riverpod/misc.dart';
import 'package:tshop/src/catalog/catalog_cache_store.dart';
import 'package:tshop/src/catalog/catalog_models.dart';
import 'package:tshop/src/catalog/catalog_repository.dart';
import 'package:tshop/src/catalog/catalog_verifier.dart';
import 'package:tshop/src/config/tshop_config.dart';
import 'package:tshop/src/data/remote/dio_client.dart';
import 'package:tshop/src/logging/app_talker.dart';

/// Immutable UI-facing state for the verified storefront catalog.
@immutable
class CatalogState {
  /// Creates a [CatalogState].
  const CatalogState({
    required this.catalog,
    required this.pointer,
    required this.isOffline,
    required this.isRefreshing,
    required this.lastCheckedAt,
    this.errorMessage,
  });

  /// Builds a [CatalogState] from a [CatalogFetchResult].
  factory CatalogState.fromFetchResult(CatalogFetchResult result) {
    return CatalogState(
      catalog: result.catalog,
      pointer: result.pointer,
      isOffline: result.isOfflineFallback,
      isRefreshing: false,
      errorMessage: result.error == null
          ? null
          : _formatCatalogError(result.error!),
      lastCheckedAt: result.checkedAt,
    );
  }

  /// Active verified catalog document.
  final CatalogDocument catalog;

  /// Active verified catalog pointer.
  final CatalogPointer pointer;

  /// Whether the active catalog is being shown from offline fallback cache.
  final bool isOffline;

  /// Whether a background refresh is currently in flight.
  final bool isRefreshing;

  /// Last non-fatal refresh or offline error message, if any.
  final String? errorMessage;

  /// Timestamp of the last completed refresh check.
  final DateTime lastCheckedAt;

  /// Returns a copy with updated fields.
  CatalogState copyWith({
    CatalogDocument? catalog,
    CatalogPointer? pointer,
    bool? isOffline,
    bool? isRefreshing,
    String? errorMessage,
    bool clearErrorMessage = false,
    DateTime? lastCheckedAt,
  }) {
    return CatalogState(
      catalog: catalog ?? this.catalog,
      pointer: pointer ?? this.pointer,
      isOffline: isOffline ?? this.isOffline,
      isRefreshing: isRefreshing ?? this.isRefreshing,
      errorMessage: clearErrorMessage
          ? null
          : (errorMessage ?? this.errorMessage),
      lastCheckedAt: lastCheckedAt ?? this.lastCheckedAt,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is CatalogState &&
            other.catalog == catalog &&
            other.pointer == pointer &&
            other.isOffline == isOffline &&
            other.isRefreshing == isRefreshing &&
            other.errorMessage == errorMessage &&
            other.lastCheckedAt == lastCheckedAt;
  }

  @override
  int get hashCode => Object.hash(
    catalog,
    pointer,
    isOffline,
    isRefreshing,
    errorMessage,
    lastCheckedAt,
  );
}

/// Manages loading and refreshing the verified storefront catalog.
class CatalogNotifier extends AsyncNotifier<CatalogState> {
  @override
  Future<CatalogState> build() async {
    final repository = ref.watch(catalogRepositoryProvider);
    final result = await repository.fetchCatalog();
    return CatalogState.fromFetchResult(result);
  }

  /// Refreshes the catalog from the configured origin.
  ///
  /// Preserves the last verified catalog while refreshing or when a refresh
  /// error occurs after an initial load.
  Future<void> refresh({bool forceRefresh = false}) async {
    final previous = state.value;
    if (previous != null) {
      state = AsyncData<CatalogState>(
        previous.copyWith(isRefreshing: true, clearErrorMessage: true),
      );
    } else {
      state = const AsyncLoading<CatalogState>();
    }

    try {
      final repository = ref.read(catalogRepositoryProvider);
      final result = await repository.fetchCatalog(forceRefresh: forceRefresh);
      state = AsyncData<CatalogState>(CatalogState.fromFetchResult(result));
    } on Object catch (error, stackTrace) {
      if (previous != null) {
        state = AsyncData<CatalogState>(
          previous.copyWith(
            isOffline: error is DioException,
            isRefreshing: false,
            errorMessage: _formatCatalogError(error),
          ),
        );
      } else {
        state = AsyncError<CatalogState>(error, stackTrace);
      }
    }
  }
}

/// Provides the default [CatalogVerifier] for the running build mode.
final catalogVerifierProvider = Provider<CatalogVerifier>(
  (ref) => CatalogVerifier(),
);

/// Provides the platform-appropriate [CatalogCacheStore].
final catalogCacheStoreProvider = Provider<CatalogCacheStore>(
  (ref) => createDefaultCatalogCacheStore(),
);

/// Provides the [CatalogRepository] wired to shared [Dio] and [TshopConfig].
final catalogRepositoryProvider = Provider<CatalogRepository>((ref) {
  return CatalogRepository(
    dio: ref.watch(dioProvider),
    config: ref.watch(tshopConfigProvider),
    verifier: ref.watch(catalogVerifierProvider),
    cacheStore: ref.watch(catalogCacheStoreProvider),
    talker: ref.watch(talkerProvider),
  );
});

/// Active verified catalog state with refresh support.
final catalogProvider = AsyncNotifierProvider<CatalogNotifier, CatalogState>(
  CatalogNotifier.new,
);

/// Looks up a single [CatalogEntry] by Android `packageName` from the active
/// catalog.
final ProviderFamily<CatalogEntry?, String> catalogEntryProvider = Provider
    .autoDispose
    .family<CatalogEntry?, String>((ref, packageName) {
      final catalog = ref.watch(
        catalogProvider.select((asyncState) => asyncState.value?.catalog),
      );
      return catalog?.entryByPackageName(packageName);
    });

String _formatCatalogError(Object error) {
  if (error is CatalogVerificationException) {
    return error.message;
  }
  if (error is DioException) {
    return error.message ?? 'Network request failed (${error.type.name}).';
  }
  return error.toString();
}
