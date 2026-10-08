import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';

/// Mode-independent brand colours from `design/src/tshop/tokens.css`.
abstract final class TshopBrand {
  /// tShop orange: brand mark, focus, primary action, update badges.
  static const accent = Color(0xFFFF7A1A);

  /// Text and glyphs on [accent].
  static const accentInk = Color(0xFFFFFFFF);

  /// Glow under focused and primary elements.
  static const accentSoft = Color(0x52FF7A1A);

  /// Lighter accent used at the peak of the focus "breath".
  static const accentBright = Color(0xFFFFA35E);

  /// Installed, open, done.
  static const good = Color(0xFF22B573);

  /// Failed, missing hardware, offline glyph.
  static const bad = Color(0xFFEC4D4D);

  /// Face button A.
  static const padA = Color(0xFFEC4D4D);

  /// Face button B.
  static const padB = Color(0xFFF2B705);

  /// Ink on face button B.
  static const padBInk = Color(0xFF3B2C00);

  /// Face button X.
  static const padX = Color(0xFF3D7CF2);

  /// Face button Y.
  static const padY = Color(0xFF22B573);

  /// Logo and action-tile fill.
  static const accentGradient = LinearGradient(
    begin: Alignment(-0.34, -0.94),
    end: Alignment(0.34, 0.94),
    colors: [Color(0xFFFF9A3D), accent, Color(0xFFF05F00)],
    stops: [0, 0.58, 1],
  );
}

/// Sizes and radii in dp. The Thor top panel is 837 × 471 dp.
abstract final class TshopMetrics {
  /// Tile corner radius.
  static const tileRadius = 18.0;

  /// Shelf / frame corner radius.
  static const shelfRadius = 22.0;

  /// Card corner radius.
  static const cardRadius = 16.0;

  /// Fully rounded.
  static const pillRadius = 999.0;

  /// Tile edge on the Thor canvas.
  static const tile = 80.0;

  /// Gap between tiles.
  static const gap = 8.0;

  /// Thor top-panel canvas.
  static const thorCanvas = Size(837, 471);
}

/// Day / Night tokens. Every tShop widget reads these, never raw colours.
@immutable
class TshopTokens extends ThemeExtension<TshopTokens> {
  /// Creates a token set. Prefer [day] and [night].
  const TshopTokens({
    required this.brightness,
    required this.wallTop,
    required this.wallBottom,
    required this.wallStripe,
    required this.shelf,
    required this.shelfEdge,
    required this.shelfShadow,
    required this.card,
    required this.cardShadow,
    required this.chip,
    required this.ink,
    required this.ink2,
    required this.ink3,
    required this.hairline,
    required this.tabActive,
    required this.scrim,
    required this.focusGap,
    required this.padNeutral,
    required this.goodInk,
    required this.accentInk,
    required this.badInk,
  });

  /// Which mode these tokens describe.
  final Brightness brightness;

  /// Wallpaper gradient top.
  final Color wallTop;

  /// Wallpaper gradient bottom.
  final Color wallBottom;

  /// Wallpaper pinstripe.
  final Color wallStripe;

  /// Frosted shelf / top-bar fill.
  final Color shelf;

  /// Shelf highlight edge.
  final Color shelfEdge;

  /// Shelf drop shadow.
  final List<BoxShadow> shelfShadow;

  /// Solid card fill.
  final Color card;

  /// Card drop shadow.
  final List<BoxShadow> cardShadow;

  /// Neutral chip fill.
  final Color chip;

  /// Primary text.
  final Color ink;

  /// Secondary text.
  final Color ink2;

  /// Tertiary text, counts, labels.
  final Color ink3;

  /// Row dividers and outlines.
  final Color hairline;

  /// Active top-bar tab fill.
  final Color tabActive;

  /// Solid colour the Detail banner scrim fades to.
  final Color scrim;

  /// Gap between an element and its focus ring.
  final Color focusGap;

  /// L / R / + and d-pad glyph fill.
  final Color padNeutral;

  /// Text on a "good" chip.
  final Color goodInk;

  /// Text on an "accent" chip.
  final Color accentInk;

  /// Text on a "bad" chip.
  final Color badInk;

  /// Day mode.
  static const day = TshopTokens(
    brightness: Brightness.light,
    wallTop: Color(0xFFF3F5F9),
    wallBottom: Color(0xFFDFE4EC),
    wallStripe: Color(0x09283450),
    shelf: Color(0x9EFFFFFF),
    shelfEdge: Color(0xE6FFFFFF),
    shelfShadow: [
      BoxShadow(color: Color(0x1A283450), offset: Offset(0, 8), blurRadius: 22),
    ],
    card: Color(0xFFFFFFFF),
    cardShadow: [
      BoxShadow(color: Color(0x1A283450), offset: Offset(0, 6), blurRadius: 18),
    ],
    chip: Color(0x12283450),
    ink: Color(0xFF1D2230),
    ink2: Color(0xFF5A6274),
    ink3: Color(0xFF8C93A3),
    hairline: Color(0x1A283450),
    tabActive: Color(0xFFFFFFFF),
    scrim: Color(0xFFECEFF4),
    focusGap: Color(0xFFFFFFFF),
    padNeutral: Color(0xFF3A4152),
    goodInk: Color(0xFF138A55),
    accentInk: Color(0xFFC45500),
    badInk: Color(0xFFC62F2F),
  );

