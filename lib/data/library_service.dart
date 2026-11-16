/// Layanan library: satu-satunya jalan widget ke database.
///
/// Semua baca-tulis library (lagu, album, artis, playlist, favorit,
/// riwayat putar, riwayat pencarian, antrean, pencarian lokal FTS5)
/// lewat kelas ini. Widget tidak pernah menyentuh drift langsung.
///
/// Aturan yang mengikat di sini:
/// - Drift menyimpan DateTime sebagai DETIK Unix (bukan milidetik):
///   dua tulis dalam satu detik yang sama punya cap waktu yang sama.
///   Karena itu semua urutan berbasis waktu memakai tiebreak
///   deterministik (id atau rowid), dan perbandingan waktu absolut di
///   SQL kustom wajib memakai detik.
/// - Semua daftar memakai pagination keyset 50 per halaman (PRD B4.4):
///   halaman berikut diminta dengan item terakhir halaman sebelumnya,
///   bukan nomor halaman, supaya sisipan di tengah tidak menggeser isi.
/// - Lagu masuk Library saat difavoritkan, ditambahkan ke playlist, atau
///   diunduh. Sekadar diputar tidak memasukkan lagu ke Library.
/// - Baris FTS ditulis dalam transaksi yang sama dengan baris aslinya.
/// - Koleksi yang tumbuh otomatis dibatasi kode: riwayat putar 10.000
///   entri, riwayat pencarian 100 query (PRD B4.6, A5 bagian 8).
library;

import 'package:drift/drift.dart';
import 'package:drift/extensions/fts5.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'laras_database.dart';
import 'tables.dart';

/// Ukuran halaman standar semua daftar (keputusan koordinator, arsitektur
/// bagian 7 butir 9).
const int kPageSize = 50;

/// Batas riwayat putar (PRD B4.6). Entri tertua dihapus otomatis.
const int kMaxPlayEvents = 10000;

/// Batas riwayat pencarian (PRD B4.6 / A5). Query terlama dihapus otomatis.
const int kMaxSearchHistory = 100;

/// Batas nama playlist (PRD B4.1).
const int kMaxPlaylistNameLength = 100;

/// Batas deskripsi playlist (PRD B4.1).
const int kMaxPlaylistDescriptionLength = 500;

/// Ambang pencatatan play event (PRD B2.7): lagu dicatat ke riwayat bila
/// diputar lebih dari 10 detik, atau sampai selesai. Ambang ini berbeda
/// dari ambang 30 detik "putaran bermakna" untuk rekomendasi (PRD B4.6).
const int kMinPlayEventMs = 10000;

/// Durasi "putaran bermakna" (PRD B4.6): dipakai rumus "Lagu untukmu" P4.
const int kMeaningfulPlayMs = 30000;

/// Urutan daftar lagu.
enum SongSort {
  /// Terbaru ditambahkan dulu.
  newest,

  /// Nama A-Z.
  byName,

  /// Total waktu putar terbanyak dulu.
  mostPlayed,
}

/// Satu lagu beserta nama-nama artisnya, siap tampil di satu baris daftar.
class SongView {
  const SongView({required this.song, this.artistNames = const <String>[]});

  final Song song;

  /// Nama artis sesuai urutan di lagu (artis utama dulu).
  final List<String> artistNames;

  /// Nama artis digabung koma, atau string kosong bila tidak ada artis.
  String get artistsLabel => artistNames.join(', ');

  String get id => song.id;
}

/// Satu lagu di dalam playlist, beserta posisinya.
class PlaylistSongEntry {
  const PlaylistSongEntry({
    required this.song,
    required this.position,
    required this.dateAdded,
  });

  final SongView song;
  final int position;
  final DateTime dateAdded;
}

/// Satu entri riwayat putar: sesi putar beserta lagunya.
class PlayHistoryEntry {
  const PlayHistoryEntry({required this.event, required this.song});

  final PlayEvent event;
  final SongView song;
}

/// Artis beserta jumlah lagu Library-nya.
class ArtistWithCount {
  const ArtistWithCount({required this.artist, required this.songCount});

  final Artist artist;
  final int songCount;
}

/// Album beserta jumlah lagu Library-nya.
class AlbumWithCount {
  const AlbumWithCount({required this.album, required this.songCount});

  final Album album;
  final int songCount;
}

/// Playlist beserta jumlah lagunya.
class PlaylistWithCount {
  const PlaylistWithCount({required this.playlist, required this.songCount});

  final Playlist playlist;
  final int songCount;
}

/// Hitungan isi library, untuk keputusan empty state.
class LibraryCounts {
  const LibraryCounts({
    required this.songs,
    required this.artists,
    required this.albums,
    required this.playlists,
    required this.favorites,
    required this.historyEntries,
  });

  final int songs;
  final int artists;
  final int albums;
  final int playlists;
  final int favorites;
  final int historyEntries;

  bool get isEmpty =>
      songs == 0 &&
      artists == 0 &&
      albums == 0 &&
      playlists == 0 &&
      favorites == 0 &&
      historyEntries == 0;
}

/// Satu file unduhan (ringan, untuk rekonsiliasi P5): tanpa nama artis
/// atau metadata lain, supaya pemindaian 10.000 lagu tidak memuat
/// seluruh SongView ke memori.
class DownloadedFileInfo {
  const DownloadedFileInfo({
    required this.songId,
    required this.filePath,
    required this.fileSizeBytes,
  });

  final String songId;

  /// Path relatif terhadap direktori unduhan (atau null bila rusak).
  final String? filePath;

  /// Ukuran yang tercatat saat unduhan selesai (atau null bila rusak).
  final int? fileSizeBytes;
}

/// Hitungan penyimpanan dari database (bukan pemindaian filesystem,
/// PRD B3.3): unduhan dan ruang lagu yang pernah diputar.
class StorageStats {
  const StorageStats({
    required this.downloadCount,
    required this.downloadBytes,
    required this.playedSongsCount,
    required this.playedSongsBytes,
  });

  const StorageStats.empty()
    : downloadCount = 0,
      downloadBytes = 0,
      playedSongsCount = 0,
      playedSongsBytes = 0;

  /// Jumlah lagu terunduh.
  final int downloadCount;

  /// Total byte file unduhan.
  final int downloadBytes;

  /// Jumlah entri cache streaming.
  final int playedSongsCount;

  /// Total byte cache streaming.
  final int playedSongsBytes;
}

/// Hasil pencarian lokal: lagu dan artis yang cocok, masing-masing
/// terurut relevansi bm25 (paling relevan dulu).
class LocalSearchResults {
  const LocalSearchResults({
    this.songs = const <SongView>[],
    this.artists = const <Artist>[],
  });

  final List<SongView> songs;
  final List<Artist> artists;

  bool get isEmpty => songs.isEmpty && artists.isEmpty;
}

/// Satu lagu untuk impor massal (dipakai tes performa dan impor P8).
class SongImport {
  const SongImport({
    required this.song,
    this.artistNames = const <String>[],
    this.album,
  });

  /// Companion lagu. Kolom yang tidak diisi (liked, total waktu putar,
  /// status unduhan) dipertahankan bila lagu sudah ada.
  final SongsCompanion song;

  final List<String> artistNames;

  /// Album pemilik lagu, bila diketahui.
  final AlbumsCompanion? album;
}

/// Id semu artis dari nama, dipakai saat channelId YTM belum diketahui.
///
/// Pemutar hanya membawa nama artis (tanpa channelId), sementara tabel
/// artists memakai channelId sebagai id. Id semu ini deterministik dari
/// nama (FNV-1a 64 bit atas nama huruf kecil), jadi nama yang sama selalu
/// memetakan ke artis yang sama. P4 menggabungkan id semu ke channelId
/// asli saat data YTM tersedia. Tabrakan hash dua nama berbeda secara
/// praktis tidak terjadi pada skala ini, dan bila terjadi kedua artis
/// tampil sebagai satu artis dengan nama yang pertama tercatat.
String localArtistIdForName(String name) {
  final String normalized = name.trim().toLowerCase();
  int hash = 0xcbf29ce484222325;
  for (final int unit in normalized.codeUnits) {
    hash ^= unit;
    hash = (hash * 0x100000001b3) & 0xFFFFFFFFFFFFFFFF;
  }
  return 'local-${hash.toRadixString(16).padLeft(16, '0')}';
}

/// Preferensi sortir daftar lagu, disimpan di SharedPreferences.
///
/// Nilai yang disimpan hanya nama enum (string pendek), sesuai aturan
/// shared_preferences hanya untuk nilai primitif kecil. Bila [prefs]
/// null (mis. tes tanpa prefs), pilihan hidup di memori sesi saja.
class LibrarySortPrefs {
  LibrarySortPrefs({this.prefs});

  static const String _songsKey = 'laras.sort.songs';

  final SharedPreferences? prefs;
  SongSort _memory = SongSort.newest;

  SongSort get songSort {
    final SharedPreferences? prefs = this.prefs;
    if (prefs == null) return _memory;
    final String? raw = prefs.getString(_songsKey);
    if (raw == null) return SongSort.newest;
    for (final SongSort sort in SongSort.values) {
      if (sort.name == raw) return sort;
    }
    return SongSort.newest;
  }

  set songSort(SongSort sort) {
    _memory = sort;
    prefs?.setString(_songsKey, sort.name);
  }
}

/// Layanan library. Dibuat sekali di `main()` dari database yang sudah
/// dibuka, lalu dibagikan lewat [LibraryScope].
class LibraryService {
  LibraryService(this.db, {LibrarySortPrefs? sortPrefs})
    : sortPrefs = sortPrefs ?? LibrarySortPrefs();

  final LarasDatabase db;

  /// Preferensi sortir daftar lagu (tersimpan di SharedPreferences bila
  /// [LibrarySortPrefs] dibuat dengan prefs, di memori bila tidak).
  final LibrarySortPrefs sortPrefs;

