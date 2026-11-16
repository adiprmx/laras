/// Impor playlist Spotify TANPA API Spotify (P8, PRD B10.1, Must #10).
///
/// LARANGAN MUTLAK (pelanggaran = penghenti rilis): app TIDAK BOLEH
/// memanggil api.spotify.com atau accounts.spotify.com; TIDAK BOLEH
/// client ID/secret/token Spotify; TIDAK BOLEH login Spotify; TIDAK
/// BOLEH library pembungkus Spotify Web API. Satu-satunya request ke
/// domain Spotify yang diizinkan adalah SATU pengambilan halaman publik
/// playlist yang dibagikan pengguna (jalur A), dan itu pun tidak
/// mengikuti redirect ke domain lain (lihat [_fetchPlaylistPage]).
///
/// Jalur B (UTAMA, aman, nol request ke Spotify): pengguna memilih atau
/// menempel file ekspor miliknya — teks "Artis - Judul" per baris, CSV,
/// atau JSON ekspor data Spotify. File dibaca lokal di HP.
///
/// Jalur A (SEKUNDER, berisiko): tautan playlist publik Spotify.
/// TERBUKTI 17 Nov 2026 dari VM (probe live, 2 playlist): halaman
/// open.spotify.com merender 30 baris lagu pertama di HTML statis
/// (`data-testid="track-row"` + `aria-label` judul +
/// `internal-artist-link`), tanpa login dan tanpa JavaScript. Batasan
/// yang dibuktikan probe: hanya 30 lagu pertama yang terbaca dari
/// halaman statis (lagu ke-31+ dimuat lewat JavaScript, yang TIDAK
/// dikejar app ini); struktur HTML bisa berubah sewaktu-waktu.
/// Keduanya dinyatakan jujur di UI (peringatan + saran pakai file).
/// Bila 0 lagu terbaca, jalur A gagal dengan pesan yang mengarahkan ke
/// jalur B — tidak ada tebakan, tidak ada percobaan login.
///
/// Pencocokan: tiap lagu dicari ke YouTube Music lewat
/// [OnlineSearchApi] yang sama dengan pencarian biasa. Padanan yakin =
/// judul DAN artis sama persis sesudah normalisasi (huruf kecil, tanpa
/// tanda baca, tanpa imbuhan dalam kurung, tanpa diakritik) di antara
/// 5 hasil teratas. Tidak ada padanan yakin = gagal dengan alasan
/// "tidak ditemukan"; app TIDAK PERNAH menebak diam-diam.
///
/// CATATAN vs PRD B10.1: pemilih kandidat ("sampai 3 kandidat, pengguna
/// memilih atau lewati") TIDAK masuk P8 sesuai scope yang ditugaskan
/// ("cocok -> masuk playlist baru; tidak cocok -> laporan gagal").
/// Alasan gagal `skipped` sudah ada di [ImportFailureReason] untuk
/// pekerjaan itu. Lagu yang tidak yakin di P8 dicatat gagal
/// "tidak ditemukan" — jujur, dan pengguna bisa menambahkannya manual.
library;

// ignore_for_file: prefer_initializing_formals - konstruktor
// SpotifyImportService memakai parameter publik `dio` + field privat
// `_dio` (Dio bawaan dibuat di [_http] dengan timeout +
// followRedirects:false); initializing formal akan membuat nama
// parameter menjadi privat dan tidak bisa dipakai pemanggil.

import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:drift/drift.dart';
import 'package:laras/data/database.dart';
import 'package:laras/extractor/extractor.dart';
import 'package:laras/features/search/search_service.dart';

import 'import_report.dart';

/// Batas ukuran halaman playlist Spotify yang dibaca jalur A (ukuran
/// nyata ~515 KB pada probe 17 Nov 2026; 2 MB memberi ruang longgar
/// tanpa membuka pintu DoS memori).
const int kSpotifyPageMaxBytes = 2 * 1024 * 1024;

/// Jumlah baris lagu yang dirender halaman statis Spotify (terbukti
/// probe: 30 di kedua playlist yang diuji).
const int kSpotifyLinkMaxTracks = 30;

/// Jeda antar pencarian pencocokan (sopan terhadap rate limit YTM).
const Duration kSpotifyMatchDelay = Duration(milliseconds: 150);

/// Jenis kegagalan jalur A (tautan playlist publik).
enum SpotifyLinkErrorKind {
  /// Bukan tautan playlist open.spotify.com yang valid.
  invalidUrl,

  /// Halaman tidak bisa diambil (jaringan, HTTP bukan 200, redirect ke
  /// domain lain, ukuran lewat batas).
  unreadable,

  /// Halaman terbaca tapi tidak ada lagu yang bisa diekstrak (struktur
  /// berubah / playlist kosong / butuh login).
  empty,
}

