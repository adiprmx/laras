/// Tes widget lembar lirik (P7): semua state tampil benar (tersinkron,
/// polos, tidak ada, instrumental, offline + coba lagi) dan baris aktif
/// berubah mengikuti posisi putar.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:laras/core/theme/app_colors.dart';
import 'package:laras/features/lyrics/lrclib_client.dart';
import 'package:laras/features/lyrics/lyrics_service.dart';
import 'package:laras/features/lyrics/lyrics_sheet.dart';
import 'package:laras/player/track.dart';

import '../../player/fakes.dart';
import '../../player/widget_helpers.dart';
import 'lyrics_service_test.dart' show FakeLrclibClient;

class _Host extends StatelessWidget {
  const _Host({
    required this.track,
    required this.service,
    required this.port,
  });

  final Track track;
  final LyricsService service;
  final FakeAudioPlayerPort port;

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: () => LyricsSheet.show(
        context,
        track: track,
        service: service,
        port: port,
      ),
      child: const Text('Buka lirik'),
    );
  }
}

Future<void> _openSheet(
  WidgetTester tester, {
  required FakeLrclibClient client,
  FakeAudioPlayerPort? port,
}) async {
  final FakeAudioPlayerPort effectivePort =
      port ?? FakeAudioPlayerPort();
  final LyricsService service = LyricsService(client: client);
  await pumpLarasWidget(
    tester,
    _Host(
      track: testTrack('abc'),
      service: service,
      port: effectivePort,
    ),
  );
  await tester.tap(find.text('Buka lirik'));
  // pumpAndSettle (bukan pump(500ms)): ketukan butuh satu frame untuk
  // dikenali, jadi animasi sheet baru mulai sesudah pump pertama —
  // pump() durasi tunggal meninggalkannya di nilai 0 (sheet di bawah
  // layar, ketukan di dalamnya meleset). Lembar lirik tidak punya
  // timer periodik, jadi pumpAndSettle aman.
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('lirik tersinkron tampil + footer atribusi', (tester) async {
    final FakeLrclibClient client = FakeLrclibClient(
      result: const LrclibTrack(
        id: 1,
        plainLyrics: 'Baris satu\nBaris dua',
        syncedLyrics: '[00:01.00]Baris satu\n[00:05.00]Baris dua',
      ),
    );
    await _openSheet(tester, client: client);
    expect(find.text('Lirik'), findsOneWidget);
    expect(find.text('Baris satu'), findsOneWidget);
    expect(find.text('Baris dua'), findsOneWidget);
    expect(find.text('Lirik dari LRCLIB'), findsOneWidget);
    expect(
      find.textContaining('Layanan itu bisa melihat judul lagu'),
      findsOneWidget,
    );
  });

  testWidgets('baris aktif berubah mengikuti posisi putar', (tester) async {
    final FakeAudioPlayerPort port = FakeAudioPlayerPort();
    final FakeLrclibClient client = FakeLrclibClient(
      result: const LrclibTrack(
        id: 1,
        syncedLyrics: '[00:01.00]Baris satu\n[00:05.00]Baris dua',
      ),
    );
    await _openSheet(tester, client: client, port: port);
    // Posisi 6 detik: baris kedua aktif (putih), baris pertama redup.
    port.emitPosition(const Duration(seconds: 6));
    await tester.pump();
    await tester.pump();
    // Gaya teks dari AnimatedDefaultTextStyle TERDEKAT di atas baris
    // (find.ancestor mengembalikan semua leluhur, termasuk style
    // default aplikasi — tidak bisa pakai .single).
    TextStyle styleOf(String text) {
      final Element element = find.text(text).evaluate().single;
      TextStyle? found;
      element.visitAncestorElements((Element ancestor) {
        final Widget widget = ancestor.widget;
        if (widget is AnimatedDefaultTextStyle) {
          found = widget.style;
          return false;
        }
        return true;
      });
      return found!;
    }

    expect(styleOf('Baris dua').color, AppColors.textPrimary);
    expect(styleOf('Baris satu').color, AppColors.textSecondary);
  });

  testWidgets('lirik polos tampil sebagai teks gulir', (tester) async {
    final FakeLrclibClient client = FakeLrclibClient(
      result: const LrclibTrack(id: 1, plainLyrics: 'Hanya lirik polos'),
    );
    await _openSheet(tester, client: client);
    expect(find.text('Hanya lirik polos'), findsOneWidget);
  });

  testWidgets('tidak ditemukan menampilkan pesan jujur', (tester) async {
    final FakeLrclibClient client = FakeLrclibClient(result: null);
    await _openSheet(tester, client: client);
    expect(find.text('Lirik lagu ini belum ada.'), findsOneWidget);
  });

  testWidgets('instrumental menampilkan pesan jujur', (tester) async {
    final FakeLrclibClient client = FakeLrclibClient(
      result: const LrclibTrack(id: 1, instrumental: true),
    );
    await _openSheet(tester, client: client);
    expect(
      find.text('Lagu ini musik saja, tanpa lirik'),
      findsOneWidget,
    );
  });

  testWidgets('offline menampilkan pesan + tombol coba lagi yang berfungsi',
      (tester) async {
    final FakeLrclibClient client = FakeLrclibClient(
      error: const LrclibException(LrclibFailureKind.network),
    );
    await _openSheet(tester, client: client);
    expect(
      find.text('Lirik belum tersimpan. Sambungkan internet sekali untuk mengambilnya.'),
      findsOneWidget,
    );
    expect(find.text('Coba lagi'), findsOneWidget);
    expect(client.fetchCount, 1);
    await tester.tap(find.text('Coba lagi'));
    await tester.pump();
    await tester.pump();
    expect(client.fetchCount, 2);
  });
}
