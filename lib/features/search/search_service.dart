/// Layanan pencarian dan browse: menggabungkan hasil lokal (FTS5) dan
/// online (InnerTube), riwayat pencarian, saran, dan halaman Jelajah.
///
/// Aturan yang mengikat (PRD B1):
/// - Pencarian jaringan HANYA saat kueri dikirim eksplisit. Saran saat
///   mengetik memakai endpoint suggest (debounce 300 ms di UI) dan
///   riwayat lokal sebagai cadangan.
/// - Hasil lokal tampil sebelum hasil online, di tab yang sama.
/// - Query yang gagal total karena jaringan TIDAK masuk riwayat; query
///   yang berhasil (walau hasilnya kosong) masuk riwayat.
/// - Kegagalan saran hilang diam-diam; kegagalan pencarian online tidak
///   menghapus hasil lokal.
///
/// [OnlineSearchApi] adalah seam untuk tes: produksi memakai
/// [InnertubeSearchApi] (fallback WEB_REMIX lalu MWEB), tes memakai
/// fake tanpa jaringan.
library;

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:laras/data/database.dart';
import 'package:laras/extractor/extractor.dart';
import 'package:laras/player/track.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// browseId beranda YouTube Music (rak Jelajah).
const String kBrowseHomeId = 'FEmusic_home';

/// browseId tangga lagu YouTube Music.
const String kBrowseChartsId = 'FEmusic_charts';

/// browseId rilisan baru YouTube Music.
const String kBrowseNewReleasesId = 'FEmusic_new_releases';

/// browseId mood dan genre YouTube Music.
const String kBrowseMoodsId = 'FEmusic_moods_and_genres';

/// Batas hasil lokal yang tampil di tab Cari (PRD B1.4: 10 per kelompok
/// di layar hasil; daftar penuh lewat "Lihat semua").
const int kSearchLocalLimit = 10;

/// Batas hasil online per kelompok di layar hasil (PRD B1.1).
const int kSearchOnlineGroupLimit = 10;

/// Jeda muat ulang otomatis seksi Jelajah (PRD B6.4, selaras TTL config).
const Duration kBrowseRefreshInterval = Duration(hours: 6);

/// Kegagalan pencarian/browse online, untuk pemilihan pesan ke pengguna.
enum OnlineFailure {
  /// Tidak ada jaringan (timeout, DNS, koneksi putus).
  network,

  /// Server menjawab tapi gagal (403, respons kosong, error lain).
  server,

  /// Respons tidak bisa di-parse (YouTube mengubah bentuk respons).
  parse,
}

/// Hasil satu pencarian online: kelompok hasil atau kegagalan.
class OnlineSearchOutcome {
  const OnlineSearchOutcome({this.grouped, this.failure});

  final GroupedSearchResults? grouped;
  final OnlineFailure? failure;

  bool get isSuccess => grouped != null;
}

/// Hasil gabungan satu pencarian: lokal + online.
class CombinedSearch {
  const CombinedSearch({
    this.local = const LocalSearchResults(),
    this.online,
    this.failure,
  });

  /// Hasil dari database lokal (FTS5), tampil pertama.
  final LocalSearchResults local;

  /// Hasil dari YouTube Music, atau null bila pencarian online gagal.
  final GroupedSearchResults? online;

  /// Kegagalan online, atau null bila online berhasil.
  final OnlineFailure? failure;

  bool get isEmpty => local.isEmpty && (online == null || online!.isEmpty);
}

/// Hasil satu pemuatan halaman browse.
class BrowseOutcome {
  const BrowseOutcome({this.page, this.failure, this.fromCache = false});

  final BrowsePage? page;
  final OnlineFailure? failure;

  /// Benar bila [page] adalah data terakhir yang tersimpan (muat ulang
  /// gagal, PRD B6.4: "Gagal memperbarui. Menampilkan data terakhir.").
  final bool fromCache;

  bool get isSuccess => page != null;
}

/// Jalur online pencarian/browse (InnerTube), dengan fallback antar client.
abstract class OnlineSearchApi {
  Future<GroupedSearchResults> search(String query, {String? params});

  Future<BrowsePage> browse(String browseId, {String? params});

  Future<List<String>> suggest(String input);
}

