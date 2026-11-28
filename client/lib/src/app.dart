import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:tshop/src/input/input_providers.dart';
import 'package:tshop/src/routing/app_router.dart';
import 'package:tshop/src/theme/tshop_theme.dart';
import 'package:tshop/src/theme/widgets/pad_glyph.dart';

/// Root widget: [MaterialApp.router] wired to [appRouterProvider].
class TshopApp extends HookConsumerWidget {
  /// Creates the app shell.
  const TshopApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);
    final padLayout = ref.watch(padButtonLayoutProvider);
    return PadLayoutScope(
      layout: padLayout,
      child: MaterialApp.router(
        title: 'tShop',
        theme: buildTshopTheme(Brightness.light),
        darkTheme: buildTshopTheme(Brightness.dark),
        routerConfig: router,
      ),
    );
  }
}
