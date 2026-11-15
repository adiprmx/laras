/// Tes permukaan beranda (K-F2-08 + K-F2-09):
/// 5 lagu langsung terlihat dengan sampul + tombol putar, tanpa ketukan
/// tambahan; mengetuk lagu memutar lewat port; seksi library muncul bila
/// ada lagu; status tekan (skala) bekerja di tombol putar.
library;

import 'package:cached_network_image_ce/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:laras/data/database.dart';
import 'package:laras/features/home/home_screen.dart';
import 'package:laras/features/library/song_row.dart';
import 'package:laras/l10n/generated/app_localizations.dart';
import 'package:laras/main.dart';
import 'package:laras/player/player.dart';

import '../../data/test_database.dart';
import '../../player/fakes.dart';

void main() {
  late FakeAudioPlayerPort port;
  late PlayerService playerService;

  setUp(() {
    port = FakeAudioPlayerPort();
    playerService = PlayerService(
      port: port,
      resolver: FakeAudioResolver(),
      solver: FakeSignatureSolver(),
    );
  });

  tearDown(() async {
    await port.dispose();
  });

  /// Viewport HP 390x1600 supaya semua 5 lagu muat tanpa scroll.
  void setPhoneViewport(WidgetTester tester) {
    tester.view.physicalSize = const Size(1170, 4800);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  Future<void> pumpHome(
    WidgetTester tester, {
    LibraryService? libraryService,
  }) async {
    await tester.pumpWidget(
      LarasApp(playerService: playerService, libraryService: libraryService),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('beranda menampilkan 5 lagu dengan tombol putar, tanpa '
      'ketukan tambahan', (WidgetTester tester) async {
    setPhoneViewport(tester);
    await pumpHome(tester);

    final AppLocalizations strings = AppLocalizations.of(
      tester.element(find.byType(Scaffold).first),
    )!;
    expect(find.text(strings.homeSongsTitle), findsOneWidget);
    expect(find.text(strings.homeSongsHint), findsOneWidget);

    // Kelima lagu terlihat langsung (judul + durasi), tanpa empty state.
    for (final Track track in homeTracks) {
      expect(find.text(track.title), findsOneWidget);
    }
    expect(find.text(strings.homeEmptyTitle), findsNothing);
    // Tidak ada lagi tombol/jargon demo spike di permukaan.
    expect(find.textContaining('spike', findRichText: true), findsNothing);
    expect(find.textContaining('demo', findRichText: true), findsNothing);

    // 6 tombol putar bulat: 1 kepala seksi + 5 per lagu.
    expect(find.byType(RoundPlayButton), findsNWidgets(6));
  });

  testWidgets('sampul album tampil dari thumbnail videoId', (
    WidgetTester tester,
  ) async {
    setPhoneViewport(tester);
    await pumpHome(tester);

    final Finder covers = find.byType(CachedNetworkImage);
    expect(covers, findsNWidgets(5));
    final List<String> urls = tester
        .widgetList<CachedNetworkImage>(covers)
        .map((CachedNetworkImage w) => w.imageUrl)
        .toList(growable: false);
    for (final Track track in homeTracks) {
      expect(
        urls,
        contains('https://i.ytimg.com/vi/${track.videoId}/hqdefault.jpg'),
      );
    }
  });

  testWidgets('mengetuk lagu memutar antrean 5 lagu dari lagu itu', (
    WidgetTester tester,
  ) async {
    setPhoneViewport(tester);
    await pumpHome(tester);

    // Ketuk judul lagu ketiga (indeks 2).
    await tester.tap(find.text(homeTracks[2].title));
    await tester.pump();
    expect(port.setQueueCalls, hasLength(1));
    final (List<Track>, int, bool) call = port.setQueueCalls.single;
    expect(call.$1.map((Track t) => t.videoId), <String>[
      for (final Track t in homeTracks) t.videoId,
    ]);
    expect(call.$2, 2);
    expect(call.$3, isTrue); // autoplay
  });

  testWidgets('tombol putar kepala seksi memutar dari lagu pertama', (
    WidgetTester tester,
  ) async {
    setPhoneViewport(tester);
    await pumpHome(tester);

    await tester.tap(find.byType(RoundPlayButton).first);
    await tester.pump();
    expect(port.setQueueCalls, hasLength(1));
    expect(port.setQueueCalls.single.$2, 0);
    expect(port.setQueueCalls.single.$3, isTrue);
  });

  testWidgets('tombol putar mengecil saat ditekan (status tekan)', (
    WidgetTester tester,
  ) async {
    setPhoneViewport(tester);
    await pumpHome(tester);

    final Finder button = find.byType(RoundPlayButton).first;
    final Finder scale = find.descendant(
      of: button,
      matching: find.byType(AnimatedScale),
    );
    expect(tester.widget<AnimatedScale>(scale).scale, 1.0);

    final TestGesture gesture = await tester.startGesture(
      tester.getCenter(button),
    );
    await tester.pump();
    expect(tester.widget<AnimatedScale>(scale).scale, lessThan(1.0));

    await gesture.up();
    await tester.pump();
    expect(tester.widget<AnimatedScale>(scale).scale, 1.0);
  });

  testWidgets('seksi Baru Ditambahkan muncul bila library berisi lagu', (
    WidgetTester tester,
  ) async {
    final (LarasDatabase db, LibraryService library) = createTestLibrary();
    addTearDown(db.close);
    await library.upsertSong(
      testSong('lib1', title: 'Lagu Library A'),
      artistNames: const <String>['Artis A'],
      addToLibrary: true,
    );
    await library.upsertSong(
      testSong('lib2', title: 'Lagu Library B'),
      artistNames: const <String>['Artis B'],
      addToLibrary: true,
    );

    setPhoneViewport(tester);
    await pumpHome(tester, libraryService: library);

    final AppLocalizations strings = AppLocalizations.of(
      tester.element(find.byType(Scaffold).first),
    )!;
    expect(find.text(strings.homeLibraryTitle), findsOneWidget);
    expect(find.text('Lagu Library A'), findsOneWidget);
    expect(find.text('Lagu Library B'), findsOneWidget);
  });

  testWidgets('seksi library sembunyi bila library kosong', (
    WidgetTester tester,
  ) async {
    final (LarasDatabase db, LibraryService library) = createTestLibrary();
    addTearDown(db.close);

    setPhoneViewport(tester);
    await pumpHome(tester, libraryService: library);

    final AppLocalizations strings = AppLocalizations.of(
      tester.element(find.byType(Scaffold).first),
    )!;
    expect(find.text(strings.homeLibraryTitle), findsNothing);
  });
}
