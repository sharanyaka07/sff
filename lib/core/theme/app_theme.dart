  import 'package:flutter/material.dart';
  import 'package:flutter/services.dart';

  class AppColors {
    // ── Primary Brand (Sky Blue) ───────────────────────────────────
    static const Color primary       = Color(0xFF29B6F6); // Sky Blue
    static const Color primaryLight  = Color(0xFF4FC3F7); // Light Sky
    static const Color primaryDark   = Color(0xFF0288D1); // Deep Sky

    // ── Accent ────────────────────────────────────────────────────
    static const Color accent        = Color(0xFF00E5FF); // Cyan glow
    static const Color accentDark    = Color(0xFF00B8D4);

    // ── Backgrounds (Midnight Blue) ────────────────────────────────
    static const Color background    = Color(0xFF0A1628); // Deep Midnight
    static const Color surface       = Color(0xFF112240); // Navy Surface
    static const Color surfaceLight  = Color(0xFF1A3057); // Lighter Navy
    static const Color cardBg        = Color(0xFF112240); // Same as surface

    // ── Borders ───────────────────────────────────────────────────
    static const Color border        = Color(0xFF1E3A5F); // Subtle border
    static const Color borderLight   = Color(0xFF29B6F6); // Active border

    // ── Text ──────────────────────────────────────────────────────
    static const Color textPrimary   = Color(0xFFE8F4FD); // Near white
    static const Color textSecondary = Color(0xFF90CAF9); // Soft blue
    static const Color textHint      = Color(0xFF4A6FA5); // Muted blue
    static const Color white         = Color(0xFFFFFFFF);

    // ── SOS / Emergency ───────────────────────────────────────────
    static const Color danger        = Color(0xFFFF1744); // Vivid Red
    static const Color dangerLight   = Color(0xFFFF5252);
    static const Color dangerDark    = Color(0xFFD50000);
    static const Color alert         = Color(0xFFFF1744); // alias for danger

    // ── Status ────────────────────────────────────────────────────
    static const Color success       = Color(0xFF00E676); // Neon Green
    static const Color warning       = Color(0xFFFFD740); // Amber
    static const Color info          = Color(0xFF29B6F6); // Same as primary

    // ── Bluetooth ─────────────────────────────────────────────────
    static const Color bluetooth       = Color(0xFF29B6F6);
    static const Color bluetoothActive = Color(0xFF00E5FF);
  }

  class AppTheme {
    static ThemeData get lightTheme => darkTheme; // single theme

    static ThemeData get darkTheme {
      return ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorScheme:  const ColorScheme.dark(
          primary: AppColors.primary,
          secondary: AppColors.accent,
          surface: AppColors.surface,
          error: AppColors.danger,
        ),
        scaffoldBackgroundColor: AppColors.background,

        // ── AppBar ───────────────────────────────────────────────
        appBarTheme: const AppBarTheme(
          backgroundColor: AppColors.surface,
          foregroundColor: AppColors.textPrimary,
          centerTitle: true,
          elevation: 0,
          systemOverlayStyle: SystemUiOverlayStyle(
            statusBarColor: AppColors.background,
            statusBarIconBrightness: Brightness.light,
          ),
          titleTextStyle: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 20,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
          iconTheme: IconThemeData(color: AppColors.primary),
        ),

        // ── Bottom Navigation ─────────────────────────────────────
        bottomNavigationBarTheme: const BottomNavigationBarThemeData(
          backgroundColor: AppColors.surface,
          selectedItemColor: AppColors.primary,
          unselectedItemColor: AppColors.textHint,
          selectedLabelStyle: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 12,
          ),
          unselectedLabelStyle: TextStyle(fontSize: 12),
          type: BottomNavigationBarType.fixed,
          elevation: 8,
        ),

        // ── Cards ─────────────────────────────────────────────────
        cardTheme: CardThemeData(
          color: AppColors.surface,
          elevation: 0,
          shadowColor: Colors.black38,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: AppColors.border, width: 1),
          ),
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        ),

        // ── Elevated Buttons ──────────────────────────────────────
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: AppColors.background,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            textStyle: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),

        // ── Input Fields ──────────────────────────────────────────
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: AppColors.surfaceLight,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColors.border),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColors.border, width: 1),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColors.primary, width: 2),
          ),
          labelStyle: const TextStyle(color: AppColors.textSecondary),
          hintStyle: const TextStyle(color: AppColors.textHint),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 14,
          ),
        ),

        // ── Divider ───────────────────────────────────────────────
        dividerTheme: const DividerThemeData(
          color: AppColors.border,
          thickness: 1,
        ),

        // ── Icon ──────────────────────────────────────────────────
        iconTheme: const IconThemeData(color: AppColors.textSecondary),

        // ── Text ──────────────────────────────────────────────────
        textTheme: const TextTheme(
          headlineLarge: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
          headlineMedium: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
          titleLarge: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
          bodyLarge: TextStyle(
            fontSize: 16,
            color: AppColors.textPrimary,
          ),
          bodyMedium: TextStyle(
            fontSize: 14,
            color: AppColors.textSecondary,
          ),
          bodySmall: TextStyle(
            fontSize: 12,
            color: AppColors.textHint,
          ),
        ),
      );
    }
  }