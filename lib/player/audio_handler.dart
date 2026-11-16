/// Jembatan MediaSession: [LarasAudioHandler] menghubungkan audio_service
/// (notifikasi media, lock screen, tombol headset/Bluetooth, Android Auto)
/// ke [AudioPlayerPort].
///
/// Handler ini tidak menyimpan state sendiri: semua state dibaca dari
/// port dan disiarkan ke MediaSession. Perintah dari sistem (putar, jeda,
/// berikutnya, sebelumnya, cari, acak, ulangi) diteruskan ke port.
library;

import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:laras/l10n/generated/app_localizations_id.dart';

import 'audio_player_port.dart';
import 'playback_failure_messages.dart';
import 'player_state.dart';
import 'track.dart';

/// Handler audio_service untuk Laras.
class LarasAudioHandler extends BaseAudioHandler {
  // Field privat, nama parameter publik; initializing formal tidak bisa
  // dipakai di sini (lint prefer_initializing_formals diabaikan per baris).
  LarasAudioHandler({required AudioPlayerPort player})
    : _player = player { // ignore: prefer_initializing_formals
    _stateSub = _player.stateStream.listen((_) => _broadcast());
    _positionSub = _player.positionStream.listen((_) => _broadcast());
    _broadcast();
  }

  final AudioPlayerPort _player;
  StreamSubscription<PlayerSnapshot>? _stateSub;
  StreamSubscription<Duration>? _positionSub;

  /// Pola videoId YouTube: tepat 11 karakter alfabet base64 URL-safe.
  ///
  /// Handler ini adalah perbatasan MediaSession: aplikasi lain bisa
  /// mengirim perintah (root MediaBrowser terbuka untuk semua pemanggil —
  /// perilaku paket audio_service, R1-L4) sehingga `mediaItem.id` tidak
  /// bisa dipercaya begitu saja. Id yang tidak valid DIABAIKAN
  /// (fail-closed): tidak masuk antrean, tidak memicu resolve.
  static final RegExp _videoIdPattern = RegExp(r'^[A-Za-z0-9_-]{11}$');

  static bool _isValidVideoId(String id) => _videoIdPattern.hasMatch(id);

  MediaItem _toMediaItem(Track track, Duration? duration) {
    return MediaItem(
      id: track.videoId,
      title: track.title,
      artist: track.artist,
      album: track.album,
      duration: duration ?? track.duration,
      artUri: track.artUri,
    );
  }

  static AudioProcessingState _mapStatus(PlayerStatus status) {
    switch (status) {
      case PlayerStatus.idle:
        return AudioProcessingState.idle;
      case PlayerStatus.loading:
        return AudioProcessingState.loading;
      case PlayerStatus.buffering:
        return AudioProcessingState.buffering;
      case PlayerStatus.ready:
        return AudioProcessingState.ready;
      case PlayerStatus.completed:
        return AudioProcessingState.completed;
      case PlayerStatus.error:
        return AudioProcessingState.error;
    }
  }

  static AudioServiceRepeatMode _mapRepeat(RepeatMode mode) {
    switch (mode) {
      case RepeatMode.off:
        return AudioServiceRepeatMode.none;
      case RepeatMode.all:
        return AudioServiceRepeatMode.all;
      case RepeatMode.one:
        return AudioServiceRepeatMode.one;
    }
  }

  void _broadcast() {
    final PlayerSnapshot snap = _player.snapshot;
    final Track? track = snap.currentTrack;
    mediaItem.add(
      track == null ? null : _toMediaItem(track, snap.duration),
    );
    queue.add(
      snap.queue
          .map((Track t) => _toMediaItem(t, null))
          .toList(growable: false),
    );
    final PlaybackFailure? failure = snap.lastError;
    final AppLocalizationsId strings = AppLocalizationsId();
    playbackState.add(
      PlaybackState(
        processingState: _mapStatus(snap.status),
        playing: snap.playing,
        controls: <MediaControl>[
          MediaControl.skipToPrevious,
          if (snap.playing) MediaControl.pause else MediaControl.play,
          MediaControl.skipToNext,
          MediaControl.stop,
        ],
        systemActions: const <MediaAction>{
          MediaAction.seek,
          MediaAction.seekForward,
          MediaAction.seekBackward,
        },
        androidCompactActionIndices: const <int>[0, 1, 2],
        updatePosition: _player.position,
        bufferedPosition: _player.bufferedPosition,
        speed: snap.speed,
        queueIndex: snap.currentIndex >= 0 ? snap.currentIndex : null,
        repeatMode: _mapRepeat(snap.repeatMode),
        shuffleMode: snap.shuffleEnabled
            ? AudioServiceShuffleMode.all
            : AudioServiceShuffleMode.none,
        errorCode: snap.status == PlayerStatus.error ? 1 : null,
        errorMessage: snap.status == PlayerStatus.error && failure != null
            ? playbackFailureMessage(strings, failure)
            : null,
      ),
    );
  }

