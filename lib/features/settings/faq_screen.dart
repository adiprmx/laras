/// Layar FAQ (B11.3, P6).
///
/// 18 pertanyaan + jawaban dari ARB (P8 menambah 6 tentang
/// backup/impor/pindah HP/Spotify). [initialIndex] membuka satu
/// pertanyaan langsung (dipakai tautan lembar kejujuran).
library;

import 'package:flutter/material.dart';

import 'package:laras/core/theme/app_colors.dart';
import 'package:laras/core/theme/app_theme.dart';
import 'package:laras/l10n/generated/app_localizations.dart';

import 'report_problem.dart';

class FaqScreen extends StatefulWidget {
  const FaqScreen({super.key, this.initialIndex});

  /// Indeks pertanyaan yang dibuka langsung (0-17), atau null.
  final int? initialIndex;

  @override
  State<FaqScreen> createState() => _FaqScreenState();
}

class _FaqScreenState extends State<FaqScreen> {
  int? _expanded;
  final Map<int, GlobalKey> _keys = <int, GlobalKey>{};

  @override
  void initState() {
    super.initState();
    _expanded = widget.initialIndex;
    if (_expanded != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final GlobalKey? key = _keys[_expanded];
        final BuildContext? target = key?.currentContext;
        if (target != null) {
          Scrollable.ensureVisible(
            target,
            duration: const Duration(milliseconds: 300),
          );
        }
      });
    }
  }

  List<(String, String)> _items(AppLocalizations strings) => <(String, String)>[
    (strings.faq1q, strings.faq1a),
    (strings.faq2q, strings.faq2a),
    (strings.faq3q, strings.faq3a),
    (strings.faq4q, strings.faq4a),
    (strings.faq5q, strings.faq5a),
    (strings.faq6q, strings.faq6a),
    (strings.faq7q, strings.faq7a),
    (strings.faq8q, strings.faq8a),
    (strings.faq9q, strings.faq9a),
    (strings.faq10q, strings.faq10a),
    (strings.faq11q, strings.faq11a),
    (strings.faq12q, strings.faq12a),
    (strings.faq13q, strings.faq13a),
    (strings.faq14q, strings.faq14a),
    (strings.faq15q, strings.faq15a),
    (strings.faq16q, strings.faq16a),
    (strings.faq17q, strings.faq17a),
    (strings.faq18q, strings.faq18a),
  ];

  @override
  Widget build(BuildContext context) {
    final AppLocalizations strings = AppLocalizations.of(context)!;
    final ThemeData theme = Theme.of(context);
    final List<(String, String)> items = _items(strings);
    return Scaffold(
      appBar: AppBar(title: Text(strings.faqTitle)),
      body: ListView.builder(
        padding: const EdgeInsets.only(bottom: AppSpacing.lg),
        itemCount: items.length + 1,
        itemBuilder: (BuildContext context, int index) {
          if (index == items.length) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                AppSpacing.lg,
                AppSpacing.md,
                0,
              ),
              child: TextButton(
                onPressed: () => openReportProblem(context),
                child: Text(strings.reportProblem),
              ),
            );
          }
          final (String, String) item = items[index];
          final GlobalKey key = _keys.putIfAbsent(index, GlobalKey.new);
          return ExpansionTile(
            key: key,
            initiallyExpanded: _expanded == index,
            onExpansionChanged: (bool expanded) {
              setState(() {
                _expanded = expanded ? index : null;
              });
            },
            title: Text(item.$1, style: theme.textTheme.bodyLarge),
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.md,
                  0,
                  AppSpacing.md,
                  AppSpacing.md,
                ),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    item.$2,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