/// Kegagalan jalur A.
class SpotifyLinkException implements Exception {
  const SpotifyLinkException(this.kind, [this.detail]);

  final SpotifyLinkErrorKind kind;
  final String? detail;

  @override
  String toString() => 'SpotifyLinkException($kind${detail == null ? '' : ': $detail'})';
}

/// Kegagalan membaca file daftar lagu (jalur B).
class SpotifyFileException implements Exception {
  const SpotifyFileException(this.message);

  final String message;

  @override
  String toString() => 'SpotifyFileException($message)';
}

/// Satu lagu dari daftar Spotify (judul + artis, tanpa id).
class SpotifyTrackRef {
  const SpotifyTrackRef({required this.title, required this.artist});

  /// Judul lagu (wajib ada).
  final String title;

  /// Nama artis (bisa kosong bila daftar hanya membawa judul).
  final String artist;

  /// Label tampil: "Artis - Judul" atau judul saja.
  String get label => artist.isEmpty ? title : '$artist - $title';
}

/// Draf playlist hasil parse file/tautan, siap dicocokkan.
class SpotifyPlaylistDraft {
  const SpotifyPlaylistDraft({
    required this.tracks,
    this.name,
    this.truncated = false,
  });

  /// Nama playlist asal (dari file/tautan), atau null bila tidak
  /// diketahui (UI memakai nama bawaan).
  final String? name;

  final List<SpotifyTrackRef> tracks;

  /// True bila daftar ini terpotong (jalur A: hanya 30 lagu pertama
  /// yang terbaca dari halaman statis).
  final bool truncated;
}

/// Layanan impor playlist Spotify (jalur file + jalur tautan).
class SpotifyImportService {
  SpotifyImportService({
    required this.library,
    required this.api,
    Dio? dio,
    this.matchDelay = kSpotifyMatchDelay,
  }) : _dio = dio;

  final LibraryService library;

  /// API pencarian online (InnerTube). Dipakai LANGSUNG (bukan lewat
  /// [SearchService.search]) supaya kueri pencocokan TIDAK masuk
  /// riwayat pencarian pengguna.
  final OnlineSearchApi api;

  final Dio? _dio;
  final Duration matchDelay;

  Dio get _http =>
      _dio ??
      Dio(
        BaseOptions(
          connectTimeout: const Duration(seconds: 15),
          receiveTimeout: const Duration(seconds: 15),
          // Jangan ikuti redirect otomatis: redirect ke
          // accounts.spotify.com (login) adalah domain TERLARANG dan
          // tidak boleh disentuh app ini. Redirect ditangani manual
          // di [_fetchPlaylistPage] (hanya dalam open.spotify.com).
          followRedirects: false,
        ),
      );

  // ------------------------------------------------------------------
  // Jalur B: file / teks tempel
  // ------------------------------------------------------------------

  /// Parse file daftar lagu (teks/CSV/JSON) dari byte mentah.
  ///
  /// Format dideteksi dari ISI (bukan hanya ekstensi, karena pemilih
  /// file SAF tidak selalu memberi nama): JSON bila dimulai `[` atau
  /// `{`, CSV bila baris pertama tampak seperti header kolom, sisanya
  /// teks "Artis - Judul" per baris. Melempar [SpotifyFileException]
  /// bila tidak ada satu pun lagu yang terbaca.
  SpotifyPlaylistDraft parseFile(Uint8List bytes, {String? fileName}) {
    final String text;
    try {
      text = utf8.decode(bytes);
    } on FormatException {
      throw const SpotifyFileException('file bukan teks yang bisa dibaca');
    }
    final String trimmed = text.trim();
    if (trimmed.isEmpty) {
      throw const SpotifyFileException('file kosong');
    }
    final String? baseName = _baseNameWithoutExtension(fileName);
    if (trimmed.startsWith('[') || trimmed.startsWith('{')) {
      final SpotifyPlaylistDraft draft = parseSpotifyJson(trimmed);
      return SpotifyPlaylistDraft(
        tracks: draft.tracks,
        name: draft.name ?? baseName,
        truncated: draft.truncated,
      );
    }
    final List<String> lines = trimmed
        .split(RegExp(r'\r?\n'))
        .map((String l) => l.trim())
        .where((String l) => l.isNotEmpty)
        .toList(growable: false);
    if (lines.isNotEmpty && _looksLikeCsvHeader(lines.first)) {
      return SpotifyPlaylistDraft(
        tracks: parseSpotifyCsv(trimmed),
        name: baseName,
      );
    }
    // CSV tanpa header (dua kolom "Artis,Judul") dideteksi dari koma di
    // mayoritas baris — kalau tidak, perlakukan sebagai teks.
    if (lines.length >= 2 &&
        lines.where((String l) => l.contains(',')).length * 2 >=
            lines.length) {
      final List<SpotifyTrackRef> csv = parseSpotifyCsv(trimmed);
      if (csv.isNotEmpty) {
        return SpotifyPlaylistDraft(tracks: csv, name: baseName);
      }
    }
    return SpotifyPlaylistDraft(
      tracks: parseSpotifyText(trimmed),
      name: baseName,
    );
  }

