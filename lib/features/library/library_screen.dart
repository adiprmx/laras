import 'package:flutter/material.dart';
import 'package:laras/core/theme/app_theme.dart';
import 'package:laras/core/widgets/empty_state.dart';
import 'package:laras/l10n/generated/app_localizations.dart';

/// Library. Di P0 hanya menampilkan judul, ikon gerigi Pengaturan, dan
/// empty state. Daftar lagu, album, artis, dan playlist datang di P3.
/// Pengaturan dibuka lewat ikon gerigi di header ini, satu-satunya pintu
/// masuk Pengaturan.
class LibraryScreen extends StatelessWidget {
  const LibraryScreen({
    super.key,
    required this.onSearchRequested,
    required this.onSettingsRequested,
  });

  final VoidCallback onSearchRequested;
  final VoidCallback onSettingsRequested;

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
              AppSpacing.xs,
              0,
            ),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    strings.tabLibrary,
                    style: theme.textTheme.displayLarge,
                  ),
                ),
                IconButton(
                  onPressed: onSettingsRequested,
                  tooltip: strings.settings,
                  icon: const Icon(Icons.settings_outlined),
                ),
              ],
            ),
          ),
          Expanded(
            child: EmptyState(
              icon: Icons.library_music_outlined,
              title: strings.libraryEmptyTitle,
              body: strings.libraryEmptyBody,
              actionLabel: strings.searchSongs,
              onAction: onSearchRequested,
            ),
          ),
        ],
      ),
    );
  }
}
