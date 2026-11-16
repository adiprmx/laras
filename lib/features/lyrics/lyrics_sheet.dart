/// Lembar lirik (P7): lirik lagu yang sedang diputar, tersinkron bila
/// tersedia.
///
/// State yang ditangani: memuat (skeleton), tersinkron (baris aktif
/// putih + lebih besar, gulir otomatis), polos (teks gulir), tidak ada,
/// instrumental, offline, dan gagal (dengan tombol coba lagi). Kaki
/// lembar selalu menampilkan atribusi sumber + pemberitahuan privasi.
///
/// Gulir otomatis berhenti 5 detik sesudah pengguna menggulir sendiri,
/// supaya pengguna bisa membaca baris lain tanpa ditarik kembali.
/// Bila lagu berganti selagi lembar terbuka, lirik dimuat ulang untuk
/// lagu yang baru.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:laras/core/theme/app_colors.dart';
import 'package:laras/core/theme/app_theme.dart';
import 'package:laras/l10n/generated/app_localizations.dart';
import 'package:laras/player/audio_player_port.dart';
import 'package:laras/player/player_state.dart';
import 'package:laras/player/track.dart';

import 'lrc_parser.dart';
import 'lyrics_service.dart';

/// Lembar bawah lirik. Dibuka lewat [LyricsSheet.show].
class LyricsSheet extends StatefulWidget {
  const LyricsSheet({
    super.key,
    required this.track,
    required this.service,
    required this.port,
    required this.scrollController,
  });

  /// Buka lembar lirik sebagai bottom sheet yang bisa ditarik.
  static Future<void> show(
    BuildContext context, {
    required Track track,
    required LyricsService service,
    required AudioPlayerPort port,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.elevated,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppRadius.sheet),
        ),
      ),
      builder: (BuildContext sheetContext) {
        return DraggableScrollableSheet(
          initialChildSize: 0.75,
          minChildSize: 0.4,
          maxChildSize: 0.95,
          expand: false,
          builder: (BuildContext context, ScrollController controller) {
            return LyricsSheet(
              track: track,
              service: service,
              port: port,
              scrollController: controller,
            );
          },
        );
      },
    );
  }

  final Track track;
  final LyricsService service;
  final AudioPlayerPort port;
  final ScrollController scrollController;

  @override
  State<LyricsSheet> createState() => _LyricsSheetState();
}

class _LyricsSheetState extends State<LyricsSheet> {
  /// Jeda gulir otomatis sesudah pengguna menggulir sendiri.
  static const Duration _userScrollPause = Duration(seconds: 5);

  late Track _track;
  Future<LyricsResult>? _future;
  LyricsResult? _parsedResult;
  List<LyricLine> _lines = const <LyricLine>[];
  List<GlobalKey> _lineKeys = const <GlobalKey>[];
  int _activeIndex = -1;
  DateTime? _userScrolledAt;
  StreamSubscription<Duration>? _positionSub;
  StreamSubscription<PlayerSnapshot>? _stateSub;

  @override
  void initState() {
    super.initState();
    _track = widget.track;
    _startFetch(_track);
    // Lagu berganti selagi lembar terbuka: muat lirik lagu yang baru.
    _stateSub = widget.port.stateStream.listen((PlayerSnapshot snap) {
      final Track? current = snap.currentTrack;
      if (current != null && current.videoId != _track.videoId) {
        _startFetch(current);
      }
    });
  }

  void _startFetch(Track track) {
    _positionSub?.cancel();
    _positionSub = null;
    setState(() {
      _track = track;
      _parsedResult = null;
      _lines = const <LyricLine>[];
      _lineKeys = const <GlobalKey>[];
      _activeIndex = -1;
      _future = widget.service.fetch(track);
    });
  }

