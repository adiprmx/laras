// Tes live: resolve nyata 1 lagu kanari lewat InnerTube, lalu port
// memutar hasilnya di engine palsu. Jalankan eksplisit:
// flutter test --tags live. CI tidak menjalankan tes ini (lihat ci.yml).
//
// Batasan jujur: pemutaran audio BETULAN tidak bisa dites dari VM
// (tidak ada engine audio Android di `flutter test`, dan QuickJS tidak
// punya library native Linux host). Yang dibuktikan di sini adalah
// rantai resolve-then-load: StreamResolver nyata mengambil player
// response + script player nyata, solver diganti stub yang mengembalikan
// URL audio contoh publik (solver QuickJS sendiri sudah divalidasi P1
// lewat oracle Node vs pytubefix), lalu port memuat URL itu ke engine
// dan mencapai status memutar. URL contoh TIDAK PERNAH diunduh di tes
// ini: FakeEngine hanya merekam panggilan setSources.
@Tags(<String>['live'])
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:laras/extractor/extractor.dart';
import 'package:laras/player/player.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fakes.dart';

/// Mengembalikan HttpClient asli: TestWidgetsFlutterBinding memasang
/// HttpClient palsu yang menjawab 400 untuk semua request.
class _RealHttpOverrides extends HttpOverrides {
  @override
  // ignore: unnecessary_overrides - lihat komentar kelas di atas.
  HttpClient createHttpClient(SecurityContext? context) =>
      super.createHttpClient(context);
}

/// Solver stub: mengembalikan URL audio contoh publik apa pun formatnya.
/// Dipakai karena QuickJS tidak bisa jalan di host Linux tes.
class _StubSignatureSolver implements SignatureSolver {
  @override
  Future<String> solve({
    required PlayerScript script,
    required AudioFormat format,
  }) async {
    return 'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-1.mp3';
  }

  @override
  Future<void> dispose() async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  HttpOverrides.global = _RealHttpOverrides();

  group('live player', () {
    test('resolve-then-play 1 lagu kanari lewat port nyata', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final InnertubeClient innertube = InnertubeClient();
      final StreamResolver resolver = StreamResolver(
        innertube: innertube,
        solver: _StubSignatureSolver(),
        configLoader: RemoteConfigLoader(prefs: prefs),
        scriptLoader: PlayerScriptLoader(client: innertube),
      );
      final FakeEngine engine = FakeEngine();
      final JustAudioPlayerPort port = JustAudioPlayerPort(
        engine: engine,
        resolver: resolver,
      );
      try {
        await port.setQueue(
          <Track>[
            const Track(
              videoId: 'hhn-nGSuenM',
              title: 'Semua Tentang Kita',
              duration: Duration(seconds: 268),
            ),
          ],
          autoplay: true,
        );
        // Satu kali coba ulang bila gagal jaringan (egress VM flaky).
        if (port.snapshot.status == PlayerStatus.error &&
            port.snapshot.lastError?.kind == PlaybackFailureKind.network) {
          await Future<void>.delayed(const Duration(seconds: 5));
          await port.play();
        }
        // Resolve nyata berhasil: log mencatat client OK.
        expect(
          resolver.recentLog.any(
            (ResolveLogEntry e) => e.outcome.startsWith('OK'),
          ),
          isTrue,
          reason: 'StreamResolver nyata harus mencatat resolve OK',
        );
        // URL dimuat ke engine.
        expect(engine.setSourcesCalls, hasLength(1));
        expect(
          engine.setSourcesCalls.single.$1.single.uri.toString(),
          isNotEmpty,
        );
        expect(engine.playCalls, 1);
        // Engine melaporkan memutar: snapshot port ikut memutar.
        engine.emitPlaying();
        await Future<void>.delayed(const Duration(milliseconds: 50));
        expect(port.snapshot.playing, isTrue);
        expect(port.snapshot.currentTrack?.videoId, 'hhn-nGSuenM');
        expect(port.snapshot.lastResolve, isNotNull);
        expect(port.snapshot.lastResolve!.videoId, 'hhn-nGSuenM');
      } finally {
        await port.dispose();
      }
    }, timeout: const Timeout(Duration(minutes: 3)));
  });
}
