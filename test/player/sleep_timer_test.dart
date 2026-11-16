/// Tes SleepTimerService (P7): hitung mundur, mode akhir-lagu, batal
/// karena ganti lagu manual, dan status completed di lagu terakhir.
/// Waktu dikendalikan fake_async — tanpa menunggu waktu nyata.
library;

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:laras/player/player.dart';

import 'fakes.dart';

PlayerSnapshot snapshotWith({
  Track? track,
  List<Track>? queue,
  int currentIndex = 0,
  bool playing = true,
  PlayerStatus status = PlayerStatus.ready,
  Duration? duration,
}) {
  final List<Track> effectiveQueue =
      queue ?? (track == null ? <Track>[] : <Track>[track]);
  return PlayerSnapshot(
    currentTrack: track,
    queue: effectiveQueue,
    currentIndex: track == null ? -1 : currentIndex,
    playing: playing,
    status: status,
    duration: duration,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('timer berbasis waktu menjeda port + event done saat habis', () {
    fakeAsync((FakeAsync async) {
      final Track track = testTrack(
        'a',
        duration: const Duration(minutes: 3),
      );
      final FakeAudioPlayerPort port = FakeAudioPlayerPort(
        initialSnapshot: snapshotWith(track: track),
      );
      final SleepTimerService timer = SleepTimerService(port: port);
      final List<SleepTimerEvent> events = <SleepTimerEvent>[];
      timer.events.listen(events.add);
      timer.startTimed(const Duration(minutes: 5));
      expect(timer.isActive, isTrue);
      expect(timer.mode.value, SleepTimerMode.timed);
      expect(timer.remaining.value, const Duration(minutes: 5));

      async.elapse(const Duration(minutes: 4, seconds: 59));
      expect(port.pauseCalls, 0);
      expect(events, isEmpty);
      expect(timer.remaining.value, const Duration(seconds: 1));

      async.elapse(const Duration(seconds: 1));
      async.flushMicrotasks();
      expect(port.pauseCalls, 1);
      expect(events, <SleepTimerEvent>[SleepTimerEvent.done]);
      expect(timer.isActive, isFalse);
      expect(timer.remaining.value, isNull);
    });
  });

  test('durasi dijepit ke 1-180 menit', () {
    fakeAsync((FakeAsync async) {
      final FakeAudioPlayerPort port = FakeAudioPlayerPort(
        initialSnapshot: snapshotWith(track: testTrack('a')),
      );
      final SleepTimerService timer = SleepTimerService(port: port);
      timer.startTimed(const Duration(minutes: 500));
      expect(timer.remaining.value, const Duration(minutes: 180));
      timer.startTimed(const Duration(minutes: 0, seconds: 30));
      // Di bawah satu menit dihormati apa adanya (jalur tes).
      expect(timer.remaining.value, const Duration(seconds: 30));
    });
  });

  test('cancel mematikan timer tanpa menjeda dan tanpa event', () {
    fakeAsync((FakeAsync async) {
      final FakeAudioPlayerPort port = FakeAudioPlayerPort(
        initialSnapshot: snapshotWith(track: testTrack('a')),
      );
      final SleepTimerService timer = SleepTimerService(port: port);
      final List<SleepTimerEvent> events = <SleepTimerEvent>[];
      timer.events.listen(events.add);
      timer.startTimed(const Duration(minutes: 5));
      timer.cancel();
      expect(timer.isActive, isFalse);
      async.elapse(const Duration(minutes: 10));
      expect(port.pauseCalls, 0);
      expect(events, isEmpty);
    });
  });

  test('mode akhir-lagu: ganti lagu otomatis menjeda + done', () {
    fakeAsync((FakeAsync async) {
      final Track a = testTrack('a', duration: const Duration(minutes: 3));
      final Track b = testTrack('b', duration: const Duration(minutes: 3));
      final FakeAudioPlayerPort port = FakeAudioPlayerPort(
        initialSnapshot: snapshotWith(
          track: a,
          queue: <Track>[a, b],
          duration: const Duration(minutes: 3),
        ),
      );
      final SleepTimerService timer = SleepTimerService(port: port);
      final List<SleepTimerEvent> events = <SleepTimerEvent>[];
      timer.events.listen(events.add);
      timer.startAfterSong();
      expect(timer.mode.value, SleepTimerMode.afterSong);
      expect(timer.remaining.value, isNull);

      // Posisi dekat akhir lagu (2 detik tersisa), lalu lagu berganti.
      port.emitPosition(const Duration(minutes: 2, seconds: 58));
      async.flushMicrotasks();
      port.emitSnapshot(
        snapshotWith(
          track: b,
          queue: <Track>[a, b],
          currentIndex: 1,
          duration: const Duration(minutes: 3),
        ),
      );
      async.flushMicrotasks();
      expect(port.pauseCalls, 1);
      expect(events, <SleepTimerEvent>[SleepTimerEvent.done]);
      expect(timer.isActive, isFalse);
    });
  });

  test('mode akhir-lagu: ganti lagu manual membatalkan + event cancelled',
      () {
    fakeAsync((FakeAsync async) {
      final Track a = testTrack('a', duration: const Duration(minutes: 3));
      final Track b = testTrack('b', duration: const Duration(minutes: 3));
      final FakeAudioPlayerPort port = FakeAudioPlayerPort(
        initialSnapshot: snapshotWith(
          track: a,
          queue: <Track>[a, b],
          duration: const Duration(minutes: 3),
        ),
      );
      final SleepTimerService timer = SleepTimerService(port: port);
      final List<SleepTimerEvent> events = <SleepTimerEvent>[];
      timer.events.listen(events.add);
      timer.startAfterSong();

      // Posisi di tengah lagu (1 menit), lalu lagu berganti manual.
      port.emitPosition(const Duration(minutes: 1));
      async.flushMicrotasks();
      port.emitSnapshot(
        snapshotWith(
          track: b,
          queue: <Track>[a, b],
          currentIndex: 1,
          duration: const Duration(minutes: 3),
        ),
      );
      async.flushMicrotasks();
      expect(port.pauseCalls, 0);
      expect(events, <SleepTimerEvent>[SleepTimerEvent.cancelledByTrackChange]);
      expect(timer.isActive, isFalse);
    });
  });

  test('mode akhir-lagu: lagu terakhir selesai (completed) menjeda', () {
    fakeAsync((FakeAsync async) {
      final Track a = testTrack('a', duration: const Duration(minutes: 3));
      final FakeAudioPlayerPort port = FakeAudioPlayerPort(
        initialSnapshot: snapshotWith(
          track: a,
          duration: const Duration(minutes: 3),
        ),
      );
      final SleepTimerService timer = SleepTimerService(port: port);
      final List<SleepTimerEvent> events = <SleepTimerEvent>[];
      timer.events.listen(events.add);
      timer.startAfterSong();
      port.emitSnapshot(
        snapshotWith(
          track: a,
          playing: false,
          status: PlayerStatus.completed,
          duration: const Duration(minutes: 3),
        ),
      );
      async.flushMicrotasks();
      expect(port.pauseCalls, 1);
      expect(events, <SleepTimerEvent>[SleepTimerEvent.done]);
    });
  });

  test('mode akhir-lagu tanpa lagu yang diputar tidak terjadi apa-apa', () {
    fakeAsync((FakeAsync async) {
      final FakeAudioPlayerPort port = FakeAudioPlayerPort();
      final SleepTimerService timer = SleepTimerService(port: port);
      timer.startAfterSong();
      expect(timer.isActive, isFalse);
    });
  });

  test('memulai timer baru menggantikan timer lama', () {
    fakeAsync((FakeAsync async) {
      final FakeAudioPlayerPort port = FakeAudioPlayerPort(
        initialSnapshot: snapshotWith(track: testTrack('a')),
      );
      final SleepTimerService timer = SleepTimerService(port: port);
      final List<SleepTimerEvent> events = <SleepTimerEvent>[];
      timer.events.listen(events.add);
      timer.startTimed(const Duration(minutes: 5));
      timer.startTimed(const Duration(minutes: 10));
      async.elapse(const Duration(minutes: 6));
      async.flushMicrotasks();
      expect(port.pauseCalls, 0);
      expect(events, isEmpty);
      async.elapse(const Duration(minutes: 4));
      async.flushMicrotasks();
      expect(port.pauseCalls, 1);
      expect(events, <SleepTimerEvent>[SleepTimerEvent.done]);
    });
  });
}
