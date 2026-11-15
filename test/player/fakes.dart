/// Palsu untuk tes player: engine, resolver, sesi audio, dan port.
///
/// Tidak ada jaringan di sini: URL resolve memakai domain `.invalid` yang
/// tidak pernah bisa dihubungi, dan engine palsu tidak memutar audio
/// apa pun — state dikendalikan eksplisit oleh tes.
library;

import 'dart:async';

import 'package:laras/extractor/extractor.dart';
import 'package:laras/player/player.dart';

/// Lagu uji singkat.
Track testTrack(
  String videoId, {
  String? title,
  String? artist,
  Duration? duration,
}) {
  return Track(
    videoId: videoId,
    title: title ?? 'Lagu $videoId',
    artist: artist ?? 'Artis $videoId',
    duration: duration ?? const Duration(minutes: 3),
  );
}

/// Hasil resolve uji: URL `.invalid` (tidak pernah bisa dihubungi).
ResolvedAudio testResolved(
  String videoId, {
  String clientName = 'WEB_REMIX',
  Duration resolveDuration = const Duration(milliseconds: 100),
}) {
  return ResolvedAudio(
    videoId: videoId,
    url: 'https://example.invalid/audio/$videoId',
    itag: 140,
    mimeType: 'audio/mp4',
    bitrate: 128000,
    clientName: clientName,
    resolveDuration: resolveDuration,
    title: 'Lagu $videoId',
    lengthSeconds: 180,
  );
}

/// Engine audio palsu: merekam panggilan, state dikendalikan tes.
class FakeEngine implements PlayerEngine {
  final StreamController<EngineState> _state =
      StreamController<EngineState>.broadcast();
  final StreamController<Duration> _position =
      StreamController<Duration>.broadcast();
  final StreamController<Duration?> _duration =
      StreamController<Duration?>.broadcast();
  final StreamController<Duration> _buffered =
      StreamController<Duration>.broadcast();
  final StreamController<int?> _index =
      StreamController<int?>.broadcast();
  final StreamController<EngineError> _error =
      StreamController<EngineError>.broadcast();

  @override
  Stream<EngineState> get stateStream => _state.stream;

  @override
  Stream<Duration> get positionStream => _position.stream;

  @override
  Stream<Duration?> get durationStream => _duration.stream;

  @override
  Stream<Duration> get bufferedPositionStream => _buffered.stream;

  @override
  Stream<int?> get currentIndexStream => _index.stream;

  @override
  Stream<EngineError> get errorStream => _error.stream;

  /// Sumber yang saat ini ada di engine (diurutkan).
  List<EngineSource> sources = <EngineSource>[];

  /// Riwayat panggilan setSources: (sumber, initialIndex, initialPosition).
  final List<(List<EngineSource>, int, Duration?)> setSourcesCalls =
      <(List<EngineSource>, int, Duration?)>[];

  final List<EngineSource> addedSources = <EngineSource>[];
  final List<int> removedIndices = <int>[];
  int playCalls = 0;
  int pauseCalls = 0;
  int stopCalls = 0;
  final List<Duration> seekCalls = <Duration>[];
  int seekToNextCalls = 0;
  int seekToPreviousCalls = 0;
  double? speed;
  double? pitch;
  EngineLoopMode? loopMode;
  bool? skipSilence;
  final List<double> volumeCalls = <double>[];

  /// Gagalkan panggilan engine berikutnya dengan [error] (sekali pakai).
  Object? failNextCallWith;

  void emitState(EngineState state) => _state.add(state);

  void emitPlaying({bool playing = true}) {
    emitState(
      EngineState(playing: playing, processing: EngineProcessing.ready),
    );
  }

  void emitPosition(Duration position) => _position.add(position);

  void emitDuration(Duration? duration) => _duration.add(duration);

  void emitBuffered(Duration buffered) => _buffered.add(buffered);

  void emitCurrentIndex(int? index) => _index.add(index);

  void emitError([int code = 1]) => _error.add(EngineError(code: code));

  void _maybeFail() {
    final Object? error = failNextCallWith;
    if (error != null) {
      failNextCallWith = null;
      throw error;
    }
  }

  @override
  Future<void> setSources(
    List<EngineSource> newSources, {
    int initialIndex = 0,
    Duration? initialPosition,
  }) async {
    _maybeFail();
    sources = List<EngineSource>.of(newSources);
    setSourcesCalls.add((List<EngineSource>.of(newSources), initialIndex, initialPosition));
  }

  @override
  Future<void> addSource(EngineSource source) async {
    _maybeFail();
    sources.add(source);
    addedSources.add(source);
  }

