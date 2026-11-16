import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:laras/core/theme/app_theme.dart';
import 'package:laras/data/database.dart';
import 'package:laras/features/downloads/downloads_screen.dart';
import 'package:laras/features/home/home_screen.dart';
import 'package:laras/features/library/library_screen.dart';
import 'package:laras/features/player/mini_player.dart';
import 'package:laras/features/player/player_screen.dart';
import 'package:laras/features/search/search_scope.dart';
import 'package:laras/features/search/search_screen.dart';
import 'package:laras/features/search/search_service.dart';
import 'package:laras/features/settings/settings_screen.dart';
import 'package:laras/l10n/generated/app_localizations.dart';
import 'package:laras/player/player.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final PlayerService playerService = await PlayerService.create();
  // Database dibuka sekali di awal. Bila gagal (mis. file rusak), app
  // tetap jalan tanpa Library: layar Library menampilkan pesan jujur
  // dan tombol favorit disembunyikan — pemutaran tidak ikut mati.
  LibraryService? libraryService;
  bool libraryFailed = false;
  SearchService? searchService;
  try {
    final LarasDatabase db = await openLarasDatabase();
    final SharedPreferences prefs = await SharedPreferences.getInstance();
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
  } catch (error, stackTrace) {
    debugPrint('Laras: database gagal dibuka: $error\n$stackTrace');
    libraryFailed = true;
    // Pencarian online tetap jalan tanpa library (tanpa hasil lokal dan
    // tanpa riwayat).
    searchService = SearchService(api: InnertubeSearchApi());
  }
  runApp(
    LarasApp(
      playerService: playerService,
      libraryService: libraryService,
      libraryFailed: libraryFailed,
      searchService: searchService,
    ),
  );
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
  });

  final PlayerService? playerService;
  final LibraryService? libraryService;
  final bool libraryFailed;
  final SearchService? searchService;

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
      home: const HomeShell(),
    );
    app = LibraryScope(
      service: libraryService,
      failed: libraryFailed,
      child: app,
    );
    app = SearchScope(service: searchService, child: app);
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
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _selectedIndex = 0;

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
                      pageBuilder: (
                        BuildContext context,
                        Animation<double> animation,
                        Animation<double> secondaryAnimation,
                      ) => PlayerScreen(port: port),
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
