import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:laras/core/theme/app_theme.dart';
import 'package:laras/features/home/home_screen.dart';
import 'package:laras/features/player/mini_player.dart';
import 'package:laras/l10n/generated/app_localizations.dart';
import 'package:laras/main.dart';
import 'package:laras/player/player.dart';

void main() {
  testWidgets('Laras renders four tabs with the dark theme', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const LarasApp());
    await tester.pumpAndSettle();

    final Finder tabBar = find.byType(BottomNavigationBar);
    final AppLocalizations strings = AppLocalizations.of(
      tester.element(find.byType(Scaffold).first),
    )!;

    // Keempat tab tampil di tab bawah.
    expect(
      find.descendant(of: tabBar, matching: find.text(strings.tabHome)),
      findsOneWidget,
    );
    expect(
      find.descendant(of: tabBar, matching: find.text(strings.tabSearch)),
      findsOneWidget,
    );
    expect(
      find.descendant(of: tabBar, matching: find.text(strings.tabLibrary)),
      findsOneWidget,
    );
    expect(
      find.descendant(of: tabBar, matching: find.text(strings.tabDownloads)),
      findsOneWidget,
    );

    // Tema gelap aktif.
    final BuildContext context = tester.element(find.byType(Scaffold).first);
    expect(Theme.of(context).brightness, Brightness.dark);

    // Mini-player tidak tampil bila belum ada lagu.
    expect(find.byKey(const Key('mini-player')), findsNothing);

    // Beranda: 5 lagu pilihan langsung terlihat, tanpa empty state
    // dan tanpa tombol perantara (K-F2-08).
    expect(find.text(strings.homeSongsTitle), findsOneWidget);
    for (final Track track in homeTracks) {
      expect(find.text(track.title), findsOneWidget);
    }
    expect(find.text(strings.homeEmptyTitle), findsNothing);

    // Tab Cari menampilkan layar "Segera hadir", bukan kontrol mati.
    await tester.tap(
      find.descendant(of: tabBar, matching: find.text(strings.tabSearch)),
    );
    await tester.pumpAndSettle();
    expect(find.text(strings.comingSoon), findsOneWidget);
    expect(find.text(strings.searchComingSoonBody), findsOneWidget);

    // Tab Unduhan menampilkan layar "Segera hadir".
    await tester.tap(
      find.descendant(of: tabBar, matching: find.text(strings.tabDownloads)),
    );
    await tester.pumpAndSettle();
    expect(find.text(strings.comingSoon), findsOneWidget);
    expect(find.text(strings.downloadsComingSoonBody), findsOneWidget);

    // Tab Library menampilkan empty state dan ikon gerigi Pengaturan.
    await tester.tap(
      find.descendant(of: tabBar, matching: find.text(strings.tabLibrary)),
    );
    await tester.pumpAndSettle();
    expect(find.text(strings.libraryEmptyTitle), findsOneWidget);
    expect(find.byIcon(Icons.settings_outlined), findsOneWidget);

    // Ikon gerigi membuka layar Pengaturan, dan kembali menutupnya.
    await tester.tap(find.byIcon(Icons.settings_outlined));
    await tester.pumpAndSettle();
    expect(find.text(strings.settingsComingSoon), findsOneWidget);
    // pageBack() mencari tombol kembali Cupertino di platform tertentu;
    // app ini Material, jadi ketuk BackButton Material secara langsung.
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(find.text(strings.libraryEmptyTitle), findsOneWidget);
  });

  testWidgets('MiniPlayer renders 64 dp tall with title and artist', (
    WidgetTester tester,
  ) async {
    bool tappedPlay = false;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const <Locale>[Locale('id')],
        home: Scaffold(
          body: MiniPlayer(
            title: 'Lagu Uji',
            artist: 'Artis Uji',
            isPlaying: false,
            onTap: () {},
            onPlayPause: () {
              tappedPlay = true;
            },
            onNext: () {},
            onPrevious: () {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Lagu Uji'), findsOneWidget);
    expect(find.text('Artis Uji'), findsOneWidget);
    final Finder miniPlayer = find.byKey(const Key('mini-player'));
    expect(tester.getSize(miniPlayer).height, 64);

    // Tanpa onToggleFavorite, tombol hati tidak tampil (tanpa tombol mati).
    expect(find.byIcon(Icons.favorite_border), findsNothing);
    expect(find.byIcon(Icons.favorite), findsNothing);

    await tester.tap(find.byIcon(Icons.play_arrow));
    expect(tappedPlay, isTrue);
  });
}
