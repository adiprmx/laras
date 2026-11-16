/// Tes format file salinan (P8, PRD B7.2/B7.3): round-trip,
/// validasi, penolakan versi lebih baru, dan batas ukuran.
/// Tes murni (tanpa database, tanpa MethodChannel).
library;

import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:laras/data/backup_format.dart';

BackupData sampleBackup() {
  return BackupData(
    version: kCurrentBackupVersion,
    appVersion: '0.9.0',
    exportedAt: DateTime.utc(2026, 11, 17, 4, 38),
    songs: <BackupSong>[
      BackupSong(
        id: 'vid-1',
        title: 'Lagu Satu',
        artists: const <BackupArtistRef>[
          BackupArtistRef(id: 'UC-1', name: 'Artis Satu'),
        ],
        albumId: 'MPRE-1',
        durationSeconds: 180,
        liked: true,
        inLibrary: true,
        totalPlayTimeMs: 60000,
        dateAdded: DateTime.utc(2026, 11, 10),
        downloaded: true,
      ),
      const BackupSong(id: 'vid-2', title: 'Lagu Dua'),
    ],
    albums: <BackupAlbum>[
      BackupAlbum(
        id: 'MPRE-1',
        title: 'Album Satu',
        year: 2024,
      ),
    ],
    artists: const <BackupArtist>[
      BackupArtist(id: 'UC-1', name: 'Artis Satu'),
    ],
    playlists: <BackupPlaylist>[
      BackupPlaylist(
        name: 'Favoritku',
        description: 'Lagu-lagu pilihan',
        songIds: const <String>['vid-1', 'vid-2'],
        createdAt: DateTime.utc(2026, 11, 12),
      ),
    ],
    playEvents: <BackupPlayEvent>[
      BackupPlayEvent(
        songId: 'vid-1',
        timestamp: DateTime.utc(2026, 11, 16, 10),
        playTimeMs: 120000,
      ),
    ],
    searchHistory: <BackupSearchQuery>[
      BackupSearchQuery(
        query: 'noah',
        timestamp: DateTime.utc(2026, 11, 16, 9),
      ),
    ],
    queue: const <BackupQueueItem>[
      BackupQueueItem(songId: 'vid-1', source: 'library'),
      BackupQueueItem(songId: 'vid-2'),
    ],
    playbackState: const BackupPlaybackState(
      currentIndex: 1,
      positionMs: 45000,
      shuffleEnabled: true,
      repeatMode: 1,
    ),
    settings: const BackupSettings(
      dataSaver: true,
      defaultQuality: 'balanced',
      wifiOnly: true,
      cacheLimitBytes: 1073741824,
      playbackSpeed: 1.25,
      playbackPitch: 1.0,
      skipSilence: true,
      sortSongs: 'byName',
      eqEnabled: true,
      eqPreset: 2,
    ),
  );
}

