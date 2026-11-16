/// Tes QueuePersistence (P7, MUST #3): simpan antrean + status,
/// restore penuh sesudah restart, dan penyimpanan otomatis.
library;

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:laras/data/database.dart';
import 'package:laras/player/player.dart';

import '../data/test_database.dart';
import 'fakes.dart';

PlayerSnapshot snapshotWithQueue(
  List<Track> queue, {
  int currentIndex = 0,
  bool playing = true,
  bool shuffle = false,
  RepeatMode repeat = RepeatMode.off,
}) {
  return PlayerSnapshot(
    currentTrack: queue.isEmpty ? null : queue[currentIndex],
    queue: queue,
    currentIndex: queue.isEmpty ? -1 : currentIndex,
    playing: playing,
    status: queue.isEmpty ? PlayerStatus.idle : PlayerStatus.ready,
    shuffleEnabled: shuffle,
    repeatMode: repeat,
  );
}

Future<void> seedQueue(
  LibraryService library,
  List<Track> tracks, {
  int currentIndex = 0,
  int positionMs = 0,
  bool shuffle = false,
  int repeatMode = 0,
}) async {
  for (final Track track in tracks) {
    await library.upsertSong(
      track.toSongsCompanion(),
      artistNames: track.artistNames,
    );
  }
  await library.replaceQueue(<QueueItemsCompanion>[
    for (int i = 0; i < tracks.length; i++)
      QueueItemsCompanion.insert(
        position: Value<int>(i),
        songId: tracks[i].videoId,
      ),
  ]);
  await library.savePlaybackState(
    currentIndex: currentIndex,
    positionMs: positionMs,
    shuffleEnabled: shuffle,
    repeatMode: repeatMode,
  );
}

