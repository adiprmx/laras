import 'package:flutter/material.dart';

/// Token warna Laras, disalin apa adanya dari spesifikasi desain A12.
///
/// Basis monokrom: hitam murni, abu, putih. Warna hanya untuk status.
/// Abu `#71717A` sengaja tidak ada di sini: kontrasnya terhadap canvas hanya
/// 4,35:1, di bawah ambang AA 4,5:1 untuk teks. Satu-satunya pemakaian yang
/// diizinkan untuk abu itu adalah elemen non-teks (misal segmen buffer slider),
/// dan pemakaian itu dicatat di tempatnya dipakai, bukan sebagai token teks.
abstract final class AppColors {
  /// Latar utama semua layar.
  static const Color canvas = Color(0xFF000000);

  /// Kartu, baris yang ditonjolkan, sheet bawah.
  static const Color surface = Color(0xFF121214);

  /// Dialog, menu, mini-player.
  static const Color elevated = Color(0xFF1C1C1E);

  /// Keadaan ditekan pada baris dan tombol hantu.
  static const Color pressed = Color(0xFF2C2C2E);

  /// Garis pemisah antar baris dan antar bagian.
  static const Color hairline = Color(0xFF262628);

  /// Judul lagu, judul layar, teks utama. Kontras 21,0:1 terhadap canvas.
  static const Color textPrimary = Color(0xFFFFFFFF);

  /// Nama artis, metadata, teks pendukung. Kontras 8,19:1 terhadap canvas.
  static const Color textSecondary = Color(0xFFA1A1AA);

  /// Durasi, jumlah lagu, keterangan kecil. Kontras 6,44:1 terhadap canvas.
  static const Color textMuted = Color(0xFF8E8E93);

  /// Tombol utama, ikon aktif di tab bawah, slider yang sedang jalan.
  static const Color accent = Color(0xFFFFFFFF);

  /// Teks di atas tombol utama putih. Tidak dipakai di tempat lain.
  static const Color textOnAccent = Color(0xFF000000);

  /// Unduhan selesai, lagu tersimpan, layanan normal.
  static const Color success = Color(0xFF34D399);

  /// Layanan terganggu, antrean unduhan menunggu koneksi.
  static const Color warning = Color(0xFFFBBF24);

  /// Gagal putar, gagal unduh, layanan rusak.
  static const Color error = Color(0xFFF87171);

  /// Info penting, tautan ke penjelasan.
  static const Color info = Color(0xFF60A5FA);

  /// Lapisan gelap di balik dialog dan sheet: hitam 60%.
  static const Color scrim = Color(0x99000000);
}
