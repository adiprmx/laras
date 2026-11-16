/// Layar impor playlist Spotify (P8, PRD B10.1).
///
/// Tiga jalan masuk daftar lagu, semuanya tanpa API Spotify:
/// - Tempel daftar lagu (teks "Artis - Judul" per baris).
/// - Pilih file daftar lagu (teks / CSV / JSON ekspor data Spotify).
/// - Tempel tautan playlist publik (jalur A — dengan peringatan risiko
///   dan batas 30 lagu pertama).
///
/// Sesudah daftar terbaca, pengguna bisa mengubah nama playlist lalu
/// menekan "Mulai mencocokkan": tiap lagu dicari ke YouTube Music satu
/// per satu dengan progres yang terlihat dan tombol batal. Lagu yang
/// sudah cocok tetap tersimpan bila dibatalkan. Hasil akhirnya adalah
/// laporan [showImportReportSheet].
library;

import 'package:flutter/material.dart';

import 'package:laras/core/theme/app_colors.dart';
import 'package:laras/core/theme/app_theme.dart';
import 'package:laras/l10n/generated/app_localizations.dart';

import 'backup_file_channel.dart';
import 'import_report.dart';
import 'import_report_sheet.dart';
import 'spotify_import.dart';

class SpotifyImportScreen extends StatefulWidget {
  const SpotifyImportScreen({
    super.key,
    required this.spotify,
    required this.files,
  });

  final SpotifyImportService spotify;
  final BackupFileChannel files;

  @override
  State<SpotifyImportScreen> createState() => _SpotifyImportScreenState();
}

class _SpotifyImportScreenState extends State<SpotifyImportScreen> {
  final TextEditingController _pasteController = TextEditingController();
  final TextEditingController _linkController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();

  SpotifyPlaylistDraft? _draft;
  bool _busy = false;
  bool _matching = false;
  bool _cancelRequested = false;
  int _matched = 0;
  int _matchTotal = 0;

