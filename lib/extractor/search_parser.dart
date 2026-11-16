/// Parser respons search dan browse InnerTube YouTube Music.
///
/// Bentuk respons di sini DIBUKTIKAN dari rekaman nyata (bukan tebakan):
/// - search: `test/fixtures/search-peterpan.json` (rekaman API P1,
///   15 Nov 2026) — daftar datar `musicResponsiveListItemRenderer` di
///   dalam `itemSectionRenderer`, ditambah `musicCardShelfRenderer`
///   hasil teratas dan `chipCloudRenderer` berisi parameter filter.
/// - browse: `test/fixtures/browse-*.json` (diekstrak dari HTML
///   music.youtube.com, 16 Nov 2026) — `singleColumnBrowseResultsRenderer`
///   untuk beranda/artis/mood, `twoColumnBrowseResultsRenderer` untuk
///   album/playlist.
///
/// Parser ini toleran: satu item yang gagal di-parse dilewati, satu
/// kelompok yang gagal tidak mengosongkan kelompok lain (PRD B1.1).
/// Parser tidak pernah melempar untuk bentuk yang tidak dikenal —
/// hasilnya hanya kosong. Kegagalan total (bukan JSON / tanpa `contents`)
/// ditangani pemanggil sebagai parse gagal.
library;

import 'models.dart';

/// Kata tipe di awal subjudul item pencarian, sesuai yang teramati di
/// rekaman nyata.
const Set<String> _songTypes = <String>{'Song', 'Video'};

/// Parameter filter pencarian per kelompok, dibaca dari chip respons.
/// Kunci peta hasil: `songs`, `albums`, `artists`, `playlists`.
const Map<String, String> _chipKeyByText = <String, String>{
  'Songs': 'songs',
  'Albums': 'albums',
  'Artists': 'artists',
  'Videos': 'videos',
  'Featured playlists': 'playlists',
  'Community playlists': 'playlistsCommunity',
};

/// Parse respons search menjadi hasil yang sudah dikelompokkan.
GroupedSearchResults parseGroupedSearchResults(Map<String, dynamic> json) {
  final List<SearchSong> songs = <SearchSong>[];
  final List<SearchAlbum> albums = <SearchAlbum>[];
  final List<SearchArtist> artists = <SearchArtist>[];
  final List<SearchPlaylist> playlists = <SearchPlaylist>[];
  final Map<String, String> filterParams = <String, String>{};
  final Set<String> seenSongs = <String>{};
  final Set<String> seenBrowse = <String>{};

  final Map<String, dynamic>? sectionList = _searchSectionList(json);
  if (sectionList == null) return const GroupedSearchResults();

  // Parameter filter dari chip (dipakai layar "Lihat semua").
  final Map<String, dynamic>? header =
      sectionList['header'] as Map<String, dynamic>?;
  final Map<String, dynamic>? chipCloud =
      header?['chipCloudRenderer'] as Map<String, dynamic>?;
  final List<dynamic>? chips = chipCloud?['chips'] as List<dynamic>?;
  if (chips != null) {
    for (final dynamic raw in chips) {
      if (raw is! Map<String, dynamic>) continue;
      final Map<String, dynamic>? chip =
          raw['chipCloudChipRenderer'] as Map<String, dynamic>?;
      if (chip == null) continue;
      final String text = _runsText(chip['text']);
      final String? key = _chipKeyByText[text];
      if (key == null) continue;
      final Map<String, dynamic>? endpoint =
          chip['navigationEndpoint'] as Map<String, dynamic>?;
      final Map<String, dynamic>? searchEndpoint =
          endpoint?['searchEndpoint'] as Map<String, dynamic>?;
      final String? params = searchEndpoint?['params'] as String?;
      if (params != null && params.isNotEmpty) {
        filterParams.putIfAbsent(key, () => params);
      }
    }
  }

  void addSong(SearchSong song) {
    if (seenSongs.add(song.videoId)) songs.add(song);
  }

  void addAlbum(SearchAlbum album) {
    if (seenBrowse.add(album.browseId)) albums.add(album);
  }

  void addArtist(SearchArtist artist) {
    if (seenBrowse.add(artist.channelId)) artists.add(artist);
  }

  void addPlaylist(SearchPlaylist playlist) {
    if (seenBrowse.add(playlist.browseId)) playlists.add(playlist);
  }

  final List<dynamic>? sections = sectionList['contents'] as List<dynamic>?;
  if (sections == null) {
    return GroupedSearchResults(filterParams: filterParams);
  }
  for (final dynamic rawSection in sections) {
    if (rawSection is! Map<String, dynamic>) continue;
    try {
      // Kartu hasil teratas: lagu dari onTap + item-item di dalamnya.
      final Map<String, dynamic>? card =
          rawSection['musicCardShelfRenderer'] as Map<String, dynamic>?;
      if (card != null) {
        final SearchSong? topSong = _parseCardSong(card);
        if (topSong != null) addSong(topSong);
        final List<dynamic>? cardItems = card['contents'] as List<dynamic>?;
        if (cardItems != null) {
          for (final dynamic rawItem in cardItems) {
            _classifyListItem(
              rawItem,
              addSong: addSong,
              addAlbum: addAlbum,
              addArtist: addArtist,
              addPlaylist: addPlaylist,
            );
          }
        }
        continue;
      }
      // Bagian biasa: kumpulkan semua baris daftar di dalamnya.
      for (final Map<String, dynamic> item in _collectListItems(rawSection)) {
        _classifyListItem(
          <String, dynamic>{'musicResponsiveListItemRenderer': item},
          addSong: addSong,
          addAlbum: addAlbum,
          addArtist: addArtist,
          addPlaylist: addPlaylist,
        );
      }
    } catch (_) {
      // Satu bagian rusak tidak boleh mengosongkan hasil lain.
      continue;
    }
  }

  return GroupedSearchResults(
    songs: songs,
    albums: albums,
    artists: artists,
    playlists: playlists,
    filterParams: filterParams,
  );
}

