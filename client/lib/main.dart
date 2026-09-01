import 'package:flutter/widgets.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:tshop/src/app.dart';
import 'package:tshop/src/logging/app_talker.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  final talker = createAppTalker();
  runApp(
    ProviderScope(
      overrides: [
        talkerProvider.overrideWithValue(talker),
      ],
      child: const TshopApp(),
    ),
  );
}
