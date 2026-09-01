import 'package:dio/dio.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:talker_dio_logger/talker_dio_logger.dart';
import 'package:tshop/src/logging/app_talker.dart';

/// Shared [Dio] with [TalkerDioLogger]. Image GETs skip response bodies.
final dioProvider = Provider<Dio>((ref) {
  final dio = Dio();
  dio.interceptors.add(
    TalkerDioLogger(
      talker: ref.watch(talkerProvider),
      settings: TalkerDioLoggerSettings(
        responseFilter: (response) =>
            response.requestOptions.responseType != ResponseType.bytes,
      ),
    ),
  );
  ref.onDispose(dio.close);
  return dio;
});