  /// Parse teks tempelan "Artis - Judul" per baris.
  ///
  /// Baris tanpa pemisah dianggap judul saja (artis kosong). Penomoran
  /// awal ("1. ", "01) ") dibuang. Baris kosong dilewati.
  static List<SpotifyTrackRef> parseSpotifyText(String text) {
    final List<SpotifyTrackRef> out = <SpotifyTrackRef>[];
    for (final String rawLine in text.split(RegExp(r'\r?\n'))) {
      String line = rawLine.trim();
      if (line.isEmpty) continue;
      line = line.replaceFirst(RegExp(r'^\d{1,4}[.)]\s+'), '');
      if (line.isEmpty) continue;
      final int sep = _findArtistTitleSeparator(line);
      if (sep == -1) {
        out.add(SpotifyTrackRef(title: line, artist: ''));
      } else {
        final String artist = line.substring(0, sep).trim();
        final String title = line.substring(sep + 3).trim();
        if (title.isEmpty) {
          out.add(SpotifyTrackRef(title: artist, artist: ''));
        } else {
          out.add(SpotifyTrackRef(title: title, artist: artist));
        }
      }
    }
    if (out.isEmpty) {
      throw const SpotifyFileException('tidak ada lagu yang terbaca');
    }
    return out;
  }

  /// Indeks pemisah " - " (atau en/em dash ber-spasi) pertama, atau -1.
  /// Pemisah di DALAM judul ("Judul - Remix") tidak bisa dibedakan dari
  /// pemisah artis-judul; pemisah pertama yang dipakai (sesuai format
  /// "Artis - Judul").
  static int _findArtistTitleSeparator(String line) {
    const List<String> separators = <String>[' - ', ' – ', ' — '];
    int best = -1;
    for (final String sep in separators) {
      final int index = line.indexOf(sep);
      if (index != -1 && (best == -1 || index < best)) best = index;
    }
    return best;
  }

  /// Parse CSV daftar lagu.
  ///
  /// Header dikenali bila memuat kolom artis (mengandung "artist") DAN
  /// kolom judul (mengandung "track", "title", "song", atau "name").
  /// Tanpa header, dua kolom dibaca sebagai (artis, judul). Parser CSV
  /// kecil ini menangani tanda kutip + koma di dalam kutip (tanpa
  /// dependensi baru — kebutuhan P8 hanya ini).
  static List<SpotifyTrackRef> parseSpotifyCsv(String text) {
    final List<List<String>> rows = _parseCsvRows(text);
    if (rows.isEmpty) {
      throw const SpotifyFileException('tidak ada lagu yang terbaca');
    }
    int artistCol = -1;
    int titleCol = -1;
    int start = 0;
    final List<String> header = rows.first
        .map((String c) => c.trim().toLowerCase())
        .toList(growable: false);
    for (int i = 0; i < header.length; i++) {
      final String col = header[i];
      if (col.contains('artist')) artistCol = i;
      if (col.contains('track') ||
          col.contains('title') ||
          col.contains('song') ||
          col == 'name') {
        titleCol = i;
      }
    }
    if (artistCol != -1 && titleCol != -1) {
      start = 1;
    } else if (rows.first.length >= 2) {
      artistCol = 0;
      titleCol = 1;
    } else {
      throw const SpotifyFileException('tidak ada lagu yang terbaca');
    }
    final List<SpotifyTrackRef> out = <SpotifyTrackRef>[];
    for (int r = start; r < rows.length; r++) {
      final List<String> row = rows[r];
      if (row.length <= titleCol) continue;
      final String title = row[titleCol].trim();
      if (title.isEmpty) continue;
      final String artist = artistCol < row.length
          ? row[artistCol].trim()
          : '';
      out.add(SpotifyTrackRef(title: title, artist: artist));
    }
    if (out.isEmpty) {
      throw const SpotifyFileException('tidak ada lagu yang terbaca');
    }
    return out;
  }

  static bool _looksLikeCsvHeader(String firstLine) {
    final String lower = firstLine.toLowerCase();
    final bool hasArtist = lower.contains('artist');
    final bool hasTitle =
        lower.contains('track') ||
        lower.contains('title') ||
        lower.contains('song') ||
        lower.contains('name');
    return hasArtist && hasTitle && firstLine.contains(',');
  }

