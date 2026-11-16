import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:laras/extractor/extractor.dart';

/// Adapter HTTP palsu: mengembalikan body dari daftar chunk, mencatat
/// berapa chunk yang benar-benar dibaca (bukti batas streaming: baca
/// berhenti begitu batas terlampaui, bukan setelah seluruh body masuk).
class ChunkedAdapter implements HttpClientAdapter {
  ChunkedAdapter({
    required this.chunks,
    this.statusCode = 200,
    this.contentLength,
  });

  final List<List<int>> chunks;
  final int statusCode;
  final int? contentLength;

  /// Jumlah chunk yang sudah ditarik pemanggil.
  int chunksConsumed = 0;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final Stream<Uint8List> stream = Stream<Uint8List>.fromIterable(
      chunks.map(Uint8List.fromList),
    ).map((Uint8List chunk) {
      chunksConsumed++;
      return chunk;
    });
    return ResponseBody(
      stream,
      statusCode,
      headers: <String, List<String>>{
        if (contentLength != null)
          Headers.contentLengthHeader: <String>['$contentLength'],
        Headers.contentTypeHeader: <String>['application/json'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

/// Adapter sekali pakai dari string JSON utuh.
ChunkedAdapter jsonAdapter(String json) => ChunkedAdapter(
  chunks: <List<int>>[utf8.encode(json)],
  contentLength: utf8.encode(json).length,
);

Dio dioWith(ChunkedAdapter adapter) {
  final Dio dio = Dio();
  dio.httpClientAdapter = adapter;
  return dio;
}

Matcher isParseFailedError() => isA<ExtractorException>().having(
  (ExtractorException e) => e.cause,
  'cause',
  ResolveFailureCause.parseFailed,
);

void main() {
  group('InnertubeClient: TypeError parser dipetakan ke parseFailed (R1-M4)', () {
    test('search: contents bertipe string -> parseFailed, bukan TypeError',
        () async {
      final InnertubeClient client = InnertubeClient(
        dio: dioWith(jsonAdapter('{"contents": "bukan-objek"}')),
      );
      // Sebelum perbaikan: TypeError lolos ke SearchService (hanya
      // menangkap ExtractorException) lalu ke UI -> macet loading.
      await expectLater(
        client.search('noah', kWebRemixClient),
        throwsA(isParseFailedError()),
      );
    });

    test('search: responseContext bertipe string -> parseFailed', () async {
      final InnertubeClient client = InnertubeClient(
        dio: dioWith(
          jsonAdapter(
            '{"contents": {}, "responseContext": "bukan-objek"}',
          ),
        ),
      );
      await expectLater(
        client.search('noah', kWebRemixClient),
        throwsA(isParseFailedError()),
      );
    });

    test('browse: contents bertipe string -> parseFailed', () async {
      final InnertubeClient client = InnertubeClient(
        dio: dioWith(jsonAdapter('{"contents": "bukan-objek"}')),
      );
      await expectLater(
        client.browse('FEmusic_home', kWebRemixClient),
        throwsA(isParseFailedError()),
      );
    });

    test('browse: renderer dua kolom bertipe string -> parseFailed',
        () async {
      final InnertubeClient client = InnertubeClient(
        dio: dioWith(
          jsonAdapter(
            '{"contents": {"twoColumnBrowseResultsRenderer": "bukan-objek"}}',
          ),
        ),
      );
      await expectLater(
        client.browse('MPRE123', kWebRemixClient),
        throwsA(isParseFailedError()),
      );
    });

    test('suggest: searchSuggestionRenderer bertipe string -> parseFailed',
        () async {
      final InnertubeClient client = InnertubeClient(
        dio: dioWith(
          jsonAdapter(
            '{"contents": [{"searchSuggestionRenderer": "bukan-objek"}]}',
          ),
        ),
      );
      await expectLater(
        client.fetchSuggestions('no', kWebRemixClient),
        throwsA(isParseFailedError()),
      );
    });

    test('search: JSON valid tapi bukan objek -> parseFailed', () async {
      final InnertubeClient client = InnertubeClient(
        dio: dioWith(jsonAdapter('[1, 2, 3]')),
      );
      await expectLater(
        client.search('noah', kWebRemixClient),
        throwsA(isParseFailedError()),
      );
    });

    test('search: JSON tidak valid -> parseFailed', () async {
      final InnertubeClient client = InnertubeClient(
        dio: dioWith(jsonAdapter('{bukan json')),
      );
      await expectLater(
        client.search('noah', kWebRemixClient),
        throwsA(isParseFailedError()),
      );
    });

    test('search: respons valid tetap ter-parse lewat jalur stream',
        () async {
      final InnertubeClient client = InnertubeClient(
        dio: dioWith(
          jsonAdapter(
            '{"contents": {"tabbedSearchResultsRenderer": {"tabs": []}}, '
            '"responseContext": {"visitorData": "vd123"}}',
          ),
        ),
      );
      final SearchResult result = await client.search('noah', kWebRemixClient);
      expect(result.visitorData, 'vd123');
      expect(result.songs, isEmpty);
    });

    test('fetchPlayer: respons valid tetap ter-parse lewat jalur stream',
        () async {
      final InnertubeClient client = InnertubeClient(
        dio: dioWith(
          jsonAdapter(
            '{"playabilityStatus": {"status": "OK"}, '
            '"streamingData": {"adaptiveFormats": []}, '
            '"videoDetails": {"title": "Lagu", "lengthSeconds": "200"}}',
          ),
        ),
      );
      final ParsedPlayerResponse parsed = await client.fetchPlayer(
        'hhn-nGSuenM',
        kWebRemixClient,
      );
      expect(parsed.playability, Playability.ok);
      expect(parsed.title, 'Lagu');
    });
  });

  group('InnertubeClient: batas ukuran respons streaming (R1-M3)', () {
    test('_postJson menolak respons 12 MB dan berhenti membaca di 11 MB',
        () async {
      // 12 chunk @ 1 MB; batas 10 MB -> baca berhenti setelah chunk
      // ke-11 (11 MB > 10 MB), chunk ke-12 tidak pernah ditarik.
      final ChunkedAdapter adapter = ChunkedAdapter(
        chunks: List<List<int>>.generate(
          12,
          (_) => List<int>.filled(1024 * 1024, 0x20),
        ),
      );
      final InnertubeClient client = InnertubeClient(dio: dioWith(adapter));
      await expectLater(
        client.search('noah', kWebRemixClient),
        throwsA(isParseFailedError()),
      );
      expect(adapter.chunksConsumed, 11);
    });

    test('fetchText menolak body di atas maxBytes dan berhenti membaca',
        () async {
      final ChunkedAdapter adapter = ChunkedAdapter(
        chunks: List<List<int>>.generate(
          10,
          (_) => List<int>.filled(50, 0x61),
        ),
      );
      final InnertubeClient client = InnertubeClient(dio: dioWith(adapter));
      await expectLater(
        client.fetchText('https://www.youtube.com/', maxBytes: 100),
        throwsA(isParseFailedError()),
      );
      // 3 chunk @ 50 byte = 150 > 100 -> berhenti di chunk ke-3.
      expect(adapter.chunksConsumed, 3);
    });

    test('Content-Length di atas batas ditolak tanpa decode body', () async {
      // Pompa eager Dio mungkin sudah menarik chunk kecil ini sebelum
      // cek berjalan; jaminan cek ini adalah penolakan sebelum decode,
      // bukan nol byte ditarik (itu dijamin ResponseSizeCap).
      final ChunkedAdapter adapter = ChunkedAdapter(
        chunks: <List<int>>[utf8.encode('{"contents": {}}')],
        contentLength: ResponseLimits.youtubeiJsonBytes + 1,
      );
      final InnertubeClient client = InnertubeClient(dio: dioWith(adapter));
      await expectLater(
        client.search('noah', kWebRemixClient),
        throwsA(isParseFailedError()),
      );
    });

    test('fetchText: teks kecil tetap terbaca utuh', () async {
      final InnertubeClient client = InnertubeClient(
        dio: dioWith(jsonAdapter('{"jsUrl": "/s/player/x/base.js"}')),
      );
      final String text = await client.fetchText('https://www.youtube.com/');
      expect(text, contains('/s/player/x/base.js'));
    });
  });
}
