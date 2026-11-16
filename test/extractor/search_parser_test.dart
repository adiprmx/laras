/// Tes parser search/browse dari fixture respons YouTube Music ASLI.
///
/// Fixture direkam dari respons nyata (HTML music.youtube.com +
/// respons API P1), dipangkas ke subtree yang dipakai parser — tidak
/// ada JSON yang dikarang dari nol. Nilai yang di-assert di bawah
/// adalah nilai verbatim dari rekaman itu.
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:laras/extractor/extractor.dart';

Future<Map<String, dynamic>> loadFixture(String name) async {
  final String raw = await File('test/fixtures/$name.json').readAsString();
  return jsonDecode(raw) as Map<String, dynamic>;
}

void main() {
  group('parseGroupedSearchResults (fixture search-peterpan)', () {
    late GroupedSearchResults results;

    setUpAll(() async {
      final Map<String, dynamic> json = await loadFixture('search-peterpan');
      results = parseGroupedSearchResults(json);
    });

    test('lagu: kartu + 3 item kartu + 2 lagu + 1 video', () {
      // Kartu hasil teratas menyumbang lagunya (onTap) + 3 item di
      // dalamnya; video musik dihitung sebagai lagu (bisa diputar).
      expect(results.songs.length, 7);
      final SearchSong card = results.songs.firstWhere(
        (SearchSong s) => s.videoId == 'hhn-nGSuenM',
      );
      expect(card.title, 'Semua Tentang Kita');
      expect(card.artist, 'Noah');
      final SearchSong peterpan = results.songs.firstWhere(
        (SearchSong s) => s.videoId == 'j9ITOOStWNU',
      );
      expect(peterpan.title, 'Semua Tentang Kita');
      expect(peterpan.artist, 'Peterpan');
      final SearchSong video = results.songs.firstWhere(
        (SearchSong s) => s.videoId == 'bJW9qWX1CNA',
      );
      expect(video.artist, 'Noah');
    });

    test('artis membawa channelId asli', () {
      expect(results.artists.length, 1);
      final SearchArtist artist = results.artists.single;
      expect(artist.name, 'Noah');
      expect(artist.channelId, 'UCCMnLkUAdm_NGMDTTC-nvDQ');
      expect(artist.subscribersText, contains('33.5M'));
    });

    test('album membawa browseId + artis + tahun', () {
      expect(results.albums.length, 1);
      final SearchAlbum album = results.albums.single;
      expect(album.title, 'Sebuah Nama, Sebuah Cerita');
      expect(album.browseId, 'MPREb_CjVCffe6rk9');
      expect(album.artists, contains('Peterpan'));
      expect(album.year, 2008);
    });

    test('playlist membawa browseId + keterangan', () {
      expect(results.playlists.length, 1);
      final SearchPlaylist playlist = results.playlists.single;
      expect(playlist.browseId, 'VLPLUDw6LIBdqtzMOnmH4PxbdaVZ746IzI7v');
      expect(playlist.subtitle, contains('Iin'));
    });

    test('podcast dilewati (bukan musik v1)', () {
      expect(
        results.songs.any((SearchSong s) => s.videoId == 'MPSPPLIBpZacpSLD4'),
        isFalse,
      );
      expect(
        results.playlists.any(
          (SearchPlaylist p) => p.browseId == 'MPSPPLIBpZacpSLD4',
        ),
        isFalse,
      );
    });

    test('param filter dibaca dari chip respons', () {
      expect(
        results.filterParams['songs'],
        'EgWKAQIIAWoSEAQQAxAFEAkQChAVEBAQDhAR',
      );
      expect(
        results.filterParams['albums'],
        'EgWKAQIYAWoSEAQQAxAFEAkQChAVEBAQDhAR',
      );
      expect(
        results.filterParams['artists'],
        'EgWKAQIgAWoSEAQQAxAFEAkQChAVEBAQDhAR',
      );
      expect(
        results.filterParams['playlists'],
        'EgeKAQQoADgBahIQBBADEAUQCRAKEBUQEBAOEBE%3D',
      );
      expect(
        results.filterParams['playlistsCommunity'],
        'EgeKAQQoAEABahIQBBADEAUQCRAKEBUQEBAOEBE%3D',
      );
    });
  });

  group('parseGroupedSearchResults toleransi', () {
    test('respons kosong menghasilkan hasil kosong, bukan throw', () {
      final GroupedSearchResults results = parseGroupedSearchResults(
        <String, dynamic>{},
      );
      expect(results.isEmpty, isTrue);
    });

    test('satu kelompok rusak tidak mengosongkan kelompok lain', () async {
      final Map<String, dynamic> json = await loadFixture('search-peterpan');
      // Rusak satu section (tipe salah) — parser harus tetap mengisi
      // kelompok lain.
      final Map<String, dynamic> sectionList =
          json['contents']['tabbedSearchResultsRenderer']['tabs'][0]['tabRenderer']['content']['sectionListRenderer']
              as Map<String, dynamic>;
      final List<dynamic> contents = sectionList['contents'] as List<dynamic>;
      contents.insert(0, 'bukan-map');
      contents.add(<String, dynamic>{'musicCardShelfRenderer': 'rusak'});
      final GroupedSearchResults results = parseGroupedSearchResults(json);
      expect(results.songs.length, 7);
      expect(results.artists.length, 1);
    });
  });

  group('parseBrowsePage (fixture browse)', () {
    test('beranda: 2 rak kartu playlist', () async {
      final Map<String, dynamic> json = await loadFixture('browse-home');
      final BrowsePage page = parseBrowsePage(json);
      expect(page.shelves.length, 2);
      expect(page.shelves[0].title, "Today's biggest hits");
      expect(page.shelves[0].items.length, 3);
      expect(page.shelves[0].isSongList, isFalse);
      final BrowseItem first = page.shelves[0].items.first;
      expect(first.kind, BrowseItemKind.playlist);
      expect(first.browseId, startsWith('VLRD'));
      expect(first.thumbnailUrl, isNotNull);
      expect(page.shelves[1].title, 'Trending community playlists');
      expect(page.shelves[1].items.first.browseId, startsWith('VLPL'));
    });

    test('playlist: header + lagu + continuation', () async {
      final Map<String, dynamic> json = await loadFixture('browse-playlist');
      final BrowsePage page = parseBrowsePage(json);
      expect(page.title, 'Vibe: Clean & Feel-Good');
      expect(page.subtitle, contains('Playlist'));
      expect(page.thumbnailUrl, isNotNull);
      expect(page.shelves.length, 1);
      final BrowseShelf shelf = page.shelves.single;
      expect(shelf.isSongList, isTrue);
      expect(shelf.items.length, 3);
      final BrowseItem first = shelf.items.first;
      expect(first.kind, BrowseItemKind.song);
      expect(first.videoId, isNotNull);
      expect(first.artist, isNotNull);
      expect(first.durationSeconds, isNotNull);
      expect(page.continuation, isNotNull);
      expect(page.allSongs.length, 3);
    });

    test('album: header + lagu tanpa continuation', () async {
      final Map<String, dynamic> json = await loadFixture('browse-album');
      final BrowsePage page = parseBrowsePage(json);
      expect(page.title, 'A Camp Family Christmas (feat. Egan Camp)');
      expect(page.shelves.length, 1);
      expect(page.shelves.single.isSongList, isTrue);
      expect(page.shelves.single.items.length, 3);
      expect(page.continuation, isNull);
    });

    test('artis: header + lagu teratas + album', () async {
      final Map<String, dynamic> json = await loadFixture('browse-artist');
      final BrowsePage page = parseBrowsePage(json);
      expect(page.title, 'Noah');
      expect(page.shelves.length, 2);
      expect(page.shelves[0].title, 'Top songs');
      expect(page.shelves[0].isSongList, isTrue);
      expect(page.shelves[0].items.length, 3);
      expect(page.shelves[1].title, 'Albums');
      expect(page.shelves[1].isSongList, isFalse);
      expect(page.shelves[1].items.first.kind, BrowseItemKind.album);
      expect(page.shelves[1].items.first.browseId, startsWith('MPRE'));
    });

    test('mood dan genre: 2 grid kategori', () async {
      final Map<String, dynamic> json = await loadFixture('browse-moods');
      final BrowsePage page = parseBrowsePage(json);
      expect(page.shelves.length, 2);
      expect(page.shelves[0].title, 'Moods & moments');
      expect(
        page.shelves[0].items.map((BrowseItem i) => i.title),
        contains('Chill'),
      );
      expect(page.shelves[0].items.first.kind, BrowseItemKind.category);
      expect(page.shelves[0].items.first.browseId, isNotNull);
      expect(page.shelves[0].items.first.browseParams, isNotNull);
      expect(page.shelves[1].title, 'Genres');
      expect(
        page.shelves[1].items.map((BrowseItem i) => i.title),
        contains('Blues'),
      );
    });

    test('respons kosong menghasilkan halaman kosong, bukan throw', () {
      final BrowsePage page = parseBrowsePage(<String, dynamic>{});
      expect(page.isEmpty, isTrue);
      expect(page.title, isEmpty);
    });
  });

  group('parseSearchSuggestions', () {
    test('mengambil teks saran dan membuang duplikat', () {
      final List<String> out = parseSearchSuggestions(<String, dynamic>{
        'contents': <dynamic>[
          <String, dynamic>{
            'searchSuggestionRenderer': <String, dynamic>{
              'suggestion': <String, dynamic>{
                'runs': <dynamic>[
                  <String, dynamic>{'text': 'noah'},
                ],
              },
            },
          },
          <String, dynamic>{
            'searchSuggestionRenderer': <String, dynamic>{
              'suggestion': <String, dynamic>{
                'runs': <dynamic>[
                  <String, dynamic>{'text': 'NOAH'},
                ],
              },
            },
          },
          <String, dynamic>{
            'searchSuggestionRenderer': <String, dynamic>{
              'suggestion': <String, dynamic>{
                'runs': <dynamic>[
                  <String, dynamic>{'text': 'noah semua tentang kita'},
                ],
              },
            },
          },
        ],
      });
      expect(out, <String>['noah', 'noah semua tentang kita']);
    });

    test('respons tanpa saran menghasilkan daftar kosong', () {
      expect(parseSearchSuggestions(<String, dynamic>{}), isEmpty);
    });

    test(
      'respons suggest ASLI (fixture suggest-noah) di-parse berurutan',
      () async {
        final Map<String, dynamic> json = await loadFixture('suggest-noah');
        expect(parseSearchSuggestions(json), <String>[
          'noah kahan',
          'noah graves',
          'noah kahan the great divide',
          'noah cyrus',
          'noah nine',
          'noah thorne',
        ]);
      },
    );
  });

  group('cap item parser + validasi thumbnail (R1-M3, R1-L2)', () {
    Map<String, dynamic> songItem(int i, {String? thumbnailUrl}) {
      return <String, dynamic>{
        'musicResponsiveListItemRenderer': <String, dynamic>{
          'playlistItemData': <String, dynamic>{
            'videoId': 'vid${i.toString().padLeft(8, '0')}',
          },
          'flexColumns': <dynamic>[
            <String, dynamic>{
              'musicResponsiveListItemFlexColumnRenderer':
                  <String, dynamic>{
                    'text': <String, dynamic>{'simpleText': 'Lagu $i'},
                  },
            },
            <String, dynamic>{
              'musicResponsiveListItemFlexColumnRenderer':
                  <String, dynamic>{
                    'text': <String, dynamic>{
                      'simpleText': 'Song • Artis $i',
                    },
                  },
            },
          ],
          if (thumbnailUrl != null)
            'thumbnail': <String, dynamic>{
              'musicThumbnailRenderer': <String, dynamic>{
                'thumbnail': <String, dynamic>{
                  'thumbnails': <dynamic>[
                    <String, dynamic>{
                      'url': thumbnailUrl,
                      'width': 60,
                      'height': 60,
                    },
                  ],
                },
              },
            },
        },
      };
    }

    Map<String, dynamic> searchJsonWithItems(
      List<Map<String, dynamic>> items,
    ) {
      return <String, dynamic>{
        'contents': <String, dynamic>{
          'tabbedSearchResultsRenderer': <String, dynamic>{
            'tabs': <dynamic>[
              <String, dynamic>{
                'tabRenderer': <String, dynamic>{
                  'selected': true,
                  'content': <String, dynamic>{
                    'sectionListRenderer': <String, dynamic>{
                      'contents': <dynamic>[
                        <String, dynamic>{
                          'musicShelfRenderer': <String, dynamic>{
                            'contents': items,
                          },
                        },
                      ],
                    },
                  },
                },
              },
            ],
          },
        },
      };
    }

    Map<String, dynamic> searchJsonWithSongs(int count) {
      return searchJsonWithItems(
        <Map<String, dynamic>>[for (int i = 0; i < count; i++) songItem(i)],
      );
    }

    test('150 lagu di satu rak -> paling banyak 100', () {
      final GroupedSearchResults results =
          parseGroupedSearchResults(searchJsonWithSongs(150));
      expect(results.songs.length, 100);
      // Semua videoId unik (tidak ada duplikat akibat cap).
      expect(
        results.songs.map((SearchSong s) => s.videoId).toSet().length,
        100,
      );
      // Catatan: _collectListItems memakai stack DFS sehingga urutan
      // traversal terbalik dari urutan dokumen (perilaku parser lama,
      // bukan bagian kontrak cap) — cap menyimpan 100 pertama dalam
      // urutan traversal itu (item 149..50).
      expect(results.songs.first.videoId, 'vid00000149');
      expect(results.songs.last.videoId, 'vid00000050');
    });

    test('99 lagu tetap utuh (cap tidak memotong hasil sah)', () {
      final GroupedSearchResults results =
          parseGroupedSearchResults(searchJsonWithSongs(99));
      expect(results.songs.length, 99);
    });

    test('thumbnail dari host liar -> null (UI pakai placeholder)', () {
      final GroupedSearchResults results = parseGroupedSearchResults(
        searchJsonWithItems(<Map<String, dynamic>>[
          songItem(0, thumbnailUrl: 'https://evil.example/x.jpg'),
          songItem(1, thumbnailUrl: 'https://i.ytimg.com/vi/x/hq.jpg'),
          songItem(2, thumbnailUrl: 'http://i.ytimg.com/vi/x/hq.jpg'),
        ]),
      );
      expect(results.songs.length, 3);
      expect(results.songs[0].thumbnailUrl, isNull);
      expect(
        results.songs[1].thumbnailUrl,
        'https://i.ytimg.com/vi/x/hq.jpg',
      );
      expect(results.songs[2].thumbnailUrl, isNull);
    });

    test('150 saran -> paling banyak 100', () {
      final List<String> out = parseSearchSuggestions(<String, dynamic>{
        'contents': <dynamic>[
          for (int i = 0; i < 150; i++)
            <String, dynamic>{
              'searchSuggestionRenderer': <String, dynamic>{
                'suggestion': <String, dynamic>{
                  'simpleText': 'saran $i',
                },
              },
            },
        ],
      });
      expect(out.length, 100);
      expect(out.first, 'saran 0');
      expect(out.last, 'saran 99');
    });

    test('playlist browse 150 lagu -> paling banyak 100', () {
      final Map<String, dynamic> json = <String, dynamic>{
        'contents': <String, dynamic>{
          'twoColumnBrowseResultsRenderer': <String, dynamic>{
            'secondaryContents': <String, dynamic>{
              'sectionListRenderer': <String, dynamic>{
                'contents': <dynamic>[
                  <String, dynamic>{
                    'musicPlaylistShelfRenderer': <String, dynamic>{
                      'contents': <dynamic>[
                        for (int i = 0; i < 150; i++) songItem(i),
                      ],
                    },
                  },
                ],
              },
            },
          },
        },
      };
      final BrowsePage page = parseBrowsePage(json);
      expect(page.shelves.length, 1);
      expect(page.shelves.first.items.length, 100);
    });
  });
}