  /// Parser CSV minimal: koma pemisah, kutip ganda escape (`""`),
  /// newline di dalam kutip didukung.
  static List<List<String>> _parseCsvRows(String text) {
    final List<List<String>> rows = <List<String>>[];
    final List<String> current = <String>[];
    final StringBuffer field = StringBuffer();
    bool inQuotes = false;
    for (int i = 0; i < text.length; i++) {
      final String ch = text[i];
      if (inQuotes) {
        if (ch == '"') {
          if (i + 1 < text.length && text[i + 1] == '"') {
            field.write('"');
            i++;
          } else {
            inQuotes = false;
          }
        } else {
          field.write(ch);
        }
      } else if (ch == '"') {
        inQuotes = true;
      } else if (ch == ',') {
        current.add(field.toString());
        field.clear();
      } else if (ch == '\n') {
        current.add(field.toString());
        field.clear();
        rows.add(List<String>.from(current));
        current.clear();
      } else if (ch != '\r') {
        field.write(ch);
      }
    }
    if (field.isNotEmpty || current.isNotEmpty) {
      current.add(field.toString());
      rows.add(List<String>.from(current));
    }
    return rows
        .where(
          (List<String> row) =>
              row.any((String cell) => cell.trim().isNotEmpty),
        )
        .toList(growable: false);
  }

  /// Parse JSON ekspor data Spotify.
  ///
  /// Bentuk yang diterima (semuanya dibaca lokal, tanpa request):
  /// - Daftar langsung: `[{"Track Name": "...", "Artist Name(s)": "..."}]`
  ///   (format Exportify / ekspor playlist umum) atau
  ///   `[{"name": "...", "artists": [{"name": "..."}]}]`.
  /// - Objek pembungkus: `{"tracks": [...]}` atau
  ///   `{"playlist": {"name": "...", "tracks": [...]}}`.
  /// - Item terbungkus: `{"track": {"name": ..., "artists": [...]}}`
  ///   (format unduhan data akun Spotify / YourLibrary).
  /// Judul dibaca dari `Track Name` / `name` / `title` / `track`;
  /// artis dari `Artist Name(s)` / `artists` (daftar nama atau daftar
  /// objek `{name}`) / `artist`. Nama playlist dari `name` /
  /// `playlistName` di objek pembungkus.
  static SpotifyPlaylistDraft parseSpotifyJson(String text) {
    final Object? decoded;
    try {
      decoded = jsonDecode(text);
    } on FormatException {
      throw const SpotifyFileException('file JSON tidak bisa dibaca');
    }
    String? playlistName;
    List<Object?> items;
    if (decoded is List) {
      items = decoded.cast<Object?>();
    } else if (decoded is Map<String, Object?>) {
      final Object? playlist = decoded['playlist'];
      final Map<String, Object?> holder =
          playlist is Map<String, Object?> ? playlist : decoded;
      final Object? name = holder['name'] ?? holder['playlistName'];
      if (name is String && name.trim().isNotEmpty) {
        playlistName = name.trim();
      }
      final Object? tracks = holder['tracks'];
      if (tracks is! List) {
        throw const SpotifyFileException(
          'file JSON ini tidak berisi daftar lagu',
        );
      }
      items = tracks.cast<Object?>();
    } else {
      throw const SpotifyFileException('file JSON ini tidak berisi daftar lagu');
    }
    final List<SpotifyTrackRef> out = <SpotifyTrackRef>[];
    for (final Object? item in items) {
      final SpotifyTrackRef? ref = _spotifyJsonTrack(item);
      if (ref != null) out.add(ref);
    }
    if (out.isEmpty) {
      throw const SpotifyFileException('tidak ada lagu yang terbaca');
    }
    return SpotifyPlaylistDraft(tracks: out, name: playlistName);
  }

  static SpotifyTrackRef? _spotifyJsonTrack(Object? item) {
    if (item is! Map<String, Object?>) return null;
    Map<String, Object?> track = item;
    final Object? wrapped = item['track'];
    if (wrapped is Map<String, Object?>) track = wrapped;
    String title = '';
    for (final String key in <String>[
      'Track Name',
      'name',
      'title',
      'track',
    ]) {
      final Object? value = track[key];
      if (value is String && value.trim().isNotEmpty) {
        title = value.trim();
        break;
      }
    }
    if (title.isEmpty) return null;
    String artist = '';
    final Object? artists = track['artists'] ?? track['Artist Name(s)'];
    if (artists is String) {
      artist = artists.trim();
    } else if (artists is List) {
      final List<String> names = <String>[];
      for (final Object? a in artists) {
        if (a is String && a.trim().isNotEmpty) {
          names.add(a.trim());
        } else if (a is Map<String, Object?>) {
          final Object? n = a['name'];
          if (n is String && n.trim().isNotEmpty) names.add(n.trim());
        }
      }
      artist = names.join(', ');
    }
    if (artist.isEmpty) {
      final Object? single = track['artist'];
      if (single is String) artist = single.trim();
    }
    return SpotifyTrackRef(title: title, artist: artist);
  }

