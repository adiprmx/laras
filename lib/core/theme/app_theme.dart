import 'package:flutter/material.dart';
import 'package:laras/core/theme/app_colors.dart';
import 'package:laras/core/theme/app_text_styles.dart';

/// Jarak Laras. Grid 4 dp: semua jarak memakai kelipatan 4.
abstract final class AppSpacing {
  static const double xxs = 4;
  static const double xs = 8;
  static const double sm = 12;
  static const double md = 16;
  static const double lg = 20;
  static const double xl = 24;
  static const double xxl = 32;
  static const double xxxl = 48;

  /// Padding horizontal halaman.
  static const double pagePadding = md;

  /// Jarak antar bagian di satu layar.
  static const double sectionGap = xl;
}

/// Radius Laras. Satu sistem, satu aturan: hanya kontrol yang pill
/// (tombol, chip, input). Kartu dan sampul tidak pernah pill.
abstract final class AppRadius {
  /// Sampul lagu kecil di daftar.
  static const double coverSmall = 8;

  /// Sampul lagu besar di Now Playing, kartu album dan playlist.
  static const double coverLarge = 12;
  static const double card = 12;

  /// Sudut atas bottom sheet, semua sudut dialog.
  static const double sheet = 16;
  static const double dialog = 16;
}

/// Ukuran komponen Laras.
abstract final class AppSizes {
  /// Target sentuh minimum untuk semua elemen yang bisa diketuk.
  static const double touchTarget = 48;

  /// Tinggi baris lagu (sampul 48 dp, teks, tombol aksi 48 dp).
  static const double songRow = 64;

  /// Tinggi baris pengaturan.
  static const double settingsRow = 56;

  /// Tinggi tab bawah, ditambah area aman bawah perangkat.
  static const double tabBar = 64;

  /// Tinggi mini-player.
  static const double miniPlayer = 64;

  /// Tombol putar utama di Now Playing, di dalam area sentuh 72 dp.
  static const double playButton = 72;

  /// Ikon aksi di baris dan app bar.
  static const double icon = 24;

  /// Ikon kecil di dalam teks pendukung.
  static const double iconSmall = 20;
}

/// Tema Laras: mode gelap saja di v1.
///
/// Keputusan yang disengaja, bukan kelalaian: design lock owner menetapkan
/// basis hitam monokrom, dan satu mode yang diperiksa penuh lebih baik dari
/// dua mode setengah jadi. Token memakai nama semantik (canvas, surface,
/// textPrimary), bukan nama warna mentah, supaya mode terang pasca-v1 hanya
/// mengganti nilai token.
abstract final class AppTheme {
  static ThemeData get dark {
    final ColorScheme colorScheme = ColorScheme.dark(
      primary: AppColors.accent,
      onPrimary: AppColors.textOnAccent,
      secondary: AppColors.textSecondary,
      surface: AppColors.surface,
      onSurface: AppColors.textPrimary,
      error: AppColors.error,
      onError: AppColors.textPrimary,
    );

    return ThemeData(
      brightness: Brightness.dark,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: AppColors.canvas,
      textTheme: TextTheme(
        displayLarge:
            AppTextStyles.display.copyWith(color: AppColors.textPrimary),
        titleLarge:
            AppTextStyles.titleLarge.copyWith(color: AppColors.textPrimary),
        titleMedium:
            AppTextStyles.titleMedium.copyWith(color: AppColors.textPrimary),
        titleSmall:
            AppTextStyles.titleSmall.copyWith(color: AppColors.textPrimary),
        bodyLarge: AppTextStyles.body.copyWith(color: AppColors.textPrimary),
        bodyMedium:
            AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary),
        bodySmall:
            AppTextStyles.caption.copyWith(color: AppColors.textMuted),
        labelLarge:
            AppTextStyles.button.copyWith(color: AppColors.textPrimary),
        labelMedium:
            AppTextStyles.micro.copyWith(color: AppColors.textSecondary),
        labelSmall: AppTextStyles.caption.copyWith(color: AppColors.textMuted),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.canvas,
        elevation: 0,
        scrolledUnderElevation: 0,
        foregroundColor: AppColors.textPrimary,
        centerTitle: false,
        titleTextStyle: AppTextStyles.display,
        iconTheme: IconThemeData(color: AppColors.textPrimary),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: AppColors.canvas,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
        selectedItemColor: AppColors.textPrimary,
        unselectedItemColor: AppColors.textMuted,
        selectedLabelStyle: AppTextStyles.micro,
        unselectedLabelStyle: AppTextStyles.micro,
        showSelectedLabels: true,
        showUnselectedLabels: true,
      ),
      iconTheme: const IconThemeData(color: AppColors.textPrimary),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.accent,
          foregroundColor: AppColors.textOnAccent,
          textStyle: AppTextStyles.button,
          shape: const StadiumBorder(),
          minimumSize: const Size(0, AppSizes.touchTarget),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.xl,
            vertical: AppSpacing.sm,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.textPrimary,
          textStyle: AppTextStyles.button,
          shape: const StadiumBorder(),
          side: const BorderSide(color: AppColors.hairline),
          minimumSize: const Size(0, AppSizes.touchTarget),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.xl,
            vertical: AppSpacing.sm,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.textPrimary,
          textStyle: AppTextStyles.button,
          minimumSize: const Size(0, AppSizes.touchTarget),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.xs,
          ),
        ),
      ),
      dialogTheme: const DialogThemeData(
        backgroundColor: AppColors.elevated,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(AppRadius.dialog)),
        ),
        titleTextStyle: AppTextStyles.titleMedium,
        contentTextStyle: AppTextStyles.body,
      ),
      cardTheme: const CardThemeData(
        color: AppColors.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(AppRadius.card)),
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppRadius.sheet),
          ),
        ),
      ),
      sliderTheme: const SliderThemeData(
        trackHeight: 4,
        activeTrackColor: AppColors.accent,
        inactiveTrackColor: AppColors.pressed,
        thumbColor: AppColors.accent,
        thumbShape: RoundSliderThumbShape(enabledThumbRadius: 8),
        overlayColor: Color(0x33FFFFFF),
        overlayShape: RoundSliderOverlayShape(overlayRadius: 20),
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.hairline,
        thickness: 1,
        space: 1,
      ),
      snackBarTheme: const SnackBarThemeData(
        backgroundColor: AppColors.elevated,
        contentTextStyle: AppTextStyles.body,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(AppRadius.card)),
        ),
      ),
      chipTheme: const ChipThemeData(
        backgroundColor: AppColors.surface,
        labelStyle: AppTextStyles.bodySmall,
        shape: StadiumBorder(side: BorderSide(color: AppColors.hairline)),
        side: BorderSide(color: AppColors.hairline),
        padding: EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.xs,
        ),
      ),
      listTileTheme: const ListTileThemeData(
        contentPadding: EdgeInsets.symmetric(horizontal: AppSpacing.md),
        titleTextStyle: AppTextStyles.titleSmall,
        subtitleTextStyle: AppTextStyles.bodySmall,
        iconColor: AppColors.textSecondary,
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.accent,
      ),
    );
  }
}
