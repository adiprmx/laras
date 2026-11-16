import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:laras/core/theme/app_theme.dart';
import 'package:laras/data/database.dart';
import 'package:laras/downloads/downloads.dart';
import 'package:laras/extractor/extractor.dart';
import 'package:laras/features/downloads/downloads_screen.dart';
import 'package:laras/features/home/home_screen.dart';
import 'package:laras/features/library/library_screen.dart';
import 'package:laras/features/lyrics/lrclib_client.dart';
import 'package:laras/features/lyrics/lyrics_scope.dart';
import 'package:laras/features/lyrics/lyrics_service.dart';
import 'package:laras/features/onboarding/onboarding_flow.dart';
import 'package:laras/features/player/mini_player.dart';
import 'package:laras/features/player/player_screen.dart';
import 'package:laras/features/search/search_scope.dart';
import 'package:laras/features/search/search_screen.dart';
import 'package:laras/features/search/search_service.dart';
import 'package:laras/features/settings/settings_screen.dart';
import 'package:laras/l10n/generated/app_localizations.dart';
import 'package:laras/player/player.dart';
import 'package:laras/resilience/resilience.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final PlayerService playerService = await PlayerService.create();
  final SharedPreferences prefs = await SharedPreferences.getInstance();
  // P6: pengaturan + layanan ketahanan. Dibuat di luar blok database
  // supaya Pengaturan dan status layanan tetap jalan walau database
  // gagal dibuka.
  final AppSettings settings = await AppSettings.create(prefs: prefs);
  final ExternalLinks externalLinks = ExternalLinks();
  final ConnectivityMonitor connectivity = ConnectivityMonitor();
  final WifiGate wifiGate = WifiGate(
    wifiOnly: () => settings.wifiOnly.value,
    isWifiConnected: connectivity.isWifi,
    wifiChanged: connectivity.wifiChanged,
  );
  // Status layanan: kanari memakai resolver yang sama dengan pemutar
  // (tidak mengganggu pemutaran — resolve kanari tidak menyentuh
  // antrean/engine), videoId dari config (jatuh ke lagu kanari bawaan).
  final RemoteConfigLoader statusConfigLoader = RemoteConfigLoader(
    prefs: prefs,
  );
  final RemotePlayerConfig statusConfig = await statusConfigLoader.current();
  final ServiceStatusService serviceStatus = ServiceStatusService(
    canary: CanaryChecker(
      resolver: playerService.resolver,
      prefs: prefs,
      videoIds: statusConfig.canaryVideoIds,
    ),
    config: statusConfigLoader,
    prefs: prefs,
  );
  // Saklar "Hemat data" berlaku langsung ke pemutar yang sudah jalan.
  final AudioPlayerPort port = playerService.port;
  if (port is JustAudioPlayerPort) {
    port.dataSaver = settings.dataSaver.value;
    settings.dataSaver.addListener(() {
      port.dataSaver = settings.dataSaver.value;
    });
  }
  // Cek kanari sekali sehari, di latar, 10 detik sesudah start (tidak
  // memblokir UI pertama dan tidak mengganggu pemutaran).
  unawaited(
    Future<void>.delayed(
      const Duration(seconds: 10),
      serviceStatus.checkIfDue,
    ),
  );
  // Database dibuka sekali di awal. Bila gagal (mis. file rusak), app
  // tetap jalan tanpa Library: layar Library menampilkan pesan jujur
  // dan tombol favorit disembunyikan — pemutaran tidak ikut mati.
  LibraryService? libraryService;
  bool libraryFailed = false;
  SearchService? searchService;
  DownloadService? downloadService;
  StreamCacheService? streamCache;
  DataWipeService? dataWipe;
  try {
    final LarasDatabase db = await openLarasDatabase();
    libraryService = LibraryService(
      db,
      sortPrefs: LibrarySortPrefs(prefs: prefs),
    );
    searchService = SearchService(
      api: InnertubeSearchApi(),
      library: libraryService,
      prefs: prefs,
    );
    // Pencatat riwayat hidup selama app: subscription-nya dipegang oleh
    // stream port, jadi variabel lokal boleh lepas sesudah start.
    final PlayHistoryRecorder recorder = PlayHistoryRecorder(
      port: playerService.port,
      library: libraryService,
    );
    recorder.start();
    // P5: layanan unduhan + cache streaming. Hanya bila database
    // berhasil dibuka; bila gagal, app tetap jalan tanpa unduhan
    // (tombol unduh disembunyikan, tab Unduhan menampilkan pesan).
    final DownloadPaths paths = await DownloadPaths.create();
    final InnertubeClient downloadInnertube = InnertubeClient();
    final ExtractorDownloadUrlSource urlSource =
        ExtractorDownloadUrlSource(
          innertube: downloadInnertube,
          solver: playerService.solver,
          configLoader: RemoteConfigLoader(prefs: prefs),
          scriptLoader: PlayerScriptLoader(client: downloadInnertube),
        );
    final StreamCacheService cache = StreamCacheService(
      library: libraryService,
      paths: paths,
      cacheLimitBytes: settings.cacheLimitBytes.value,
    );
    final DownloadService downloads = DownloadService(
      library: libraryService,
      paths: paths,
      urlSource: urlSource,
      streamCache: cache,
      defaultQuality: _qualityFromString(settings.defaultQuality.value),
    );
    streamCache = cache;
    downloadService = downloads;
    // P6: gerbang WiFi untuk unduhan + cache; saklar berlaku langsung
    // saat diubah di Pengaturan.
    downloads.wifiGate = wifiGate;
    cache.wifiGate = wifiGate;
    settings.wifiOnly.addListener(() {
      unawaited(downloads.recheckWifiGate());
    });
    // Kabel cache ke player: lagu yang diputar dari file cache
    // dicatat; bila engine gagal pada lagu dari cache, entrinya
    // dihapus supaya pemutaran ulang mengambil stream segar.
    if (port is JustAudioPlayerPort) {
      port.playbackCache = cache;
      // P6: penandaan lagu yang tidak bisa diputar (B4.7).
      port.unplayableMarker = LibraryUnplayableMarker(
        library: libraryService,
        serviceStatus: serviceStatus,
      );
    }
    // Cache tidak berebut bandwidth dengan unduhan yang diminta
    // pengguna, dan tidak pernah menghapus lagu yang sedang diputar.
    cache.isBusy = () => downloads.hasActiveJob;
    cache.protectedVideoId =
        () => playerService.port.snapshot.currentTrack?.videoId;
    downloads.onQueueIdle = cache.pumpPending;
    // P6: "Hapus semua data" (B7.3). Menutup database + menghentikan
    // unduhan sebelum menghapus file.
    dataWipe = DataWipeService(
      prefs: prefs,
      documentsDir: await getApplicationDocumentsDirectory(),
      tempDir: await getTemporaryDirectory(),
      databaseFileName: kDatabaseFileName,
      downloadsDir: paths.downloadsDir,
      cacheDir: paths.cacheDir,
      onStopDownloads: downloads.dispose,
      onCloseDatabase: db.close,
    );
    // Rekonsiliasi di latar (tidak memblokir startup): sinkronkan
    // tabel job dengan file yang benar-benar ada, lalu jalankan
    // antrean (job yang tertinggal dari sesi sebelumnya dilanjutkan).
    unawaited(
      _reconcileAndStart(downloads, cache, libraryService, paths),
    );
    // P7 (MUST #3): pulihkan antrean + posisi dari sesi sebelumnya, di
    // latar (tidak memblokir frame pertama). Penyimpanan otomatis
    // dimulai SESUDAH restore selesai, supaya snapshot awal yang kosong
    // tidak menimpa antrean tersimpan.
    final QueuePersistence queuePersistence = QueuePersistence(
      port: playerService.port,
      library: libraryService,
      downloadsDir: paths.downloadsDir.path,
    );
    unawaited(
      queuePersistence.restore().then((_) => queuePersistence.start()),
    );
  } catch (error, stackTrace) {
    debugPrint('Laras: database gagal dibuka: $error\n$stackTrace');
    libraryFailed = true;
    // Pencarian online tetap jalan tanpa library (tanpa hasil lokal dan
    // tanpa riwayat).
    searchService = SearchService(api: InnertubeSearchApi());
  }
  // P7: lirik (LRCLIB + cache database). Tanpa database, fetch-only
  // (tanpa cache) — dipakai saat database gagal dibuka.
  final LyricsService lyricsService = LyricsService(
    client: LrclibClient(),
    library: libraryService,
  );
  // P7 (MUST #13): tautan dalam dari platform (EventChannel).
  final DeepLinkService deepLinkService = DeepLinkService(
    links: const EventChannel(
      'id.my.adipmusic.laras/deep_link',
    ).receiveBroadcastStream().map((Object? e) => e.toString()),
    resolver: playerService.resolver,
    port: playerService.port,
  );
  deepLinkService.start();
  runApp(
    LarasApp(
      playerService: playerService,
      libraryService: libraryService,
      libraryFailed: libraryFailed,
      searchService: searchService,
      downloadService: downloadService,
      streamCache: streamCache,
      settings: settings,
      serviceStatus: serviceStatus,
      wifiGate: wifiGate,
      externalLinks: externalLinks,
      dataWipe: dataWipe,
      lyricsService: lyricsService,
      deepLinkService: deepLinkService,
    ),
  );
}

