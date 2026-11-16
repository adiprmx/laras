/// Tab Cari: kolom cari + riwayat + saran + hasil lokal dan online.
///
/// Alur (PRD B1):
/// - Mengetik menampilkan saran (jaringan, lalu riwayat lokal bila
///   jaringan gagal) — TANPA pencarian jaringan.
/// - Pencarian jaringan HANYA saat kueri dikirim eksplisit (tombol cari
///   di keyboard atau ketuk saran/riwayat).
/// - Hasil lokal (FTS5) tampil pertama, lalu kelompok online
///   (Lagu, Album, Artis, Playlist), masing-masing maks 10 + "Lihat
///   semua". Filter "Library saja" menyembunyikan kelompok online.
/// - Riwayat tampil di bawah kolom cari saat belum ada kueri; hapus per
///   item dengan tombol "Urungkan" 5 detik, hapus semua dengan dialog
///   konfirmasi.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:laras/core/theme/app_colors.dart';
import 'package:laras/core/theme/app_theme.dart';
import 'package:laras/core/widgets/empty_state.dart';
import 'package:laras/core/widgets/loading_rows.dart';
import 'package:laras/data/database.dart';
import 'package:laras/extractor/extractor.dart';
import 'package:laras/features/library/play_helpers.dart';
import 'package:laras/features/library/song_row.dart';
import 'package:laras/features/search/browse_card.dart';
import 'package:laras/features/search/browse_detail_screen.dart';
import 'package:laras/features/search/search_group_screen.dart';
import 'package:laras/features/search/search_scope.dart';
import 'package:laras/features/search/search_service.dart';
import 'package:laras/l10n/generated/app_localizations.dart';
import 'package:laras/player/player.dart';

