/// Implementasi [AudioPlayerPort] di atas just_audio + audio_session.
///
/// Desain yang mengikat:
///
/// * Antrean milik [QueueController]; engine selalu jalan dengan shuffle
///   mati dan hanya mengenal jendela 2 lagu (lagu yang sedang diputar +
///   lagu berikutnya). Jendela ini yang memberi gapless: ExoPlayer
///   menyiapkan lagu berikutnya sebelum lagu yang sedang diputar habis.
/// * URL stream di-resolve malas (saat giliran lagu tiba) dan hanya
///   disimpan di memori untuk lagu di jendela.
/// * Seam re-resolve (gate P1, K-F2-05): bila pemutaran gagal di tengah
///   lagu (URL kedaluwarsa, 403, jaringan putus), port otomatis resolve
///   ulang lagu yang sama dan lanjut dari posisi terakhir (toleransi
///   kurang lebih 2 detik), maks 3 percobaan per lagu, tanpa interaksi
///   pengguna. Bila ketiganya gagal, lagu dilewati dan kegagalan
///   dilaporkan jujur lewat [PlayerSnapshot.lastError].
/// * Interupsi ditangani di sini lewat audio_session (just_audio
///   dibuat dengan `handleInterruptions: false`): panggilan masuk
///   menjeda lalu lanjut otomatis, headset dicabut menjeda tanpa lanjut
///   otomatis, duck mengecilkan volume sementara.
///
/// Pesan error engine tidak pernah dicetak: pesan ExoPlayer bisa
/// mengandung URL stream.
library;

import 'dart:async';

import 'package:laras/extractor/extractor.dart';

import 'audio_player_port.dart';
import 'audio_session_port.dart';
import 'player_engine.dart';
import 'player_state.dart';
import 'queue_controller.dart';
import 'track.dart';

class JustAudioPlayerPort implements AudioPlayerPort {
  // Field privat, nama parameter publik; initializing formal tidak bisa
  // dipakai di sini (lint prefer_initializing_formals diabaikan per baris).
  JustAudioPlayerPort({
    required PlayerEngine engine,
    required AudioResolver resolver,
    AudioSessionPort? session,
    QueueController? queueController,
  }) : _engine = engine, // ignore: prefer_initializing_formals
       _resolver = resolver, // ignore: prefer_initializing_formals
       _session = session, // ignore: prefer_initializing_formals
       _queue = queueController ?? QueueController() {
    _engineStateSub = _engine.stateStream.listen(_onEngineState);
    _positionSub = _engine.positionStream.listen(_onPosition);
    _durationSub = _engine.durationStream.listen(_onDuration);
    _bufferedSub = _engine.bufferedPositionStream.listen(_onBuffered);
    _indexSub = _engine.currentIndexStream.listen(_onEngineIndex);
    _errorSub = _engine.errorStream.listen(_onEngineError);
    _session?.configureMusic().then<void>(
      (_) {},
      onError: (_) {
        // Sesi audio gagal: pemutaran tetap jalan, hanya penanganan
        // interupsi yang tidak aktif.
      },
    );
    _noisySub = _session?.becomingNoisyStream.listen((_) {
      if (_snapshot.playing) unawaited(pause());
    });
    _interruptionSub = _session?.interruptionStream.listen(_onInterruption);
  }

  /// Maks percobaan re-resolve per lagu (keputusan gate P1).
  static const int maxReResolveAttempts = 3;

  /// Batas tombol sebelumnya: di atas ini, tombol kembali ke awal lagu
  /// yang sama; di bawah ini, pindah ke lagu sebelumnya.
  static const Duration previousThreshold = Duration(seconds: 3);

  /// Volume saat duck (navigator berbicara). Nilai yang dipilih: cukup
  /// pelan untuk mendengar navigator, cukup keras untuk tetap sadar lagu
  /// masih jalan.
  static const double duckVolume = 0.3;

  final PlayerEngine _engine;
  final AudioResolver _resolver;
  final AudioSessionPort? _session;
  final QueueController _queue;

  PlayerSnapshot _snapshot = PlayerSnapshot.idle;
  final StreamController<PlayerSnapshot> _stateController =
      StreamController<PlayerSnapshot>.broadcast();
  final StreamController<Duration> _positionController =
      StreamController<Duration>.broadcast();
  final StreamController<Duration> _bufferedController =
      StreamController<Duration>.broadcast();

