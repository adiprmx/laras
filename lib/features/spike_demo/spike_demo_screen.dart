/// Layar demo spike SEMENTARA - hapus sebelum v1.0.0.
///
/// Bukti ujung-ke-ujung untuk owner: daftar 5 lagu kanari, ketuk lagu
/// -> resolve lewat [StreamResolver] -> putar via just_audio langsung.
/// Menampilkan status tiap lagu (menyiapkan / diputar / gagal) dan catatan
/// percobaan resolve (client yang dipakai + waktu, tanpa URL).
///
/// File ini + rute dari Beranda + string ARB `spikeDemo*` wajib dihapus
/// sebelum rilis v1.0.0 (P2 menggantinya dengan Player sungguhan).
library;

import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:laras/core/theme/app_colors.dart';
import 'package:laras/core/theme/app_theme.dart';
import 'package:laras/extractor/extractor.dart';
import 'package:laras/l10n/generated/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum _SongState { idle, resolving, playing, failed }

class _SongRow {
  _SongRow(this.song) : state = _SongState.idle;

  final CanarySong song;
  _SongState state;
  String? statusLine;
}

class SpikeDemoScreen extends StatefulWidget {
  const SpikeDemoScreen({super.key});

  @override
  State<SpikeDemoScreen> createState() => _SpikeDemoScreenState();
}

class _SpikeDemoScreenState extends State<SpikeDemoScreen> {
  final List<_SongRow> _rows = kCanarySongs
      .map<_SongRow>((CanarySong s) => _SongRow(s))
      .toList(growable: false);
  final AudioPlayer _player = AudioPlayer();

  StreamResolver? _resolver;
  SignatureSolver? _solver;
  List<ResolveLogEntry> _log = <ResolveLogEntry>[];
  String? _initError;
  bool _initializing = true;

  @override
  void initState() {
    super.initState();
    _initExtractor();
    _player.playerStateStream.listen((PlayerState state) {
      if (!mounted) return;
      if (state.processingState == ProcessingState.completed) {
        _markPlayingAsIdle();
      }
    });
  }