/// Jeda sebelum saran diminta saat mengetik (PRD B1.2).
const Duration kSuggestionDebounce = Duration(milliseconds: 300);

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _controller = TextEditingController();
  Timer? _debounce;
  int _generation = 0;

  SearchService? _service;
  List<String> _history = const <String>[];
  List<String> _suggestions = const <String>[];
  CombinedSearch? _results;
  String? _submittedQuery;
  bool _loading = false;
  bool _libraryOnly = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onTextChanged);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final SearchService? service = SearchScope.maybeOf(context);
    if (service != _service) {
      _service = service;
      _reloadHistory();
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _reloadHistory() async {
    final SearchService? service = _service;
    if (service == null) return;
    final List<String> history = await service.recentSearches();
    if (!mounted) return;
    setState(() {
      _history = history;
    });
  }

  void _onTextChanged() {
    final String text = _controller.text;
    _debounce?.cancel();
    // Mengetik membatalkan hasil lama: hasil yang tampil harus sesuai
    // kueri yang dikirim, bukan ketikan baru yang belum dikirim.
    if (_results != null) {
      setState(() {
        _results = null;
        _submittedQuery = null;
      });
    }
    if (text.trim().isEmpty) {
      setState(() {
        _suggestions = const <String>[];
      });
      return;
    }
    _debounce = Timer(kSuggestionDebounce, () {
      _fetchSuggestions(text);
    });
  }

  Future<void> _fetchSuggestions(String input) async {
    final SearchService? service = _service;
    if (service == null) return;
    final int generation = ++_generation;
    final List<String> suggestions = await service.suggestions(input);
    if (!mounted || generation != _generation) return;
    // Jangan tampilkan saran untuk ketikan yang sudah berubah.
    if (_controller.text != input) return;
    setState(() {
      _suggestions = suggestions;
    });
  }

  Future<void> _submit(String rawQuery) async {
    final String query = rawQuery.trim();
    if (query.isEmpty) return;
    final SearchService? service = _service;
    if (service == null) return;
    FocusScope.of(context).unfocus();
    final int generation = ++_generation;
    setState(() {
      _loading = true;
      _suggestions = const <String>[];
      _submittedQuery = query;
    });
    final CombinedSearch results = _libraryOnly
        ? CombinedSearch(
            local: await service.searchLocalOnly(
              query,
              limit: kSearchLocalLimit,
            ),
          )
        : await service.search(query);
    if (!mounted || generation != _generation) return;
    if (_libraryOnly) {
      await service.recordSearchQuery(query);
    }
    setState(() {
      _results = results;
      _loading = false;
    });
    await _reloadHistory();
  }

  void _clearText() {
    _debounce?.cancel();
    _controller.clear();
    setState(() {
      _results = null;
      _submittedQuery = null;
      _suggestions = const <String>[];
    });
  }

  Future<void> _deleteHistory(String query) async {
    final SearchService? service = _service;
    if (service == null) return;
    await service.deleteSearchQuery(query);
    await _reloadHistory();
    if (!mounted) return;
    final AppLocalizations strings = AppLocalizations.of(context)!;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(strings.historyDeleted),
        duration: const Duration(seconds: 5),
        action: SnackBarAction(
          label: strings.undo,
          onPressed: () async {
            await service.restoreSearchQuery(query);
            await _reloadHistory();
          },
        ),
      ),
    );
  }

  Future<void> _clearHistory() async {
    final SearchService? service = _service;
    if (service == null) return;
    final AppLocalizations strings = AppLocalizations.of(context)!;
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(strings.clearSearchHistoryTitle),
          content: Text(strings.clearSearchHistoryBody),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(strings.cancel),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(strings.delete),
            ),
          ],
        );
      },
    );
    if (confirmed != true || !mounted) return;
    await service.clearSearchHistory();
    await _reloadHistory();
  }

  void _setLibraryOnly(bool value) {
    if (_libraryOnly == value) return;
    setState(() {
      _libraryOnly = value;
    });
    final String? query = _submittedQuery;
    if (query != null) {
      unawaited(_submit(query));
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations strings = AppLocalizations.of(context)!;
    final ThemeData theme = Theme.of(context);
    final PlayerService? service = PlayerScope.maybeOf(context);
    final AudioPlayerPort? port = service?.port;
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
          const SizedBox(height: AppSpacing.md),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            child: _SearchField(
              controller: _controller,
              hint: strings.searchFieldHint,
              clearLabel: strings.searchClear,
              onSubmitted: _submit,
              onClear: _clearText,
            ),
          ),
          if (_submittedQuery != null) ...<Widget>[
            const SizedBox(height: AppSpacing.sm),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
              child: Wrap(
                spacing: AppSpacing.xs,
                children: <Widget>[
                  ChoiceChip(
                    label: Text(strings.filterAll),
                    selected: !_libraryOnly,
                    onSelected: (_) => _setLibraryOnly(false),
                  ),
                  ChoiceChip(
                    label: Text(strings.filterLibraryOnly),
                    selected: _libraryOnly,
                    onSelected: (_) => _setLibraryOnly(true),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.sm),
          Expanded(
            child: port == null
                ? _buildBody(context, strings, null, PlayerSnapshot.idle)
                : StreamBuilder<PlayerSnapshot>(
                    stream: port.stateStream,
                    initialData: port.snapshot,
                    builder:
                        (
                          BuildContext context,
                          AsyncSnapshot<PlayerSnapshot> shot,
                        ) {
                          return _buildBody(
                            context,
                            strings,
                            port,
                            shot.data ?? port.snapshot,
                          );
                        },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody(
    BuildContext context,
    AppLocalizations strings,
    AudioPlayerPort? port,
    PlayerSnapshot snap,
  ) {
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.all(AppSpacing.md),
        child: LoadingRows(count: 6),
      );
    }
    final CombinedSearch? results = _results;
    final String? query = _submittedQuery;
    if (results != null && query != null) {
      return _SearchResults(
        results: results,
        query: query,
        libraryOnly: _libraryOnly,
        port: port,
        snap: snap,
        onRetry: () => _submit(query),
      );
    }
    if (_controller.text.trim().isNotEmpty) {
      return _SuggestionsList(
        suggestions: _suggestions,
        onPick: (String suggestion) {
          _controller.text = suggestion;
          unawaited(_submit(suggestion));
        },
      );
    }
    return _HistoryList(
      history: _history,
      hint: strings.searchHint,
      onPick: (String item) {
        _controller.text = item;
        unawaited(_submit(item));
      },
      onDelete: _deleteHistory,
      onClearAll: _history.isEmpty ? null : _clearHistory,
    );
  }
}

/// Kolom cari: ikon kaca pembesar, teks petunjuk, tombol silang saat ada
/// teks. Mengirim kueri lewat keyboard (tombol cari).
class _SearchField extends StatelessWidget {
  const _SearchField({
    required this.controller,
    required this.hint,
    required this.clearLabel,
    required this.onSubmitted,
    required this.onClear,
  });

  final TextEditingController controller;
  final String hint;
  final String clearLabel;
  final ValueChanged<String> onSubmitted;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (BuildContext context, Widget? child) {
        final bool hasText = controller.text.isNotEmpty;
        return TextField(
          controller: controller,
          textInputAction: TextInputAction.search,
          onSubmitted: onSubmitted,
          decoration: InputDecoration(
            hintText: hint,
            prefixIcon: const Icon(Icons.search),
            suffixIcon: hasText
                ? IconButton(
                    icon: const Icon(Icons.clear),
                    tooltip: clearLabel,
                    onPressed: onClear,
                  )
                : null,
            filled: true,
            fillColor: AppColors.surface,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadius.card),
              borderSide: BorderSide.none,
            ),
          ),
        );
      },
    );
  }
}