  Duration _position = Duration.zero;
  Duration _buffered = Duration.zero;

  /// Posisi terakhir yang diketahui, untuk lanjut setelah re-resolve.
  Duration _lastPosition = Duration.zero;

  /// URL hasil resolve untuk lagu di jendela (maks 2 entri). Memori saja.
  final Map<String, ResolvedAudio> _resolved = <String, ResolvedAudio>{};

  /// videoId lagu di engine, sesuai urutan sumber. Elemen pertama selalu
  /// lagu yang sedang diputar; elemen kedua (bila ada) lagu berikutnya.
  List<String> _windowTags = <String>[];

  bool _sourceLoaded = false;
  bool _pendingPlay = false;
  bool _reResolving = false;
  int _reResolveAttempts = 0;
  EngineProcessing? _lastProcessing;

  /// Generasi antrean: naik tiap kali lagu/antrean berubah karena aksi
  /// pengguna atau perpindahan otomatis. Pekerjaan async yang dimulai di
  /// generasi lama dibatalkan saat generasinya tidak cocok lagi.
  int _generation = 0;

  Future<bool>? _loadFuture;
  int _loadFutureGen = -1;

  bool _resumeAfterInterruption = false;
  bool _userPausedDuringInterruption = false;
  bool _interruptionActive = false;
  bool _ducked = false;

  bool _disposed = false;

  StreamSubscription<EngineState>? _engineStateSub;
  StreamSubscription<Duration>? _positionSub;
  StreamSubscription<Duration?>? _durationSub;
  StreamSubscription<Duration>? _bufferedSub;
  StreamSubscription<int?>? _indexSub;
  StreamSubscription<EngineError>? _errorSub;
  StreamSubscription<void>? _noisySub;
  StreamSubscription<InterruptionEvent>? _interruptionSub;

  @override
  PlayerSnapshot get snapshot => _snapshot;

  @override
  Stream<PlayerSnapshot> get stateStream => _stateController.stream;

  @override
  Duration get position => _position;

  @override
  Stream<Duration> get positionStream => _positionController.stream;

  @override
  Duration get bufferedPosition => _buffered;

  @override
  Stream<Duration> get bufferedPositionStream => _bufferedController.stream;

  void _emit(PlayerSnapshot next) {
    if (_disposed || next == _snapshot) return;
    _snapshot = next;
    _stateController.add(next);
  }

  /// Snapshot kosong yang mempertahankan pengaturan pemutaran.
  PlayerSnapshot _freshIdle() {
    return PlayerSnapshot(
      shuffleEnabled: _snapshot.shuffleEnabled,
      repeatMode: _snapshot.repeatMode,
      speed: _snapshot.speed,
      pitch: _snapshot.pitch,
      skipSilence: _snapshot.skipSilence,
    );
  }

  Future<void> _setSessionActive(bool active) async {
    try {
      await _session?.setActive(active);
    } on Object catch (_) {
      // Sesi audio gagal: pemutaran tetap jalan.
    }
  }

  Future<void> _playEngine() async {
    await _setSessionActive(true);
    await _engine.play();
  }

  // ----- Pendengar engine -----

  void _onEngineState(EngineState state) {
    if (_disposed) return;
    final EngineProcessing processing = state.processing;
    final bool becameCompleted =
        processing == EngineProcessing.completed &&
        _lastProcessing != EngineProcessing.completed;
    _lastProcessing = processing;
    if (becameCompleted) {
      unawaited(_onCompleted());
      return;
    }
    // Selama re-resolve, status snapshot tetap buffering + reResolving;
    // event engine diabaikan supaya UI tidak berkedip.
    if (_reResolving) return;
    if (state.playing &&
        processing == EngineProcessing.ready &&
        _reResolveAttempts > 0) {
      // Pemutaran pulih setelah re-resolve: anggaran percobaan segar lagi
      // untuk kegagalan berikutnya di lagu yang sama.
      _reResolveAttempts = 0;
    }
    _emit(
      _snapshot.copyWith(
        playing: state.playing,
        status: _mapProcessing(processing),
      ),
    );
  }

  static PlayerStatus _mapProcessing(EngineProcessing processing) {
    switch (processing) {
      case EngineProcessing.idle:
        return PlayerStatus.idle;
      case EngineProcessing.loading:
        return PlayerStatus.loading;
      case EngineProcessing.buffering:
        return PlayerStatus.buffering;
      case EngineProcessing.ready:
        return PlayerStatus.ready;
      case EngineProcessing.completed:
        return PlayerStatus.completed;
    }
  }

