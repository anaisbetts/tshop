import 'dart:async';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:talker/talker.dart';
import 'package:tshop/src/config/tshop_config.dart';
import 'package:tshop/src/install/apk_downloader.dart';

const String _apkCacheDirName = 'tshop_apks';
const String _partExtension = '.part';

/// Callback returning the base temporary directory used by [IoApkDownloader].
typedef ApkTempDirectoryProvider = Future<Directory> Function();

/// Native (`dart:io`) [ApkDownloader] that streams APK bytes to disk while
/// incrementally computing SHA-256 and atomically promotes `.part` files only
/// after verification succeeds.
final class IoApkDownloader implements ApkDownloader {
  /// Creates an [IoApkDownloader].
  IoApkDownloader({
    required this._dio,
    required this._config,
    this._talker,
    ApkTempDirectoryProvider? tempDirectoryProvider,
  }) : _tempDirectoryProvider = tempDirectoryProvider ?? getTemporaryDirectory;

  final Dio _dio;
  final TshopConfig _config;
  final Talker? _talker;
  final ApkTempDirectoryProvider _tempDirectoryProvider;

  @override
  Future<String> downloadAndVerify({
    required Uri uri,
    required String expectedSha256,
    required int expectedSizeBytes,
    ApkDownloadProgressCallback? onProgress,
    VoidCallback? onVerifying,
    CancelToken? cancelToken,
  }) async {
    final normalizedExpected = _normalizeAndValidateSha256(expectedSha256, uri);
    final dir = await _apkDir();
    if (!dir.existsSync()) {
      await dir.create(recursive: true);
    }

    final finalFile = File('${dir.path}/$normalizedExpected.apk');
    final partFile = File('${finalFile.path}$_partExtension');

    // Reuse an already-downloaded APK only if its on-disk SHA-256 matches.
    if (finalFile.existsSync()) {
      onVerifying?.call();
      final existingHash = await _hashFile(finalFile);
      if (existingHash == normalizedExpected) {
        final existingSize = await finalFile.length();
        onProgress?.call(existingSize, existingSize);
        return finalFile.path;
      }
      _talker?.warning(
        'Cached APK for $normalizedExpected failed SHA-256 check; '
        'deleting and re-downloading.',
      );
      await _safeDelete(finalFile);
    }

    await _safeDelete(partFile);

    final response = await _dio.getUri<ResponseBody>(
      uri,
      cancelToken: cancelToken,
      options: Options(
        responseType: ResponseType.stream,
        headers: <String, Object?>{
          'User-Agent': _config.userAgent,
        },
      ),
    );

    final body = response.data;
    if (body == null) {
      throw DioException(
        requestOptions: response.requestOptions,
        response: response,
        type: DioExceptionType.badResponse,
        message: 'Empty APK response body from $uri.',
      );
    }

    final headerLength = _parseContentLength(response.headers);
    final totalBytes = headerLength > 0 ? headerLength : expectedSizeBytes;
    final fileSink = partFile.openWrite();
    var sinkClosed = false;

    try {
      final digest = await _streamToSinkAndHash(
        stream: body.stream,
        fileSink: fileSink,
        totalBytes: totalBytes,
        requestOptions: response.requestOptions,
        onProgress: onProgress,
        cancelToken: cancelToken,
      );

      await fileSink.flush();
      await fileSink.close();
      sinkClosed = true;

      onVerifying?.call();

      final actualSha256 = digest.toString().toLowerCase();
      if (actualSha256 != normalizedExpected) {
        await _safeDelete(partFile);
        throw ApkVerificationException(
          expectedSha256: normalizedExpected,
          actualSha256: actualSha256,
          uri: uri,
        );
      }

      if (finalFile.existsSync()) {
        await _safeDelete(finalFile);
      }
      await partFile.rename(finalFile.path);
      return finalFile.path;
    } catch (_) {
      if (!sinkClosed) {
        await _safeCloseSink(fileSink);
      }
      await _safeDelete(partFile);
      rethrow;
    }
  }

