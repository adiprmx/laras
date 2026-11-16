/// Tes parser LRC (P7): format timestamp, multi-timestamp, metadata,
/// urutan, dan pencarian baris aktif.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:laras/features/lyrics/lrc_parser.dart';

void main() {
  group('parseLrc', () {
    test('baris dasar ter-parse dengan waktu yang benar', () {
      final List<LyricLine> lines = parseLrc(
        '[00:01.00]Baris satu\n[00:05.50]Baris dua\n',
      );
      expect(lines, hasLength(2));
      expect(lines[0].time, const Duration(seconds: 1));
      expect(lines[0].text, 'Baris satu');
      expect(lines[1].time, const Duration(seconds: 5, milliseconds: 500));
      expect(lines[1].text, 'Baris dua');
    });

    test('pecahan 1/2/3 digit dihitung dengan benar', () {
      final List<LyricLine> lines = parseLrc(
        '[00:01.5]Sepersepuluh\n[00:02.25]Seperseratus\n[00:03.125]Milidetik\n',
      );
      expect(lines[0].time, const Duration(seconds: 1, milliseconds: 500));
      expect(lines[1].time, const Duration(seconds: 2, milliseconds: 250));
      expect(lines[2].time, const Duration(seconds: 3, milliseconds: 125));
    });

    test('tanpa pecahan detik tetap valid', () {
      final List<LyricLine> lines = parseLrc('[01:30]Tanpa pecahan\n');
      expect(lines, hasLength(1));
      expect(lines[0].time, const Duration(minutes: 1, seconds: 30));
    });

    test('koma sebagai pemisah pecahan diterima', () {
      final List<LyricLine> lines = parseLrc('[00:01,50]Koma\n');
      expect(lines, hasLength(1));
      expect(lines[0].time, const Duration(seconds: 1, milliseconds: 500));
    });

    test('multi-timestamp menjadi beberapa entri dengan teks sama', () {
      final List<LyricLine> lines = parseLrc(
        '[00:01.00][00:05.00]Refrain\n',
      );
      expect(lines, hasLength(2));
      expect(lines[0].time, const Duration(seconds: 1));
      expect(lines[1].time, const Duration(seconds: 5));
      expect(lines[0].text, 'Refrain');
      expect(lines[1].text, 'Refrain');
    });

    test('tag metadata diabaikan', () {
      final List<LyricLine> lines = parseLrc(
        '[ti:Judul Lagu]\n[ar:Nama Artis]\n[al:Album]\n[offset:100]\n'
        '[00:01.00]Baris nyata\n',
      );
      expect(lines, hasLength(1));
      expect(lines[0].text, 'Baris nyata');
    });

    test('baris tanpa timestamp dan baris kosong diabaikan', () {
      final List<LyricLine> lines = parseLrc(
        'Teks tanpa timestamp\n\n[00:01.00]Valid\n[00:02.00]\n',
      );
      expect(lines, hasLength(1));
      expect(lines[0].text, 'Valid');
    });

    test('hasil diurutkan menaik walau input acak', () {
      final List<LyricLine> lines = parseLrc(
        '[00:05.00]Kelima\n[00:01.00]Pertama\n[00:03.00]Ketiga\n',
      );
      expect(
        lines.map((LyricLine l) => l.text).toList(),
        <String>['Pertama', 'Ketiga', 'Kelima'],
      );
    });

    test('input kosong menghasilkan daftar kosong', () {
      expect(parseLrc(''), isEmpty);
      expect(parseLrc('[ti:Hanya metadata]\n'), isEmpty);
    });

    test('spasi di sekitar teks dipangkas', () {
      final List<LyricLine> lines = parseLrc('[00:01.00]  Ber-spasi  \n');
      expect(lines[0].text, 'Ber-spasi');
    });
  });

  group('lyricLineIndexAt', () {
    final List<LyricLine> lines = parseLrc(
      '[00:01.00]Satu\n[00:05.00]Dua\n[00:10.00]Tiga\n',
    );

    test('sebelum baris pertama menghasilkan -1', () {
      expect(lyricLineIndexAt(lines, Duration.zero), -1);
      expect(
        lyricLineIndexAt(lines, const Duration(milliseconds: 999)),
        -1,
      );
    });

    test('tepat di waktu baris menghasilkan baris itu', () {
      expect(lyricLineIndexAt(lines, const Duration(seconds: 1)), 0);
      expect(lyricLineIndexAt(lines, const Duration(seconds: 5)), 1);
    });

    test('di antara dua baris menghasilkan baris sebelumnya', () {
      expect(lyricLineIndexAt(lines, const Duration(seconds: 7)), 1);
    });

    test('sesudah baris terakhir menghasilkan baris terakhir', () {
      expect(lyricLineIndexAt(lines, const Duration(minutes: 9)), 2);
    });

    test('daftar kosong menghasilkan -1', () {
      expect(lyricLineIndexAt(<LyricLine>[], Duration.zero), -1);
    });
  });
}