  void _onPosition(Duration p) {
    if (_disposed) return;
    _position = p;
    _lastPosition = p;
    _positionController.add(p);
  }

  void _onDuration(Duration? d) {
    if (_disposed) return;
    if (d == null) {
      _emit(_snapshot.copyWith(clearDuration: true));
    } else {
      _emit(_snapshot.copyWith(duration: d));
    }
  }

  void _onBuffered(Duration b) {
    if (_disposed) return;
    _buffered = b;
    _bufferedController.add(b);
  }

  void _onEngineIndex(int? index) {
    if (_disposed || index == null || index != 1) return;
    if (_windowTags.length < 2) return;
    unawaited(_onWindowAdvanced());
  }

  Future<void> _onWindowAdvanced() async {
    // Pindah lagu membatalkan pekerjaan async lagu lama (mis. re-resolve
    // yang masih berjalan): generasinya tidak cocok lagi.
    _generation++;
    final Track? expected = _queue.trackAfterCurrent;
    final String advancedTag = _windowTags[1];
    if (expected == null || expected.videoId != advancedTag) {
      // Jendela dan antrean tidak sinkron (mutasi antrean beradu dengan
      // perpindahan otomatis): bangun ulang jendela dari antrean.
      final Track? current = _queue.current;
      if (current == null) return;
      final bool wasPlaying = _snapshot.playing;
      await _loadCurrent(autoplay: wasPlaying, userInitiated: false);
      return;
    }
    _queue.jumpTo(_queue.currentIndex + 1);
    _windowTags.removeAt(0);
    _lastPosition = Duration.zero;
    _position = Duration.zero;
    _positionController.add(Duration.zero);
    _reResolveAttempts = 0;
    final Track now = _queue.current!;
    _emit(
      _snapshot.copyWith(
        currentTrack: now,
        currentIndex: _queue.currentIndex,
        queue: _queue.tracks,
        duration: now.duration,
        clearError: true,
      ),
    );
    _pruneResolvedCache();
    final Track? following = _queue.trackAfterCurrent;
    if (following != null) unawaited(_appendNext(following));
  }

  void _onEngineError(EngineError error) {
    if (_disposed || _reResolving || _loadFuture != null) return;
    if (_snapshot.status == PlayerStatus.idle) return;
    final Track? track = _queue.current;
    if (track == null) return;
    final Duration? duration = _snapshot.duration;
    if (duration != null &&
        _lastPosition > duration - const Duration(seconds: 3)) {
      // Gagal di ujung lagu: anggap selesai, lanjut ke lagu berikutnya.
      unawaited(_onCompleted());
      return;
    }
    if (track.isLocal) {
      // Lagu lokal (file di perangkat, P5) TIDAK BOLEH memicu resolve
      // jaringan: tidak ada URL yang bisa di-resolve ulang, file-nya ya
      // file-nya. Langsung lewati ke lagu berikutnya tanpa menyentuh
      // resolver sama sekali.
      unawaited(_failCurrentTrack(null));
      return;
    }
    unawaited(_reResolveLoop(track));
  }

  // ----- Re-resolve (seam K-F2-05) -----

  Future<void> _reResolveLoop(Track track) async {
    if (_reResolving) return;
    _reResolving = true;
    final bool wasPlaying = _snapshot.playing;
    _emit(
      _snapshot.copyWith(reResolving: true, status: PlayerStatus.buffering),
    );
    ExtractorException? lastError;
    try {
      for (int attempt = 1; attempt <= maxReResolveAttempts; attempt++) {
        _reResolveAttempts = attempt;
        final int gen = _generation;
        try {
          // URL lama sudah mati: buang dari cache supaya resolve segar.
          _resolved.remove(track.videoId);
          final ResolvedAudio resolved = await _resolveFor(track);
          if (gen != _generation || _disposed) return;
          final Duration resumeAt = _lastPosition;
          await _buildWindow(
            track,
            Uri.parse(resolved.url),
            startAt: resumeAt,
          );
          if (gen != _generation || _disposed) return;
          if (wasPlaying) await _playEngine();
          _reResolveAttempts = 0;
          _emit(_snapshot.copyWith(reResolving: false));
          return;
        } on ExtractorException catch (e) {
          lastError = e;
        } on Object catch (_) {
          // Error engine (setSources/play): coba lagi dengan URL segar.
        }
      }
      await _failCurrentTrack(lastError);
    } finally {
      _reResolving = false;
      if (!_disposed) _emit(_snapshot.copyWith(reResolving: false));
    }
  }

