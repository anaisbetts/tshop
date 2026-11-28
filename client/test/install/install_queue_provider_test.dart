import 'dart:async';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:talker/talker.dart';
import 'package:tshop/src/catalog/catalog_models.dart';
import 'package:tshop/src/catalog/catalog_provider.dart';
import 'package:tshop/src/config/tshop_config.dart';
import 'package:tshop/src/install/apk_downloader.dart';
import 'package:tshop/src/install/apk_downloader_io.dart';
import 'package:tshop/src/install/apk_downloader_stub.dart';
import 'package:tshop/src/install/app_install_state.dart';
import 'package:tshop/src/install/install_queue_provider.dart';
import 'package:tshop/src/logging/app_talker.dart';
import 'package:tshop/src/platform/app_services.dart';

void main() {
  group('InstallQueueNotifier & derived providers', () {
    test(
      'silent PServiceBridge install transitions downloading -> verifying -> '
      'installing -> installed and refreshes installedPackagesProvider',
      () async {
        final fakeServices = _FakeAppServices(
          device: const DeviceInfo(
            supportedAbis: <String>['arm64-v8a'],
            sdkInt: 34,
            hasPServiceBridge: true,
          ),
        );
        final fakeDownloader = _FakeApkDownloader(
          onDownload: (request) async {
            request.onProgress?.call(512, 1024);
            request.onProgress?.call(1024, 1024);
            request.onVerifying?.call();
            return '/tmp/tshop_apks/${request.expectedSha256}.apk';
          },
        );
        final entry = _makeEntry(
          packageName: 'org.example.retroarch',
          name: 'RetroArch',
          versionCode: 200,
          sha256: 'a' * 64,
        );

        final container = _createTestContainer(
          services: fakeServices,
          downloader: fakeDownloader,
          entries: <CatalogEntry>[entry],
        );
        addTearDown(() async {
          container.dispose();
          await fakeServices.close();
        });

        await container.read(catalogProvider.future);
        await container.read(installedPackagesProvider.future);
        await container.read(deviceInfoProvider.future);

        final observedStages = <InstallTaskStage?>[];
        container.listen<InstallTask?>(
          installQueueProvider.select(
            (queue) => queue.taskFor(entry.packageName),
          ),
          (previous, next) {
            observedStages.add(next?.stage);
          },
        );

        expect(
          container.read(resolvedAppStateProvider(entry.packageName))?.status,
          AppCatalogStatus.available,
        );

        await container
            .read(installQueueProvider.notifier)
            .enqueueInstall(
              entry,
            );
        await _pumpMicrotasks();

        // Wait until installApkFile has been called and stage is installing.
        expect(fakeServices.installedFileCalls, hasLength(1));
        expect(
          fakeServices.installedFileCalls.single.packageName,
          entry.packageName,
        );
        expect(
          container
              .read(installQueueProvider)
              .taskFor(entry.packageName)
              ?.stage,
          InstallTaskStage.installing,
        );
        expect(
          fakeDownloader.requests.single.uri.toString(),
          'http://127.0.0.1:8787/apk/${'a' * 64}.apk?r=install',
        );

        // Simulate PServiceBridge completion and package becoming present.
        fakeServices
          ..installedPackages = <InstalledPackage>[
            const InstalledPackage(
              packageName: 'org.example.retroarch',
              versionCode: 200,
              signingSha256: 'aabbccdd',
            ),
          ]
          ..emitInstallEvent(
            InstallSucceeded(packageName: entry.packageName, sessionId: 0),
          );
        await _pumpMicrotasks();

        expect(
          observedStages,
          containsAllInOrder(<InstallTaskStage?>[
            InstallTaskStage.queued,
            InstallTaskStage.downloading,
            InstallTaskStage.verifying,
            InstallTaskStage.installing,
            null,
          ]),
        );
        expect(
          container.read(installQueueProvider).taskFor(entry.packageName),
          isNull,
        );
        expect(
          container.read(resolvedAppStateProvider(entry.packageName))?.status,
          AppCatalogStatus.installed,
        );
        expect(fakeDownloader.deletedSha256s, contains('a' * 64));
      },
    );

    test(
      'PackageInstaller fallback transitions awaitingConfirm -> '
      'confirmPendingInstall -> InstallSucceeded',
      () async {
        final fakeServices = _FakeAppServices(
          device: const DeviceInfo(
            supportedAbis: <String>['arm64-v8a'],
            sdkInt: 34,
            hasPServiceBridge: false,
          ),
        );
        final fakeDownloader = _FakeApkDownloader(
          onDownload: (request) async => '/tmp/${request.expectedSha256}.apk',
        );
        final entry = _makeEntry(
          packageName: 'org.example.dolphin',
          name: 'Dolphin',
          versionCode: 300,
          sha256: 'b' * 64,
        );

        final container = _createTestContainer(
          services: fakeServices,
          downloader: fakeDownloader,
          entries: <CatalogEntry>[entry],
        );
        addTearDown(() async {
          container.dispose();
          await fakeServices.close();
        });

        await container.read(catalogProvider.future);
        await container.read(installedPackagesProvider.future);

        await container
            .read(installQueueProvider.notifier)
            .enqueueInstall(
              entry,
            );
        await _pumpMicrotasks();

        fakeServices.emitInstallEvent(
          InstallAwaitingConfirmation(
            packageName: entry.packageName,
            sessionId: 42,
          ),
        );
        await _pumpMicrotasks();

        final awaiting = container
            .read(installQueueProvider)
            .taskFor(entry.packageName);
        expect(awaiting?.stage, InstallTaskStage.awaitingConfirm);
        expect(awaiting?.sessionId, 42);
        expect(
          container.read(resolvedAppStateProvider(entry.packageName))?.status,
          AppCatalogStatus.awaitingConfirm,
        );

        final launched = await container
            .read(installQueueProvider.notifier)
            .confirmPendingInstall(entry.packageName);
        expect(launched, isTrue);
        expect(fakeServices.confirmedPackages, [entry.packageName]);

        fakeServices
          ..installedPackages = <InstalledPackage>[
            const InstalledPackage(
              packageName: 'org.example.dolphin',
              versionCode: 300,
              signingSha256: 'aabbccdd',
            ),
          ]
          ..emitInstallEvent(
            InstallSucceeded(packageName: entry.packageName, sessionId: 42),
          );
        await _pumpMicrotasks();

        expect(
          container.read(installQueueProvider).taskFor(entry.packageName),
          isNull,
        );
        expect(
          container.read(resolvedAppStateProvider(entry.packageName))?.status,
          AppCatalogStatus.installed,
        );
      },
    );

    test(
      'SHA-256 mismatch marks failed, supports retry and dismiss',
      () async {
        var shouldFail = true;
        final fakeServices = _FakeAppServices(
          device: const DeviceInfo(
            supportedAbis: <String>['arm64-v8a'],
            sdkInt: 34,
            hasPServiceBridge: true,
          ),
        );
        final fakeDownloader = _FakeApkDownloader(
          onDownload: (request) async {
            if (shouldFail) {
              throw ApkVerificationException(
                expectedSha256: request.expectedSha256,
                actualSha256: '0' * 64,
                uri: request.uri,
              );
            }
            return '/tmp/${request.expectedSha256}.apk';
          },
        );
        final entry = _makeEntry(
          packageName: 'org.example.ppsspp',
          name: 'PPSSPP',
          versionCode: 100,
          sha256: 'c' * 64,
        );

        final container = _createTestContainer(
          services: fakeServices,
          downloader: fakeDownloader,
          entries: <CatalogEntry>[entry],
        );
        addTearDown(() async {
          container.dispose();
          await fakeServices.close();
        });

        await container.read(catalogProvider.future);
        await container.read(installedPackagesProvider.future);

        await container
            .read(installQueueProvider.notifier)
            .enqueueInstall(
              entry,
            );
        await _pumpMicrotasks();

        final failed = container
            .read(installQueueProvider)
            .taskFor(entry.packageName);
        expect(failed?.stage, InstallTaskStage.failed);
        expect(failed?.needsInstallPermission, isFalse);
        expect(failed?.errorMessage, contains('SHA-256'));
        expect(fakeServices.installedFileCalls, isEmpty);

        // Dismiss removes failed item cleanly.
        container
            .read(installQueueProvider.notifier)
            .dismissFailed(entry.packageName);
        expect(
          container.read(installQueueProvider).taskFor(entry.packageName),
          isNull,
        );

        // Enqueue again while still failing, then retry after fixing.
        await container
            .read(installQueueProvider.notifier)
            .enqueueInstall(
              entry,
            );
        await _pumpMicrotasks();
        expect(
          container
              .read(installQueueProvider)
              .taskFor(entry.packageName)
              ?.stage,
          InstallTaskStage.failed,
        );

        shouldFail = false;
        await container.read(installQueueProvider.notifier).retryTask(entry);
        await _pumpMicrotasks();

        expect(
          container
              .read(installQueueProvider)
              .taskFor(entry.packageName)
              ?.stage,
          InstallTaskStage.installing,
        );
        expect(fakeServices.installedFileCalls, hasLength(1));
      },
    );

    test(
      'missing canRequestPackageInstalls sets needsInstallPermission: true',
      () async {
        final fakeServices = _FakeAppServices(
          device: const DeviceInfo(
            supportedAbis: <String>['arm64-v8a'],
            sdkInt: 34,
            hasPServiceBridge: false,
          ),
          canRequestInstalls: false,
        );
        final fakeDownloader = _FakeApkDownloader(
          onDownload: (request) async => '/tmp/${request.expectedSha256}.apk',
        );
        final entry = _makeEntry(
          packageName: 'org.example.flycast',
          name: 'Flycast',
          versionCode: 100,
          sha256: 'd' * 64,
        );

        final container = _createTestContainer(
          services: fakeServices,
          downloader: fakeDownloader,
          entries: <CatalogEntry>[entry],
        );
        addTearDown(() async {
          container.dispose();
          await fakeServices.close();
        });

        await container.read(catalogProvider.future);
        await container.read(installedPackagesProvider.future);

        await container
            .read(installQueueProvider.notifier)
            .enqueueInstall(
              entry,
            );
        await _pumpMicrotasks();

        final task = container
            .read(installQueueProvider)
            .taskFor(entry.packageName);
        expect(task?.stage, InstallTaskStage.failed);
        expect(task?.needsInstallPermission, isTrue);
        expect(fakeDownloader.requests, isEmpty);
      },
    );

    test(
      'enforces max 2 concurrent downloads and 1 active install handoff',
      () async {
        final fakeServices = _FakeAppServices(
          device: const DeviceInfo(
            supportedAbis: <String>['arm64-v8a'],
            sdkInt: 34,
            hasPServiceBridge: true,
          ),
        );
        final completers = <String, Completer<String>>{};
        final fakeDownloader = _FakeApkDownloader(
          onDownload: (request) {
            final completer = Completer<String>();
            completers[request.expectedSha256] = completer;
            return completer.future;
          },
        );

        final e1 = _makeEntry(
          packageName: 'org.example.one',
          name: 'One',
          versionCode: 10,
          sha256: '1' * 64,
        );
        final e2 = _makeEntry(
          packageName: 'org.example.two',
          name: 'Two',
          versionCode: 10,
          sha256: '2' * 64,
        );
        final e3 = _makeEntry(
          packageName: 'org.example.three',
          name: 'Three',
          versionCode: 10,
          sha256: '3' * 64,
        );

        final container = _createTestContainer(
          services: fakeServices,
          downloader: fakeDownloader,
          entries: <CatalogEntry>[e1, e2, e3],
        );
        addTearDown(() async {
          container.dispose();
          await fakeServices.close();
        });

        await container.read(catalogProvider.future);
        await container.read(installedPackagesProvider.future);

        final notifier = container.read(installQueueProvider.notifier);
        await notifier.enqueueInstall(e1);
        await notifier.enqueueInstall(e2);
        await notifier.enqueueInstall(e3);
        await _pumpMicrotasks();

        // Only 2 downloads run concurrently; 3rd waits in queued stage.
        expect(completers.keys, hasLength(2));
        expect(
          container.read(installQueueProvider).taskFor(e1.packageName)?.stage,
          InstallTaskStage.downloading,
        );
        expect(
          container.read(installQueueProvider).taskFor(e2.packageName)?.stage,
          InstallTaskStage.downloading,
        );
        expect(
          container.read(installQueueProvider).taskFor(e3.packageName)?.stage,
          InstallTaskStage.queued,
        );

        // Finish downloads 1 & 2; download 3 starts, only 1 install starts.
        completers['1' * 64]!.complete('/tmp/1.apk');
        completers['2' * 64]!.complete('/tmp/2.apk');
        await _pumpMicrotasks();

        expect(completers.containsKey('3' * 64), isTrue);
        expect(fakeServices.installedFileCalls, hasLength(1));
        expect(
          fakeServices.installedFileCalls.single.packageName,
          e1.packageName,
        );
        expect(
          container.read(installQueueProvider).taskFor(e1.packageName)?.stage,
          InstallTaskStage.installing,
        );
        expect(
          container.read(installQueueProvider).taskFor(e2.packageName)?.stage,
          InstallTaskStage.verifying,
        );

        // Once install 1 succeeds, install 2 begins automatically.
        fakeServices.emitInstallEvent(
          InstallSucceeded(packageName: e1.packageName, sessionId: 0),
        );
        await _pumpMicrotasks();

        expect(fakeServices.installedFileCalls, hasLength(2));
        expect(
          fakeServices.installedFileCalls[1].packageName,
          e2.packageName,
        );

        // Cancel in-flight download 3.
        await notifier.cancelTask(e3.packageName);
        await _pumpMicrotasks();
        expect(
          fakeDownloader.requests.last.cancelToken?.isCancelled,
          isTrue,
        );
        expect(
          container.read(installQueueProvider).taskFor(e3.packageName),
          isNull,
        );

        // Move install 2 to awaitingConfirm, then cancel it.
        fakeServices.emitInstallEvent(
          InstallAwaitingConfirmation(
            packageName: e2.packageName,
            sessionId: 77,
          ),
        );
        await _pumpMicrotasks();
        await notifier.cancelTask(e2.packageName);
        expect(fakeServices.cancelledConfirmations, [e2.packageName]);
        expect(
          container.read(installQueueProvider).taskFor(e2.packageName),
          isNull,
        );
      },
    );

    test(
      'Privacy Mode downloads from upstreamUrl and never falls back on error',
      () async {
        final fakeServices = _FakeAppServices(
          device: const DeviceInfo(
            supportedAbis: <String>['arm64-v8a'],
            sdkInt: 34,
            hasPServiceBridge: true,
          ),
        );
        final fakeDownloader = _FakeApkDownloader(
          onDownload: (request) async {
            throw DioException(
              requestOptions: RequestOptions(path: request.uri.toString()),
              type: DioExceptionType.connectionError,
              message: 'Upstream unreachable',
            );
          },
        );
        final entry = _makeEntry(
          packageName: 'org.example.priv',
          name: 'Privacy App',
          versionCode: 10,
          sha256: 'e' * 64,
          upstreamUrl: 'https://upstream.example/releases/priv.apk',
        );

        final container = _createTestContainer(
          services: fakeServices,
          downloader: fakeDownloader,
          entries: <CatalogEntry>[entry],
        );
        addTearDown(() async {
          container.dispose();
          await fakeServices.close();
        });

        await container.read(catalogProvider.future);
        await container.read(installedPackagesProvider.future);
        container.read(privacyModeProvider.notifier).setEnabled(enabled: true);

        await container
            .read(installQueueProvider.notifier)
            .enqueueInstall(
              entry,
            );
        await _pumpMicrotasks();

        expect(fakeDownloader.requests, hasLength(1));
        expect(
          fakeDownloader.requests.single.uri.toString(),
          'https://upstream.example/releases/priv.apk',
        );
        expect(
          container
              .read(installQueueProvider)
              .taskFor(entry.packageName)
              ?.stage,
          InstallTaskStage.failed,
        );
      },
    );

    test('updateAll and libraryBadgeCountProvider stay in sync', () async {
      final update1 = _makeEntry(
        packageName: 'org.example.u1',
        name: 'Update One',
        versionCode: 200,
        sha256: '4' * 64,
      );
      final update2 = _makeEntry(
        packageName: 'org.example.u2',
        name: 'Update Two',
        versionCode: 200,
        sha256: '5' * 64,
      );
      final current = _makeEntry(
        packageName: 'org.example.current',
        name: 'Up To Date',
        versionCode: 200,
        sha256: '6' * 64,
      );
      final other = _makeEntry(
        packageName: 'org.example.other',
        name: 'Other Source',
        versionCode: 200,
        sha256: '7' * 64,
      );

      final fakeServices = _FakeAppServices(
        device: const DeviceInfo(
          supportedAbis: <String>['arm64-v8a'],
          sdkInt: 34,
          hasPServiceBridge: true,
        ),
        installedPackages: <InstalledPackage>[
          const InstalledPackage(
            packageName: 'org.example.u1',
            versionCode: 100,
            signingSha256: 'aabbccdd',
          ),
          const InstalledPackage(
            packageName: 'org.example.u2',
            versionCode: 100,
            signingSha256: 'aabbccdd',
          ),
          const InstalledPackage(
            packageName: 'org.example.current',
            versionCode: 200,
            signingSha256: 'aabbccdd',
          ),
          const InstalledPackage(
            packageName: 'org.example.other',
            versionCode: 100,
            signingSha256: 'deadbeef',
          ),
        ],
      );
      final fakeDownloader = _FakeApkDownloader(
        onDownload: (request) async => '/tmp/${request.expectedSha256}.apk',
      );

      final entries = <CatalogEntry>[update1, update2, current, other];
      final container = _createTestContainer(
        services: fakeServices,
        downloader: fakeDownloader,
        entries: entries,
      );
      addTearDown(() async {
        container.dispose();
        await fakeServices.close();
      });

      await container.read(catalogProvider.future);
      await container.read(installedPackagesProvider.future);

      // Two updates available -> badge is 2.
      expect(container.read(libraryBadgeCountProvider), 2);

      await container.read(installQueueProvider.notifier).updateAll(entries);
      await _pumpMicrotasks();

      // Both queued with intent=update; badge stays 2 (no double count).
      expect(container.read(installQueueProvider).count, 2);
      expect(container.read(libraryBadgeCountProvider), 2);
      expect(
        fakeDownloader.requests.map((r) => r.uri.queryParameters['r']).toList(),
        ['update', 'update'],
      );

      // Complete both installs and update mock package list.
      fakeServices
        ..installedPackages = <InstalledPackage>[
          const InstalledPackage(
            packageName: 'org.example.u1',
            versionCode: 200,
            signingSha256: 'aabbccdd',
          ),
          const InstalledPackage(
            packageName: 'org.example.u2',
            versionCode: 200,
            signingSha256: 'aabbccdd',
          ),
          const InstalledPackage(
            packageName: 'org.example.current',
            versionCode: 200,
            signingSha256: 'aabbccdd',
          ),
          const InstalledPackage(
            packageName: 'org.example.other',
            versionCode: 100,
            signingSha256: 'deadbeef',
          ),
        ]
        ..emitInstallEvent(
          const InstallSucceeded(packageName: 'org.example.u1', sessionId: 0),
        );
      await _pumpMicrotasks();
      fakeServices.emitInstallEvent(
        const InstallSucceeded(packageName: 'org.example.u2', sessionId: 0),
      );
      await _pumpMicrotasks();

      expect(container.read(installQueueProvider).count, 0);
      expect(container.read(libraryBadgeCountProvider), 0);
    });

    test(
      'openApp and uninstallApp delegate and refresh installed packages',
      () async {
        final entry = _makeEntry(
          packageName: 'org.example.app',
          name: 'App',
          versionCode: 100,
          sha256: '8' * 64,
        );
        final fakeServices = _FakeAppServices(
          device: const DeviceInfo(
            supportedAbis: <String>['arm64-v8a'],
            sdkInt: 34,
            hasPServiceBridge: true,
          ),
          installedPackages: <InstalledPackage>[
            const InstalledPackage(
              packageName: 'org.example.app',
              versionCode: 100,
              signingSha256: 'aabbccdd',
            ),
          ],
        );
        final fakeDownloader = _FakeApkDownloader(
          onDownload: (request) async => '/tmp/unused.apk',
        );

        final container = _createTestContainer(
          services: fakeServices,
          downloader: fakeDownloader,
          entries: <CatalogEntry>[entry],
        );
        addTearDown(() async {
          container.dispose();
          await fakeServices.close();
        });

        await container.read(catalogProvider.future);
        await container.read(installedPackagesProvider.future);

        final notifier = container.read(installQueueProvider.notifier);
        await notifier.openApp(entry.packageName);
        expect(fakeServices.openedPackages, [entry.packageName]);

        fakeServices.installedPackages = const <InstalledPackage>[];
        await notifier.uninstallApp(entry.packageName);
        expect(fakeServices.uninstalledPackages, [entry.packageName]);
        expect(
          container.read(resolvedAppStateProvider(entry.packageName))?.status,
          AppCatalogStatus.available,
        );
      },
    );

    test(
      'web host (canInstall == false) fails cleanly without crashing',
      () async {
        final fakeServices = _FakeAppServices(
          canInstall: false,
          device: const DeviceInfo(
            supportedAbis: <String>[],
            sdkInt: 0,
            hasPServiceBridge: false,
          ),
        );
        final fakeDownloader = _FakeApkDownloader(
          onDownload: (request) async => '/tmp/unused.apk',
        );
        final entry = _makeEntry(
          packageName: 'org.example.web',
          name: 'Web App',
          versionCode: 100,
          sha256: '9' * 64,
        );

        final container = _createTestContainer(
          services: fakeServices,
          downloader: fakeDownloader,
          entries: <CatalogEntry>[entry],
        );
        addTearDown(() async {
          container.dispose();
          await fakeServices.close();
        });

        await container.read(catalogProvider.future);
        await container.read(installedPackagesProvider.future);

        await container
            .read(installQueueProvider.notifier)
            .enqueueInstall(entry);
        await _pumpMicrotasks();

        final task = container
            .read(installQueueProvider)
            .taskFor(entry.packageName);
        expect(task?.stage, InstallTaskStage.failed);
        expect(task?.needsInstallPermission, isFalse);
        expect(task?.errorMessage, isNotEmpty);
        expect(fakeDownloader.requests, isEmpty);
      },
    );
  });

  group('IoApkDownloader & StubApkDownloader', () {
    test(
      'streams APK, sends User-Agent, verifies SHA-256, and renames atomically',
      () async {
        final tempDir = await Directory.systemTemp.createTemp(
          'tshop_apk_dl_test_',
        );
        addTearDown(() async {
          if (tempDir.existsSync()) {
            await tempDir.delete(recursive: true);
          }
        });

        final payload = Uint8List.fromList(List<int>.generate(4096, (i) => i));
        final expectedHash = sha256.convert(payload).toString();
        final adapter = _StreamHttpAdapter((options) async {
          expect(options.headers['User-Agent'], tshopUserAgent);
          return ResponseBody(
            Stream<Uint8List>.fromIterable(<Uint8List>[
              payload.sublist(0, 1024),
              payload.sublist(1024),
            ]),
            200,
            headers: <String, List<String>>{
              Headers.contentLengthHeader: <String>['${payload.length}'],
            },
          );
        });
        final dio = Dio()..httpClientAdapter = adapter;
        final downloader = IoApkDownloader(
          dio: dio,
          config: TshopConfig(
            catalogBaseUrl: Uri.parse('http://127.0.0.1:8787'),
            userAgent: tshopUserAgent,
          ),
          tempDirectoryProvider: () async => tempDir,
        );

        final progressSteps = <(int, int)>[];
        var verifyingCalled = false;
        final path = await downloader.downloadAndVerify(
          uri: Uri.parse('http://127.0.0.1:8787/apk/$expectedHash.apk'),
          expectedSha256: expectedHash,
          expectedSizeBytes: payload.length,
          onProgress: (received, total) => progressSteps.add((received, total)),
          onVerifying: () => verifyingCalled = true,
        );

        expect(File(path).existsSync(), isTrue);
        expect(File('$path.part').existsSync(), isFalse);
        expect(await File(path).readAsBytes(), payload);
        expect(verifyingCalled, isTrue);
        expect(progressSteps, <(int, int)>[
          (1024, payload.length),
          (payload.length, payload.length),
        ]);

        // Second call reuses verified cached APK without hitting network.
        final cachedPath = await downloader.downloadAndVerify(
          uri: Uri.parse('http://127.0.0.1:8787/apk/$expectedHash.apk'),
          expectedSha256: expectedHash,
          expectedSizeBytes: payload.length,
        );
        expect(cachedPath, path);
        expect(adapter.requestCount, 1);
      },
    );

    test(
      'deletes .part and throws ApkVerificationException on hash mismatch',
      () async {
        final tempDir = await Directory.systemTemp.createTemp(
          'tshop_apk_mismatch_test_',
        );
        addTearDown(() async {
          if (tempDir.existsSync()) {
            await tempDir.delete(recursive: true);
          }
        });

        final payload = Uint8List.fromList(<int>[1, 2, 3, 4, 5]);
        final wrongExpectedHash = 'f' * 64;
        final adapter = _StreamHttpAdapter((options) async {
          return ResponseBody(
            Stream<Uint8List>.value(payload),
            200,
          );
        });
        final dio = Dio()..httpClientAdapter = adapter;
        final downloader = IoApkDownloader(
          dio: dio,
          config: TshopConfig(
            catalogBaseUrl: Uri.parse('http://127.0.0.1:8787'),
          ),
          tempDirectoryProvider: () async => tempDir,
        );

        await expectLater(
          downloader.downloadAndVerify(
            uri: Uri.parse('http://127.0.0.1:8787/apk/$wrongExpectedHash.apk'),
            expectedSha256: wrongExpectedHash,
            expectedSizeBytes: payload.length,
          ),
          throwsA(isA<ApkVerificationException>()),
        );

        final apkDir = Directory('${tempDir.path}/tshop_apks');
        expect(apkDir.listSync(), isEmpty);
      },
    );

    test('StubApkDownloader throws AppServiceUnsupported', () async {
      const stub = StubApkDownloader();
      await expectLater(
        stub.downloadAndVerify(
          uri: Uri.parse('https://example.com/a.apk'),
          expectedSha256: 'a' * 64,
          expectedSizeBytes: 100,
        ),
        throwsA(isA<AppServiceUnsupported>()),
      );
    });

    test('IoApkDownloader cleans up .part when cancelled mid-stream', () async {
      final tempDir = await Directory.systemTemp.createTemp(
        'tshop_apk_cancel_test_',
      );
      addTearDown(() async {
        if (tempDir.existsSync()) {
          await tempDir.delete(recursive: true);
        }
      });

      final controller = StreamController<Uint8List>();
      addTearDown(controller.close);

      final adapter = _StreamHttpAdapter((options) async {
        return ResponseBody(controller.stream, 200);
      });
      final dio = Dio()..httpClientAdapter = adapter;
      final downloader = IoApkDownloader(
        dio: dio,
        config: TshopConfig(catalogBaseUrl: Uri.parse('http://127.0.0.1:8787')),
        tempDirectoryProvider: () async => tempDir,
      );

      final cancelToken = CancelToken();
      final future = downloader.downloadAndVerify(
        uri: Uri.parse('http://127.0.0.1:8787/apk/${'e' * 64}.apk'),
        expectedSha256: 'e' * 64,
        expectedSizeBytes: 4096,
        cancelToken: cancelToken,
      );

      await _pumpMicrotasks();
      controller.add(Uint8List.fromList(<int>[1, 2, 3, 4]));
      await _pumpMicrotasks();
      cancelToken.cancel('User cancelled');

      await expectLater(future, throwsA(isA<DioException>()));
      final apkDir = Directory('${tempDir.path}/tshop_apks');
      expect(apkDir.listSync(), isEmpty);
    });
  });
}

