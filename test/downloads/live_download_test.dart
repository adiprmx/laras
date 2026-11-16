// Tes live: resolve + unduh nyata 1 lagu kanari (hhn-nGSuenM),
// lalu putar dari file lokal lewat port nyata + FakeEngine.
// Jalankan eksplisit: flutter test --tags live
// CI tidak menjalankan tes ini (lihat ci.yml).
@Tags(<String>['live'])
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:laras/data/database.dart';
import 'package:laras/downloads/downloads.dart';
import 'package:laras/extractor/extractor.dart';
import 'package:laras/player/player.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/test_database.dart';
import '../player/fakes.dart';

/// HttpClient asli (binding tes memasang mock HTTP yang menjawab 400).
class _RealHttpOverrides extends HttpOverrides {
  @override
  // ignore: unnecessary_overrides - lihat live_extractor_test.dart.
  HttpClient createHttpClient(SecurityContext? context) =>
      super.createHttpClient(context);
}

/// Loader config nilai bawaan (tanpa fetch remote): tes tidak
/// bergantung pada ketersediaan config GitHub Releases.
class _DefaultsConfigLoader extends RemoteConfigLoader {
  _DefaultsConfigLoader({required super.prefs});

  @override
  Future<RemotePlayerConfig> current({bool forceRefresh = false}) async =>
      RemotePlayerConfig.defaults();

  @override
  Future<RemotePlayerConfig> refresh({bool force = false}) async =>
      RemotePlayerConfig.defaults();
}

/// Sisa ruang palsu (10 GB): pra-periksa ruang tidak memblokir unduhan
/// nyata di VM (MethodChannel tidak ada di tes).
class _FakeFreeSpace implements FreeSpaceProvider {
  @override
  Future<int?> freeBytes(String path) async => 10 * 1024 * 1024 * 1024;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  HttpOverrides.global = _RealHttpOverrides();
  late SharedPreferences prefs;

  setUpAll(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    prefs = await SharedPreferences.getInstance();
  });

  group('live download', () {
    test('unduh nyata 1 lagu kanari + putar dari file', () async {
      final Directory temp = await Directory.systemTemp.createTemp(
        'laras_live_dl',
      );
      final Directory downloadsDir = Directory('${temp.path}/downloads')
        ..createSync();
      final Directory cacheDir = Directory('${temp.path}/cache')
        ..createSync();
      final DownloadPaths paths = DownloadPaths(
        downloadsDir: downloadsDir,
        cacheDir: cacheDir,
      );
      final (LarasDatabase db, LibraryService library) = createTestLibrary();
      final InnertubeClient innertube = InnertubeClient();
      final QuickJsSignatureSolver solver = QuickJsSignatureSolver();
      final DownloadService downloads = DownloadService(
        library: library,
        paths: paths,
        urlSource: ExtractorDownloadUrlSource(
          innertube: innertube,
          solver: solver,
          configLoader: _DefaultsConfigLoader(prefs: prefs),
          scriptLoader: PlayerScriptLoader(client: innertube),
        ),
        freeSpace: _FakeFreeSpace(),
        backoffFor: (_) => const Duration(seconds: 2),
      );
      downloads.start();
      try {
        const Track canary = Track(
          videoId: 'hhn-nGSuenM',
          title: 'Semua Tentang Kita',
          duration: Duration(seconds: 268),
        );
        expect(
          await downloads.enqueue(canary, quality: DownloadQuality.best),
          isTrue,
        );

        DownloadJob? job;
        // Satu kali coba ulang bila gagal jaringan (egress VM flaky).
        for (int round = 0; round < 2; round++) {
          job = await _waitForTerminal(library, 'hhn-nGSuenM');
          if (job?.status == DownloadJobStatus.completed) break;
          if (job?.status == DownloadJobStatus.failed &&
              job?.errorMessage == DownloadFailure.network &&
              round == 0) {
            await downloads.resumeJob('hhn-nGSuenM');
            continue;
          }
          break;
        }

        expect(
          job?.status,
          DownloadJobStatus.completed,
          reason: 'job gagal: ${job?.errorMessage} '
              'sesudah ${job?.attempts} percobaan',
        );
        expect(job!.quality, 251);
        final SongView? view = await library.songById('hhn-nGSuenM');
        expect(view?.song.downloadState, DownloadState.downloaded);
        final String relative = view!.song.filePath!;
        final File file = File('${downloadsDir.path}/$relative');
        expect(await file.exists(), isTrue);
        final int size = await file.length();
        expect(size, greaterThan(0));
        expect(size, view.song.fileSizeBytes);
        // Perkiraan Terbaik 268 dtk = 160000 x 268 / 8 = 5.360.000 B;
        // ukuran nyata harus dalam orde yang sama (bukan file kosong
        // atau file raksasa yang salah).
        expect(size, greaterThan(1000000));
        expect(size, lessThan(20000000));

        // Putar dari file: port nyata + FakeEngine, resolver palsu
        // yang akan meledak bila dipanggil (pagar P0).
        final FakeEngine engine = FakeEngine();
        final FakeAudioResolver resolver = FakeAudioResolver();
        resolver.scripted['hhn-nGSuenM'] = <Object>[
          const ExtractorException(ResolveFailureCause.emptyResponse),
        ];
        final JustAudioPlayerPort port = JustAudioPlayerPort(
          engine: engine,
          resolver: resolver,
          session: FakeAudioSession(),
        );
        try {
          final Track localTrack = downloads.trackFor(view);
          expect(localTrack.isLocal, isTrue);
          expect(localTrack.localPath, file.path);
          await port.setQueue(<Track>[localTrack], autoplay: true);
          await Future<void>.delayed(const Duration(milliseconds: 100));
          expect(resolver.resolveCalls, isEmpty);
          expect(engine.setSourcesCalls, hasLength(1));
          expect(
            engine.setSourcesCalls.single.$1.single.uri,
            Uri.file(file.path),
          );
          expect(engine.playCalls, 1);
        } finally {
          await port.dispose();
        }
      } finally {
        await downloads.dispose();
        await solver.dispose();
        await db.close();
        if (await temp.exists()) await temp.delete(recursive: true);
      }
    }, timeout: const Timeout(Duration(minutes: 20)));
  });
}

/// Tunggu job mencapai status akhir (selesai/gagal), maks 8 menit.
/// (Egress VM lambat/flaky: resolve + unduh ~5 MB nyata bisa makan
/// waktu beberapa menit; batas lama 4 menit terbukti terlalu pendek
/// pada 16 Nov 2026 — job masih `running` saat deadline tiba.)
Future<DownloadJob?> _waitForTerminal(
  LibraryService library,
  String songId,
) async {
  final DateTime deadline = DateTime.now().add(const Duration(minutes: 8));
  while (DateTime.now().isBefore(deadline)) {
    final DownloadJob? job = await library.downloadJobBySongId(songId);
    if (job != null &&
        (job.status == DownloadJobStatus.completed ||
            job.status == DownloadJobStatus.failed)) {
      return job;
    }
    await Future<void>.delayed(const Duration(seconds: 2));
  }
  return library.downloadJobBySongId(songId);
}
