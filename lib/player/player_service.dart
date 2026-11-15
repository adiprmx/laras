/// Bootstrap player: merakit resolver, engine, port, dan handler
/// audio_service menjadi satu [PlayerService] yang dipegang app.
///
/// Bila inisialisasi audio_service gagal (mis. manifest belum lengkap),
/// app tetap jalan dengan port saja: pemutaran di dalam app bekerja,
/// hanya notifikasi media dan kontrol lock screen yang tidak ada.
/// Kegagalan itu dicatat lewat debugPrint, bukan dilempar, supaya satu
/// subsistem yang gagal tidak mematikan seluruh app.
library;

import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:laras/extractor/extractor.dart';
import 'package:laras/l10n/generated/app_localizations_id.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'audio_handler.dart';
import 'audio_player_port.dart';
import 'audio_session_port.dart';
import 'just_audio_player.dart';
import 'player_engine.dart';

class PlayerService {
  PlayerService({
    required this.port,
    required this.resolver,
    required this.solver,
    this.handler,
  });

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
    return PlayerService(
      port: port,
      resolver: resolver,
      solver: solver,
      handler: handler,
    );
  }

  /// Port player (satu-satunya jalan UI ke audio).
  final AudioPlayerPort port;

  /// Resolver stream (dipakai port; log-nya dibaca layar demo).
  final AudioResolver resolver;

  /// Solver signature QuickJS (hidup selama app jalan).
  final SignatureSolver solver;

  /// Handler MediaSession, null bila audio_service gagal init.
  final LarasAudioHandler? handler;

  /// Log resolve terakhir (tanpa URL), untuk layar demo spike.
  List<ResolveLogEntry> get resolveLog => resolver.recentLog;

  Future<void> dispose() async {
    await handler?.dispose();
    await port.dispose();
    await solver.dispose();
  }
}
