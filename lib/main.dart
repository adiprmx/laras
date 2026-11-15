import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:laras/core/theme/app_theme.dart';
import 'package:laras/features/downloads/downloads_screen.dart';
import 'package:laras/features/home/home_screen.dart';
import 'package:laras/features/library/library_screen.dart';
import 'package:laras/features/player/mini_player.dart';
import 'package:laras/features/player/player_screen.dart';
import 'package:laras/features/search/search_screen.dart';
import 'package:laras/features/settings/settings_screen.dart';
import 'package:laras/l10n/generated/app_localizations.dart';
import 'package:laras/player/player.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final PlayerService playerService = await PlayerService.create();
  runApp(LarasApp(playerService: playerService));
}

/// Laras: pemutar musik Android gratis, tanpa iklan, bisa offline.
///
/// v1 hanya memakai mode gelap dan Bahasa Indonesia. Semua string UI tinggal
/// di `lib/l10n/app_id.arb`; tidak ada string yang di-hardcode di widget.
///
/// [playerService] boleh null bila app dipompa di widget test tanpa
/// player: slot mini-player lalu kosong dan tidak ada yang crash.
class LarasApp extends StatelessWidget {
  const LarasApp({super.key, this.playerService});

  final PlayerService? playerService;

  @override
  Widget build(BuildContext context) {
    final PlayerService? service = playerService;
    final Widget app = MaterialApp(
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
    if (service == null) return app;
    return PlayerScope(service: service, child: app);
  }
}

/// Shell utama: tab bawah empat tab (Beranda, Cari, Library, Unduhan) dan
/// slot mini-player di atas tab bawah.
///
/// Mini-player hanya tampil bila ada lagu di player. Ketuk mini-player
/// membuka Player layar penuh.
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _selectedIndex = 0;

  void _goToSearch() {
    setState(() {
      _selectedIndex = 1;
    });
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
            return MiniPlayer(
              title: track.title,
              artist: track.artist,
              isPlaying: snap.playing,
              position: posShot.data ?? port.position,
              duration: snap.duration ?? track.duration,
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (BuildContext context) =>
                        PlayerScreen(port: port),
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
          HomeScreen(onSearchRequested: _goToSearch),
          const SearchScreen(),
          LibraryScreen(
            onSearchRequested: _goToSearch,
            onSettingsRequested: _openSettings,
          ),
          DownloadsScreen(onSearchRequested: _goToSearch),
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
