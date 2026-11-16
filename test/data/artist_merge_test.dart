/// Tes sambungan artis P3 → P4: artis pseudo-id (`local-<hash>`)
/// digabung ke channelId YTM saat data pencarian memberi channelId,
/// dan album dicatat dari metadata track.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:laras/data/database.dart';
import 'package:laras/player/track.dart';

import 'test_database.dart';

void main() {
  late LarasDatabase db;
  late LibraryService service;

  setUp(() {
    (db, service) = createTestLibrary();
  });

  tearDown(() async {
    await db.close();
  });

  test(
    'upsertSong dengan channelId memakai channelId sebagai id artis',
    () async {
      await service.upsertSong(
        testSong('vid1', title: 'Lagu Satu'),
        artistNames: <String>['Noah'],
        artistChannelIds: <String?>['UCCMnLkUAdm_NGMDTTC-nvDQ'],
        addToLibrary: true,
      );
      final List<SongView> songs = await service.songsPage();
      expect(songs.single.artistNames, <String>['Noah']);
      final List<ArtistWithCount> artists = await service.artistsPage();
      expect(artists.length, 1);
      expect(artists.single.artist.id, 'UCCMnLkUAdm_NGMDTTC-nvDQ');
      expect(artists.single.artist.name, 'Noah');
    },
  );

  test('upsertSong tanpa channelId tetap memakai id semu local-', () async {
    await service.upsertSong(
      testSong('vid1', title: 'Lagu Satu'),
      artistNames: <String>['Noah'],
      addToLibrary: true,
    );
    final List<ArtistWithCount> artists = await service.artistsPage();
    expect(artists.single.artist.id, startsWith('local-'));
  });

  test(
    'mergeArtistChannel memindahkan lagu dari id semu ke channelId',
    () async {
      await service.upsertSong(
        testSong('vid1', title: 'Lagu Satu'),
        artistNames: <String>['Noah'],
        addToLibrary: true,
      );
      await service.upsertSong(
        testSong('vid2', title: 'Lagu Dua'),
        artistNames: <String>['Noah'],
        addToLibrary: true,
      );
      final String pseudoId = localArtistIdForName('Noah');
      expect((await service.artistsPage()).single.artist.id, pseudoId);

      await service.mergeArtistChannel(
        name: 'Noah',
        channelId: 'UCCMnLkUAdm_NGMDTTC-nvDQ',
      );

      final List<ArtistWithCount> artists = await service.artistsPage();
      expect(artists.length, 1);
      expect(artists.single.artist.id, 'UCCMnLkUAdm_NGMDTTC-nvDQ');
      expect(artists.single.songCount, 2);
      // Lagu tetap bisa dicari lewat nama artis (FTS tersinkron).
      final LocalSearchResults found = await service.searchLocal('Noah');
      expect(found.songs.length, 2);
      // Baris artis semu hilang.
      final List<Artist> all = await service.artistsPage().then(
        (List<ArtistWithCount> views) =>
            views.map((ArtistWithCount v) => v.artist).toList(),
      );
      expect(all.any((Artist a) => a.id == pseudoId), isFalse);
    },
  );

  test('mergeArtistChannel tidak duplikat bila channelId sudah ada', () async {
    await service.upsertSong(
      testSong('vid1', title: 'Lagu Satu'),
      artistNames: <String>['Noah'],
      artistChannelIds: <String?>['UCCMnLkUAdm_NGMDTTC-nvDQ'],
      addToLibrary: true,
    );
    await service.upsertSong(
      testSong('vid2', title: 'Lagu Dua'),
      artistNames: <String>['Noah'],
      addToLibrary: true,
    );
    await service.mergeArtistChannel(
      name: 'Noah',
      channelId: 'UCCMnLkUAdm_NGMDTTC-nvDQ',
    );
    final List<ArtistWithCount> artists = await service.artistsPage();
    expect(artists.length, 1);
    expect(artists.single.songCount, 2);
  });

  test('mergeArtistChannel tanpa artis semu tidak berbuat apa-apa', () async {
    await service.mergeArtistChannel(
      name: 'Tidak Ada',
      channelId: 'UCtidakada',
    );
    expect(await service.artistsPage(), isEmpty);
  });

  test('album dicatat dari track yang membawa albumBrowseId', () async {
    const Track track = Track(
      videoId: 'vid1',
      title: 'Lagu Satu',
      artist: 'Noah',
      artistChannelId: 'UCCMnLkUAdm_NGMDTTC-nvDQ',
      album: 'Sebuah Nama, Sebuah Cerita',
      albumBrowseId: 'MPREb_CjVCffe6rk9',
    );
    await service.upsertSong(
      track.toSongsCompanion(),
      artistNames: track.artistNames,
      artistChannelIds: track.artistChannelIds,
      album: track.albumCompanion,
      addToLibrary: true,
    );
    final List<AlbumWithCount> albums = await service.albumsPage();
    expect(albums.length, 1);
    expect(albums.single.album.id, 'MPREb_CjVCffe6rk9');
    expect(albums.single.album.title, 'Sebuah Nama, Sebuah Cerita');
    expect(albums.single.songCount, 1);
    final List<SongView> songs = await service.songsPage();
    expect(songs.single.song.albumId, 'MPREb_CjVCffe6rk9');
  });

  test('album tanpa browseId tidak dibuatkan baris', () async {
    const Track track = Track(
      videoId: 'vid1',
      title: 'Lagu Satu',
      artist: 'Noah',
      album: 'Album Tanpa Id',
    );
    expect(track.albumCompanion, isNull);
    await service.upsertSong(
      track.toSongsCompanion(),
      artistNames: track.artistNames,
      artistChannelIds: track.artistChannelIds,
      album: track.albumCompanion,
      addToLibrary: true,
    );
    expect(await service.albumsPage(), isEmpty);
  });
}