/// Kualitas unduhan dari string preferensi (lihat [AppSettings]).
DownloadQuality _qualityFromString(String value) {
  switch (value) {
    case kQualityBalanced:
      return DownloadQuality.balanced;
    case kQualityDataSaver:
      return DownloadQuality.dataSaver;
    case kQualityBest:
    default:
      return DownloadQuality.best;
  }
}

/// Rekonsiliasi saat start, lalu jalankan antrean unduhan.
///
/// Rekonsiliasi gagal (mis. direktori tidak bisa dibaca) tidak boleh
/// mematikan unduhan: antrean tetap dijalankan.
Future<void> _reconcileAndStart(
  DownloadService downloads,
  StreamCacheService cache,
  LibraryService library,
  DownloadPaths paths,
) async {
  try {
    downloads.lastReconcile = await reconcileDownloads(
      library: library,
      paths: paths,
      cache: cache,
    );
  } catch (error, stackTrace) {
    debugPrint('Laras: rekonsiliasi unduhan gagal: $error\n$stackTrace');
  }
  downloads.start();
}

/// Laras: pemutar musik Android gratis, tanpa iklan, bisa offline.
///
/// v1 hanya memakai mode gelap dan Bahasa Indonesia. Semua string UI tinggal
/// di `lib/l10n/app_id.arb`; tidak ada string yang di-hardcode di widget.
///
/// [playerService] dan [libraryService] boleh null bila app dipompa di
/// widget test tanpa player/database: slot mini-player lalu kosong, layar
/// Library menampilkan empty state, dan tidak ada yang crash.
class LarasApp extends StatelessWidget {
  const LarasApp({
    super.key,
    this.playerService,
    this.libraryService,
    this.libraryFailed = false,
    this.searchService,
    this.downloadService,
    this.streamCache,
    this.settings,
    this.serviceStatus,
    this.wifiGate,
    this.externalLinks,
    this.dataWipe,
    this.lyricsService,
    this.deepLinkService,
  });

