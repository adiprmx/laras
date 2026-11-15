/// Tab Cari. Pencarian online datang di P4; mesin pencarian lokal (FTS5)
/// sudah dibangun di P3 dan diuji, tapi layarnya baru dipasang bersama
/// pencarian online supaya pengguna tidak menemui kolom cari yang hanya
/// mencari di library kosong. Sementara itu layar ini berkata jujur.
library;

import 'package:flutter/material.dart';
import 'package:laras/core/theme/app_theme.dart';
import 'package:laras/core/widgets/coming_soon_screen.dart';
import 'package:laras/l10n/generated/app_localizations.dart';

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
            child: ComingSoonScreen(
              icon: Icons.search_outlined,
              title: strings.comingSoon,
              body: strings.searchComingSoonBody,
            ),
          ),
        ],
      ),
    );
  }
}