ProviderContainer _createTestContainer({
  required _FakeAppServices services,
  required _FakeApkDownloader downloader,
  required List<CatalogEntry> entries,
}) {
  final doc = CatalogDocument(
    schemaVersion: 1,
    generatedAt: DateTime.utc(2026, 11, 27),
    apkBaseUrl: '/apk',
    capabilityTags: const <CatalogCapabilityTag>[],
    categories: <CatalogCategoryFrame>[
      CatalogCategoryFrame(
        id: 'Emulators',
        name: LocalizedText(const <String, String>{'en': 'Emulators'}),
        entries: entries.map((e) => e.packageName).toList(),
      ),
    ],
    entries: entries,
  );
  final pointer = CatalogPointer(
    schemaVersion: 1,
    minClientVersionCode: 1,
    generatedAt: DateTime.utc(2026, 11, 27),
    generatedAtRaw: '2026-11-27T00:00:00Z',
    keyId: 'dev-v1',
    catalogUrl: '/catalog/catalog-test.json',
    catalogSha256: 'a' * 64,
    catalogSize: 100,
    statsUrl: 'https://stats.tshop.example/',
    signature: 'sig',
  );
  final catalogState = CatalogState(
    catalog: doc,
    pointer: pointer,
    isOffline: false,
    isRefreshing: false,
    lastCheckedAt: DateTime.utc(2026, 11, 27),
  );

  return ProviderContainer(
    overrides: [
      talkerProvider.overrideWithValue(Talker()),
      tshopConfigProvider.overrideWithValue(
        TshopConfig(catalogBaseUrl: Uri.parse('http://127.0.0.1:8787')),
      ),
      appServicesProvider.overrideWithValue(services),
      apkDownloaderProvider.overrideWithValue(downloader),
      catalogProvider.overrideWith(() => _FixedCatalogNotifier(catalogState)),
    ],
  );
}