  static String? _baseNameWithoutExtension(String? fileName) {
    if (fileName == null) return null;
    String base = fileName.trim();
    final int slash = base.lastIndexOf('/');
    if (slash != -1) base = base.substring(slash + 1);
    final int dot = base.lastIndexOf('.');
    if (dot > 0) base = base.substring(0, dot);
    base = base.trim();
    return base.isEmpty ? null : base;
  }

  // ------------------------------------------------------------------
  // Jalur A: tautan playlist publik
  // ------------------------------------------------------------------

  /// Ambil daftar lagu dari tautan playlist publik Spotify (jalur A).
  ///
  /// SATU request GET ke URL yang ditempel pengguna, setelah validasi
  /// ketat (hanya `https://open.spotify.com/playlist/<id>`).
  /// Redirect tidak diikuti otomatis dan tidak pernah ke luar
  /// open.spotify.com. Melempar [SpotifyLinkException] bila tautan
  /// tidak valid, halaman tidak bisa dibaca, atau tidak ada lagu yang
  /// terbaca (UI mengarahkan ke jalur file).
  Future<SpotifyPlaylistDraft> fetchFromLink(String rawUrl) async {
    final Uri uri = validateSpotifyPlaylistUrl(rawUrl);
    final String html = await _fetchPlaylistPage(uri);
    final SpotifyPlaylistDraft draft = parseSpotifyPlaylistHtml(html);
    if (draft.tracks.isEmpty) {
      throw const SpotifyLinkException(
        SpotifyLinkErrorKind.empty,
        'tidak ada baris lagu di halaman',
      );
    }
    return draft;
  }

  /// Validasi tautan playlist Spotify. Mengembalikan URI yang
  /// dinormalisasi (tanpa query/fragment). Melempar
  /// [SpotifyLinkException] jenis [SpotifyLinkErrorKind.invalidUrl]
  /// untuk host/path/id apa pun di luar bentuk yang diizinkan —
  /// termasuk api.spotify.com dan accounts.spotify.com (TERLARANG).
  static Uri validateSpotifyPlaylistUrl(String rawUrl) {
    final Uri? uri = Uri.tryParse(rawUrl.trim());
    final List<String> segments = uri?.pathSegments ?? const <String>[];
    final bool valid =
        uri != null &&
        uri.scheme == 'https' &&
        uri.host == 'open.spotify.com' &&
        segments.length == 2 &&
        segments[0] == 'playlist' &&
        RegExp(r'^[A-Za-z0-9]{22}$').hasMatch(segments[1]);
    if (!valid) {
      throw const SpotifyLinkException(
        SpotifyLinkErrorKind.invalidUrl,
        'bukan tautan playlist open.spotify.com',
      );
    }
    return Uri.https('open.spotify.com', '/playlist/${segments[1]}');
  }

  Future<String> _fetchPlaylistPage(Uri uri, {int depth = 0}) async {
    final Dio dio = _http;
    final ResponseSizeCap cap = ResponseSizeCap(kSpotifyPageMaxBytes);
    try {
      final Response<String> response = await dio.getUri<String>(
        uri,
        options: Options(
          responseType: ResponseType.plain,
          headers: <String, String>{
            // UA browser Android (sama dengan probe 17 Nov 2026):
            // Spotify merender daftar lagu di HTML untuk UA ini.
            'User-Agent':
                'Mozilla/5.0 (Linux; Android 13; Pixel 7) '
                'AppleWebKit/537.36 (KHTML, like Gecko) '
                'Chrome/120.0 Mobile Safari/537.36',
            'Accept-Language': 'id-ID,id;q=0.9,en;q=0.8',
          },
          // Redirect manual: hanya dalam open.spotify.com (mis.
          // penambahan locale). Redirect ke host lain = tolak.
          followRedirects: false,
          validateStatus: (int? status) =>
              status != null && status >= 200 && status < 400,
        ),
        cancelToken: cap.cancelToken,
        onReceiveProgress: cap.onReceiveProgress,
      );
      final int? status = response.statusCode;
      if (status != null && status >= 300 && status < 400) {
        final String? location = response.headers.value('location');
        final Uri? next = location == null
            ? null
            : Uri.tryParse(location);
        if (depth < 2 &&
            next != null &&
            next.scheme == 'https' &&
            next.host == 'open.spotify.com' &&
            next.pathSegments.length == 2 &&
            next.pathSegments[0] == 'playlist') {
          return await _fetchPlaylistPage(
            Uri.https('open.spotify.com', next.path),
            depth: depth + 1,
          );
        }
        throw const SpotifyLinkException(
          SpotifyLinkErrorKind.unreadable,
          'redirect ke luar halaman playlist',
        );
      }
      if (status != 200) {
        throw SpotifyLinkException(
          SpotifyLinkErrorKind.unreadable,
          'HTTP $status',
        );
      }
      final String? body = response.data;
      if (body == null || body.isEmpty) {
        throw const SpotifyLinkException(
          SpotifyLinkErrorKind.unreadable,
          'halaman kosong',
        );
      }
      return body;
    } on SpotifyLinkException {
      rethrow;
    } on DioException catch (e) {
      if (cap.exceeded) {
        throw const SpotifyLinkException(
          SpotifyLinkErrorKind.unreadable,
          'halaman melebihi batas ukuran',
        );
      }
      throw SpotifyLinkException(
        SpotifyLinkErrorKind.unreadable,
        'Dio ${e.type}',
      );
    }
  }