  /// Petakan penyebab kegagalan resolve ke jenis yang tampil ke pengguna.
  /// Timeout dibedakan dari putusnya jaringan: pesannya berbeda ("internet
  /// lambat, coba lagi" vs "tidak ada internet").
  static PlaybackFailureKind _kindOf(ExtractorException? cause) {
    if (cause == null) return PlaybackFailureKind.unplayable;
    if (cause.isTimeout) return PlaybackFailureKind.timeout;
    if (cause.isNetworkError) return PlaybackFailureKind.network;
    return PlaybackFailureKind.unplayable;
  }

  /// Lagu gagal total setelah re-resolve habis: laporkan jujur, lalu
  /// coba lagu berikutnya (lewati yang tidak bisa diputar).
  Future<void> _failCurrentTrack(ExtractorException? cause) async {
    final Track? track = _queue.current;
    if (track == null || _disposed) return;
    final PlaybackFailureKind kind = _kindOf(cause);
    // Indeks berikutnya mengabaikan mode ulangi satu: lagu yang baru
    // gagal total tidak dicoba lagi di rantai ini.
    final int current = _queue.currentIndex;
    final int? next = current + 1 < _queue.length
        ? current + 1
        : (_queue.repeatMode == RepeatMode.all ? 0 : null);
    final int skipped = await _loadWithSkipChain(next, autoplay: true);
    if (_disposed) return;
    if (skipped >= 0) {
      _emit(
        _snapshot.copyWith(
          lastError: PlaybackFailure(
            kind: kind,
            trackTitle: track.title,
            skippedCount: skipped + 1,
          ),
        ),
      );
      return;
    }
    _emit(
      _snapshot.copyWith(
        status: PlayerStatus.error,
        playing: false,
        lastError: PlaybackFailure(kind: kind, trackTitle: track.title),
      ),
    );
  }

  /// Muat lagu di [startIndex], dan bila gagal terus mencoba lagu-lagu
  /// berikutnya sampai satu berhasil atau semua sudah dicoba.
  /// Mengembalikan jumlah lagu yang dilewati, atau -1 bila tidak ada
  /// lagu yang berhasil dimuat. Mode ulangi satu diperlakukan seperti
  /// mode mati di rantai ini (tidak mengulang lagu yang gagal).
  Future<int> _loadWithSkipChain(int? startIndex, {required bool autoplay}) async {
    if (startIndex == null) return -1;
    final Set<int> tried = <int>{};
    int target = startIndex;
    int skipped = 0;
    while (!tried.contains(target)) {
      tried.add(target);
      _generation++;
      _queue.jumpTo(target);
      _reResolveAttempts = 0;
      _lastPosition = Duration.zero;
      final bool ok = await _loadCurrent(
        autoplay: autoplay,
        userInitiated: false,
      );
      if (ok) return skipped;
      if (_disposed) return -1;
      skipped++;
      final int current = _queue.currentIndex;
      int? next;
      if (current + 1 < _queue.length) {
        next = current + 1;
      } else if (_queue.repeatMode == RepeatMode.all) {
        next = 0;
      }
      if (next == null) return -1;
      target = next;
    }
    return -1;
  }

  Future<void> _onCompleted() async {
    if (_disposed || _reResolving) return;
    final int? next = _queue.nextIndexForCompletion();
    if (next == null) {
      _emit(_snapshot.copyWith(status: PlayerStatus.completed, playing: false));
      return;
    }
    final int skipped = await _loadWithSkipChain(next, autoplay: true);
    if (_disposed) return;
    if (skipped >= 0) {
      if (skipped > 0) {
        _emit(
          _snapshot.copyWith(
            lastError: PlaybackFailure(
              kind: PlaybackFailureKind.unplayable,
              trackTitle: '',
              skippedCount: skipped,
            ),
          ),
        );
      }
      return;
    }
    _emit(
      _snapshot.copyWith(
        status: PlayerStatus.error,
        playing: false,
        lastError: PlaybackFailure(
          kind: PlaybackFailureKind.unplayable,
          trackTitle: _queue.current?.title ?? '',
        ),
      ),
    );
  }