  @override
  void dispose() {
    _pasteController.dispose();
    _linkController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  void _useDraft(SpotifyPlaylistDraft draft) {
    final AppLocalizations strings = AppLocalizations.of(context)!;
    setState(() {
      _draft = draft;
      _nameController.text =
          draft.name ?? strings.spotifyDefaultPlaylistName;
    });
  }

  void _usePastedText() {
    final String text = _pasteController.text.trim();
    if (text.isEmpty || _busy || _matching) return;
    try {
      final List<SpotifyTrackRef> tracks =
          SpotifyImportService.parseSpotifyText(text);
      _useDraft(SpotifyPlaylistDraft(tracks: tracks));
    } on SpotifyFileException {
      _showSnack(AppLocalizations.of(context)!.spotifyFileEmpty);
    }
  }

  Future<void> _pickFile() async {
    if (_busy || _matching) return;
    setState(() => _busy = true);
    try {
      final PickedFile? picked = await widget.files.pickFile();
      if (picked == null || !mounted) return;
      final SpotifyPlaylistDraft draft = widget.spotify.parseFile(
        picked.bytes,
        fileName: picked.name,
      );
      _useDraft(draft);
    } on SpotifyFileException {
      _showSnack(AppLocalizations.of(context)!.spotifyFileEmpty);
    } on BackupFileException {
      _showSnack(AppLocalizations.of(context)!.backupPickFailed);
    } on Object {
      _showSnack(AppLocalizations.of(context)!.backupPickFailed);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _fetchLink() async {
    if (_busy || _matching) return;
    final String url = _linkController.text.trim();
    if (url.isEmpty) return;
    setState(() => _busy = true);
    try {
      final SpotifyPlaylistDraft draft = await widget.spotify.fetchFromLink(
        url,
      );
      if (!mounted) return;
      _useDraft(draft);
    } on SpotifyLinkException catch (e) {
      if (!mounted) return;
      final AppLocalizations strings = AppLocalizations.of(context)!;
      switch (e.kind) {
        case SpotifyLinkErrorKind.invalidUrl:
          _showSnack(strings.spotifyLinkInvalid);
        case SpotifyLinkErrorKind.unreadable:
          _showSnack(strings.spotifyLinkUnreadable);
        case SpotifyLinkErrorKind.empty:
          _showSnack(strings.spotifyLinkEmpty);
      }
    } on Object {
      if (!mounted) return;
      _showSnack(AppLocalizations.of(context)!.spotifyLinkUnreadable);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _startMatching() async {
    final SpotifyPlaylistDraft? draft = _draft;
    if (draft == null || _matching) return;
    final String name = _nameController.text.trim();
    if (name.isEmpty) return;
    setState(() {
      _matching = true;
      _cancelRequested = false;
      _matched = 0;
      _matchTotal = draft.tracks.length;
    });
    final ImportReport report;
    try {
      report = await widget.spotify.importDraft(
        draft,
        playlistName: name,
        onProgress: (int done, int total) {
          if (mounted) {
            setState(() {
              _matched = done;
              _matchTotal = total;
            });
          }
        },
        isCancelled: () => _cancelRequested,
      );
    } on Object {
      if (!mounted) return;
      setState(() => _matching = false);
      _showSnack(AppLocalizations.of(context)!.spotifyMatchingFailed);
      return;
    }
    if (!mounted) return;
    setState(() {
      _matching = false;
      _draft = null;
      _pasteController.clear();
      _linkController.clear();
    });
    await showImportReportSheet(context, report);
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations strings = AppLocalizations.of(context)!;
    final ThemeData theme = Theme.of(context);
    final SpotifyPlaylistDraft? draft = _draft;
    final bool busy = _busy || _matching;
    return Scaffold(
      appBar: AppBar(title: Text(strings.spotifyTitle)),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: <Widget>[
          Text(
            strings.spotifyIntro,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            strings.spotifyPasteTitle,
            style: theme.textTheme.titleSmall?.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          TextField(
            controller: _pasteController,
            enabled: !busy,
            maxLines: 5,
            minLines: 3,
            decoration: InputDecoration(
              hintText: strings.spotifyPasteHint,
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          FilledButton.tonal(
            onPressed: busy ? null : _usePastedText,
            child: Text(strings.spotifyPasteUse),
          ),
          const SizedBox(height: AppSpacing.md),
          FilledButton.tonalIcon(
            onPressed: busy ? null : _pickFile,
            icon: _busy
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.file_open_outlined),
            label: Text(strings.spotifyFromFile),
          ),
          const SizedBox(height: AppSpacing.lg),
          const Divider(),
          const SizedBox(height: AppSpacing.sm),
          TextField(
            controller: _linkController,
            enabled: !busy,
            keyboardType: TextInputType.url,
            decoration: InputDecoration(
              hintText: strings.spotifyLinkHint,
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Container(
            padding: const EdgeInsets.all(AppSpacing.sm),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              strings.spotifyLinkWarning,
              style: theme.textTheme.bodySmall?.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          FilledButton.tonalIcon(
            onPressed: busy ? null : _fetchLink,
            icon: const Icon(Icons.link_outlined),
            label: Text(strings.spotifyFromLink),
          ),
          if (draft != null) ...<Widget>[
            const SizedBox(height: AppSpacing.lg),
            const Divider(),
            const SizedBox(height: AppSpacing.sm),
            TextField(
              controller: _nameController,
              enabled: !busy,
              decoration: InputDecoration(
                labelText: strings.spotifyPlaylistName,
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              strings.spotifyTrackCount(draft.tracks.length),
              style: theme.textTheme.bodyLarge,
            ),
            if (draft.truncated)
              Padding(
                padding: const EdgeInsets.only(top: AppSpacing.xs),
                child: Text(
                  strings.spotifyTruncatedNote,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppColors.warning,
                  ),
                ),
              ),
            const SizedBox(height: AppSpacing.xs),
            for (final SpotifyTrackRef track in draft.tracks.take(5))
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Text(
                  track.label,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            if (draft.tracks.length > 5)
              Text(
                '…',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            const SizedBox(height: AppSpacing.md),
            if (_matching) ...<Widget>[
              LinearProgressIndicator(
                value: _matchTotal == 0
                    ? null
                    : _matched / _matchTotal,
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                strings.spotifyMatching(_matched, _matchTotal),
                style: theme.textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.sm),
              TextButton(
                onPressed: () {
                  setState(() => _cancelRequested = true);
                },
                child: Text(strings.spotifyCancel),
              ),
            ] else
              FilledButton(
                onPressed: _startMatching,
                child: Text(strings.spotifyStartMatching),
              ),
          ],
        ],
      ),
    );
  }
}