  /// Stream yang memberi sinyal setiap kali tabel library berubah.
  /// Layar memakai ini untuk memuat ulang halaman yang sedang tampil.
  Stream<void> get libraryChanged =>
      db.tableUpdates().map((Set<TableUpdate> _) {});

  // ------------------------------------------------------------------
  // Lagu
  // ------------------------------------------------------------------

  /// Simpan atau perbarui satu lagu beserta artis dan albumnya.
  ///
  /// Lagu yang sudah ada hanya diperbarui metadata-nya (judul, album,
  /// durasi, sampul, tanggal ubah); favorit, total waktu putar, status
  /// unduhan, dan tanggal tambah dipertahankan. Pemetaan artis ditulis
  /// ulang sesuai [artistNames] (urutan = posisi). Baris FTS diperbarui
  /// dalam transaksi yang sama.
  ///
  /// [artistChannelIds] sejajar dengan [artistNames]: bila posisi ke-i
  /// membawa channelId YTM, artis itu disimpan dengan channelId tersebut
  /// (bukan id semu lokal). Bila daftar ini lebih pendek dari
  /// [artistNames], posisi yang tidak tercakup memakai id semu.
  ///
  /// [addToLibrary] benar berarti lagu masuk Library (`in_library = 1`).
  /// Lagu yang sudah di Library tetap di Library walau dipanggil dengan
  /// [addToLibrary] salah.
  Future<void> upsertSong(
    SongsCompanion song, {
    List<String> artistNames = const <String>[],
    List<String?> artistChannelIds = const <String?>[],
    AlbumsCompanion? album,
    bool addToLibrary = false,
  }) async {
    final DateTime now = DateTime.now();
    await db.transaction(() async {
      final String? albumId = await _upsertAlbum(album);
      final SongsCompanion withAlbum = albumId == null
          ? song
          : song.copyWith(albumId: Value<String?>(albumId));
      await _upsertSongRow(withAlbum, now: now, addToLibrary: addToLibrary);
      await _replaceSongArtists(
        withAlbum.id.value,
        artistNames,
        channelIds: artistChannelIds,
        now: now,
      );
      await _syncSongFts(
        withAlbum.id.value,
        title: withAlbum.title.value,
        artistNames: artistNames,
      );
    });
  }

  /// Impor massal: sama seperti [upsertSong] untuk tiap item, tapi dalam
  /// satu transaksi (dipakai tes performa dan impor backup P8).
  Future<void> importSongs(List<SongImport> items) async {
    if (items.isEmpty) return;
    final DateTime now = DateTime.now();
    await db.transaction(() async {
      for (final SongImport item in items) {
        final String? albumId = await _upsertAlbum(item.album);
        final SongsCompanion withAlbum = albumId == null
            ? item.song
            : item.song.copyWith(albumId: Value<String?>(albumId));
        await _upsertSongRow(withAlbum, now: now, addToLibrary: true);
        await _replaceSongArtists(
          withAlbum.id.value,
          item.artistNames,
          now: now,
        );
        await _syncSongFts(
          withAlbum.id.value,
          title: withAlbum.title.value,
          artistNames: item.artistNames,
        );
      }
    });
  }

  Future<String?> _upsertAlbum(AlbumsCompanion? album) async {
    if (album == null) return null;
    final String id = album.id.value;
    // Tanggal tambah wajib di kolom (NOT NULL): isi bila pemanggil tidak
    // membawanya, supaya insert tidak gagal.
    final AlbumsCompanion withDate = album.dateAdded.present
        ? album
        : album.copyWith(dateAdded: Value<DateTime>(DateTime.now()));
    await db.into(db.albums).insert(withDate, mode: InsertMode.insertOrIgnore);
    return id;
  }

  Future<void> _upsertSongRow(
    SongsCompanion song, {
    required DateTime now,
    required bool addToLibrary,
  }) async {
    final String id = song.id.value;
    final Song? existing = await (db.select(
      db.songs,
    )..where((Songs s) => s.id.equals(id))).getSingleOrNull();
    if (existing == null) {
      await db
          .into(db.songs)
          .insert(
            song.copyWith(
              inLibrary: Value<bool>(addToLibrary),
              dateAdded: Value<DateTime>(now),
              dateModified: Value<DateTime>(now),
            ),
          );
      return;
    }
    await (db.update(db.songs)..where((Songs s) => s.id.equals(id))).write(
      SongsCompanion(
        title: Value<String>(song.title.value),
        albumId: song.albumId,
        durationSeconds: song.durationSeconds,
        thumbnailUrl: song.thumbnailUrl,
        inLibrary: addToLibrary
            ? const Value<bool>(true)
            : const Value<bool>.absent(),
        dateModified: Value<DateTime>(now),
      ),
    );
  }

  Future<void> _replaceSongArtists(
    String songId,
    List<String> artistNames, {
    List<String?> channelIds = const <String?>[],
    required DateTime now,
  }) async {
    await (db.delete(
      db.songArtists,
    )..where((SongArtists m) => m.songId.equals(songId))).go();
    for (int i = 0; i < artistNames.length; i++) {
      final String name = artistNames[i].trim();
      if (name.isEmpty) continue;
      final String? channelId = i < channelIds.length
          ? channelIds[i]?.trim()
          : null;
      final String artistId = channelId != null && channelId.isNotEmpty
          ? channelId
          : localArtistIdForName(name);
      await db
          .into(db.artists)
          .insert(
            ArtistsCompanion.insert(id: artistId, name: name, dateAdded: now),
            mode: InsertMode.insertOrIgnore,
          );
      await db
          .into(db.songArtists)
          .insert(
            SongArtistsCompanion.insert(
              songId: songId,
              artistId: artistId,
              position: i,
            ),
          );
      await _syncArtistFts(artistId, name: name);
    }
  }

  Future<void> _syncSongFts(
    String songId, {
    required String title,
    required List<String> artistNames,
  }) async {
    final LibrarySearch fts = db.librarySearch;
    await (db.delete(fts)..where(
          (LibrarySearch f) => f.kind.equals('song') & f.refId.equals(songId),
        ))
        .go();
    await db
        .into(fts)
        .insert(
          LibrarySearchCompanion.insert(
            kind: 'song',
            refId: songId,
            title: title,
            names: artistNames.join(' '),
          ),
        );
  }

  Future<void> _syncArtistFts(String artistId, {required String name}) async {
    final LibrarySearch fts = db.librarySearch;
    await (db.delete(fts)..where(
          (LibrarySearch f) =>
              f.kind.equals('artist') & f.refId.equals(artistId),
        ))
        .go();
    await db
        .into(fts)
        .insert(
          LibrarySearchCompanion.insert(
            kind: 'artist',
            refId: artistId,
            title: name,
            names: '',
          ),
        );
  }

  /// Bangun ulang seluruh isi FTS dari tabel lagu dan artis.
  /// Dipakai setelah impor massal P8 bila indeks perlu diperbaiki.
  Future<void> rebuildFts() async {
    await db.transaction(() async {
      await db.delete(db.librarySearch).go();
      final List<Song> songs = await db.select(db.songs).get();
      for (final Song song in songs) {
        final SongView view = (await _attachArtists(<Song>[song])).single;
        await _syncSongFts(
          song.id,
          title: song.title,
          artistNames: view.artistNames,
        );
      }
      final List<Artist> artists = await db.select(db.artists).get();
      for (final Artist artist in artists) {
        await _syncArtistFts(artist.id, name: artist.name);
      }
    });
  }

  /// Satu lagu beserta artisnya, atau null bila belum dikenal app.
  Future<SongView?> songById(String id) async {
    final Song? song = await (db.select(
      db.songs,
    )..where((Songs s) => s.id.equals(id))).getSingleOrNull();
    if (song == null) return null;
    return (await _attachArtists(<Song>[song])).single;
  }

  /// Halaman lagu Library (hanya `in_library = 1`).
  ///
  /// [after] adalah item terakhir halaman sebelumnya; null berarti halaman
  /// pertama. Daftar kosong berarti tidak ada halaman berikut.
  Future<List<SongView>> songsPage({
    SongSort sort = SongSort.newest,
    SongView? after,
    int limit = kPageSize,
  }) async {
    final SimpleSelectStatement<Songs, Song> query = db.select(db.songs);
    switch (sort) {
      case SongSort.newest:
        query.where(
          (Songs s) => s.inLibrary.equals(true) & _newestCursor(s, after?.song),
        );
        query.orderBy(<OrderingTerm Function(Songs)>[
          (Songs s) =>
              OrderingTerm(expression: s.dateAdded, mode: OrderingMode.desc),
          (Songs s) => OrderingTerm(expression: s.id, mode: OrderingMode.desc),
        ]);
      case SongSort.byName:
        query.where(
          (Songs s) => s.inLibrary.equals(true) & _nameCursor(s, after?.song),
        );
        query.orderBy(<OrderingTerm Function(Songs)>[
          (Songs s) => OrderingTerm(expression: s.title.lower()),
          (Songs s) => OrderingTerm(expression: s.id),
        ]);
      case SongSort.mostPlayed:
        query.where(
          (Songs s) => s.inLibrary.equals(true) & _playedCursor(s, after?.song),
        );
        query.orderBy(<OrderingTerm Function(Songs)>[
          (Songs s) => OrderingTerm(
            expression: s.totalPlayTimeMs,
            mode: OrderingMode.desc,
          ),
          (Songs s) => OrderingTerm(expression: s.id, mode: OrderingMode.desc),
        ]);
    }
    query.limit(limit);
    return _attachArtists(await query.get());
  }

