import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:tshop/src/app.dart';
import 'package:tshop/src/logging/app_talker.dart';
import 'package:tshop/src/platform/app_services.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  final talker = createAppTalker();
  final appServices = bindAppServices(talker: talker);
  if (kIsWeb) {
    talker.info(
      'Web demo: app services are stubbed; installs will not run.',
    );
  }
  runApp(
    ProviderScope(
      overrides: [
        talkerProvider.overrideWithValue(talker),
        appServicesProvider.overrideWithValue(appServices),
      ],
      child: const TshopApp(),
    ),
  );
}
