/// Lapisan unduhan dan cache Laras (P5).
///
/// Isi paket P5: antrean unduhan serial dengan resume Range dan retry,
/// kualitas unduhan 3 opsi, cache streaming LRU 500 MB, layar
/// Penyimpanan, dan rekonsiliasi saat start. Janji inti owner:
/// lagu bisa diputar gratis dan offline.
///
/// Aturan yang mengikat: eviction cache TIDAK PERNAH menghapus unduhan
/// (direktori terpisah `downloads/` vs `stream-cache/` + tes K9);
/// URL stream hanya hidup di memori; file ditulis `.part` lalu di-rename
/// setelah ukuran cocok.
library;

export 'download_paths.dart';
export 'download_quality.dart';
export 'download_service.dart';
export 'download_url_resolver.dart';
export 'downloads_scope.dart';
export 'format_bytes.dart';
export 'free_space.dart';
export 'reconciler.dart';
export 'stream_cache.dart';