  /// Halaman lagu favorit (playlist virtual Favorit, PRD B4.1).
  Future<List<SongView>> favoriteSongsPage({
    SongView? after,
    int limit = kPageSize,
  }) async {
    final SimpleSelectStatement<Songs, Song> query = db.select(db.songs)
      ..where((Songs s) => s.liked.equals(true) & _newestCursor(s, after?.song))
      ..orderBy(<OrderingTerm Function(Songs)>[
        (Songs s) =>
            OrderingTerm(expression: s.dateAdded, mode: OrderingMode.desc),
        (Songs s) => OrderingTerm(expression: s.id, mode: OrderingMode.desc),
      ])
      ..limit(limit);
    return _attachArtists(await query.get());
  }

  /// Halaman lagu satu artis, urut nama.
  Future<List<SongView>> songsByArtistPage(
    String artistId, {
    SongView? after,
    int limit = kPageSize,
  }) async {
    final JoinedSelectStatement<HasResultSet, dynamic> query =
        db.select(db.songs).join(<Join<HasResultSet, dynamic>>[
            innerJoin(
              db.songArtists,
              db.songArtists.songId.equalsExp(db.songs.id),
            ),
          ])
          ..where(
            db.songArtists.artistId.equals(artistId) &
                _nameCursor(db.songs, after?.song),
          )
          ..orderBy(<OrderingTerm>[
            OrderingTerm(expression: db.songs.title.lower()),
            OrderingTerm(expression: db.songs.id),
          ])
          ..limit(limit);
    final List<TypedResult> rows = await query.get();
    final List<Song> songs = rows
        .map((TypedResult r) => r.readTable(db.songs))
        .toList(growable: false);
    return _attachArtists(songs);
  }

  /// Halaman lagu satu album, urut nama (skema v1 tidak punya nomor trek).
  Future<List<SongView>> songsByAlbumPage(
    String albumId, {
    SongView? after,
    int limit = kPageSize,
  }) async {
    final SimpleSelectStatement<Songs, Song> query = db.select(db.songs)
      ..where(
        (Songs s) => s.albumId.equals(albumId) & _nameCursor(s, after?.song),
      )
      ..orderBy(<OrderingTerm Function(Songs)>[
        (Songs s) => OrderingTerm(expression: s.title.lower()),
        (Songs s) => OrderingTerm(expression: s.id),
      ])
      ..limit(limit);
    return _attachArtists(await query.get());
  }

  /// Syarat keyset untuk urutan terbaru: (dateAdded, id) lebih kecil dari
  /// kursor. Tanpa kursor, syaratnya selalu benar.
  Expression<bool> _newestCursor(Songs s, Song? after) {
    if (after == null) return const Constant<bool>(true);
    return s.dateAdded.isSmallerThanValue(after.dateAdded) |
        (s.dateAdded.equals(after.dateAdded) &
            s.id.isSmallerThanValue(after.id));
  }

  /// Syarat keyset untuk urutan nama: (lower(title), id) lebih besar dari
  /// kursor.
  Expression<bool> _nameCursor(Songs s, Song? after) {
    if (after == null) return const Constant<bool>(true);
    final String titleKey = after.title.toLowerCase();
    return s.title.lower().isBiggerThanValue(titleKey) |
        (s.title.lower().equals(titleKey) & s.id.isBiggerThanValue(after.id));
  }

  /// Syarat keyset untuk urutan sering diputar: (totalPlayTimeMs, id)
  /// lebih kecil dari kursor.
  Expression<bool> _playedCursor(Songs s, Song? after) {
    if (after == null) return const Constant<bool>(true);
    return s.totalPlayTimeMs.isSmallerThanValue(after.totalPlayTimeMs) |
        (s.totalPlayTimeMs.equals(after.totalPlayTimeMs) &
            s.id.isSmallerThanValue(after.id));
  }

  /// Tempelkan nama artis ke daftar lagu (dua query, tanpa N+1).
  Future<List<SongView>> _attachArtists(List<Song> songs) async {
    if (songs.isEmpty) return const <SongView>[];
    final List<String> ids = songs.map((Song s) => s.id).toList();
    final List<SongArtist> mappings = await (db.select(
      db.songArtists,
    )..where((SongArtists m) => m.songId.isIn(ids))).get();
    final List<String> artistIds = mappings
        .map((SongArtist m) => m.artistId)
        .toSet()
        .toList(growable: false);
    final Map<String, String> namesById = <String, String>{};
    if (artistIds.isNotEmpty) {
      final List<Artist> artists = await (db.select(
        db.artists,
      )..where((Artists a) => a.id.isIn(artistIds))).get();
      for (final Artist artist in artists) {
        namesById[artist.id] = artist.name;
      }
    }
    final Map<String, List<(int, String)>> grouped =
        <String, List<(int, String)>>{};
    for (final SongArtist m in mappings) {
      final String? name = namesById[m.artistId];
      if (name == null) continue;
      grouped.putIfAbsent(m.songId, () => <(int, String)>[]).add((
        m.position,
        name,
      ));
    }
    return songs
        .map((Song song) {
          final List<(int, String)> names =
              grouped[song.id] ?? <(int, String)>[];
          names.sort(
            ((int, String) a, (int, String) b) => a.$1.compareTo(b.$1),
          );
          return SongView(
            song: song,
            artistNames: names.map(((int, String) e) => e.$2).toList(),
          );
        })
        .toList(growable: false);
  }

  /// Hitungan isi library.
  Future<LibraryCounts> libraryCounts() async {
    final int songs = await _count(
      'SELECT COUNT(*) AS c FROM songs WHERE in_library = 1',
    );
    final int artists = await _count('SELECT COUNT(*) AS c FROM artists');
    final int albums = await _count('SELECT COUNT(*) AS c FROM albums');
    final int playlists = await _count('SELECT COUNT(*) AS c FROM playlists');
    final int favorites = await _count(
      'SELECT COUNT(*) AS c FROM songs WHERE liked = 1',
    );
    final int history = await _count('SELECT COUNT(*) AS c FROM play_events');
    return LibraryCounts(
      songs: songs,
      artists: artists,
      albums: albums,
      playlists: playlists,
      favorites: favorites,
      historyEntries: history,
    );
  }

  Future<int> _count(String sql) async {
    final QueryRow row = await db.customSelect(sql).getSingle();
    return row.read<int>('c');
  }

  // ------------------------------------------------------------------
  // Favorit
  // ------------------------------------------------------------------

  /// Apakah lagu ini difavoritkan (false bila lagu belum dikenal).
  Future<bool> isLiked(String songId) async {
    final Song? song = await (db.select(
      db.songs,
    )..where((Songs s) => s.id.equals(songId))).getSingleOrNull();
    return song?.liked ?? false;
  }

  /// Stream status favorit satu lagu (untuk tombol hati yang reaktif).
  Stream<bool> watchIsLiked(String songId) {
    final SimpleSelectStatement<Songs, Song> query = db.select(db.songs)
      ..where((Songs s) => s.id.equals(songId));
    return query.watchSingleOrNull().map((Song? song) => song?.liked ?? false);
  }

  /// Balik status favorit lagu. Menandai favorit juga memasukkan lagu ke
  /// Library. Mengembalikan status baru. Lagu wajib sudah ada di database
  /// (pemanggil memastikan lewat [upsertSong] dulu); bila belum ada,
  /// melempar [StateError].
  Future<bool> toggleLiked(String songId) async {
    final Song? song = await (db.select(
      db.songs,
    )..where((Songs s) => s.id.equals(songId))).getSingleOrNull();
    if (song == null) {
      throw StateError('toggleLiked: lagu $songId belum ada di database');
    }
    final bool liked = !song.liked;
    await (db.update(db.songs)..where((Songs s) => s.id.equals(songId))).write(
      SongsCompanion(
        liked: Value<bool>(liked),
        inLibrary: liked ? const Value<bool>(true) : const Value<bool>.absent(),
        dateModified: Value<DateTime>(DateTime.now()),
      ),
    );
    return liked;
  }

  /// Keluarkan lagu dari Library: favorit mati, lagu keluar dari semua
  /// playlist, `in_library` mati. Baris lagu dan riwayat putarnya tetap
  /// ada (riwayat adalah fakta yang sudah terjadi).
  Future<void> removeFromLibrary(String songId) async {
    await db.transaction(() async {
      await (db.delete(
        db.playlistSongs,
      )..where((PlaylistSongs p) => p.songId.equals(songId))).go();
      await (db.update(
        db.songs,
      )..where((Songs s) => s.id.equals(songId))).write(
        SongsCompanion(
          liked: const Value<bool>(false),
          inLibrary: const Value<bool>(false),
          dateModified: Value<DateTime>(DateTime.now()),
        ),
      );
    });
  }

  // ------------------------------------------------------------------
  // Artis dan album
  // ------------------------------------------------------------------

