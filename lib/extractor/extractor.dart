/// Lapisan ekstraksi Laras: client InnerTube kustom di Dart.
///
/// Isi paket P1: parser player/search/browse, solver signature dan n challenge
/// di QuickJS, orkestrator fallback antar client, dan tabel config remote.
///
/// Aturan yang mengikat: modul ini terpisah dari UI supaya perbaikan ekstraksi
/// tidak menyentuh tampilan. Semua kode ditulis dari nol dari spesifikasi;
/// dilarang menyalin kode dari repo kompetitor. Tidak ada pemakaian API
/// Spotify dalam bentuk apa pun. Format SABR ditolak, tidak pernah dipilih.
library;

export 'canary.dart';
export 'cipher/player_script.dart';
export 'cipher/player_script_loader.dart';
export 'cipher/signature_solver.dart';
export 'client_definitions.dart';
export 'errors.dart';
export 'fallback_orchestrator.dart';
export 'innertube_client.dart';
export 'itag_picker.dart';
export 'models.dart';
export 'player_parser.dart';
export 'remote_config.dart';
export 'resolver.dart';
