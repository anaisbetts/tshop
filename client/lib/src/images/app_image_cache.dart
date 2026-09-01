import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:tshop/src/data/remote/dio_client.dart';

/// [CacheManager] whose downloads go through the shared [Dio].
final imageCacheProvider = Provider<CacheManager>((ref) {
  final cache = CacheManager(
    Config('tshopImages', fileService: DioFileService(ref.watch(dioProvider))),
  );
  ref.onDispose(() => unawaited(cache.dispose()));
  return cache;
});

/// [FileService] that issues GETs on a [Dio] so interceptors still run.
class DioFileService extends FileService {
  /// Creates a service that fetches cache bytes with [dio].
  DioFileService(this.dio);

  /// Client used for cache downloads.
  final Dio dio;

  @override
  Future<FileServiceResponse> get(
    String url, {
    Map<String, String>? headers,
  }) async {
    final response = await dio.get<List<int>>(
      url,
      options: Options(responseType: ResponseType.bytes, headers: headers),
    );
    return _DioGetResponse(response);
  }
}

class _DioGetResponse implements FileServiceResponse {
  _DioGetResponse(this._response) : _receivedTime = DateTime.now();

  final Response<List<int>> _response;
  final DateTime _receivedTime;

  @override
  Stream<List<int>> get content => Stream<List<int>>.value(
    _response.data ?? const <int>[],
  );

  @override
  int? get contentLength => _response.data?.length;

  @override
  String? get eTag => _response.headers.value('etag');

  @override
  String get fileExtension {
    final type = _response.headers.value('content-type');
    if (type == null) {
      return '';
    }
    return '.${type.split(';').first.split('/').last}';
  }

  @override
  int get statusCode => _response.statusCode ?? 0;

  // ponytail: 7-day TTL, honor Cache-Control when artwork eviction matters.
  @override
  DateTime get validTill => _receivedTime.add(const Duration(days: 7));
}