/// Daftar saran saat mengetik. Ketuk saran mengirim kueri itu.
class _SuggestionsList extends StatelessWidget {
  const _SuggestionsList({required this.suggestions, required this.onPick});

  final List<String> suggestions;
  final ValueChanged<String> onPick;

  @override
  Widget build(BuildContext context) {
    if (suggestions.isEmpty) return const SizedBox.shrink();
    return ListView.builder(
      itemCount: suggestions.length,
      itemBuilder: (BuildContext context, int index) {
        final String suggestion = suggestions[index];
        return ListTile(
          leading: const Icon(Icons.search),
          title: Text(suggestion),
          onTap: () => onPick(suggestion),
        );
      },
    );
  }
}

/// Riwayat pencarian di bawah kolom cari (saat belum ada kueri).
class _HistoryList extends StatelessWidget {
  const _HistoryList({
    required this.history,
    required this.hint,
    required this.onPick,
    required this.onDelete,
    required this.onClearAll,
  });

  final List<String> history;
  final String hint;
  final ValueChanged<String> onPick;
  final ValueChanged<String> onDelete;
  final VoidCallback? onClearAll;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations strings = AppLocalizations.of(context)!;
    final ThemeData theme = Theme.of(context);
    if (history.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Text(
          hint,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
      );
    }
    final VoidCallback? onClearAll = this.onClearAll;
    return ListView(
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.md,
            AppSpacing.xs,
            AppSpacing.xs,
            0,
          ),
          child: Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  strings.recentSearches,
                  style: theme.textTheme.titleMedium,
                ),
              ),
              if (onClearAll != null)
                TextButton(
                  onPressed: onClearAll,
                  child: Text(strings.deleteAll),
                ),
            ],
          ),
        ),
        for (final String item in history)
          ListTile(
            leading: const Icon(Icons.history),
            title: Text(item, maxLines: 1, overflow: TextOverflow.ellipsis),
            trailing: IconButton(
              icon: const Icon(Icons.close),
              tooltip: strings.delete,
              onPressed: () => onDelete(item),
            ),
            onTap: () => onPick(item),
          ),
      ],
    );
  }
}

/// Hasil pencarian: kelompok lokal dulu, lalu kelompok online.
class _SearchResults extends StatelessWidget {
  const _SearchResults({
    required this.results,
    required this.query,
    required this.libraryOnly,
    required this.port,
    required this.snap,
    required this.onRetry,
  });