  @override
  Future<void> play() => _player.play();

  @override
  Future<void> pause() => _player.pause();

  @override
  Future<void> stop() => _player.stop();

  @override
  Future<void> seek(Duration position) => _player.seek(
    position.isNegative ? Duration.zero : position,
  );

  @override
  Future<void> seekBackward(bool begin) async {
    if (begin) return;
    await _player.seek(_player.position - const Duration(seconds: 10));
  }

  @override
  Future<void> seekForward(bool begin) async {
    if (begin) return;
    await _player.seek(_player.position + const Duration(seconds: 10));
  }

  @override
  Future<void> skipToNext() => _player.skipToNext();

  @override
  Future<void> skipToPrevious() => _player.skipToPrevious();

  @override
  Future<void> skipToQueueItem(int index) => _player.skipToIndex(index);

  @override
  Future<void> playMediaItem(MediaItem mediaItem) async {
    if (!_isValidVideoId(mediaItem.id)) return;
    final List<Track> queue = _player.snapshot.queue;
    final int existing = queue.indexWhere((t) => t.videoId == mediaItem.id);
    if (existing >= 0) {
      await _player.skipToIndex(existing);
      await _player.play();
      return;
    }
    await _player.setQueue(
      <Track>[
        Track(
          videoId: mediaItem.id,
          title: mediaItem.title,
          artist: mediaItem.artist,
          album: mediaItem.album,
          duration: mediaItem.duration,
          artUri: mediaItem.artUri,
        ),
      ],
      autoplay: true,
    );
  }

  @override
  Future<void> addQueueItem(MediaItem mediaItem) async {
    if (!_isValidVideoId(mediaItem.id)) return;
    await _player.addToQueue(
      Track(
        videoId: mediaItem.id,
        title: mediaItem.title,
        artist: mediaItem.artist,
        album: mediaItem.album,
        duration: mediaItem.duration,
        artUri: mediaItem.artUri,
      ),
    );
  }

  @override
  Future<void> addQueueItems(List<MediaItem> mediaItems) async {
    for (final MediaItem item in mediaItems) {
      await addQueueItem(item);
    }
  }

  @override
  Future<void> insertQueueItem(int index, MediaItem mediaItem) async {
    if (!_isValidVideoId(mediaItem.id)) return;
    await _player.insertInQueue(
      index,
      Track(
        videoId: mediaItem.id,
        title: mediaItem.title,
        artist: mediaItem.artist,
        album: mediaItem.album,
        duration: mediaItem.duration,
        artUri: mediaItem.artUri,
      ),
    );
  }

  @override
  Future<void> removeQueueItem(MediaItem mediaItem) async {
    final List<Track> queue = _player.snapshot.queue;
    final int index = queue.indexWhere((t) => t.videoId == mediaItem.id);
    if (index >= 0) await _player.removeFromQueue(index);
  }

  @override
  Future<void> updateQueue(List<MediaItem> queue) async {
    final String? currentId = _player.snapshot.currentTrack?.videoId;
    final bool wasPlaying = _player.snapshot.playing;
    final List<MediaItem> valid =
        queue.where((m) => _isValidVideoId(m.id)).toList(growable: false);
    // Semua id tidak valid: jangan hapus antrean pengguna karena perintah
    // eksternal yang rusak. Daftar kosong yang sah (hapus antrean) tetap
    // diteruskan.
    if (queue.isNotEmpty && valid.isEmpty) return;
    final List<Track> tracks = valid
        .map(
          (MediaItem m) => Track(
            videoId: m.id,
            title: m.title,
            artist: m.artist,
            album: m.album,
            duration: m.duration,
            artUri: m.artUri,
          ),
        )
        .toList(growable: false);
    final int currentIndex = currentId == null
        ? 0
        : tracks.indexWhere((Track t) => t.videoId == currentId);
    await _player.setQueue(
      tracks,
      initialIndex: currentIndex < 0 ? 0 : currentIndex,
      autoplay: wasPlaying,
    );
  }

  @override
  Future<void> setShuffleMode(AudioServiceShuffleMode shuffleMode) async {
    await _player.setShuffle(shuffleMode != AudioServiceShuffleMode.none);
  }

  @override
  Future<void> setRepeatMode(AudioServiceRepeatMode repeatMode) async {
    switch (repeatMode) {
      case AudioServiceRepeatMode.none:
        await _player.setRepeatMode(RepeatMode.off);
      case AudioServiceRepeatMode.one:
        await _player.setRepeatMode(RepeatMode.one);
      case AudioServiceRepeatMode.all:
      case AudioServiceRepeatMode.group:
        await _player.setRepeatMode(RepeatMode.all);
    }
  }

  @override
  Future<void> setSpeed(double speed) =>
      _player.setSpeed(speed.clamp(0.5, 2.0));

  /// Bebaskan langganan. Dipanggil saat service dihentikan.
  Future<void> dispose() async {
    await _stateSub?.cancel();
    await _positionSub?.cancel();
  }
}
