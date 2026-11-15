import 'package:flutter/material.dart';
import 'package:laras/core/theme/app_theme.dart';
import 'package:laras/core/widgets/empty_state.dart';
import 'package:laras/l10n/generated/app_localizations.dart';

/// Beranda. Di P0 hanya menampilkan judul dan empty state pengguna baru:
/// seksi lokal dan seksi Jelajah datang di P4.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key, required this.onSearchRequested});

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
            child: Text(strings.tabHome, style: theme.textTheme.displayLarge),
          ),
          Expanded(
            child: EmptyState(
              icon: Icons.music_note_outlined,
              title: strings.homeEmptyTitle,
              body: strings.homeEmptyBody,
              actionLabel: strings.searchSongs,
              onAction: onSearchRequested,
            ),
          ),
        ],
      ),
    );
  }
}
