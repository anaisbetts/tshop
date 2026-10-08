import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:tshop/src/routing/app_router.dart';
import 'package:tshop/src/theme/tshop_theme.dart';

/// Root widget: [MaterialApp.router] wired to [appRouterProvider].
class TshopApp extends HookConsumerWidget {
  /// Creates the app shell.
  const TshopApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);
    return MaterialApp.router(
      title: 'tShop',
      theme: buildTshopTheme(Brightness.light),
      darkTheme: buildTshopTheme(Brightness.dark),
      routerConfig: router,
    );
  }
}