  /// Halaman artis beserta jumlah lagu Library masing-masing, urut nama.
  ///
  /// Hanya artis yang punya minimal satu lagu Library yang tampil: artis
  /// yang hanya muncul dari lagu yang pernah diputar (tapi belum
  /// disimpan) tidak ikut, supaya tab Artis tidak penuh baris "0 lagu".
  /// Difilter di SQL (INNER JOIN ke lagu Library), bukan sesudah paging,
  /// supaya keyset tetap benar.
  Future<List<ArtistWithCount>> artistsPage({
    ArtistWithCount? after,
    int limit = kPageSize,
  }) async {
    final StringBuffer sql = StringBuffer(
      'SELECT a.id AS id, a.name AS name, a.thumbnail_url AS thumbnail_url, '
      'a.liked AS liked, a.date_added AS date_added, '
      'COUNT(DISTINCT sa.song_id) AS song_count '
      'FROM artists a '
      'JOIN song_artists sa ON sa.artist_id = a.id '
      'JOIN songs s ON s.id = sa.song_id AND s.in_library = 1 ',
    );
    final List<Variable<Object>> vars = <Variable<Object>>[];
    if (after != null) {
      final String nameKey = after.artist.name.toLowerCase();
      sql.write('WHERE lower(a.name) > ? OR (lower(a.name) = ? AND a.id > ?) ');
      vars.addAll(<Variable<Object>>[
        Variable<String>(nameKey),
        Variable<String>(nameKey),
        Variable<String>(after.artist.id),
      ]);
    }
    sql.write('GROUP BY a.id ORDER BY lower(a.name) ASC, a.id ASC LIMIT ?');
    vars.add(Variable<int>(limit));
    final List<QueryRow> rows = await db
        .customSelect(
          sql.toString(),
          variables: vars,
          readsFrom: <TableInfo<Table, Object?>>{
            db.artists,
            db.songArtists,
            db.songs,
          },
        )
        .get();
    return rows
        .map((QueryRow r) {
          return ArtistWithCount(
            artist: Artist(
              id: r.read<String>('id'),
              name: r.read<String>('name'),
              thumbnailUrl: r.readNullable<String>('thumbnail_url'),
              liked: r.read<bool>('liked'),
              dateAdded: r.read<DateTime>('date_added'),
            ),
            songCount: r.read<int>('song_count'),
          );
        })
        .toList(growable: false);
  }

  /// Halaman album beserta jumlah lagu Library masing-masing, urut nama.
  /// Hanya album yang punya minimal satu lagu Library yang tampil.
  Future<List<AlbumWithCount>> albumsPage({
    AlbumWithCount? after,
    int limit = kPageSize,
  }) async {
    final StringBuffer sql = StringBuffer(
      'SELECT a.id AS id, a.title AS title, a.year AS year, '
      'a.thumbnail_url AS thumbnail_url, a.liked AS liked, '
      'a.date_added AS date_added, COUNT(*) AS song_count '
      'FROM albums a '
      'JOIN songs s ON s.album_id = a.id AND s.in_library = 1 ',
    );
    final List<Variable<Object>> vars = <Variable<Object>>[];
    if (after != null) {
      final String titleKey = after.album.title.toLowerCase();
      sql.write(
        'WHERE lower(a.title) > ? OR (lower(a.title) = ? AND a.id > ?) ',
      );
      vars.addAll(<Variable<Object>>[
        Variable<String>(titleKey),
        Variable<String>(titleKey),
        Variable<String>(after.album.id),
      ]);
    }
    sql.write('GROUP BY a.id ORDER BY lower(a.title) ASC, a.id ASC LIMIT ?');
    vars.add(Variable<int>(limit));
    final List<QueryRow> rows = await db
        .customSelect(
          sql.toString(),
          variables: vars,
          readsFrom: <TableInfo<Table, Object?>>{db.albums, db.songs},
        )
        .get();
    return rows
        .map((QueryRow r) {
          return AlbumWithCount(
            album: Album(
              id: r.read<String>('id'),
              title: r.read<String>('title'),
              year: r.readNullable<int>('year'),
              thumbnailUrl: r.readNullable<String>('thumbnail_url'),
              liked: r.read<bool>('liked'),
              dateAdded: r.read<DateTime>('date_added'),
            ),
            songCount: r.read<int>('song_count'),
          );
        })
        .toList(growable: false);
  }

  Future<Artist?> artistById(String id) async {
    return (db.select(
      db.artists,
    )..where((Artists a) => a.id.equals(id))).getSingleOrNull();
  }

  /// Gabungkan artis id semu (`local-<hash nama>`) ke channelId YTM
  /// aslinya (P4).
  ///
  /// Dipanggil saat data pencarian/browse memberi channelId untuk nama
  /// artis yang selama ini hanya dikenal namanya: pemetaan lagu artis
  /// semu dipindah ke baris channelId (duplikat posisi diabaikan),
  /// baris artis semu dihapus, dan baris FTS artis diperbarui. Bila
  /// tidak ada artis semu untuk nama itu, hanya memastikan baris
  /// channelId ada (dengan nama + sampul terbaru bila diberikan).
  /// Bila [channelId] kosong atau sama dengan id semu, tidak terjadi
  /// apa-apa.
  Future<void> mergeArtistChannel({
    required String name,
    required String channelId,
    String? thumbnailUrl,
  }) async {
    final String trimmedName = name.trim();
    final String trimmedChannelId = channelId.trim();
    if (trimmedName.isEmpty || trimmedChannelId.isEmpty) return;
    final String pseudoId = localArtistIdForName(trimmedName);
    if (pseudoId == trimmedChannelId) return;
    await db.transaction(() async {
      final DateTime now = DateTime.now();
      final Artist? existing = await (db.select(
        db.artists,
      )..where((Artists a) => a.id.equals(trimmedChannelId))).getSingleOrNull();
      if (existing == null) {
        await db
            .into(db.artists)
            .insert(
              ArtistsCompanion.insert(
                id: trimmedChannelId,
                name: trimmedName,
                thumbnailUrl: Value<String?>(thumbnailUrl),
                dateAdded: now,
              ),
            );
      } else if (thumbnailUrl != null &&
          thumbnailUrl.isNotEmpty &&
          (existing.thumbnailUrl == null || existing.thumbnailUrl!.isEmpty)) {
        await (db.update(
          db.artists,
        )..where((Artists a) => a.id.equals(trimmedChannelId))).write(
          ArtistsCompanion(thumbnailUrl: Value<String?>(thumbnailUrl)),
        );
      }
      final List<SongArtist> mappings = await (db.select(
        db.songArtists,
      )..where((SongArtists m) => m.artistId.equals(pseudoId))).get();
      for (final SongArtist mapping in mappings) {
        await db
            .into(db.songArtists)
            .insert(
              SongArtistsCompanion.insert(
                songId: mapping.songId,
                artistId: trimmedChannelId,
                position: mapping.position,
              ),
              mode: InsertMode.insertOrIgnore,
            );
      }
      await (db.delete(
        db.songArtists,
      )..where((SongArtists m) => m.artistId.equals(pseudoId))).go();
      await (db.delete(
        db.artists,
      )..where((Artists a) => a.id.equals(pseudoId))).go();
      await _syncArtistFts(trimmedChannelId, name: trimmedName);
      final LibrarySearch fts = db.librarySearch;
      await (db.delete(fts)..where(
            (LibrarySearch f) =>
                f.kind.equals('artist') & f.refId.equals(pseudoId),
          ))
          .go();
    });
  }

  Future<Album?> albumById(String id) async {
    return (db.select(
      db.albums,
    )..where((Albums a) => a.id.equals(id))).getSingleOrNull();
  }

  // ------------------------------------------------------------------
  // Playlist
  // ------------------------------------------------------------------

  /// Buat playlist baru. Nama wajib tidak kosong dan paling panjang 100
  /// karakter; deskripsi paling panjang 500 karakter. Mengembalikan id
  /// playlist. Melempar [ArgumentError] bila validasi gagal.
  Future<int> createPlaylist(String name, {String? description}) async {
    final String trimmed = name.trim();
    _validatePlaylistName(trimmed);
    _validatePlaylistDescription(description);
    final DateTime now = DateTime.now();
    return db
        .into(db.playlists)
        .insert(
          PlaylistsCompanion.insert(
            name: trimmed,
            description: Value<String?>(description?.trim()),
            createdAt: now,
            updatedAt: now,
          ),
        );
  }

  /// Ubah nama playlist (validasi sama seperti [createPlaylist]).
  Future<void> renamePlaylist(int id, String name) async {
    final String trimmed = name.trim();
    _validatePlaylistName(trimmed);
    await (db.update(
      db.playlists,
    )..where((Playlists p) => p.id.equals(id))).write(
      PlaylistsCompanion(
        name: Value<String>(trimmed),
        updatedAt: Value<DateTime>(DateTime.now()),
      ),
    );
  }

  /// Ubah deskripsi playlist (null berarti kosongkan deskripsi).
  Future<void> updatePlaylistDescription(int id, String? description) async {
    _validatePlaylistDescription(description);
    await (db.update(
      db.playlists,
    )..where((Playlists p) => p.id.equals(id))).write(
      PlaylistsCompanion(
        description: Value<String?>(description?.trim()),
        updatedAt: Value<DateTime>(DateTime.now()),
      ),
    );
  }

  /// Hapus playlist. Lagu di dalamnya ikut terhapus dari playlist
  /// (CASCADE); lagu di Library tidak ikut terhapus.
  Future<void> deletePlaylist(int id) async {
    await (db.delete(
      db.playlists,
    )..where((Playlists p) => p.id.equals(id))).go();
  }

  Future<Playlist?> playlistById(int id) async {
    return (db.select(
      db.playlists,
    )..where((Playlists p) => p.id.equals(id))).getSingleOrNull();
  }

  /// Halaman playlist beserta jumlah lagu masing-masing, urut terakhir
  /// diubah dulu.
  Future<List<PlaylistWithCount>> playlistsPage({
    PlaylistWithCount? after,
    int limit = kPageSize,
  }) async {
    final SimpleSelectStatement<Playlists, Playlist> query = db.select(
      db.playlists,
    );
    if (after != null) {
      final Playlist p = after.playlist;
      query.where(
        (Playlists t) =>
            t.updatedAt.isSmallerThanValue(p.updatedAt) |
            (t.updatedAt.equals(p.updatedAt) & t.id.isSmallerThanValue(p.id)),
      );
    }
    query
      ..orderBy(<OrderingTerm Function(Playlists)>[
        (Playlists t) =>
            OrderingTerm(expression: t.updatedAt, mode: OrderingMode.desc),
        (Playlists t) =>
            OrderingTerm(expression: t.id, mode: OrderingMode.desc),
      ])
      ..limit(limit);
    final List<Playlist> playlists = await query.get();
    if (playlists.isEmpty) return const <PlaylistWithCount>[];
    final List<int> ids = playlists.map((Playlist p) => p.id).toList();
    final List<QueryRow> rows = await db
        .customSelect(
          'SELECT playlist_id AS id, COUNT(*) AS c FROM playlist_songs '
          'WHERE playlist_id IN (${ids.map((_) => '?').join(', ')}) '
          'GROUP BY playlist_id',
          variables: ids
              .map((int id) => Variable<int>(id))
              .toList(growable: false),
          readsFrom: <TableInfo<Table, Object?>>{db.playlistSongs},
        )
        .get();
    final Map<int, int> counts = <int, int>{
      for (final QueryRow row in rows) row.read<int>('id'): row.read<int>('c'),
    };
    return playlists
        .map(
          (Playlist p) =>
              PlaylistWithCount(playlist: p, songCount: counts[p.id] ?? 0),
        )
        .toList(growable: false);
  }

