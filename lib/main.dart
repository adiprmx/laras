import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:laras/core/theme/app_theme.dart';
import 'package:laras/features/downloads/downloads_screen.dart';
import 'package:laras/features/home/home_screen.dart';
import 'package:laras/features/library/library_screen.dart';
import 'package:laras/features/search/search_screen.dart';
import 'package:laras/features/settings/settings_screen.dart';
import 'package:laras/l10n/generated/app_localizations.dart';

void main() {
  runApp(const LarasApp());
}

/// Laras: pemutar musik Android gratis, tanpa iklan, bisa offline.
///
/// v1 hanya memakai mode gelap dan Bahasa Indonesia. Semua string UI tinggal
/// di `lib/l10n/app_id.arb`; tidak ada string yang di-hardcode di widget.
class LarasApp extends StatelessWidget {
  const LarasApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
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
  }
}

/// Shell utama: tab bawah empat tab (Beranda, Cari, Library, Unduhan) dan
/// slot mini-player di atas tab bawah.
///
/// Mini-player hanya tampil bila ada lagu. P0 belum punya player, jadi
/// slotnya kosong; P2 mengisi [_buildMiniPlayer] dengan lagu dari
/// PlayerService lewat widget `MiniPlayer` di `features/player/`.
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
    // P2: ganti baris ini dengan MiniPlayer yang diisi lagu dari
    // PlayerService. Selama belum ada lagu, slot ini tidak menampilkan
    // apa-apa dan tab bawah menempel ke tepi bawah layar.
    return const SizedBox.shrink();
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