  /// Ekstrak nama playlist + daftar lagu dari HTML halaman playlist
  /// publik Spotify (fungsi murni — diuji dengan fixture HTML asli).
  ///
  /// Jangkar yang dipakai (terbukti di 2 playlist, 17 Nov 2026):
  /// - Nama: `<meta property="og:title" content="...">` (fallback:
  ///   `<title>Nama | Spotify Playlist</title>`).
  /// - Tiap lagu: `aria-label="<Judul>" data-testid="track-row">`
  ///   + `<span data-testid="internal-artist-link"><a ...>Artis</a>`
  ///   pertama SESUDAH baris itu (sebelum baris berikut).
  /// Entitas HTML (`&#x27;`, `&amp;`, dsb.) di-decode. Baris tanpa judul
  /// dilewati. Hasil dibatasi [kSpotifyLinkMaxTracks] (halaman statis
  /// hanya merender 30 baris pertama); [SpotifyPlaylistDraft.truncated]
  /// true bila batas itu tercapai.
  static SpotifyPlaylistDraft parseSpotifyPlaylistHtml(String html) {
    String? name;
    final RegExpMatch? ogTitle = RegExp(
      r'<meta\s+property="og:title"\s+content="([^"]*)"',
    ).firstMatch(html);
    if (ogTitle != null) {
      final String decoded = _decodeHtmlEntities(ogTitle.group(1)!).trim();
      if (decoded.isNotEmpty) name = decoded;
    }
    name ??= _titleTagName(html);
    final List<RegExpMatch> markers = RegExp(
      r'data-testid="track-row"',
    ).allMatches(html).toList(growable: false);
    final List<SpotifyTrackRef> tracks = <SpotifyTrackRef>[];
    for (int i = 0; i < markers.length; i++) {
      final RegExpMatch marker = markers[i];
      // Judul: aria-label terakhir dalam 600 karakter SEBELUM marker
      // (aria-label ada di tag pembuka baris yang sama).
      final int titleFrom = (marker.start - 600).clamp(0, marker.start);
      final String before = html.substring(titleFrom, marker.start);
      final List<RegExpMatch> labels = RegExp(
        r'aria-label="([^"]+)"',
      ).allMatches(before).toList(growable: false);
      if (labels.isEmpty) continue;
      final String title = _decodeHtmlEntities(
        labels.last.group(1)!,
      ).trim();
      if (title.isEmpty) continue;
      // Artis: tautan artis pertama SESUDAH marker, sebelum marker
      // baris berikut (atau maks 8.000 karakter — baris tidak sepanjang
      // itu; batas ini mencegah "mencuri" artis baris berikut bila satu
      // baris tidak punya tautan artis).
      final int bodyStart = marker.end;
      final int bodyEnd = i + 1 < markers.length
          ? markers[i + 1].start
          : (bodyStart + 8000).clamp(0, html.length);
      final String body = html.substring(bodyStart, bodyEnd);
      final RegExpMatch? artistMatch = RegExp(
        r'data-testid="internal-artist-link"><a[^>]*>([^<]+)</a>',
      ).firstMatch(body);
      final String artist = artistMatch == null
          ? ''
          : _decodeHtmlEntities(artistMatch.group(1)!).trim();
      tracks.add(SpotifyTrackRef(title: title, artist: artist));
      if (tracks.length >= kSpotifyLinkMaxTracks) break;
    }
    return SpotifyPlaylistDraft(
      tracks: tracks,
      name: name,
      truncated: tracks.length >= kSpotifyLinkMaxTracks,
    );
  }

