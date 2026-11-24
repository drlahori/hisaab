import 'package:flutter/material.dart';

import 'store.dart';

/// The three looks a user can choose in More → Appearance. Light only.
class HStyle {
  const HStyle({
    required this.id,
    required this.name,
    required this.desc,
    required this.font,
    required this.headFont,
    required this.bg,
    required this.card,
    required this.cardBorder,
    required this.text,
    required this.sub,
    required this.chip,
    required this.accent,
    required this.onAccent,
    required this.ui,
    required this.nav,
    required this.navOff,
    required this.inc,
    required this.exp,
    required this.avatarRadius,
    required this.groupDays,
  });

  final String id;
  final String name;
  final String desc;
  final String font;
  final String headFont;
  final Color bg; // page background
  final Color card; // cards and rows
  final Color cardBorder;
  final Color text;
  final Color sub; // secondary text
  final Color chip; // small filled surfaces
  final Color accent; // big fills: Add button, hero card, highlights
  final Color onAccent;
  final Color ui; // accent used for small text and icons (readable on bg)
  final Color nav; // floating bottom bar
  final Color navOff;
  final Color inc;
  final Color exp;
  final double avatarRadius; // 0.5 = circle, else corner radius as a fraction
  final bool groupDays; // true: one card per day; false: one card per transaction
}

const kStyles = <HStyle>[
  HStyle(
    id: 'clean',
    name: 'Clean',
    desc: 'Bright and calm, with a teal balance card',
    font: 'Inter',
    headFont: 'Inter',
    bg: Color(0xFFF6F7F9),
    card: Color(0xFFFFFFFF),
    cardBorder: Color(0xFFE5E7EB),
    text: Color(0xFF111827),
    sub: Color(0xFF4B5563),
    chip: Color(0xFFE9ECEF),
    accent: Color(0xFF0F766E),
    onAccent: Color(0xFFFFFFFF),
    ui: Color(0xFF0F766E),
    nav: Color(0xFF111827),
    navOff: Color(0xFF9CA3AF),
    inc: Color(0xFF15803D),
    exp: Color(0xFFC2410C),
    avatarRadius: 0.3,
    groupDays: true,
  ),
  HStyle(
    id: 'midnight',
    name: 'Midnight',
    desc: 'Navy and gold, with a big centred total',
    font: 'Manrope',
    headFont: 'Manrope',
    bg: Color(0xFFF4F1EA),
    card: Color(0xFFFFFFFF),
    cardBorder: Color(0xFFE7E1D5),
    text: Color(0xFF0E1524),
    sub: Color(0xFF5B6577),
    chip: Color(0xFFFFFFFF),
    accent: Color(0xFFF5B841),
    onAccent: Color(0xFF0E1524),
    ui: Color(0xFF0E1524),
    nav: Color(0xFF0E1524),
    navOff: Color(0xFF94A3B8),
    inc: Color(0xFF15803D),
    exp: Color(0xFFC2410C),
    avatarRadius: 0.5,
    groupDays: false,
  ),
  HStyle(
    id: 'bold',
    name: 'Bold',
    desc: 'Warm colours, chunky cards and a spending chart',
    font: 'Inter',
    headFont: 'SpaceGrotesk',
    bg: Color(0xFFFFF8F3),
    card: Color(0xFFFFFFFF),
    cardBorder: Color(0xFFF0E6DE),
    text: Color(0xFF1C1917),
    sub: Color(0xFF57534E),
    chip: Color(0xFFF5EBE3),
    accent: Color(0xFFE2553F),
    onAccent: Color(0xFFFFFFFF),
    ui: Color(0xFFB8402D),
    nav: Color(0xFF1C1917),
    navOff: Color(0xFFA8A29E),
    inc: Color(0xFF15803D),
    exp: Color(0xFFB8402D),
    avatarRadius: 0.32,
    groupDays: false,
  ),
];

HStyle styleById(String? id) =>
    kStyles.firstWhere((s) => s.id == id, orElse: () => kStyles.first);

/// The style currently chosen in settings.
HStyle get hs => styleById(store.style);

/// Soft background + strong foreground pairs for category avatars.
const _tints = <(Color, Color)>[
  (Color(0xFFFEF3C7), Color(0xFF92400E)),
  (Color(0xFFDBEAFE), Color(0xFF1E40AF)),
  (Color(0xFFFCE7F3), Color(0xFF9D174D)),
  (Color(0xFFDCFCE7), Color(0xFF166534)),
  (Color(0xFFEDE9FE), Color(0xFF5B21B6)),
  (Color(0xFFFFEDD5), Color(0xFF9A3412)),
  (Color(0xFFCCFBF1), Color(0xFF115E59)),
  (Color(0xFFE0E7FF), Color(0xFF3730A3)),
];

(Color, Color) tintFor(String? key) {
  if (key == null || key.isEmpty) return _tints[0];
  var h = 0;
  for (final c in key.codeUnits) {
    h = (h * 31 + c) & 0x7fffffff;
  }
  return _tints[h % _tints.length];
}

ThemeData buildTheme(HStyle s) {
  final scheme = ColorScheme.fromSeed(seedColor: s.accent, brightness: Brightness.light).copyWith(
    primary: s.ui,
    onPrimary: Colors.white,
    secondaryContainer: s.chip,
    onSecondaryContainer: s.text,
    surface: s.bg,
    onSurface: s.text,
    onSurfaceVariant: s.sub,
    surfaceContainerHighest: s.chip,
    surfaceContainerLow: s.card,
    surfaceContainer: s.card,
    outlineVariant: s.cardBorder,
  );
  final base = ThemeData(useMaterial3: true, colorScheme: scheme, fontFamily: s.font);
  return base.copyWith(
    scaffoldBackgroundColor: s.bg,
    textTheme: base.textTheme.copyWith(
      headlineMedium: base.textTheme.headlineMedium?.copyWith(fontFamily: s.headFont, fontWeight: FontWeight.w700),
      titleLarge: base.textTheme.titleLarge?.copyWith(fontFamily: s.headFont, fontWeight: FontWeight.w700),
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: s.bg,
      foregroundColor: s.text,
      surfaceTintColor: Colors.transparent,
      scrolledUnderElevation: 0,
      titleTextStyle: TextStyle(
          fontFamily: s.headFont, fontSize: 20, fontWeight: FontWeight.w700, color: s.text),
    ),
    cardTheme: CardThemeData(
      color: s.card,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: s.cardBorder),
      ),
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: s.accent,
      foregroundColor: s.onAccent,
      elevation: 3,
      shape: const StadiumBorder(),
      extendedTextStyle: TextStyle(fontFamily: s.font, fontWeight: FontWeight.w700, fontSize: 15),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(backgroundColor: s.accent, foregroundColor: s.onAccent),
    ),
    dialogTheme: DialogThemeData(backgroundColor: s.card, surfaceTintColor: Colors.transparent),
    bottomSheetTheme: BottomSheetThemeData(backgroundColor: s.card, surfaceTintColor: Colors.transparent),
  );
}
