import 'package:flutter_test/flutter_test.dart';
import 'package:tshop/src/catalog/catalog_models.dart';
import 'package:tshop/src/install/app_install_state.dart';
import 'package:tshop/src/platform/app_services.dart';

void main() {
  group('app_install_state', () {
    final variant = CatalogVariant(
      sha256: 'deadbeef' * 8,
      sizeBytes: 4613734,
      abis: const <String>['arm64-v8a'],
      minSdk: 26,
      targetSdk: 35,
      upstreamUrl: 'https://upstream.example/app.apk',
    );

    CatalogEntry makeEntry({
      String packageName = 'org.example.emu',
      RehostMode rehostMode = RehostMode.rehost,
      List<String> allowedSigningCerts = const <String>['aa:bb:cc:dd'],
      List<String> capabilities = const <String>[],
      int? versionCode = 200,
    }) {
      return CatalogEntry(
        packageName: packageName,
        slug: 'emu',
        rank: 1,
        name: LocalizedText(const <String, String>{'en': 'Example Emu'}),
        publisher: 'Example',
        category: 'Emulators',
        searchTags: const <String>[],
        summary: LocalizedText(const <String, String>{'en': 'Summary'}),
        description: LocalizedStringList(const <String, List<String>>{
          'en': <String>['Description'],
        }),
        homepageUrl: 'https://example.com',
        rehostMode: rehostMode,
        landing: rehostMode == RehostMode.landing
            ? CatalogLanding(
                reason: LocalizedText(const <String, String>{
                  'en': 'Publisher direct download.',
                }),
                url: 'https://example.com/download',
              )
            : null,
        allowedSigningCerts: allowedSigningCerts,
        capabilities: capabilities,
        tile: CatalogTile(
          iconUrl: '/art/icon.webp',
          backdropColors: const <String>['#123456'],
          backdropAngle: 145,
          iconScale: 0.9,
        ),
        screenshots: const <CatalogScreenshot>[],
        release: rehostMode == RehostMode.landing
            ? null
            : CatalogRelease(
                versionCode: versionCode,
                versionName: '2.0.0',
                releasedAt: DateTime.utc(2026, 11),
                variantsAreUserChoice: false,
                variants: <CatalogVariant>[variant],
              ),
        changelogs: const <CatalogChangelog>[],
      );
    }

    test('resolves available and landing statuses', () {
      final rehostEntry = makeEntry();
      final landingEntry = makeEntry(
        packageName: 'org.example.landing',
        rehostMode: RehostMode.landing,
      );

      final availableState = resolveAppInstallState(
        entry: rehostEntry,
        installedPackages: const <String, InstalledPackage>{},
      );
      expect(availableState.status, AppCatalogStatus.available);
      expect(availableState.installedPackage, isNull);
      expect(availableState.selectedVariant, variant);

      final landingState = resolveAppInstallState(
        entry: landingEntry,
        installedPackages: const <String, InstalledPackage>{},
      );
      expect(landingState.status, AppCatalogStatus.landing);
      expect(landingState.selectedVariant, isNull);
    });

    test('resolves installed, device-ahead, and version-unclear states', () {
      final entry = makeEntry();
      final exact = resolveAppInstallState(
        entry: entry,
        installedPackages: const <String, InstalledPackage>{
          'org.example.emu': InstalledPackage(
            packageName: 'org.example.emu',
            versionCode: 200,
            signingSha256: 'aabbccdd',
          ),
        },
      );
      expect(exact.status, AppCatalogStatus.installed);
      expect(exact.isDeviceAhead, isFalse);
      expect(exact.isVersionUnclear, isFalse);

      final ahead = resolveAppInstallState(
        entry: entry,
        installedPackages: const <String, InstalledPackage>{
          'org.example.emu': InstalledPackage(
            packageName: 'org.example.emu',
            versionCode: 250,
            signingSha256: 'AABBCCDD',
          ),
        },
      );
      expect(ahead.status, AppCatalogStatus.installed);
      expect(ahead.isDeviceAhead, isTrue);

      final unclearEntry = makeEntry(versionCode: null);
      final unclear = resolveAppInstallState(
        entry: unclearEntry,
        installedPackages: const <String, InstalledPackage>{
          'org.example.emu': InstalledPackage(
            packageName: 'org.example.emu',
            versionCode: 100,
            signingSha256: 'aabbccdd',
          ),
        },
      );
      expect(unclear.status, AppCatalogStatus.installed);
      expect(unclear.isVersionUnclear, isTrue);
    });

    test('resolves updateAvailable and empty-allowlist adoption', () {
      final entry = makeEntry();
      final updateState = resolveAppInstallState(
        entry: entry,
        installedPackages: const <String, InstalledPackage>{
          'org.example.emu': InstalledPackage(
            packageName: 'org.example.emu',
            versionCode: 150,
            signingSha256: 'AA:BB:CC:DD',
          ),
        },
      );
      expect(updateState.status, AppCatalogStatus.updateAvailable);

      final emptyAllowlistEntry = makeEntry(
        allowedSigningCerts: const <String>[],
      );
      final adopted = resolveAppInstallState(
        entry: emptyAllowlistEntry,
        installedPackages: const <String, InstalledPackage>{
          'org.example.emu': InstalledPackage(
            packageName: 'org.example.emu',
            versionCode: 150,
            signingSha256: '99887766',
          ),
        },
      );
      expect(adopted.status, AppCatalogStatus.updateAvailable);
    });

    test(
      'resolves otherSource and checks multi-signer cert case-insensitively',
      () {
        final entry = makeEntry(
          allowedSigningCerts: const <String>['AA:BB:CC:DD', '11:22:33:44'],
        );

        final mismatch = resolveAppInstallState(
          entry: entry,
          installedPackages: const <String, InstalledPackage>{
            'org.example.emu': InstalledPackage(
              packageName: 'org.example.emu',
              versionCode: 150,
              signingSha256: 'ffffffff',
            ),
          },
        );
        expect(mismatch.status, AppCatalogStatus.otherSource);

        final lineageMatch = resolveAppInstallState(
          entry: entry,
          installedPackages: const <String, InstalledPackage>{
            'org.example.emu': InstalledPackage(
              packageName: 'org.example.emu',
              versionCode: 200,
              signingSha256: 'eeeeeeee',
              signingSha256s: <String>['eeeeeeee', '11223344'],
            ),
          },
        );
        expect(lineageMatch.status, AppCatalogStatus.installed);
      },
    );

    test(
      'maps every InstallTaskStage to the corresponding AppCatalogStatus',
      () {
        final entry = makeEntry();
        final expected = <InstallTaskStage, AppCatalogStatus>{
          InstallTaskStage.queued: AppCatalogStatus.queued,
          InstallTaskStage.downloading: AppCatalogStatus.downloading,
          InstallTaskStage.verifying: AppCatalogStatus.verifying,
          InstallTaskStage.installing: AppCatalogStatus.installing,
          InstallTaskStage.awaitingConfirm: AppCatalogStatus.awaitingConfirm,
          InstallTaskStage.failed: AppCatalogStatus.failed,
        };

        for (final pair in expected.entries) {
          final task = InstallTask(
            packageName: entry.packageName,
            appName: 'Example Emu',
            variant: variant,
            intent: installIntentInstall,
            stage: pair.key,
            progress: 0.5,
            bytesReceived: 100,
            totalBytes: 200,
            errorMessage: pair.key == InstallTaskStage.failed ? 'Boom' : null,
          );
          final resolved = resolveAppInstallState(
            entry: entry,
            installedPackages: const <String, InstalledPackage>{},
            activeTask: task,
          );
          expect(resolved.status, pair.value);
          expect(resolved.activeTask, task);
        }
      },
    );

    test('tracks unmetCapabilities against device metCapabilities', () {
      final entry = makeEntry(
        capabilities: const <String>['gpu:adreno', 'dual-screen'],
      );
      final resolved = resolveAppInstallState(
        entry: entry,
        installedPackages: const <String, InstalledPackage>{},
        metCapabilities: const <String>{'gpu:adreno'},
      );
      expect(resolved.hasUnmetCapabilities, isTrue);
      expect(resolved.unmetCapabilities, ['dual-screen']);
    });

    test('formatByteSize formats B, KB, MB, and GB cleanly', () {
      expect(formatByteSize(-10), '0 B');
      expect(formatByteSize(0), '0 B');
      expect(formatByteSize(512), '512 B');
      expect(formatByteSize(1024), '1 KB');
      expect(formatByteSize(512 * 1024), '512 KB');
      expect(formatByteSize((4.4 * 1024 * 1024).round()), '4.4 MB');
      expect(formatByteSize(1024 * 1024 - 1), '1.0 MB');
      expect(formatByteSize((1.5 * 1024 * 1024 * 1024).round()), '1.5 GB');
    });
  });
}
