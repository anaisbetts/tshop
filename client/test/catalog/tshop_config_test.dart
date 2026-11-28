import 'package:flutter_test/flutter_test.dart';
import 'package:tshop/src/config/tshop_config.dart';

void main() {
  group('TshopConfig', () {
    test('uses debug web default when not release and running on web', () {
      final config = TshopConfig.fromEnvironment(
        catalogBaseUrlOverride: '',
        isReleaseMode: false,
        isWeb: true,
      );

      expect(
        config.catalogBaseUrl,
        Uri.parse(defaultDebugWebCatalogBaseUrl),
      );
      expect(config.userAgent, 'tShop/1.0.0 (Web)');
    });

    test('uses debug device default when not release and native', () {
      final config = TshopConfig.fromEnvironment(
        catalogBaseUrlOverride: '',
        isReleaseMode: false,
        isWeb: false,
      );

      expect(
        config.catalogBaseUrl,
        Uri.parse(defaultDebugDeviceCatalogBaseUrl),
      );
      expect(config.userAgent, 'tShop/1.0.0 (Android)');
    });

    test('uses release default in release mode', () {
      final config = TshopConfig.fromEnvironment(
        catalogBaseUrlOverride: '',
        isReleaseMode: true,
        isWeb: false,
      );

      expect(
        config.catalogBaseUrl,
        Uri.parse(defaultReleaseCatalogBaseUrl),
      );
    });

    test('honors explicit catalogBaseUrlOverride over defaults', () {
      final config = TshopConfig.fromEnvironment(
        catalogBaseUrlOverride: 'https://staging.tshop.dev',
        isReleaseMode: true,
        isWeb: true,
      );

      expect(config.catalogBaseUrl, Uri.parse('https://staging.tshop.dev'));
    });

    test('resolveUrl resolves relative paths and leaves absolute URLs', () {
      final config = TshopConfig(
        catalogBaseUrl: Uri.parse('http://tisiphone.snowy-sole.ts.net:8787'),
      );

      expect(
        config.pointerUri,
        Uri.parse('http://tisiphone.snowy-sole.ts.net:8787/pointer.json'),
      );
      expect(
        config.resolveUrl('/catalog/catalog-abc123.json'),
        Uri.parse(
          'http://tisiphone.snowy-sole.ts.net:8787/catalog/catalog-abc123.json',
        ),
      );
      expect(
        config.resolveUrl('/art/deadbeef.webp'),
        Uri.parse('http://tisiphone.snowy-sole.ts.net:8787/art/deadbeef.webp'),
      );
      expect(
        config.resolveUrl('/apk'),
        Uri.parse('http://tisiphone.snowy-sole.ts.net:8787/apk'),
      );
      expect(
        config.resolveUrl('https://cdn.tshop.example/apk'),
        Uri.parse('https://cdn.tshop.example/apk'),
      );
    });
  });
}
