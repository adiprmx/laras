/// Tab Unduhan. Antrean unduhan, progress, dan ringkasan penyimpanan
/// datang di P5. Sementara itu layar ini berkata jujur, tanpa tombol
/// yang pura-pura bisa dipakai.
library;

import 'package:flutter/material.dart';
import 'package:laras/core/theme/app_theme.dart';
import 'package:laras/core/widgets/coming_soon_screen.dart';
import 'package:laras/l10n/generated/app_localizations.dart';

class DownloadsScreen extends StatelessWidget {
  const DownloadsScreen({super.key});

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
            child: Text(
              strings.tabDownloads,
              style: theme.textTheme.displayLarge,
            ),
          ),
          Expanded(
            child: ComingSoonScreen(
              icon: Icons.download_outlined,
              title: strings.comingSoon,
              body: strings.downloadsComingSoonBody,
            ),
          ),
        ],
      ),
    );
  }
}