  /// Tambahkan lagu ke playlist. Lagu yang sama tidak bisa ditambahkan
  /// dua kali (mengembalikan false). Menambahkan lagu juga memasukkannya
  /// ke Library. Mengembalikan true bila lagu benar-benar ditambahkan.
  Future<bool> addSongToPlaylist(int playlistId, String songId) async {
    return db.transaction(() async {
      final PlaylistSong? existing =
          await (db.select(db.playlistSongs)..where(
                (PlaylistSongs p) =>
                    p.playlistId.equals(playlistId) & p.songId.equals(songId),
              ))
              .getSingleOrNull();
      if (existing != null) return false;
      final int position = await _nextPlaylistPosition(playlistId);
      final DateTime now = DateTime.now();
      await db
          .into(db.playlistSongs)
          .insert(
            PlaylistSongsCompanion.insert(
              playlistId: playlistId,
              songId: songId,
              position: position,
              dateAdded: now,
            ),
          );
      await (db.update(db.songs)..where((Songs s) => s.id.equals(songId)))
          .write(const SongsCompanion(inLibrary: Value<bool>(true)));
      await _touchPlaylist(playlistId, now);
      return true;
    });
  }

  /// Tambahkan beberapa lagu sekaligus (duplikat dilewati).
  /// Mengembalikan jumlah lagu yang benar-benar ditambahkan.
  Future<int> addSongsToPlaylist(int playlistId, List<String> songIds) async {
    int added = 0;
    for (final String songId in songIds) {
      if (await addSongToPlaylist(playlistId, songId)) added++;
    }
    return added;
  }

  /// Keluarkan lagu dari playlist. Posisi lagu lain dirapatkan kembali
  /// (0..n-1 tanpa lubang).
  Future<void> removeSongFromPlaylist(int playlistId, String songId) async {
    await db.transaction(() async {
      await (db.delete(db.playlistSongs)..where(
            (PlaylistSongs p) =>
                p.playlistId.equals(playlistId) & p.songId.equals(songId),
          ))
          .go();
      await _renumberPlaylist(playlistId);
      await _touchPlaylist(playlistId, DateTime.now());
    });
  }

  /// Pindahkan lagu ke posisi baru di playlist. Posisi di luar rentang
  /// dijepit ke ujung yang valid.
  Future<void> moveSongInPlaylist(
    int playlistId,
    String songId,
    int newPosition,
  ) async {
    await db.transaction(() async {
      final List<PlaylistSong> rows =
          await (db.select(db.playlistSongs)
                ..where((PlaylistSongs p) => p.playlistId.equals(playlistId))
                ..orderBy(<OrderingTerm Function(PlaylistSongs)>[
                  (PlaylistSongs p) => OrderingTerm(expression: p.position),
                ]))
              .get();
      final List<String> ids = rows.map((PlaylistSong r) => r.songId).toList();
      final int from = ids.indexOf(songId);
      if (from == -1) return;
      ids.removeAt(from);
      final int to = newPosition.clamp(0, ids.length);
      ids.insert(to, songId);
      for (int i = 0; i < ids.length; i++) {
        await (db.update(db.playlistSongs)..where(
              (PlaylistSongs p) =>
                  p.playlistId.equals(playlistId) & p.songId.equals(ids[i]),
            ))
            .write(PlaylistSongsCompanion(position: Value<int>(i)));
      }
      await _touchPlaylist(playlistId, DateTime.now());
    });
  }

  /// Halaman lagu satu playlist, urut posisi.
  Future<List<PlaylistSongEntry>> playlistSongsPage(
    int playlistId, {
    PlaylistSongEntry? after,
    int limit = kPageSize,
  }) async {
    final SimpleSelectStatement<PlaylistSongs, PlaylistSong> query = db.select(
      db.playlistSongs,
    )..where((PlaylistSongs p) => p.playlistId.equals(playlistId));
    if (after != null) {
      query.where(
        (PlaylistSongs p) => p.position.isBiggerThanValue(after.position),
      );
    }
    query
      ..orderBy(<OrderingTerm Function(PlaylistSongs)>[
        (PlaylistSongs p) => OrderingTerm(expression: p.position),
      ])
      ..limit(limit);
    final List<PlaylistSong> rows = await query.get();
    if (rows.isEmpty) return const <PlaylistSongEntry>[];
    final List<String> ids = rows.map((PlaylistSong r) => r.songId).toList();
    final List<Song> songs = await (db.select(
      db.songs,
    )..where((Songs s) => s.id.isIn(ids))).get();
    final List<SongView> views = await _attachArtists(songs);
    final Map<String, SongView> byId = <String, SongView>{
      for (final SongView v in views) v.id: v,
    };
    final List<PlaylistSongEntry> entries = <PlaylistSongEntry>[];
    for (final PlaylistSong row in rows) {
      final SongView? view = byId[row.songId];
      if (view == null) continue;
      entries.add(
        PlaylistSongEntry(
          song: view,
          position: row.position,
          dateAdded: row.dateAdded,
        ),
      );
    }
    return entries;
  }

  /// Lagu playlist untuk diputar: paling banyak [limit] lagu, mulai dari
  /// [startSongId] bila diberikan (lagu itu jadi lagu pertama antrean).
  /// Batas ini mengikuti batas antrean pemutar (200 lagu).
  Future<List<SongView>> playlistSongsForPlayback(
    int playlistId, {
    String? startSongId,
    int limit = 200,
  }) async {
    final SimpleSelectStatement<PlaylistSongs, PlaylistSong> query = db.select(
      db.playlistSongs,
    )..where((PlaylistSongs p) => p.playlistId.equals(playlistId));
    if (startSongId != null) {
      final PlaylistSong? start =
          await (db.select(db.playlistSongs)..where(
                (PlaylistSongs p) =>
                    p.playlistId.equals(playlistId) &
                    p.songId.equals(startSongId),
              ))
              .getSingleOrNull();
      if (start != null) {
        query.where(
          (PlaylistSongs p) => p.position.isBiggerOrEqualValue(start.position),
        );
      }
    }
    query
      ..orderBy(<OrderingTerm Function(PlaylistSongs)>[
        (PlaylistSongs p) => OrderingTerm(expression: p.position),
      ])
      ..limit(limit);
    final List<PlaylistSong> rows = await query.get();
    if (rows.isEmpty) return const <SongView>[];
    final List<String> ids = rows.map((PlaylistSong r) => r.songId).toList();
    final List<Song> songs = await (db.select(
      db.songs,
    )..where((Songs s) => s.id.isIn(ids))).get();
    final List<SongView> views = await _attachArtists(songs);
    final Map<String, SongView> byId = <String, SongView>{
      for (final SongView v in views) v.id: v,
    };
    return <SongView>[
      for (final PlaylistSong row in rows)
        if (byId[row.songId] != null) byId[row.songId]!,
    ];
  }

  Future<int> _nextPlaylistPosition(int playlistId) async {
    final PlaylistSong? last =
        await (db.select(db.playlistSongs)
              ..where((PlaylistSongs p) => p.playlistId.equals(playlistId))
              ..orderBy(<OrderingTerm Function(PlaylistSongs)>[
                (PlaylistSongs p) => OrderingTerm(
                  expression: p.position,
                  mode: OrderingMode.desc,
                ),
              ])
              ..limit(1))
            .getSingleOrNull();
    return (last?.position ?? -1) + 1;
  }

  Future<void> _renumberPlaylist(int playlistId) async {
    final List<PlaylistSong> rows =
        await (db.select(db.playlistSongs)
              ..where((PlaylistSongs p) => p.playlistId.equals(playlistId))
              ..orderBy(<OrderingTerm Function(PlaylistSongs)>[
                (PlaylistSongs p) => OrderingTerm(expression: p.position),
              ]))
            .get();
    for (int i = 0; i < rows.length; i++) {
      if (rows[i].position != i) {
        await (db.update(db.playlistSongs)..where(
              (PlaylistSongs p) =>
                  p.playlistId.equals(playlistId) &
                  p.songId.equals(rows[i].songId),
            ))
            .write(PlaylistSongsCompanion(position: Value<int>(i)));
      }
    }
  }

  Future<void> _touchPlaylist(int playlistId, DateTime now) async {
    await (db.update(db.playlists)
          ..where((Playlists p) => p.id.equals(playlistId)))
        .write(PlaylistsCompanion(updatedAt: Value<DateTime>(now)));
  }

  void _validatePlaylistName(String trimmed) {
    if (trimmed.isEmpty) {
      throw ArgumentError('Nama playlist tidak boleh kosong');
    }
    if (trimmed.length > kMaxPlaylistNameLength) {
      throw ArgumentError(
        'Nama playlist paling panjang $kMaxPlaylistNameLength karakter',
      );
    }
  }

  void _validatePlaylistDescription(String? description) {
    if (description != null &&
        description.trim().length > kMaxPlaylistDescriptionLength) {
      throw ArgumentError(
        'Deskripsi playlist paling panjang $kMaxPlaylistDescriptionLength karakter',
      );
    }
  }