  // ----- Muat lagu + jendela gapless -----

  /// Resolve URL lagu, memakai cache jendela bila ada.
  Future<ResolvedAudio> _resolveFor(Track track) async {
    final ResolvedAudio? cached = _resolved[track.videoId];
    if (cached != null) return cached;
    final ResolvedAudio resolved = await _resolver.resolve(track.videoId);
    _resolved[track.videoId] = resolved;
    _emit(
      _snapshot.copyWith(
        lastResolve: ResolveInfo(
          videoId: resolved.videoId,
          clientName: resolved.clientName,
          resolveDuration: resolved.resolveDuration,
        ),
      ),
    );
    return resolved;
  }

  Future<Uri> _sourceUriFor(Track track) async {
    if (track.isLocal) return Uri.file(track.localPath!);
    final ResolvedAudio resolved = await _resolveFor(track);
    return Uri.parse(resolved.url);
  }

  /// Muat lagu yang sedang diputar di antrean. Serial: panggilan kedua
  /// selagi load berjalan memakai future yang sama (generasi yang sama).
  /// Mengembalikan false bila lagu gagal dimuat.
  Future<bool> _loadCurrent({
    required bool autoplay,
    required bool userInitiated,
  }) {
    final Future<bool>? existing = _loadFuture;
    if (existing != null && _loadFutureGen == _generation) {
      if (autoplay) _pendingPlay = true;
      return existing;
    }
    final Future<bool> future = _doLoad(
      autoplay: autoplay,
      userInitiated: userInitiated,
    );
    _loadFuture = future;
    _loadFutureGen = _generation;
    unawaited(
      future.then<void>((_) {
        if (_loadFuture == future) {
          _loadFuture = null;
          _loadFutureGen = -1;
        }
      }),
    );
    return future;
  }

  Future<bool> _doLoad({
    required bool autoplay,
    required bool userInitiated,
  }) async {
    final Track? track = _queue.current;
    if (track == null || _disposed) return false;
    final int gen = _generation;
    _emit(
      _snapshot.copyWith(
        // Identitas lagu diumumkan di awal muat: rantai lewati dan
        // perpindahan otomatis mengubah antrean tanpa jalur lain yang
        // meng-update snapshot, jadi tanpa ini UI stuck di lagu lama.
        currentTrack: track,
        currentIndex: _queue.currentIndex,
        queue: _queue.tracks,
        duration: track.duration,
        clearDuration: track.duration == null,
        status: PlayerStatus.loading,
        clearError: true,
      ),
    );
    try {
      final Uri uri = await _sourceUriFor(track);
      if (gen != _generation || _disposed) return false;
      await _buildWindow(track, uri);
      if (gen != _generation || _disposed) return false;
      final bool shouldPlay = autoplay || _pendingPlay;
      _pendingPlay = false;
      if (shouldPlay) await _playEngine();
      return true;
    } on ExtractorException catch (e) {
      if (userInitiated && gen == _generation && !_disposed) {
        _emit(
          _snapshot.copyWith(
            status: PlayerStatus.error,
            playing: false,
            lastError: PlaybackFailure(
              kind: _kindOf(e),
              trackTitle: track.title,
            ),
          ),
        );
      }
      return false;
    } on Object catch (_) {
      if (userInitiated && gen == _generation && !_disposed) {
        _emit(
          _snapshot.copyWith(
            status: PlayerStatus.error,
            playing: false,
            lastError: PlaybackFailure(
              kind: PlaybackFailureKind.unplayable,
              trackTitle: track.title,
            ),
          ),
        );
      }
      return false;
    }
  }

  /// Bangun jendela engine: lagu ini + pramuat lagu berikutnya di latar.
  Future<void> _buildWindow(Track track, Uri uri, {Duration? startAt}) async {
    _windowTags = <String>[track.videoId];
    await _engine.setSources(
      <EngineSource>[EngineSource(uri: uri, tag: track.videoId)],
      initialPosition: startAt,
    );
    _sourceLoaded = true;
    final Track? next = _queue.trackAfterCurrent;
    if (next != null) unawaited(_appendNext(next));
  }