  @override
  Future<void> removeSourceAt(int index) async {
    _maybeFail();
    removedIndices.add(index);
    if (index >= 0 && index < sources.length) sources.removeAt(index);
  }

  @override
  Future<void> play() async {
    _maybeFail();
    playCalls++;
  }

  @override
  Future<void> pause() async {
    _maybeFail();
    pauseCalls++;
  }

  @override
  Future<void> stop() async {
    _maybeFail();
    stopCalls++;
  }

  @override
  Future<void> seek(Duration position) async {
    _maybeFail();
    seekCalls.add(position);
  }

  @override
  Future<void> seekToNext() async {
    _maybeFail();
    seekToNextCalls++;
  }

  @override
  Future<void> seekToPrevious() async {
    _maybeFail();
    seekToPreviousCalls++;
  }

  @override
  Future<void> setSpeed(double value) async {
    speed = value;
  }

  @override
  Future<void> setPitch(double value) async {
    pitch = value;
  }

  @override
  Future<void> setLoopMode(EngineLoopMode mode) async {
    loopMode = mode;
  }

  @override
  Future<void> setSkipSilence(bool enabled) async {
    skipSilence = enabled;
  }

  @override
  Future<void> setVolume(double volume) async {
    volumeCalls.add(volume);
  }

  @override
  Future<void> dispose() async {
    await _state.close();
    await _position.close();
    await _duration.close();
    await _buffered.close();
    await _index.close();
    await _error.close();
  }
}

/// Resolver palsu: hasil per videoId dikendalikan tes.
///
/// [scripted] berisi antrean hasil per videoId — tiap resolve mengambil
/// hasil pertama (berguna untuk simulasi "gagal 2 kali lalu berhasil").
/// Bila tidak ada skrip, pakai [results]; bila tidak ada juga, sukses
/// dengan URL `.invalid` default.
class FakeAudioResolver implements AudioResolver {
  FakeAudioResolver({this.delay = Duration.zero});

  final Duration delay;

  final Map<String, List<Object>> scripted = <String, List<Object>>{};
  final Map<String, Object> results = <String, Object>{};
  final List<String> resolveCalls = <String>[];
  final List<ResolveLogEntry> _log = <ResolveLogEntry>[];

  @override
  List<ResolveLogEntry> get recentLog =>
      List<ResolveLogEntry>.unmodifiable(_log);

  @override
  Future<ResolvedAudio> resolve(String videoId, {bool dataSaver = false}) async {
    resolveCalls.add(videoId);
    if (delay != Duration.zero) await Future<void>.delayed(delay);
    Object? outcome;
    final List<Object>? script = scripted[videoId];
    if (script != null && script.isNotEmpty) {
      outcome = script.removeAt(0);
    } else {
      outcome = results[videoId];
    }
    if (outcome is Exception) throw outcome;
    if (outcome is Error) throw outcome;
    final ResolvedAudio resolved = outcome is ResolvedAudio
        ? outcome
        : testResolved(videoId);
    _log.add(
      ResolveLogEntry(
        timestamp: DateTime.utc(2026, 11, 16),
        videoId: videoId,
        clientName: resolved.clientName,
        outcome: 'OK',
        durationMs: resolved.resolveDuration.inMilliseconds,
      ),
    );
    return resolved;
  }
}

/// Sesi audio palsu: interupsi dan headset dicabut dikendalikan tes.
class FakeAudioSession implements AudioSessionPort {
  final StreamController<InterruptionEvent> _interruption =
      StreamController<InterruptionEvent>.broadcast();
  final StreamController<void> _noisy =
      StreamController<void>.broadcast();

  @override
  Stream<InterruptionEvent> get interruptionStream => _interruption.stream;

  @override
  Stream<void> get becomingNoisyStream => _noisy.stream;

  int configureMusicCalls = 0;
  final List<bool> setActiveCalls = <bool>[];

  void emitInterruption({required bool begin, required InterruptionKind kind}) {
    _interruption.add(InterruptionEvent(begin: begin, kind: kind));
  }

  void emitNoisy() => _noisy.add(null);

  @override
  Future<void> configureMusic() async {
    configureMusicCalls++;
  }

  @override
  Future<void> setActive(bool active) async {
    setActiveCalls.add(active);
  }

  Future<void> dispose() async {
    await _interruption.close();
    await _noisy.close();
  }
}

/// Port player palsu untuk tes widget dan handler: snapshot dikendalikan
/// tes, semua panggilan direkam.
class FakeAudioPlayerPort implements AudioPlayerPort {
  FakeAudioPlayerPort({PlayerSnapshot? initialSnapshot})
    : _snapshot = initialSnapshot ?? PlayerSnapshot.idle;