/// Parse respons browse menjadi halaman (kepala + rak-rak).
BrowsePage parseBrowsePage(Map<String, dynamic> json) {
  final Map<String, dynamic>? contents =
      json['contents'] as Map<String, dynamic>?;
  if (contents == null) return const BrowsePage(title: '');

  // Dua kolom (album/playlist): kepala di tab, lagu di secondaryContents.
  final Map<String, dynamic>? twoColumn =
      contents['twoColumnBrowseResultsRenderer'] as Map<String, dynamic>?;
  if (twoColumn != null) return _parseTwoColumnPage(twoColumn);

  final Map<String, dynamic>? singleColumn =
      contents['singleColumnBrowseResultsRenderer'] as Map<String, dynamic>?;
  if (singleColumn == null) return const BrowsePage(title: '');

  String title = '';
  String? subtitle;
  String? thumbnailUrl;
  final Map<String, dynamic>? header = json['header'] as Map<String, dynamic>?;
  if (header != null) {
    final Map<String, dynamic>? renderer = _firstRenderer(header);
    if (renderer != null) {
      title = _runsText(renderer['title']);
      subtitle = _runsText(renderer['subtitle']);
      if (subtitle.isEmpty) subtitle = null;
      thumbnailUrl = _bestThumbnail(
        renderer['thumbnail'] as Map<String, dynamic>?,
      );
    }
  }

  final List<BrowseShelf> shelves = <BrowseShelf>[];
  final Map<String, dynamic>? sectionList = _tabSectionList(singleColumn);
  final List<dynamic>? sections = sectionList?['contents'] as List<dynamic>?;
  if (sections != null) {
    for (final dynamic rawSection in sections) {
      if (rawSection is! Map<String, dynamic>) continue;
      try {
        final BrowseShelf? shelf = _parseBrowseSection(rawSection);
        if (shelf != null && shelf.items.isNotEmpty) shelves.add(shelf);
      } catch (_) {
        continue;
      }
    }
  }
  return BrowsePage(
    title: title,
    subtitle: subtitle,
    thumbnailUrl: thumbnailUrl,
    shelves: shelves,
  );
}

/// Parse respons `music/get_search_suggestions` menjadi daftar teks saran.
///
/// Bentuk respons terverifikasi live 16 Nov 2026 (fixture
/// `suggest-noah.json`): `contents[].searchSuggestionsSectionRenderer
/// .contents[].searchSuggestionRenderer.suggestion.runs`. Parser berjalan
/// toleran (mencari node `searchSuggestionRenderer` di mana pun di pohon)
/// supaya tetap jalan bila YouTube menambah section lain. Bila respons
/// tidak membawa node itu, hasilnya kosong dan layar memakai saran
/// riwayat lokal.
List<String> parseSearchSuggestions(Map<String, dynamic> json) {
  final List<String> out = <String>[];
  final Set<String> seen = <String>{};
  // Antrean (BFS), bukan tumpukan: urutan dokumen dipertahankan supaya
  // saran tampil sesuai urutan YouTube (paling relevan dulu).
  final List<Object?> queue = <Object?>[json];
  int index = 0;
  while (index < queue.length) {
    final Object? node = queue[index++];
    if (node is List) {
      queue.addAll(node);
      continue;
    }
    if (node is! Map<String, dynamic>) continue;
    final Map<String, dynamic>? suggestion =
        node['searchSuggestionRenderer'] as Map<String, dynamic>?;
    if (suggestion != null) {
      final String text = _runsText(suggestion['suggestion']);
      if (text.isNotEmpty && seen.add(text.toLowerCase())) out.add(text);
    }
    queue.addAll(node.values);
  }
  return out;
}

// ------------------------------------------------------------------
// Search: struktur dasar
// ------------------------------------------------------------------