  // ------------------------------------------------------------------
  // Riwayat putar
  // ------------------------------------------------------------------

  /// Catat satu sesi putar: simpan event, tambahkan durasi ke total waktu
  /// putar lagu, lalu pangkas riwayat ke [kMaxPlayEvents] entri.
  ///
  /// [playTimeMs] adalah durasi yang benar-benar terdengar (bukan posisi
  /// akhir lagu). Pemanggil ([PlayHistoryRecorder]) memastikan hanya sesi
  /// yang memenuhi ambang PRD B2.7 yang dicatat.
  Future<void> recordPlay({
    required String songId,
    required DateTime timestamp,
    required int playTimeMs,
  }) async {
    await db.transaction(() async {
      await db
          .into(db.playEvents)
          .insert(
            PlayEventsCompanion.insert(
              songId: songId,
              timestamp: timestamp,
              playTimeMs: playTimeMs,
            ),
          );
      final Song? song = await (db.select(
        db.songs,
      )..where((Songs s) => s.id.equals(songId))).getSingleOrNull();
      if (song != null) {
        await (db.update(
          db.songs,
        )..where((Songs s) => s.id.equals(songId))).write(
          SongsCompanion(
            totalPlayTimeMs: Value<int>(song.totalPlayTimeMs + playTimeMs),
          ),
        );
      }
      final int count = await _count('SELECT COUNT(*) AS c FROM play_events');
      if (count > kMaxPlayEvents) {
        final int excess = count - kMaxPlayEvents;
        await db.customStatement(
          'DELETE FROM play_events WHERE id IN ('
          'SELECT id FROM play_events ORDER BY timestamp ASC, id ASC '
          'LIMIT ?)',
          <Object>[excess],
        );
      }
    });
  }

  /// Halaman riwayat putar, terbaru dulu.
  Future<List<PlayHistoryEntry>> historyPage({
    PlayHistoryEntry? after,
    int limit = kPageSize,
  }) async {
    final SimpleSelectStatement<PlayEvents, PlayEvent> query = db.select(
      db.playEvents,
    );
    if (after != null) {
      final PlayEvent e = after.event;
      query.where(
        (PlayEvents t) =>
            t.timestamp.isSmallerThanValue(e.timestamp) |
            (t.timestamp.equals(e.timestamp) & t.id.isSmallerThanValue(e.id)),
      );
    }
    query
      ..orderBy(<OrderingTerm Function(PlayEvents)>[
        (PlayEvents t) =>
            OrderingTerm(expression: t.timestamp, mode: OrderingMode.desc),
        (PlayEvents t) =>
            OrderingTerm(expression: t.id, mode: OrderingMode.desc),
      ])
      ..limit(limit);
    final List<PlayEvent> events = await query.get();
    if (events.isEmpty) return const <PlayHistoryEntry>[];
    final List<String> ids = events
        .map((PlayEvent e) => e.songId)
        .toSet()
        .toList(growable: false);
    final List<Song> songs = await (db.select(
      db.songs,
    )..where((Songs s) => s.id.isIn(ids))).get();
    final List<SongView> views = await _attachArtists(songs);
    final Map<String, SongView> byId = <String, SongView>{
      for (final SongView v in views) v.id: v,
    };
    return <PlayHistoryEntry>[
      for (final PlayEvent event in events)
        if (byId[event.songId] != null)
          PlayHistoryEntry(event: event, song: byId[event.songId]!),
    ];
  }

  /// Lagu yang baru diputar, tanpa duplikat: tiap lagu tampil sekali,
  /// di posisi putaran terakhirnya (PRD B6.1, seksi "Baru diputar"
  /// beranda P4). Urutan: putaran terakhir terbaru dulu.
  Future<List<SongView>> recentPlayedSongs({int limit = 10}) async {
    final List<QueryRow> rows = await db
        .customSelect(
          'SELECT song_id AS id FROM play_events '
          'GROUP BY song_id ORDER BY MAX(timestamp) DESC, MAX(id) DESC '
          'LIMIT ?',
          variables: <Variable<Object>>[Variable<int>(limit)],
          readsFrom: <TableInfo<Table, Object?>>{db.playEvents},
        )
        .get();
    final List<String> ids = rows
        .map((QueryRow r) => r.read<String>('id'))
        .toList(growable: false);
    if (ids.isEmpty) return const <SongView>[];
    final List<Song> songs = await (db.select(
      db.songs,
    )..where((Songs s) => s.id.isIn(ids))).get();
    final List<SongView> views = await _attachArtists(songs);
    final Map<String, SongView> byId = <String, SongView>{
      for (final SongView v in views) v.id: v,
    };
    return <SongView>[
      for (final String id in ids)
        if (byId[id] != null) byId[id]!,
    ];
  }

  /// Hapus seluruh riwayat putar. Total waktu putar lagu TIDAK direset:
  /// total itu agregat seumur hidup yang juga menggerakkan urutan
  /// "Sering diputar"; yang dihapus hanya daftar riwayat yang tampil.
  Future<void> clearHistory() async {
    await db.delete(db.playEvents).go();
  }

  /// Jumlah putaran bermakna (30 detik atau lebih) satu lagu dalam
  /// [within] terakhir. Dipakai rumus "Lagu untukmu" di P4.
  Future<int> meaningfulPlayCount(
    String songId, {
    Duration within = const Duration(days: 30),
  }) async {
    final DateTime since = DateTime.now().subtract(within);
    final QueryRow row = await db
        .customSelect(
          'SELECT COUNT(*) AS c FROM play_events '
          'WHERE song_id = ? AND play_time_ms >= ? AND timestamp >= ?',
          variables: <Variable<Object>>[
            Variable<String>(songId),
            Variable<int>(kMeaningfulPlayMs),
            // Drift menyimpan DateTime sebagai detik Unix.
            Variable<int>(since.millisecondsSinceEpoch ~/ 1000),
          ],
          readsFrom: <TableInfo<Table, Object?>>{db.playEvents},
        )
        .getSingle();
    return row.read<int>('c');
  }

  // ------------------------------------------------------------------
  // Pencarian lokal (FTS5)
  // ------------------------------------------------------------------

  /// Cari lagu dan artis di dalam database (bukan hanya Library: lagu
  /// yang pernah diputar tapi belum disimpan ikut ditemukan).
  ///
  /// Semua kata kunci wajib cocok (AND), tiap kata memakai awalan
  /// (`kata*`). Bila AND tidak menemukan apa pun, dicoba OR (salah satu
  /// kata cocok). Query kosong atau hanya berisi karakter khusus
  /// mengembalikan hasil kosong, bukan error.
  Future<LocalSearchResults> searchLocal(
    String query, {
    int limit = kPageSize,
  }) async {
    final String? andQuery = _ftsQuery(query, useOr: false);
    if (andQuery == null) return const LocalSearchResults();
    LocalSearchResults results = await _searchFts(andQuery, limit: limit);
    if (results.isEmpty) {
      final String? orQuery = _ftsQuery(query, useOr: true);
      if (orQuery != null && orQuery != andQuery) {
        results = await _searchFts(orQuery, limit: limit);
      }
    }
    return results;
  }

  Future<LocalSearchResults> _searchFts(
    String ftsQuery, {
    required int limit,
  }) async {
    final LibrarySearch fts = db.librarySearch;
    final List<String> songIds = await _ftsRefIds(fts, ftsQuery, 'song', limit);
    final List<String> artistIds = await _ftsRefIds(
      fts,
      ftsQuery,
      'artist',
      limit,
    );
    final List<SongView> songs;
    if (songIds.isEmpty) {
      songs = const <SongView>[];
    } else {
      final List<Song> rows = await (db.select(
        db.songs,
      )..where((Songs s) => s.id.isIn(songIds))).get();
      final List<SongView> views = await _attachArtists(rows);
      final Map<String, SongView> byId = <String, SongView>{
        for (final SongView v in views) v.id: v,
      };
      // Pertahankan urutan relevansi FTS (bukan urutan hasil IN).
      songs = <SongView>[
        for (final String id in songIds)
          if (byId[id] != null) byId[id]!,
      ];
    }
    final List<Artist> artists;
    if (artistIds.isEmpty) {
      artists = const <Artist>[];
    } else {
      final List<Artist> rows = await (db.select(
        db.artists,
      )..where((Artists a) => a.id.isIn(artistIds))).get();
      final Map<String, Artist> byId = <String, Artist>{
        for (final Artist a in rows) a.id: a,
      };
      artists = <Artist>[
        for (final String id in artistIds)
          if (byId[id] != null) byId[id]!,
      ];
    }
    return LocalSearchResults(songs: songs, artists: artists);
  }

  Future<List<String>> _ftsRefIds(
    LibrarySearch fts,
    String ftsQuery,
    String kind,
    int limit,
  ) async {
    final List<TypedResult> rows =
        await (db.selectOnly(fts)
              ..addColumns(<Expression<Object>>[fts.refId])
              ..where(fts.match(ftsQuery) & fts.kind.equals(kind))
              ..orderBy(<OrderingTerm>[OrderingTerm(expression: fts.rank)])
              ..limit(limit))
            .get();
    return rows
        .map((TypedResult r) => r.read(fts.refId))
        .whereType<String>()
        .toList(growable: false);
  }

