/// Pemilih format audio dari daftar `adaptiveFormats` respons player.
///
/// Urutan kanonis (arsitektur 3.2, PRD 5.8): 251, 140, 250, 249, 139.
/// Urutan hemat data (saklar "Hemat data"): 249, 139, 250, 140, 251; naik
/// bila perlu supaya lagu tetap bisa diputar.
///
/// Aturan yang mengikat: format SABR tidak pernah dipilih. Format tanpa
/// URL langsung dan tanpa signatureCipher yang lengkap juga tidak dipilih.
/// Fungsi ini murni (tanpa I/O) supaya mudah dites.
library;

import 'models.dart';

/// Urutan kualitas terbaik: Opus 251 dulu, lalu AAC 140.
const List<int> kBestQualityItagOrder = <int>[251, 140, 250, 249, 139];

/// Urutan hemat data: Opus/AAC bitrate terendah dulu.
const List<int> kDataSaverItagOrder = <int>[249, 139, 250, 140, 251];

/// Pilih satu format audio terbaik dari daftar, atau null bila tidak ada
/// format yang bisa dipakai.
///
/// [dataSaver] memakai urutan hemat data. Format SABR selalu dilewati,
/// apa pun urutannya.
AudioFormat? pickAudioFormat(
  List<AudioFormat> formats, {
  bool dataSaver = false,
}) {
  final List<int> order = dataSaver ? kDataSaverItagOrder : kBestQualityItagOrder;
  final List<AudioFormat> usable = formats
      .where((f) => !f.isSabr && (f.hasDirectUrl || f.needsSolver))
      .toList(growable: false);
  if (usable.isEmpty) return null;
  for (final int itag in order) {
    for (final AudioFormat format in usable) {
      if (format.itag == itag) return format;
    }
  }
  // Itag di luar daftar yang dikenal: pakai bitrate tertinggi sebagai
  // jalan terakhir, supaya format audio baru dari YouTube tetap bisa jalan.
  usable.sort((a, b) => b.bitrate.compareTo(a.bitrate));
  return usable.first;
}