  static String? _titleTagName(String html) {
    final RegExpMatch? match = RegExp(
      r'<title>([^<]*)</title>',
    ).firstMatch(html);
    if (match == null) return null;
    String title = _decodeHtmlEntities(match.group(1)!).trim();
    const String suffix = ' | Spotify Playlist';
    if (title.endsWith(suffix)) {
      title = title.substring(0, title.length - suffix.length).trim();
    }
    return title.isEmpty ? null : title;
  }

  /// Decode entitas HTML yang muncul di judul/artis Spotify: named
  /// umum (`&amp;` `&quot;` `&lt;` `&gt;` `&#39;`) + numerik desimal
  /// (`&#39;`) dan hex (`&#x27;`). Entitas tak dikenal dibiarkan apa
  /// adanya (lebih aman daripada menebak).
  static String _decodeHtmlEntities(String raw) {
    String out = raw
        .replaceAll('&amp;', '&')
        .replaceAll('&quot;', '"')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&#39;', "'")
        .replaceAll('&apos;', "'");
    out = out.replaceAllMapped(RegExp(r'&#x([0-9a-fA-F]+);'), (Match m) {
      final int? code = int.tryParse(m.group(1)!, radix: 16);
      if (code == null || code <= 0 || code > 0x10FFFF) return m.group(0)!;
      return String.fromCharCode(code);
    });
    out = out.replaceAllMapped(RegExp(r'&#([0-9]+);'), (Match m) {
      final int? code = int.tryParse(m.group(1)!);
      if (code == null || code <= 0 || code > 0x10FFFF) return m.group(0)!;
      return String.fromCharCode(code);
    });
    return out;
  }

  // ------------------------------------------------------------------
  // Pencocokan ke YouTube Music + pembuatan playlist
  // ------------------------------------------------------------------

  /// Cocokkan [draft] ke YouTube Music lalu buat satu playlist baru.
  ///
  /// Aturan padanan yakin: judul DAN artis sama persis sesudah
  /// normalisasi, di antara 5 hasil teratas. Lagu yang tidak cocok
  /// masuk [ImportReport.failures] dengan alasan `notFound`. Playlist
  /// TIDAK dibuat bila tidak ada satu pun lagu yang cocok (PRD B10.4).
  /// Lagu yang sudah dicocokkan TETAP tersimpan bila pengguna
  /// membatalkan ([isCancelled] true) atau jaringan putus di tengah —
  /// sisanya dicatat gagal (`cancelled` / `network`).
  ///
  /// [onProgress] dipanggil sesudah tiap lagu (done, total) untuk
  /// indikator progres UI. [playlistName] adalah nama playlist baru
  /// (UI menyediakan kolom nama; pemanggil wajib memberi nama yang
  /// sudah divalidasi tak kosong).
  Future<ImportReport> importDraft(
    SpotifyPlaylistDraft draft, {
    required String playlistName,
    void Function(int done, int total)? onProgress,
    bool Function()? isCancelled,
  }) async {
    final int total = draft.tracks.length;
    int succeeded = 0;
    int alreadyExisted = 0;
    final List<ImportFailure> failures = <ImportFailure>[];
    final List<SearchSong> matched = <SearchSong>[];
    bool stopped = false;
    for (int i = 0; i < total; i++) {
      if (isCancelled?.call() ?? false) {
        for (int j = i; j < total; j++) {
          failures.add(
            ImportFailure(
              label: draft.tracks[j].label,
              reason: ImportFailureReason.cancelled,
            ),
          );
        }
        stopped = true;
        break;
      }
      final SpotifyTrackRef ref = draft.tracks[i];
      try {
        final GroupedSearchResults results = await api.search(
          ref.artist.isEmpty ? ref.title : '${ref.artist} ${ref.title}',
        );
        final SearchSong? match = _findConfidentMatch(results, ref);
        if (match == null) {
          failures.add(
            ImportFailure(
              label: ref.label,
              reason: ImportFailureReason.notFound,
            ),
          );
        } else if (matched.any(
          (SearchSong m) => m.videoId == match.videoId,
        )) {
          alreadyExisted++;
        } else {
          matched.add(match);
        }
      } on ExtractorException catch (e) {
        if (e.isNetworkError) {
          // Jaringan putus: berhenti; sisanya gagal `network`.
          // Lagu yang sudah cocok tetap disimpan di bawah.
          failures.add(
            ImportFailure(
              label: ref.label,
              reason: ImportFailureReason.network,
            ),
          );
          for (int j = i + 1; j < total; j++) {
            failures.add(
              ImportFailure(
                label: draft.tracks[j].label,
                reason: ImportFailureReason.network,
              ),
            );
          }
          stopped = true;
          break;
        }
        failures.add(
          ImportFailure(
            label: ref.label,
            reason: ImportFailureReason.searchFailed,
          ),
        );
      } on Object catch (_) {
        failures.add(
          ImportFailure(
            label: ref.label,
            reason: ImportFailureReason.searchFailed,
          ),
        );
      }
      onProgress?.call(i + 1, total);
      if (!stopped && i + 1 < total && matchDelay > Duration.zero) {
        await Future<void>.delayed(matchDelay);
      }
    }
    int? playlistId;
    if (matched.isNotEmpty) {
      playlistId = await library.createPlaylist(playlistName);
      for (final SearchSong song in matched) {
        await library.upsertSong(
          SongsCompanion(
            id: Value<String>(song.videoId),
            title: Value<String>(song.title),
            durationSeconds: Value<int?>(song.durationSeconds),
            thumbnailUrl: Value<String?>(song.thumbnailUrl),
          ),
          artistNames: song.artist == null ? const <String>[] : <String>[song.artist!],
          artistChannelIds: song.artistChannelId == null
              ? const <String?>[]
              : <String?>[song.artistChannelId],
          album: song.albumBrowseId == null || song.album == null
              ? null
              : AlbumsCompanion(
                  id: Value<String>(song.albumBrowseId!),
                  title: Value<String>(song.album!),
                ),
          addToLibrary: true,
        );
        final bool added = await library.addSongToPlaylist(
          playlistId,
          song.videoId,
        );
        if (added) {
          succeeded++;
        } else {
          alreadyExisted++;
        }
      }
    }
    return ImportReport(
      succeeded: succeeded,
      alreadyExisted: alreadyExisted,
      failures: failures,
      playlistId: playlistId,
      playlistName: matched.isEmpty ? null : playlistName,
    );
  }

