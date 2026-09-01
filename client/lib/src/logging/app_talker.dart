import 'package:flutter/foundation.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:talker_flutter/talker_flutter.dart';

/// Builds the process-wide [Talker]. Debug keeps history; release logs
/// warnings and up to logcat (Android) or the browser console (web).
Talker createAppTalker() {
  return TalkerFlutter.init(
    settings: TalkerSettings(
      // ignore: avoid_redundant_argument_values, false in release.
      useHistory: kDebugMode,
    ),
    logger: TalkerLogger(
      output: _writeTalkerLine,
      settings: TalkerLoggerSettings(
        level: kDebugMode ? LogLevel.debug : LogLevel.warning,
      ),
    ),
  );
}

/// Shared Talker used by app code, Dio, and the router observer.
final talkerProvider = Provider<Talker>((ref) => createAppTalker());

void _writeTalkerLine(String message) {
  if (kIsWeb) {
    // Talker is the console sink on web; app code still uses Talker.
    // ignore: avoid_print
    print(message);
    return;
  }
  debugPrint(message);
}
