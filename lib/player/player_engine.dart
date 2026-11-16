/// Jahitan engine audio: interface kecil di atas just_audio.
///
/// Adapter player ([JustAudioPlayerPort]) hanya mengenal interface ini,
/// jadi logika antrean, jendela gapless, dan re-resolve bisa dites penuh
/// dengan engine palsu tanpa platform audio Android.
library;

import 'package:just_audio/just_audio.dart' as ja;

/// Status pemrosesan engine (cermin ProcessingState just_audio, tanpa
/// mengekspos tipe just_audio ke adapter).
enum EngineProcessing { idle, loading, buffering, ready, completed }

/// State engine: sedang memutar atau tidak + status pemrosesan.
class EngineState {
  const EngineState({required this.playing, required this.processing});

  final bool playing;
  final EngineProcessing processing;

  @override
  bool operator ==(Object other) =>
      other is EngineState &&
      other.playing == playing &&
      other.processing == processing;

  @override
  int get hashCode => Object.hash(playing, processing);

  @override
  String toString() => 'EngineState(playing: $playing, $processing)';
}

/// Satu sumber audio di engine: URL + tag identitas (videoId).
class EngineSource {
  const EngineSource({required this.uri, required this.tag});

  final Uri uri;

  /// Identitas sumber (videoId lagu). Dipakai adapter untuk mencocokkan
  /// indeks engine dengan indeks antrean.
  final String tag;
}

/// Error engine. Hanya kode yang diteruskan: pesan error ExoPlayer bisa
/// mengandung URL stream, jadi tidak pernah dibawa ke log atau UI.
class EngineError {
  const EngineError({required this.code});

  /// Kode error platform (di Android: tipe ExoPlaybackException).
  final int code;
}

/// Mode ulang di engine. Hanya `off` dan `one`: ulangi semua antrean
/// ditangani adapter (jendela engine hanya berisi 2 lagu, bukan antrean).
enum EngineLoopMode { off, one }

/// Interface engine audio yang dibutuhkan adapter.
abstract class PlayerEngine {
  Stream<EngineState> get stateStream;
  Stream<Duration> get positionStream;
  Stream<Duration?> get durationStream;
  Stream<Duration> get bufferedPositionStream;
  Stream<int?> get currentIndexStream;
  Stream<EngineError> get errorStream;

  /// ID sesi audio Android saat ini (untuk equalizer, P7). Null bila
  /// belum ada sesi (belum ada lagu yang dimuat) atau di platform lain.
  int? get androidAudioSessionId;

  /// Perubahan ID sesi audio Android.
  Stream<int?> get androidAudioSessionIdStream;

  /// Muat daftar sumber sebagai satu playlist berurutan, mulai dari
  /// [initialIndex] dan [initialPosition].
  Future<void> setSources(
    List<EngineSource> sources, {
    int initialIndex = 0,
    Duration? initialPosition,
  });

  /// Tambah satu sumber di ujung playlist.
  Future<void> addSource(EngineSource source);

  /// Hapus sumber di [index] dari playlist.
  Future<void> removeSourceAt(int index);

  Future<void> play();
  Future<void> pause();
  Future<void> stop();
  Future<void> seek(Duration position);
  Future<void> seekToNext();
  Future<void> seekToPrevious();
  Future<void> setSpeed(double speed);
  Future<void> setPitch(double pitch);
  Future<void> setLoopMode(EngineLoopMode mode);
  Future<void> setSkipSilence(bool enabled);

  /// Volume engine 0.0-1.0, dipakai untuk duck saat interupsi.
  Future<void> setVolume(double volume);

  Future<void> dispose();
}

/// Implementasi [PlayerEngine] di atas just_audio (Media3 ExoPlayer).
class JustAudioEngine implements PlayerEngine {
  JustAudioEngine({ja.AudioPlayer? player})
    : _player =
          player ??
          ja.AudioPlayer(
            // Interupsi (panggilan, headset dicabut) ditangani adapter
            // lewat audio_session, bukan oleh just_audio, supaya perilaku
            // lanjut-setelah-interupsi deterministik dan bisa dites.
            handleInterruptions: false,
            // Skip otomatis saat error dimatikan: adapter yang memutuskan
            // (re-resolve dulu, baru lewati lagu bila gagal total).
            maxSkipsOnError: 0,
          );

  final ja.AudioPlayer _player;

  static EngineProcessing _mapProcessing(ja.ProcessingState state) {
    switch (state) {
      case ja.ProcessingState.idle:
        return EngineProcessing.idle;
      case ja.ProcessingState.loading:
        return EngineProcessing.loading;
      case ja.ProcessingState.buffering:
        return EngineProcessing.buffering;
      case ja.ProcessingState.ready:
        return EngineProcessing.ready;
      case ja.ProcessingState.completed:
        return EngineProcessing.completed;
    }
  }

  @override
  Stream<EngineState> get stateStream => _player.playerStateStream.map(
    (ja.PlayerState s) => EngineState(
      playing: s.playing,
      processing: _mapProcessing(s.processingState),
    ),
  );

  @override
  Stream<Duration> get positionStream => _player.positionStream;

  @override
  Stream<Duration?> get durationStream => _player.durationStream;

  @override
  Stream<Duration> get bufferedPositionStream => _player.bufferedPositionStream;

  @override
  Stream<int?> get currentIndexStream => _player.currentIndexStream;

  @override
  Stream<EngineError> get errorStream =>
      _player.errorStream.map((ja.PlayerException e) => EngineError(code: e.code));

  /// ID sesi audio Android dari just_audio (P7, untuk equalizer).
  /// just_audio mengeksposnya lewat `androidAudioSessionId` (null bila
  /// belum ada sesi).
  @override
  int? get androidAudioSessionId => _player.androidAudioSessionId;

  @override
  Stream<int?> get androidAudioSessionIdStream =>
      _player.androidAudioSessionIdStream;

  @override
  Future<void> setSources(
    List<EngineSource> sources, {
    int initialIndex = 0,
    Duration? initialPosition,
  }) {
    return _player.setAudioSources(
      sources
          .map(
            (EngineSource s) =>
                ja.AudioSource.uri(s.uri, tag: s.tag),
          )
          .toList(growable: false),
      initialIndex: initialIndex,
      initialPosition: initialPosition,
    );
  }

  @override
  Future<void> addSource(EngineSource source) {
    return _player.addAudioSource(
      ja.AudioSource.uri(source.uri, tag: source.tag),
    );
  }

  @override
  Future<void> removeSourceAt(int index) {
    return _player.removeAudioSourceAt(index);
  }

  @override
  Future<void> play() => _player.play();

  @override
  Future<void> pause() => _player.pause();

  @override
  Future<void> stop() => _player.stop();

  @override
  Future<void> seek(Duration position) => _player.seek(position);

  @override
  Future<void> seekToNext() => _player.seekToNext();

  @override
  Future<void> seekToPrevious() => _player.seekToPrevious();

  @override
  Future<void> setSpeed(double speed) => _player.setSpeed(speed);

  @override
  Future<void> setPitch(double pitch) => _player.setPitch(pitch);

  @override
  Future<void> setLoopMode(EngineLoopMode mode) {
    return _player.setLoopMode(
      mode == EngineLoopMode.one ? ja.LoopMode.one : ja.LoopMode.off,
    );
  }

  @override
  Future<void> setSkipSilence(bool enabled) {
    return _player.setSkipSilenceEnabled(enabled);
  }

  @override
  Future<void> setVolume(double volume) => _player.setVolume(volume);

  @override
  Future<void> dispose() => _player.dispose();
}
