/// Interface resolve audio: satu lagu menjadi URL siap putar.
///
/// Lapisan player memakai interface ini, bukan [StreamResolver] konkret,
/// supaya player bisa dites dengan resolver palsu tanpa jaringan.
/// Implementasi nyata adalah [StreamResolver] (fallback_orchestrator.dart).
library;

import 'models.dart';

abstract class AudioResolver {
  /// Resolve satu lagu menjadi URL audio siap putar.
  ///
  /// Melempar [ExtractorException] bila semua client gagal. URL hasil
  /// hanya hidup di memori dan kedaluwarsa; pemutar memakainya segera.
  Future<ResolvedAudio> resolve(String videoId, {bool dataSaver = false});

  /// Log resolve terakhir (maks 50 baris, tanpa URL).
  List<ResolveLogEntry> get recentLog;
}
