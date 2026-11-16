/// Tes LyricsService (P7): cache database dulu, LRCLIB bila belum ada,
/// cache negatif in-memory, dan pemetaan error.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:laras/data/database.dart';
import 'package:laras/features/lyrics/lrclib_client.dart';
import 'package:laras/features/lyrics/lyrics_service.dart';
import 'package:laras/player/track.dart';

import '../../data/test_database.dart';
import '../../player/fakes.dart';

/// Client LRCLIB palsu: hasil/error dikendalikan tes.
class FakeLrclibClient extends LrclibClient {
  FakeLrclibClient({this.result, this.error});

  final LrclibTrack? result;
  final LrclibException? error;
  int fetchCount = 0;

  @override
  Future<LrclibTrack?> fetchLyrics({
    required String artist,
    required String title,
    String? album,
    Duration? duration,
  }) async {
    fetchCount++;
    if (error != null) throw error!;
    return result;
  }
}

const LrclibTrack kFoundTrack = LrclibTrack(
  id: 1,
  plainLyrics: 'Lirik polos',
  syncedLyrics: '[00:01.00]Lirik sinkron',
);

void main() {
  late LarasDatabase db;
  late LibraryService library;

  setUp(() {
    (db, library) = createTestLibrary();
  });

  tearDown(() async {
    await db.close();
  });

  group('LyricsService.fetch', () {
    test('cache database dipakai, client tidak dipanggil', () async {
      final Track track = testTrack('abc');
      await library.upsertSong(
        track.toSongsCompanion(),
        artistNames: track.artistNames,
      );
      await library.saveLyrics(
        songId: 'abc',
        lyrics: 'Dari cache',
        syncedLyrics: '[00:01.00]Dari cache',
      );
      final FakeLrclibClient client = FakeLrclibClient(result: kFoundTrack);
      final LyricsService service = LyricsService(
        client: client,
        library: library,
      );
      final LyricsResult result = await service.fetch(track);
      expect(result.status, LyricsStatus.found);
      expect(result.plainLyrics, 'Dari cache');
      expect(result.syncedLyrics, '[00:01.00]Dari cache');
      expect(client.fetchCount, 0);
    });

    test('cache miss mengambil dari client lalu menyimpan ke database',
        () async {
      final Track track = testTrack('abc');
      final FakeLrclibClient client = FakeLrclibClient(result: kFoundTrack);
      final LyricsService service = LyricsService(
        client: client,
        library: library,
      );
      final LyricsResult result = await service.fetch(track);
      expect(result.status, LyricsStatus.found);
      expect(result.plainLyrics, 'Lirik polos');
      expect(result.hasSynced, isTrue);
      expect(client.fetchCount, 1);
      // Tersimpan: fetch kedua memakai cache (client tidak dipanggil lagi).
      final LyricsResult again = await service.fetch(track);
      expect(again.status, LyricsStatus.found);
      expect(client.fetchCount, 1);
      final Lyric? saved = await library.getLyrics('abc');
      expect(saved, isNotNull);
      expect(saved!.lyrics, 'Lirik polos');
    });

    test('tidak ditemukan dicatat in-memory (client tidak ditanya lagi)',
        () async {
      final Track track = testTrack('abc');
      final FakeLrclibClient client = FakeLrclibClient(result: null);
      final LyricsService service = LyricsService(
        client: client,
        library: library,
      );
      expect((await service.fetch(track)).status, LyricsStatus.notFound);
      expect((await service.fetch(track)).status, LyricsStatus.notFound);
      expect(client.fetchCount, 1);
      // Tidak disimpan ke database (supaya sesi berikut bisa menemukan
      // lirik yang baru ditambahkan LRCLIB).
      expect(await library.getLyrics('abc'), isNull);
    });

    test('instrumental dilaporkan + dicatat in-memory', () async {
      final Track track = testTrack('abc');
      final FakeLrclibClient client = FakeLrclibClient(
        result: const LrclibTrack(id: 2, instrumental: true),
      );
      final LyricsService service = LyricsService(
        client: client,
        library: library,
      );
      expect(
        (await service.fetch(track)).status,
        LyricsStatus.instrumental,
      );
      expect(
        (await service.fetch(track)).status,
        LyricsStatus.instrumental,
      );
      expect(client.fetchCount, 1);
    });

    test('error jaringan dilaporkan offline dan TIDAK dicatat negatif',
        () async {
      final Track track = testTrack('abc');
      final FakeLrclibClient client = FakeLrclibClient(
        error: const LrclibException(LrclibFailureKind.network),
      );
      final LyricsService service = LyricsService(
        client: client,
        library: library,
      );
      expect((await service.fetch(track)).status, LyricsStatus.offline);
      expect((await service.fetch(track)).status, LyricsStatus.offline);
      expect(client.fetchCount, 2);
    });

    test('rate limit dilaporkan error', () async {
      final Track track = testTrack('abc');
      final FakeLrclibClient client = FakeLrclibClient(
        error: const LrclibException(LrclibFailureKind.rateLimited),
      );
      final LyricsService service = LyricsService(
        client: client,
        library: library,
      );
      expect((await service.fetch(track)).status, LyricsStatus.error);
    });

    test('tanpa nama artis langsung notFound tanpa memanggil client',
        () async {
      const Track track = Track(videoId: 'abc', title: 'Tanpa Artis');
      final FakeLrclibClient client = FakeLrclibClient(result: kFoundTrack);
      final LyricsService service = LyricsService(
        client: client,
        library: library,
      );
      expect((await service.fetch(track)).status, LyricsStatus.notFound);
      expect(client.fetchCount, 0);
    });

    test('tanpa database tetap jalan fetch-only', () async {
      final Track track = testTrack('abc');
      final FakeLrclibClient client = FakeLrclibClient(result: kFoundTrack);
      final LyricsService service = LyricsService(client: client);
      final LyricsResult result = await service.fetch(track);
      expect(result.status, LyricsStatus.found);
      expect(result.plainLyrics, 'Lirik polos');
    });

    test('hasil hanya-tersinkron tersimpan dengan lirik polos kosong',
        () async {
      final Track track = testTrack('abc');
      final FakeLrclibClient client = FakeLrclibClient(
        result: const LrclibTrack(
          id: 3,
          syncedLyrics: '[00:01.00]Hanya sinkron',
        ),
      );
      final LyricsService service = LyricsService(
        client: client,
        library: library,
      );
      final LyricsResult result = await service.fetch(track);
      expect(result.status, LyricsStatus.found);
      expect(result.plainLyrics, isNull);
      expect(result.hasSynced, isTrue);
      final Lyric? saved = await library.getLyrics('abc');
      expect(saved, isNotNull);
      expect(saved!.lyrics, '');
      expect(saved.syncedLyrics, '[00:01.00]Hanya sinkron');
    });

    test('dua fetch bersamaan hanya memanggil client sekali (dedup)',
        () async {
      final Track track = testTrack('abc');
      final FakeLrclibClient client = FakeLrclibClient(result: kFoundTrack);
      final LyricsService service = LyricsService(
        client: client,
        library: library,
      );
      final List<LyricsResult> results = await Future.wait(<Future<LyricsResult>>[
        service.fetch(track),
        service.fetch(track),
      ]);
      expect(results[0].status, LyricsStatus.found);
      expect(results[1].status, LyricsStatus.found);
      expect(client.fetchCount, 1);
    });
  });

  group('LyricsService: batas lirik yang disimpan (R3-L1)', () {
    test('lirik tersinkron raksasa (>256 KB) tidak disimpan ke database',
        () async {
      // Tanpa cap, layanan lama menyimpan lirik 300 KB ke DB — tes ini
      // GAGAL sebelum perbaikan R3-L1 dan LOLOS sesudahnya.
      final Track track = testTrack('abc');
      final FakeLrclibClient client = FakeLrclibClient(
        result: LrclibTrack(
          id: 9,
          plainLyrics: 'Pendek',
          syncedLyrics: 'x' * (300 * 1024),
        ),
      );
      final LyricsService service = LyricsService(
        client: client,
        library: library,
      );
      final LyricsResult result = await service.fetch(track);
      expect(result.status, LyricsStatus.found);
      expect(result.hasSynced, isTrue);
      // Lirik tetap tampil, tapi tidak disimpan (DB tidak bertambah).
      expect(await library.getLyrics('abc'), isNull);
    });

    test('lirik polos raksasa (>256 KB) tidak disimpan ke database',
        () async {
      final Track track = testTrack('abc');
      final FakeLrclibClient client = FakeLrclibClient(
        result: LrclibTrack(id: 10, plainLyrics: 'y' * (300 * 1024)),
      );
      final LyricsService service = LyricsService(
        client: client,
        library: library,
      );
      final LyricsResult result = await service.fetch(track);
      expect(result.status, LyricsStatus.found);
      expect(await library.getLyrics('abc'), isNull);
    });

    test('lirik tepat di batas 256 KB masih disimpan', () async {
      final Track track = testTrack('abc');
      final FakeLrclibClient client = FakeLrclibClient(
        result: LrclibTrack(id: 11, plainLyrics: 'z' * (256 * 1024)),
      );
      final LyricsService service = LyricsService(
        client: client,
        library: library,
      );
      final LyricsResult result = await service.fetch(track);
      expect(result.status, LyricsStatus.found);
      final Lyric? saved = await library.getLyrics('abc');
      expect(saved, isNotNull);
      expect(saved!.lyrics.length, 256 * 1024);
    });
  });
}
