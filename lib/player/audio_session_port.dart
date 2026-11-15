/// Jahitan sesi audio: interface kecil di atas audio_session.
///
/// Adapter memakai interface ini untuk fokus audio (panggilan masuk,
/// headset dicabut) supaya perilaku interupsi bisa dites dengan sesi palsu.
library;

import 'package:audio_session/audio_session.dart' as session;

/// Jenis interupsi audio.
enum InterruptionKind {
  /// Suara harus dijeda (panggilan masuk).
  pause,

  /// Suara harus dikecilkan sementara (navigator berbicara).
  duck,
}

/// Satu peristiwa interupsi: mulai (`begin` benar) atau selesai.
class InterruptionEvent {
  const InterruptionEvent({required this.begin, required this.kind});

  final bool begin;
  final InterruptionKind kind;
}

/// Interface sesi audio yang dibutuhkan adapter.
abstract class AudioSessionPort {
  /// Aliran interupsi (panggilan, app audio lain).
  Stream<InterruptionEvent> get interruptionStream;

  /// Aliran "headset dicabut / perangkat audio hilang" (becoming noisy).
  Stream<void> get becomingNoisyStream;

  /// Konfigurasi sesi untuk pemutar musik.
  Future<void> configureMusic();

  /// Aktifkan atau nonaktifkan sesi audio.
  Future<void> setActive(bool active);
}

/// Implementasi [AudioSessionPort] di atas audio_session.
class RealAudioSession implements AudioSessionPort {
  RealAudioSession({session.AudioSession? audioSession})
    : _sessionFuture = audioSession != null
          ? Future<session.AudioSession>.value(audioSession)
          : session.AudioSession.instance;

  final Future<session.AudioSession> _sessionFuture;

  @override
  Stream<InterruptionEvent> get interruptionStream async* {
    final session.AudioSession s = await _sessionFuture;
    yield* s.interruptionEventStream.map(
      (session.AudioInterruptionEvent e) => InterruptionEvent(
        begin: e.begin,
        // Jenis tak dikenal diperlakukan sebagai jeda: lebih aman diam
        // daripada terus memutar saat sistem meminta diam.
        kind: e.type == session.AudioInterruptionType.duck
            ? InterruptionKind.duck
            : InterruptionKind.pause,
      ),
    );
  }

  @override
  Stream<void> get becomingNoisyStream async* {
    final session.AudioSession s = await _sessionFuture;
    yield* s.becomingNoisyEventStream;
  }

  @override
  Future<void> configureMusic() async {
    final session.AudioSession s = await _sessionFuture;
    await s.configure(const session.AudioSessionConfiguration.music());
  }

  @override
  Future<void> setActive(bool active) async {
    final session.AudioSession s = await _sessionFuture;
    await s.setActive(active);
  }
}
