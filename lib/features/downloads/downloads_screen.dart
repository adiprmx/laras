import 'package:flutter/material.dart';
import 'package:laras/core/theme/app_theme.dart';
import 'package:laras/core/widgets/empty_state.dart';
import 'package:laras/l10n/generated/app_localizations.dart';

/// Tab Unduhan. Di P0 hanya menampilkan judul dan empty state. Antrean
/// unduhan, progress, dan ringkasan penyimpanan datang di P5.
class DownloadsScreen extends StatelessWidget {
  const DownloadsScreen({super.key, required this.onSearchRequested});

  final VoidCallback onSearchRequested;

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
            child: EmptyState(
              icon: Icons.download_outlined,
              title: strings.downloadsEmptyTitle,
              body: strings.downloadsEmptyBody,
              actionLabel: strings.searchSongs,
              onAction: onSearchRequested,
            ),
          ),
        ],
      ),
    );
  }
}