/// Implementasi [OnlineSearchApi] di atas [InnertubeClient].
///
/// Tiap panggilan mencoba client sesuai urutan fallback bawaan
/// (WEB_REMIX lalu MWEB). Kegagalan jaringan langsung dilempar (client
/// lain tidak akan membantu); kegagalan lain mencoba client berikut.
class InnertubeSearchApi implements OnlineSearchApi {
  InnertubeSearchApi({InnertubeClient? client})
    : _client = client ?? InnertubeClient();

  final InnertubeClient _client;

  @override
  Future<GroupedSearchResults> search(String query, {String? params}) async {
    final SearchResult result = await _withFallback(
      (ClientDefinition client) =>
          _client.search(query, client, params: params),
    );
    return result.grouped;
  }

  @override
  Future<BrowsePage> browse(String browseId, {String? params}) async {
    return _withFallback(
      (ClientDefinition client) =>
          _client.browse(browseId, client, params: params),
    );
  }

  @override
  Future<List<String>> suggest(String input) async {
    return _withFallback(
      (ClientDefinition client) => _client.fetchSuggestions(input, client),
    );
  }

  Future<T> _withFallback<T>(
    Future<T> Function(ClientDefinition client) call,
  ) async {
    ExtractorException? lastError;
    for (final ClientDefinition client in kDefaultClientFallbackOrder) {
      try {
        return await call(client);
      } on ExtractorException catch (e) {
        if (e.isNetworkError) rethrow;
        lastError = e;
      }
    }
    throw lastError ??
        const ExtractorException(
          ResolveFailureCause.emptyResponse,
          detail: 'tidak ada client yang bisa dipakai',
        );
  }
}

/// Layanan pencarian: satu pintu UI ke pencarian lokal + online,
/// riwayat, saran, dan browse.
class SearchService {
  SearchService({required this.api, this.library, this.prefs});

  final OnlineSearchApi api;

  /// Library lokal; null bila database gagal dibuka (app tetap jalan
  /// tanpa hasil lokal dan riwayat).
  final LibraryService? library;

  /// Preferensi untuk cap waktu muat Jelajah; null berarti cap waktu
  /// hanya hidup di memori sesi.
  final SharedPreferences? prefs;

  static const String _homeFetchedAtKey = 'laras.browse.homeFetchedAt';

  BrowsePage? _cachedHome;
  DateTime? _homeFetchedAt;

  /// Cari [query] di lokal dan online sekaligus.
  ///
  /// Hasil lokal selalu dicoba dulu dan tidak pernah gagal total
  /// (bila database bermasalah, hasilnya kosong). Pencarian online
  /// yang gagal mengembalikan [CombinedSearch.failure] tanpa
  /// menghilangkan hasil lokal. Query dicatat ke riwayat hanya bila
  /// pencarian online BERHASIL (PRD B1.3).
  Future<CombinedSearch> search(String query, {String? params}) async {
    final String trimmed = query.trim();
    if (trimmed.isEmpty) return const CombinedSearch();
    final LibraryService? library = this.library;
    final LocalSearchResults local = library == null
        ? const LocalSearchResults()
        : await _safeLocalSearch(library, trimmed);
    try {
      final GroupedSearchResults grouped = await api.search(
        trimmed,
        params: params,
      );
      // Gabungkan artis pseudo-id ke channelId di latar (tidak
      // memblokir hasil): data pencarian memberi channelId asli.
      unawaited(_mergeArtistsFromResults(grouped));
      // R2-L1: pencatatan riwayat adalah efek samping — kegagalan
      // database di sini tidak boleh membuang hasil pencarian yang
      // sudah berhasil (dan tidak boleh lolos ke UI sebagai error
      // yang membuat layar macet di loading).
      if (library != null) {
        try {
          await library.addSearchQuery(trimmed);
        } catch (_) {
          // Riwayat gagal dicatat: hasil tetap tampil.
        }
      }
      return CombinedSearch(local: local, online: grouped);
    } on ExtractorException catch (e) {
      return CombinedSearch(local: local, failure: _classify(e));
    } on Object catch (_) {
      // R2-L1: error non-parser (mis. error tak terduga di API) tidak
      // boleh lolos ke `_submit` — layar akan macet di loading bila
      // `_loading` tidak pernah kembali false. Petakan ke kegagalan
      // server supaya UI menampilkan pesan + tombol coba lagi.
      return CombinedSearch(local: local, failure: OnlineFailure.server);
    }
  }

