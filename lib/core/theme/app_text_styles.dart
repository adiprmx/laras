import 'package:flutter/material.dart';

/// Skala tipografi Laras, dari spesifikasi desain A12.
///
/// Font: font sistem Android (tanpa biaya APK). Lantai 12 sp untuk semua teks
/// yang menghadap pengguna; token micro 11 sp dari A12 dinaikkan ke 12 sp
/// sesuai PRD. Angka yang berubah-ubah (timer, durasi, jumlah) memakai
/// [captionTabular] supaya lebarnya sejajar vertikal.
abstract final class AppTextStyles {
  /// Judul layar utama (Beranda, Library, Unduhan).
  static const TextStyle display = TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.w700,
    height: 32 / 24,
  );

  /// Judul lagu di Now Playing.
  static const TextStyle titleLarge = TextStyle(
    fontSize: 22,
    fontWeight: FontWeight.w700,
    height: 28 / 22,
  );

  /// Judul bagian di dalam layar, judul playlist.
  static const TextStyle titleMedium = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w600,
    height: 24 / 18,
  );

  /// Judul lagu di baris daftar, judul kartu.
  static const TextStyle titleSmall = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    height: 22 / 16,
  );

  /// Teks utama di dialog dan penjelasan singkat.
  static const TextStyle body = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w400,
    height: 22 / 15,
  );

  /// Nama artis di baris daftar, teks tombol sekunder.
  static const TextStyle bodySmall = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    height: 20 / 14,
  );

  /// Durasi, jumlah lagu, metadata kecil.
  static const TextStyle caption = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w400,
    height: 16 / 12,
  );

  /// Label kecil yang bukan teks utama: angka di badge, keterangan di bawah
  /// ikon. Lantai 12 sp berlaku di sini, sama seperti teks lainnya.
  static const TextStyle micro = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w600,
    height: 16 / 12,
  );

  /// Angka yang berubah-ubah: timer pemutaran, durasi, jumlah lagu, ukuran
  /// file. Tabular supaya angkanya tidak bergeser saat nilainya berubah.
  static const TextStyle captionTabular = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w400,
    height: 16 / 12,
    fontFeatures: <FontFeature>[FontFeature.tabularFigures()],
  );

  /// Label tombol utama dan sekunder. Label tombol tidak pernah di bawah 14 sp.
  static const TextStyle button = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w600,
    height: 20 / 14,
  );
}
