import 'package:flutter/material.dart';
import 'package:tshop/src/theme/tshop_tokens.dart';

/// Bundled in `assets/fonts/` (Latin subset).
const tshopFontFamily = 'M PLUS Rounded 1c';

/// Builds the tShop [ThemeData] for one mode.
///
/// The Storybook type scale maps onto [TextTheme] like this:
///
/// | Storybook            | TextTheme slot  | Size / weight |
/// |----------------------|-----------------|---------------|
/// | Detail name          | displaySmall    | 26 / 900      |
/// | Info-strip hero      | headlineSmall   | 22 / 800      |
/// | Frame label          | titleMedium     | 17 / 800      |
/// | Settings row title   | titleSmall      | 14 / 800      |
/// | Body                 | bodyMedium      | 12.5 / 500    |
/// | Button               | labelLarge      | 14 / 800      |
/// | UI (tabs, legend)    | labelMedium     | 12 / 700      |
/// | Small (chips, notes) | labelSmall      | 10.5 / 700    |
ThemeData buildTshopTheme(Brightness brightness) {
  final tokens = switch (brightness) {
    Brightness.light => TshopTokens.day,
    Brightness.dark => TshopTokens.night,
  };
  final colorScheme = ColorScheme(
    brightness: brightness,
    primary: TshopBrand.accent,
    onPrimary: TshopBrand.accentInk,
    secondary: TshopBrand.good,
    onSecondary: Colors.white,
    error: TshopBrand.bad,
    onError: Colors.white,
    surface: tokens.card,
    onSurface: tokens.ink,
    onSurfaceVariant: tokens.ink2,
    outline: tokens.ink3,
    outlineVariant: tokens.hairline,
    surfaceContainerHighest: tokens.chip,
  );
  final textTheme = _textTheme(tokens);

  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: colorScheme,
    fontFamily: tshopFontFamily,
    textTheme: textTheme,
    scaffoldBackgroundColor: tokens.wallBottom,
    extensions: [tokens],
    appBarTheme: AppBarTheme(
      backgroundColor: tokens.wallTop,
      foregroundColor: tokens.ink,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      titleTextStyle: textTheme.headlineSmall,
    ),
    dividerTheme: DividerThemeData(color: tokens.hairline, thickness: 1),
    iconTheme: IconThemeData(color: tokens.ink2),
  );
}

TextTheme _textTheme(TshopTokens tokens) {
  TextStyle style(
    double size,
    FontWeight weight, {
    Color? color,
    double? height,
    double? letterSpacing,
  }) => TextStyle(
    fontFamily: tshopFontFamily,
    fontSize: size,
    fontWeight: weight,
    color: color ?? tokens.ink,
    height: height,
    letterSpacing: letterSpacing,
  );

  return TextTheme(
    displaySmall: style(
      26,
      FontWeight.w900,
      height: 1.1,
      letterSpacing: -0.4,
    ),
    headlineSmall: style(
      22,
      FontWeight.w800,
      height: 1.15,
      letterSpacing: -0.2,
    ),
    titleMedium: style(17, FontWeight.w800, letterSpacing: -0.2),
    titleSmall: style(14, FontWeight.w800),
    bodyMedium: style(12.5, FontWeight.w500, height: 1.5),
    bodySmall: style(12, FontWeight.w500, color: tokens.ink2),
    labelLarge: style(14, FontWeight.w800),
    labelMedium: style(12, FontWeight.w700, color: tokens.ink2),
    labelSmall: style(10.5, FontWeight.w700, color: tokens.ink2),
  );
}