Map<String, dynamic>? _searchSectionList(Map<String, dynamic> json) {
  final Map<String, dynamic>? contents =
      json['contents'] as Map<String, dynamic>?;
  final Map<String, dynamic>? tabbed =
      contents?['tabbedSearchResultsRenderer'] as Map<String, dynamic>?;
  final List<dynamic>? tabs = tabbed?['tabs'] as List<dynamic>?;
  if (tabs == null || tabs.isEmpty) return null;
  Map<String, dynamic>? tab;
  for (final dynamic raw in tabs) {
    if (raw is! Map<String, dynamic>) continue;
    final Map<String, dynamic>? renderer =
        raw['tabRenderer'] as Map<String, dynamic>?;
    if (renderer == null) continue;
    tab ??= renderer;
    if (renderer['selected'] == true) {
      tab = renderer;
      break;
    }
  }
  final Map<String, dynamic>? content =
      tab?['content'] as Map<String, dynamic>?;
  return content?['sectionListRenderer'] as Map<String, dynamic>?;
}

Map<String, dynamic>? _tabSectionList(Map<String, dynamic> resultsRenderer) {
  final List<dynamic>? tabs = resultsRenderer['tabs'] as List<dynamic>?;
  if (tabs == null || tabs.isEmpty) return null;
  for (final dynamic raw in tabs) {
    if (raw is! Map<String, dynamic>) continue;
    final Map<String, dynamic>? renderer =
        raw['tabRenderer'] as Map<String, dynamic>?;
    if (renderer == null) continue;
    final Map<String, dynamic>? content =
        renderer['content'] as Map<String, dynamic>?;
    final Map<String, dynamic>? sectionList =
        content?['sectionListRenderer'] as Map<String, dynamic>?;
    if (sectionList != null) return sectionList;
  }
  return null;
}

/// Kumpulkan semua `musicResponsiveListItemRenderer` di satu subtree.
List<Map<String, dynamic>> _collectListItems(Map<String, dynamic> node) {
  final List<Map<String, dynamic>> out = <Map<String, dynamic>>[];
  final List<Object?> stack = <Object?>[node];
  while (stack.isNotEmpty) {
    final Object? current = stack.removeLast();
    if (current is List) {
      stack.addAll(current);
      continue;
    }
    if (current is! Map<String, dynamic>) continue;
    final Map<String, dynamic>? item =
        current['musicResponsiveListItemRenderer'] as Map<String, dynamic>?;
    if (item != null) {
      out.add(item);
      continue;
    }
    stack.addAll(current.values);
  }
  return out;
}

/// Lagu dari kartu hasil teratas (musicCardShelfRenderer).
SearchSong? _parseCardSong(Map<String, dynamic> card) {
  final Map<String, dynamic>? onTap = card['onTap'] as Map<String, dynamic>?;
  final Map<String, dynamic>? watch =
      onTap?['watchEndpoint'] as Map<String, dynamic>?;
  final String? videoId = watch?['videoId'] as String?;
  if (videoId == null || videoId.isEmpty) return null;
  final String title = _runsText(card['title']);
  if (title.isEmpty) return null;
  final List<Map<String, dynamic>> runs = _runsOf(
    card['subtitle'] as Map<String, dynamic>?,
  );
  String? artist;
  String? artistChannelId;
  int? durationSeconds;
  for (final Map<String, dynamic> run in runs) {
    final String text = run['text'] as String? ?? '';
    final Map<String, dynamic>? browse = _runBrowseEndpoint(run);
    final String? pageType = _browsePageType(browse);
    if (pageType == 'MUSIC_PAGE_TYPE_ARTIST') {
      artist ??= text;
      artistChannelId ??= browse?['browseId'] as String?;
    }
    durationSeconds ??= _parseDuration(text);
  }
  return SearchSong(
    videoId: videoId,
    title: title,
    artist: artist,
    artistChannelId: artistChannelId,
    durationSeconds: durationSeconds,
    thumbnailUrl: _bestThumbnail(card['thumbnail'] as Map<String, dynamic>?),
  );
}