  /// Ubah teks ketikan pengguna menjadi query FTS5 yang aman.
  ///
  /// Karakter khusus FTS5 (`"`, `*`, `(`, `)`, `:`, `^`, `+`, `-`, dan
  /// sejenisnya) dibuang; tiap kata dibungkus awalan (`kata*`) supaya
  /// ketikan sebagian tetap menemukan hasil; kata digabung AND atau OR.
  /// Mengembalikan null bila tidak ada kata yang valid.
  String? _ftsQuery(String input, {required bool useOr}) {
    final List<String> terms = input
        .split(RegExp(r'\s+'))
        .map((String word) {
          return word.replaceAll(RegExp('[^\\p{L}\\p{N}]', unicode: true), '');
        })
        .where((String word) => word.isNotEmpty)
        .map((String word) => '$word*')
        .toList(growable: false);
    if (terms.isEmpty) return null;
    return terms.join(useOr ? ' OR ' : ' AND ');
  }

  // ------------------------------------------------------------------
  // Riwayat pencarian
  // ------------------------------------------------------------------

  /// Simpan query pencarian (query sama tidak diduplikasi: baris lama
  /// dihapus lalu disisip baru supaya naik ke atas daftar). Daftar
  /// dipangkas ke [kMaxSearchHistory] query.
  ///
  /// Dedup tidak membedakan kapitalisasi (PRD B1.3: "Queen" dan
  /// "queen" adalah query yang sama); ejaan yang tersimpan adalah
  /// ejaan terakhir yang diketik pengguna.
  Future<void> addSearchQuery(String query) async {
    final String trimmed = query.trim();
    if (trimmed.isEmpty) return;
    final DateTime now = DateTime.now();
    await db.transaction(() async {
      // Hapus + sisip (bukan update): UPDATE mempertahankan rowid lama,
      // dan rowid adalah tiebreak urutan saat cap waktu detiknya sama.
      // Perbandingan memakai huruf kecil supaya "Queen" dan "queen"
      // dianggap satu query (PRD B1.3).
      await (db.delete(db.searchHistory)..where(
            (SearchHistory t) => t.query.lower().equals(trimmed.toLowerCase()),
          ))
          .go();
      await db
          .into(db.searchHistory)
          .insert(
            SearchHistoryCompanion.insert(query: trimmed, timestamp: now),
          );
      final int count = await _count(
        'SELECT COUNT(*) AS c FROM search_history',
      );
      if (count > kMaxSearchHistory) {
        final int excess = count - kMaxSearchHistory;
        await db.customStatement(
          'DELETE FROM search_history WHERE query IN ('
          'SELECT query FROM search_history '
          'ORDER BY timestamp ASC, rowid ASC LIMIT ?)',
          <Object>[excess],
        );
      }
    });
  }

  /// Query pencarian terbaru dulu (tiebreak rowid: cap waktu drift
  /// beresolusi detik, jadi query berurutan bisa berbagi detik yang sama).
  Future<List<String>> recentSearches({int limit = 10}) async {
    final List<QueryRow> rows = await db
        .customSelect(
          'SELECT query FROM search_history '
          'ORDER BY timestamp DESC, rowid DESC LIMIT ?',
          variables: <Variable<Object>>[Variable<int>(limit)],
          readsFrom: <TableInfo<Table, Object?>>{db.searchHistory},
        )
        .get();
    return rows.map((QueryRow r) => r.read<String>('query')).toList();
  }

