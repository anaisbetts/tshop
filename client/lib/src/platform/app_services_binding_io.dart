import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:talker/talker.dart';
import 'package:tshop/src/platform/android_app_services.dart';
import 'package:tshop/src/platform/app_services.dart';

/// Binds [AndroidAppServices] on Android and [StubAppServices] elsewhere.
///
/// Respects [debugDefaultTargetPlatformOverride] so unit tests can exercise
/// the Android binding path without running on an Android device.
AppServices bindPlatformAppServices({required Talker talker}) {
  final override = debugDefaultTargetPlatformOverride;
  final isAndroid = override != null
      ? override == TargetPlatform.android
      : Platform.isAndroid;
  if (isAndroid) {
    return AndroidAppServices(talker: talker);
  }
  return StubAppServices(talker: talker);
}