/// Klasifikasikan satu baris daftar ke kelompok hasil yang tepat.
void _classifyListItem(
  dynamic rawItem, {
  required void Function(SearchSong) addSong,
  required void Function(SearchAlbum) addAlbum,
  required void Function(SearchArtist) addArtist,
  required void Function(SearchPlaylist) addPlaylist,
}) {
  if (rawItem is! Map<String, dynamic>) return;
  final Map<String, dynamic>? item =
      rawItem['musicResponsiveListItemRenderer'] as Map<String, dynamic>?;
  if (item == null) return;
  try {
    final List<String> flexTexts = _flexTexts(item);
    if (flexTexts.isEmpty || flexTexts.first.isEmpty) return;
    final String title = flexTexts.first;
    final String subtitle = flexTexts.length > 1 ? flexTexts[1] : '';
    final String typeWord = subtitle.split('•').first.trim();
    final String? videoId = _itemVideoId(item);
    final Map<String, dynamic>? browse = _itemBrowseEndpoint(item);
    final String? pageType = _browsePageType(browse);
    final String? browseId = browse?['browseId'] as String?;
    final String? thumbnailUrl = _bestThumbnail(
      item['thumbnail'] as Map<String, dynamic>?,
    );

    // Lagu/video: punya videoId dan (tipe lagu/video, atau tanpa tipe
    // browse yang jelas). Tipe lain yang punya videoId tetap lagu —
    // videoId adalah yang menentukan bisa diputar.
    if (videoId != null &&
        (_songTypes.contains(typeWord) ||
            typeWord.isEmpty ||
            pageType == null)) {
      final _ArtistAlbum meta = _artistAlbumFromItem(item, subtitle);
      addSong(
        SearchSong(
          videoId: videoId,
          title: title,
          artist: meta.artist,
          artistChannelId: meta.artistChannelId,
          album: meta.album,
          albumBrowseId: meta.albumBrowseId,
          durationSeconds: _durationFromItem(item),
          thumbnailUrl: thumbnailUrl,
        ),
      );
      return;
    }
    if (browseId == null || browseId.isEmpty) return;
    if (typeWord == 'Artist' || pageType == 'MUSIC_PAGE_TYPE_ARTIST') {
      final String detail = subtitle.split('•').length > 1
          ? subtitle.split('•').sublist(1).join('•').trim()
          : '';
      addArtist(
        SearchArtist(
          channelId: browseId,
          name: title,
          thumbnailUrl: thumbnailUrl,
          subscribersText: detail.isEmpty ? null : detail,
        ),
      );
      return;
    }
    if (typeWord == 'Album' ||
        typeWord == 'Single' ||
        typeWord == 'EP' ||
        pageType == 'MUSIC_PAGE_TYPE_ALBUM') {
      final List<String> parts = subtitle
          .split('•')
          .map((String s) => s.trim())
          .where((String s) => s.isNotEmpty)
          .toList(growable: false);
      int? year;
      if (parts.isNotEmpty) {
        year = int.tryParse(parts.last);
        if (year == null || year < 1900 || year > 2100) year = null;
      }
      final List<String> artists = parts.length > 1
          ? _splitNames(parts[1])
          : const <String>[];
      addAlbum(
        SearchAlbum(
          browseId: browseId,
          title: title,
          artists: artists,
          year: year,
          thumbnailUrl: thumbnailUrl,
        ),
      );
      return;
    }
    if (typeWord == 'Playlist' || pageType == 'MUSIC_PAGE_TYPE_PLAYLIST') {
      final String detail = subtitle.split('•').length > 1
          ? subtitle.split('•').sublist(1).join('•').trim()
          : '';
      addPlaylist(
        SearchPlaylist(
          browseId: browseId,
          title: title,
          subtitle: detail.isEmpty ? null : detail,
          thumbnailUrl: thumbnailUrl,
        ),
      );
      return;
    }
    // Podcast, Episode, Profile, dan tipe lain: bukan musik v1,
    // sengaja dilewati (tidak masuk kelompok mana pun).
  } catch (_) {
    // Satu item rusak tidak boleh mengosongkan kelompoknya.
    return;
  }
}

// ------------------------------------------------------------------
// Browse: dua kolom (album/playlist) dan satu kolom (beranda/artis)
// ------------------------------------------------------------------

BrowsePage _parseTwoColumnPage(Map<String, dynamic> twoColumn) {
  String title = '';
  String? subtitle;
  String? thumbnailUrl;
  final List<BrowseShelf> shelves = <BrowseShelf>[];
  String? continuation;

  final Map<String, dynamic>? tabSectionList = _tabSectionList(twoColumn);
  final List<dynamic>? tabSections =
      tabSectionList?['contents'] as List<dynamic>?;
  if (tabSections != null) {
    for (final dynamic raw in tabSections) {
      if (raw is! Map<String, dynamic>) continue;
      final Map<String, dynamic>? header =
          raw['musicResponsiveHeaderRenderer'] as Map<String, dynamic>?;
      if (header == null) continue;
      title = _runsText(header['title']);
      final String sub1 = _runsText(header['subtitle']);
      final String sub2 = _runsText(header['secondSubtitle']);
      final String joined = <String>[
        sub1,
        sub2,
      ].where((String s) => s.isNotEmpty).join(' • ');
      subtitle = joined.isEmpty ? null : joined;
      thumbnailUrl = _bestThumbnail(
        header['thumbnail'] as Map<String, dynamic>?,
      );
    }
  }

  final Map<String, dynamic>? secondary =
      twoColumn['secondaryContents'] as Map<String, dynamic>?;
  final Map<String, dynamic>? secList =
      secondary?['sectionListRenderer'] as Map<String, dynamic>?;
  continuation = _continuationToken(secList);
  final List<dynamic>? secContents = secList?['contents'] as List<dynamic>?;
  if (secContents != null) {
    for (final dynamic raw in secContents) {
      if (raw is! Map<String, dynamic>) continue;
      final Map<String, dynamic>? shelf =
          raw['musicPlaylistShelfRenderer'] as Map<String, dynamic>? ??
          raw['musicShelfRenderer'] as Map<String, dynamic>?;
      if (shelf == null) continue;
      final List<BrowseItem> items = _listItemsToBrowseItems(
        shelf['contents'] as List<dynamic>?,
      );
      if (items.isNotEmpty) {
        shelves.add(BrowseShelf(title: title, items: items, isSongList: true));
      }
    }
  }
  return BrowsePage(
    title: title,
    subtitle: subtitle,
    thumbnailUrl: thumbnailUrl,
    shelves: shelves,
    continuation: continuation,
  );
}

