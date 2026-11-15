import 'package:flutter_test/flutter_test.dart';
import 'package:laras/extractor/extractor.dart';

AudioFormat format(int itag, {int bitrate = 100000, bool sabr = false, bool direct = true}) {
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
  group('pickAudioFormat', () {
    test('urutan kualitas terbaik: 251 dulu', () {
      final List<AudioFormat> formats = <AudioFormat>[
        format(140, bitrate: 130000),
        format(251, bitrate: 155000),
        format(249, bitrate: 59000),
      ];
      expect(pickAudioFormat(formats)?.itag, 251);
    });

    test('tanpa 251, pakai 140', () {
      final List<AudioFormat> formats = <AudioFormat>[
        format(250, bitrate: 78000),
        format(140, bitrate: 130000),
        format(249, bitrate: 59000),
      ];
      expect(pickAudioFormat(formats)?.itag, 140);
    });

    test('urutan hemat data: 249 dulu', () {
      final List<AudioFormat> formats = <AudioFormat>[
        format(251, bitrate: 155000),
        format(140, bitrate: 130000),
        format(249, bitrate: 59000),
      ];
      expect(pickAudioFormat(formats, dataSaver: true)?.itag, 249);
    });

    test('format SABR tidak pernah dipilih', () {
      final List<AudioFormat> formats = <AudioFormat>[
        format(251, sabr: true),
        format(140),
      ];
      expect(pickAudioFormat(formats)?.itag, 140);
    });

    test('semua SABR -> null', () {
      final List<AudioFormat> formats = <AudioFormat>[
        format(251, sabr: true),
        format(140, sabr: true),
      ];
      expect(pickAudioFormat(formats), isNull);
    });

    test('format cipher (tanpa URL langsung) bisa dipilih', () {
      final List<AudioFormat> formats = <AudioFormat>[
        format(251, direct: false),
      ];
      final AudioFormat? picked = pickAudioFormat(formats);
      expect(picked?.itag, 251);
      expect(picked?.needsSolver, isTrue);
    });

    test('format tanpa URL dan tanpa cipher tidak dipilih', () {
      const AudioFormat broken = AudioFormat(
        itag: 251,
        mimeType: 'audio/webm; codecs="opus"',
        bitrate: 155000,
      );
      expect(pickAudioFormat(<AudioFormat>[broken]), isNull);
    });

    test('itag tak dikenal: bitrate tertinggi sebagai jalan terakhir', () {
      final List<AudioFormat> formats = <AudioFormat>[
        format(599, bitrate: 48000),
        format(600, bitrate: 64000),
      ];
      expect(pickAudioFormat(formats)?.itag, 600);
    });

    test('daftar kosong -> null', () {
      expect(pickAudioFormat(<AudioFormat>[]), isNull);
    });
  });

  group('konstanta urutan', () {
    test('urutan kualitas memuat 5 itag kanonis', () {
      expect(kBestQualityItagOrder, <int>[251, 140, 250, 249, 139]);
    });

    test('urutan hemat data memuat 5 itag kanonis', () {
      expect(kDataSaverItagOrder, <int>[249, 139, 250, 140, 251]);
    });
  });
}