  final PlayerService? playerService;
  final LibraryService? libraryService;
  final bool libraryFailed;
  final SearchService? searchService;

  /// Layanan unduhan + cache (P5), null bila database gagal dibuka
  /// atau bila app dipompa di widget test tanpa layanan unduhan.
  final DownloadService? downloadService;
  final StreamCacheService? streamCache;

  /// Layanan ketahanan (P6), null bila app dipompa di widget test
  /// tanpa scope: fitur terkait disembunyikan, bukan crash.
  final AppSettings? settings;
  final ServiceStatusService? serviceStatus;
  final WifiGate? wifiGate;
  final ExternalLinks? externalLinks;
  final DataWipeService? dataWipe;

  /// Layanan lirik (P7), null bila app dipompa di widget test tanpa
  /// service: tombol lirik disembunyikan, bukan crash.
  final LyricsService? lyricsService;

  /// Service tautan dalam (P7, MUST #13), null bila app dipompa di
  /// widget test tanpa service.
  final DeepLinkService? deepLinkService;

  @override
  Widget build(BuildContext context) {
    final PlayerService? service = playerService;
    Widget app = MaterialApp(
      onGenerateTitle: (BuildContext context) =>
          AppLocalizations.of(context)!.appTitle,
      theme: AppTheme.dark,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.dark,
      localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const <Locale>[Locale('id')],
      home: HomeShell(
        deepLinkService: deepLinkService,
        sleepTimer: service?.sleepTimer,
      ),
    );
    app = LibraryScope(
      service: libraryService,
      failed: libraryFailed,
      child: app,
    );
    app = LyricsScope(service: lyricsService, child: app);
    app = SearchScope(service: searchService, child: app);
    app = DownloadsScope(
      downloads: downloadService,
      cache: streamCache,
      child: app,
    );
    app = ResilienceScope(
      settings: settings,
      serviceStatus: serviceStatus,
      wifiGate: wifiGate,
      externalLinks: externalLinks,
      dataWipe: dataWipe,
      child: app,
    );
    if (service == null) return app;
    return PlayerScope(service: service, child: app);
  }
}

