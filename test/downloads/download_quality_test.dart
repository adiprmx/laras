import 'package:flutter_test/flutter_test.dart';
import 'package:laras/downloads/downloads.dart';

void main() {
  group('DownloadQuality.itagOrder', () {
    test('Terbaik: 251 dulu, lalu 140, 250, 249, 139', () {
      expect(
        DownloadQuality.best.itagOrder,
        const <int>[251, 140, 250, 249, 139],
      );
    });

    test('Seimbang: 140 dulu, 251 jalan terakhir', () {
      expect(
        DownloadQuality.balanced.itagOrder,
        const <int>[140, 250, 249, 139, 251],
      );
    });

    test('Hemat data: 249 dulu, lalu 139', () {
      expect(
        DownloadQuality.dataSaver.itagOrder,
        const <int>[249, 139, 250, 140, 251],
      );
    });
  });

  group('DownloadQuality.estimateBytes', () {
    // Rumus PRD: bitrate x durasi / 8. Durasi uji 210 detik (3:30).
    test('Terbaik 210 dtk = 160000 x 210 / 8 = 4.200.000 byte', () {
      expect(
        DownloadQuality.best.estimateBytes(const Duration(seconds: 210)),
        4200000,
      );
    });

    test('Seimbang 210 dtk = 128000 x 210 / 8 = 3.360.000 byte', () {
      expect(
        DownloadQuality.balanced.estimateBytes(const Duration(seconds: 210)),
        3360000,
      );
    });

    test('Hemat data 210 dtk = 50000 x 210 / 8 = 1.312.500 byte', () {
      expect(
        DownloadQuality.dataSaver.estimateBytes(const Duration(seconds: 210)),
        1312500,
      );
    });

    test('durasi nol = 0 byte', () {
      expect(
        DownloadQuality.best.estimateBytes(Duration.zero),
        0,
      );
    });
  });

  group('DownloadQuality.primaryItag / fromPrimaryItag', () {
    test('itag utama tiap kualitas', () {
      expect(DownloadQuality.best.primaryItag, 251);
      expect(DownloadQuality.balanced.primaryItag, 140);
      expect(DownloadQuality.dataSaver.primaryItag, 249);
    });

    test('fromPrimaryItag membalikkan pemetaan', () {
      expect(DownloadQuality.fromPrimaryItag(251), DownloadQuality.best);
      expect(DownloadQuality.fromPrimaryItag(140), DownloadQuality.balanced);
      expect(DownloadQuality.fromPrimaryItag(249), DownloadQuality.dataSaver);
    });

    test('fromPrimaryItag itag tak dikenal = null', () {
      expect(DownloadQuality.fromPrimaryItag(999), isNull);
      expect(DownloadQuality.fromPrimaryItag(250), isNull);
    });
  });
}
