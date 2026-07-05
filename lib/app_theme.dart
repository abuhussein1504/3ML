import 'package:flutter/material.dart';

class AppColors extends ThemeExtension<AppColors> {
  final Color bgPrimary;
  final Color bgSecondary;
  final Color bgCard;
  final Color bgCardAlt;
  final Color textPrimary;
  final Color textSecondary;
  final Color textMuted;
  final Color border;
  final Color borderLight;
  final Color inputFill;

  const AppColors({
    required this.bgPrimary,
    required this.bgSecondary,
    required this.bgCard,
    required this.bgCardAlt,
    required this.textPrimary,
    required this.textSecondary,
    required this.textMuted,
    required this.border,
    required this.borderLight,
    required this.inputFill,
  });

  @override
  AppColors copyWith({
    Color? bgPrimary,
    Color? bgSecondary,
    Color? bgCard,
    Color? bgCardAlt,
    Color? textPrimary,
    Color? textSecondary,
    Color? textMuted,
    Color? border,
    Color? borderLight,
    Color? inputFill,
  }) =>
      AppColors(
        bgPrimary: bgPrimary ?? this.bgPrimary,
        bgSecondary: bgSecondary ?? this.bgSecondary,
        bgCard: bgCard ?? this.bgCard,
        bgCardAlt: bgCardAlt ?? this.bgCardAlt,
        textPrimary: textPrimary ?? this.textPrimary,
        textSecondary: textSecondary ?? this.textSecondary,
        textMuted: textMuted ?? this.textMuted,
        border: border ?? this.border,
        borderLight: borderLight ?? this.borderLight,
        inputFill: inputFill ?? this.inputFill,
      );

  @override
  AppColors lerp(AppColors? other, double t) {
    if (other is! AppColors) return this;
    return AppColors(
      bgPrimary: Color.lerp(bgPrimary, other.bgPrimary, t)!,
      bgSecondary: Color.lerp(bgSecondary, other.bgSecondary, t)!,
      bgCard: Color.lerp(bgCard, other.bgCard, t)!,
      bgCardAlt: Color.lerp(bgCardAlt, other.bgCardAlt, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      textMuted: Color.lerp(textMuted, other.textMuted, t)!,
      border: Color.lerp(border, other.border, t)!,
      borderLight: Color.lerp(borderLight, other.borderLight, t)!,
      inputFill: Color.lerp(inputFill, other.inputFill, t)!,
    );
  }

  static const dark = AppColors(
    bgPrimary:    Color(0xFF080C1A),
    bgSecondary:  Color(0xFF0F1628),
    bgCard:       Color(0xFF141D35),
    bgCardAlt:    Color(0xFF1A2440),
    textPrimary:  Color(0xFFEEF2FF),
    textSecondary:Color(0xFF7B87A8),
    textMuted:    Color(0xFF3D4A6B),
    border:       Color(0xFF1E2D50),
    borderLight:  Color(0xFF2A3A60),
    inputFill:    Color(0xFF141D35),
  );

  static const light = AppColors(
    bgPrimary:    Color(0xFFF0F2FA),
    bgSecondary:  Color(0xFFE8ECF6),
    bgCard:       Color(0xFFFFFFFF),
    bgCardAlt:    Color(0xFFE2E8F4),
    textPrimary:  Color(0xFF0B1026),
    textSecondary:Color(0xFF3D4566),
    textMuted:    Color(0xFF5C6577),
    border:       Color(0xFFC9D0E8),
    borderLight:  Color(0xFFD8DEEE),
    inputFill:    Color(0xFFF8F9FD),
  );
}

extension AppColorsX on BuildContext {
  AppColors get appColors =>
      Theme.of(this).extension<AppColors>() ?? AppColors.dark;
}

class AppTheme {
  static const Color primary     = Color(0xFF00D4A1);
  static const Color primaryDark = Color(0xFF009E78);
  static const Color accent      = Color(0xFF7C6FFF);
  static const Color danger      = Color(0xFFFF5252);
  static const Color warning     = Color(0xFFFFB547);
  static const Color success     = Color(0xFF00D4A1);