  final CombinedSearch results;
  final String query;
  final bool libraryOnly;
  final AudioPlayerPort? port;
  final PlayerSnapshot snap;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations strings = AppLocalizations.of(context)!;
    final GroupedSearchResults? online = results.online;
    if (results.isEmpty && results.failure == null) {
      return EmptyState(
        icon: Icons.search_off_outlined,
        title: strings.noResultsTitle,
        body: strings.searchNoResults(query),
      );
    }
    return ListView(
      padding: const EdgeInsets.only(bottom: AppSpacing.xl),
      children: <Widget>[
        if (results.failure != null)
          _FailureBanner(failure: results.failure!, onRetry: onRetry),
        if (results.local.songs.isNotEmpty)
          _LocalSongsGroup(
            views: results.local.songs,
            query: query,
            port: port,
            snap: snap,
          ),
        // Label pemisah kelompok online (simetris dengan label lokal
        // "Dari Library-mu" di atas): pengguna tahu hasil di bawah ini
        // berasal dari internet, bukan dari HP.
        if (online != null && !libraryOnly && !online.isEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              AppSpacing.md,
              AppSpacing.md,
              0,
            ),
            child: Text(
              strings.onlineResults,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ),
        if (online != null && !libraryOnly) ...<Widget>[
          if (online.songs.isNotEmpty)
            _OnlineSongsGroup(
              songs: online.songs,
              query: query,
              filterParams: online.filterParams['songs'],
              port: port,
              snap: snap,
            ),
          if (online.albums.isNotEmpty)
            _OnlineBrowseGroup(
              title: strings.albums,
              items: <_BrowseEntry>[
                for (final SearchAlbum album in online.albums)
                  _BrowseEntry(
                    title: album.title,
                    subtitle: album.displaySubtitle,
                    thumbnailUrl: album.thumbnailUrl,
                    browseId: album.browseId,
                  ),
              ],
              query: query,
              group: SearchGroup.albums,
              filterParams: online.filterParams['albums'],
            ),
          if (online.artists.isNotEmpty)
            _OnlineBrowseGroup(
              title: strings.artists,
              items: <_BrowseEntry>[
                for (final SearchArtist artist in online.artists)
                  _BrowseEntry(
                    title: artist.name,
                    subtitle: artist.subscribersText,
                    thumbnailUrl: artist.thumbnailUrl,
                    browseId: artist.channelId,
                  ),
              ],
              query: query,
              group: SearchGroup.artists,
              filterParams: online.filterParams['artists'],
            ),
          if (online.playlists.isNotEmpty)
            _OnlineBrowseGroup(
              title: strings.playlists,
              items: <_BrowseEntry>[
                for (final SearchPlaylist playlist in online.playlists)
                  _BrowseEntry(
                    title: playlist.title,
                    subtitle: playlist.subtitle,
                    thumbnailUrl: playlist.thumbnailUrl,
                    browseId: playlist.browseId,
                  ),
              ],
              query: query,
              group: SearchGroup.playlists,
              filterParams:
                  online.filterParams['playlists'] ??
                  online.filterParams['playlistsCommunity'],
            ),
        ],
      ],
    );
  }
}

/// Banner kegagalan online di atas hasil lokal: hasil lokal tetap
/// tampil, pesan menjelaskan kenapa hasil internet tidak ada.
class _FailureBanner extends StatelessWidget {
  const _FailureBanner({required this.failure, required this.onRetry});

  final OnlineFailure failure;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations strings = AppLocalizations.of(context)!;
    final String message = switch (failure) {
      OnlineFailure.network => strings.searchNeedsInternet,
      OnlineFailure.parse => strings.searchServiceChanged,
      OnlineFailure.server => strings.onlineResultsFailed,
    };
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        0,
        AppSpacing.md,
        AppSpacing.sm,
      ),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.card),
        ),
        child: Row(
          children: <Widget>[
            Expanded(
              child: Text(
                message,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            TextButton(onPressed: onRetry, child: Text(strings.retry)),
          ],
        ),
      ),
    );
  }
}

/// Kepala kelompok hasil: judul + tombol "Lihat semua" bila ada.
class _GroupHeader extends StatelessWidget {
  const _GroupHeader({required this.title, required this.onSeeAll});

  final String title;
  final VoidCallback? onSeeAll;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations strings = AppLocalizations.of(context)!;
    final ThemeData theme = Theme.of(context);
    final VoidCallback? onSeeAll = this.onSeeAll;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.xs,
        0,
      ),
      child: Row(
        children: <Widget>[
          Expanded(child: Text(title, style: theme.textTheme.titleMedium)),
          if (onSeeAll != null)
            TextButton(onPressed: onSeeAll, child: Text(strings.seeAll)),
        ],
      ),
    );
  }
}

class _LocalSongsGroup extends StatelessWidget {
  const _LocalSongsGroup({
    required this.views,
    required this.query,
    required this.port,
    required this.snap,
  });

  final List<SongView> views;
  final String query;
  final AudioPlayerPort? port;
  final PlayerSnapshot snap;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations strings = AppLocalizations.of(context)!;
    final AudioPlayerPort? port = this.port;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        _GroupHeader(
          title: strings.fromYourLibrary,
          // "Lihat semua" hanya bila hasil mencapai batas: di bawah itu
          // semua hasil sudah tampil.
          onSeeAll: views.length >= kSearchLocalLimit
              ? () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (BuildContext context) => SearchGroupScreen(
                        title: strings.fromYourLibrary,
                        query: query,
                        group: SearchGroup.localSongs,
                      ),
                    ),
                  );
                }
              : null,
        ),
        for (int i = 0; i < views.length; i++)
          Builder(
            builder: (BuildContext context) {
              final SongView view = views[i];
              final Track track = view.toTrack();
              final Track? current = snap.currentTrack;
              final bool isCurrent =
                  current != null && current.videoId == track.videoId;
              return SongRow(
                title: view.song.title,
                subtitle: view.artistNames.isEmpty ? null : view.artistsLabel,
                artUri: track.artUri,
                duration: track.duration,
                isCurrent: isCurrent,
                isPlaying: isCurrent && snap.playing,
                onTap: port == null
                    ? null
                    : () => playSongViews(port, snap, views, i),
              );
            },
          ),
      ],
    );
  }
}