void main() {
  late LarasDatabase db;
  late LibraryService library;

  setUp(() {
    (db, library) = createTestLibrary();
  });

  tearDown(() async {
    await db.close();
  });

  group('QueuePersistence.saveNow', () {
    test('menyimpan antrean + status lengkap', () async {
      final List<Track> tracks = <Track>[
        testTrack('a'),
        testTrack('b'),
        testTrack('c'),
      ];
      final FakeAudioPlayerPort port = FakeAudioPlayerPort(
        initialSnapshot: snapshotWithQueue(
          tracks,
          currentIndex: 1,
          shuffle: true,
          repeat: RepeatMode.all,
        ),
      );
      port.emitPosition(const Duration(seconds: 42));
      final QueuePersistence persistence = QueuePersistence(
        port: port,
        library: library,
      );
      await persistence.saveNow();

      final List<QueueItem> items = await library.loadQueue();
      expect(
        items.map((QueueItem i) => i.songId).toList(),
        <String>['a', 'b', 'c'],
      );
      final PlaybackStateData? state = await library.loadPlaybackState();
      expect(state, isNotNull);
      expect(state!.currentIndex, 1);
      expect(state.positionMs, 42000);
      expect(state.shuffleEnabled, isTrue);
      expect(state.repeatMode, RepeatModeValue.all);
      // Lagu antrean TIDAK masuk Library (sekadar diputar).
      final SongView? view = await library.songById('a');
      expect(view!.song.inLibrary, isFalse);
      await persistence.dispose();
      await port.dispose();
    });

    test('antrean kosong mengosongkan antrean tersimpan', () async {
      await seedQueue(library, <Track>[testTrack('a'), testTrack('b')]);
      expect(await library.loadQueue(), hasLength(2));
      final FakeAudioPlayerPort port = FakeAudioPlayerPort();
      final QueuePersistence persistence = QueuePersistence(
        port: port,
        library: library,
      );
      await persistence.saveNow();
      expect(await library.loadQueue(), isEmpty);
      await persistence.dispose();
      await port.dispose();
    });
  });

  group('QueuePersistence.restore', () {
    test('memulihkan antrean + indeks + posisi + mode', () async {
      final List<Track> tracks = <Track>[
        testTrack('a'),
        testTrack('b'),
        testTrack('c'),
      ];
      await seedQueue(
        library,
        tracks,
        currentIndex: 1,
        positionMs: 60000,
        shuffle: true,
        repeatMode: RepeatModeValue.all,
      );
      final FakeAudioPlayerPort port = FakeAudioPlayerPort();
      final QueuePersistence persistence = QueuePersistence(
        port: port,
        library: library,
      );
      expect(await persistence.restore(), isTrue);
      expect(port.setQueueCalls, hasLength(1));
      final (List<Track>, int, bool) call = port.setQueueCalls.single;
      expect(
        call.$1.map((Track t) => t.videoId).toList(),
        <String>['a', 'b', 'c'],
      );
      expect(call.$2, 1);
      expect(call.$3, isFalse);
      expect(port.setShuffleCalls, <bool>[true]);
      expect(port.setRepeatModeCalls, <RepeatMode>[RepeatMode.all]);
      expect(port.seekCalls, <Duration>[const Duration(seconds: 60)]);
      await persistence.dispose();
      await port.dispose();
    });

    test('posisi dekat akhir lagu tidak di-seek', () async {
      await seedQueue(
        library,
        <Track>[testTrack('a')],
        positionMs: 175000,
      );
      final FakeAudioPlayerPort port = FakeAudioPlayerPort();
      final QueuePersistence persistence = QueuePersistence(
        port: port,
        library: library,
      );
      expect(await persistence.restore(), isTrue);
      expect(port.seekCalls, isEmpty);
      await persistence.dispose();
      await port.dispose();
    });

    test('tanpa antrean tersimpan mengembalikan false', () async {
      final FakeAudioPlayerPort port = FakeAudioPlayerPort();
      final QueuePersistence persistence = QueuePersistence(
        port: port,
        library: library,
      );
      expect(await persistence.restore(), isFalse);
      expect(port.setQueueCalls, isEmpty);
      await persistence.dispose();
      await port.dispose();
    });

    test('port yang sudah punya antrean tidak di-restore', () async {
      await seedQueue(library, <Track>[testTrack('a')]);
      final FakeAudioPlayerPort port = FakeAudioPlayerPort(
        initialSnapshot: snapshotWithQueue(<Track>[testTrack('x')]),
      );
      final QueuePersistence persistence = QueuePersistence(
        port: port,
        library: library,
      );
      expect(await persistence.restore(), isFalse);
      expect(port.setQueueCalls, isEmpty);
      await persistence.dispose();
      await port.dispose();
    });

    test('indeks di luar rentang dijepit', () async {
      await seedQueue(
        library,
        <Track>[testTrack('a'), testTrack('b')],
        currentIndex: 99,
      );
      final FakeAudioPlayerPort port = FakeAudioPlayerPort();
      final QueuePersistence persistence = QueuePersistence(
        port: port,
        library: library,
      );
      expect(await persistence.restore(), isTrue);
      expect(port.setQueueCalls.single.$2, 1);
      await persistence.dispose();
      await port.dispose();
    });

    test('lagu yang dihapus ikut hilang dari antrean (FK cascade)', () async {
      await seedQueue(library, <Track>[testTrack('a'), testTrack('b')]);
      // Hapus lagu b: FK cascade menghapus baris queue_items-nya juga.
      await (db.delete(
        db.songs,
      )..where((Songs s) => s.id.equals('b'))).go();
      expect(await library.loadQueue(), hasLength(1));
      final FakeAudioPlayerPort port = FakeAudioPlayerPort();
      final QueuePersistence persistence = QueuePersistence(
        port: port,
        library: library,
      );
      expect(await persistence.restore(), isTrue);
      expect(port.setQueueCalls.single.$1, hasLength(1));
      expect(port.setQueueCalls.single.$1.single.videoId, 'a');
      await persistence.dispose();
      await port.dispose();
    });
  });

  group('QueuePersistence.start (otomatis)', () {
    test('perubahan snapshot tersimpan sesudah debounce', () async {
      final FakeAudioPlayerPort port = FakeAudioPlayerPort();
      final QueuePersistence persistence = QueuePersistence(
        port: port,
        library: library,
      );
      persistence.start();
      port.emitSnapshot(
        snapshotWithQueue(<Track>[testTrack('a'), testTrack('b')]),
      );
      // Debounce 500 mdtk: belum tersimpan di 100 mdtk, tersimpan di 700.
      await Future<void>.delayed(const Duration(milliseconds: 100));
      expect(await library.loadQueue(), isEmpty);
      await Future<void>.delayed(const Duration(milliseconds: 600));
      final List<QueueItem> items = await library.loadQueue();
      expect(
        items.map((QueueItem i) => i.songId).toList(),
        <String>['a', 'b'],
      );
      await persistence.dispose();
      await port.dispose();
    });

    test('jeda langsung menyimpan posisi', () async {
      final FakeAudioPlayerPort port = FakeAudioPlayerPort(
        initialSnapshot: snapshotWithQueue(
          <Track>[testTrack('a')],
          playing: true,
        ),
      );
      final QueuePersistence persistence = QueuePersistence(
        port: port,
        library: library,
      );
      persistence.start();
      port.emitPosition(const Duration(seconds: 30));
      port.emitSnapshot(
        snapshotWithQueue(<Track>[testTrack('a')], playing: false),
      );
      await Future<void>.delayed(const Duration(milliseconds: 200));
      final PlaybackStateData? state = await library.loadPlaybackState();
      expect(state, isNotNull);
      expect(state!.positionMs, 30000);
      await persistence.dispose();
      await port.dispose();
    });
  });
}
