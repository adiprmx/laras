import 'package:flutter_test/flutter_test.dart';
import 'package:laras/downloads/downloads.dart';
import 'package:laras/extractor/extractor.dart';

AudioFormat format(
  int itag, {
  int bitrate = 100000,
  bool sabr = false,
  bool direct = true,
}) {
  return AudioFormat(
    itag: itag,
    mimeType: itag == 140 || itag == 139
        ? 'audio/mp4; codecs="mp4a.40.2"'
        : 'audio/webm; codecs="opus"',
    bitrate: bitrate,
    url: direct ? 'https://example.invalid/audio/$itag' : null,
    cipheredSignature: direct ? null : 'cipher-$itag',
    cipherParamName: direct ? null : 'sig',
    cipherUrl: direct ? null : 'https://example.invalid/cipher/$itag',
    isSabr: sabr,
  );
}

void main() {
  group('pickFormatForQuality', () {
    final List<AudioFormat> all = <AudioFormat>[
      format(140, bitrate: 130000),
      format(251, bitrate: 155000),
      format(250, bitrate: 70000),
      format(249, bitrate: 59000),
      format(139, bitrate: 48000),
    ];

    test('Terbaik memilih 251', () {
      expect(
        pickFormatForQuality(all, DownloadQuality.best)?.itag,
        251,
      );
    });

    test('Seimbang memilih 140', () {
      expect(
        pickFormatForQuality(all, DownloadQuality.balanced)?.itag,
        140,
      );
    });

    test('Hemat data memilih 249', () {
      expect(
        pickFormatForQuality(all, DownloadQuality.dataSaver)?.itag,
        249,
      );
    });

    test('Terbaik tanpa 251 jatuh ke 140', () {
      final List<AudioFormat> formats = all
          .where((AudioFormat f) => f.itag != 251)
          .toList();
      expect(
        pickFormatForQuality(formats, DownloadQuality.best)?.itag,
        140,
      );
    });

    test('Seimbang tanpa 140 jatuh ke 250', () {
      final List<AudioFormat> formats = all
          .where((AudioFormat f) => f.itag != 140)
          .toList();
      expect(
        pickFormatForQuality(formats, DownloadQuality.balanced)?.itag,
        250,
      );
    });

    test('Hemat data tanpa 249 jatuh ke 139', () {
      final List<AudioFormat> formats = all
          .where((AudioFormat f) => f.itag != 249)
          .toList();
      expect(
        pickFormatForQuality(formats, DownloadQuality.dataSaver)?.itag,
        139,
      );
    });

    test('format SABR tidak pernah dipilih', () {
      final List<AudioFormat> formats = <AudioFormat>[
        format(251, bitrate: 155000, sabr: true),
        format(139, bitrate: 48000),
      ];
      expect(
        pickFormatForQuality(formats, DownloadQuality.best)?.itag,
        139,
      );
    });

    test('hanya format SABR -> null', () {
      final List<AudioFormat> formats = <AudioFormat>[
        format(251, bitrate: 155000, sabr: true),
      ];
      expect(pickFormatForQuality(formats, DownloadQuality.best), isNull);
    });

    test('format tanpa URL dan tanpa cipher tidak bisa dipakai', () {
      const AudioFormat broken = AudioFormat(
        itag: 251,
        mimeType: 'audio/webm; codecs="opus"',
        bitrate: 155000,
      );
      expect(
        pickFormatForQuality(
          <AudioFormat>[broken],
          DownloadQuality.best,
        ),
        isNull,
      );
    });

    test('format cipher (butuh solver) bisa dipakai', () {
      final List<AudioFormat> formats = <AudioFormat>[
        format(251, bitrate: 155000, direct: false),
      ];
      expect(
        pickFormatForQuality(formats, DownloadQuality.best)?.itag,
        251,
      );
    });

    test('itag tak dikenal: jalan terakhir bitrate tertinggi', () {
      final List<AudioFormat> formats = <AudioFormat>[
        format(999, bitrate: 200000),
        format(888, bitrate: 100000),
      ];
      expect(
        pickFormatForQuality(formats, DownloadQuality.best)?.itag,
        999,
      );
    });

    test('daftar kosong -> null', () {
      expect(
        pickFormatForQuality(const <AudioFormat>[], DownloadQuality.best),
        isNull,
      );
    });
  });
}
