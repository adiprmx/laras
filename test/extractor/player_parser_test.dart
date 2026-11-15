import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:laras/extractor/extractor.dart';

Map<String, dynamic> loadFixture(String name) {
  final File file = File('test/fixtures/$name');
  return jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
}

void main() {
  group('parsePlayerResponse atas fixture respons ASLI (probe 15 Nov 2026)', () {
    test('WEB_REMIX OK: 4 format audio cipher, itag 251 + 140 ada', () {
      final ParsedPlayerResponse parsed = parsePlayerResponse(
        loadFixture('player-web-remix-ok.json'),
      );
      expect(parsed.playability, Playability.ok);
      expect(parsed.title, 'Rahasia Hati');
      expect(parsed.lengthSeconds, 251);
      final List<int> itags = parsed.audioFormats.map((f) => f.itag).toList();
      expect(itags, containsAll(<int>[140, 249, 250, 251]));
      // Semua format audio adalah cipher (tanpa URL langsung).
      for (final AudioFormat f in parsed.audioFormats) {
        expect(f.hasDirectUrl, isFalse);
        expect(f.needsSolver, isTrue);
        expect(f.isSabr, isFalse);
        expect(f.cipheredSignature, isNotEmpty);
        expect(f.cipherParamName, 'sig');
        expect(f.cipherUrl, startsWith('https://'));
      }
      final AudioFormat f251 = parsed.audioFormats.firstWhere(
        (f) => f.itag == 251,
      );
      expect(f251.mimeType, contains('opus'));
      expect(f251.bitrate, greaterThan(100000));
    });

    test('URL SABR tingkat atas BUKAN penanda SABR-only', () {
      final ParsedPlayerResponse parsed = parsePlayerResponse(
        loadFixture('player-web-remix-ok.json'),
      );
      // Respons ini membawa serverAbrStreamingUrl tingkat atas SEKALIGUS
      // format konvensional - parser tidak boleh menyimpulkan SABR-only.
      expect(parsed.hasTopLevelSabrUrl, isTrue);
      expect(parsed.isSabrOnly, isFalse);
    });

    test('ANDROID SABR-only: playability OK tapi semua format SABR', () {
      final ParsedPlayerResponse parsed = parsePlayerResponse(
        loadFixture('player-android-sabr-only.json'),
      );
      expect(parsed.playability, Playability.ok);
      expect(parsed.audioFormats, isNotEmpty);
      expect(parsed.isSabrOnly, isTrue);
      for (final AudioFormat f in parsed.audioFormats) {
        expect(f.isSabr, isTrue);
        expect(f.hasDirectUrl, isFalse);
        expect(f.needsSolver, isFalse);
      }
      // Pemilih itag tidak memilih apa pun dari daftar SABR-only.
      expect(pickAudioFormat(parsed.audioFormats), isNull);
    });

    test('ANDROID_MUSIC LOGIN_REQUIRED dengan alasan sign in', () {
      final ParsedPlayerResponse parsed = parsePlayerResponse(
        loadFixture('player-login-required.json'),
      );
      expect(parsed.playability, Playability.loginRequired);
      expect(parsed.reason, contains('sign in'));
      expect(parsed.audioFormats, isEmpty);
    });

    test('WEB_EMBEDDED ERROR video tidak tersedia', () {
      final ParsedPlayerResponse parsed = parsePlayerResponse(
        loadFixture('player-web-embedded-error.json'),
      );
      expect(parsed.playability, Playability.error);
      expect(parsed.reason, isNotNull);
      expect(parsed.audioFormats, isEmpty);
    });

    test('respons tanpa playabilityStatus -> unknown', () {
      final ParsedPlayerResponse parsed = parsePlayerResponse(
        <String, dynamic>{'streamingData': <String, dynamic>{}},
      );
      expect(parsed.playability, Playability.unknown);
    });

    test('JSON bukan objek yang diharapkan -> parseFailed', () {
      expect(
        () => parsePlayerResponse(<String, dynamic>{
          'playabilityStatus': 'bukan objek',
        }),
        throwsA(
          isA<ExtractorException>().having(
            (e) => e.cause,
            'cause',
            ResolveFailureCause.parseFailed,
          ),
        ),
      );
    });
  });

  group('parseSearchResponse', () {
    test('mengumpulkan videoId dari pohon respons', () {
      final Map<String, dynamic> json = <String, dynamic>{
        'contents': <String, dynamic>{
          'sectionListRenderer': <String, dynamic>{
            'contents': <dynamic>[
              <String, dynamic>{
                'musicShelfRenderer': <String, dynamic>{
                  'contents': <dynamic>[
                    <String, dynamic>{
                      'musicResponsiveListItemRenderer': <String, dynamic>{
                        'playlistItemData': <String, dynamic>{
                          'videoId': 'hhn-nGSuenM',
                        },
                        'flexColumns': <dynamic>[],
                      },
                    },
                    <String, dynamic>{
                      'musicResponsiveListItemRenderer': <String, dynamic>{
                        'playlistItemData': <String, dynamic>{
                          'videoId': 'qkC4waEZVt4',
                        },
                      },
                    },
                  ],
                },
              },
            ],
          },
        },
      };
      final List<SearchSong> songs = parseSearchResponse(json);
      expect(
        songs.map((s) => s.videoId),
        containsAll(<String>['hhn-nGSuenM', 'qkC4waEZVt4']),
      );
    });

    test('videoId duplikat hanya diambil sekali', () {
      final Map<String, dynamic> json = <String, dynamic>{
        'a': <String, dynamic>{'videoId': 'hhn-nGSuenM'},
        'b': <String, dynamic>{'videoId': 'hhn-nGSuenM'},
      };
      expect(parseSearchResponse(json).length, 1);
    });
  });
}