  /// Query riwayat yang diawali [prefix] (tidak membedakan
  /// kapitalisasi), terbaru dulu. Dipakai saran pencarian lokal saat
  /// mengetik (PRD B1.2: saran offline berasal dari riwayat).
  Future<List<String>> searchHistoryMatching(
    String prefix, {
    int limit = 8,
  }) async {
    final String trimmed = prefix.trim();
    if (trimmed.isEmpty) return const <String>[];
    // Karakter khusus LIKE di-escape supaya ketikan pengguna dibaca
    // harfiah ("%"/"_" di query tidak menjadi wildcard).
    final String escaped = trimmed
        .toLowerCase()
        .replaceAll(r'\', r'\\')
        .replaceAll('%', r'\%')
        .replaceAll('_', r'\_');
    final List<QueryRow> rows = await db
        .customSelect(
          'SELECT query FROM search_history '
          "WHERE lower(query) LIKE ? ESCAPE '\\' "
          'ORDER BY timestamp DESC, rowid DESC LIMIT ?',
          variables: <Variable<Object>>[
            Variable<String>('$escaped%'),
            Variable<int>(limit),
          ],
          readsFrom: <TableInfo<Table, Object?>>{db.searchHistory},
        )
        .get();
    return rows.map((QueryRow r) => r.read<String>('query')).toList();
  }

  /// Hapus satu query dari riwayat pencarian.
  Future<void> deleteSearchQuery(String query) async {
    await (db.delete(
      db.searchHistory,
    )..where((SearchHistory t) => t.query.equals(query))).go();
  }

  /// Hapus seluruh riwayat pencarian.
  Future<void> clearSearchHistory() async {
    await db.delete(db.searchHistory).go();
  }

  // ------------------------------------------------------------------
  // Antrean tersimpan
  // ------------------------------------------------------------------

  /// Ganti seluruh antrean tersimpan dengan [items] (dipakai pemutar
  /// saat antrean berubah; pemulihan posisi penuh adalah kerja P7).
  Future<void> replaceQueue(List<QueueItemsCompanion> items) async {
    await db.transaction(() async {
      await db.delete(db.queueItems).go();
      if (items.isNotEmpty) {
        await db.batch((Batch batch) {
          batch.insertAll(db.queueItems, items);
        });
      }
    });
  }

  /// Muat antrean tersimpan, urut posisi.
  Future<List<QueueItem>> loadQueue() async {
    return (db.select(db.queueItems)
          ..orderBy(<OrderingTerm Function(QueueItems)>[
            (QueueItems q) => OrderingTerm(expression: q.position),
          ]))
        .get();
  }

  /// Kosongkan antrean tersimpan.
  Future<void> clearQueue() async {
    await db.delete(db.queueItems).go();
  }

  // ------------------------------------------------------------------
  // Unduhan (P5)
  // ------------------------------------------------------------------

  /// Stream status unduhan satu lagu (`DownloadState`), untuk tombol
  /// unduh yang reaktif. Lagu yang belum dikenal bernilai 0.
  Stream<int> watchDownloadState(String songId) {
    final SimpleSelectStatement<Songs, Song> query = db.select(db.songs)
      ..where((Songs s) => s.id.equals(songId));
    return query.watchSingleOrNull().map(
      (Song? song) => song?.downloadState ?? DownloadState.notDownloaded,
    );
  }

  /// Lagu terunduh, urut file terbesar dulu (PRD B3.3).
  Future<List<SongView>> downloadedSongs({int limit = 10}) async {
    final SimpleSelectStatement<Songs, Song> query = db.select(db.songs)
      ..where((Songs s) => s.downloadState.equals(DownloadState.downloaded))
      ..orderBy(<OrderingTerm Function(Songs)>[
        (Songs s) =>
            OrderingTerm(expression: s.fileSizeBytes, mode: OrderingMode.desc),
        (Songs s) => OrderingTerm(expression: s.id),
      ])
      ..limit(limit);
    return _attachArtists(await query.get());
  }

  /// Halaman lagu terunduh, urut file terbesar dulu (keyset pada
  /// (fileSizeBytes DESC, id ASC)).
  Future<List<SongView>> downloadedSongsPage({
    SongView? after,
    int limit = kPageSize,
  }) async {
    final SimpleSelectStatement<Songs, Song> query = db.select(db.songs);
    if (after == null) {
      query.where(
        (Songs s) => s.downloadState.equals(DownloadState.downloaded),
      );
    } else {
      final int afterSize = after.song.fileSizeBytes ?? 0;
      query.where(
        (Songs s) =>
            s.downloadState.equals(DownloadState.downloaded) &
            (s.fileSizeBytes.isSmallerThanValue(afterSize) |
                (s.fileSizeBytes.equals(afterSize) &
                    s.id.isBiggerThanValue(after.song.id))),
      );
    }
    query
      ..orderBy(<OrderingTerm Function(Songs)>[
        (Songs s) =>
            OrderingTerm(expression: s.fileSizeBytes, mode: OrderingMode.desc),
        (Songs s) => OrderingTerm(expression: s.id),
      ])
      ..limit(limit);
    return _attachArtists(await query.get());
  }

  /// Daftar ringan semua file unduhan (untuk rekonsiliasi saat start).
  Future<List<DownloadedFileInfo>> downloadedFiles() async {
    final List<QueryRow> rows = await db
        .customSelect(
          'SELECT id, file_path, file_size_bytes FROM songs '
          'WHERE download_state = ?',
          variables: <Variable<Object>>[
            Variable<int>(DownloadState.downloaded),
          ],
          readsFrom: <TableInfo<Table, Object?>>{db.songs},
        )
        .get();
    return rows
        .map(
          (QueryRow r) => DownloadedFileInfo(
            songId: r.read<String>('id'),
            filePath: r.readNullable<String>('file_path'),
            fileSizeBytes: r.readNullable<int>('file_size_bytes'),
          ),
        )
        .toList(growable: false);
  }

  /// Tandai lagu sebagai terunduh (file sudah di-rename dan ukurannya
  /// cocok). Lagu ikut masuk Library.
  Future<void> markDownloaded({
    required String songId,
    required String filePath,
    required int fileSizeBytes,
    String? formatId,
  }) async {
    await (db.update(db.songs)..where((Songs s) => s.id.equals(songId))).write(
      SongsCompanion(
        downloadState: const Value<int>(DownloadState.downloaded),
        filePath: Value<String?>(filePath),
        fileSizeBytes: Value<int?>(fileSizeBytes),
        downloadedAt: Value<DateTime?>(DateTime.now()),
        formatId: Value<String?>(formatId),
        inLibrary: const Value<bool>(true),
        dateModified: Value<DateTime>(DateTime.now()),
      ),
    );
  }

  /// Kosongkan status unduhan lagu (file hilang/rusak/dihapus pengguna).
  /// Lagu tetap di Library.
  Future<void> clearDownloadState(String songId) async {
    await (db.update(db.songs)..where((Songs s) => s.id.equals(songId))).write(
      SongsCompanion(
        downloadState: const Value<int>(DownloadState.notDownloaded),
        filePath: const Value<String?>(null),
        fileSizeBytes: const Value<int?>(null),
        downloadedAt: const Value<DateTime?>(null),
        formatId: const Value<String?>(null),
        dateModified: Value<DateTime>(DateTime.now()),
      ),
    );
  }

  /// Ubah status unduhan lagu saja (mis. menjadi "mengunduh" saat job
  /// dibuat). Metadata file tidak disentuh.
  Future<void> setDownloadState(String songId, int state) async {
    await (db.update(db.songs)..where((Songs s) => s.id.equals(songId))).write(
      SongsCompanion(
        downloadState: Value<int>(state),
        dateModified: Value<DateTime>(DateTime.now()),
      ),
    );
  }

  /// Simpan metadata format audio (itag, mime, bitrate) bila belum ada.
  Future<void> upsertFormat(FormatsCompanion format) async {
    await db
        .into(db.formats)
        .insert(format, mode: InsertMode.insertOrIgnore);
  }

  /// Semua pekerjaan unduhan, urut dibuat dulu (null = paling tua).
  Future<List<DownloadJob>> downloadJobs() async {
    return (db.select(db.downloadJobs)
          ..orderBy(<OrderingTerm Function(DownloadJobs)>[
            (DownloadJobs j) => OrderingTerm(expression: j.createdAt),
            (DownloadJobs j) => OrderingTerm(expression: j.songId),
          ]))
        .get();
  }

  /// Stream semua pekerjaan unduhan (untuk tab Unduhan).
  Stream<List<DownloadJob>> watchDownloadJobs() {
    final SimpleSelectStatement<DownloadJobs, DownloadJob> query =
        db.select(db.downloadJobs)
          ..orderBy(<OrderingTerm Function(DownloadJobs)>[
            (DownloadJobs j) => OrderingTerm(expression: j.createdAt),
            (DownloadJobs j) => OrderingTerm(expression: j.songId),
          ]);
    return query.watch();
  }

  /// Satu pekerjaan unduhan, atau null bila tidak ada.
  Future<DownloadJob?> downloadJobBySongId(String songId) async {
    return (db.select(
      db.downloadJobs,
    )..where((DownloadJobs j) => j.songId.equals(songId))).getSingleOrNull();
  }

  /// Sisip atau ganti satu pekerjaan unduhan.
  Future<void> upsertDownloadJob(DownloadJobsCompanion job) async {
    await db
        .into(db.downloadJobs)
        .insert(job, mode: InsertMode.insertOrReplace);
  }

  /// Perbarui kolom-kolom pekerjaan unduhan.
  Future<void> updateDownloadJob(
    String songId,
    DownloadJobsCompanion patch,
  ) async {
    await (db.update(
      db.downloadJobs,
    )..where((DownloadJobs j) => j.songId.equals(songId))).write(patch);
  }

  /// Hapus pekerjaan unduhan.
  Future<void> deleteDownloadJob(String songId) async {
    await (db.delete(
      db.downloadJobs,
    )..where((DownloadJobs j) => j.songId.equals(songId))).go();
  }

  /// Pekerjaan yang tertinggal berstatus "mengunduh" (app mati di tengah
  /// unduhan) kembali ke antrean. Dipanggil rekonsiliasi saat start.
  /// Mengembalikan jumlah job yang direset.
  Future<int> resetRunningJobsToQueued() async {
    final List<DownloadJob> running =
        await (db.select(db.downloadJobs)..where(
              (DownloadJobs j) => j.status.equals(DownloadJobStatus.running),
            ))
            .get();
    if (running.isEmpty) return 0;
    await db.transaction(() async {
      for (final DownloadJob job in running) {
        await (db.update(db.downloadJobs)..where(
              (DownloadJobs j) => j.songId.equals(job.songId),
            ))
            .write(
              DownloadJobsCompanion(
                status: const Value<int>(DownloadJobStatus.queued),
                updatedAt: Value<DateTime>(DateTime.now()),
              ),
            );
      }
    });
    return running.length;
  }

  /// Hapus pekerjaan selesai yang lebih tua dari [olderThan]
  /// (PRD B3.2: 7 hari). Mengembalikan jumlah yang dihapus.
  Future<int> pruneCompletedJobs({
    Duration olderThan = const Duration(days: 7),
  }) async {
    final DateTime cutoff = DateTime.now().subtract(olderThan);
    final List<DownloadJob> stale =
        await (db.select(db.downloadJobs)..where(
              (DownloadJobs j) =>
                  j.status.equals(DownloadJobStatus.completed) &
                  j.updatedAt.isSmallerThanValue(cutoff),
            ))
            .get();
    if (stale.isEmpty) return 0;
    await db.transaction(() async {
      for (final DownloadJob job in stale) {
        await (db.delete(
          db.downloadJobs,
        )..where((DownloadJobs j) => j.songId.equals(job.songId))).go();
      }
    });
    return stale.length;
  }

  // ------------------------------------------------------------------
  // Cache streaming (P5): manifest di tabel cache_entries
  // ------------------------------------------------------------------

  /// Satu entri cache, atau null bila tidak ada.
  Future<CacheEntry?> cacheEntry(String key) async {
    return (db.select(
      db.cacheEntries,
    )..where((CacheEntries e) => e.key.equals(key))).getSingleOrNull();
  }

  /// Entri cache untuk satu lagu (semua itag yang pernah di-cache).
  /// videoId di-escape supaya `_` di dalamnya dibaca harfiah di LIKE.
  Future<List<CacheEntry>> cacheEntriesForVideo(String videoId) async {
    final String escaped = videoId
        .replaceAll(r'\', r'\\')
        .replaceAll('%', r'\%')
        .replaceAll('_', r'\_');
    final List<QueryRow> rows = await db
        .customSelect(
          'SELECT "key", file_path, size_bytes, last_accessed, created_at '
          "FROM cache_entries WHERE \"key\" LIKE ? ESCAPE '\\' ",
          variables: <Variable<Object>>[Variable<String>('${escaped}_%')],
          readsFrom: <TableInfo<Table, Object?>>{db.cacheEntries},
        )
        .get();
    return rows
        .map(
          (QueryRow r) => CacheEntry(
            key: r.read<String>('key'),
            filePath: r.read<String>('file_path'),
            sizeBytes: r.read<int>('size_bytes'),
            lastAccessed: r.read<DateTime>('last_accessed'),
            createdAt: r.read<DateTime>('created_at'),
          ),
        )
        .toList(growable: false);
  }

  /// Sisip atau ganti satu entri cache.
  Future<void> upsertCacheEntry(CacheEntriesCompanion entry) async {
    await db
        .into(db.cacheEntries)
        .insert(entry, mode: InsertMode.insertOrReplace);
  }

  /// Perbarui waktu akses terakhir entri cache (dipakai LRU).
  Future<void> touchCacheEntry(String key, DateTime now) async {
    await (db.update(
      db.cacheEntries,
    )..where((CacheEntries e) => e.key.equals(key))).write(
      CacheEntriesCompanion(lastAccessed: Value<DateTime>(now)),
    );
  }

  /// Hapus satu entri cache.
  Future<void> deleteCacheEntry(String key) async {
    await (db.delete(
      db.cacheEntries,
    )..where((CacheEntries e) => e.key.equals(key))).go();
  }

  /// Hapus beberapa entri cache sekaligus.
  Future<void> deleteCacheEntries(List<String> keys) async {
    if (keys.isEmpty) return;
    await (db.delete(
      db.cacheEntries,
    )..where((CacheEntries e) => e.key.isIn(keys))).go();
  }

  /// Entri cache urut akses terakhir (paling lama dulu) — urutan eviction
  /// LRU. [limit] 0 berarti semua.
  Future<List<CacheEntry>> cacheEntriesByLru({int limit = 0}) async {
    final SimpleSelectStatement<CacheEntries, CacheEntry> query =
        db.select(db.cacheEntries)
          ..orderBy(<OrderingTerm Function(CacheEntries)>[
            (CacheEntries e) => OrderingTerm(expression: e.lastAccessed),
            (CacheEntries e) => OrderingTerm(expression: e.key),
          ]);
    if (limit > 0) query.limit(limit);
    return query.get();
  }

  /// Semua entri cache (untuk rekonsiliasi).
  Future<List<CacheEntry>> allCacheEntries() async {
    return db.select(db.cacheEntries).get();
  }

  /// Hitungan penyimpanan dari database (PRD B3.3).
  Future<StorageStats> storageStats() async {
    final int downloadCount = await _count(
      'SELECT COUNT(*) AS c FROM songs WHERE download_state = '
      '${DownloadState.downloaded}',
    );
    final QueryRow downloadRow = await db
        .customSelect(
          'SELECT COALESCE(SUM(file_size_bytes), 0) AS s FROM songs '
          'WHERE download_state = ?',
          variables: <Variable<Object>>[
            Variable<int>(DownloadState.downloaded),
          ],
          readsFrom: <TableInfo<Table, Object?>>{db.songs},
        )
        .getSingle();
    final int playedSongsCount = await _count(
      'SELECT COUNT(*) AS c FROM cache_entries',
    );
    final QueryRow cacheRow = await db
        .customSelect(
          'SELECT COALESCE(SUM(size_bytes), 0) AS s FROM cache_entries',
          readsFrom: <TableInfo<Table, Object?>>{db.cacheEntries},
        )
        .getSingle();
    return StorageStats(
      downloadCount: downloadCount,
      downloadBytes: downloadRow.read<int>('s'),
      playedSongsCount: playedSongsCount,
      playedSongsBytes: cacheRow.read<int>('s'),
    );
  }
}
