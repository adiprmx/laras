/// Akses [LibraryService] dari widget tree.
///
/// [LibraryScope.maybeOf] mengembalikan null bila tidak ada scope (mis.
/// widget test yang memompa widget tanpa service, atau database gagal
/// dibuka saat start): pemanggil wajib menangani null dengan menampilkan
/// empty state yang jujur, bukan crash. Bedakan kedua kasus itu lewat
/// [LibraryScope.failedOf]: benar hanya bila database gagal dibuka.
library;

import 'package:flutter/widgets.dart';

import 'library_service.dart';

class LibraryScope extends InheritedWidget {
  const LibraryScope({
    super.key,
    required this.service,
    this.failed = false,
    required super.child,
  });

  final LibraryService? service;

  /// Benar bila database gagal dibuka saat start (service null karena
  /// error, bukan karena tidak dipasang).
  final bool failed;

  static LibraryService? maybeOf(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<LibraryScope>()
        ?.service;
  }

  static bool failedOf(BuildContext context) {
    return context
            .dependOnInheritedWidgetOfExactType<LibraryScope>()
            ?.failed ??
        false;
  }

  @override
  bool updateShouldNotify(LibraryScope oldWidget) =>
      service != oldWidget.service || failed != oldWidget.failed;
}
