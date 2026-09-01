import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:talker_flutter/talker_flutter.dart';
import 'package:tshop/src/logging/app_talker.dart';
import 'package:tshop/src/routing/app_routes.dart';

/// App [GoRouter] with a Talker navigator observer.
final appRouterProvider = Provider<GoRouter>((ref) {
  final talker = ref.watch(talkerProvider);
  final router = GoRouter(
    initialLocation: AppRoutes.home,
    observers: [TalkerRouteObserver(talker)],
    routes: [
      GoRoute(
        path: AppRoutes.home,
        name: 'home',
        builder: (context, state) => const PlaceholderPage(),
      ),
    ],
  );
  ref.onDispose(router.dispose);
  return router;
});

/// Single `/` page. Long-press the title in debug to open Talker.
class PlaceholderPage extends ConsumerWidget {
  /// Creates the placeholder home page.
  const PlaceholderPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    const title = Text('tShop');
    return Scaffold(
      appBar: AppBar(
        title: kDebugMode
            ? GestureDetector(
                onLongPress: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => TalkerScreen(
                        talker: ref.read(talkerProvider),
                      ),
                    ),
                  );
                },
                child: title,
              )
            : title,
      ),
    );
  }
}
