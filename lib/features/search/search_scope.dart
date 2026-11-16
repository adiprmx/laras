/// Akses [SearchService] dari widget tree.
///
/// [SearchScope.maybeOf] mengembalikan null bila tidak ada scope (mis.
/// widget test yang memompa widget tanpa service): pemanggil wajib
/// menangani null dengan menyembunyikan bagian online, bukan crash.
library;

import 'package:flutter/widgets.dart';

import 'search_service.dart';

class SearchScope extends InheritedWidget {
  const SearchScope({super.key, required this.service, required super.child});

  final SearchService? service;

  static SearchService? maybeOf(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<SearchScope>()?.service;
  }

  @override
  bool updateShouldNotify(SearchScope oldWidget) =>
      service != oldWidget.service;
}
