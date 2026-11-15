/// Daftar berpaginasi keyset untuk tab Library.
///
/// Memuat halaman pertama saat dibangun, menambah halaman berikut lewat
/// tombol "Muat lagi" di ujung daftar (bukan infinite scroll: eksplisit,
/// terprediksi, dan mudah diuji). Memuat ulang halaman pertama saat
/// [reloadStream] memberi sinyal (perubahan database dari tempat lain,
/// mis. favorit ditandai dari layar Player).
///
/// [T] adalah tipe item halaman; [loadPage] menerima item terakhir
/// halaman sebelumnya (null untuk halaman pertama) dan mengembalikan
/// halaman berikut.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:laras/core/theme/app_theme.dart';
import 'package:laras/core/widgets/empty_state.dart';
import 'package:laras/core/widgets/loading_rows.dart';
import 'package:laras/data/database.dart';
import 'package:laras/l10n/generated/app_localizations.dart';

class PagedList<T> extends StatefulWidget {
  const PagedList({
    super.key,
    required this.loadPage,
    required this.itemBuilder,
    required this.emptyIcon,
    required this.emptyTitle,
    required this.emptyBody,
    this.header,
    this.reloadStream,
  });

  final Future<List<T>> Function(T? after) loadPage;

  /// Membangun satu baris. [items] adalah seluruh item yang sudah
  /// dimuat (untuk antrean putar), [index] posisi item di dalamnya.
  final Widget Function(BuildContext context, T item, int index, List<T> items)
  itemBuilder;

  final IconData emptyIcon;
  final String emptyTitle;
  final String emptyBody;

  /// Widget di atas daftar (mis. kontrol sortir atau tombol aksi).
  final Widget? header;

  /// Stream yang memicu muat ulang halaman pertama saat ada event.
  final Stream<void>? reloadStream;

  @override
  State<PagedList<T>> createState() => _PagedListState<T>();
}

class _PagedListState<T> extends State<PagedList<T>> {
  List<T> _items = <T>[];
  bool _loading = true;
  bool _loadingMore = false;
  bool _hasMore = false;
  StreamSubscription<void>? _reloadSub;

  @override
  void initState() {
    super.initState();
    _loadFirstPage();
    _reloadSub = widget.reloadStream?.listen((_) {
      if (!mounted) return;
      _loadFirstPage();
    });
  }

  @override
  void dispose() {
    _reloadSub?.cancel();
    super.dispose();
  }

  Future<void> _loadFirstPage() async {
    setState(() {
      _loading = true;
    });
    final List<T> page = await widget.loadPage(null);
    if (!mounted) return;
    setState(() {
      _items = page;
      _hasMore = page.length >= kPageSize;
      _loading = false;
    });
  }

  Future<void> _loadMore() async {
    if (_loadingMore || _items.isEmpty) return;
    setState(() {
      _loadingMore = true;
    });
    final List<T> page = await widget.loadPage(_items.last);
    if (!mounted) return;
    setState(() {
      _items = <T>[..._items, ...page];
      _hasMore = page.length >= kPageSize;
      _loadingMore = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations strings = AppLocalizations.of(context)!;
    final Widget? header = widget.header;
    if (_loading) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          if (header case final Widget h) h,
          const LoadingRows(),
        ],
      );
    }
    if (_items.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          if (header case final Widget h) h,
          Expanded(
            child: EmptyState(
              icon: widget.emptyIcon,
              title: widget.emptyTitle,
              body: widget.emptyBody,
            ),
          ),
        ],
      );
    }
    return Column(
      children: <Widget>[
        if (header case final Widget h) h,
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
            ),
            itemCount: _items.length + (_hasMore ? 1 : 0),
            itemBuilder: (BuildContext context, int index) {
              if (index >= _items.length) {
                return Padding(
                  padding: const EdgeInsets.symmetric(
                    vertical: AppSpacing.md,
                  ),
                  child: Center(
                    child: _loadingMore
                        ? Text(
                            strings.loadingMore,
                            style: Theme.of(
                              context,
                            ).textTheme.bodySmall,
                          )
                        : TextButton(
                            onPressed: _loadMore,
                            child: Text(strings.loadMore),
                          ),
                  ),
                );
              }
              final T item = _items[index];
              return widget.itemBuilder(context, item, index, _items);
            },
          ),
        ),
      ],
    );
  }
}
