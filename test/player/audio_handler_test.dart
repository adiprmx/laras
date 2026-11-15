import 'package:audio_service/audio_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:laras/l10n/generated/app_localizations_id.dart';
import 'package:laras/player/player.dart';

import 'fakes.dart';

void main() {
  group('LarasAudioHandler', () {
    late FakeAudioPlayerPort port;
    late LarasAudioHandler handler;
    late List<Track> tracks;

    Future<void> settle() =>
        Future<void>.delayed(const Duration(milliseconds: 10));

    PlayerSnapshot snapshotWith({
      Track? current,
      List<Track>? queue,
      int currentIndex = 0,
      bool playing = false,
      PlayerStatus status = PlayerStatus.ready,
      Duration? duration,
      bool shuffleEnabled = false,
      RepeatMode repeatMode = RepeatMode.off,
      double speed = 1.0,
      PlaybackFailure? lastError,
    }) {
      return PlayerSnapshot(
        currentTrack: current,
        queue: queue ?? tracks,
        currentIndex: currentIndex,
        playing: playing,
        status: status,
        duration: duration,
        shuffleEnabled: shuffleEnabled,
        repeatMode: repeatMode,
        speed: speed,
        lastError: lastError,
      );
    }

    setUp(() {
      tracks = <Track>[
        testTrack('a', duration: const Duration(minutes: 3)),
        testTrack('b', duration: const Duration(minutes: 4)),
        testTrack('c', duration: const Duration(minutes: 5)),
      ];
      port = FakeAudioPlayerPort();
      handler = LarasAudioHandler(player: port);
    });

    tearDown(() async {
      await handler.dispose();
      await port.dispose();
    });

    test('snapshot awal idle: mediaItem null, antrean kosong', () {
      expect(handler.mediaItem.value, isNull);
      expect(handler.queue.value, isEmpty);
      expect(
        handler.playbackState.value.processingState,
        AudioProcessingState.idle,
      );
    });

    test('snapshot dipetakan ke mediaItem, antrean, dan playbackState',
        () async {
      port.emitSnapshot(
        snapshotWith(
          current: tracks[1],
          currentIndex: 1,
          playing: true,
          duration: const Duration(minutes: 4),
          speed: 1.5,
        ),
      );
      await settle();
      final MediaItem? item = handler.mediaItem.value;
      expect(item, isNotNull);
      expect(item!.id, 'b');
      expect(item.title, 'Lagu b');
      expect(item.artist, 'Artis b');
      expect(item.duration, const Duration(minutes: 4));
      expect(
        handler.queue.value.map((m) => m.id).toList(),
        <String>['a', 'b', 'c'],
      );
      final PlaybackState state = handler.playbackState.value;
      expect(state.playing, isTrue);
      expect(state.processingState, AudioProcessingState.ready);
      expect(state.speed, 1.5);
      expect(state.queueIndex, 1);
      expect(state.controls, contains(MediaControl.pause));
      expect(state.controls, contains(MediaControl.skipToNext));
      expect(state.androidCompactActionIndices, <int>[0, 1, 2]);
      expect(state.systemActions, contains(MediaAction.seek));
    });

    test('saat dijeda tombol kontrolnya play, bukan pause', () async {
      port.emitSnapshot(snapshotWith(current: tracks[0], playing: false));
      await settle();
      expect(
        handler.playbackState.value.controls,
        contains(MediaControl.play),
      );
      expect(
        handler.playbackState.value.controls,
        isNot(contains(MediaControl.pause)),
      );
    });

    test('status loading/buffering/error dipetakan', () async {
      port.emitSnapshot(
        snapshotWith(current: tracks[0], status: PlayerStatus.loading),
      );
      await settle();
      expect(
        handler.playbackState.value.processingState,
        AudioProcessingState.loading,
      );
      port.emitSnapshot(
        snapshotWith(
          current: tracks[0],
          status: PlayerStatus.error,
          lastError: const PlaybackFailure(
            kind: PlaybackFailureKind.network,
            trackTitle: 'Lagu a',
          ),
        ),
      );
      await settle();
      final PlaybackState state = handler.playbackState.value;
      expect(state.processingState, AudioProcessingState.error);
      expect(state.errorCode, isNotNull);
      expect(state.errorMessage, AppLocalizationsId().noInternet);
    });

    test('mode acak dan ulangi dipetakan', () async {
      port.emitSnapshot(
        snapshotWith(
          current: tracks[0],
          shuffleEnabled: true,
          repeatMode: RepeatMode.one,
        ),
      );
      await settle();
      expect(
        handler.playbackState.value.shuffleMode,
        AudioServiceShuffleMode.all,
      );
      expect(
        handler.playbackState.value.repeatMode,
        AudioServiceRepeatMode.one,
      );
    });

    test('posisi diperbarui dari positionStream', () async {
      port.emitSnapshot(snapshotWith(current: tracks[0], playing: true));
      port.emitPosition(const Duration(seconds: 42));
      await settle();
      expect(
        handler.playbackState.value.updatePosition,
        const Duration(seconds: 42),
      );
    });

    test('perintah play/pause/stop/skip/seek diteruskan ke port', () async {
      await handler.play();
      await handler.pause();
      await handler.stop();
      await handler.skipToNext();
      await handler.skipToPrevious();
      await handler.seek(const Duration(seconds: 15));
      expect(port.playCalls, 1);
      expect(port.pauseCalls, 1);
      expect(port.stopCalls, 1);
      expect(port.skipToNextCalls, 1);
      expect(port.skipToPreviousCalls, 1);
      expect(port.seekCalls, <Duration>[const Duration(seconds: 15)]);
    });

    test('seekForward/seekBackward menggeser 10 detik', () async {
      port.emitPosition(const Duration(seconds: 30));
      await handler.seekForward(false);
      await handler.seekBackward(false);
      await handler.seekForward(true);
      expect(port.seekCalls, <Duration>[
        const Duration(seconds: 40),
        const Duration(seconds: 20),
      ]);
    });

    test('setShuffleMode/setRepeatMode/setSpeed diteruskan', () async {
      await handler.setShuffleMode(AudioServiceShuffleMode.all);
      await handler.setShuffleMode(AudioServiceShuffleMode.none);
      await handler.setRepeatMode(AudioServiceRepeatMode.one);
      await handler.setRepeatMode(AudioServiceRepeatMode.group);
      await handler.setRepeatMode(AudioServiceRepeatMode.none);
      await handler.setSpeed(1.25);
      expect(port.setShuffleCalls, <bool>[true, false]);
      expect(port.setRepeatModeCalls, <RepeatMode>[
        RepeatMode.one,
        RepeatMode.all,
        RepeatMode.off,
      ]);
      expect(port.setSpeedCalls, <double>[1.25]);
    });

    test('playMediaItem lagu yang sudah ada melompat ke lagu itu', () async {
      port.emitSnapshot(snapshotWith(current: tracks[0]));
      await settle();
      await handler.playMediaItem(const MediaItem(id: 'c', title: 'Lagu c'));
      expect(port.skipToIndexCalls, <int>[2]);
      expect(port.playCalls, 1);
    });

    test('playMediaItem lagu baru mengganti antrean', () async {
      port.emitSnapshot(snapshotWith(current: tracks[0]));
      await settle();
      await handler.playMediaItem(
        const MediaItem(id: 'z', title: 'Lagu Baru', artist: 'Artis Baru'),
      );
      expect(port.setQueueCalls, hasLength(1));
      expect(port.setQueueCalls.single.$1.single.videoId, 'z');
      expect(port.setQueueCalls.single.$1.single.title, 'Lagu Baru');
      expect(port.setQueueCalls.single.$3, isTrue);
    });

    test('add/remove/update antrean diteruskan', () async {
      port.emitSnapshot(snapshotWith(current: tracks[0]));
      await settle();
      await handler.addQueueItem(const MediaItem(id: 'd', title: 'Lagu d'));
      await handler.removeQueueItem(const MediaItem(id: 'b', title: 'Lagu b'));
      expect(port.addToQueueCalls.single.videoId, 'd');
      expect(port.removeFromQueueCalls, <int>[1]);
      await handler.updateQueue(<MediaItem>[
        const MediaItem(id: 'c', title: 'Lagu c'),
        const MediaItem(id: 'a', title: 'Lagu a'),
      ]);
      expect(port.setQueueCalls.single.$1.map((t) => t.videoId).toList(),
          <String>['c', 'a']);
      expect(port.setQueueCalls.single.$2, 1);
    });

    test('skipToQueueItem diteruskan', () async {
      await handler.skipToQueueItem(2);
      expect(port.skipToIndexCalls, <int>[2]);
    });
  });
}
