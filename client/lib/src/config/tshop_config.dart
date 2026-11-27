import 'package:flutter/foundation.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

/// Build-time `--dart-define=TSHOP_CATALOG_BASE_URL=...` override.
const String _catalogBaseUrlDefine = String.fromEnvironment(
  'TSHOP_CATALOG_BASE_URL',
);

/// Default catalog origin used for non-release web builds.
const String defaultDebugWebCatalogBaseUrl = 'http://127.0.0.1:8787';

/// Default catalog origin used for non-release device builds.
const String defaultDebugDeviceCatalogBaseUrl =
    'http://tisiphone.snowy-sole.ts.net:8787';

/// Default catalog origin used for release builds.
const String defaultReleaseCatalogBaseUrl = 'https://catalog.tshop.example';

/// Default HTTP User-Agent string sent by tShop clients.
const String tshopUserAgent = kIsWeb
    ? 'tShop/1.0.0 (Web)'
    : 'tShop/1.0.0 (Android)';

/// Runtime configuration for the tShop catalog and network layer.
@immutable
class TshopConfig {
  /// Creates a [TshopConfig] with explicit [catalogBaseUrl] and [userAgent].
  const TshopConfig({
    required this.catalogBaseUrl,
    this.userAgent = tshopUserAgent,
  });

  /// Builds a [TshopConfig] from compile-time environment defines and defaults.
  factory TshopConfig.fromEnvironment({
    String? catalogBaseUrlOverride,
    bool? isReleaseMode,
    bool? isWeb,
    String? userAgent,
  }) {
    final override = (catalogBaseUrlOverride ?? _catalogBaseUrlDefine).trim();
    final release = isReleaseMode ?? kReleaseMode;
    final web = isWeb ?? kIsWeb;
    final rawUrl = override.isNotEmpty
        ? override
        : _defaultCatalogBaseUrl(isReleaseMode: release, isWeb: web);
    return TshopConfig(
      catalogBaseUrl: Uri.parse(rawUrl),
      userAgent:
          userAgent ?? (web ? 'tShop/1.0.0 (Web)' : 'tShop/1.0.0 (Android)'),
    );
  }

  /// Base URI for catalog endpoints (`pointer.json`, `/catalog/*`, `/art/*`).
  final Uri catalogBaseUrl;

  /// HTTP User-Agent string identifying this tShop build.
  final String userAgent;

  /// Fully resolved URI for `pointer.json`.
  Uri get pointerUri => resolveUrl('/pointer.json');

  /// Resolves [pathOrUrl] against [catalogBaseUrl].
  ///
  /// Relative paths such as `/catalog/catalog-<sha>.json`, `/apk`, and
  /// `/art/<sha>.webp` resolve against [catalogBaseUrl], while absolute URLs
  /// are returned unchanged.
  Uri resolveUrl(String pathOrUrl) => catalogBaseUrl.resolve(pathOrUrl);

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is TshopConfig &&
            other.catalogBaseUrl == catalogBaseUrl &&
            other.userAgent == userAgent;
  }

  @override
  int get hashCode => Object.hash(catalogBaseUrl, userAgent);

  @override
  String toString() =>
      'TshopConfig(catalogBaseUrl: $catalogBaseUrl, userAgent: $userAgent)';
}

/// Provides the active [TshopConfig].
final tshopConfigProvider = Provider<TshopConfig>(
  (ref) => TshopConfig.fromEnvironment(),
);

String _defaultCatalogBaseUrl({
  required bool isReleaseMode,
  required bool isWeb,
}) {
  if (isReleaseMode) {
    return defaultReleaseCatalogBaseUrl;
  }
  return isWeb
      ? defaultDebugWebCatalogBaseUrl
      : defaultDebugDeviceCatalogBaseUrl;
}