  @override
  Future<void> deleteCachedApk(String sha256) async {
    final normalized = sha256.trim().toLowerCase();
    if (!_isSafeHexDigest(normalized)) {
      return;
    }
    final dir = await _apkDir();
    final finalFile = File('${dir.path}/$normalized.apk');
    final partFile = File('${finalFile.path}$_partExtension');
    await _safeDelete(finalFile);
    await _safeDelete(partFile);
  }

  Future<Directory> _apkDir() async {
    final baseDir = await _tempDirectoryProvider();
    return Directory('${baseDir.path}/$_apkCacheDirName');
  }
}

/// Creates a native [IoApkDownloader].
ApkDownloader createPlatformApkDownloader({
  required Dio dio,
  required TshopConfig config,
  Talker? talker,
}) => IoApkDownloader(dio: dio, config: config, talker: talker);

final class _DigestAccumulator implements Sink<Digest> {
  Digest? _digest;

  Digest get value {
    final result = _digest;
    if (result == null) {
      throw StateError('SHA-256 digest was not finalized.');
    }
    return result;
  }

  @override
  void add(Digest data) {
    _digest = data;
  }

  @override
  void close() {}
}

Future<Digest> _streamToSinkAndHash({
  required Stream<Uint8List> stream,
  required IOSink fileSink,
  required int totalBytes,
  required RequestOptions requestOptions,
  ApkDownloadProgressCallback? onProgress,
  CancelToken? cancelToken,
}) async {
  final digestAccumulator = _DigestAccumulator();
  final hashSink = sha256.startChunkedConversion(digestAccumulator);
  final completer = Completer<Digest>();
  var bytesReceived = 0;

  late final StreamSubscription<Uint8List> subscription;
  subscription = stream.listen(
    (chunk) {
      if (completer.isCompleted) {
        return;
      }
      if (cancelToken?.isCancelled ?? false) {
        unawaited(subscription.cancel());
        completer.completeError(
          cancelToken!.cancelError ??
              DioException.requestCancelled(
                requestOptions: requestOptions,
                reason: 'Cancelled',
              ),
        );
        return;
      }
      fileSink.add(chunk);
      hashSink.add(chunk);
      bytesReceived += chunk.length;
      onProgress?.call(bytesReceived, totalBytes);
    },
    onError: (Object error, StackTrace stackTrace) {
      if (!completer.isCompleted) {
        completer.completeError(error, stackTrace);
      }
    },
    onDone: () {
      if (!completer.isCompleted) {
        hashSink.close();
        completer.complete(digestAccumulator.value);
      }
    },
    cancelOnError: true,
  );

  if (cancelToken != null) {
    unawaited(
      cancelToken.whenCancel.then((cancelError) {
        if (!completer.isCompleted) {
          unawaited(subscription.cancel());
          completer.completeError(cancelError);
        }
      }),
    );
  }

  return completer.future;
}

Future<String> _hashFile(File file) async {
  final digest = await sha256.bind(file.openRead()).first;
  return digest.toString().toLowerCase();
}

int _parseContentLength(Headers headers) {
  final raw = headers.value(Headers.contentLengthHeader);
  if (raw == null) {
    return -1;
  }
  return int.tryParse(raw.trim()) ?? -1;
}

String _normalizeAndValidateSha256(String sha256Value, Uri uri) {
  final normalized = sha256Value.trim().toLowerCase();
  if (!_isSafeHexDigest(normalized)) {
    throw ApkVerificationException(
      expectedSha256: normalized,
      actualSha256: '',
      uri: uri,
      message: 'Catalog entry contains an invalid SHA-256 digest.',
    );
  }
  return normalized;
}

bool _isSafeHexDigest(String value) {
  if (value.isEmpty) {
    return false;
  }
  return RegExp(r'^[0-9a-f]+$').hasMatch(value);
}

Future<void> _safeCloseSink(IOSink sink) async {
  try {
    await sink.close();
  } on Object {
    // Best-effort cleanup on abort.
  }
}

Future<void> _safeDelete(File file) async {
  try {
    if (file.existsSync()) {
      await file.delete();
    }
  } on Object {
    // Best-effort cleanup of temp/partial files.
  }
}