  /// Cari lokal saja (dipakai layar "Lihat semua" kelompok lokal).
  Future<LocalSearchResults> searchLocalOnly(
    String query, {
    int limit = kPageSize,
  }) async {
    final LibraryService? library = this.library;
    if (library == null) return const LocalSearchResults();
    return _safeLocalSearch(library, query.trim(), limit: limit);
  }

  /// Saran pencarian untuk [input] yang sedang diketik.
  ///
  /// Saran jaringan dulu (maks 8); bila gagal atau kosong, saran dari
  /// riwayat lokal yang cocok awalan. Kegagalan di sini tidak pernah
  /// melempar — hasilnya hanya kosong.
  Future<List<String>> suggestions(String input) async {
    final String trimmed = input.trim();
    if (trimmed.isEmpty) return const <String>[];
    try {
      final List<String> online = await api.suggest(trimmed);
      final List<String> filtered = online
          .where((String s) => s.toLowerCase() != trimmed.toLowerCase())
          .toList(growable: false);
      if (filtered.isNotEmpty) return filtered;
    } on ExtractorException {
      // Saran jaringan gagal: lanjut ke riwayat lokal (diam-diam).
    }
    final LibraryService? library = this.library;
    if (library == null) return const <String>[];
    try {
      return await library.searchHistoryMatching(trimmed);
    } catch (_) {
      return const <String>[];
    }
  }

  /// Catat [query] ke riwayat (dipakai mode "Library saja", yang tidak
  /// lewat [search] sehingga tidak tercatat otomatis).
  Future<void> recordSearchQuery(String query) async {
    await library?.addSearchQuery(query);
  }

  /// Riwayat pencarian terbaru dulu.
  Future<List<String>> recentSearches({int limit = 10}) async {
    final LibraryService? library = this.library;
    if (library == null) return const <String>[];
    return library.recentSearches(limit: limit);
  }

  /// Hapus satu query dari riwayat.
  Future<void> deleteSearchQuery(String query) async {
    await library?.deleteSearchQuery(query);
  }

  /// Hapus seluruh riwayat pencarian.
  Future<void> clearSearchHistory() async {
    await library?.clearSearchHistory();
  }

  /// Kembalikan satu query ke riwayat (tombol "Urungkan" setelah hapus).
  Future<void> restoreSearchQuery(String query) async {
    await library?.addSearchQuery(query);
  }

  /// Muat halaman browse (artis, album, playlist, kategori).
  Future<BrowseOutcome> browse(String browseId, {String? params}) async {
    try {
      final BrowsePage page = await api.browse(browseId, params: params);
      return BrowseOutcome(page: page);
    } on ExtractorException catch (e) {
      return BrowseOutcome(failure: _classify(e));
    } on Object catch (_) {
      // R2-L1: sama seperti search — error tak terduga dipetakan ke
      // kegagalan server, bukan dilempar ke FutureBuilder (yang tanpa
      // cabang hasError akan menampilkan shimmer selamanya).
      return const BrowseOutcome(failure: OnlineFailure.server);
    }
  }

  /// Muat rak Jelajah beranda (FEmusic_home), dengan cache 6 jam.
  ///
  /// Bila data terakhir masih segar dan [forceRefresh] salah, data
  /// cache dipakai tanpa request. Bila muat ulang gagal tapi ada data
  /// cache, data cache dikembalikan dengan [BrowseOutcome.fromCache]
  /// benar (PRD B6.4).
  Future<BrowseOutcome> browseHome({bool forceRefresh = false}) async {
    final BrowsePage? cached = _cachedHome;
    final DateTime? fetchedAt = _homeFetchedAt ?? _readHomeFetchedAt();
    final bool fresh =
        cached != null &&
        fetchedAt != null &&
        DateTime.now().difference(fetchedAt) < kBrowseRefreshInterval;
    if (fresh && !forceRefresh) {
      return BrowseOutcome(page: cached);
    }
    try {
      final BrowsePage page = await api.browse(kBrowseHomeId);
      _cachedHome = page;
      _homeFetchedAt = DateTime.now();
      await prefs?.setInt(
        _homeFetchedAtKey,
        _homeFetchedAt!.millisecondsSinceEpoch,
      );
      return BrowseOutcome(page: page);
    } on ExtractorException catch (e) {
      if (cached != null) {
        return BrowseOutcome(
          page: cached,
          failure: _classify(e),
          fromCache: true,
        );
      }
      return BrowseOutcome(failure: _classify(e));
    } on Object catch (_) {
      // R2-L1: sama seperti browse — error tak terduga dipetakan ke
      // kegagalan server (dengan data terakhir bila ada).
      if (cached != null) {
        return BrowseOutcome(
          page: cached,
          failure: OnlineFailure.server,
          fromCache: true,
        );
      }
      return const BrowseOutcome(failure: OnlineFailure.server);
    }
  }

