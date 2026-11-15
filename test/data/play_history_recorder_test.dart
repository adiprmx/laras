/// Tes pencatat riwayat putar: ambang 10 detik, lagu selesai, seek.
library;


import 'package:flutter_test/flutter_test.dart';
import 'package:laras/data/database.dart';
import 'package:laras/player/player.dart';

import '../player/fakes.dart';
import 'test_database.dart';

void main() {
  late LarasDatabase db;
  late LibraryService service;
  late FakeAudioPlayerPort port;
  late PlayHistoryRecorder recorder;

  setUp(() {
    (db, service) = createTestLibrary();
    port = FakeAudioPlayerPort();
    recorder = PlayHistoryRecorder(port: port, library: service);
    recorder.start();
  });

  tearDown(() async {
    await recorder.dispose();
    await port.dispose();
    await db.close();
  });

  /// Tunggu sampai kondisi terpenuhi (paling lama 2 detik), lalu kembalikan
  /// benar bila terpenuhi. Dipakai karena pencatatan berjalan async di
  /// balik stream.
  Future<bool> waitFor(
    Future<bool> Function() condition, {
    Duration timeout = const Duration(seconds: 2),
  }) async {
    final DateTime deadline = DateTime.now().add(timeout);
    while (DateTime.now().isBefore(deadline)) {
      if (await condition()) return true;
      await Future<void>.delayed(const Duration(milliseconds: 20));
    }
    return condition();
  }

  Future<int> historyCount() async {
    return (await service.libraryCounts()).historyEntries;
  }

  PlayerSnapshot playingSnapshot(Track track) {
    return PlayerSnapshot(
      currentTrack: track,
      queue: <Track>[track],
      currentIndex: 0,
      playing: true,
      status: PlayerStatus.ready,
      duration: track.duration,
    );
  }

  /// Simulasikan mendengarkan [seconds] detik: posisi naik 1 detik per tick.
  void emitListening(int seconds) {
    for (int i = 0; i <= seconds; i++) {
      port.emitPosition(Duration(seconds: i));
    }
  }

  /// Beri kesempatan event stream terkirim: state dan posisi adalah dua
  /// stream terpisah, dan burst sinkron tanpa jeda tidak mencerminkan
  /// kedatangan event di produksi (yang tersebar dari waktu ke waktu).
  Future<void> pumpEvents() async {
    await Future<void>.delayed(Duration.zero);
  }

  test('12 detik didengar lalu lagu berganti: satu event tercatat', () async {
    final Track track = testTrack('v1', title: 'Lagu Satu');
    port.emitSnapshot(playingSnapshot(track));
    await pumpEvents();
    emitListening(12);
    await pumpEvents();
    port.emitSnapshot(playingSnapshot(testTrack('v2', title: 'Lagu Dua')));

    expect(await waitFor(() async => await historyCount() == 1), isTrue);
    final List<PlayHistoryEntry> page = await service.historyPage();
    expect(page.single.song.id, 'v1');
    expect(page.single.event.playTimeMs, 12000);
  });

  test('5 detik didengar lalu lagu berganti: tidak tercatat', () async {
    final Track track = testTrack('v1');
    port.emitSnapshot(playingSnapshot(track));
    await pumpEvents();
    emitListening(5);
    await pumpEvents();
    port.emitSnapshot(playingSnapshot(testTrack('v2')));

    await Future<void>.delayed(const Duration(milliseconds: 200));
    expect(await historyCount(), 0);
  });

  test('lagu selesai dicatat walau hanya didengar 3 detik', () async {
    final Track track = testTrack('v1');
    port.emitSnapshot(playingSnapshot(track));
    await pumpEvents();
    emitListening(3);
    await pumpEvents();
    port.emitSnapshot(
      playingSnapshot(track).copyWith(
        status: PlayerStatus.completed,
        playing: false,
      ),
    );

    expect(await waitFor(() async => await historyCount() == 1), isTrue);
    final List<PlayHistoryEntry> page = await service.historyPage();
    expect(page.single.event.playTimeMs, 3000);
  });

  test('lompat posisi (seek) tidak dihitung sebagai waktu mendengar', () async {
    final Track track = testTrack('v1');
    port.emitSnapshot(playingSnapshot(track));
    await pumpEvents();
    port.emitPosition(Duration.zero);
    port.emitPosition(const Duration(seconds: 1));
    port.emitPosition(const Duration(seconds: 2));
    // Lompat ke detik 60: selisih 58 detik di atas batas 5 detik/tick.
    port.emitPosition(const Duration(seconds: 60));
    port.emitPosition(const Duration(seconds: 61));
    port.emitPosition(const Duration(seconds: 62));
    await pumpEvents();
    port.emitSnapshot(playingSnapshot(testTrack('v2')));

    await Future<void>.delayed(const Duration(milliseconds: 200));
    // Hanya 2 + 1 + 1 = 4 detik yang terhitung, di bawah ambang 10 detik.
    expect(await historyCount(), 0);
  });

  test('metadata lagu tersimpan saat sesi dibuka, tanpa masuk Library', () async {
    final Track track = testTrack('v1', title: 'Lagu Satu', artist: 'Andi');
    port.emitSnapshot(playingSnapshot(track));

    expect(
      await waitFor(() async => await service.songById('v1') != null),
      isTrue,
    );
    final SongView view = (await service.songById('v1'))!;
    expect(view.song.title, 'Lagu Satu');
    expect(view.artistNames, <String>['Andi']);
    expect(view.song.inLibrary, isFalse);
  });

  test('dispose menutup sesi yang sedang berjalan', () async {
    final Track track = testTrack('v1');
    port.emitSnapshot(playingSnapshot(track));
    await pumpEvents();
    emitListening(11);
    await pumpEvents();
    await recorder.dispose();

    expect(await historyCount(), 1);
  });

  test('jeda lalu lanjut tidak menggelembungkan durasi', () async {
    final Track track = testTrack('v1');
    port.emitSnapshot(playingSnapshot(track));
    await pumpEvents();
    emitListening(6);
    await pumpEvents();
    // Jeda: posisi diam di detik 6 (tick berulang dengan posisi sama
    // menambah nol).
    port.emitPosition(const Duration(seconds: 6));
    port.emitPosition(const Duration(seconds: 6));
    // Lanjut: posisi maju dari detik 6.
    port.emitPosition(const Duration(seconds: 7));
    port.emitPosition(const Duration(seconds: 8));
    port.emitPosition(const Duration(seconds: 9));
    await pumpEvents();
    port.emitSnapshot(playingSnapshot(testTrack('v2')));

    await Future<void>.delayed(const Duration(milliseconds: 200));
    // 6 + 0 + 3 = 9 detik, di bawah ambang 10 detik.
    expect(await historyCount(), 0);
  });
}
