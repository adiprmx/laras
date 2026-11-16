/// Bootstrap player: merakit resolver, engine, port, dan handler
/// audio_service menjadi satu [PlayerService] yang dipegang app.
///
/// Bila inisialisasi audio_service gagal (mis. manifest belum lengkap),
/// app tetap jalan dengan port saja: pemutaran di dalam app bekerja,
/// hanya notifikasi media dan kontrol lock screen yang tidak ada.
/// Kegagalan itu dicatat lewat debugPrint, bukan dilempar, supaya satu
/// subsistem yang gagal tidak mematikan seluruh app.
library;

import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:laras/extractor/extractor.dart';
import 'package:laras/l10n/generated/app_localizations_id.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'audio_handler.dart';
import 'audio_player_port.dart';
import 'audio_session_port.dart';
import 'equalizer_service.dart';
import 'just_audio_player.dart';
import 'playback_prefs.dart';
import 'player_engine.dart';
import 'player_state.dart';
import 'sleep_timer.dart';

class PlayerService {
  PlayerService({
    required this.port,
    required this.resolver,
    required this.solver,
    this.handler,
    SleepTimerService? sleepTimer,
    EqualizerService? equalizerService,
    this.playbackPrefs,
  }) : sleepTimer = sleepTimer ?? SleepTimerService(port: port),
       equalizerService = equalizerService ?? EqualizerService();

  /// Rakit seluruh stack player nyata (resolver + engine + port +
  /// handler audio_service). Dipanggil sekali dari `main()`.
  static Future<PlayerService> create() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final InnertubeClient innertube = InnertubeClient();
    final QuickJsSignatureSolver solver = QuickJsSignatureSolver();
    final StreamResolver resolver = StreamResolver(
      innertube: innertube,
      solver: solver,
      configLoader: RemoteConfigLoader(prefs: prefs),
      scriptLoader: PlayerScriptLoader(client: innertube),
    );
    final AudioPlayerPort port = JustAudioPlayerPort(
      engine: JustAudioEngine(),
      resolver: resolver,
      session: RealAudioSession(),
    );
    // P7: pulihkan kecepatan/nada/lewati-hening yang tersimpan (sisa
    // P2), lalu simpan tiap kali berubah. Penyimpanan lewat langganan
    // stateStream — tanpa mengubah interface port. Langganan dipasang
    // ke field sesudah service dibuat, dibatalkan di dispose().
    final PlaybackPrefs playbackPrefs = PlaybackPrefs(prefs: prefs);
    await port.setSpeed(playbackPrefs.speed);
    await port.setPitch(playbackPrefs.pitch);
    await port.setSkipSilence(playbackPrefs.skipSilence);
    double lastSpeed = playbackPrefs.speed;
    double lastPitch = playbackPrefs.pitch;
    bool lastSkipSilence = playbackPrefs.skipSilence;
    // P7: timer tidur + equalizer. Equalizer ditempel ke session id
    // saat tersedia/berubah (session baru ada sesudah lagu dimuat).
    final SleepTimerService sleepTimer = SleepTimerService(port: port);
    final EqualizerService equalizerService = EqualizerService(prefs: prefs);
    unawaited(equalizerService.attach(port.androidAudioSessionId));
    LarasAudioHandler? handler;
    try {
      handler = await AudioService.init(
        builder: () => LarasAudioHandler(player: port),
        config: AudioServiceConfig(
          androidNotificationChannelId: 'id.my.adipmusic.laras.channel',
          androidNotificationChannelName:
              AppLocalizationsId().notificationChannelName,
          androidNotificationIcon: 'drawable/ic_notification',
          notificationColor: const Color(0xFF000000),
          // Tetap foreground saat dijeda: lanjut dari lock screen sesudah
          // jeda harus jalan tanpa pengecualian optimasi baterai
          // (Android 12+ melarang start foreground service dari latar).
          androidStopForegroundOnPause: false,
        ),
      );
    } on Object catch (e) {
      debugPrint('Laras: audio_service gagal diinisialisasi: $e');
      handler = null;
    }
    final PlayerService service = PlayerService(
      port: port,
      resolver: resolver,
      solver: solver,
      handler: handler,
      sleepTimer: sleepTimer,
      equalizerService: equalizerService,
      playbackPrefs: playbackPrefs,
    );
    service._prefsSub = port.stateStream.listen((PlayerSnapshot snap) {
      if (snap.speed == lastSpeed &&
          snap.pitch == lastPitch &&
          snap.skipSilence == lastSkipSilence) {
        return;
      }
      lastSpeed = snap.speed;
      lastPitch = snap.pitch;
      lastSkipSilence = snap.skipSilence;
      unawaited(
        playbackPrefs.saveAll(
          speed: snap.speed,
          pitch: snap.pitch,
          skipSilence: snap.skipSilence,
        ),
      );
    });
    service._eqSessionSub = port.androidAudioSessionIdStream.listen(
      equalizerService.attach,
    );
    return service;
  }

  /// Langganan internal dari [create] (simpan prefs + tempel EQ ke
  /// session id); dibatalkan di [dispose].
  StreamSubscription<PlayerSnapshot>? _prefsSub;
  StreamSubscription<int?>? _eqSessionSub;

  /// Port player (satu-satunya jalan UI ke audio).
  final AudioPlayerPort port;

  /// Resolver stream (dipakai port; log-nya dibaca layar demo).
  final AudioResolver resolver;

  /// Solver signature QuickJS (hidup selama app jalan).
  final SignatureSolver solver;

  /// Handler MediaSession, null bila audio_service gagal init.
  final LarasAudioHandler? handler;

  /// Timer tidur (P7). Dibuat default dari port bila tidak disuntik.
  final SleepTimerService sleepTimer;

  /// Equalizer Android (P7). Dibuat default bila tidak disuntik.
  final EqualizerService equalizerService;

  /// Preferensi pemutar tersimpan (P7, sisa P2). Null bila service
  /// dirakit di tes tanpa prefs.
  final PlaybackPrefs? playbackPrefs;

  /// Log resolve terakhir (tanpa URL), untuk layar demo spike.
  List<ResolveLogEntry> get resolveLog => resolver.recentLog;

  Future<void> dispose() async {
    await _prefsSub?.cancel();
    await _eqSessionSub?.cancel();
    await handler?.dispose();
    await sleepTimer.dispose();
    await equalizerService.dispose();
    await port.dispose();
    await solver.dispose();
  }
}
