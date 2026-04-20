import 'package:flutter/material.dart';
import 'dart:ui' as ui;

//* Colors
// We map these to our Neumorphic design system.
abstract class AppColors {
  // Light Theme Colors
  static const Color lightBg = Color(0xFFFFF5E0); // Principal
  static const Color lightSecondary = Color(0xFF8DECB4); // Segundo
  static const Color lightTertiary = Color(0xFF41B06E); // Tercer
  static const Color lightQuaternary = Color(0xFF141E46); // Cuarto

  // Dark Theme Colors
  static const Color darkBg = Color(0xFF18230F); // Principal
  static const Color darkSecondary = Color(0xFF27391C); // Segundo
  static const Color darkTertiary = Color(0xFF255F38); // Tercer
  static const Color darkQuaternary = Color(0xFF1F7D53); // Cuarto
}

//* Typography constants
abstract class AppTypography {
  // Heading sizes
  static const double h1 = 36.0;
  static const double h2 = 32.0;
  static const double h3 = 28.0;
  static const double h4 = 24.0;
  static const double h5 = 20.0;
  static const double h6 = 18.0;

  // Body sizes
  static const double bodyLarge = 16.0;
  static const double bodyMedium = 14.0;
  static const double bodySmall = 12.0;
  static const double bodyXSmall = 11.0;

  // Caption
  static const double caption = 12.0;
  static const double captionSmall = 10.0;

  // Font weights
  static const FontWeight light = FontWeight.w300;
  static const FontWeight normal = FontWeight.w400;
  static const FontWeight medium = FontWeight.w500;
  static const FontWeight semibold = FontWeight.w600;
  static const FontWeight bold = FontWeight.w700;
  static const FontWeight extraBold = FontWeight.w800;
}

//* Spacing and size constants
abstract class AppDimens {
  // Padding and margins
  static const double xs = 4.0;
  static const double sm = 8.0;
  static const double md = 12.0;
  static const double lg = 16.0;
  static const double xl = 20.0;
  static const double xxl = 24.0;
  static const double xxxl = 32.0;

  // Border radius
  static const double radiusSmall = 4.0;
  static const double radiusMedium = 8.0;
  static const double radiusLarge = 12.0;
  static const double radiusXLarge = 16.0;
  static const double radiusApple = 22.0;
  static const double radiusPill = 50.0;

  // Component sizes
  static const double bottomNavHeight = 70.0;
  static const double navbarHeight = 86.0;
  static const double touchTargetMin = 48.0;

  // Icon sizes
  static const double iconSmall = 16.0;
  static const double iconMedium = 24.0;
  static const double iconLarge = 28.0;
  static const double iconXLarge = 32.0;
}

//* Custom ThemeExtension for Neumorphic Design Tokens
// This allows us to inject custom shadows and blur amounts directly into the theme,
// keeping our UI components clean and completely decoupled from hardcoded values.
class AppDesignTokens extends ThemeExtension<AppDesignTokens> {
  final double blurAmount;
  final BorderRadius cardRadius;
  final List<BoxShadow> neumorphicShadow;
  final List<BoxShadow> neumorphicPressedShadow;

  const AppDesignTokens({
    required this.blurAmount,
    required this.cardRadius,
    required this.neumorphicShadow,
    required this.neumorphicPressedShadow,
  });

  @override
  ThemeExtension<AppDesignTokens> copyWith({
    double? blurAmount,
    BorderRadius? cardRadius,
    List<BoxShadow>? neumorphicShadow,
    List<BoxShadow>? neumorphicPressedShadow,
  }) {
    return AppDesignTokens(
      blurAmount: blurAmount ?? this.blurAmount,
      cardRadius: cardRadius ?? this.cardRadius,
      neumorphicShadow: neumorphicShadow ?? this.neumorphicShadow,
      neumorphicPressedShadow:
          neumorphicPressedShadow ?? this.neumorphicPressedShadow,
    );
  }