BrowseShelf? _parseBrowseSection(Map<String, dynamic> section) {
  final Map<String, dynamic>? carousel =
      section['musicCarouselShelfRenderer'] as Map<String, dynamic>?;
  if (carousel != null) {
    final Map<String, dynamic>? header =
        carousel['header'] as Map<String, dynamic>?;
    final Map<String, dynamic>? basicHeader =
        header?['musicCarouselShelfBasicHeaderRenderer']
            as Map<String, dynamic>?;
    final String title = _runsText(basicHeader?['title']);
    final List<BrowseItem> items = <BrowseItem>[];
    final List<dynamic>? contents = carousel['contents'] as List<dynamic>?;
    if (contents != null) {
      for (final dynamic raw in contents) {
        if (raw is! Map<String, dynamic>) continue;
        try {
          final BrowseItem? item = _parseTwoRowItem(raw);
          if (item != null) items.add(item);
        } catch (_) {
          continue;
        }
      }
    }
    if (title.isEmpty && items.isEmpty) return null;
    return BrowseShelf(title: title, items: items);
  }

  final Map<String, dynamic>? shelf =
      section['musicShelfRenderer'] as Map<String, dynamic>?;
  if (shelf != null) {
    final String title = _runsText(shelf['title']);
    final List<BrowseItem> items = _listItemsToBrowseItems(
      shelf['contents'] as List<dynamic>?,
    );
    if (items.isEmpty) return null;
    return BrowseShelf(title: title, items: items, isSongList: true);
  }

  final Map<String, dynamic>? grid =
      section['gridRenderer'] as Map<String, dynamic>?;
  if (grid != null) {
    final Map<String, dynamic>? gridHeader =
        grid['header'] as Map<String, dynamic>?;
    final Map<String, dynamic>? gridTitle =
        gridHeader?['gridHeaderRenderer'] as Map<String, dynamic>?;
    final String title = _runsText(gridTitle?['title']);
    final List<BrowseItem> items = <BrowseItem>[];
    final List<dynamic>? gridItems = grid['items'] as List<dynamic>?;
    if (gridItems != null) {
      for (final dynamic raw in gridItems) {
        if (raw is! Map<String, dynamic>) continue;
        try {
          final Map<String, dynamic>? button =
              raw['musicNavigationButtonRenderer'] as Map<String, dynamic>?;
          if (button == null) continue;
          final String text = _runsText(button['buttonText']);
          final Map<String, dynamic>? click =
              button['clickCommand'] as Map<String, dynamic>?;
          final Map<String, dynamic>? browse =
              click?['browseEndpoint'] as Map<String, dynamic>?;
          final String? browseId = browse?['browseId'] as String?;
          if (text.isEmpty || browseId == null || browseId.isEmpty) {
            continue;
          }
          items.add(
            BrowseItem(
              kind: BrowseItemKind.category,
              title: text,
              browseId: browseId,
              browseParams: browse?['params'] as String?,
              thumbnailUrl: _bestThumbnail(
                button['thumbnail'] as Map<String, dynamic>?,
              ),
            ),
          );
        } catch (_) {
          continue;
        }
      }
    }
    if (items.isEmpty) return null;
    return BrowseShelf(title: title, items: items);
  }

  // itemSectionRenderer berisi baris daftar (bentuk cadangan).
  final Map<String, dynamic>? itemSection =
      section['itemSectionRenderer'] as Map<String, dynamic>?;
  if (itemSection != null) {
    final List<BrowseItem> items = _listItemsToBrowseItems(
      itemSection['contents'] as List<dynamic>?,
    );
    if (items.isEmpty) return null;
    return BrowseShelf(title: '', items: items, isSongList: true);
  }
  return null;
}

/// Kartu dua baris (musicTwoRowItemRenderer) menjadi [BrowseItem].
BrowseItem? _parseTwoRowItem(Map<String, dynamic> raw) {
  final Map<String, dynamic>? item =
      raw['musicTwoRowItemRenderer'] as Map<String, dynamic>?;
  if (item == null) return null;
  final String title = _runsText(item['title']);
  if (title.isEmpty) return null;
  final String subtitle = _runsText(item['subtitle']);
  final String? thumbnailUrl = _bestThumbnail(
    item['thumbnailRenderer'] as Map<String, dynamic>?,
  );
  final Map<String, dynamic>? endpoint =
      item['navigationEndpoint'] as Map<String, dynamic>?;
  final Map<String, dynamic>? watch =
      endpoint?['watchEndpoint'] as Map<String, dynamic>?;
  final String? videoId = watch?['videoId'] as String?;
  if (videoId != null && videoId.isNotEmpty) {
    final List<String> parts = subtitle
        .split('•')
        .map((String s) => s.trim())
        .where((String s) => s.isNotEmpty)
        .toList(growable: false);
    return BrowseItem(
      kind: BrowseItemKind.song,
      title: title,
      subtitle: subtitle.isEmpty ? null : subtitle,
      videoId: videoId,
      thumbnailUrl: thumbnailUrl,
      artist: parts.isEmpty ? null : parts.first,
    );
  }
  final Map<String, dynamic>? browse =
      endpoint?['browseEndpoint'] as Map<String, dynamic>?;
  final String? browseId = browse?['browseId'] as String?;
  if (browseId == null || browseId.isEmpty) return null;
  final String? pageType = _browsePageType(browse);
  final BrowseItemKind kind = switch (pageType) {
    'MUSIC_PAGE_TYPE_ALBUM' => BrowseItemKind.album,
    'MUSIC_PAGE_TYPE_ARTIST' => BrowseItemKind.artist,
    'MUSIC_PAGE_TYPE_PLAYLIST' => BrowseItemKind.playlist,
    _ =>
      browseId.startsWith('MPRE')
          ? BrowseItemKind.album
          : browseId.startsWith('UC')
          ? BrowseItemKind.artist
          : BrowseItemKind.playlist,
  };
  return BrowseItem(
    kind: kind,
    title: title,
    subtitle: subtitle.isEmpty ? null : subtitle,
    browseId: browseId,
    browseParams: browse?['params'] as String?,
    thumbnailUrl: thumbnailUrl,
  );
}