  /// Pramuat lagu berikutnya ke jendela (best-effort; gagal diam-diam,
  /// lagu itu di-resolve lagi saat gilirannya tiba).
  Future<void> _appendNext(Track track) async {
    final int gen = _generation;
    try {
      final Uri uri = await _sourceUriFor(track);
      if (gen != _generation || _disposed) return;
      if (!identical(_queue.trackAfterCurrent, track)) return;
      if (_windowTags.length > 1) return;
      await _engine.addSource(
        EngineSource(uri: uri, tag: track.videoId),
      );
      if (gen != _generation || _disposed) return;
      _windowTags.add(track.videoId);
    } on Object catch (_) {
      // Pramuat gagal: bukan error pengguna; coba lagi saat giliran tiba.
    }
  }

  /// Buang cache resolve di luar jendela (lagu yang sedang diputar +
  /// lagu berikutnya). URL tidak pernah menumpuk di memori.
  void _pruneResolvedCache() {
    final Set<String> keep = <String>{
      if (_queue.current != null) _queue.current!.videoId,
      if (_queue.trackAfterCurrent != null)
        _queue.trackAfterCurrent!.videoId,
    };
    _resolved.removeWhere((String key, _) => !keep.contains(key));
  }

  /// Sinkronkan lagu berikutnya di jendela setelah antrean berubah
  /// (tambah/sisip/hapus/pindah/acak). Sumber basi dihapus segera;
  /// lagu berikutnya yang baru dipramuat di latar supaya mutasi antrean
  /// tidak menunggu jaringan.
  Future<void> _syncWindowAfterMutation() async {
    if (_windowTags.isEmpty || !_sourceLoaded) return;
    final Track? expectedNext = _queue.trackAfterCurrent;
    final String? actualNext =
        _windowTags.length > 1 ? _windowTags[1] : null;
    if (expectedNext?.videoId == actualNext) return;
    if (actualNext != null) {
      try {
        await _engine.removeSourceAt(1);
      } on Object catch (_) {
        // Engine dan jendela tidak sinkron: bangun ulang di pemakaian
        // berikutnya (skipToNext memakai _advanceTo bila jendela kosong).
      }
      _windowTags.removeAt(1);
    }
    if (expectedNext != null) unawaited(_appendNext(expectedNext));
  }

  Future<void> _advanceTo(int index, {required bool autoplay}) async {
    _generation++;
    _queue.jumpTo(index);
    _reResolveAttempts = 0;
    _lastPosition = Duration.zero;
    _position = Duration.zero;
    _positionController.add(Duration.zero);
    final Track track = _queue.current!;
    _emit(
      _snapshot.copyWith(
        currentTrack: track,
        currentIndex: index,
        queue: _queue.tracks,
        status: PlayerStatus.loading,
        duration: track.duration,
        playing: autoplay,
        clearError: true,
      ),
    );
    await _loadCurrent(autoplay: autoplay, userInitiated: true);
  }

  // ----- Interupsi (audio_session) -----

  void _onInterruption(InterruptionEvent event) {
    if (_disposed) return;
    if (event.begin) {
      if (event.kind == InterruptionKind.duck) {
        _ducked = true;
        unawaited(_engine.setVolume(duckVolume));
      } else {
        if (_snapshot.playing) {
          _resumeAfterInterruption = true;
          unawaited(pause());
        }
        // Tandai aktif sesudah pause sendiri, supaya jeda manual pengguna
        // selama interupsi bisa dibedakan dari jeda otomatis ini.
        _interruptionActive = true;
      }
      return;
    }
    if (_ducked) {
      _ducked = false;
      unawaited(_engine.setVolume(1.0));
    }
    if (_resumeAfterInterruption && !_userPausedDuringInterruption) {
      unawaited(play());
    }
    _resumeAfterInterruption = false;
    _userPausedDuringInterruption = false;
    _interruptionActive = false;
  }

  // ----- AudioPlayerPort -----

  @override
  Future<void> setQueue(
    List<Track> tracks, {
    int initialIndex = 0,
    bool autoplay = false,
  }) async {
    if (_disposed) return;
    _queue.setQueue(tracks, initialIndex: initialIndex);
    _generation++;
    _pendingPlay = false;
    _reResolveAttempts = 0;
    _lastPosition = Duration.zero;
    _position = Duration.zero;
    _positionController.add(Duration.zero);
    _resolved.clear();
    _windowTags = <String>[];
    _sourceLoaded = false;
    final Track? current = _queue.current;
    _emit(
      PlayerSnapshot(
        currentTrack: current,
        queue: _queue.tracks,
        currentIndex: _queue.currentIndex,
        status: current == null
            ? PlayerStatus.idle
            : PlayerStatus.loading,
        duration: current?.duration,
        shuffleEnabled: _queue.shuffleEnabled,
        repeatMode: _queue.repeatMode,
        speed: _snapshot.speed,
        pitch: _snapshot.pitch,
        skipSilence: _snapshot.skipSilence,
      ),
    );
    if (current == null) {
      await _engine.stop();
      return;
    }
    await _loadCurrent(autoplay: autoplay, userInitiated: true);
  }

