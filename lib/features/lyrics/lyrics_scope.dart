/// Akses [LyricsService] dari widget tree (P7).
///
/// [LyricsScope.maybeOf] mengembalikan null bila tidak ada scope (mis.
/// widget test yang memompa widget tanpa service): pemanggil wajib
/// menangani null dengan menyembunyikan tombol lirik, bukan crash.
library;

import 'package:flutter/widgets.dart';

import 'lyrics_service.dart';

class LyricsScope extends InheritedWidget {
  const LyricsScope({super.key, required this.service, required super.child});

  final LyricsService? service;

  static LyricsService? maybeOf(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<LyricsScope>()?.service;
  }

  @override
  bool updateShouldNotify(LyricsScope oldWidget) =>
      service != oldWidget.service;
}