/// Baris daftar (musicResponsiveListItemRenderer) menjadi item lagu browse.
List<BrowseItem> _listItemsToBrowseItems(List<dynamic>? contents) {
  final List<BrowseItem> out = <BrowseItem>[];
  if (contents == null) return out;
  for (final dynamic raw in contents) {
    if (raw is! Map<String, dynamic>) continue;
    try {
      final Map<String, dynamic>? item =
          raw['musicResponsiveListItemRenderer'] as Map<String, dynamic>?;
      if (item == null) continue;
      final List<String> flexTexts = _flexTexts(item);
      if (flexTexts.isEmpty || flexTexts.first.isEmpty) continue;
      final String? videoId = _itemVideoId(item);
      if (videoId == null || videoId.isEmpty) continue;
      final String subtitle = flexTexts.length > 1 ? flexTexts[1] : '';
      final _ArtistAlbum meta = _artistAlbumFromItem(item, subtitle);
      out.add(
        BrowseItem(
          kind: BrowseItemKind.song,
          title: flexTexts.first,
          subtitle: subtitle.isEmpty ? null : subtitle,
          videoId: videoId,
          thumbnailUrl: _bestThumbnail(
            item['thumbnail'] as Map<String, dynamic>?,
          ),
          durationSeconds: _durationFromItem(item),
          artist: meta.artist,
          artistChannelId: meta.artistChannelId,
          album: meta.album,
          albumBrowseId: meta.albumBrowseId,
        ),
      );
    } catch (_) {
      continue;
    }
  }
  return out;
}

// ------------------------------------------------------------------
// Primitif bersama: teks runs, thumbnail, durasi, endpoint
// ------------------------------------------------------------------

/// Teks dari objek `simpleText`/`runs` InnerTube.
String _runsText(Object? node) {
  if (node is Map<String, dynamic>) {
    final Object? simple = node['simpleText'];
    if (simple is String) return simple;
    final Object? runs = node['runs'];
    if (runs is List) {
      final StringBuffer buffer = StringBuffer();
      for (final dynamic run in runs) {
        if (run is Map<String, dynamic>) {
          final Object? text = run['text'];
          if (text is String) buffer.write(text);
        }
      }
      return buffer.toString();
    }
  }
  if (node is String) return node;
  return '';
}

List<Map<String, dynamic>> _runsOf(Map<String, dynamic>? node) {
  if (node == null) return const <Map<String, dynamic>>[];
  final List<dynamic>? runs = node['runs'] as List<dynamic>?;
  if (runs == null) return const <Map<String, dynamic>>[];
  return runs.whereType<Map<String, dynamic>>().toList(growable: false);
}

/// Renderer pertama di dalam objek pembungkus (mis. `header`).
Map<String, dynamic>? _firstRenderer(Map<String, dynamic> wrapper) {
  for (final Object? value in wrapper.values) {
    if (value is Map<String, dynamic>) return value;
  }
  return null;
}

/// Thumbnail terbesar yang lebarnya tidak melebihi 544 px (cukup untuk
/// sampul di daftar dan kartu); bila tidak ada, yang terkecil.
String? _bestThumbnail(Map<String, dynamic>? node) {
  if (node == null) return null;
  final Map<String, dynamic> renderer =
      node['musicThumbnailRenderer'] as Map<String, dynamic>? ?? node;
  final Map<String, dynamic>? thumb =
      renderer['thumbnail'] as Map<String, dynamic>?;
  final List<dynamic>? thumbnails = thumb?['thumbnails'] as List<dynamic>?;
  if (thumbnails == null || thumbnails.isEmpty) return null;
  String? bestUrl;
  int bestWidth = -1;
  String? smallestUrl;
  int smallestWidth = 1 << 30;
  for (final dynamic raw in thumbnails) {
    if (raw is! Map<String, dynamic>) continue;
    final String? url = raw['url'] as String?;
    if (url == null || url.isEmpty) continue;
    final int width = _asInt(raw['width']) ?? 0;
    if (width < smallestWidth) {
      smallestWidth = width;
      smallestUrl = url;
    }
    if (width <= 544 && width > bestWidth) {
      bestWidth = width;
      bestUrl = url;
    }
  }
  return bestUrl ?? smallestUrl;
}