void main() {
  test('round-trip: encode lalu parse mengembalikan isi yang sama', () {
    final BackupData original = sampleBackup();
    final BackupData parsed = BackupData.parseText(original.encode());
    expect(parsed.version, kCurrentBackupVersion);
    expect(parsed.appVersion, '0.9.0');
    expect(parsed.songs.length, 2);
    expect(parsed.songs[0].id, 'vid-1');
    expect(parsed.songs[0].title, 'Lagu Satu');
    expect(parsed.songs[0].artists.length, 1);
    expect(parsed.songs[0].artists[0].name, 'Artis Satu');
    expect(parsed.songs[0].albumId, 'MPRE-1');
    expect(parsed.songs[0].liked, isTrue);
    expect(parsed.songs[0].downloaded, isTrue);
    expect(parsed.songs[0].totalPlayTimeMs, 60000);
    expect(parsed.albums.length, 1);
    expect(parsed.albums[0].year, 2024);
    expect(parsed.artists.length, 1);
    expect(parsed.playlists.length, 1);
    expect(parsed.playlists[0].songIds, <String>['vid-1', 'vid-2']);
    expect(parsed.playEvents.length, 1);
    expect(parsed.playEvents[0].playTimeMs, 120000);
    expect(parsed.searchHistory.length, 1);
    expect(parsed.searchHistory[0].query, 'noah');
    expect(parsed.queue.length, 2);
    expect(parsed.queue[0].source, 'library');
    expect(parsed.playbackState!.currentIndex, 1);
    expect(parsed.playbackState!.shuffleEnabled, isTrue);
    expect(parsed.settings!.dataSaver, isTrue);
    expect(parsed.settings!.defaultQuality, 'balanced');
    expect(parsed.settings!.cacheLimitBytes, 1073741824);
    expect(parsed.settings!.playbackSpeed, 1.25);
    expect(parsed.settings!.sortSongs, 'byName');
    expect(parsed.settings!.eqPreset, 2);
    expect(parsed.downloadedSongIds, <String>['vid-1']);
    expect(parsed.favoriteCount, 1);
  });

  test('file kosong (hanya header) lolos: semua daftar kosong', () {
    final BackupData parsed = BackupData.parseText(
      '{"backupVersion":1,"appVersion":"0.9.0",'
      '"exportedAt":"2026-11-17T04:38:00.000Z"}',
    );
    expect(parsed.songs, isEmpty);
    expect(parsed.playlists, isEmpty);
    expect(parsed.settings, isNull);
  });

  test('JSON bukan objek -> notBackup', () {
    expect(
      () => BackupData.parseText('[1,2,3]'),
      throwsA(
        isA<BackupException>().having(
          (BackupException e) => e.kind,
          'kind',
          BackupErrorKind.notBackup,
        ),
      ),
    );
  });

  test('JSON rusak -> invalidJson', () {
    expect(
      () => BackupData.parseText('{bukan json'),
      throwsA(
        isA<BackupException>().having(
          (BackupException e) => e.kind,
          'kind',
          BackupErrorKind.invalidJson,
        ),
      ),
    );
  });

  test('UTF-8 tidak valid -> invalidJson', () {
    expect(
      () => BackupData.parseBytes(Uint8List.fromList(<int>[0xFF, 0xFE])),
      throwsA(
        isA<BackupException>().having(
          (BackupException e) => e.kind,
          'kind',
          BackupErrorKind.invalidJson,
        ),
      ),
    );
  });

  test('tanpa backupVersion -> notBackup', () {
    expect(
      () => BackupData.parseText('{"appVersion":"0.9.0"}'),
      throwsA(
        isA<BackupException>().having(
          (BackupException e) => e.kind,
          'kind',
          BackupErrorKind.notBackup,
        ),
      ),
    );
  });

  test('backupVersion lebih baru ditolak (B7.3)', () {
    expect(
      () => BackupData.parseText(
        '{"backupVersion":99,"appVersion":"9.9.9",'
        '"exportedAt":"2026-11-17T04:38:00.000Z"}',
      ),
      throwsA(
        isA<BackupException>().having(
          (BackupException e) => e.kind,
          'kind',
          BackupErrorKind.newerVersion,
        ),
      ),
    );
  });

  test('backupVersion 0 -> notBackup', () {
    expect(
      () => BackupData.parseText('{"backupVersion":0}'),
      throwsA(
        isA<BackupException>().having(
          (BackupException e) => e.kind,
          'kind',
          BackupErrorKind.notBackup,
        ),
      ),
    );
  });

  test('file lebih dari 10 MB ditolak sebelum parsing (B7.2)', () {
    final Uint8List big = Uint8List(kMaxBackupBytes + 1);
    expect(
      () => BackupData.parseBytes(big),
      throwsA(
        isA<BackupException>().having(
          (BackupException e) => e.kind,
          'kind',
          BackupErrorKind.tooLarge,
        ),
      ),
    );
  });

  test('id lagu duplikat -> invalidStructure', () {
    final Map<String, Object?> json = sampleBackup().toJson();
    json['songs'] = <Object?>[
      <String, Object?>{'id': 'vid-1', 'title': 'Satu'},
      <String, Object?>{'id': 'vid-1', 'title': 'Satu lagi'},
    ];
    expect(
      () => BackupData.parseText(jsonEncode(json)),
      throwsA(
        isA<BackupException>().having(
          (BackupException e) => e.kind,
          'kind',
          BackupErrorKind.invalidStructure,
        ),
      ),
    );
  });

  test('playlist merujuk lagu yang tidak ada -> invalidStructure', () {
    final Map<String, Object?> json = sampleBackup().toJson();
    json['playlists'] = <Object?>[
      <String, Object?>{
        'name': 'Rusak',
        'songIds': <String>['vid-hilang'],
      },
    ];
    expect(
      () => BackupData.parseText(jsonEncode(json)),
      throwsA(
        isA<BackupException>().having(
          (BackupException e) => e.kind,
          'kind',
          BackupErrorKind.invalidStructure,
        ),
      ),
    );
  });

  test('lagu merujuk album yang tidak ada -> invalidStructure', () {
    final Map<String, Object?> json = sampleBackup().toJson();
    json['songs'] = <Object?>[
      <String, Object?>{
        'id': 'vid-1',
        'title': 'Satu',
        'albumId': 'MPRE-hilang',
      },
    ];
    json['albums'] = <Object?>[];
    expect(
      () => BackupData.parseText(jsonEncode(json)),
      throwsA(
        isA<BackupException>().having(
          (BackupException e) => e.kind,
          'kind',
          BackupErrorKind.invalidStructure,
        ),
      ),
    );
  });

  test('antrean merujuk lagu yang tidak ada -> invalidStructure', () {
    final Map<String, Object?> json = sampleBackup().toJson();
    json['queue'] = <Object?>[
      <String, Object?>{'songId': 'vid-hilang'},
    ];
    expect(
      () => BackupData.parseText(jsonEncode(json)),
      throwsA(
        isA<BackupException>().having(
          (BackupException e) => e.kind,
          'kind',
          BackupErrorKind.invalidStructure,
        ),
      ),
    );
  });

  test('riwayat putar merujuk lagu yang tidak ada -> invalidStructure', () {
    final Map<String, Object?> json = sampleBackup().toJson();
    json['playEvents'] = <Object?>[
      <String, Object?>{
        'songId': 'vid-hilang',
        'timestamp': 1700000000000,
        'playTimeMs': 1000,
      },
    ];
    expect(
      () => BackupData.parseText(jsonEncode(json)),
      throwsA(
        isA<BackupException>().having(
          (BackupException e) => e.kind,
          'kind',
          BackupErrorKind.invalidStructure,
        ),
      ),
    );
  });

  test('antrean lebih dari 200 item -> invalidStructure', () {
    final Map<String, Object?> json = sampleBackup().toJson();
    json['queue'] = List<Map<String, Object?>>.generate(
      201,
      (int i) => <String, Object?>{'songId': 'vid-1'},
    );
    expect(
      () => BackupData.parseText(jsonEncode(json)),
      throwsA(
        isA<BackupException>().having(
          (BackupException e) => e.kind,
          'kind',
          BackupErrorKind.invalidStructure,
        ),
      ),
    );
  });

  test('pengaturan bertipe salah diabaikan, bukan menolak file', () {
    final Map<String, Object?> json = sampleBackup().toJson();
    json['settings'] = <String, Object?>{
      'dataSaver': 'bukan-bool',
      'cacheLimitBytes': 'bukan-angka',
      'playbackSpeed': 1.5,
    };
    final BackupData parsed = BackupData.parseText(jsonEncode(json));
    expect(parsed.settings!.dataSaver, isNull);
    expect(parsed.settings!.cacheLimitBytes, isNull);
    expect(parsed.settings!.playbackSpeed, 1.5);
  });

  test('nama file salinan: backup-musik-YYYYMMDD-HHmmss.json', () {
    expect(
      backupFileName(DateTime(2026, 11, 17, 4, 38, 5)),
      'backup-musik-20261117-043805.json',
    );
    expect(
      backupFileName(),
      matches(RegExp(r'^backup-musik-\d{8}-\d{6}\.json$')),
    );
  });

  test('format tanggal ringkasan memakai bulan Indonesia', () {
    expect(
      formatBackupDate(DateTime(2026, 11, 17, 4, 38)),
      '17 Nov 2026, 04.38',
    );
    expect(
      formatBackupDate(DateTime(2026, 5, 1, 0, 5)),
      '1 Mei 2026, 00.05',
    );
  });
}