  /// Baris tersinkron untuk [result], di-parse sekali per hasil (bukan
  /// per rebuild). Penjadwalan langganan posisi dilakukan sesudah frame.
  List<LyricLine> _linesFor(LyricsResult result, String synced) {
    if (identical(_parsedResult, result)) return _lines;
    _parsedResult = result;
    final List<LyricLine> lines = parseLrc(synced);
    if (lines.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _lines.isEmpty) {
          setState(() => _onSyncedLoaded(lines));
        }
      });
    }
    return lines;
  }

  void _onSyncedLoaded(List<LyricLine> lines) {
    _lines = lines;
    _lineKeys = List<GlobalKey>.generate(
      lines.length,
      (_) => GlobalKey(),
      growable: false,
    );
    _positionSub?.cancel();
    _positionSub = widget.port.positionStream.listen(_onPosition);
    // Tanpa setState bersarang: pemanggil sudah berada di dalam setState.
    _activeIndex = lyricLineIndexAt(lines, widget.port.position);
    if (_activeIndex >= 0) _scrollToActive(animate: false);
  }

  void _onPosition(Duration position) {
    _updateActive(position, animate: true);
  }

  void _updateActive(Duration position, {required bool animate}) {
    if (_lines.isEmpty) return;
    final int index = lyricLineIndexAt(_lines, position);
    if (index == _activeIndex) return;
    setState(() => _activeIndex = index);
    if (index < 0) return;
    _scrollToActive(animate: animate);
  }

  /// Gulir ke baris aktif, kecuali pengguna baru saja menggulir sendiri.
  void _scrollToActive({required bool animate}) {
    final int index = _activeIndex;
    if (index < 0) return;
    final DateTime? scrolledAt = _userScrolledAt;
    if (scrolledAt != null &&
        DateTime.now().difference(scrolledAt) < _userScrollPause) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || index >= _lineKeys.length) return;
      final BuildContext? lineContext = _lineKeys[index].currentContext;
      if (lineContext == null) return;
      Scrollable.ensureVisible(
        lineContext,
        duration: animate
            ? const Duration(milliseconds: 300)
            : Duration.zero,
        alignment: 0.4,
      );
    });
  }

  @override
  void dispose() {
    _positionSub?.cancel();
    _stateSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations strings = AppLocalizations.of(context)!;
    final ThemeData theme = Theme.of(context);
    return NotificationListener<ScrollNotification>(
      onNotification: (ScrollNotification notification) {
        // Hanya guliran dari jari pengguna yang menjeda gulir otomatis;
        // guliran program (ensureVisible) tidak ikut tercatat.
        if (notification is ScrollUpdateNotification &&
            notification.dragDetails != null) {
          _userScrolledAt = DateTime.now();
        }
        return false;
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const SizedBox(height: AppSpacing.sm),
          Center(
            child: Container(
              width: 32,
              height: 4,
              decoration: const BoxDecoration(
                color: AppColors.pressed,
                borderRadius: BorderRadius.all(Radius.circular(2)),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              AppSpacing.sm,
              AppSpacing.sm,
              AppSpacing.xs,
            ),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        strings.lyrics,
                        style: theme.textTheme.titleMedium,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _track.title,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (_track.artist != null)
                        Text(
                          _track.artist!,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: AppColors.textMuted,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  tooltip: strings.close,
                  onPressed: () => Navigator.of(context).maybePop(),
                ),
              ],
            ),
          ),
          Expanded(
            child: FutureBuilder<LyricsResult>(
              future: _future,
              builder:
                  (
                    BuildContext context,
                    AsyncSnapshot<LyricsResult> shot,
                  ) {
                    if (shot.connectionState == ConnectionState.waiting ||
                        !shot.hasData) {
                      if (shot.hasError) {
                        return _errorBody(
                          context,
                          message: strings.lyricsFailed,
                        );
                      }
                      return _loadingBody(context);
                    }
                    final LyricsResult result = shot.data!;
                    switch (result.status) {
                      case LyricsStatus.found:
                        final String? synced = result.syncedLyrics;
                        if (synced != null && synced.isNotEmpty) {
                          final List<LyricLine> lines = _linesFor(
                            result,
                            synced,
                          );
                          if (lines.isNotEmpty) {
                            return _syncedBody(lines);
                          }
                        }
                        final String plain = result.plainLyrics ?? '';
                        if (plain.trim().isNotEmpty) {
                          return _plainBody(plain);
                        }
                        return _messageBody(
                          context,
                          icon: Icons.music_note_outlined,
                          message: strings.lyricsMissing,
                        );
                      case LyricsStatus.notFound:
                        return _messageBody(
                          context,
                          icon: Icons.music_note_outlined,
                          message: strings.lyricsMissing,
                        );
                      case LyricsStatus.instrumental:
                        return _messageBody(
                          context,
                          icon: Icons.music_note_outlined,
                          message: strings.lyricsInstrumental,
                        );
                      case LyricsStatus.offline:
                        return _errorBody(
                          context,
                          message: strings.lyricsNotSaved,
                          icon: Icons.cloud_off_outlined,
                        );
                      case LyricsStatus.error:
                        return _errorBody(
                          context,
                          message: strings.lyricsFailed,
                        );
                    }
                  },
            ),
          ),
          _footer(context),
        ],
      ),
    );
  }

  Widget _loadingBody(BuildContext context) {
    final AppLocalizations strings = AppLocalizations.of(context)!;
    final ThemeData theme = Theme.of(context);
    return SingleChildScrollView(
      controller: widget.scrollController,
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            strings.lyricsLoading,
            style: theme.textTheme.bodySmall?.copyWith(
              color: AppColors.textMuted,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          for (final double width in <double>[0.9, 0.7, 0.8, 0.6, 0.85])
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.md),
              child: FractionallySizedBox(
                widthFactor: width,
                child: Container(
                  height: 16,
                  decoration: const BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.all(Radius.circular(4)),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _syncedBody(List<LyricLine> lines) {
    final ThemeData theme = Theme.of(context);
    return ListView.builder(
      controller: widget.scrollController,
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.sm,
        AppSpacing.md,
        AppSpacing.xl,
      ),
      itemCount: lines.length,
      itemBuilder: (BuildContext context, int index) {
        final bool active = index == _activeIndex;
        return Padding(
          key: index < _lineKeys.length ? _lineKeys[index] : null,
          padding: const EdgeInsets.symmetric(vertical: 7),
          child: AnimatedDefaultTextStyle(
            duration: const Duration(milliseconds: 200),
            style:
                (active
                        ? theme.textTheme.titleMedium
                        : theme.textTheme.bodyLarge)!
                    .copyWith(
                      color: active
                          ? AppColors.textPrimary
                          : AppColors.textSecondary,
                      height: 1.5,
                    ),
            child: Text(lines[index].text),
          ),
        );
      },
    );
  }

  Widget _plainBody(String text) {
    final ThemeData theme = Theme.of(context);
    return SingleChildScrollView(
      controller: widget.scrollController,
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.sm,
        AppSpacing.md,
        AppSpacing.xl,
      ),
      child: Text(
        text,
        style: theme.textTheme.bodyLarge?.copyWith(height: 1.7),
      ),
    );
  }

  Widget _messageBody(
    BuildContext context, {
    required IconData icon,
    required String message,
  }) {
    final ThemeData theme = Theme.of(context);
    return SingleChildScrollView(
      controller: widget.scrollController,
      padding: const EdgeInsets.all(AppSpacing.md),
      child: SizedBox(
        height: 240,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Icon(icon, size: 40, color: AppColors.textMuted),
            const SizedBox(height: AppSpacing.sm),
            Text(
              message,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _errorBody(
    BuildContext context, {
    required String message,
    IconData icon = Icons.error_outline,
  }) {
    final AppLocalizations strings = AppLocalizations.of(context)!;
    final ThemeData theme = Theme.of(context);
    return SingleChildScrollView(
      controller: widget.scrollController,
      padding: const EdgeInsets.all(AppSpacing.md),
      child: SizedBox(
        height: 240,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Icon(icon, size: 40, color: AppColors.textMuted),
            const SizedBox(height: AppSpacing.sm),
            Text(
              message,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.md),
            FilledButton.icon(
              onPressed: () => _startFetch(_track),
              icon: const Icon(Icons.refresh),
              label: Text(strings.retry),
            ),
          ],
        ),
      ),
    );
  }

  Widget _footer(BuildContext context) {
    final AppLocalizations strings = AppLocalizations.of(context)!;
    final ThemeData theme = Theme.of(context);
    return Container(
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: AppColors.hairline)),
      ),
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(
            strings.lyricsSource,
            style: theme.textTheme.bodySmall?.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            strings.lyricsNotice,
            style: theme.textTheme.bodySmall?.copyWith(
              color: AppColors.textMuted,
            ),
          ),
        ],
      ),
    );
  }
}
