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
      // Id 11 karakter (format videoId YouTube): handler memvalidasi id
      // perintah MediaSession (R1-L4), jadi tes memakai id yang sah.
      tracks = <Track>[
        testTrack(
          'aaaaaaaaaaa',
          title: 'Lagu a',
          artist: 'Artis a',
          duration: const Duration(minutes: 3),
        ),
        testTrack(
          'bbbbbbbbbbb',
          title: 'Lagu b',
          artist: 'Artis b',
          duration: const Duration(minutes: 4),
        ),
        testTrack(
          'ccccccccccc',
          title: 'Lagu c',
          artist: 'Artis c',
          duration: const Duration(minutes: 5),
        ),
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
      expect(item!.id, 'bbbbbbbbbbb');
      expect(item.title, 'Lagu b');
      expect(item.artist, 'Artis b');
      expect(item.duration, const Duration(minutes: 4));
      expect(
        handler.queue.value.map((m) => m.id).toList(),
        <String>['aaaaaaaaaaa', 'bbbbbbbbbbb', 'ccccccccccc'],
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
      await handler.playMediaItem(
        const MediaItem(id: 'ccccccccccc', title: 'Lagu c'),
      );
      expect(port.skipToIndexCalls, <int>[2]);
      expect(port.playCalls, 1);
    });

    test('playMediaItem lagu baru mengganti antrean', () async {
      port.emitSnapshot(snapshotWith(current: tracks[0]));
      await settle();
      await handler.playMediaItem(
        const MediaItem(
          id: 'zzzzzzzzzzz',
          title: 'Lagu Baru',
          artist: 'Artis Baru',
        ),
      );
      expect(port.setQueueCalls, hasLength(1));
      expect(port.setQueueCalls.single.$1.single.videoId, 'zzzzzzzzzzz');
      expect(port.setQueueCalls.single.$1.single.title, 'Lagu Baru');
      expect(port.setQueueCalls.single.$3, isTrue);
    });

    test('add/remove/update antrean diteruskan', () async {
      port.emitSnapshot(snapshotWith(current: tracks[0]));
      await settle();
      await handler.addQueueItem(
        const MediaItem(id: 'ddddddddddd', title: 'Lagu d'),
      );
      await handler.removeQueueItem(
        const MediaItem(id: 'bbbbbbbbbbb', title: 'Lagu b'),
      );
      expect(port.addToQueueCalls.single.videoId, 'ddddddddddd');
      expect(port.removeFromQueueCalls, <int>[1]);
      await handler.updateQueue(<MediaItem>[
        const MediaItem(id: 'ccccccccccc', title: 'Lagu c'),
        const MediaItem(id: 'aaaaaaaaaaa', title: 'Lagu a'),
      ]);
      expect(port.setQueueCalls.single.$1.map((t) => t.videoId).toList(),
          <String>['ccccccccccc', 'aaaaaaaaaaa']);
      expect(port.setQueueCalls.single.$2, 1);
    });

    test('skipToQueueItem diteruskan', () async {
      await handler.skipToQueueItem(2);
      expect(port.skipToIndexCalls, <int>[2]);
    });

    test('playMediaItem id tidak valid diabaikan', () async {
      port.emitSnapshot(snapshotWith(current: tracks[0]));
      await settle();
      await handler.playMediaItem(
        const MediaItem(id: 'terlalu-pendek', title: 'Jahat'),
      );
      await handler.playMediaItem(
        const MediaItem(id: 'aaaaaaaaaa!', title: 'Jahat'),
      );
      await handler.playMediaItem(
        const MediaItem(id: '../../etc/passwd', title: 'Jahat'),
      );
      expect(port.skipToIndexCalls, isEmpty);
      expect(port.setQueueCalls, isEmpty);
      expect(port.playCalls, 0);
    });

    test('add/insert antrean id tidak valid diabaikan', () async {
      await handler.addQueueItem(
        const MediaItem(id: 'pendek', title: 'Jahat'),
      );
      await handler.insertQueueItem(
        0,
        const MediaItem(id: 'aaaaaaaaaaaa', title: 'Jahat'),
      );
      expect(port.addToQueueCalls, isEmpty);
      expect(port.insertInQueueCalls, isEmpty);
    });

    test('updateQueue menyaring id tidak valid', () async {
      port.emitSnapshot(snapshotWith(current: tracks[0]));
      await settle();
      await handler.updateQueue(<MediaItem>[
        const MediaItem(id: 'ccccccccccc', title: 'Lagu c'),
        const MediaItem(id: 'tidak-valid!', title: 'Jahat'),
        const MediaItem(id: 'aaaaaaaaaaa', title: 'Lagu a'),
      ]);
      expect(port.setQueueCalls.single.$1.map((t) => t.videoId).toList(),
          <String>['ccccccccccc', 'aaaaaaaaaaa']);
    });

    test('updateQueue semua tidak valid tidak menghapus antrean', () async {
      port.emitSnapshot(snapshotWith(current: tracks[0]));
      await settle();
      await handler.updateQueue(<MediaItem>[
        const MediaItem(id: 'x', title: 'Jahat'),
      ]);
      expect(port.setQueueCalls, isEmpty);
    });

    test('setSpeed dijepit ke 0,5-2,0', () async {
      await handler.setSpeed(0.1);
      await handler.setSpeed(5.0);
      await handler.setSpeed(1.5);
      expect(port.setSpeedCalls, <double>[0.5, 2.0, 1.5]);
    });

    test('seek negatif dijepit ke nol', () async {
      await handler.seek(const Duration(seconds: -5));
      expect(port.seekCalls, <Duration>[Duration.zero]);
    });

    test('R2-L2: playMediaItem artUri di luar host thumbnail dihapus',
        () async {
      port.emitSnapshot(snapshotWith(current: tracks[0]));
      await settle();
      await handler.playMediaItem(
        MediaItem(
          id: 'zzzzzzzzzzz',
          title: 'Lagu Baru',
          artUri: Uri.parse('http://evil.example/x.jpg'),
        ),
      );
      expect(port.setQueueCalls.single.$1.single.artUri, isNull);
    });

    test('R2-L2: playMediaItem artUri thumbnail yang sah dipertahankan',
        () async {
      port.emitSnapshot(snapshotWith(current: tracks[0]));
      await settle();
      await handler.playMediaItem(
        MediaItem(
          id: 'zzzzzzzzzzz',
          title: 'Lagu Baru',
          artUri: Uri.parse('https://i.ytimg.com/vi/zzzzzzzzzzz/hqdefault.jpg'),
        ),
      );
      expect(
        port.setQueueCalls.single.$1.single.artUri.toString(),
        'https://i.ytimg.com/vi/zzzzzzzzzzz/hqdefault.jpg',
      );
    });

    test('R2-L2: add/insert antrean artUri jahat dihapus', () async {
      await handler.addQueueItem(
        MediaItem(
          id: 'ddddddddddd',
          title: 'Lagu d',
          artUri: Uri.parse('https://evil.example.evil.com/x.png'),
        ),
      );
      await handler.insertQueueItem(
        0,
        MediaItem(
          id: 'eeeeeeeeeee',
          title: 'Lagu e',
          artUri: Uri.parse('https://googlevideo.com@evil.example/x.png'),
        ),
      );
      expect(port.addToQueueCalls.single.artUri, isNull);
      expect(port.insertInQueueCalls.single.$2.artUri, isNull);
    });

    test('R2-L2: updateQueue menyaring artUri, id yang sah tetap jalan',
        () async {
      await handler.updateQueue(<MediaItem>[
        MediaItem(
          id: 'ccccccccccc',
          title: 'Lagu c',
          artUri: Uri.parse('https://lh3.googleusercontent.com/a-/x.jpg'),
        ),
        MediaItem(
          id: 'aaaaaaaaaaa',
          title: 'Lagu a',
          artUri: Uri.parse('http://192.168.1.1/x.jpg'),
        ),
      ]);
      final List<Track> tracks = port.setQueueCalls.single.$1;
      expect(tracks.map((t) => t.videoId).toList(),
          <String>['ccccccccccc', 'aaaaaaaaaaa']);
      expect(
        tracks[0].artUri.toString(),
        'https://lh3.googleusercontent.com/a-/x.jpg',
      );
      expect(tracks[1].artUri, isNull);
    });
  });
}