  static const Color bgPrimary   = Color(0xFF080C1A);
  static const Color bgSecondary = Color(0xFF0F1628);
  static const Color bgCard      = Color(0xFF141D35);
  static const Color bgCardAlt   = Color(0xFF1A2440);
  static const Color textPrimary   = Color(0xFFEEF2FF);
  static const Color textSecondary = Color(0xFF7B87A8);
  static const Color textMuted     = Color(0xFF3D4A6B);
  static const Color border      = Color(0xFF1E2D50);
  static const Color borderLight = Color(0xFF2A3A60);

  static const LinearGradient primaryGradient = LinearGradient(
    colors: [Color(0xFF00D4A1), Color(0xFF00A8FF)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient dangerGradient = LinearGradient(
    colors: [Color(0xFFFF5252), Color(0xFFFF1744)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient cardGradient = LinearGradient(
    colors: [Color(0xFF141D35), Color(0xFF0F1628)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient cardGradientLight = LinearGradient(
    colors: [Color(0xFFFFFFFF), Color(0xFFECEFF8)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const List<Color> dayColors = [
    Color(0xFF00D4A1),
    Color(0xFF00C4F0),
    Color(0xFF7C6FFF),
    Color(0xFFFFB547),
    Color(0xFFFF7C7C),
  ];

  // ─── Dark Theme ────────────────────────────────────────────
  static ThemeData get darkTheme => ThemeData(
    brightness: Brightness.dark,
    scaffoldBackgroundColor: AppColors.dark.bgPrimary,
    colorScheme: ColorScheme.dark(
      primary: primary,
      secondary: accent,
      error: danger,
      surface: AppColors.dark.bgSecondary,
    ),
    fontFamily: 'Roboto',
    extensions: const [AppColors.dark],
    appBarTheme: AppBarTheme(
      backgroundColor: AppColors.dark.bgPrimary,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        color: AppColors.dark.textPrimary,
        fontSize: 20,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.5,
      ),
      iconTheme: IconThemeData(color: AppColors.dark.textPrimary),
    ),
    bottomNavigationBarTheme: BottomNavigationBarThemeData(
      backgroundColor: AppColors.dark.bgSecondary,
      selectedItemColor: primary,
      unselectedItemColor: AppColors.dark.textMuted,
      type: BottomNavigationBarType.fixed,
      elevation: 0,
      selectedLabelStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
      unselectedLabelStyle: const TextStyle(fontSize: 11),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.dark.bgCard,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: AppColors.dark.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: AppColors.dark.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: primary, width: 1.5),
      ),
      hintStyle: TextStyle(color: AppColors.dark.textMuted),
      labelStyle: TextStyle(color: AppColors.dark.textSecondary),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: primary,
        foregroundColor: AppColors.dark.bgPrimary,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
        elevation: 0,
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: primary,
        textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
      ),
    ),
    cardTheme: CardThemeData(
      color: AppColors.dark.bgCard,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: AppColors.dark.border, width: 1),
      ),
      margin: EdgeInsets.zero,
    ),
    dividerTheme: DividerThemeData(
      color: AppColors.dark.border,
      thickness: 1,
      space: 1,
    ),
    textTheme: TextTheme(
      displayLarge:  TextStyle(fontSize: 48, fontWeight: FontWeight.w900, color: AppColors.dark.textPrimary, letterSpacing: -2),
      displayMedium: TextStyle(fontSize: 36, fontWeight: FontWeight.w800, color: AppColors.dark.textPrimary, letterSpacing: -1.5),
      headlineLarge: TextStyle(fontSize: 28, fontWeight: FontWeight.w700, color: AppColors.dark.textPrimary, letterSpacing: -0.5),
      headlineMedium:TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: AppColors.dark.textPrimary),
      titleLarge:    TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.dark.textPrimary),
      titleMedium:   TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.dark.textPrimary),
      bodyLarge:     TextStyle(fontSize: 16, color: AppColors.dark.textPrimary, height: 1.5),
      bodyMedium:    TextStyle(fontSize: 14, color: AppColors.dark.textSecondary, height: 1.5),
      bodySmall:     TextStyle(fontSize: 12, color: AppColors.dark.textMuted),
    ),
  );