  DateTime? _readHomeFetchedAt() {
    final int? ms = prefs?.getInt(_homeFetchedAtKey);
    if (ms == null) return null;
    _homeFetchedAt = DateTime.fromMillisecondsSinceEpoch(ms);
    return _homeFetchedAt;
  }

  Future<LocalSearchResults> _safeLocalSearch(
    LibraryService library,
    String query, {
    int limit = kSearchLocalLimit,
  }) async {
    try {
      return await library.searchLocal(query, limit: limit);
    } catch (error) {
      debugPrint('SearchService: pencarian lokal gagal: $error');
      return const LocalSearchResults();
    }
  }

  /// Gabungkan artis pseudo-id ke channelId untuk tiap lagu hasil
  /// pencarian yang membawa keduanya. Kegagalan database di sini tidak
  /// mengganggu hasil pencarian.
  Future<void> _mergeArtistsFromResults(GroupedSearchResults grouped) async {
    final LibraryService? library = this.library;
    if (library == null) return;
    final Map<String, String> byName = <String, String>{};
    for (final SearchSong song in grouped.songs) {
      final String? artist = song.artist?.trim();
      final String? channelId = song.artistChannelId?.trim();
      if (artist != null &&
          artist.isNotEmpty &&
          channelId != null &&
          channelId.isNotEmpty) {
        byName[artist] = channelId;
      }
    }
    for (final SearchArtist artist in grouped.artists) {
      byName[artist.name] = artist.channelId;
    }
    for (final MapEntry<String, String> entry in byName.entries) {
      try {
        await library.mergeArtistChannel(
          name: entry.key,
          channelId: entry.value,
        );
      } catch (error) {
        debugPrint('SearchService: gabung artis gagal: $error');
      }
    }
  }

  OnlineFailure _classify(ExtractorException e) {
    if (e.isNetworkError) return OnlineFailure.network;
    if (e.cause == ResolveFailureCause.parseFailed) {
      return OnlineFailure.parse;
    }
    return OnlineFailure.server;
  }
}

/// Keterangan tampil album hasil pencarian: artis + tahun
/// (mis. "Peterpan • 2008"), atau null bila tidak ada keduanya.
extension SearchAlbumDisplay on SearchAlbum {
  String? get displaySubtitle {
    final List<String> parts = <String>[...artists, if (year != null) '$year'];
    if (parts.isEmpty) return null;
    return parts.join(' • ');
  }
}

/// Lagu hasil pencarian menjadi lagu pemutar (album + channelId ikut).
extension SearchSongTrack on SearchSong {
  Track toTrack() {
    final String? thumb = thumbnailUrl;
    return Track(
      videoId: videoId,
      title: title,
      artist: artist,
      artistChannelId: artistChannelId,
      album: album,
      albumBrowseId: albumBrowseId,
      duration: durationSeconds == null
          ? null
          : Duration(seconds: durationSeconds!),
      artUri: thumb == null || thumb.isEmpty ? null : Uri.tryParse(thumb),
    );
  }
}

/// Item lagu browse menjadi lagu pemutar.
extension BrowseItemTrack on BrowseItem {
  Track toTrack() {
    final String? thumb = thumbnailUrl;
    return Track(
      videoId: videoId ?? '',
      title: title,
      artist: artist,
      artistChannelId: artistChannelId,
      album: album,
      albumBrowseId: albumBrowseId,
      duration: durationSeconds == null
          ? null
          : Duration(seconds: durationSeconds!),
      artUri: thumb == null || thumb.isEmpty ? null : Uri.tryParse(thumb),
    );
  }
}
