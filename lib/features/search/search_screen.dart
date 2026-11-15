import 'package:flutter/material.dart';
import 'package:laras/core/theme/app_theme.dart';
import 'package:laras/core/widgets/empty_state.dart';
import 'package:laras/l10n/generated/app_localizations.dart';

/// Tab Cari. Pencarian belum dibangun di P0, jadi layar ini berkata jujur
/// soal itu daripada menampilkan kolom cari palsu. Pencarian datang di P4.
class SearchScreen extends StatelessWidget {
  const SearchScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final AppLocalizations strings = AppLocalizations.of(context)!;
    final ThemeData theme = Theme.of(context);
    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              AppSpacing.md,
              AppSpacing.md,
              0,
            ),
            child: Text(strings.tabSearch, style: theme.textTheme.displayLarge),
          ),
          Expanded(
            child: EmptyState(
              icon: Icons.search_outlined,
              title: strings.tabSearch,
              body: strings.searchComingSoon,
            ),
          ),
        ],
      ),
    );
  }
}