  /// Night mode.
  static const night = TshopTokens(
    brightness: Brightness.dark,
    wallTop: Color(0xFF1A1D26),
    wallBottom: Color(0xFF10121A),
    wallStripe: Color(0x06FFFFFF),
    shelf: Color(0x0DFFFFFF),
    shelfEdge: Color(0x14FFFFFF),
    shelfShadow: [
      BoxShadow(
        color: Color(0x59000000),
        offset: Offset(0, 10),
        blurRadius: 26,
      ),
    ],
    card: Color(0xFF232733),
    cardShadow: [
      BoxShadow(color: Color(0x59000000), offset: Offset(0, 8), blurRadius: 22),
    ],
    chip: Color(0x14FFFFFF),
    ink: Color(0xFFF2F4F8),
    ink2: Color(0xFFAAB1C0),
    ink3: Color(0xFF727A8C),
    hairline: Color(0x14FFFFFF),
    tabActive: Color(0x24FFFFFF),
    scrim: Color(0xFF181B24),
    focusGap: Color(0xFF10121A),
    padNeutral: Color(0xFF4A5266),
    goodInk: Color(0xFF4FDC9A),
    accentInk: Color(0xFFFFA25C),
    badInk: Color(0xFFFF8080),
  );

  /// Wallpaper gradient behind every screen.
  LinearGradient get wallpaper => LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [wallTop, wallBottom],
  );

  /// The 3 dp gap + 3 dp orange ring + glow. [breath] 0–1 brightens it.
  ///
  /// Flutter paints shadows in list order, so the gap goes last to sit on
  /// top of the ring.
  List<BoxShadow> focusRing({double breath = 0}) => [
    BoxShadow(
      color: Color.lerp(
        TshopBrand.accentSoft,
        const Color(0x80FF7A1A),
        breath,
      )!,
      offset: const Offset(0, 10),
      blurRadius: lerpDouble(24, 30, breath)!,
    ),
    BoxShadow(
      color: Color.lerp(TshopBrand.accent, TshopBrand.accentBright, breath)!,
      spreadRadius: 6,
    ),
    BoxShadow(color: focusGap, spreadRadius: 3),
  ];

  @override
  TshopTokens copyWith({
    Brightness? brightness,
    Color? wallTop,
    Color? wallBottom,
    Color? wallStripe,
    Color? shelf,
    Color? shelfEdge,
    List<BoxShadow>? shelfShadow,
    Color? card,
    List<BoxShadow>? cardShadow,
    Color? chip,
    Color? ink,
    Color? ink2,
    Color? ink3,
    Color? hairline,
    Color? tabActive,
    Color? scrim,
    Color? focusGap,
    Color? padNeutral,
    Color? goodInk,
    Color? accentInk,
    Color? badInk,
  }) {
    return TshopTokens(
      brightness: brightness ?? this.brightness,
      wallTop: wallTop ?? this.wallTop,
      wallBottom: wallBottom ?? this.wallBottom,
      wallStripe: wallStripe ?? this.wallStripe,
      shelf: shelf ?? this.shelf,
      shelfEdge: shelfEdge ?? this.shelfEdge,
      shelfShadow: shelfShadow ?? this.shelfShadow,
      card: card ?? this.card,
      cardShadow: cardShadow ?? this.cardShadow,
      chip: chip ?? this.chip,
      ink: ink ?? this.ink,
      ink2: ink2 ?? this.ink2,
      ink3: ink3 ?? this.ink3,
      hairline: hairline ?? this.hairline,
      tabActive: tabActive ?? this.tabActive,
      scrim: scrim ?? this.scrim,
      focusGap: focusGap ?? this.focusGap,
      padNeutral: padNeutral ?? this.padNeutral,
      goodInk: goodInk ?? this.goodInk,
      accentInk: accentInk ?? this.accentInk,
      badInk: badInk ?? this.badInk,
    );
  }

  @override
  TshopTokens lerp(TshopTokens? other, double t) {
    if (other == null) return this;
    Color c(Color a, Color b) => Color.lerp(a, b, t)!;
    List<BoxShadow> s(List<BoxShadow> a, List<BoxShadow> b) =>
        BoxShadow.lerpList(a, b, t)!;
    return TshopTokens(
      brightness: t < 0.5 ? brightness : other.brightness,
      wallTop: c(wallTop, other.wallTop),
      wallBottom: c(wallBottom, other.wallBottom),
      wallStripe: c(wallStripe, other.wallStripe),
      shelf: c(shelf, other.shelf),
      shelfEdge: c(shelfEdge, other.shelfEdge),
      shelfShadow: s(shelfShadow, other.shelfShadow),
      card: c(card, other.card),
      cardShadow: s(cardShadow, other.cardShadow),
      chip: c(chip, other.chip),
      ink: c(ink, other.ink),
      ink2: c(ink2, other.ink2),
      ink3: c(ink3, other.ink3),
      hairline: c(hairline, other.hairline),
      tabActive: c(tabActive, other.tabActive),
      scrim: c(scrim, other.scrim),
      focusGap: c(focusGap, other.focusGap),
      padNeutral: c(padNeutral, other.padNeutral),
      goodInk: c(goodInk, other.goodInk),
      accentInk: c(accentInk, other.accentInk),
      badInk: c(badInk, other.badInk),
    );
  }
}

/// Shorthand for the current [TshopTokens].
extension TshopTokensContext on BuildContext {
  /// Tokens for the nearest [Theme]; falls back to [TshopTokens.day].
  TshopTokens get tshop =>
      Theme.of(this).extension<TshopTokens>() ?? TshopTokens.day;
}
