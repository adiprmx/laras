import 'package:flutter_test/flutter_test.dart';
import 'package:laras/extractor/extractor.dart';

void main() {
  group('isAllowedStreamUrl (R1-M1)', () {
    test('URL googlevideo subdomain diterima', () {
      expect(
        isAllowedStreamUrl(
          'https://rr1---sn-p5qs7n7e.googlevideo.com/videoplayback?itag=251',
        ),
        isTrue,
      );
      expect(
        isAllowedStreamUrl(
          'https://rr5---sn-vgqsrndl.googlevideo.com/videoplayback?expire=1',
        ),
        isTrue,
      );
      expect(
        isAllowedStreamUrl('https://googlevideo.com/videoplayback'),
        isTrue,
      );
    });

    test('host arbitrer ditolak', () {
      expect(
        isAllowedStreamUrl('https://evil.example/a.mp3'),
        isFalse,
      );
      expect(
        isAllowedStreamUrl('https://evil.example/googlevideo.com/x'),
        isFalse,
      );
    });

    test('host mirip tapi bukan subdomain ditolak', () {
      // Tanpa pemisah titik: bukan subdomain googlevideo.com.
      expect(
        isAllowedStreamUrl('https://evilgooglevideo.com/videoplayback'),
        isFalse,
      );
      // googlevideo.com sebagai subdomain penyerang.
      expect(
        isAllowedStreamUrl(
          'https://googlevideo.com.evil.example/videoplayback',
        ),
        isFalse,
      );
    });

    test('skema http ditolak', () {
      expect(
        isAllowedStreamUrl(
          'http://rr1---sn-x.googlevideo.com/videoplayback',
        ),
        isFalse,
      );
    });

    test('userinfo ditolak (pola googlevideo.com@evil.com)', () {
      expect(
        isAllowedStreamUrl('https://googlevideo.com@evil.example/x'),
        isFalse,
      );
      expect(
        isAllowedStreamUrl(
          'https://user:pass@rr1---sn-x.googlevideo.com/videoplayback',
        ),
        isFalse,
      );
    });

    test('URL rusak / kosong ditolak', () {
      expect(isAllowedStreamUrl(''), isFalse);
      expect(isAllowedStreamUrl('bukan url'), isFalse);
      expect(isAllowedStreamUrl('https://'), isFalse);
    });

    test('host huruf besar tetap diterima (normalisasi)', () {
      expect(
        isAllowedStreamUrl(
          'https://RR1---SN-X.GOOGLEVIDEO.COM/videoplayback',
        ),
        isTrue,
      );
    });
  });

  group('isAllowedThumbnailUrl (R1-L2)', () {
    test('host thumbnail YouTube/Google diterima', () {
      expect(
        isAllowedThumbnailUrl('https://i.ytimg.com/vi/hhn-nGSuenM/hqdefault.jpg'),
        isTrue,
      );
      expect(
        isAllowedThumbnailUrl('https://lh3.googleusercontent.com/abc=s176'),
        isTrue,
      );
      expect(
        isAllowedThumbnailUrl('https://yt3.ggpht.com/abc=s176'),
        isTrue,
      );
      expect(
        isAllowedThumbnailUrl('https://yt3.googleusercontent.com/abc'),
        isTrue,
      );
    });

    test('host arbitrer dan http ditolak', () {
      expect(
        isAllowedThumbnailUrl('http://evil.example/x.jpg'),
        isFalse,
      );
      expect(
        isAllowedThumbnailUrl('https://evil.example/x.jpg'),
        isFalse,
      );
      expect(
        isAllowedThumbnailUrl('https://i.ytimg.com.evil.example/x.jpg'),
        isFalse,
      );
    });
  });
}