  @override
  ThemeExtension<AppDesignTokens> lerp(
    ThemeExtension<AppDesignTokens>? other,
    double t,
  ) {
    if (other is! AppDesignTokens) return this;
    return AppDesignTokens(
      blurAmount: ui.lerpDouble(blurAmount, other.blurAmount, t) ?? blurAmount,
      cardRadius:
          BorderRadius.lerp(cardRadius, other.cardRadius, t) ?? cardRadius,
      neumorphicShadow:
          BoxShadow.lerpList(neumorphicShadow, other.neumorphicShadow, t) ??
          neumorphicShadow,
      neumorphicPressedShadow:
          BoxShadow.lerpList(
            neumorphicPressedShadow,
            other.neumorphicPressedShadow,
            t,
          ) ??
          neumorphicPressedShadow,
    );
  }
}

//* Custom ThemeData for the app
class AppTheme {
  // Light Neumorphic Tokens
  static final AppDesignTokens _lightTokens = AppDesignTokens(
    blurAmount: 16.0,
    cardRadius: BorderRadius.circular(AppDimens.radiusApple),
    neumorphicShadow: [
      const BoxShadow(
        color: Colors.white, // Light source from top-left (lighter than FFF5E0)
        offset: Offset(-5, -5),
        blurRadius: 10,
      ),
      const BoxShadow(
        color: Color(0xFFE5DCC9), // Darker shade of lightBg for shadow
        offset: Offset(5, 5),
        blurRadius: 10,
      ),
    ],
    neumorphicPressedShadow: [
      const BoxShadow(
        color: Colors.white,
        offset: Offset(-2, -2),
        blurRadius: 5,
      ),
      const BoxShadow(
        color: Color(0xFFE5DCC9),
        offset: Offset(2, 2),
        blurRadius: 5,
      ),
    ],
  );

  // Dark Neumorphic Tokens
  static final AppDesignTokens _darkTokens = AppDesignTokens(
    blurAmount: 20.0,
    cardRadius: BorderRadius.circular(AppDimens.radiusApple),
    neumorphicShadow: [
      const BoxShadow(
        color: Color(0xFF233316), // Lighter shade of darkBg
        offset: Offset(-5, -5),
        blurRadius: 10,
      ),
      const BoxShadow(
        color: Color(0xFF0D1308), // Darker shade of darkBg
        offset: Offset(5, 5),
        blurRadius: 10,
      ),
    ],
    neumorphicPressedShadow: [
      const BoxShadow(
        color: Color(0xFF233316),
        offset: Offset(-2, -2),
        blurRadius: 5,
      ),
      const BoxShadow(
        color: Color(0xFF0D1308),
        offset: Offset(2, 2),
        blurRadius: 5,
      ),
    ],
  );