int? _asInt(Object? value) {
  if (value == null) return null;
  if (value is int) return value;
  if (value is String) return int.tryParse(value);
  if (value is double) return value.toInt();
  return null;
}

/// Durasi dari teks "m:ss" atau "h:mm:ss"; null bila bukan durasi.
int? _parseDuration(String text) {
  final String trimmed = text.trim();
  final RegExpMatch? match = RegExp(r'^(\d+):(\d{2})(?::(\d{2}))?$')
      .firstMatch(trimmed);
  if (match == null) return null;
  final int first = int.parse(match.group(1)!);
  final int second = int.parse(match.group(2)!);
  final String? third = match.group(3);
  if (third == null) return first * 60 + second;
  return first * 3600 + second * 60 + int.parse(third);
}

/// Teks semua kolom fleksibel satu baris daftar, sesuai urutan.
List<String> _flexTexts(Map<String, dynamic> item) {
  final List<dynamic>? columns = item['flexColumns'] as List<dynamic>?;
  if (columns == null) return const <String>[];
  final List<String> out = <String>[];
  for (final dynamic raw in columns) {
    if (raw is! Map<String, dynamic>) continue;
    final Map<String, dynamic>? column =
        raw['musicResponsiveListItemFlexColumnRenderer']
            as Map<String, dynamic>?;
    if (column == null) continue;
    out.add(_runsText(column['text']));
  }
  return out;
}

/// Semua run teks di semua kolom fleksibel + kolom tetap satu baris.
List<Map<String, dynamic>> _allItemRuns(Map<String, dynamic> item) {
  final List<Map<String, dynamic>> out = <Map<String, dynamic>>[];
  final List<dynamic>? columns = item['flexColumns'] as List<dynamic>?;
  if (columns != null) {
    for (final dynamic raw in columns) {
      if (raw is! Map<String, dynamic>) continue;
      final Map<String, dynamic>? column =
          raw['musicResponsiveListItemFlexColumnRenderer']
              as Map<String, dynamic>?;
      if (column == null) continue;
      out.addAll(_runsOf(column['text'] as Map<String, dynamic>?));
    }
  }
  final List<dynamic>? fixed = item['fixedColumns'] as List<dynamic>?;
  if (fixed != null) {
    for (final dynamic raw in fixed) {
      if (raw is! Map<String, dynamic>) continue;
      final Map<String, dynamic>? column =
          raw['musicResponsiveListItemFixedColumnRenderer']
              as Map<String, dynamic>?;
      if (column == null) continue;
      out.addAll(_runsOf(column['text'] as Map<String, dynamic>?));
    }
  }
  return out;
}

Map<String, dynamic>? _runBrowseEndpoint(Map<String, dynamic> run) {
  final Map<String, dynamic>? endpoint =
      run['navigationEndpoint'] as Map<String, dynamic>?;
  return endpoint?['browseEndpoint'] as Map<String, dynamic>?;
}

String? _browsePageType(Map<String, dynamic>? browseEndpoint) {
  final Map<String, dynamic>? configs =
      browseEndpoint?['browseEndpointContextSupportedConfigs']
          as Map<String, dynamic>?;
  final Map<String, dynamic>? musicConfig =
      configs?['browseEndpointContextMusicConfig'] as Map<String, dynamic>?;
  return musicConfig?['pageType'] as String?;
}

/// videoId satu baris daftar: dari `playlistItemData`, overlay tombol
/// putar, atau navigationEndpoint-nya sendiri.
String? _itemVideoId(Map<String, dynamic> item) {
  final Map<String, dynamic>? playlistData =
      item['playlistItemData'] as Map<String, dynamic>?;
  final String? fromData = playlistData?['videoId'] as String?;
  if (fromData != null && fromData.isNotEmpty) return fromData;
  final Map<String, dynamic>? overlay =
      item['overlay'] as Map<String, dynamic>?;
  final Map<String, dynamic>? overlayContent =
      overlay?['musicItemThumbnailOverlayRenderer'] as Map<String, dynamic>?;
  final Map<String, dynamic>? content =
      overlayContent?['content'] as Map<String, dynamic>?;
  final Map<String, dynamic>? playButton =
      content?['musicPlayButtonRenderer'] as Map<String, dynamic>?;
  final Map<String, dynamic>? playEndpoint =
      playButton?['playNavigationEndpoint'] as Map<String, dynamic>?;
  final Map<String, dynamic>? watch =
      playEndpoint?['watchEndpoint'] as Map<String, dynamic>?;
  final String? fromOverlay = watch?['videoId'] as String?;
  if (fromOverlay != null && fromOverlay.isNotEmpty) return fromOverlay;
  final Map<String, dynamic>? endpoint =
      item['navigationEndpoint'] as Map<String, dynamic>?;
  final Map<String, dynamic>? watchEndpoint =
      endpoint?['watchEndpoint'] as Map<String, dynamic>?;
  final String? fromNav = watchEndpoint?['videoId'] as String?;
  if (fromNav != null && fromNav.isNotEmpty) return fromNav;
  return null;
}

