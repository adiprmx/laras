import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:laras/player/player.dart';

import 'fakes.dart';

void main() {
  group('QueueController', () {
    late QueueController queue;
    late List<Track> tracks;

    setUp(() {
      queue = QueueController(random: Random(42));
      tracks = <Track>[
        testTrack('a'),
        testTrack('b'),
        testTrack('c'),
        testTrack('d'),
      ];
    });

    test('setQueue menempatkan lagu awal dan antrean', () {
      queue.setQueue(tracks, initialIndex: 1);
      expect(queue.length, 4);
      expect(queue.currentIndex, 1);
      expect(queue.current, same(tracks[1]));
      expect(queue.tracks, tracks);
    });

    test('setQueue kosong mengosongkan antrean', () {
      queue.setQueue(tracks);
      queue.setQueue(<Track>[]);
      expect(queue.isEmpty, isTrue);
      expect(queue.current, isNull);
      expect(queue.currentIndex, -1);
    });

    test('setQueue menolak lebih dari 200 lagu', () {
      final List<Track> tooMany = List<Track>.generate(
        kMaxQueueLength + 1,
        (int i) => testTrack('t$i'),
      );
      expect(() => queue.setQueue(tooMany), throwsArgumentError);
    });

    test('setQueue menolak initialIndex di luar jangkauan', () {
      expect(() => queue.setQueue(tracks, initialIndex: 4), throwsArgumentError);
      expect(() => queue.setQueue(tracks, initialIndex: -1), throwsArgumentError);
    });

    test('add menambah di ujung dan false saat penuh', () {
      final QueueController full = QueueController();
      full.setQueue(
        List<Track>.generate(kMaxQueueLength, (int i) => testTrack('t$i')),
      );
      expect(full.add(testTrack('extra')), isFalse);
      expect(full.length, kMaxQueueLength);

      queue.setQueue(tracks);
      expect(queue.add(testTrack('e')), isTrue);
      expect(queue.length, 5);
      expect(queue.tracks.last.videoId, 'e');
    });

    test('insert menyisip dan menggeser indeks lagu yang diputar', () {
      queue.setQueue(tracks, initialIndex: 1);
      expect(queue.insert(0, testTrack('x')), isTrue);
      expect(queue.tracks[0].videoId, 'x');
      expect(queue.currentIndex, 2);
      expect(queue.current!.videoId, 'b');
      expect(queue.insert(99, testTrack('y')), isFalse);
    });

    test('removeAt menjaga indeks lagu yang diputar', () {
      queue.setQueue(tracks, initialIndex: 2);
      final Track removed = queue.removeAt(0);
      expect(removed.videoId, 'a');
      expect(queue.currentIndex, 1);
      expect(queue.current!.videoId, 'c');

      // Hapus lagu yang sedang diputar: indeks menunjuk lagu berikutnya.
      queue.removeAt(1);
      expect(queue.current!.videoId, 'd');

      // Hapus lagu terakhir yang sedang diputar: mundur satu.
      queue.removeAt(1);
      expect(queue.current!.videoId, 'b');
      expect(queue.length, 1);
    });

    test('move mengikuti lagu yang diputar lewat identitas', () {
      queue.setQueue(tracks, initialIndex: 1);
      queue.move(1, 3);
      expect(queue.tracks.map((t) => t.videoId), <String>['a', 'c', 'd', 'b']);
      expect(queue.currentIndex, 3);
      expect(queue.current!.videoId, 'b');
    });

    test('clear mengosongkan antrean', () {
      queue.setQueue(tracks);
      queue.clear();
      expect(queue.isEmpty, isTrue);
      expect(queue.current, isNull);
    });

    test('shuffle menempatkan lagu yang diputar di depan', () {
      queue.setQueue(tracks, initialIndex: 2);
      queue.setShuffle(true);
      expect(queue.shuffleEnabled, isTrue);
      expect(queue.currentIndex, 0);
      expect(queue.current!.videoId, 'c');
      expect(
        queue.tracks.map((t) => t.videoId).toSet(),
        <String>{'a', 'b', 'c', 'd'},
      );
      // Sisanya diacak: dengan seed 42 urutannya bukan urutan asli.
      expect(
        queue.tracks.map((t) => t.videoId).toList(),
        isNot(<String>['c', 'a', 'b', 'd']),
      );
    });

    test('shuffle deterministik dengan seed yang sama', () {
      final QueueController first = QueueController(random: Random(7));
      final QueueController second = QueueController(random: Random(7));
      first.setQueue(tracks, initialIndex: 1);
      second.setQueue(tracks, initialIndex: 1);
      first.setShuffle(true);
      second.setShuffle(true);
      expect(
        first.tracks.map((t) => t.videoId).toList(),
        second.tracks.map((t) => t.videoId).toList(),
      );
    });

    test('mematikan shuffle mengembalikan urutan asli', () {
      queue.setQueue(tracks, initialIndex: 2);
      queue.setShuffle(true);
      queue.setShuffle(false);
      expect(queue.shuffleEnabled, isFalse);
      expect(queue.tracks, tracks);
      expect(queue.currentIndex, 2);
      expect(queue.current!.videoId, 'c');
    });

    test('nextIndexForCompletion: off diam di ujung', () {
      queue.setQueue(tracks, initialIndex: 3);
      expect(queue.nextIndexForCompletion(), isNull);
      queue.jumpTo(1);
      expect(queue.nextIndexForCompletion(), 2);
    });

    test('nextIndexForCompletion: all membungkus, one mengulang', () {
      queue.setQueue(tracks, initialIndex: 3);
      queue.setRepeatMode(RepeatMode.all);
      expect(queue.nextIndexForCompletion(), 0);
      queue.setRepeatMode(RepeatMode.one);
      expect(queue.nextIndexForCompletion(), 3);
    });

    test('nextIndexForSkip: one diperlakukan seperti off', () {
      queue.setQueue(tracks, initialIndex: 3);
      queue.setRepeatMode(RepeatMode.one);
      expect(queue.nextIndexForSkip(), isNull);
      queue.setRepeatMode(RepeatMode.all);
      expect(queue.nextIndexForSkip(), 0);
      queue.jumpTo(1);
      queue.setRepeatMode(RepeatMode.one);
      expect(queue.nextIndexForSkip(), 2);
    });

    test('previousIndexForSkip: all membungkus dari awal', () {
      queue.setQueue(tracks, initialIndex: 0);
      expect(queue.previousIndexForSkip(), isNull);
      queue.setRepeatMode(RepeatMode.all);
      expect(queue.previousIndexForSkip(), 3);
      queue.jumpTo(2);
      expect(queue.previousIndexForSkip(), 1);
    });

    test('trackAfterCurrent null di ujung antrean', () {
      queue.setQueue(tracks, initialIndex: 3);
      expect(queue.trackAfterCurrent, isNull);
      queue.jumpTo(1);
      expect(queue.trackAfterCurrent!.videoId, 'c');
    });

    test('duplikat videoId yang sama boleh ada dua kali', () {
      final Track first = testTrack('dup');
      final Track second = testTrack('dup');
      queue.setQueue(<Track>[first, second]);
      expect(queue.length, 2);
      queue.setShuffle(true);
      expect(queue.length, 2);
    });
  });
}