  // ─── Light Theme ───────────────────────────────────────────
  static ThemeData get lightTheme => ThemeData(
    brightness: Brightness.light,
    scaffoldBackgroundColor: AppColors.light.bgPrimary,
    colorScheme: ColorScheme.light(
      primary: primary,
      secondary: accent,
      error: danger,
      surface: AppColors.light.bgSecondary,
    ),
    fontFamily: 'Roboto',
    extensions: const [AppColors.light],
    appBarTheme: AppBarTheme(
      backgroundColor: AppColors.light.bgPrimary,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        color: AppColors.light.textPrimary,
        fontSize: 20,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.5,
      ),
      iconTheme: IconThemeData(color: AppColors.light.textPrimary),
    ),
    bottomNavigationBarTheme: BottomNavigationBarThemeData(
      backgroundColor: AppColors.light.bgSecondary,
      selectedItemColor: primary,
      unselectedItemColor: AppColors.light.textMuted,
      type: BottomNavigationBarType.fixed,
      elevation: 0,
      selectedLabelStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
      unselectedLabelStyle: const TextStyle(fontSize: 11),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.light.inputFill,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: AppColors.light.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: AppColors.light.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: primary, width: 1.5),
      ),
      hintStyle: TextStyle(color: AppColors.light.textMuted),
      labelStyle: TextStyle(color: AppColors.light.textSecondary),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: primary,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
        elevation: 0,
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: primary,
        textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
      ),
    ),
    cardTheme: CardThemeData(
      color: AppColors.light.bgCard,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: AppColors.light.border, width: 1),
      ),
      margin: EdgeInsets.zero,
    ),
    dividerTheme: DividerThemeData(
      color: AppColors.light.border,
      thickness: 1,
      space: 1,
    ),
    textTheme: TextTheme(
      displayLarge:  TextStyle(fontSize: 48, fontWeight: FontWeight.w900, color: AppColors.light.textPrimary, letterSpacing: -2),
      displayMedium: TextStyle(fontSize: 36, fontWeight: FontWeight.w800, color: AppColors.light.textPrimary, letterSpacing: -1.5),
      headlineLarge: TextStyle(fontSize: 28, fontWeight: FontWeight.w700, color: AppColors.light.textPrimary, letterSpacing: -0.5),
      headlineMedium:TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: AppColors.light.textPrimary),
      titleLarge:    TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.light.textPrimary),
      titleMedium:   TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.light.textPrimary),
      bodyLarge:     TextStyle(fontSize: 16, color: AppColors.light.textPrimary, height: 1.5),
      bodyMedium:    TextStyle(fontSize: 14, color: AppColors.light.textSecondary, height: 1.5),
      bodySmall:     TextStyle(fontSize: 12, color: AppColors.light.textMuted),
    ),
  );

  static BoxDecoration glassCard(BuildContext? context, {double radius = 20, Color? borderColor}) {
    final c = context?.appColors ?? AppColors.dark;
    return BoxDecoration(
      color: c.bgCard,
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(color: borderColor ?? c.border, width: 1),
    );
  }

  static BoxDecoration primaryCard(BuildContext? context, {double radius = 20}) {
    final isDark = context != null
        ? Theme.of(context).brightness == Brightness.dark
        : true;
    return BoxDecoration(
      gradient: isDark ? cardGradient : cardGradientLight,
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(color: primary.withValues(alpha: 0.25), width: 1),
    );
  }

  static BoxDecoration glassCardLegacy({double radius = 20, Color? borderColor}) =>
      BoxDecoration(
        color: bgCard,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: borderColor ?? border, width: 1),
      );

  static BoxDecoration primaryCardLegacy({double radius = 20}) =>
      BoxDecoration(
        gradient: cardGradient,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: primary.withValues(alpha: 0.25), width: 1),
      );
}

