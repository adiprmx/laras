/// Penandaan lagu yang tidak bisa diputar (B4.7, P6).
///
/// Antarmuka [UnplayableMarker] memisahkan pemutar dari database:
/// pemutar hanya tahu "tandai / bersihkan / cek", tanpa tahu drift.
///
/// Penjaga di [LibraryUnplayableMarker.mark]:
/// - tidak menandai saat status layanan broken (kerusakan massal bukan
///   salah lagu satu per satu);
/// - tidak pernah menandai lagu yang sudah terunduh (unduhan tetap bisa
///   diputar walau sumber online hilang).
library;

// ignore_for_file: prefer_initializing_formals - konstruktor publik memakai
// parameter bernama publik + field privat; initializing formal akan
// membuat nama parameter menjadi privat dan tidak bisa dipakai pemanggil.

import 'package:laras/data/library_service.dart';
import 'package:laras/resilience/service_status.dart';

/// Penanda status "tidak bisa diputar" per lagu.
abstract class UnplayableMarker {
  /// Apakah lagu [songId] sedang bertanda.
  Future<bool> isMarked(String songId);

  /// Tandai lagu sebagai tidak bisa diputar (bila penjaga mengizinkan).
  Future<void> mark(String songId);

  /// Bersihkan tanda lagu (dipanggil saat satu resolve berhasil).
  Future<void> clear(String songId);
}

/// Implementasi berbasis [LibraryService].
class LibraryUnplayableMarker implements UnplayableMarker {
  LibraryUnplayableMarker({
    required LibraryService library,
    ServiceStatusService? serviceStatus,
  }) : _library = library,
       _serviceStatus = serviceStatus;

  final LibraryService _library;
  final ServiceStatusService? _serviceStatus;

  @override
  Future<bool> isMarked(String songId) => _library.isUnplayable(songId);

  @override
  Future<void> mark(String songId) async {
    // Kerusakan massal: jangan tandai lagu satu per satu.
    if (_serviceStatus != null && _serviceStatus.isBroken) return;
    // Lagu terunduh tetap bisa diputar: jangan pernah ditandai.
    final bool downloaded = await _library.isDownloaded(songId);
    if (downloaded) return;
    await _library.markUnplayable(songId);
  }

  @override
  Future<void> clear(String songId) => _library.clearUnplayable(songId);
}