  @override
  Future<void> play() async {
    if (_disposed) return;
    final Track? track = _queue.current;
    if (track == null) return;
    if (_snapshot.status == PlayerStatus.completed) {
      await seek(Duration.zero);
    }
    if (_snapshot.status == PlayerStatus.error) {
      // Coba lagi dari awal dengan URL segar.
      _resolved.remove(track.videoId);
      _reResolveAttempts = 0;
      await _loadCurrent(autoplay: true, userInitiated: true);
      return;
    }
    if (_loadFuture != null) {
      _pendingPlay = true;
      return;
    }
    if (!_sourceLoaded) {
      await _loadCurrent(autoplay: true, userInitiated: true);
      return;
    }
    _pendingPlay = false;
    await _playEngine();
  }

  @override
  Future<void> pause() async {
    if (_disposed) return;
    if (_interruptionActive) _userPausedDuringInterruption = true;
    _pendingPlay = false;
    await _engine.pause();
  }

  @override
  Future<void> stop() async {
    if (_disposed) return;
    _generation++;
    _pendingPlay = false;
    _reResolveAttempts = 0;
    _sourceLoaded = false;
    _windowTags = <String>[];
    _position = Duration.zero;
    _lastPosition = Duration.zero;
    _positionController.add(Duration.zero);
    await _engine.stop();
    await _setSessionActive(false);
    _emit(_snapshot.copyWith(playing: false, status: PlayerStatus.idle));
  }

  @override
  Future<void> seek(Duration position) async {
    if (_disposed) return;
    Duration target = position;
    if (target < Duration.zero) target = Duration.zero;
    final Duration? duration = _snapshot.duration;
    if (duration != null && target > duration) target = duration;
    _lastPosition = target;
    await _engine.seek(target);
  }

  @override
  Future<void> skipToNext() async {
    if (_disposed || _queue.current == null) return;
    if (_windowTags.length > 1) {
      // Batalkan pekerjaan async lagu lama (mis. re-resolve) sebelum
      // engine pindah: indeks baru tiba lewat event sesudah ini.
      _generation++;
      await _engine.seekToNext();
      return;
    }
    final int? next = _queue.nextIndexForSkip();
    if (next == null) return;
    await _advanceTo(next, autoplay: _snapshot.playing);
  }

  @override
  Future<void> skipToPrevious() async {
    if (_disposed || _queue.current == null) return;
    if (_position > previousThreshold) {
      await seek(Duration.zero);
      return;
    }
    final int? prev = _queue.previousIndexForSkip();
    if (prev == null) {
      await seek(Duration.zero);
      return;
    }
    await _advanceTo(prev, autoplay: _snapshot.playing);
  }

  @override
  Future<void> skipToIndex(int index) async {
    if (_disposed) return;
    if (index < 0 || index >= _queue.length) return;
    if (index == _queue.currentIndex) {
      await seek(Duration.zero);
      return;
    }
    await _advanceTo(index, autoplay: _snapshot.playing);
  }

  @override
  Future<bool> addToQueue(Track track) async {
    if (_disposed) return false;
    final bool wasEmpty = _queue.isEmpty;
    final bool ok = _queue.add(track);
    if (!ok) return false;
    _emit(
      _snapshot.copyWith(
        queue: _queue.tracks,
        currentIndex: _queue.currentIndex,
        currentTrack: _queue.current,
      ),
    );
    if (wasEmpty) {
      await _loadCurrent(autoplay: false, userInitiated: true);
    } else {
      await _syncWindowAfterMutation();
    }
    return true;
  }