class _OnlineSongsGroup extends StatelessWidget {
  const _OnlineSongsGroup({
    required this.songs,
    required this.query,
    required this.filterParams,
    required this.port,
    required this.snap,
  });

  final List<SearchSong> songs;
  final String query;
  final String? filterParams;
  final AudioPlayerPort? port;
  final PlayerSnapshot snap;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations strings = AppLocalizations.of(context)!;
    final List<Track> tracks = songs
        .map((SearchSong s) => s.toTrack())
        .toList(growable: false);
    final List<Track> shown = tracks.length > kSearchOnlineGroupLimit
        ? tracks.sublist(0, kSearchOnlineGroupLimit)
        : tracks;
    final AudioPlayerPort? port = this.port;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        _GroupHeader(
          title: strings.songs,
          onSeeAll: tracks.length >= kSearchOnlineGroupLimit
              ? () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (BuildContext context) => SearchGroupScreen(
                        title: strings.songs,
                        query: query,
                        group: SearchGroup.songs,
                        params: filterParams,
                      ),
                    ),
                  );
                }
              : null,
        ),
        for (int i = 0; i < shown.length; i++)
          Builder(
            builder: (BuildContext context) {
              final Track track = shown[i];
              final Track? current = snap.currentTrack;
              final bool isCurrent =
                  current != null && current.videoId == track.videoId;
              final bool busy =
                  isCurrent &&
                  (snap.status == PlayerStatus.loading ||
                      snap.status == PlayerStatus.buffering);
              return SongRow(
                title: track.title,
                subtitle: track.artist,
                artUri: track.artUri,
                duration: track.duration,
                isCurrent: isCurrent,
                isPlaying: isCurrent && snap.playing,
                isBusy: busy,
                onTap: port == null
                    ? null
                    : () => playTracks(port, snap, tracks, i),
                trailing: port == null
                    ? null
                    : RoundPlayButton(
                        isPlaying: isCurrent && snap.playing,
                        onPressed: () => playTracks(port, snap, tracks, i),
                      ),
              );
            },
          ),
      ],
    );
  }
}

class _BrowseEntry {
  const _BrowseEntry({
    required this.title,
    required this.subtitle,
    required this.thumbnailUrl,
    required this.browseId,
  });

  final String title;
  final String? subtitle;
  final String? thumbnailUrl;
  final String browseId;
}

class _OnlineBrowseGroup extends StatelessWidget {
  const _OnlineBrowseGroup({
    required this.title,
    required this.items,
    required this.query,
    required this.group,
    required this.filterParams,
  });

  final String title;
  final List<_BrowseEntry> items;
  final String query;
  final SearchGroup group;
  final String? filterParams;

  @override
  Widget build(BuildContext context) {
    final List<_BrowseEntry> shown = items.length > kSearchOnlineGroupLimit
        ? items.sublist(0, kSearchOnlineGroupLimit)
        : items;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        _GroupHeader(
          title: title,
          onSeeAll: items.length >= kSearchOnlineGroupLimit
              ? () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (BuildContext context) => SearchGroupScreen(
                        title: title,
                        query: query,
                        group: group,
                        params: filterParams,
                      ),
                    ),
                  );
                }
              : null,
        ),
        for (final _BrowseEntry item in shown)
          BrowseResultRow(
            title: item.title,
            subtitle: item.subtitle,
            artUri: item.thumbnailUrl == null
                ? null
                : Uri.tryParse(item.thumbnailUrl!),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (BuildContext context) => BrowseDetailScreen(
                    browseId: item.browseId,
                    title: item.title,
                    subtitle: item.subtitle,
                    artUri: item.thumbnailUrl == null
                        ? null
                        : Uri.tryParse(item.thumbnailUrl!),
                  ),
                ),
              );
            },
          ),
      ],
    );
  }
}
