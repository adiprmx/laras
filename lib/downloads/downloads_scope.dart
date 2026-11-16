/// Scope layanan unduhan + cache: dibagikan ke seluruh widget lewat
/// InheritedWidget (pola yang sama dengan LibraryScope dan PlayerScope).
///
/// Kedua layanan null bila database gagal dibuka (app tetap jalan tanpa
/// unduhan; tombol unduh disembunyikan, tab Unduhan menampilkan pesan
/// jujur).
library;

import 'package:flutter/widgets.dart';

import 'download_service.dart';
import 'stream_cache.dart';

class DownloadsScope extends InheritedWidget {
  const DownloadsScope({
    super.key,
    required this.downloads,
    required this.cache,
    required super.child,
  });

  /// Layanan unduhan, atau null bila database gagal dibuka.
  final DownloadService? downloads;

  /// Layanan cache streaming, atau null bila database gagal dibuka.
  final StreamCacheService? cache;

  static DownloadsScope? maybeOf(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<DownloadsScope>();
  }

  /// Layanan unduhan dari scope terdekat, atau null.
  static DownloadService? downloadsOf(BuildContext context) {
    return maybeOf(context)?.downloads;
  }

  /// Direktori unduhan (untuk membangun localPath Track), atau null
  /// bila layanan unduhan tidak tersedia.
  static String? downloadsDirOf(BuildContext context) {
    return maybeOf(context)?.downloads?.downloadsDir;
  }

  @override
  bool updateShouldNotify(DownloadsScope oldWidget) {
    return downloads != oldWidget.downloads || cache != oldWidget.cache;
  }
}
