import 'package:flutter_test/flutter_test.dart';
import 'package:tshop/src/catalog/catalog_models.dart';
import 'package:tshop/src/install/variant_selector.dart';
import 'package:tshop/src/platform/app_services.dart';

void main() {
  group('variant_selector', () {
    test('universal APK (abis: []) matches any device', () {
      final universal = _variant(
        sha256: 'aaaa',
        abis: const <String>[],
      );
      final release = _release(variants: <CatalogVariant>[universal]);

      const arm64Device = DeviceInfo(
        supportedAbis: <String>['arm64-v8a', 'armeabi-v7a'],
        sdkInt: 34,
        hasPServiceBridge: false,
      );
      const x86Device = DeviceInfo(
        supportedAbis: <String>['x86_64'],
        sdkInt: 31,
        hasPServiceBridge: false,
      );

      expect(selectCompatibleVariants(release, arm64Device), [universal]);
      expect(pickBestVariant(release, arm64Device), universal);
      expect(selectCompatibleVariants(release, x86Device), [universal]);
      expect(pickBestVariant(release, x86Device), universal);
    });

    test('prioritizes device ABI order and filters incompatible ABIs', () {
      final x86Variant = _variant(
        sha256: '1111',
        abis: const <String>['x86_64'],
      );
      final arm32Variant = _variant(
        sha256: '2222',
        abis: const <String>['armeabi-v7a'],
      );
      final arm64Variant = _variant(
        sha256: '3333',
        abis: const <String>['arm64-v8a'],
      );
      final universalVariant = _variant(
        sha256: '4444',
        abis: const <String>[],
      );
      final release = _release(
        variants: <CatalogVariant>[
          x86Variant,
          universalVariant,
          arm32Variant,
          arm64Variant,
        ],
      );

      const thorDevice = DeviceInfo(
        supportedAbis: <String>['arm64-v8a', 'armeabi-v7a'],
        sdkInt: 33,
        hasPServiceBridge: true,
      );

      final compatible = selectCompatibleVariants(release, thorDevice);
      expect(compatible, [arm64Variant, arm32Variant, universalVariant]);
      expect(pickBestVariant(release, thorDevice), arm64Variant);

      const x86Device = DeviceInfo(
        supportedAbis: <String>['x86_64'],
        sdkInt: 33,
        hasPServiceBridge: false,
      );
      expect(selectCompatibleVariants(release, x86Device), [
        x86Variant,
        universalVariant,
      ]);
      expect(pickBestVariant(release, x86Device), x86Variant);
    });

    test('filters variants by minSdk when device.sdkInt > 0', () {
      final modern = _variant(
        sha256: 'aaaa',
        abis: const <String>['arm64-v8a'],
        minSdk: 31,
      );
      final legacy = _variant(
        sha256: 'bbbb',
        abis: const <String>['arm64-v8a'],
      );
      final release = _release(variants: <CatalogVariant>[modern, legacy]);

      const android10 = DeviceInfo(
        supportedAbis: <String>['arm64-v8a'],
        sdkInt: 29,
        hasPServiceBridge: false,
      );
      expect(selectCompatibleVariants(release, android10), [legacy]);
      expect(pickBestVariant(release, android10), legacy);

      const tooOld = DeviceInfo(
        supportedAbis: <String>['arm64-v8a'],
        sdkInt: 21,
        hasPServiceBridge: false,
      );
      final selection = resolveVariantSelection(release, tooOld);
      expect(selection.compatibleVariants, isEmpty);
      expect(selection.bestVariant, isNull);
      expect(selection.hasCompatibleVariant, isFalse);
      expect(selection.needsUserChoice, isFalse);
    });

    test('returns all variants on web/stub when sdkInt == 0', () {
      final v1 = _variant(
        sha256: 'aaaa',
        abis: const <String>['arm64-v8a'],
        minSdk: 31,
      );
      final v2 = _variant(
        sha256: 'bbbb',
        abis: const <String>['armeabi-v7a'],
        minSdk: 26,
      );
      final release = _release(variants: <CatalogVariant>[v1, v2]);

      const webStubDevice = DeviceInfo(
        supportedAbis: <String>[],
        sdkInt: 0,
        hasPServiceBridge: false,
      );

      expect(selectCompatibleVariants(release, webStubDevice), [v1, v2]);
      expect(pickBestVariant(release, webStubDevice), v1);
    });

    test(
      'sets needsUserChoice only when variantsAreUserChoice and >1 match',
      () {
        final standard = _variant(
          sha256: 'aaaa',
          abis: const <String>['arm64-v8a'],
          minSdk: 26,
          label: 'Standard',
        );
        final turnip = _variant(
          sha256: 'bbbb',
          abis: const <String>['arm64-v8a'],
          minSdk: 31,
          label: 'Optimized',
        );

        final choiceRelease = _release(
          variantsAreUserChoice: true,
          variants: <CatalogVariant>[standard, turnip],
        );
        final autoRelease = _release(
          variants: <CatalogVariant>[standard, turnip],
        );

        const android14 = DeviceInfo(
          supportedAbis: <String>['arm64-v8a'],
          sdkInt: 34,
          hasPServiceBridge: false,
        );
        const android10 = DeviceInfo(
          supportedAbis: <String>['arm64-v8a'],
          sdkInt: 29,
          hasPServiceBridge: false,
        );

        final twoMatch = resolveVariantSelection(choiceRelease, android14);
        expect(twoMatch.compatibleVariants, [standard, turnip]);
        expect(twoMatch.needsUserChoice, isTrue);
        expect(needsUserChoice(choiceRelease, android14), isTrue);

        // Only one compatible variant on Android 10 -> no dialog needed.
        final oneMatch = resolveVariantSelection(choiceRelease, android10);
        expect(oneMatch.compatibleVariants, [standard]);
        expect(oneMatch.needsUserChoice, isFalse);
        expect(needsUserChoice(choiceRelease, android10), isFalse);

        // variantsAreUserChoice == false -> never prompts even with 2 matches.
        final autoMatch = resolveVariantSelection(autoRelease, android14);
        expect(autoMatch.compatibleVariants, [standard, turnip]);
        expect(autoMatch.needsUserChoice, isFalse);
      },
    );
  });
}

CatalogRelease _release({
  required List<CatalogVariant> variants,
  bool variantsAreUserChoice = false,
}) {
  return CatalogRelease(
    versionCode: 100,
    versionName: '1.0.0',
    releasedAt: DateTime.utc(2026, 11),
    variantsAreUserChoice: variantsAreUserChoice,
    variants: variants,
  );
}

CatalogVariant _variant({
  required String sha256,
  required List<String> abis,
  int minSdk = 24,
  String? label,
}) {
  return CatalogVariant(
    sha256: sha256,
    sizeBytes: 4 * 1024 * 1024,
    abis: abis,
    minSdk: minSdk,
    targetSdk: 35,
    label: label == null ? null : LocalizedText(<String, String>{'en': label}),
    upstreamUrl: 'https://example.com/$sha256.apk',
  );
}
