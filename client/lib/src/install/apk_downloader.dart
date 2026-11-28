import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:talker/talker.dart';
import 'package:tshop/src/config/tshop_config.dart';
import 'package:tshop/src/install/apk_downloader_stub.dart'
    if (dart.library.io) 'package:tshop/src/install/apk_downloader_io.dart'
    as downloader_impl;

/// Callback invoked as APK bytes arrive from the network.
typedef ApkDownloadProgressCallback = void Function(
  int bytesReceived,
  int totalBytes,
);

/// Thrown when a downloaded APK fails SHA-256 integrity verification.
final class ApkVerificationException implements Exception {
  /// Creates an [ApkVerificationException].
  const ApkVerificationException({
    required this.expectedSha256,
    required this.actualSha256,
    required this.uri,
    this.message,
  });

  /// Expected lowercase hex SHA-256 digest from the signed catalog.
  final String expectedSha256;

  /// Actual lowercase hex SHA-256 digest computed from the downloaded file.
  final String actualSha256;

  /// Download URI that produced the mismatched payload.
  final Uri uri;

  /// Optional custom error detail.
  final String? message;

  /// Human-readable description suitable for logs and UI error banners.
  String get description =>
      message ??
      'APK integrity check failed: expected SHA-256 $expectedSha256, '
          'got $actualSha256.';

  @override
  String toString() => 'ApkVerificationException: $description ($uri)';
}

/// Platform-agnostic interface for downloading and SHA-256-verifying APKs.
abstract interface class ApkDownloader {
  /// Downloads the APK at [uri], verifies its SHA-256 matches
  /// [expectedSha256], and returns the local filesystem path to the verified
  /// `.apk` file.
  Future<String> downloadAndVerify({
    required Uri uri,
    required String expectedSha256,
    required int expectedSizeBytes,
    ApkDownloadProgressCallback? onProgress,
    VoidCallback? onVerifying,
    CancelToken? cancelToken,
  });

  /// Deletes any cached `.apk` or partial `.apk.part` file for [sha256].
  Future<void> deleteCachedApk(String sha256);
}

/// Creates the platform-appropriate [ApkDownloader].
///
/// Uses streaming filesystem downloads on native targets and a stub that
/// throws `AppServiceUnsupported` on web.
ApkDownloader createDefaultApkDownloader({
  required Dio dio,
  required TshopConfig config,
  Talker? talker,
}) => downloader_impl.createPlatformApkDownloader(
  dio: dio,
  config: config,
  talker: talker,
);