  /// Padanan yakin di antara 5 hasil teratas: judul sama persis DAN
  /// artis sama persis sesudah normalisasi. Bila daftar tidak membawa
  /// artis, judul saja yang dicocokkan.
  static SearchSong? _findConfidentMatch(
    GroupedSearchResults results,
    SpotifyTrackRef ref,
  ) {
    final String wantTitle = normalizeTrackText(ref.title);
    final String wantArtist = normalizeTrackText(ref.artist);
    if (wantTitle.isEmpty) return null;
    for (final SearchSong song in results.songs.take(5)) {
      if (normalizeTrackText(song.title) != wantTitle) continue;
      if (wantArtist.isEmpty) return song;
      final List<String> artists = (song.artist ?? '')
          .split(',')
          .map(normalizeTrackText)
          .toList(growable: false);
      if (artists.contains(wantArtist)) return song;
    }
    return null;
  }

  /// Normalisasi untuk pencocokan: huruf kecil, imbuhan dalam kurung /
  /// kurung siku di akhir dibuang ("(Official Video)", "[Remastered]"),
  /// diakritik Latin dilipat (é -> e), tanda baca + spasi berlebih
  /// dibuang. Dua judul yang sama isinya tapi beda ejaan ringan
  /// ("Beyoncé" vs "Beyonce") tetap cocok.
  static String normalizeTrackText(String raw) {
    String text = raw.toLowerCase().trim();
    // Buang imbuhan dalam kurung di akhir, berulang (judul bisa punya
    // dua: "Judul (Remastered) [Official Video]").
    while (true) {
      final String trimmed = text
          .replaceAll(RegExp(r'\s*\([^()]*\)\s*$'), '')
          .replaceAll(RegExp(r'\s*\[[^\[\]]*\]\s*$'), '')
          .trim();
      if (trimmed == text) break;
      text = trimmed;
    }
    const Map<String, String> folds = <String, String>{
      'à': 'a',
      'á': 'a',
      'â': 'a',
      'ã': 'a',
      'ä': 'a',
      'å': 'a',
      'æ': 'ae',
      'ç': 'c',
      'è': 'e',
      'é': 'e',
      'ê': 'e',
      'ë': 'e',
      'ì': 'i',
      'í': 'i',
      'î': 'i',
      'ï': 'i',
      'ñ': 'n',
      'ò': 'o',
      'ó': 'o',
      'ô': 'o',
      'õ': 'o',
      'ö': 'o',
      'ø': 'o',
      'ù': 'u',
      'ú': 'u',
      'û': 'u',
      'ü': 'u',
      'ý': 'y',
      'ÿ': 'y',
      'ß': 'ss',
      'ł': 'l',
      'đ': 'd',
      'ş': 's',
      'ğ': 'g',
      'ı': 'i',
    };
    final StringBuffer folded = StringBuffer();
    for (final int unit in text.runes) {
      final String ch = String.fromCharCode(unit);
      folded.write(folds[ch] ?? ch);
    }
    return folded
        .toString()
        .replaceAll(RegExp(r'[^\p{L}\p{N}]+', unicode: true), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }
}
