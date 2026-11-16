/// Tes widget tab Library: lagu + sortir, favorit, playlist
/// (buat/ubah/hapus/tambah lagu), riwayat, album, artis — semuanya
/// terhadap database in-memory nyata.
library;

import 'package:drift/drift.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:laras/data/database.dart';
import 'package:laras/features/onboarding/onboarding_flow.dart';
import 'package:laras/l10n/generated/app_localizations.dart';
import 'package:laras/main.dart';
import 'package:laras/player/player.dart';
import 'package:laras/resilience/honesty_sheet.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../data/test_database.dart';
import '../../player/fakes.dart';

void main() {
  late LarasDatabase db;
  late LibraryService library;
  late FakeAudioPlayerPort port;
  late PlayerService playerService;

  setUp(() {
    final (LarasDatabase newDb, LibraryService newService) =
        createTestLibrary();
    db = newDb;
    library = newService;
    port = FakeAudioPlayerPort();
    playerService = PlayerService(
      port: port,
      resolver: FakeAudioResolver(),
      solver: FakeSignatureSolver(),
    );
  });

  tearDown(() async {
    await db.close();
    await port.dispose();
  });

  void setPhoneViewport(WidgetTester tester) {
    tester.view.physicalSize = const Size(1170, 4800);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  AppLocalizations stringsOf(WidgetTester tester) {
    return AppLocalizations.of(
      tester.element(find.byType(Scaffold).first),
    )!;
  }

  Future<void> pumpLibrary(
    WidgetTester tester, {
    bool withService = true,
    bool failed = false,
  }) async {
    // Matikan urutan first-run (diuji di first_run_test.dart).
    SharedPreferences.setMockInitialValues(<String, Object>{
      kOnboardingShownKey: true,
      kHonestySheetShownKey: true,
    });
    await tester.pumpWidget(
      LarasApp(
        playerService: playerService,
        libraryService: withService ? library : null,
        libraryFailed: failed,
      ),
    );
    await tester.pumpAndSettle();
    final AppLocalizations strings = stringsOf(tester);
    await tester.tap(
      find.descendant(
        of: find.byType(BottomNavigationBar),
        matching: find.text(strings.tabLibrary),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> tapTab(WidgetTester tester, String label) async {
    // TabBar bisa di-scroll: tab ke-4+ mungkin di luar viewport 390 px,
    // jadi gulir dulu sampai terlihat baru ketuk.
    await tester.ensureVisible(find.text(label));
    await tester.pumpAndSettle();
    await tester.tap(find.text(label));
    await tester.pumpAndSettle();
  }

  testWidgets('tanpa service: empty state jujur + gerigi pengaturan', (
    WidgetTester tester,
  ) async {
    await pumpLibrary(tester, withService: false);
    final AppLocalizations strings = stringsOf(tester);
    expect(find.text(strings.libraryEmptyTitle), findsOneWidget);
    expect(find.byIcon(Icons.settings_outlined), findsOneWidget);
    // Tanpa service tidak ada tab (tidak ada data untuk ditampilkan).
    expect(find.text(strings.songs), findsNothing);
  });

  testWidgets('database gagal dibuka: pesan gagal, bukan crash', (
    WidgetTester tester,
  ) async {
    await pumpLibrary(tester, withService: false, failed: true);
    final AppLocalizations strings = stringsOf(tester);
    expect(find.text(strings.libraryFailed), findsOneWidget);
  });

  testWidgets('tab Lagu menampilkan lagu + sortir Terbaru lalu Nama', (
    WidgetTester tester,
  ) async {
    // Id urut sisipan; dalam satu detik yang sama, tiebreak id DESC
    // membuat urutan Terbaru deterministik: s3, s2, s1.
    await library.upsertSong(
      testSong('s1', title: 'Zebra'),
      addToLibrary: true,
    );
    await library.upsertSong(
      testSong('s2', title: 'Apel'),
      addToLibrary: true,
    );
    await library.upsertSong(
      testSong('s3', title: 'Mangga'),
      addToLibrary: true,
    );

    setPhoneViewport(tester);
    await pumpLibrary(tester);
    final AppLocalizations strings = stringsOf(tester);

    // Urutan default Terbaru: Mangga, Apel, Zebra.
    expect(find.text('Mangga'), findsOneWidget);
    expect(find.text('Apel'), findsOneWidget);
    expect(find.text('Zebra'), findsOneWidget);
    final double yMangga = tester.getTopLeft(find.text('Mangga')).dy;
    final double yApel = tester.getTopLeft(find.text('Apel')).dy;
    final double yZebra = tester.getTopLeft(find.text('Zebra')).dy;
    expect(yMangga, lessThan(yApel));
    expect(yApel, lessThan(yZebra));

    // Ganti sortir ke Nama: Apel, Mangga, Zebra.
    await tester.tap(find.text(strings.sortNewest));
    await tester.pumpAndSettle();
    await tester.tap(find.text(strings.sortByName));
    await tester.pumpAndSettle();
    expect(
      tester.getTopLeft(find.text('Apel')).dy,
      lessThan(tester.getTopLeft(find.text('Mangga')).dy),
    );
    expect(
      tester.getTopLeft(find.text('Mangga')).dy,
      lessThan(tester.getTopLeft(find.text('Zebra')).dy),
    );
  });

  testWidgets('tombol hati memasukkan lagu ke tab Favorit', (
    WidgetTester tester,
  ) async {
    await library.upsertSong(
      testSong('fav1', title: 'Lagu Favorit'),
      addToLibrary: true,
    );
    setPhoneViewport(tester);
    await pumpLibrary(tester);
    final AppLocalizations strings = stringsOf(tester);

    await tester.tap(find.byTooltip(strings.favoriteAdd));
    await tester.pumpAndSettle();
    expect(await library.isLiked('fav1'), isTrue);

    await tapTab(tester, strings.favorite);
    expect(find.text('Lagu Favorit'), findsOneWidget);

    // Hati kedua kalinya melepas favorit; tab Favorit jadi kosong.
    await tester.tap(find.byTooltip(strings.favoriteRemove));
    await tester.pumpAndSettle();
    expect(find.text(strings.favoritesEmptyTitle), findsOneWidget);
  });

  testWidgets('playlist: buat, tambah lagu, ubah nama, hapus', (
    WidgetTester tester,
  ) async {
    await library.upsertSong(
      testSong('p1', title: 'Lagu Playlist'),
      addToLibrary: true,
    );
    setPhoneViewport(tester);
    await pumpLibrary(tester);
    final AppLocalizations strings = stringsOf(tester);

    // Buat playlist lewat dialog.
    await tapTab(tester, strings.playlists);
    expect(find.text(strings.playlistsEmptyTitle), findsOneWidget);
    await tester.tap(find.text(strings.createPlaylist));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'Playlist Uji');
    await tester.tap(find.text(strings.save));
    await tester.pumpAndSettle();
    expect(find.text('Playlist Uji'), findsOneWidget);

    // Buka detail, tambah lagu lewat sheet pilih.
    await tester.tap(find.text('Playlist Uji'));
    await tester.pumpAndSettle();
    expect(find.text(strings.playlistEmpty), findsOneWidget);
    await tester.tap(find.text(strings.addSongs));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Lagu Playlist'));
    await tester.pump();
    await tester.tap(find.text(strings.save));
    await tester.pumpAndSettle();
    expect(find.text('Lagu Playlist'), findsOneWidget);
    expect(find.text(strings.playlistSongsCount(1)), findsOneWidget);

    // Ubah nama lewat tombol gerigi AppBar (tooltip renamePlaylist).
    await tester.tap(find.byTooltip(strings.renamePlaylist));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byType(TextField).first,
      'Playlist Baru',
    );
    await tester.tap(find.text(strings.save));
    await tester.pumpAndSettle();
    expect(find.text('Playlist Baru'), findsOneWidget);

    // Hapus playlist lewat tombol hapus AppBar + dialog konfirmasi.
    await tester.tap(find.byTooltip(strings.delete));
    await tester.pumpAndSettle();
    expect(find.text(strings.deletePlaylistTitle), findsOneWidget);
    await tester.tap(find.text(strings.delete));
    await tester.pumpAndSettle();
    expect(find.text('Playlist Baru'), findsNothing);
    expect(find.text(strings.playlistsEmptyTitle), findsOneWidget);

    // Lagunya tetap ada di Library (hapus playlist tidak hapus lagu).
    await tapTab(tester, strings.songs);
    expect(find.text('Lagu Playlist'), findsOneWidget);
  });

  testWidgets('tab Riwayat menampilkan putar + hapus riwayat', (
    WidgetTester tester,
  ) async {
    await library.upsertSong(
      testSong('h1', title: 'Lagu Riwayat'),
      addToLibrary: true,
    );
    await library.recordPlay(
      songId: 'h1',
      timestamp: DateTime.now(),
      playTimeMs: 60000,
    );
    setPhoneViewport(tester);
    await pumpLibrary(tester);
    final AppLocalizations strings = stringsOf(tester);

    await tapTab(tester, strings.history);
    expect(find.text('Lagu Riwayat'), findsOneWidget);
    expect(find.text(strings.clearHistory), findsOneWidget);

    await tester.tap(find.text(strings.clearHistory));
    await tester.pumpAndSettle();
    expect(find.text(strings.clearHistoryTitle), findsOneWidget);
    await tester.tap(find.text(strings.delete));
    await tester.pumpAndSettle();
    expect(find.text(strings.historyEmptyTitle), findsOneWidget);
  });

  testWidgets('tab Artis dan Album membuka daftar lagunya', (
    WidgetTester tester,
  ) async {
    await library.upsertSong(
      testSong('aa1', title: 'Lagu Koleksi'),
      artistNames: const <String>['Artis Uji'],
      album: const AlbumsCompanion(
        id: Value<String>('al1'),
        title: Value<String>('Album Uji'),
      ),
      addToLibrary: true,
    );
    setPhoneViewport(tester);
    await pumpLibrary(tester);
    final AppLocalizations strings = stringsOf(tester);

    await tapTab(tester, strings.artists);
    expect(find.text('Artis Uji'), findsOneWidget);
    await tester.tap(find.text('Artis Uji'));
    await tester.pumpAndSettle();
    expect(find.text('Lagu Koleksi'), findsOneWidget);
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();

    await tapTab(tester, strings.albums);
    expect(find.text('Album Uji'), findsOneWidget);
    await tester.tap(find.text('Album Uji'));
    await tester.pumpAndSettle();
    expect(find.text('Lagu Koleksi'), findsOneWidget);
  });

  testWidgets('mengetuk lagu di Library memutar lewat port', (
    WidgetTester tester,
  ) async {
    await library.upsertSong(
      testSong('play1', title: 'Lagu Putar'),
      addToLibrary: true,
    );
    setPhoneViewport(tester);
    await pumpLibrary(tester);

    await tester.tap(find.text('Lagu Putar'));
    await tester.pump();
    expect(port.setQueueCalls, hasLength(1));
    expect(port.setQueueCalls.single.$1.single.videoId, 'play1');
    expect(port.setQueueCalls.single.$3, isTrue);
  });
}