  /// Light theme
  static ThemeData lightTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    primaryColor: AppColors.lightTertiary,
    scaffoldBackgroundColor: AppColors.lightBg,
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.lightTertiary,
      brightness: Brightness.light,
      primary: AppColors.lightTertiary,
      secondary: AppColors.lightSecondary,
      surface: AppColors.lightBg,
      onSurface: AppColors.lightQuaternary,
    ),
    textTheme: TextTheme(
      displayLarge: const TextStyle(
        fontSize: AppTypography.h1,
        fontWeight: AppTypography.extraBold,
        color: AppColors.lightQuaternary,
      ),
      displayMedium: const TextStyle(
        fontSize: AppTypography.h2,
        fontWeight: AppTypography.bold,
        color: AppColors.lightQuaternary,
      ),
      displaySmall: const TextStyle(
        fontSize: AppTypography.h3,
        fontWeight: AppTypography.bold,
        color: AppColors.lightQuaternary,
      ),
      headlineLarge: const TextStyle(
        fontSize: AppTypography.h4,
        fontWeight: AppTypography.semibold,
        color: AppColors.lightQuaternary,
      ),
      titleLarge: const TextStyle(
        fontSize: AppTypography.h5,
        fontWeight: AppTypography.semibold,
        color: AppColors.lightQuaternary,
      ),
      bodyLarge: const TextStyle(
        fontSize: AppTypography.bodyLarge,
        fontWeight: AppTypography.normal,
        color: AppColors.lightQuaternary,
      ),
      bodyMedium: const TextStyle(
        fontSize: AppTypography.bodyMedium,
        fontWeight: AppTypography.normal,
        color: AppColors.lightQuaternary,
      ),
      bodySmall: const TextStyle(
        fontSize: AppTypography.bodySmall,
        fontWeight: AppTypography.normal,
        color: AppColors.lightQuaternary,
      ),
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.transparent,
      elevation: 0,
      iconTheme: IconThemeData(color: AppColors.lightQuaternary),
      titleTextStyle: TextStyle(
        fontSize: AppTypography.h5,
        fontWeight: AppTypography.semibold,
        color: AppColors.lightQuaternary,
      ),
    ),
    bottomNavigationBarTheme: BottomNavigationBarThemeData(
      backgroundColor: AppColors.lightBg,
      selectedItemColor: AppColors.lightTertiary,
      unselectedItemColor: AppColors.lightQuaternary.withValues(alpha: 0.5),
      showUnselectedLabels: true,
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.lightTertiary,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDimens.radiusMedium),
        ),
      ),
    ),
    visualDensity: VisualDensity.adaptivePlatformDensity,
    extensions: [_lightTokens],
  );

  /// Dark theme
  static ThemeData darkTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    primaryColor: AppColors.darkTertiary,
    scaffoldBackgroundColor: AppColors.darkBg,
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.darkTertiary,
      brightness: Brightness.dark,
      primary: AppColors.darkTertiary,
      secondary: AppColors.darkSecondary,
      surface: AppColors.darkBg,
      onSurface: Colors.white,
    ),
    textTheme: TextTheme(
      displayLarge: const TextStyle(
        fontSize: AppTypography.h1,
        fontWeight: AppTypography.extraBold,
        color: Colors.white,
      ),
      displayMedium: const TextStyle(
        fontSize: AppTypography.h2,
        fontWeight: AppTypography.bold,
        color: Colors.white,
      ),
      displaySmall: const TextStyle(
        fontSize: AppTypography.h3,
        fontWeight: AppTypography.bold,
        color: Colors.white,
      ),
      headlineLarge: const TextStyle(
        fontSize: AppTypography.h4,
        fontWeight: AppTypography.semibold,
        color: Colors.white,
      ),
      titleLarge: const TextStyle(
        fontSize: AppTypography.h5,
        fontWeight: AppTypography.semibold,
        color: Colors.white,
      ),
      bodyLarge: const TextStyle(
        fontSize: AppTypography.bodyLarge,
        fontWeight: AppTypography.normal,
        color: Colors.white70,
      ),
      bodyMedium: const TextStyle(
        fontSize: AppTypography.bodyMedium,
        fontWeight: AppTypography.normal,
        color: Colors.white70,
      ),
      bodySmall: const TextStyle(
        fontSize: AppTypography.bodySmall,
        fontWeight: AppTypography.normal,
        color: Colors.white60,
      ),
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.transparent,
      elevation: 0,
      iconTheme: IconThemeData(color: Colors.white),
      titleTextStyle: TextStyle(
        fontSize: AppTypography.h5,
        fontWeight: AppTypography.semibold,
        color: Colors.white,
      ),
    ),
    bottomNavigationBarTheme: BottomNavigationBarThemeData(
      backgroundColor: AppColors.darkBg,
      selectedItemColor: AppColors.darkTertiary,
      unselectedItemColor: Colors.white54,
      showUnselectedLabels: true,
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.darkTertiary,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDimens.radiusMedium),
        ),
      ),
    ),
    visualDensity: VisualDensity.adaptivePlatformDensity,
    extensions: [_darkTokens],
  );
}
