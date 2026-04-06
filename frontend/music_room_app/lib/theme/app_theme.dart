import 'package:flutter/material.dart';

//! Colors
abstract class AppColors {
  // * Primary colors
  // ? are gonna change in the future
  static const Color primaryDark = Color.fromARGB(255, 104, 104, 104);
  static const Color primaryRed = Color.fromARGB(255, 255, 0, 8);

  // * Utility colors
  static const Color backgroundLight = Color.fromARGB(255, 255, 17, 255);
}

//! Typography constants
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

//!  Spacing and size constants
abstract class AppDimens {
  // * Padding and margins
  static const double xs = 4.0;
  static const double sm = 8.0;
  static const double md = 12.0;
  static const double lg = 16.0;
  static const double xl = 20.0;
  static const double xxl = 24.0;
  static const double xxxl = 32.0;
  
  // * Border radius
  static const double radiusSmall = 4.0;
  static const double radiusMedium = 8.0;
  static const double radiusLarge = 12.0;
  static const double radiusXLarge = 16.0;
  static const double radiusPill = 50.0; // For fully rounded corners
  
  //* Component sizes
  static const double bottomNavHeight = 70.0;
  static const double navbarHeight = 86.0;
  static const double touchTargetMin = 48.0; // Minimum tap target size
  
  //* Icon sizes
  static const double iconSmall = 16.0;
  static const double iconMedium = 24.0;
  static const double iconLarge = 28.0;
  static const double iconXLarge = 32.0;
}

// * Centralized TextStyles for the app
abstract class AppTextStyles {
  static const TextStyle displayLarge = TextStyle(
    fontSize: AppTypography.h1,
    fontWeight: AppTypography.extraBold,
    color: AppColors.primaryDark,
  );

  static const TextStyle titleLarge = TextStyle(
    fontSize: AppTypography.h5,
    fontWeight: AppTypography.semibold,
    color: AppColors.primaryDark,
  );

  static const TextStyle bodyLarge = TextStyle(
    fontSize: AppTypography.bodyLarge,
    fontWeight: AppTypography.normal,
    color: AppColors.primaryDark,
  );
}

/// ! Custom ThemeData for the app
class AppTheme {
  static final TextTheme _textTheme = TextTheme(
    displayLarge: AppTextStyles.displayLarge,
    displayMedium: TextStyle(fontSize: AppTypography.h2, fontWeight: AppTypography.bold, color: AppColors.primaryDark),
    displaySmall: TextStyle(fontSize: AppTypography.h3, fontWeight: AppTypography.bold, color: AppColors.primaryDark),
    headlineLarge: TextStyle(fontSize: AppTypography.h4, fontWeight: AppTypography.semibold, color: AppColors.primaryDark),
    titleLarge: AppTextStyles.titleLarge,
    bodyLarge: AppTextStyles.bodyLarge,
    bodyMedium: TextStyle(fontSize: AppTypography.bodyMedium, fontWeight: AppTypography.normal, color: AppColors.primaryDark),
    bodySmall: TextStyle(fontSize: AppTypography.bodySmall, fontWeight: AppTypography.normal, color: AppColors.primaryDark),
    labelSmall: TextStyle(fontSize: AppTypography.captionSmall, fontWeight: AppTypography.medium, color: AppColors.primaryRed),
  );

  // * Reusable button style for primary actions
  static final ButtonStyle primaryButtonStyle = ElevatedButton.styleFrom(
    backgroundColor: AppColors.primaryRed,
    foregroundColor: Colors.white,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppDimens.radiusMedium),
    ),
    padding: const EdgeInsets.symmetric(
      horizontal: AppDimens.lg,
      vertical: AppDimens.sm,
    ),
  );

  /// Light theme (primary)
  static ThemeData lightTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    primaryColor: AppColors.primaryDark,
    scaffoldBackgroundColor: Colors.white,
    colorScheme: ColorScheme.light(
      primary: AppColors.primaryDark,
      onPrimary: Colors.white,
      secondary: AppColors.primaryRed,
      onSurface: AppColors.primaryDark,
    ),
    textTheme: _textTheme,
    appBarTheme: AppBarTheme(
      backgroundColor: AppColors.primaryDark,
      titleTextStyle: _textTheme.titleLarge?.copyWith(color: Colors.white),
      iconTheme: const IconThemeData(color: Colors.white),
      elevation: 0,
    ),
    bottomNavigationBarTheme: BottomNavigationBarThemeData(
      backgroundColor: AppColors.primaryDark,
      selectedItemColor: AppColors.primaryRed,
      unselectedItemColor: Colors.grey.shade600,
      showUnselectedLabels: true,
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primaryRed,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDimens.radiusMedium),
        ),
      ),
    ),
    visualDensity: VisualDensity.adaptivePlatformDensity,
  );
}