Future<void> _pumpMicrotasks() async {
  for (var i = 0; i < 10; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

CatalogEntry _makeEntry({
  required String packageName,
  required String name,
  required int versionCode,
  required String sha256,
  String upstreamUrl = 'https://upstream.example/app.apk',
}) {
  return CatalogEntry(
    packageName: packageName,
    slug: packageName,
    rank: 1,
    name: LocalizedText(<String, String>{'en': name}),
    publisher: 'Example',
    category: 'Emulators',
    searchTags: const <String>[],
    summary: LocalizedText(const <String, String>{'en': 'Summary'}),
    description: LocalizedStringList(const <String, List<String>>{
      'en': <String>['Description'],
    }),
    homepageUrl: 'https://example.com',
    rehostMode: RehostMode.rehost,
    allowedSigningCerts: const <String>['aabbccdd'],
    capabilities: const <String>[],
    tile: CatalogTile(
      iconUrl: '/art/icon.webp',
      backdropColors: const <String>['#123456'],
      backdropAngle: 145,
      iconScale: 0.9,
    ),
    screenshots: const <CatalogScreenshot>[],
    release: CatalogRelease(
      versionCode: versionCode,
      versionName: '1.0.$versionCode',
      releasedAt: DateTime.utc(2026, 11),
      variantsAreUserChoice: false,
      variants: <CatalogVariant>[
        CatalogVariant(
          sha256: sha256,
          sizeBytes: 1024,
          abis: const <String>['arm64-v8a'],
          minSdk: 24,
          targetSdk: 35,
          upstreamUrl: upstreamUrl,
        ),
      ],
    ),
    changelogs: const <CatalogChangelog>[],
  );
}

final class _FixedCatalogNotifier extends CatalogNotifier {
  _FixedCatalogNotifier(this._initialState);

  final CatalogState _initialState;

  @override
  Future<CatalogState> build() async => _initialState;
}

final class _InstallFileCall {
  const _InstallFileCall({
    required this.packageName,
    required this.filePath,
  });

  final String packageName;
  final String filePath;
}

final class _FakeAppServices implements AppServices {
  _FakeAppServices({
    required this.device,
    this.canInstall = true,
    this.canRequestInstalls = true,
    this.installedPackages = const <InstalledPackage>[],
  });

  final DeviceInfo device;

  @override
  final bool canInstall;

  bool canRequestInstalls;
  List<InstalledPackage> installedPackages;

  final List<_InstallFileCall> installedFileCalls = <_InstallFileCall>[];
  final List<String> confirmedPackages = <String>[];
  final List<String> cancelledConfirmations = <String>[];
  final List<String> openedPackages = <String>[];
  final List<String> uninstalledPackages = <String>[];

  final StreamController<InstallEvent> _installEventsController =
      StreamController<InstallEvent>.broadcast();

  void emitInstallEvent(InstallEvent event) {
    _installEventsController.add(event);
  }

  Future<void> close() async {
    await _installEventsController.close();
  }

  @override
  Future<DeviceInfo> deviceInfo() async => device;

  @override
  Future<List<InstalledPackage>> scanInstalled() async => installedPackages;

  @override
  Future<Set<String>> metCapabilities() async => const <String>{};

  @override
  Future<bool> canRequestPackageInstalls() async => canRequestInstalls;

  @override
  Future<void> installApkFile({
    required String packageName,
    required String filePath,
  }) async {
    installedFileCalls.add(
      _InstallFileCall(packageName: packageName, filePath: filePath),
    );
  }

  @override
  Future<bool> launchPendingConfirmation({required String packageName}) async {
    confirmedPackages.add(packageName);
    return true;
  }

  @override
  Future<void> cancelPendingConfirmation({required String packageName}) async {
    cancelledConfirmations.add(packageName);
  }

  @override
  Stream<InstallEvent> get installEvents => _installEventsController.stream;

  @override
  Stream<GamepadHatEvent> get gamepadHatEvents =>
      const Stream<GamepadHatEvent>.empty();

  @override
  Future<void> enqueueInstall({
    required String packageName,
    required Uri apk,
  }) async {}

  @override
  Future<void> enqueueUninstall({required String packageName}) async {
    uninstalledPackages.add(packageName);
  }

  @override
  Future<void> openInstalled({required String packageName}) async {
    openedPackages.add(packageName);
  }

  @override
  Future<void> notifyUpdates({required int count}) async {}

  @override
  Future<void> openInstallPermissionSettings() async {}

  @override
  Future<void> requestNotificationPermission() async {}
}

final class _FakeDownloadRequest {
  const _FakeDownloadRequest({
    required this.uri,
    required this.expectedSha256,
    required this.expectedSizeBytes,
    this.onProgress,
    this.onVerifying,
    this.cancelToken,
  });

  final Uri uri;
  final String expectedSha256;
  final int expectedSizeBytes;
  final ApkDownloadProgressCallback? onProgress;
  final VoidCallback? onVerifying;
  final CancelToken? cancelToken;
}

final class _FakeApkDownloader implements ApkDownloader {
  _FakeApkDownloader({required this.onDownload});

  final Future<String> Function(_FakeDownloadRequest request) onDownload;
  final List<_FakeDownloadRequest> requests = <_FakeDownloadRequest>[];
  final List<String> deletedSha256s = <String>[];

  @override
  Future<String> downloadAndVerify({
    required Uri uri,
    required String expectedSha256,
    required int expectedSizeBytes,
    ApkDownloadProgressCallback? onProgress,
    VoidCallback? onVerifying,
    CancelToken? cancelToken,
  }) {
    final request = _FakeDownloadRequest(
      uri: uri,
      expectedSha256: expectedSha256,
      expectedSizeBytes: expectedSizeBytes,
      onProgress: onProgress,
      onVerifying: onVerifying,
      cancelToken: cancelToken,
    );
    requests.add(request);
    return onDownload(request);
  }

  @override
  Future<void> deleteCachedApk(String sha256) async {
    deletedSha256s.add(sha256);
  }
}

final class _StreamHttpAdapter implements HttpClientAdapter {
  _StreamHttpAdapter(this._handler);

  final Future<ResponseBody> Function(RequestOptions options) _handler;
  int requestCount = 0;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) {
    requestCount++;
    return _handler(options);
  }

  @override
  void close({bool force = false}) {}
}
