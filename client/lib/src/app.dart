import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:tshop/src/routing/app_router.dart';

/// Root widget: [MaterialApp.router] wired to [appRouterProvider].
class TshopApp extends HookConsumerWidget {
  /// Creates the app shell.
  const TshopApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);
    return MaterialApp.router(
      title: 'tShop',
      routerConfig: router,
    );
  }
}