  Future<void> _initExtractor() async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final InnertubeClient innertube = InnertubeClient();
      final QuickJsSignatureSolver solver = QuickJsSignatureSolver();
      final StreamResolver resolver = StreamResolver(
        innertube: innertube,
        solver: solver,
        configLoader: RemoteConfigLoader(prefs: prefs),
        scriptLoader: PlayerScriptLoader(client: innertube),
      );
      if (!mounted) return;
      setState(() {
        _solver = solver;
        _resolver = resolver;
        _initializing = false;
      });
    } on Object catch (e) {
      if (!mounted) return;
      setState(() {
        _initError = e.toString();
        _initializing = false;
      });
    }
  }

  @override
  void dispose() {
    _player.dispose();
    _solver?.dispose();
    super.dispose();
  }

  void _markPlayingAsIdle() {
    setState(() {
      for (final _SongRow row in _rows) {
        if (row.state == _SongState.playing) {
          row.state = _SongState.idle;
          row.statusLine = null;
        }
      }
    });
  }

  Future<void> _onTapSong(_SongRow row) async {
    final StreamResolver? resolver = _resolver;
    if (resolver == null || row.state == _SongState.resolving) return;
    if (row.state == _SongState.playing) {
      await _player.stop();
      setState(() {
        row.state = _SongState.idle;
        row.statusLine = null;
      });
      return;
    }
    for (final _SongRow other in _rows) {
      if (other != row && other.state == _SongState.playing) {
        other.state = _SongState.idle;
        other.statusLine = null;
      }
    }
    await _player.stop();
    setState(() {
      row.state = _SongState.resolving;
      row.statusLine = null;
    });
    try {
      final ResolvedAudio resolved = await resolver.resolve(row.song.videoId);
      await _player.setUrl(resolved.url);
      await _player.play();
      if (!mounted) return;
      final double seconds = resolved.resolveDuration.inMilliseconds / 1000;
      setState(() {
        row.state = _SongState.playing;
        row.statusLine =
            '${AppLocalizations.of(context)!.spikeDemoReadyIn(seconds.toStringAsFixed(1))} · ${resolved.clientName}';
        _log = resolver.recentLog;
      });
    } on ExtractorException catch (e) {
      if (!mounted) return;
      setState(() {
        row.state = _SongState.failed;
        row.statusLine = _plainMessage(e);
        _log = resolver.recentLog;
      });
    } on Object {
      if (!mounted) return;
      setState(() {
        row.state = _SongState.failed;
        row.statusLine = AppLocalizations.of(context)!.songCannotPlay;
        _log = resolver.recentLog;
      });
    }
  }

  String _plainMessage(ExtractorException e) {
    final AppLocalizations strings = AppLocalizations.of(context)!;
    if (e.isNetworkError) return strings.noInternet;
    return strings.songCannotPlay;
  }

  String _formatDuration(int seconds) {
    final int minutes = seconds ~/ 60;
    final int rest = seconds % 60;
    return '$minutes:${rest.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations strings = AppLocalizations.of(context)!;
    final ThemeData theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(strings.spikeDemoTitle)),
      body: _initializing
          ? const Center(child: CircularProgressIndicator())
          : _initError != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Text(
                  strings.songCannotPlay,
                  style: theme.textTheme.bodyLarge,
                  textAlign: TextAlign.center,
                ),
              ),
            )
          : ListView(
              padding: const EdgeInsets.all(AppSpacing.md),
              children: <Widget>[
                Container(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    border: Border.all(color: AppColors.warning),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    strings.spikeDemoBanner,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: AppColors.warning,
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                ..._rows.map(_buildRow),
                const SizedBox(height: AppSpacing.xl),
                Text(
                  strings.spikeDemoLogTitle,
                  style: theme.textTheme.titleMedium,
                ),
                const SizedBox(height: AppSpacing.sm),
                if (_log.isEmpty)
                  Text(
                    strings.spikeDemoLogEmpty,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: AppColors.textMuted,
                    ),
                  )
                else
                  ..._log.reversed.map(
                    (ResolveLogEntry entry) => Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                      child: Text(
                        '[${entry.clientName}] ${entry.outcome} '
                        '(${entry.durationMs} ms)',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: AppColors.textMuted,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
    );
  }

  Widget _buildRow(_SongRow row) {
    final AppLocalizations strings = AppLocalizations.of(context)!;
    final ThemeData theme = Theme.of(context);
    final bool busy = row.state == _SongState.resolving;
    final bool playing = row.state == _SongState.playing;
    final bool failed = row.state == _SongState.failed;
    return Card(
      color: AppColors.surface,
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: InkWell(
        onTap: () => _onTapSong(row),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(
            children: <Widget>[
              SizedBox(
                width: 44,
                height: 44,
                child: busy
                    ? const CircularProgressIndicator()
                    : Icon(
                        playing ? Icons.stop : Icons.play_arrow,
                        color: playing
                            ? AppColors.success
                            : AppColors.textPrimary,
                        size: 32,
                      ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      row.song.title,
                      style: theme.textTheme.titleSmall,
                    ),
                    const SizedBox(height: AppSpacing.xxs),
                    Text(
                      _formatDuration(row.song.lengthSeconds),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AppColors.textMuted,
                      ),
                    ),
                    if (busy)
                      Padding(
                        padding: const EdgeInsets.only(top: AppSpacing.xxs),
                        child: Text(
                          strings.spikeDemoResolving,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                      )
                    else if (playing)
                      Padding(
                        padding: const EdgeInsets.only(top: AppSpacing.xxs),
                        child: Text(
                          strings.spikeDemoPlaying,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: AppColors.success,
                          ),
                        ),
                      )
                    else if (failed)
                      Padding(
                        padding: const EdgeInsets.only(top: AppSpacing.xxs),
                        child: Text(
                          row.statusLine ?? strings.songCannotPlay,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: AppColors.error,
                          ),
                        ),
                      ),
                    if (playing && row.statusLine != null)
                      Padding(
                        padding: const EdgeInsets.only(top: AppSpacing.xxs),
                        child: Text(
                          row.statusLine!,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: AppColors.textMuted,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