/// Shell utama: tab bawah empat tab (Beranda, Cari, Library, Unduhan) dan
/// slot mini-player di atas tab bawah.
///
/// Mini-player hanya tampil bila ada lagu di player. Ketuk mini-player
/// membuka Player layar penuh dengan transisi naik dari bawah.
class HomeShell extends StatefulWidget {
  const HomeShell({super.key, this.deepLinkService, this.sleepTimer});

  /// Service tautan dalam (P7, MUST #13). Null di widget test tanpa
  /// service: tidak ada langganan hasil tautan.
  final DeepLinkService? deepLinkService;

  /// Timer tidur (P7). Null di widget test tanpa service: tidak ada
  /// SnackBar kejadian timer.
  final SleepTimerService? sleepTimer;

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _selectedIndex = 0;

  /// Orkestrasi first-run sudah pernah dimulai (sekali per shell).
  bool _firstRunStarted = false;

  StreamSubscription<DeepLinkOutcome>? _deepLinkSub;
  StreamSubscription<SleepTimerEvent>? _sleepTimerSub;

  @override
  void initState() {
    super.initState();
    // Orkestrasi first-run (Rombak UI-2, verdict owner 17:56 WIB):
    // onboarding -> lembar kejujuran P6 -> beranda. Dijalankan sesudah
    // frame pertama supaya Navigator + localizations sudah tersedia.
    // Satu pemilik urutan: HomeScreen TIDAK auto-show apa pun.
    WidgetsBinding.instance.addPostFrameCallback((_) => _runFirstRun());
    // P7: hasil tautan dalam + kejadian timer tidur dilaporkan lewat
    // SnackBar di shell (selalu terpasang, di tab mana pun pengguna
    // berada) — bukan di layar pemutar yang bisa saja sedang tertutup.
    final DeepLinkService? deepLinks = widget.deepLinkService;
    if (deepLinks != null) {
      _deepLinkSub = deepLinks.outcomes.listen((DeepLinkOutcome outcome) {
        if (outcome == DeepLinkOutcome.failed && mounted) {
          _showSnack(AppLocalizations.of(context)!.deepLinkFailed);
        }
      });
      // Tautan yang ditangani sebelum shell terpasang (cold start):
      // hasilnya tersimpan di lastOutcome — laporkan sekali.
      if (deepLinks.lastOutcome == DeepLinkOutcome.failed) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            _showSnack(AppLocalizations.of(context)!.deepLinkFailed);
          }
        });
      }
    }
    final SleepTimerService? timer = widget.sleepTimer;
    if (timer != null) {
      _sleepTimerSub = timer.events.listen((SleepTimerEvent event) {
        if (!mounted) return;
        final AppLocalizations strings = AppLocalizations.of(context)!;
        _showSnack(
          event == SleepTimerEvent.done
              ? strings.sleepTimerDone
              : strings.sleepTimerCancelled,
        );
      });
    }
  }

  @override
  void dispose() {
    _deepLinkSub?.cancel();
    _sleepTimerSub?.cancel();
    super.dispose();
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  /// Urutan sekali-jalan untuk pengguna baru.
  ///
  /// Onboarding tampil bila flag `onboarding_shown_v1` belum true;
  /// flag ditandai sesudah alur kembali (ditutup dengan cara apa pun,
  /// termasuk tombol kembali = lewati). Lembar kejujuran lalu tampil
  /// bila flagnya belum true ([showHonestySheet] menjaga + menandai
  /// flagnya sendiri). Kegagalan satu langkah tidak menggagalkan
  /// langkah berikutnya dan tidak pernah mematikan app.
  Future<void> _runFirstRun() async {
    if (_firstRunStarted) return;
    _firstRunStarted = true;
    if (!mounted) return;
    try {
      if (!await isOnboardingShown()) {
        if (!mounted) return;
        await OnboardingFlow.show(context);
        if (!mounted) return;
        await markOnboardingShown();
      }
    } on Object catch (error, stackTrace) {
      debugPrint('Laras: onboarding first-run gagal: $error\n$stackTrace');
    }
    if (!mounted) return;
    try {
      await showHonestySheet(context);
    } on Object catch (error, stackTrace) {
      debugPrint('Laras: lembar kejujuran gagal: $error\n$stackTrace');
    }
  }

  void _openSettings() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (BuildContext context) => const SettingsScreen(),
      ),
    );
  }

  void _onTabTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  Widget _buildMiniPlayer() {
    final PlayerService? service = PlayerScope.maybeOf(context);
    if (service == null) return const SizedBox.shrink();
    final AudioPlayerPort port = service.port;
    final LibraryService? libraryService = LibraryScope.maybeOf(context);
    return StreamBuilder<PlayerSnapshot>(
      stream: port.stateStream,
      initialData: port.snapshot,
      builder: (BuildContext context, AsyncSnapshot<PlayerSnapshot> shot) {
        final PlayerSnapshot snap = shot.data ?? port.snapshot;
        final Track? track = snap.currentTrack;
        if (track == null) return const SizedBox.shrink();
        return StreamBuilder<Duration>(
          stream: port.positionStream,
          initialData: port.position,
          builder: (BuildContext context, AsyncSnapshot<Duration> posShot) {
            MiniPlayer buildMini({
              bool? isFavorite,
              VoidCallback? onToggleFavorite,
            }) {
              return MiniPlayer(
                title: track.title,
                artist: track.artist,
                artUri: track.artUri,
                isPlaying: snap.playing,
                position: posShot.data ?? port.position,
                duration: snap.duration ?? track.duration,
                isFavorite: isFavorite,
                onToggleFavorite: onToggleFavorite,
                // State error diteruskan apa adanya: mini-player
                // menampilkan pesan + tombol coba lagi (P0).
                failure: snap.status == PlayerStatus.error
                    ? snap.lastError
                    : null,
                onTap: () {
                  Navigator.of(context).push(
                    PageRouteBuilder<void>(
                      pageBuilder:
                          (
                            BuildContext context,
                            Animation<double> animation,
                            Animation<double> secondaryAnimation,
                          ) => PlayerScreen(
                            port: port,
                            sleepTimer: service.sleepTimer,
                            equalizerService: service.equalizerService,
                            lyricsService: LyricsScope.maybeOf(context),
                          ),
                      transitionsBuilder:
                          (
                            BuildContext context,
                            Animation<double> animation,
                            Animation<double> secondaryAnimation,
                            Widget child,
                          ) {
                            final CurvedAnimation curved = CurvedAnimation(
                              parent: animation,
                              curve: Curves.easeOutCubic,
                              reverseCurve: Curves.easeInCubic,
                            );
                            return SlideTransition(
                              position: Tween<Offset>(
                                begin: const Offset(0, 1),
                                end: Offset.zero,
                              ).animate(curved),
                              child: FadeTransition(
                                opacity: curved,
                                child: child,
                              ),
                            );
                          },
                    ),
                  );
                },
                onPlayPause: () {
                  if (snap.playing) {
                    port.pause();
                  } else {
                    port.play();
                  }
                },
                onPrevious: () => port.skipToPrevious(),
                onNext: () => port.skipToNext(),
              );
            }

            final LibraryService? library = libraryService;
            if (library == null) return buildMini();
            return StreamBuilder<bool>(
              stream: library.watchIsLiked(track.videoId),
              initialData: false,
              builder: (BuildContext context, AsyncSnapshot<bool> likeShot) {
                return buildMini(
                  isFavorite: likeShot.data ?? false,
                  onToggleFavorite: () async {
                    await library.upsertSong(
                      track.toSongsCompanion(),
                      artistNames: track.artistNames,
                      artistChannelIds: track.artistChannelIds,
                      album: track.albumCompanion,
                    );
                    await library.toggleLiked(track.videoId);
                  },
                );
              },
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations strings = AppLocalizations.of(context)!;
    return Scaffold(
      body: IndexedStack(
        index: _selectedIndex,
        children: <Widget>[
          const HomeScreen(),
          const SearchScreen(),
          LibraryScreen(onSettingsRequested: _openSettings),
          const DownloadsScreen(),
        ],
      ),
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          _buildMiniPlayer(),
          BottomNavigationBar(
            currentIndex: _selectedIndex,
            onTap: _onTabTapped,
            items: <BottomNavigationBarItem>[
              BottomNavigationBarItem(
                icon: const Icon(Icons.home_outlined),
                activeIcon: const Icon(Icons.home),
                label: strings.tabHome,
              ),
              BottomNavigationBarItem(
                icon: const Icon(Icons.search_outlined),
                activeIcon: const Icon(Icons.search),
                label: strings.tabSearch,
              ),
              BottomNavigationBarItem(
                icon: const Icon(Icons.library_music_outlined),
                activeIcon: const Icon(Icons.library_music),
                label: strings.tabLibrary,
              ),
              BottomNavigationBarItem(
                icon: const Icon(Icons.download_outlined),
                activeIcon: const Icon(Icons.download),
                label: strings.tabDownloads,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
