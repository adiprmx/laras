/// Akses layanan salinan data dari widget tree (P8).
///
/// [BackupScope.maybeOf] mengembalikan null bila tidak ada scope (mis.
/// widget test yang memompa widget tanpa service): pemanggil wajib
/// menangani null dengan menyembunyikan fitur terkait, bukan crash.
library;

import 'package:flutter/widgets.dart';

import 'backup_service.dart';
import 'spotify_import.dart';

class BackupScope extends InheritedWidget {
  const BackupScope({
    super.key,
    required super.child,
    this.backup,
    this.spotify,
  });

  final BackupService? backup;
  final SpotifyImportService? spotify;

  static BackupScope? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<BackupScope>();

  static BackupService? backupOf(BuildContext context) =>
      maybeOf(context)?.backup;

  static SpotifyImportService? spotifyOf(BuildContext context) =>
      maybeOf(context)?.spotify;

  @override
  bool updateShouldNotify(BackupScope oldWidget) =>
      backup != oldWidget.backup || spotify != oldWidget.spotify;
}
