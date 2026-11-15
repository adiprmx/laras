/// Akses [PlayerService] dari widget tree.
///
/// [PlayerScope.maybeOf] mengembalikan null bila tidak ada scope (mis.
/// widget test yang memompa widget tanpa service): pemanggil wajib
/// menangani null dengan tidak menampilkan pemutar, bukan crash.
library;

import 'package:flutter/widgets.dart';

import 'player_service.dart';

class PlayerScope extends InheritedWidget {
  const PlayerScope({super.key, required this.service, required super.child});

  final PlayerService service;

  static PlayerService? maybeOf(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<PlayerScope>()
        ?.service;
  }

  @override
  bool updateShouldNotify(PlayerScope oldWidget) =>
      service != oldWidget.service;
}
