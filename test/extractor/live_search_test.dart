// Tes live P4: 1 pencarian nyata + 1 browse nyata ke YouTube Music.
// Jalankan eksplisit: flutter test --tags live
// CI tidak menjalankan tes ini (lihat ci.yml).
//
// Lolos dari VM 16 Nov 2026 (~07:00 WIB) setelah egress pulih:
// pencarian "noah" mengembalikan lagu, browse FEmusic_home
// mengembalikan rak. Bila gagal di lain waktu, cek egress dulu
// (curl google.com + POST youtubei) sebelum vonis kode gagal —
// POST youtubei sempat diblokir total dari IP egress VM ini
// (curl 52 Empty reply, 16 Nov ~06:10-06:35 WIB).
@Tags(<String>['live'])
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:laras/extractor/extractor.dart';

/// HttpClient asli (lihat live_extractor_test.dart): binding tes
/// memasang HttpClient palsu yang menjawab 400 untuk semua request.
class _RealHttpOverrides extends HttpOverrides {
  @override
  // ignore: unnecessary_overrides - lihat komentar kelas di atas.
  HttpClient createHttpClient(SecurityContext? context) =>
      super.createHttpClient(context);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  HttpOverrides.global = _RealHttpOverrides();

  group('live search/browse', () {
    test('pencarian nyata "noah" mengembalikan lagu dengan videoId', () async {
      final InnertubeClient client = InnertubeClient();
      final SearchResult result = await client.search('noah', kWebRemixClient);
      expect(result.grouped.songs, isNotEmpty);
      expect(result.grouped.songs.first.videoId, isNotEmpty);
      expect(result.grouped.songs.first.title, isNotEmpty);
    });

    test('browse nyata FEmusic_home mengembalikan rak', () async {
      final InnertubeClient client = InnertubeClient();
      final BrowsePage page = await client.browse(
        'FEmusic_home',
        kWebRemixClient,
      );
      expect(page.shelves, isNotEmpty);
      expect(page.shelves.first.items, isNotEmpty);
    });
  });
}