Map<String, dynamic>? _itemBrowseEndpoint(Map<String, dynamic> item) {
  final Map<String, dynamic>? endpoint =
      item['navigationEndpoint'] as Map<String, dynamic>?;
  return endpoint?['browseEndpoint'] as Map<String, dynamic>?;
}

/// Durasi satu baris daftar: kolom tetap dulu, lalu run mana pun yang
/// berbentuk durasi.
int? _durationFromItem(Map<String, dynamic> item) {
  final List<dynamic>? fixed = item['fixedColumns'] as List<dynamic>?;
  if (fixed != null) {
    for (final dynamic raw in fixed) {
      if (raw is! Map<String, dynamic>) continue;
      final Map<String, dynamic>? column =
          raw['musicResponsiveListItemFixedColumnRenderer']
              as Map<String, dynamic>?;
      if (column == null) continue;
      final int? duration = _parseDuration(_runsText(column['text']));
      if (duration != null) return duration;
    }
  }
  for (final Map<String, dynamic> run in _allItemRuns(item)) {
    final int? duration = _parseDuration(run['text'] as String? ?? '');
    if (duration != null) return duration;
  }
  return null;
}

/// Artis + album dari run-run satu baris daftar.
///
/// Run yang membawa browseEndpoint bertipe ARTIST/ALBUM memberi nama
/// sekaligus id-nya. Bila tidak ada run ber-id artis, nama artis diambil
/// dari segmen subjudul setelah kata tipe ("Song • Nama Artis").
class _ArtistAlbum {
  const _ArtistAlbum({
    this.artist,
    this.artistChannelId,
    this.album,
    this.albumBrowseId,
  });

  final String? artist;
  final String? artistChannelId;
  final String? album;
  final String? albumBrowseId;
}

_ArtistAlbum _artistAlbumFromItem(Map<String, dynamic> item, String subtitle) {
  final List<String> artistNames = <String>[];
  String? artistChannelId;
  String? album;
  String? albumBrowseId;
  for (final Map<String, dynamic> run in _allItemRuns(item)) {
    final String text = run['text'] as String? ?? '';
    if (text.isEmpty) continue;
    final Map<String, dynamic>? browse = _runBrowseEndpoint(run);
    final String? pageType = _browsePageType(browse);
    if (pageType == 'MUSIC_PAGE_TYPE_ARTIST') {
      if (!artistNames.contains(text)) artistNames.add(text);
      artistChannelId ??= browse?['browseId'] as String?;
    } else if (pageType == 'MUSIC_PAGE_TYPE_ALBUM') {
      album ??= text;
      albumBrowseId ??= browse?['browseId'] as String?;
    }
  }
  String? artist;
  if (artistNames.isNotEmpty) {
    artist = artistNames.join(', ');
  } else {
    // Cadangan: segmen kedua subjudul ("Song • Artis • Album").
    final List<String> parts = subtitle
        .split('•')
        .map((String s) => s.trim())
        .where((String s) => s.isNotEmpty)
        .toList(growable: false);
    if (parts.length > 1) {
      artist = parts[1];
      // Segmen ketiga bisa jadi album ("Song • Artis • Album • 3:24")
      // — tapi bisa juga jumlah putar; album hanya diambil bila
      // segmen itu bukan angka/jumlah dan bukan durasi.
      if (parts.length > 2 && album == null) {
        final String candidate = parts[2];
        if (_parseDuration(candidate) == null &&
            !RegExp(r'^\d').hasMatch(candidate) &&
            !candidate.toLowerCase().contains('plays') &&
            !candidate.toLowerCase().contains('views') &&
            !candidate.toLowerCase().contains('subscribers')) {
          album = candidate;
        }
      }
    }
  }
  return _ArtistAlbum(
    artist: artist,
    artistChannelId: artistChannelId,
    album: album,
    albumBrowseId: albumBrowseId,
  );
}

/// Pisahkan nama-nama artis ("A, B & C" menjadi [A, B, C]).
List<String> _splitNames(String text) {
  return text
      .split(RegExp(r'\s*(?:,|&)\s*'))
      .map((String s) => s.trim())
      .where((String s) => s.isNotEmpty)
      .toList(growable: false);
}

/// Token continuation dari satu sectionListRenderer, bila ada.
String? _continuationToken(Map<String, dynamic>? sectionList) {
  final List<dynamic>? continuations =
      sectionList?['continuations'] as List<dynamic>?;
  if (continuations == null || continuations.isEmpty) return null;
  final Map<String, dynamic>? first =
      continuations.first as Map<String, dynamic>?;
  final Map<String, dynamic>? data =
      first?['nextContinuationData'] as Map<String, dynamic>?;
  final String? token = data?['continuation'] as String?;
  if (token == null || token.isEmpty) return null;
  return token;
}
