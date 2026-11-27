import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:talker/talker.dart';
import 'package:tshop/src/config/tshop_config.dart';
import 'package:tshop/src/install/apk_downloader.dart';
import 'package:tshop/src/platform/app_services.dart';

const String _webDownloadUnsupportedMessage =
    'tShop web is a demo and cannot download or install APKs.';

/// Web-safe stub [ApkDownloader] that refuses all downloads.
final class StubApkDownloader implements ApkDownloader {
  /// Creates a [StubApkDownloader].
  const StubApkDownloader({this.talker});

  /// Optional logger for diagnostic messages.
  final Talker? talker;

  @override
  Future<String> downloadAndVerify({
    required Uri uri,
    required String expectedSha256,
    required int expectedSizeBytes,
    ApkDownloadProgressCallback? onProgress,
    VoidCallback? onVerifying,
    CancelToken? cancelToken,
  }) async {
    talker?.warning('web demo: refused APK download ($uri)');
    throw const AppServiceUnsupported(_webDownloadUnsupportedMessage);
  }

  @override
  Future<void> deleteCachedApk(String sha256) async {
    talker?.debug('web demo: skipped deleting cached APK ($sha256)');
  }
}

/// Creates the web-safe [StubApkDownloader].
ApkDownloader createPlatformApkDownloader({
  required Dio dio,
  required TshopConfig config,
  Talker? talker,
}) => StubApkDownloader(talker: talker);