  PlayerSnapshot _snapshot;
  final StreamController<PlayerSnapshot> _state =
      StreamController<PlayerSnapshot>.broadcast();
  final StreamController<Duration> _position =
      StreamController<Duration>.broadcast();
  final StreamController<Duration> _buffered =
      StreamController<Duration>.broadcast();

  Duration _positionValue = Duration.zero;
  Duration _bufferedValue = Duration.zero;

  @override
  PlayerSnapshot get snapshot => _snapshot;

  @override
  Stream<PlayerSnapshot> get stateStream => _state.stream;

  @override
  Duration get position => _positionValue;

  @override
  Stream<Duration> get positionStream => _position.stream;

  @override
  Duration get bufferedPosition => _bufferedValue;

  @override
  Stream<Duration> get bufferedPositionStream => _buffered.stream;

  /// Ganti snapshot dan siarkan ke pendengar.
  void emitSnapshot(PlayerSnapshot snap) {
    _snapshot = snap;
    _state.add(snap);
  }

  void emitPosition(Duration value) {
    _positionValue = value;
    _position.add(value);
  }

  void emitBuffered(Duration value) {
    _bufferedValue = value;
    _buffered.add(value);
  }

  final List<(List<Track>, int, bool)> setQueueCalls =
      <(List<Track>, int, bool)>[];
  int playCalls = 0;
  int pauseCalls = 0;
  int stopCalls = 0;
  final List<Duration> seekCalls = <Duration>[];
  int skipToNextCalls = 0;
  int skipToPreviousCalls = 0;
  final List<int> skipToIndexCalls = <int>[];
  final List<Track> addToQueueCalls = <Track>[];
  final List<(int, Track)> insertInQueueCalls = <(int, Track)>[];
  final List<int> removeFromQueueCalls = <int>[];
  final List<(int, int)> moveInQueueCalls = <(int, int)>[];
  int clearQueueCalls = 0;
  final List<bool> setShuffleCalls = <bool>[];
  final List<RepeatMode> setRepeatModeCalls = <RepeatMode>[];
  final List<double> setSpeedCalls = <double>[];
  final List<double> setPitchCalls = <double>[];
  final List<bool> setSkipSilenceCalls = <bool>[];
  bool addToQueueResult = true;
  bool insertInQueueResult = true;

  @override
  Future<void> setQueue(
    List<Track> tracks, {
    int initialIndex = 0,
    bool autoplay = false,
  }) async {
    setQueueCalls.add((List<Track>.of(tracks), initialIndex, autoplay));
  }

  @override
  Future<void> play() async {
    playCalls++;
  }

  @override
  Future<void> pause() async {
    pauseCalls++;
  }

  @override
  Future<void> stop() async {
    stopCalls++;
  }

  @override
  Future<void> seek(Duration position) async {
    seekCalls.add(position);
  }

  @override
  Future<void> skipToNext() async {
    skipToNextCalls++;
  }

  @override
  Future<void> skipToPrevious() async {
    skipToPreviousCalls++;
  }

  @override
  Future<void> skipToIndex(int index) async {
    skipToIndexCalls.add(index);
  }

  @override
  Future<bool> addToQueue(Track track) async {
    addToQueueCalls.add(track);
    return addToQueueResult;
  }

  @override
  Future<bool> insertInQueue(int index, Track track) async {
    insertInQueueCalls.add((index, track));
    return insertInQueueResult;
  }

  @override
  Future<void> removeFromQueue(int index) async {
    removeFromQueueCalls.add(index);
  }

  @override
  Future<void> moveInQueue(int from, int to) async {
    moveInQueueCalls.add((from, to));
  }

  @override
  Future<void> clearQueue() async {
    clearQueueCalls++;
  }

  @override
  Future<void> setShuffle(bool enabled) async {
    setShuffleCalls.add(enabled);
  }

  @override
  Future<void> setRepeatMode(RepeatMode mode) async {
    setRepeatModeCalls.add(mode);
  }

  @override
  Future<void> setSpeed(double speed) async {
    setSpeedCalls.add(speed);
  }

  @override
  Future<void> setPitch(double pitch) async {
    setPitchCalls.add(pitch);
  }

  @override
  Future<void> setSkipSilence(bool enabled) async {
    setSkipSilenceCalls.add(enabled);
  }

  @override
  Future<void> dispose() async {
    await _state.close();
    await _position.close();
    await _buffered.close();
  }
}

/// Solver palsu untuk merakit [PlayerService] di tes widget.
class FakeSignatureSolver implements SignatureSolver {
  @override
  Future<String> solve({
    required PlayerScript script,
    required AudioFormat format,
  }) async {
    return 'https://example.invalid/solved';
  }

  @override
  Future<void> dispose() async {}
}