  @override
  Future<bool> insertInQueue(int index, Track track) async {
    if (_disposed) return false;
    final bool wasEmpty = _queue.isEmpty;
    final bool ok = _queue.insert(index, track);
    if (!ok) return false;
    _emit(
      _snapshot.copyWith(
        queue: _queue.tracks,
        currentIndex: _queue.currentIndex,
        currentTrack: _queue.current,
      ),
    );
    if (wasEmpty) {
      await _loadCurrent(autoplay: false, userInitiated: true);
    } else {
      await _syncWindowAfterMutation();
    }
    return true;
  }

  @override
  Future<void> removeFromQueue(int index) async {
    if (_disposed) return;
    if (index < 0 || index >= _queue.length) return;
    final bool removedCurrent = index == _queue.currentIndex;
    final bool wasPlaying = _snapshot.playing;
    _queue.removeAt(index);
    if (_queue.isEmpty) {
      _generation++;
      _sourceLoaded = false;
      _windowTags = <String>[];
      _resolved.clear();
      await _engine.stop();
      _emit(_freshIdle());
      return;
    }
    if (removedCurrent) {
      _generation++;
      _lastPosition = Duration.zero;
      _position = Duration.zero;
      _positionController.add(Duration.zero);
      final Track now = _queue.current!;
      _emit(
        _snapshot.copyWith(
          currentTrack: now,
          currentIndex: _queue.currentIndex,
          queue: _queue.tracks,
          status: PlayerStatus.loading,
          duration: now.duration,
          playing: wasPlaying,
          clearError: true,
        ),
      );
      await _loadCurrent(autoplay: wasPlaying, userInitiated: true);
      return;
    }
    _emit(
      _snapshot.copyWith(
        queue: _queue.tracks,
        currentIndex: _queue.currentIndex,
      ),
    );
    await _syncWindowAfterMutation();
  }

  @override
  Future<void> moveInQueue(int from, int to) async {
    if (_disposed) return;
    if (from < 0 ||
        from >= _queue.length ||
        to < 0 ||
        to >= _queue.length) {
      return;
    }
    _queue.move(from, to);
    _emit(
      _snapshot.copyWith(
        queue: _queue.tracks,
        currentIndex: _queue.currentIndex,
      ),
    );
    await _syncWindowAfterMutation();
  }

  @override
  Future<void> clearQueue() async {
    if (_disposed) return;
    _generation++;
    _queue.clear();
    _pendingPlay = false;
    _sourceLoaded = false;
    _windowTags = <String>[];
    _resolved.clear();
    _lastPosition = Duration.zero;
    _position = Duration.zero;
    _positionController.add(Duration.zero);
    await _engine.stop();
    _emit(_freshIdle());
  }

  @override
  Future<void> setShuffle(bool enabled) async {
    if (_disposed) return;
    _queue.setShuffle(enabled);
    _emit(
      _snapshot.copyWith(
        queue: _queue.tracks,
        currentIndex: _queue.currentIndex,
        shuffleEnabled: enabled,
      ),
    );
    await _syncWindowAfterMutation();
  }

  @override
  Future<void> setRepeatMode(RepeatMode mode) async {
    if (_disposed) return;
    _queue.setRepeatMode(mode);
    await _engine.setLoopMode(
      mode == RepeatMode.one ? EngineLoopMode.one : EngineLoopMode.off,
    );
    _emit(_snapshot.copyWith(repeatMode: mode));
  }

  @override
  Future<void> setSpeed(double speed) async {
    if (_disposed) return;
    final double clamped = speed.clamp(0.25, 3.0);
    await _engine.setSpeed(clamped);
    _emit(_snapshot.copyWith(speed: clamped));
  }

  @override
  Future<void> setPitch(double pitch) async {
    if (_disposed) return;
    final double clamped = pitch.clamp(0.5, 2.0);
    await _engine.setPitch(clamped);
    _emit(_snapshot.copyWith(pitch: clamped));
  }

  @override
  Future<void> setSkipSilence(bool enabled) async {
    if (_disposed) return;
    await _engine.setSkipSilence(enabled);
    _emit(_snapshot.copyWith(skipSilence: enabled));
  }

  @override
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    await _engineStateSub?.cancel();
    await _positionSub?.cancel();
    await _durationSub?.cancel();
    await _bufferedSub?.cancel();
    await _indexSub?.cancel();
    await _errorSub?.cancel();
    await _noisySub?.cancel();
    await _interruptionSub?.cancel();
    await _stateController.close();
    await _positionController.close();
    await _bufferedController.close();
    await _engine.dispose();
    await _setSessionActive(false);
  }
}
