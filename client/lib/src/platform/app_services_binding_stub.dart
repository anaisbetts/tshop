import 'package:talker/talker.dart';
import 'package:tshop/src/platform/app_services.dart';

/// Binds [StubAppServices] on targets without `dart:io` (web).
AppServices bindPlatformAppServices({required Talker talker}) {
  return StubAppServices(talker: talker);
}
