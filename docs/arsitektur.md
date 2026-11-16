# Arsitektur Aplikasi Musik Gratis Tanpa Iklan + Offline

**Status:** Fase 1, riset dan dokumen saja. Belum ada kode, belum ada repo.
**Tanggal cek sumber:** 15 November 2026. Semua versi paket, tanggal rilis, dan klaim live dalam dokumen ini dicek pada tanggal itu dari pub.dev, GitHub, dan dokumentasi resmi.
**Disusun oleh:** Koordinator Fase 1 dari laporan lima tim Paket 2: A2 Mobile dan Aplikasi (library audio), A4 API dan Integrasi (ekstraksi stream), A5 Data dan Database (storage lokal), A6 Blue Team (rencana keamanan), A13 Performance dan Skalabilitas (performa dan cache).
**Dokumen acuan:** `docs/riset-kompetitor.md` (teardown InnerTune, OuterTune, Spotube, ViMusic, SimpMusic; rekomendasi lisensi GPL-3.0-only dari tim C8, belum diputuskan owner).
**Laporan tim lengkap:** `hidden_files/tim/library-audio-flutter.md` (A2), `hidden_files/tim/ekstraksi-stream.md` (A4), `hidden_files/tim/storage-lokal.md` (A5), `hidden_files/tim/rencana-keamanan.md` (A6), `hidden_files/tim/performa-cache.md` (A13). Dokumen ini adalah gabungan yang sudah diverifikasi koordinator; detail penuh ada di laporan masing-masing tim.

**Cara membaca:** angka versi dan tanggal adalah hasil cek live 15 November 2026 dan akan berubah. Setiap klaim yang belum terverifikasi dilabeli eksplisit di bagian 9, bukan ditebak. Selisih antar tim diselesaikan koordinator di bagian 7, dengan alasan yang ditulis terbuka.

## Ringkasan eksekutif

App ini adalah client Flutter untuk Android yang mengambil audio dari YouTube dan YouTube Music lewat InnerTube, memutarnya dengan Media3 ExoPlayer lewat just_audio, menyimpan library di SQLite lewat drift, dan bekerja offline lewat unduhan dan cache. Tanpa server, tanpa akun di v1, tanpa telemetri, tanpa iklan. Biaya Rp0.

| Komponen | Pilihan v1 | Versi (cek 15 Nov 2026) | Alasan singkat |
|---|---|---|---|
| Bahasa dan framework | Flutter + Dart, Android dulu | Flutter 3.47.8 / Dart 3.13.7 (menurut analisis Pana Nov 2026) | Satu codebase; pola CI yang sama dengan repo AyoQris dan Dokter HP milik owner |
| Engine audio | just_audio | 0.10.6 (MIT) | Satu-satunya engine Flutter dengan antrean, shuffle, repeat, skip silence, pitch, EQ Android, dan gapless yang terverifikasi; memakai Media3 ExoPlayer, mesin yang sama dengan kelima kompetitor native |
| Background dan MediaSession | audio_service | 0.18.19 | Foreground service, notifikasi media, lock screen, headset, Android Auto; agnostik terhadap engine |
| Fokus audio | audio_session | 0.2.4 | Interupsi panggilan, duck saat navigator berbicara, headset dicabut |
| Ekstraksi stream | InnerTube kustom di Dart (modul terpisah) + QuickJS di perangkat | quickjs_engine 0.1.7 (MIT, QuickJS-NG 0.14.0) | Tidak ada paket Dart yang siap pakai mentah-mentah; pola ini terbukti di InnerTune dan SimpMusic |
| Runtime JS untuk solver | quickjs_engine | 0.1.7 (5 Nov 2026) | Engine terbaru, satu engine di semua platform, API kompatibel flutter_js |
| Database lokal | drift (ORM di atas SQLite) | 2.35.4 (MIT), drift_dev 2.35.3 | Type-safe, relasi SQL penuh, migrasi teruji otomatis, FTS5, isolate latar; lisensi MIT terverifikasi koordinator dari metadata repo simolus3/drift |
| HTTP client | dio | 5.11.1 (MIT, 4 Sep 2026) | Timeout, interceptor retry, progress unduhan bawaan; API terverifikasi di 5.10.0 |
| Cache sampul | cached_network_image_ce | Halaman diperbarui 31 Okt 2026 (MIT) | Timeout bawaan lewat ConnectionParameters, metadata Hive CE, LRU cleanup |
| Target APK | Maks 25 MB per ABI (arm64), regang 20 MB | Target, bukan hasil ukur | InnerTune 6,5 MiB tidak bisa dicapai Flutter karena engine saja 4-8 MB per ABI |
| Android minimum | API 26 (Android 8.0) | Keputusan koordinator, bagian 7 | Selaras SimpMusic dan OuterTune 0.11.1; notification channels native; API 24 tetap fallback yang sah |

**Tujuh keputusan arsitektur utama:**

1. **Player dibungkus interface milik app.** Semua akses audio lewat `AudioPlayerPort` (atau nama sejenis) milik aplikasi, bukan memanggil just_audio langsung dari widget. Ini mitigasi utama atas tiga risiko stack audio: satu maintainer untuk tiga paket, just_audio tertinggal di media3 1.4.1, dan audio_service di atas androidx.media yang sudah deprecated.
2. **Extractor adalah modul terpisah di dalam repo.** InnerTube kustom di Dart, dengan parser player/search/browse, solver signature dan n challenge di QuickJS, orkestrator fallback antar client, dan tabel config remote. Modul terpisah membuat perbaikan extractor cepat dan tidak menyentuh UI, mengikuti InnerTune dan Spotube.
3. **Kerusakan YouTube dianggap kejadian rutin, bukan pengecualian.** Fallback antar lima client, deteksi kerusakan lokal lewat video kanari, dan tabel player config remote di GitHub Releases (refresh 6 jam) agar perbaikan bisa sampai ke pengguna tanpa rilis app.
4. **Cache streaming dan unduhan dipisah total.** Cache streaming LRU default 500 MB di direktori temporer, bisa dihapus otomatis; unduhan permanen tidak pernah dihapus otomatis. Pola InnerTune.
5. **Semua koleksi di SQLite, tidak pernah di key-value store.** Pelajaran OOM Spotube (issue #3193): DataStore JSON yang menyimpan cover full-size sampai ratusan MB dan crash. shared_preferences hanya nilai primitif kecil (batas keras 1 KB per nilai, 100 KB total).
6. **Tanpa login di v1, tanpa kredensial di perangkat.** Login YouTube Music ditunda; tanpa login, tidak ada cookie sesi akun Google di perangkat sama sekali. Spesifikasi penyimpanan login tetap ditulis lengkap untuk rilis berikutnya.
7. **Keamanan diuji berulang, bukan sekali.** Siklus Red, Blue, Red memakai OWASP MASVS v2.1.0 dan MASTG v2.0.0, terikat milestone, berhenti di nol temuan kritis/tinggi/sedang, maks 5 ronde.

## 1. Gambaran arsitektur

```
+------------------------------------------------------------------+
|  UI (Flutter widgets)                                            |
|  Beranda, Pencarian, Player, Library, Playlist, Pengaturan       |
|  State management di lapisan ini; tidak ada akses langsung ke    |
|  just_audio, drift, atau HTTP dari widget.                       |
+------------------------------------------------------------------+
        |                    |                    |
+-------v------+   +---------v--------+   +-------v--------+
| PlayerService|   | LibraryService   |   | SearchService  |
| (AudioPlayer-|   | (playlist,       |   | (pencarian     |
|  Port)       |   |  favorit,        |   |  lokal FTS5 +  |
|              |   |  riwayat)        |   |  pencarian YTM)|
+-------+------+   +---------+--------+   +-------+--------+
        |                    |                    |
+-------v------+   +---------v--------+   +-------v--------+
| just_audio   |   | drift (SQLite)   |   | InnerTube      |
| + audio_     |   | 15 tabel, FTS5,  |   | module (Dart)  |
| service +    |   | isolate latar    |   | player/search/ |
| audio_session|   |                  |   | browse parser  |
+-------+------+   +---------+--------+   +-------+--------+
        |                    |                    |
+-------v------+   +---------v--------+   +-------v--------+
| Media3       |   | File unduhan +   |   | QuickJS solver |
| ExoPlayer    |   | cache streaming  |   | (quickjs_     |
| (Android)    |   | (storage lokal)  |   |  engine) +     |
|              |   |                  |   |  config remote |
+--------------+   +------------------+   +----------------+
```

Aturan lapisan yang mengikat:

- Widget hanya berbicara ke service. Service hanya berbicara ke port/interface. Implementasi konkret (just_audio, drift, dio) hidup di balik interface dan bisa diganti tanpa menyentuh UI.
- Semua pekerjaan berat (query besar, parsing, solver QuickJS, unduhan) berjalan di luar UI thread: drift di background isolate, QuickJS di thread/isolate khusus dengan stack besar, unduhan di foreground service terpisah.
- Semua fetch jaringan punya timeout eksplisit (aturan proyek, berlaku umum). Tidak ada request tanpa batas waktu, termasuk `res.json()` dan pemanggilan sesi auth.
- Tidak ada data pengguna yang meninggalkan perangkat kecuali request ke YouTube/Google (pencarian, stream) dan penyedia lirik. Tidak ada server milik app, tidak ada telemetri.

## 2. Stack audio

Sumber: laporan A2, `hidden_files/tim/library-audio-flutter.md`. Semua API di bawah ini dibaca dari dokumentasi pub.dev dan README paket pada 15 November 2026.

### 2.1 Rekomendasi: just_audio 0.10.6 + audio_service 0.18.19 + audio_session 0.2.4

Ketiganya dari satu maintainer (Ryan Heise), dirancang untuk bekerja bersama, rilis terakhir serentak 29 Juni 2026. Pola ini dipakai luas di production, termasuk Songloft dan BlackHole.

**just_audio 0.10.6** (MIT, pertama terbit 28 Nov 2019, Flutter minimum 3.27.0). Di Android memakai Media3 ExoPlayer. API terverifikasi yang relevan untuk v1: `AudioPlayer`, `setUrl` (dengan `headers` dan `userAgent`), `play`, `pause`, `stop`, `seek`, `setVolume`, `setSpeed`, `setAudioSources` (dengan `initialIndex`, `initialPosition`, `useLazyPreparation`, `shuffleOrder`), `addAudioSource`, `insertAudioSource`, `removeAudioSourceAt`, `moveAudioSource`, `seekToNext`, `seekToPrevious`, `setShuffleModeEnabled`, `setLoopMode` (`off`, `all`, `one`), `setClip`, `LockCachingAudioSource` (eksperimental, cache sambil putar), `StreamAudioSource` (sumber byte kustom, relevan bila tim perlu menyuapkan byte audio sendiri), stream state (`playerStateStream`, `durationStream`, `positionStream`, `bufferedPositionStream`, `sequenceStateStream`, `currentIndexStream`, `errorStream`), efek Android (`AndroidEqualizer`, `AndroidLoudnessEnhancer`, `AudioPipeline`), dan `setSkipSilenceEnabled` serta `setPitch` (keduanya Android saja, nama method terverifikasi dari changelog dan tabel fitur; signature lengkap per parameter wajib dicek di Fase 2).

Detail konfigurasi yang wajib masuk checklist Fase 2: header, caching, dan stream source diimplementasikan lewat proxy HTTP localhost yang butuh akses cleartext ke `127.0.0.1`. README menyarankan network security config khusus localhost, bukan `usesCleartextTraffic` global. Catatan A6 soal Network Security Config dan Dio/HttpClient Dart masih belum terverifikasi (bagian 9); kedua hal ini harus diuji bersama di Fase 2 karena saling terkait.

**audio_service 0.18.19** (pertama terbit 28 Nov 2018). Membungkus engine audio agar jalan di background dan berinteraksi dengan notifikasi media, lock screen, tombol headset, wearables, dan Android Auto. API terverifikasi: `AudioHandler`, `BaseAudioHandler`, mixin `QueueHandler` dan `SeekHandler`, `AudioService.init`, `AudioServiceConfig` (termasuk `androidNotificationChannelId`, `androidNotificationChannelName`, `androidStopForegroundOnPause`), `MediaItem`, `PlaybackState` (field `controls`, `systemActions`, `androidCompactActionIndices`, `processingState`, `playing`, `updatePosition`, `bufferedPosition`, `speed`, `queueIndex`), `setRepeatMode`, `setShuffleMode`, `customAction`, `playMediaItem`, `playFromSearch`, `playFromUri`, `playFromMediaId`, `addQueueItem`, `insertQueueItem`, `removeQueueItem`, `updateQueue`, `skipToNext`, `skipToPrevious`, `skipToQueueItem`, stream `AudioService.position`, dan `IsolatedAudioHandler`. Setup Android wajib: izin `WAKE_LOCK`, `FOREGROUND_SERVICE`, `FOREGROUND_SERVICE_MEDIA_PLAYBACK` (target SDK 34); activity `AudioServiceActivity`; service `AudioService` dengan `foregroundServiceType="mediaPlayback"` dan intent filter `android.media.browse.MediaBrowserService`; receiver `MediaButtonReceiver` untuk action `MEDIA_BUTTON`. Satu proses hanya menjalankan satu audio_service. Lisensi audio_service tidak terverifikasi dalam riset ini (bagian 9).

**audio_session 0.2.4** (pertama terbit 23 Agu 2020). Mengonfigurasi interaksi dengan app audio lain. API terverifikasi: `AudioSession.instance`, `configure` dengan `AudioSessionConfiguration.music()`, `.speech()`, atau `.custom()`, `setActive`, `interruptionEventStream` (`AudioInterruptionType.duck`, `pause`, `unknown`), `becomingNoisyEventStream` (headset dicabut), `devicesChangedEventStream`, `configurationStream`, `AndroidAudioAttributes`, `AndroidAudioFocusGainType`, `androidWillPauseWhenDucked`. just_audio sendiri punya parameter konstruktor `handleInterruptions` yang otomatis pause saat interupsi. Lisensi audio_session tidak terverifikasi dalam riset ini (bagian 9).

### 2.2 Tiga risiko terbesar stack audio dan mitigasinya

**Risiko 1: audio_service di atas androidx.media yang sudah deprecated.** Implementasi native Android-nya sangat terindikasi memakai `MediaBrowserServiceCompat` dan `MediaSessionCompat` dari `androidx.media`, bukan Media3. Bukti: ringkasan DeepWiki atas repo (sumber sekunder) ditambah pola manifest di README audio_service sendiri (service dengan intent filter `android.media.browse.MediaBrowserService` + `MediaButtonReceiver`), yang konsisten dengan stack `androidx.media`. Pembacaan source langsung belum dilakukan (bagian 9). Deprecation-nya sendiri terkonfirmasi dari Google: halaman rilis Jetpack Media menyatakan versi 1.8.0 (6 Mei 2026) berisi "Deprecate `androidx.media`. Use `androidx.media3` instead.", dengan header halaman "Superseded by media3". Kelima kompetitor native memakai Media3 `MediaSession` dan `MediaLibraryService`. Rute Flutter tidak mencapai stack sesi Media3 tanpa menulis kode native sendiri atau menunggu migrasi audio_service, dan tidak ditemukan bukti migrasi tersebut dalam sumber yang dibaca. API deprecated tetap berfungsi, tetapi tidak ada perbaikan dan tidak ada fitur baru dari Google untuk jalur itu, dan risiko pecah di Android versi mendatang lebih tinggi. Mitigasi: uji audio_service di Android 15 dan 16 sejak awal Fase 2 dan catat perilaku notifikasi medianya; `just_audio_background` dicatat sebagai jalan keluar bila audio_service terbukti bermasalah dan tim memutuskan memangkas fitur background.

**Risiko 2: just_audio tertinggal di media3 1.4.1.** Changelog just_audio mencatat migrasi ke media3 ExoPlayer 1.4.1 pada 0.9.45 (1 Feb 2025, terverifikasi verbatim dari changelog pub.dev), tanpa bump versi media3 di changelog setelah itu sampai 0.10.6. Media3 stabil terbaru adalah 1.11.1 (11 Nov 2026): selisih tujuh rilis minor. Versi persis di file build 0.10.6 tidak terverifikasi dari source (bagian 9). Praktisnya, bug dan perbaikan decoder yang masuk Media3 setelah 1.4.1 tidak didapat app selama just_audio tidak bump. Ini risiko perawatan, bukan blocker: 1.4.1 adalah rilis stabil yang sudah dipakai luas, dan persis sama dengan versi Media3 InnerTune. Catatan kualitas dokumentasi: README just_audio masih memuat snippet lama `com.google.android.exoplayer` untuk memaksa versi ExoPlayer, padahal paket sudah bermigrasi ke media3. Snippet itu stale dan jangan diikuti. README juga masih mencantumkan "Equaliser" di bagian "Vote on upcoming features" padahal tabel fitur menandai equalizer Android sebagai tersedia. Dokumentasi just_audio tidak konsisten di titik ini; tabel fitur dan changelog yang menjadi acuan.

**Risiko 3: satu maintainer untuk tiga paket utama.** Rilis terakhir ketiganya 29 Juni 2026, sekitar empat setengah bulan sebelum riset ini. Mitigasi utama adalah arsitektur: bungkus player di balik interface Dart milik aplikasi (`AudioPlayerPort` atau sejenisnya) sehingga engine bisa diganti tanpa menyentuh UI, antrean, dan state management. Jangan panggil API just_audio langsung dari widget. Semua akses lewat service player.

### 2.3 Matriks fitur v1

| Fitur v1 | just_audio | audio_service | media_kit | mpv_audio_kit | audioplayers |
|---|---|---|---|---|---|
| Antrean | Ya, `setAudioSources`, tambah/sisip/hapus/pindah item | Ya, `addQueueItem`, `updateQueue`, `skipToQueueItem` | Ya, `Playlist`, modifikasi queue | Tidak diverifikasi | Tidak, tulis sendiri |
| Shuffle | Ya, `setShuffleModeEnabled`, `shuffleOrder` | Ya, `setShuffleMode` | Ya | Tidak diverifikasi | Tidak |
| Repeat | Ya, `setLoopMode` off/all/one | Ya, `setRepeatMode` none/one/all/group | Ya, `setPlaylistMode` none/single/loop | Tidak diverifikasi | Tidak |
| Skip silence | Ya, Android saja | Tidak | Tidak ditemukan | Tidak ditemukan | Tidak ditemukan |
| Normalisasi volume | Sebagian, `AndroidLoudnessEnhancer` adalah boost, bukan normalisasi | Tidak | Tidak ditemukan | Ya, `LoudnormEffect` EBU R128 + ReplayGain | Tidak ditemukan |
| Tempo/pitch | Ya, `setSpeed` semua platform, `setPitch` Android saja | Tidak | Ya, `setRate`, `setPitch` | Ya, pitch/tempo shift | Sebagian, `setPlaybackRate` |
| Sleep timer | Tidak, level app | Tidak, level app | Tidak, level app | Tidak, level app | Tidak, level app |
| Gapless | Ya, Android | Tidak relevan (bukan engine) | Tidak terverifikasi | Ya, dinyatakan di README | Tidak ditemukan |
| Equalizer | Ya, Android saja (`AndroidEqualizer`) | Tidak | Tidak ditemukan | Ya, 10 band ISO, semua platform | Tidak ditemukan |

### 2.4 Equalizer, normalisasi, sleep timer

**Equalizer v1: `AndroidEqualizer` just_audio.** Tidak ada plugin equalizer standalone untuk Flutter yang nyata dan dirawat; pencarian pub.dev tidak menemukan paket equalizer standalone yang aktif. `AndroidEqualizer` dipasang lewat `AudioPipeline(androidAudioEffects: [...])` pada konstruktor `AudioPlayer`, dengan properti `enabled`. Efek ini memakai efek Equalizer sistem Android, sehingga jumlah band dan frekuensi tengah mengikuti perangkat, bukan standar tetap. Detail band per perangkat wajib diuji di perangkat nyata di Fase 2. UI band v1 membaca kapabilitas perangkat saat runtime, dan dokumen produk mencatat bahwa EQ v1 adalah Android-only dan bergantung pada perangkat. Bila owner menuntut EQ 10 band yang konsisten di semua perangkat, satu-satunya jalan Flutter yang terverifikasi adalah mpv_audio_kit, dengan konsekuensi maturity dan F-Droid di bawah ini. `flutter_soloud` 1.2.5 punya efek equalizer tetapi terakhir diperbarui 989 hari lalu (sekitar Feb 2024): tidak dirawat, ditolak. `audio_video_player` 0.1.0-beta.5 masih beta dan bukan engine utama: tidak direkomendasikan sebagai fondasi EQ.

**Normalisasi volume antar lagu: ditunda ke pasca-v1.** `AndroidLoudnessEnhancer` adalah efek boost loudness sistem Android, bukan normalisasi antar lagu berbasis pengukuran loudness. Normalisasi yang benar (ReplayGain atau EBU R128) hanya ada di mpv_audio_kit. Rekomendasi tim: terima LoudnessEnhancer sebagai volume boost dan tunda normalisasi antar lagu, daripada berpura-pura LoudnessEnhancer adalah normalisasi.

**Sleep timer: implementasi level app.** Tidak satu pun library yang dibaca menyediakan sleep timer sebagai API. Implementasinya `Timer` yang memanggil `pause` (dan sebaiknya juga `stop` pada service) setelah durasi yang dipilih pengguna. Satu detail yang wajib diputuskan di Fase 2: apakah timer juga menghentikan foreground service atau hanya pause, karena keduanya memberi pengalaman yang berbeda saat pengguna membuka app lagi.

### 2.5 Cadangan engine, berurutan

1. **Cadangan pertama (murah): just_audio + just_audio_media_kit 2.1.0** (lisensi Unlicense). Binding media_kit untuk just_audio; API just_audio berjalan di atas engine libmpv. Kode Dart pemutar hampir tidak berubah; audio_service dan audio_session tetap dipakai. Kekurangan: `SilenceAudioSource` tidak didukung, dan perawatan binding ini perlu dinilai di Fase 2.
2. **Cadangan kedua (sedang): media_kit 1.2.6 langsung + audio_service custom handler.** Dipakai bila just_audio berhenti dirawat sepenuhnya, mengikuti pola TubeNative. Biayanya: menulis lapisan antrean, shuffle, repeat, dan gapless sendiri di atas API media_kit, karena media_kit tidak menyediakan API playlist sematang just_audio. Catatan: media_kit tidak punya service background bawaan; rilis terakhir 13 Des 2025 (sekitar sebelas bulan sebelum riset); lisensi libmpv yang dibundel `media_kit_libs_audio` tidak terverifikasi; ukuran native libs per ABI tidak terverifikasi.
3. **Cadangan ketiga (jangka panjang): mpv_audio_kit 0.7.0** (BSD-3-Clause untuk paket Dart; libmpv yang dibundel LGPL v3+). Audio player berbasis mpv v0.41.0 dengan 86 efek FFmpeg bertipe, EQ grafis 10 band frekuensi tengah standar ISO (31 Hz sampai 16 kHz), normalisasi EBU R128 (`LoudnormEffect`), ReplayGain, dan gapless. Penghalang v1: baru delapan bulan (terbit 15 Mar 2026), masih 0.x, satu developer, API berubah cepat; build mengunduh biner libmpv untuk tiap target native dan memeriksa SHA-256-nya, sehingga build pertama butuh akses network (F-Droid membangun dari source tanpa network dan umumnya menolak biner prebuilt; status kebijakannya belum terverifikasi); menambah 7,7-8,3 MB per ABI; dukungan antrean dan integrasi background tidak diverifikasi dalam riset ini. Evaluasi ulang pada tiap milestone besar.

**Yang ditolak sebagai engine:** audioplayers (tanpa antrean, default MediaPlayer, ExoPlayer hanya lewat implementasi non-endorsed yang opt-in, tanpa klaim gapless/skip silence/EQ/pitch yang ditemukan); mt_audio 0.2.0-beta.3 (perantara beta di atas stack yang sama); flutter_soloud (tidak dirawat); menulis engine native Media3 sendiri di Fase 2 (di luar cakupan Flutter dan menghilangkan alasan memakai Flutter; bila tim sampai mempertimbangkan ini, itu sinyal untuk mengevaluasi ulang pilihan Flutter itu sendiri, dan keputusan sebesar itu ada di owner dan koordinator).

## 3. Ekstraksi stream

Sumber: laporan A4, `hidden_files/tim/ekstraksi-stream.md`. Semua paket, versi, dan tanggal dicek live 15 November 2026 dari pub.dev dan GitHub API.

### 3.1 Tidak ada paket Dart yang siap pakai mentah-mentah untuk v1

| Paket | Versi terakhir | Rilis terakhir | Lisensi | Status |
|---|---|---|---|---|
| youtube_explode_dart | 3.1.0 | 9 Mei 2026 | BSD-3-Clause | Hidup pelan, solver JS hanya Deno |
| darttubefix | 1.0.8 di repo | 15 Sep 2026 | MIT | Baru, satu maintainer, belum teruji |
| youtube_extractor_muzo | 1.0.0 | 31 Mei 2026 | MIT | Satu rilis, tanpa update sejak rilis |
| muzoapi | 0.0.1 | 23 Des 2025 | Tidak terverifikasi | Sangat awal, hampir tanpa informasi |
| youtube_explode_dart_plus | 1.0.3 | 18 Okt 2025 | Tidak terverifikasi | Fork, ada peringatan kompatibilitas Dart 3.x |
| ytdlp_flutter | 0.1.0 | 29 Agu 2026 | MIT, Android GPL-3.0 | Baru, yt-dlp asli, tambah sekitar 30 MB/ABI |
| extractor | 1.0.0 | 26 Feb 2026 | MIT, Android GPL-3.0 | Android saja, yt-dlp asli |
| android_new_pipe_extractor | Tidak terverifikasi | 29 Mei 2025 | Tidak terverifikasi | README template, tidak layak |
| zen_engine | Tidak terverifikasi | 3 Nov 2026 | GPL-3.0 | Engine musik lengkap, bukan sekadar extractor |
| yt | 3.1.0 | 19 Mei 2026 | Tidak terverifikasi | API resmi, butuh API key, bukan extractor |

**youtube_explode_dart 3.1.0** adalah fondasi paling matang di ekosistem Dart (423 bintang, 67 open issue per 15 Nov 2026, tidak diarsipkan), tetapi tidak bisa dipakai mentah-mentah di Android: README menyatakan verbatim "Some youtube clients require you to complete a js challenge in order to download a video. This requires having a full js runtime like deno, nodejs or quickjs. Currently the only implemented runtime is deno". Deno tidak jalan di dalam HP Android. CHANGELOG 3.0.0 mencatat antarmuka solver kustom tersedia ("Implement new interfaces for custom JS challenges solver"), tetapi implementasi QuickJS tidak tersedia di paket ini. Nilai terbesarnya untuk proyek ini adalah sebagai referensi implementasi dan kandidat fork dengan solver yang diganti. Sinyal komunitas: app Harmony Music memakai fork git paket ini (anandnet/youtube_explode_dart, ref 1d9ec9ba) di pubspec-nya, bukan versi pub.dev. API nyata yang terverifikasi: `YoutubeExplode()`, `yt.videos.get(id)`, `yt.videos.streams.getManifest(id, ytClients: [...])`, `manifest.audioOnly.withHigestBitrate()`, `manifest.hls`, `yt.videos.streams.get(streamInfo)`, `yt.videos.closedCaptions.getManifest(id)`, `yt.playlists.getVideos(id)`, `yt.videos.comments.getComments(video)`. Bila `ytClients` null, library mengatur client sendiri (default client android, ditambah client tv bila ada js solver). Dokumentasi mencatat video dengan batasan umur sudah tidak didukung karena perubahan API YouTube, dan client android sering mencegah pengunduhan stream yang sama lebih dari sekali.

**darttubefix 1.0.8** (versi repo; nomor versi persis yang terbit di pub.dev tidak terverifikasi) adalah kandidat paling menarik di antara paket Dart murni karena cakupan YouTube Music-nya dan desain fallback client-nya (`WEB_MUSIC`, `WEB`, `ANDROID_VR`, `TV`, `IOS`), tetapi berumur tiga bulan (rilis pertama 22 Agu 2026), nol bintang, satu maintainer, dan belum teruji komunitas. Terjemahan dari paket Python `pytubefix`. Untuk Flutter, README merekomendasikan `flutter_js` agar tidak butuh Node.js. Klaim README "100% playability" untuk decipher dinamis tidak bisa diverifikasi dan tidak dipakai sebagai dasar rekomendasi. Layak di-spike di Fase 2 berdampingan dengan InnerTube kustom.

**youtube_extractor_muzo 1.0.0** punya desain paling lengkap di atas kertas (satu-satunya paket Dart yang mengklaim menangani poToken lewat attestation BotGuard di WebView headless, fallback berurutan lewat 11 client InnerTube, cache bundle script player di disk dengan TTL 6 jam), tetapi tanpa perawatan dan tanpa bukti pengujian independen. Arsitekturnya layak dipelajari, paketnya tidak layak dijadikan dependensi v1.

**ytdlp_flutter 0.1.0** dan **extractor 1.0.0** menjalankan yt-dlp asli di perangkat (Android memakai youtubedl-android: Python 3.8 plus FFmpeg yang dibundel), jadi paling tahan terhadap perubahan YouTube, dengan harga tambah sekitar 30 MB per ABI dan ketergantungan GPL-3.0 lewat youtubedl-android (selaras dengan rekomendasi lisensi tim C8, bukan penghalang). Keduanya mensyaratkan minSdk 24 dan `android:extractNativeLibs="true"`. ytdlp_flutter bisa auto-update yt-dlp saat init plus `Ytdlp.update()` (Android saja). extractor (terbit pertama 8 Mei 2022) punya riwayat lebih panjang; versi yang dibundel: youtubedl-android v0.18.1, yt-dlp 2025.11.12 (bisa diperbarui), FFmpeg 6.0, Python 3.8; komunikasi Dart ke native memakai Pigeon.

### 3.2 Jalur utama: InnerTube kustom di Dart sebagai modul terpisah

Bangun client InnerTube sendiri di Dart sebagai modul terpisah di dalam repo app. Yang realistis adalah client InnerTube minimal untuk audio: player, search, browse, plus solver signature dan n challenge di QuickJS, plus fallback antar client. Yang tidak realistis adalah meniru seluruh yt-dlp atau YouTube.js. Semua kompetitor Kotlin menempuh jalan ini (InnerTune, ViMusic, OuterTune era YTM, dan SimpMusic semuanya memakai InnerTube kustom dengan Ktor). Tidak ada dari mereka yang menemukan jalan pintas lewat library jadi. Beban perawatannya permanen, dan itu harus diterima sebelum memulai.

**Endpoint yang terverifikasi** (dari README paket Python `innertube` di PyPI dan artikel dev.to 26 Mar 2026; semua memakai POST JSON ke `https://www.youtube.com/youtubei/v1/<nama>` atau `https://music.youtube.com/youtubei/v1/<nama>` untuk YouTube Music): `config`, `browse` (navigasi hierarkis: home, channel, playlist), `player` (informasi playback dan URL stream), `search`, `next` (komentar, rekomendasi, antrean), `get_transcript`, `music/get_search_suggestions`, `music/get_queue`. Untuk v1 audio, endpoint wajib adalah `player` dan `search`, disusul `browse` untuk halaman artis, album, dan playlist.

**Bentuk permintaan player:** body JSON berisi `context.client` dengan `clientName`, `clientVersion`, dan `visitorData`, ditambah `videoId`. Bila client membutuhkan attestation, token dikirim di `serviceIntegrityDimensions.poToken`. Nilai `clientName` dan `clientVersion` harus cocok dengan client asli yang ditiru, termasuk header HTTP yang menyertainya (User-Agent dan Referer yang sesuai). Paket `innertube` mendokumentasikan 65 konteks client yang sudah dikonfigurasi; ini menjadi referensi untuk membangun tabel client di Dart.

**Hasil spike P1, 16 Nov 2026 (mengikat):** `playbackContext.contentPlaybackContext.signatureTimestamp` (sts dari base.js yang sedang dipakai) WAJIB ada di request player pertama. Terbukti 4 kombinasi (`diag-sts-vd.js`): dengan sts, WEB_REMIX mengembalikan OK (4 format audio) baik dengan maupun tanpa visitorData; tanpa sts, server membalas UNPLAYABLE ("The page needs to be reloaded.") baik dengan maupun tanpa visitorData. Karena itu app memuat script player DULU (untuk sts) sebelum request player pertama; desain lama ("tanpa sts dulu, ulangi bila LOGIN_REQUIRED") salah, karena tanpa sts server membalas UNPLAYABLE, bukan LOGIN_REQUIRED, sehingga retry tidak pernah terpicu. visitorData segar dari endpoint search tetap dipakai (cache 6 jam; refresh sekali + ulangi sekali saat LOGIN_REQUIRED): bukti probe 15 Nov 2026, saat reputasi IP rendah, request tanpa visitorData dibalas LOGIN_REQUIRED untuk SEMUA client, sementara request yang sama dengan visitorData segar lolos.

**Bentuk respons player:** `videoDetails` (metadata), `playabilityStatus` (status bisa diputar atau tidak, beserta alasan), dan `streamingData` dengan `formats` (muxed) dan `adaptiveFormats` (DASH terpisah; tiap entri membawa `itag`, `mimeType`, `bitrate`, dan `url`, atau `signatureCipher` bila URL-nya terproteksi signature; ada juga `serverAbrStreamingUrl` untuk format SABR). Struktur lengkap respons player tetap perlu dibuktikan dengan memanggil endpoint secara langsung di Fase 2, karena YouTube mengubah respons tanpa pemberitahuan.

**Format audio yang tersedia** (dari gist daftar itag yang diperbarui 11 Okt 2026, dikuatkan dua artikel dev.to Mei dan Okt 2026):

| Itag | Container | Codec | Bitrate | Ketersediaan |
|---|---|---|---|---|
| 139 | MP4 | AAC (LC) | 48 kbps | Ya |
| 140 | MP4 | AAC (LC) | 128 kbps | Ya, termasuk YT Music |
| 141 | MP4 | AAC (LC) | 256 kbps | Premium saja, opsi High Quality |
| 249 | WebM | Opus (VBR) | sekitar 50 kbps | Sebagian video |
| 250 | WebM | Opus (VBR) | sekitar 70 kbps | Sebagian video |
| 251 | WebM | Opus (VBR) | sekitar 128 sampai 160 kbps | Ya |

Kualitas audio publik terbaik adalah itag 251 (Opus, sampai sekitar 160 kbps). Tidak ada stream 320 kbps dan tidak ada yang lossless. Itag 141 (AAC 256 kbps) hanya untuk pelanggan Premium. Klaim "lossless streaming" yang muncul di deskripsi zen_engine tidak bisa benar untuk sumber YouTube dan tidak dipakai di sini. Urutan pemilihan itag audio di parser: 251, lalu 140, lalu 250, lalu 249, lalu 139.

**Client InnerTube dan urutan fallback v1.** ID client adalah angka stabil; versi client berubah seiring rilis app asli dan wajib hidup di konfigurasi remote, bukan di-hardcode. Data versi di README zerodytrash/YouTube-Internal-Clients berasal dari September 2022 (sudah basi empat tahun) dan hanya menunjukkan bentuk nilai, bukan nilai yang harus dipakai. Selama penulisan laporan A4, verifikasi ulang menemukan lima angka versi client di draf awal salah dan semuanya diperbaiki sebelum laporan selesai; ini bukti standar verifikasi tim, bukan kelemahan laporan.

| Client | ID | Dipakai untuk |
|---|---|---|
| WEB | 1 | Web YouTube umum; terakhir karena SABR dan poToken |
| ANDROID | 3 | App YouTube Android |
| IOS | 5 | App YouTube iOS; memberi HLS, audio hanya itag 139 dan 140 |
| TVHTML5 | 7 | App YouTube TV |
| ANDROID_MUSIC | 21 | App YouTube Music Android; utama untuk musik |
| IOS_MUSIC | 26 | App YouTube Music iOS |
| ANDROID_VR | 28 | App YouTube VR Android; fallback stream |
| WEB_EMBEDDED_PLAYER | 56 | Player embed web |
| WEB_MUSIC | 61 | Web YouTube Music |
| WEB_REMIX | 67 | Web YouTube Music (nama lama); kedua |
| TVHTML5_SIMPLY | 75 | TV sederhana |
| TVHTML5_SIMPLY_EMBEDDED_PLAYER | 85 | Player embed TV; fallback stream |

Urutan fallback v1 (HASIL UKUR spike P1, 15-16 Nov 2026 - menggantikan usulan desain di bawah; bukti lengkap di `docs/spike-ekstraksi.md` di repo Laras): 1. WEB_REMIX (67), 2. MWEB (2). Hanya dua client ini yang memberi format audio konvensional (cipher) untuk 5/5 lagu kanari. ANDROID (3) dan IOS (5) dikecualikan: playability OK tapi SEMUA format audio hanya SABR (tanpa `url` dan tanpa `signatureCipher`). ANDROID_MUSIC (21) dan IOS_MUSIC (26) dikecualikan: LOGIN_REQUIRED ("Please sign in") untuk semua versi yang dicoba. WEB (1) dikecualikan: LOGIN_REQUIRED ("Sign in to confirm you're not a bot"). WEB_EMBEDDED_PLAYER (56) dikecualikan: ERROR ("This video is unavailable"). ANDROID_VR (28) dikecualikan: LOGIN_REQUIRED. TVHTML5_SIMPLY_EMBEDDED_PLAYER (85) dikecualikan: ERROR ("no longer supported").

Versi client yang terverifikasi live (15 Nov 2026, diverifikasi ulang 16 Nov 2026): WEB_REMIX 1.20261110.04.00 (dari HTML music.youtube.com; versi pin yt-dlp/pytubefix 1.20260707.12.00 sudah terlalu tua dan kena LOGIN_REQUIRED), MWEB 2.20260708.05.00 (dari yt-dlp master), WEB 2.20261112.10.00 (dari HTML youtube.com). base.js hash `fad7e4e9` (2.677.001 byte, sts 20767) tidak berubah antara 15 dan 16 Nov 2026.

Usulan desain awal (DIGANTI hasil ukur di atas, disimpan sebagai riwayat): 1. ANDROID_MUSIC (21), 2. WEB_REMIX (67), 3. ANDROID_VR (28), 4. TVHTML5_SIMPLY_EMBEDDED_PLAYER (85), 5. WEB (1, terakhir, dan hanya bila app sudah bisa menangani respons SABR dengan benar: menolak format SABR, bukan memilihnya). Kegagalan satu client tidak boleh terlihat pengguna sebagai error bila client berikut berhasil. Kegagalan baru ditampilkan bila semua client gagal, dengan pesan yang menyebut langkah yang bisa dicoba (coba lagi, ganti lagu), bukan kode error mentah.

### 3.3 Tiga mekanisme proteksi YouTube yang wajib ditangani

**Signature deciphering dan n challenge.** URL stream diacak: parameter signature (`sig` atau `s`) harus diubah dengan fungsi decipher yang hanya ada di dalam script player YouTube (`base.js`); parameter `n` (throttling) harus diubah dengan fungsi transform yang juga ada di `base.js`. Bila nilai `n` salah, server memberi 0 byte atau membatasi kecepatan sampai tidak bisa diputar. Tiap video memakai versi player tertentu, ditandai `signatureTimestamp` (disingkat sts di kode SimpMusic). Cara kerja solver yang dipakai semua implementasi modern: unduh `base.js` untuk versi player yang dipakai respons; temukan fungsi decipher dan fungsi transform n di dalam script itu (langkah yang rapuh, karena YouTube mengacak nama fungsi dan struktur obfuscation di tiap rilis player); jalankan kedua fungsi itu di runtime JavaScript di perangkat; sisipkan hasil decipher ke URL stream. Pendekatan tiap proyek: yt-dlp mengimplementasikan ulang transform di Python dengan modul EJS untuk kasus yang butuh eksekusi JS; YouTube.js tidak menyertakan interpreter bawaan ("YouTube.js does not include a built-in interpreter for this purpose, so you must provide your own"); ytdl-core mem-parsing AST lalu mengeksekusi di sandbox; SimpMusic menjalankan script player utuh di QuickJS; NewPipeExtractor memakai Mozilla Rhino di dalam library (terlihat dari aturan ProGuard `-keep class org.mozilla.javascript.**` di README-nya, terverifikasi koordinator dari halaman repo live).

**poToken dan BotGuard.** Proof of Origin token adalah token attestation dari sistem anti bot Google (BotGuard di web, DroidGuard di Android). Token dikirim di `serviceIntegrityDimensions.poToken`, bersama `visitorData` di `context.client` (dokumentasi pytubefix 11.2.1). Tanpa poToken, request dari client yang terdampak bisa mengembalikan HTTP 403, error deteksi bot, atau pemblokiran akun dan IP. Client yang paling membutuhkan adalah WEB, MWEB, dan TV (dokumentasi ytdl-core). Minting poToken butuh menjalankan BotGuard VM JavaScript; implementasi yang ada: `bgutils-js`, provider plugin yt-dlp seperti `bgutil-ytdlp-pot-provider`, dan WebView headless V8 (dipakai youtube_extractor_muzo). Implikasi untuk v1: hindari keharusan minting poToken dengan memilih client yang tidak membutuhkannya sebagai jalur utama. Bila suatu saat semua client butuh poToken, minting BotGuard di perangkat menjadi pekerjaan besar tersendiri, dan itu adalah risiko yang harus dicatat sejak awal, bukan kejutan di tengah jalan. Minting poToken sengaja TIDAK masuk v1.

**SABR (Server Adaptive Bitrate).** Protokol streaming adaptif milik YouTube yang dikendalikan server. Format SABR tidak memberi URL HTTP statis di `streamingData`; sebagai gantinya ada `serverAbrStreamingUrl`. Playback memakai request protokol biner (`VideoPlaybackAbrRequest`), framing UMP (YouTube Media Protocol), dan asosiasi track audio dan video secara bersamaan. Stream SABR sering membutuhkan attestation poToken. Deteksi: keberadaan field `serverAbrStreamingUrl` menandai stream SABR. Implikasi untuk v1: client WEB tidak bisa diandalkan untuk URL audio langsung; jalur utama harus memakai client yang masih memberi URL konvensional. Bila suatu saat semua client memberi SABR saja, app butuh implementasi client SABR (protobuf plus UMP) atau beralih ke yt-dlp. Ini risiko struktural terbesar kedua setelah poToken. Klaim bahwa semua permukaan web YouTube sudah pindah ke SABR bersumber tunggal (README ytdlp_flutter) dan tidak diverifikasi independen; mekanisme SABR sendiri terverifikasi dari ytdl-core dan JavaTube.

**Hasil spike P1, 15 Nov 2026 (mengikat, memperbaiki aturan deteksi di atas):** status SABR ditentukan PER FORMAT, bukan dari field tingkat atas `streamingData`. Respons WEB_REMIX membawa `serverAbrStreamingUrl` tingkat atas SEKALIGUS format konvensional di `adaptiveFormats`, jadi field tingkat atas saja bukan penanda SABR-only. Bentuk SABR-only yang teramati (client ANDROID/IOS): format audio TIDAK punya `url`, TIDAK punya `signatureCipher`, dan TIDAK punya `serverAbrStreamingUrl` per format. Aturan parser: format ditandai SABR bila (a) punya `serverAbrStreamingUrl` sendiri, ATAU (b) tidak punya URL langsung maupun cipher SEMENTARA respons membawa URL SABR tingkat atas. Pemilih itag tidak pernah memilih format SABR; `serverAbrStreamingUrl` tidak pernah dipakai sebagai URL putar.

### 3.4 QuickJS di perangkat: angka SimpMusic yang bisa ditiru langsung

SimpMusic adalah satu-satunya kompetitor yang rilis rutin sampai November 2026 (v2.5.0, 1 Nov 2026; commit terakhir 13 Nov 2026). Ia memakai tiga jalur ekstraksi sekaligus: InnerTube kustom (Ktor), NewPipeExtractor v0.26.1, dan fork BravePipeExtractor, plus QuickJS (quickjs-kt 1.0.15, komentar di `libs.versions.toml` branch dev: "QuickJS binding for KMP, runs YouTube's player JS to solve sig/n challenges locally"). Tim A4 membaca source-nya langsung lewat GitHub API (submodule `core`, repo maxrave-dev/core, commit yang di-pin SimpMusic dev: 8413a257cbe45d102a9f101f2760e35b549e4d9e).

File `QuickJsEngine.kt` (262 baris, komentar menyatakan pendekatannya berdasarkan integrasi QuickJS milik yt-dlp) memberi angka-angka yang tidak boleh diulang dari nol:

- Timeout evaluasi: 10.000 ms.
- Limit memori native: 192 MiB. Script player YouTube berukuran sekitar 2,6 MiB, dan membangun AST-nya di EJS butuh lebih dari 128 MiB.
- Limit stack native: 8 MiB. Default stack QuickJS 256 KB tidak cukup untuk n-transform, dan engine bisa SIGSEGV tanpa melempar error JS bila stack habis.
- Eksekusi butuh thread khusus dengan stack besar.
- Semua entry point diserialisasi, karena dua track yang resolve bersamaan dan tiap runtime QuickJS memegang limit 192 MB bisa kehabisan memori bila berjalan paralel.

Implikasi untuk Flutter: runtime JS tidak boleh jalan di UI thread, dan batas memori serta stack harus diatur eksplisit. Angka-angka SimpMusic adalah titik awal yang sudah terbukti, bukan teori. Keputusan koordinator atas selisih dengan usulan A6 (16 MB, 5 detik) ada di bagian 7.

**Padanan QuickJS di Flutter** (semua dicek di pub.dev 15 Nov 2026):

| Paket | Versi | Rilis terakhir | Engine | Catatan |
|---|---|---|---|---|
| flutter_js | 0.8.6 | 27 Jan 2026 | QuickJS 2021-03-27 di Android/Windows/Linux, JavaScriptCore di iOS/macOS | MIT, paling lama dipakai, engine tertanggal 2021 |
| quickjs_engine | 0.1.7 | 5 Nov 2026 | QuickJS-NG 0.14.0, satu engine di semua platform | MIT, fork flutter_js, API kompatibel; pilihan pertama |
| flutter_qjs_next | Tidak terverifikasi | 26 Sep 2026 | QuickJS 2026-06-04 | API kompatibel flutter_js, FFI native, tanpa Web; pembanding |
| gg_quickjs | Tidak terverifikasi | 19 Okt 2026 | QuickJS-ng 0.17.0 | MIT, build hook kompilasi C dari source, isolate latar, sandbox |

quickjs_engine terverifikasi koordinator dari halaman pub.dev live: membundel QuickJS-NG 0.14.0, fork flutter_js, API-compatible drop-in (`getJavascriptRuntime()`, `evaluate()`, `onMessage()`), satu engine di semua platform, snippet dependensi `quickjs_engine: ^0.1.7`, Android dibangun dari source lewat NDK CMake (4 ABI, alignment halaman ELF 16 KB). Rekomendasi spike Fase 2: quickjs_engine sebagai pilihan pertama, flutter_qjs_next sebagai pembanding. Keduanya harus dibuktikan menjalankan n-transform dari `base.js` asli dengan batas memori dan stack mengikuti angka SimpMusic sebelum dipakai di v1. Jalan kelima adalah `webview_flutter` dengan V8 headless (dipakai youtube_extractor_muzo): lebih berat dan membawa permukaan WebView, tapi V8 adalah engine JS yang paling lengkap.

**Hasil spike P1, 15-16 Nov 2026 (mengikat):** (1) Parameter `timeout` di `QuickJsRuntime2` TIDAK BERFUNGSI: sisi Dart meneruskannya ke `jsNewRuntime`, tapi implementasi C hanya menerima channel dan tidak memasang interrupt handler sama sekali (tidak ada `JS_SetInterruptHandler` di `libfastdev_quickjs_runtime.cpp`; argumen timeout dibuang diam-diam oleh ABI C). Timeout 10 detik WAJIB ditegakkan di Dart: runtime hidup di isolate pekerja, bila satu solve melewati 10 detik isolate dimatikan paksa lalu dibuat ulang. Stack dan memori limit DITEGAKKAN native (nyata di C++). (2) Solver sig+n TERBUKTI BENAR di Node (validasi oracle pytubefix 11.2.1: signature dan n identik; byte audio asli terbukti: `audio/webm`, magic EBML). (3) QuickJS TIDAK BISA dites di `flutter test` host Linux (paket tidak membawa lib native Linux; Android membangun dari source `native/` via CMake) - wiring QuickJS diverifikasi lewat build CI + APK demo di perangkat owner. (4) Batas 1 MiB: dari VM, googlevideo membatasi tepat 1 MiB per URL lalu 403 (terbukti di URL segar WEB_REMIX dan MWEB; bukan anggaran per-URL, bukan single-use n). Penyebab (reputasi IP egress datacenter vs penegakan poToken) tidak bisa ditentukan dari VM - hanya uji perangkat owner yang bisa memutuskan. Bila batas ini juga berlaku di HP, pemutaran lagu penuh butuh re-resolve di tengah pemutaran (pekerjaan P2+).

### 3.5 Tabel player config remote dan deteksi kerusakan

**Tabel config remote (pola SimpMusic dan Metrolist faraday).** File `FaradayCipherEngine.kt` (298 baris) memecahkan signature dan n secara lokal memakai tabel player remote: player script YouTube tetap diunduh dan dieksekusi di QuickJS; tabel remote tidak berisi signature yang sudah di-decode, isinya adalah nama fungsi dan class di dalam player JS YouTube, plus signatureTimestamp (sts) untuk versi player itu. Yang dibeli tabel adalah langkah penebakan nama fungsi lewat regex, langkah yang rusak setiap kali YouTube mengacak obfuscation-nya. Dengan tabel, kerusakan itu diperbaiki dengan menerbitkan entri baru, bukan dengan merilis app baru. Ada dua sumber tabel: tabel SimpMusic sendiri dulu, lalu tabel Metrolist untuk hash yang belum diterbitkan. File `RemotePlayerConfigStore.kt` (424 baris): refresh normal dengan TTL 6 jam; refresh yang dipicu kegagalan untuk hash player tak dikenal dan penolakan CDN, dengan single-flight dan rate limit; timeout request 5 detik; maksimal ukuran respons config 4 MB. URL config legacy: `https://github.com/MetrolistGroup/faraday/releases/download/{playerTag}/{playerHash}.json`.

Repo MetrolistGroup/faraday sendiri terverifikasi koordinator dari halaman GitHub live: deskripsi "Remote YouTube player configuration registry", 4 bintang, 528 rilis, tidak diarsipkan, README menyatakan "Faraday watches YouTube `player.js` rotations, derives cipher configs (`sig`, `nClass`, `sts`, `aliases`), validates them against real CDN streams, and updates the registry automatically." Dipakai Metrolist, Metrolist KMP (WIP), dan InnerTubeX. Ini membuktikan pola tabel config remote adalah praktik hidup, bukan ide di atas kertas.

Isi tabel konfigurasi yang diusulkan untuk app ini: daftar client aktif dan urutannya beserta versi tiap client; pemetaan hash player ke nama fungsi decipher, nama class transform n, dan signatureTimestamp; ambang deteksi kerusakan dan TTL cache; nomor versi skema config, agar app lama menolak config yang tidak dikenalnya. Aturan yang mengikat: config adalah data, bukan kode; app tidak pernah mengeksekusi JavaScript dari tabel config (yang dieksekusi di QuickJS hanyalah script player YouTube itu sendiri); config diambil lewat HTTPS dari host yang di-pin (GitHub Releases repo sendiri, mengikuti pola faraday); validasi skema sebelum dipakai; bila host mati atau config rusak, app memakai cache terakhir yang valid; refresh normal TTL 6 jam, refresh dipicu kegagalan dengan single-flight dan rate limit; biaya Rp0 (tidak ada server). Yang belum terverifikasi: apakah F-Droid menerima app yang mengambil konfigurasi remote yang mengubah perilaku ekstraksi (wajib dicek saat pengajuan F-Droid, bukan diasumsikan; flag NonFreeNet sudah pasti menempel tapi bukan penolakan).

**Hasil spike P1, 16 Nov 2026 (implementasi nyata):** pre-release tag `config-v1` di repo `adiprmx/laras` (BUKAN tag `v*`, tidak memicu workflow rilis), berisi `player-config.json`: 2 client (WEB_REMIX 1.20261110.04.00, MWEB 2.20260708.05.00) + `playerHashes` (fad7e4e9 ke sts 20767) + 5 videoId kanari + TTL 21600 detik. Loader mencoba URL rilis dulu (`github.com/adiprmx/laras/releases/download/config-v1/player-config.json`), lalu URL cadangan dari tree tag (`raw.githubusercontent.com/adiprmx/laras/config-v1/player-config.json`). Cadangan ini ada karena upload aset rilis lewat API butuh `uploads.github.com` dengan auth, dan kredensial GitHub di lingkungan ini hanya berlaku untuk `api.github.com` (surrogate ditolak 401 di uploads.github.com, terbukti 16 Nov 2026) - aset rilis belum terunggah; koordinator bisa mengunggahnya lewat browser. Live test "fetch config remote nyata" LOLOS: loader mengambil config nyata dari tag. Commit config `5b2da5746cbebaae9543ac4004158a088f4edef2` (parent main HEAD; tidak ada di branch mana pun, hanya dijangkau lewat tag).

**Deteksi kerusakan lokal** (semua lokal, tanpa telemetri ke server mana pun): video kanari, daftar kecil video publik yang diketahui bisa diputar; app menguji resolve terhadap satu video kanari saat start dingin pertama hari itu, di latar, tanpa mengganggu pemutaran. Klasifikasi error: tiap kegagalan resolve dicatat dengan penyebabnya (HTTP 403, respons kosong, parse gagal, hanya format SABR, timeout solver, hash player tak dikenal). Ambang rusak (usulan desain, bukan data): bila tiga resolve kanari berturut-turut gagal dengan penyebab yang sama, atau bila lebih dari separuh resolve dalam satu jam gagal, app menandai dirinya rusak dan menampilkan pesan jujur di layar utama beserta tombol "periksa pembaruan konfigurasi". Angka ambang ini bisa diubah di konfigurasi remote.

**Hasil P6 (16 Nov 2026, Tim Ketahanan):** deteksi kanari dipasang penuh (paket baru `lib/resilience/`; nol dependensi baru — tautan email/browser dan status WiFi lewat MethodChannel, bukan url_launcher/connectivity_plus/package_info_plus). `ServiceStatusService` membungkus `CanaryChecker` + `RemoteConfigLoader`: cek sekali sehari di latar saat start dingin dan saat kembali dari background, status tersimpan di SharedPreferences dan dibaca UI lewat `ValueNotifier` (`ResilienceScope`). Ambang rusak persis desain: 3 cek gagal berurutan dengan penyebab dominan sama, atau >50% gagal dalam 1 jam dengan minimal 5 resolve; kegagalan jaringan diabaikan dan tidak memajukan waktu cek. Banner beranda 3 tingkat (ok = tanpa banner, degraded = tipis, broken = jelas + tombol "Periksa pembaruan"); tombol yang sama ada di Pengaturan dan kegagalan Jelajah, memaksa refresh config di luar TTL 6 jam lalu menjalankan ulang cek kanari. Deteksi perubahan config membandingkan sidik jari isi (client + hash player + videoId kanari), BUKAN `fetchedAt` — refresh selalu menulis `fetchedAt` baru walau isi sama, sehingga perbandingan `fetchedAt` membuat hasil "sudah terbaru" tidak pernah tercapai (bug ketahuan lewat tes, diperbaiki sebelum push). Keenam penyebab resolve dipetakan ke pesan bahasa sehari-hari tanpa jargon (`cause_messages.dart`); satu client gagal lalu fallback berhasil tidak terlihat pengguna. Varian satu baris per penyebab dipakai mini-player (`causeShortMessage`, <= 25 karakter) supaya jenis gagal TERLIHAT di mini-player, bukan hanya di layar pemutar penuh — pesan singkat lama selalu generik ("Tidak bisa diputar") walau penyebabnya diketahui. Tambahan P6 (verdict owner 18:56 WIB, tombol "Coba lagi" ditekan berkali-kali selalu gagal tanpa diketahui jenisnya): kode diagnostik singkat `LRS1-...` di dialog "Laporkan kerusakan" — merangkum kegagalan terakhir (jenis + penyebab + waktu + client yang dicoba + versi app/config + status kanari) dari data lokal saja (`lastError` snapshot player + `recentLog` per client yang sudah berisi penyebab terstruktur dari P0-2 + status kanari + `ServiceStatusService.currentConfigInfo()`), berfungsi offline, bisa disalin ke chat, dan ikut terkirim di badan email laporan; kode tidak berisi judul lagu, videoId, URL, IP, atau data pribadi apa pun (legenda format ada di doc header `diagnostic_code.dart`). Lagu tidak bisa diputar (dari `playabilityStatus`, BUKAN dari kegagalan jaringan) ditandai di kolom baru `songs.unplayable` (skema v3, migrasi v2→v3 teruji): tampil redup + label, dilewati otomatis di rantai pemutaran TANPA resolve (termasuk pramuat jendela — celah awal: pramuat memasukkan lagu bertanda ke jendela sehingga lewati-otomatis tidak jalan, diperbaiki di `_appendNext`), ketukan pengguna tetap mencoba resolve (satu-satunya jalan membersihkan tanda), status layanan broken memblokir penandaan (kerusakan massal), lagu terunduh tidak pernah ditandai. Layar Pengaturan nyata menggantikan stub: Hemat data, kualitas unduhan bawaan, batas ruang lagu yang pernah diputar (250 MB–2 GB), unduh WiFi saja (ditegakkan di DownloadService + StreamCacheService; hotspot HP terbaca sebagai WiFi oleh Android — batasan dicatat di FAQ, bukan disembunyikan), status layanan, Tentang, FAQ 12 pertanyaan, Laporkan kerusakan via email ke adiprmx@gmail.com (hanya 8 item diagnostik yang diizinkan PRD B11.4), Hapus semua data dua konfirmasi (tanpa tombol "Simpan salinan dulu" — itu P8). Lembar kejujuran satu kali (B11.5) diekspos sebagai komponen callable `showHonestySheet(context)` + flag `honesty_sheet_shown_v1` (fungsi menandai flag setelah lembar ditutup; orkestrasi first-run onboarding -> lembar -> beranda milik Tim Rombak UI-2, BUKAN auto-show dari beranda). Log internal maks 1 MB dengan rotasi potong-setengah-terlama, semua URL http(s) disensor. K6 dan K7 dibuktikan tes: client utama dihapus/dimatikan di config tiruan → 10/10 lagu tetap jalan tanpa error terlihat; TTL dimanipulasi → config baru dipakai setelah refresh latar. Yang belum bisa dibuktikan dari VM: MethodChannel Android (isWifi, openMail, openLink, deviceInfo — tanpa Android SDK lokal, verifikasi lewat CI + HP owner) dan unduh penuh (IP VM ditolak googlevideo 403 — lingkungan, bukan bug app).

**Pelajaran dari kompetitor:** InnerTune, kerusakan massal (issue #1792, dibuka 8 Jan 2025, masih open) tanpa perbaikan cepat membunuh app yang sebelumnya populer; pelajarannya, kecepatan respons lebih penting daripada kesempurnaan arsitektur. SimpMusic, tiga jalur ekstraksi sekaligus, QuickJS lokal, tabel config remote dengan refresh 6 jam dan refresh saat gagal, dua sumber tabel yang saling mencadangkan; arsitektur paling defensif di antara kompetitor, dan satu-satunya yang rilis rutin sampai November 2026. Spotube, extractor dipisah ke plugin dan modul sehingga perbaikan extractor tidak menyentuh UI. NewPipeExtractor, rilis v0.27.0 dan v0.27.1 selang tiga hari di awal November 2026; kecepatan seperti ini hanya mungkin karena library-nya fokus pada satu hal dan komunitasnya besar; tim kecil tidak bisa meniru kecepatan ini tanpa config remote. yt-dlp, rilis berkala dan komunitas besar membuatnya paling tahan terhadap perubahan; ini alasan ytdlp_flutter menjadi cadangan pertama.

**Yang tidak boleh dilakukan:** mengandalkan satu client; mengandalkan satu paket tanpa fork dan tanpa pemahaman isinya; mengabaikan SABR; menjadikan poToken satu-satunya jalan; menyimpan URL stream sebagai tautan permanen (URL kedaluwarsa, simpan videoId dan segarkan URL saat diputar).

### 3.6 Spike Fase 2 yang wajib lolos sebelum komitmen penuh

Jalur utama belum diputuskan final. Enam spike di bawah ini wajib lolos sebelum tim berkomitmen penuh. Tiap spike punya kriteria lolos yang bisa diuji, bukan perasaan.

1. Player request ke ANDROID_MUSIC dan WEB_REMIX mengembalikan adaptiveFormats dengan itag 251 dan 140 untuk lima video musik berbeda. Kriteria lolos: lima dari lima mengembalikan URL audio, atau kegagalan didokumentasikan dengan penyebabnya.
2. QuickJS (quickjs_engine) menjalankan n-transform dari `base.js` asli dan menghasilkan URL yang bisa diputar penuh. Kriteria lolos: satu lagu tiga menit diputar sampai habis tanpa HTTP 403.
3. Fallback antar client: matikan client utama di config, app otomatis pindah ke client berikut dan lagu tetap jalan tanpa error yang terlihat pengguna.
4. Tabel config remote: ubah entri versi client di GitHub Release, app mengambilnya dalam TTL dan memakai nilai baru tanpa install ulang.
5. SABR: panggil player dengan client WEB, catat format yang dikembalikan, dan buktikan app tidak memilih format SABR.
6. Ukur ukuran APK tambahan dari quickjs_engine dan waktu resolve rata-rata per lagu. Target desain: resolve di bawah 2 detik per lagu. Angka ini adalah target, bukan janji.

**Hasil spike P1, 15-16 Nov 2026 (laporan lengkap: `docs/spike-ekstraksi.md` di repo Laras; putusan: GO BERSYARAT):** Spike 1 PASS (WEB_REMIX live 5/5, MWEB 5/5; ANDROID_MUSIC gagal dengan penyebab terdokumentasi). Spike 2 PARTIAL (solver sig+n tervalidasi oracle + byte audio asli terbukti; unduh penuh mentok 1 MiB lalu 403 dari VM - penyebab hanya bisa diputuskan uji perangkat owner). Spike 3 PASS (tes fallback + log). Spike 4 PASS dengan catatan (pre-release `config-v1` + loader terbukti live; aset rilis belum terunggah, config dilayani dari tree tag). Spike 5 PASS (parser + pemilih itag menolak SABR; fixture ANDROID SABR-only asli). Spike 6 PARTIAL (waktu resolve median 4.049 ms dari VM, target <2.000 ms tidak tercapai dari VM - bottleneck jaringan egress, solver median 10,5 ms; ukuran APK menunggu CI pasca-push karena quickjs_engine sudah ada di pubspec sejak P0 sehingga tidak ada baseline selisih).

### 3.7 Jalur cadangan ekstraksi

1. **Cadangan pertama: ytdlp_flutter 0.1.0.** Bila InnerTube kustom macet di spike (misalnya solver QuickJS tidak bisa menjalankan n-transform, atau semua client memberi SABR saja). Keunggulan: yt-dlp asli dengan update berkala dari komunitas besar dan kemampuan update extractor tanpa rilis app di Android. Harga: ukuran APK tambah sekitar 30 MB per ABI dan ketergantungan GPL-3.0 lewat youtubedl-android. Paket ini berumur tiga bulan dan nol bintang, jadi spike-nya wajib membuktikan pemutaran audio nyata, bukan hanya info video.
2. **Cadangan kedua: NewPipeExtractor v0.27.1 lewat platform channel.** Bila jalur utama dan ytdlp_flutter sama-sama tidak memuaskan. NewPipeExtractor (TeamNewPipe, GPL-3.0, 2.063 bintang, push terakhir 11 Nov 2026; rilis v0.27.1 pada 10 Nov 2026, v0.27.0 pada 7 Nov 2026) adalah extractor paling teruji di antara semua kandidat. Cara pakai dari Flutter: dependensi Gradle di modul Android (`com.github.teamnewpipe:NewPipeExtractor` lewat JitPack Maven) lalu jembatan ke Dart lewat MethodChannel atau Pigeon, mengikuti pola plugin `extractor`. Harga: Android saja, GPL-3.0, update extractor selalu butuh rilis app, desugaring wajib untuk minSdk di bawah 33, ukuran APK tambahan belum diukur. Paket pub.dev `android_new_pipe_extractor` bukan jalan pintas (README masih template bawaan plugin).
3. **Jalan tengah: fork youtube_explode_dart 3.1.0 dengan solver QuickJS.** Ganti DenoEJSSolver dengan solver QuickJS memakai quickjs_engine, lewat antarmuka solver kustom yang sudah disediakan paket itu sejak 3.0.0. Menghemat pekerjaan parser dan HTTP client, dengan harga ketergantungan pada kode yang tidak dirawat aktif. Layak dipertimbangkan bila spike InnerTube kustom dari nol terlalu lambat.

**Referensi implementasi yang bisa dipelajari** (mempelajari perilaku adalah reverse engineering terhadap layanan YouTube, bukan penyalinan kode; bila kode GPL-3.0 disalin ke repo, seluruh app wajib GPL-3.0, yang selaras dengan rekomendasi tim C8): YouTube.js v18.3.0 (MIT, 23 Okt 2026) untuk client InnerTube lengkap dan parser YTM; yt-dlp (Unlicense) untuk solver signature/n, EJS, dan kebijakan POT; ytmusicapi 1.12.3 (MIT, 16 Sep 2026) untuk parsing search/browse YTM; pytubefix 11.2.1 untuk cipher, poToken, dan client; NewPipeExtractor v0.27.1 (GPL-3.0) untuk ekstraktor teruji dan solver Rhino; ytdl-core (dokumen 30 Okt 2026) untuk SABR, POT, dan solver.

**Komponen yang harus dibangun** (pemetaan dari arsitektur kompetitor dan implementasi referensi): 1. HTTP client InnerTube (POST JSON, header per client, timeout di semua request, retry dengan backoff untuk 429 dan 503). 2. Tabel definisi client yang bisa diperbarui tanpa rilis app. 3. Parser respons player (pemilihan itag audio 251, 140, 250, 249, 139; deteksi SABR). 4. Parser search dan browse YouTube Music (pekerjaan terbesar kedua karena struktur respons dalam dan berubah-ubah). 5. Solver signature dan n challenge (pekerjaan tersulit dan paling rapuh). 6. Tabel player config remote (penawar kerapuhan komponen 5). 7. Orkestrator fallback dengan klasifikasi kegagalan. 8. Cache stream URL (URL kedaluwarsa; simpan videoId, segarkan URL saat diputar).

## 4. Storage lokal

Sumber: laporan A5, `hidden_files/tim/storage-lokal.md`. Versi dan API dicek live 15 November 2026 dari docs setup resmi drift dan pub.dev.

### 4.1 Rekomendasi: drift 2.35.4

drift adalah ORM type-safe di atas SQLite: relasi SQL penuh, migrasi teruji otomatis lewat `drift_dev schema steps`, FTS5 untuk pencarian lokal, `NativeDatabase.createInBackground` untuk isolate latar, dan perawatan aktif. Versi yang terverifikasi persis di docs setup resmi drift: drift 2.35.4, drift_dev 2.35.3, drift_flutter 0.3.1, sqlite3 3.9.1, path_provider 2.1.6, build_runner 2.16.2. API `NativeDatabase.createInBackground`, `LazyDatabase`, `driftDatabase`, dan `schemaVersion` terkonfirmasi di docs yang sama. Lisensi drift adalah MIT, terverifikasi koordinator dari metadata repo simolus3/drift ("License: MIT License (MIT)", 3.302 bintang, 4.784 commit, tidak diarsipkan). Fallback: sqflite 2.4.4+2.

**Yang ditolak, dengan alasan:** isar asli (stabil terakhir 25 Apr 2023, tidak dirawat) dan hive asli (stabil terakhir Jun 2022, tidak dirawat); sembast 3.10.0 karena seluruh database dimuat ke memori saat dibuka (README verbatim "loaded in memory when opened", diperbarui 3 Nov 2026), pola yang sama dengan penyebab OOM Spotube; ObjectBox karena NoSQL plus Sync berbayar, bertabrakan dengan prinsip Rp0; Floor dan froom (ditolak, detail di laporan A5).

### 4.2 Skema v1: 15 tabel

Skema mengacu entitas Room InnerTune. Tabel: `songs`, `albums`, `artists`, `song_artists`, `album_artists`, `playlists`, `playlist_songs`, `formats`, `lyrics`, `play_events`, `search_history`, `queue_items`, `local_items`, `cache_entries`, `download_jobs`. Relasi lagu-artis dan lagu-album memakai tabel penghubung (banyak-ke-banyak); playlist memakai `playlist_songs` dengan urutan; antrean pemutaran adalah tabel `queue_items` (bukan state memori); riwayat putar adalah `play_events`; riwayat pencarian adalah `search_history`; manifest cache adalah tabel `cache_entries` (bukan file JSON); antrean unduhan adalah `download_jobs` sehingga tahan restart app. Indeks dibuat untuk kolom yang sering dipakai di klausa WHERE, JOIN, dan ORDER BY. Detail kolom dan indeks lengkap ada di laporan A5 bagian 4; definisi DDL final ditulis di Fase 2 bersama migrasi teruji `drift_dev schema steps`.

**File unduhan dihubungkan lewat `download_state` + `file_path` relatif di tabel songs** (pola SimpMusic, diperkuat `file_size_bytes` + rekonsiliasi saat start app). File hilang atau rusak menurunkan state ke 0 tanpa menghapus lagu dari library.

**Hasil P3 (16 Nov 2026, Tim Database dan Library):** skema v1 diimplementasikan penuh — 15 tabel persis desain A5 ditambah 1 tabel virtual FTS5 `library_search` (bukan tabel ke-16; virtual, berisi judul lagu + nama artis). File: `lib/data/` (`tables.dart`, `laras_database.dart`, `library_service.dart`, `play_history_recorder.dart`, `track_songs.dart`, `database_connection.dart`, `library_scope.dart`), codegen `lib/data/laras_database.g.dart` (6.425 baris), `drift_schemas/drift_schema_v1.json`, `test/generated_migrations.dart`, 61 tes data + tes widget library. Penyimpangan dari A5, dengan alasan: (1) `playlists.description` ditambahkan (kolom nullable TEXT; PRD B4.1 menetapkan deskripsi playlist maks 500 karakter, A5 tidak punya kolomnya); (2) `liked`/`in_library` memakai `boolean()` drift (penyimpanan sama, INTEGER 0/1 + CHECK, tapi type-safe di Dart); (3) aksi FK ditulis eksplisit karena A5 diam: CASCADE untuk `playlist_songs`, `song_artists`, `album_artists`, `play_events`, `formats`, `lyrics`, `download_jobs`, `queue_items`; SET NULL untuk `songs.album_id` dan `songs.format_id`. Tiga fakta implementasi yang wajib diketahui tim berikutnya: drift menyimpan DateTime sebagai detik Unix, BUKAN milidetik (terverifikasi dari source drift `mapping.dart:77,182`) — semua pengurutan berbasis waktu memakai tiebreak deterministik (id/rowid); modul FTS5 wajib didaftarkan di `build.yaml` sebagai `sql.options.modules: [fts5]` (bentuk `sqlite.modules` ditolak drift bila opsi `sql` juga ada); `generate_manager: false` di `build.yaml` (service memakai API select/insert klasik, menghemat ~5.500 baris codegen — relevan dengan sisa ruang APK ~2,4 MB). Mesin pencarian lokal (FTS5 + riwayat pencarian) jadi dan teruji; UI layar Cari ditunda ke P4 bersama pencarian online (permukaan demo menampilkan "Segera hadir" per K-F2-07/08). Antrean: tabel + service jadi, restore otomatis belum (butuh kolom posisi, kerja P7). Artis yang hanya dikenal namanya memakai pseudo-id `local-<FNV-1a nama>`; P4 menggabungkannya ke channelId YTM bila tersedia. Kinerja terukur di VM (database in-memory, 3 run): insert 1.000 lagu 8.428–11.525 ms; query halaman pertama (50 lagu) 31–101 ms; pencarian FTS5 29–71 ms.

**Hasil P6 (16 Nov 2026, Tim Ketahanan) — skema v3:** kolom `songs.unplayable` (boolean, bawaan false) + indeks `songs_unplayable_idx` untuk penandaan lagu tidak bisa diputar (B4.7). Migrasi v2→v3 teruji (termasuk lompat langsung v1→v3); blok `onUpgrade` memakai penjaga `from < N && to >= N` supaya blok v3 tidak jalan saat migrasi v1→v2. `SongsCompanion.unplayable` bawaan `Value.absent()`, jadi insert ke database v2 tidak menyentuh kolom baru.

### 4.3 File unduhan

Lokasi default: app-specific external storage (`getExternalStorageDirectory()`), tanpa izin tambahan, di bawah scoped storage. Nama file `<videoId>.<ekstensi>` (ID konten sebagai nama file, bukan judul lagu, sekaligus mencegah path traversal lewat metadata; lihat skenario S6 di bagian 6). Tulis tag metadata ke file (audiotags atau flutter_taglib, diputuskan setelah uji Fase 2). Unduhan ditulis ke file `.part` lalu di-rename setelah selesai, agar file setengah jadi tidak pernah dianggap utuh.

### 4.4 Cache: streaming dan unduhan dipisah total

Mengikuti InnerTune (dua SimpleCache terpisah: `@PlayerCache` dan `@DownloadCache`). Cache streaming di `getTemporaryDirectory()`, default 500 MB, LRU lewat manifest tabel `cache_entries`, dihitung dari database bukan pemindaian filesystem. `LockCachingAudioSource` just_audio masih eksperimental, jadi v1 memakai cache manual (file `.part` lalu rename). Unduhan permanen tidak pernah dihapus otomatis oleh eviction cache. Hitungan batas cache dan pengaturan pengguna ada di bagian 5.2.

### 4.5 Backup dan ekspor

Format utama: JSON berversi. Salinan file SQLite sebagai opsi lanjutan. Impor wajib mendukung semua versi backup lama selamanya, impor dalam satu transaksi, dan merge bukan timpa buta (pelajaran OuterTune 0.11.x vs 0.10.x, di mana format backup yang berubah memutus kompatibilitas). Bila suatu saat ada kebutuhan membaca file backup besar, pakai streaming parser, bukan `readAsString` lalu `jsonDecode` sekaligus.

### 4.6 Sembilan aturan anti-OOM (pelajaran Spotube)

Fakta dasar (terverifikasi tim A2 Paket 1 dari source live): Spotube memakai tujuh DataStore Preferences store yang menyimpan JSON. DataStore membaca seluruh file preferences ke heap saat dibuka. Build awal menyimpan cover full-size sebagai array angka JSON sampai ratusan MB dan crash dengan OutOfMemoryError (issue #3193). Perbaikannya adalah `dropIfOversized` yang membuang store antrean dan media lokal bila ukurannya melewati 8 MB.

1. Key-value store (`shared_preferences`) hanya untuk nilai primitif kecil: boolean, angka, string pendek. Batas keras: tidak ada satu nilai pun yang melebihi 1 KB, dan total seluruh preferences tidak melebihi 100 KB. Daftar objek, antrean, riwayat, dan cache tidak pernah masuk ke sini.
2. Semua koleksi masuk ke drift (SQLite). Antrean adalah tabel `queue_items`, riwayat adalah tabel `play_events`, pencarian adalah tabel `search_history`. SQLite membaca per baris lewat query berindeks, tidak pernah memuat seluruh tabel ke memori.
3. Gambar tidak pernah disimpan sebagai data di database atau di key-value store. Thumbnail disimpan sebagai file, database hanya menyimpan URL atau path. Cover art di file audio disematkan sebagai tag, bukan sebagai blob database.
4. Semua query daftar memakai LIMIT dan pagination. Tidak ada query yang memuat seluruh tabel lagu ke memori. Standar halaman adalah 50 item (keputusan koordinator, bagian 7; laporan A5 menyebut 100 baris per halaman untuk daftar lagu dan 50 entri untuk riwayat). Stream drift (`watch`) dipakai dengan LIMIT yang sama.
5. Tidak ada JSON blob besar di kolom database. Kolom JSON hanya untuk struktur kecil yang tidak perlu di-query (misal pengaturan per-playlist), dibatasi 4 KB per baris. Bila datanya perlu di-query atau bisa tumbuh, buat tabel sendiri.
6. Cache manifest adalah tabel database (`cache_entries`), bukan file JSON. File JSON manifest akan tumbuh tanpa batas dan harus dibaca penuh setiap kali dibuka.
7. Batas ukuran di semua koleksi yang tumbuh otomatis, ditegakkan oleh kode: riwayat putar dibatasi 10.000 entri (hapus yang tertua saat melewati batas), riwayat pencarian dibatasi 100 query, log internal dibatasi 1 MB dengan rotasi.
8. Pengujian regresi: uji otomatis yang mengisi database dengan 10.000 lagu, 1.000 entri riwayat, dan antrean 500 lagu, lalu mengukur memori saat membuka library. Uji ini gagal bila pemakaian memori melewati ambang yang ditetapkan tim (ambang persis diputuskan di Fase 2 setelah pengukuran pertama di perangkat nyata, bukan ditebak di sini).
9. Jangan meniru pola "baca seluruh file lalu parse" untuk data apa pun yang bisa tumbuh.

## 5. Performa dan caching

Sumber: laporan A13, `hidden_files/tim/performa-cache.md`. Angka di bagian ini adalah target desain atau hitungan eksak dari asumsi yang dinyatakan jelas, bukan hasil ukur; hasil ukur wajib menggantikannya sejak build pertama di Fase 2.

### 5.1 Anggaran ukuran APK

Target v1: maks 25 MB per ABI (arm64), regang 20 MB. InnerTune 6,5 MiB tidak bisa dicapai Flutter karena engine saja 4-8 MB per ABI (tiga sumber 2026 sepakat). Baseline resmi terakhir: app minimal Maret 2021 4,3 MB ARM32 / 4,8 MB ARM64; hello world 2026 sekitar 8-10 MB. FAQ resmi Flutter saat ini tidak memberi angka ("The engine adds a small baseline footprint (a few megabytes compressed), which varies by target platform and architecture."), jadi dokumen ini tidak menyajikan satu angka pasti untuk ukuran akhir app. Cara mencapai target: split per ABI wajib, R8, tanpa aset berat, tanpa FFmpeg, audit `--analyze-size` tiap rilis, ukur sejak build release pertama dan catat breakdown-nya. Biaya ukuran yang terverifikasi per kandidat: mpv_audio_kit menambah 7,7-8,3 MB per ABI; ytdlp_flutter/extractor menambah sekitar 30 MB per ABI (keduanya bukan jalur v1); kontribusi ukuran dependensi Media3 ExoPlayer pada APK just_audio tidak terverifikasi; ukuran native libs media_kit per ABI tidak terverifikasi; ukuran APK tambahan dari quickjs_engine dan NewPipeExtractor tidak terverifikasi (spike Fase 2 wajib mengukurnya).

### 5.2 Cache dua lapis

**Lapisan 1: cache streaming (sementara).** LRU, default 500 MB, terpisah dari unduhan. Hitungan batas (asumsi dinyatakan eksplisit): Opus 160 kbps x 210 detik = 4,2 MB per lagu, jadi 500 MB muat sekitar 119 lagu atau sekitar 7 jam musik. Asumsi durasi 210 detik dan bitrate 160 kbps: bitrate selaras dengan itag 251 (sampai sekitar 160 kbps, bagian 3.2); durasi 210 detik adalah asumsi tim yang dinyatakan terbuka. Pengguna mengatur 250 MB / 500 MB / 1 GB / 2 GB. Eviction LRU lewat manifest tabel `cache_entries`.

**Lapisan 2: unduhan permanen.** Tidak pernah dihapus otomatis oleh eviction cache. Hanya pengguna yang menghapus, satu per satu atau per playlist.

### 5.3 Cache gambar sampul

Paket: `cached_network_image_ce` (MIT, halaman diperbarui 31 Okt 2026). Alasan penentu: timeout bawaan lewat `ConnectionParameters` (aturan proyek mewajibkan timeout di semua fetch), metadata Hive CE, LRU cleanup. Klaim fork bahwa "paket asli tidak dirawat sejak Agt 2024" tampak kedaluwarsa: paket asli merilis 4.0.5 pada 21 Okt 2026 dan 4.0.7 terkonfirmasi 13-15 Nov 2026. Angka versi pasti `_ce` tidak terverifikasi (4.6.2 pada 4 Mar 2026 per feed; halaman diperbarui 31 Okt 2026). Batas disk 200 MB. Decode dibatasi: thumbnail 200 px, now-playing 512 px. ImageCache global diturunkan ke 200 gambar / 50 MiB dari default 1000 gambar / 100 MiB. Paket asli `cached_network_image` 4.0.7 dicatat sebagai cadangan. Ukuran file thumbnail YTM nyata belum diukur (asumsi 100 KB perlu diukur di Fase 2).

### 5.4 Performa UI: daftar ribuan lagu tanpa jank

`ListView.builder` + `itemExtent`; pagination drift 50 item per halaman dengan keyset pagination; FTS5 untuk pencarian lokal; debounce 300 ms pada input pencarian; tunda muat gambar saat fling; pre-cache 10 item berikutnya. Antrean di memori dibatasi maks 200 item metadata. Daftar besar selalu memakai streaming dan pagination; tidak ada daftar yang memuat seluruh library ke memori. Disiplin dispose di semua controller dan subscription; drift berjalan di background isolate.

### 5.5 Cold start dan pemutaran pertama

Target (target desain, bukan hasil ukur): TTID 1,5 detik, TTFD 2,5 detik, pemutaran pertama 2 detik (koneksi baik) di perangkat kelas menengah. Ambang vitals Android: cold 5 detik, warm 2 detik, hot 1,5 detik dianggap berlebihan. Cara ukur: `--trace-startup`, `adb am start -W`, DevTools, FrameTiming, protokol 5x ukur lalu buang min/max. Uji stress: 10.000 lagu di RAM 3 GB.

### 5.6 Ketahanan jaringan: timeout, retry, offline-first

Timeout: connect 10 detik / receive 15 detik untuk API JSON; 30 detik untuk stream dan gambar; inactivity timeout untuk unduhan. Retry maks 3x, backoff 1 detik / 2 detik + jitter, hanya untuk error jaringan, 5xx, dan 429. Resume unduhan via header `Range`. Retry berlaku untuk POST youtubei MAUPUN GET teks (HTML youtube.com dan base.js): load script ada di jalur kritis resolve pertama (untuk sts), jadi satu timeout koneksi tidak boleh membunuh resolve (hasil spike P1, 16 Nov 2026).

Perilaku offline-first (library, pencarian lokal, playlist, antrean, dan unduhan tetap jalan tanpa internet):

| Fungsi | Tanpa internet | Keterangan |
|---|---|---|
| Putar lagu yang diunduh | Jalan | File lokal, tanpa jaringan sama sekali |
| Putar lagu dari cache streaming | Jalan | Selama file cache masih ada dan URL belum perlu divalidasi ulang |
| Browsing library lokal | Jalan | Semua data dari drift |
| Pencarian di library lokal | Jalan | FTS5 lokal |
| Playlist, favorit, riwayat | Jalan | Semua lokal |
| Antrean pemutaran | Jalan | Antrean disimpan lokal |
| Pengaturan | Jalan | Semua lokal |
| Pencarian YouTube Music baru | Tidak jalan | Tampilkan pesan jelas + tombol coba lagi |
| Streaming lagu yang belum di-cache | Tidak jalan | Tampilkan pesan jelas |
| Ambil metadata/sampul baru | Tidak jalan | Tampilkan placeholder, metadata lama tetap tampil |
| Unduh lagu baru | Tidak jalan | Masuk antrean unduhan, jalan otomatis saat online |

Aturan tambahan: jangan blokir UI menunggu jaringan (layar library tampil dari database lokal dulu; data jaringan memperbarui tampilan belakangan; tidak ada layar yang menampilkan loading penuh hanya karena jaringan lambat). App mendengarkan perubahan status koneksi dan menampilkan indikator offline yang jelas, bukan error misterius (paket pendeteksi konektivitas belum diverifikasi di riset ini; kandidat umum adalah `connectivity_plus`, tetapi versi dan statusnya belum dicek). Antrean unduhan tahan restart karena daftar unduhan yang tertunda disimpan di drift, bukan di memori.

## 6. Keamanan

Sumber: laporan A6, `hidden_files/tim/rencana-keamanan.md`. Rencana ini berlaku sejak Fase 2; Fase 1 hanya menulis rencananya.

### 6.1 Lima keputusan utama

**1. Login YouTube Music DITUNDA dari v1.** Login menaruh cookie sesi akun Google di perangkat, aset bernilai tertinggi di threat model (setara akses akun Google). Tanpa login, tidak ada kredensial di perangkat sama sekali. Spesifikasi penyimpanan login tetap ditulis lengkap untuk rilis berikutnya: flutter_secure_storage 11.2.0 (RSA OAEP + AES-GCM default, `AndroidOptions`, `biometric()`, min SDK 23; terkonfirmasi dari 4 halaman pub.dev independen) di atas Android Keystore sebagai fondasi. Token dan cookie hanya di flutter_secure_storage, tidak pernah di SharedPreferences, file, atau database.

**2. Enkripsi database TIDAK wajib di v1.** Sandbox UID + enkripsi file API 29+ + scoped storage + `allowBackup="false"` sudah cukup untuk database tanpa login. Tiga pemicu eksplisit yang membuatnya wajib nanti: login masuk; owner menilai profil selera sensitif; regulasi mewajibkan. Biaya terverifikasi bila nanti dipakai: overhead 5-15% (Zetetic), 0-3% ruang ekstra (pengukuran Galaxy A55, Okt 2026), dan jebakan konfigurasi PBKDF2 685 ms vs 5 ms bila memakai raw key Keystore (kunci enkripsi database wajib berupa raw key acak dari Keystore, bukan passphrase). drift merekomendasikan SQLite3MultipleCiphers, bukan `sqlcipher_flutter_libs` (stale sejak Mar 2025).

**3. JANGAN certificate pinning ke YouTube/Google.** Pinning hanya aman untuk endpoint yang dikendalikan tim. Google merotasi kunci tanpa pemberitahuan dan F-Droid bisa tertinggal berminggu-minggu dari GitHub, jadi pin kedaluwarsa berarti app mati total. Gantinya: TLS ketat, cleartext mati, validasi respons. Pengecualian yang selaras dengan prinsip ini: pinning ke host config remote milik sendiri (GitHub Releases repo app) diizinkan, karena host itu dikendalikan tim (keputusan koordinator, bagian 7).

**4. Jalur QuickJS dibatasi ketat.** Preferensi awal A6 adalah porting logika decipher ke Dart murni; keputusan koordinator (bagian 7) menetapkan QuickJS sebagai jalur utama karena player JS ter-obfuscate dan berubah tiap rilis, sehingga porting manual tidak realistis sebagai fondasi. Pagar yang tetap berlaku: isolate/thread terpisah dengan stack besar, batas memori 192 MiB dan stack 8 MiB dan timeout 10 detik mengikuti angka SimpMusic yang terbukti (bagian 3.4), tanpa callback host, validasi output, hash player dicocokkan, eksekusi serial. Bukti nyata risikonya: 11 November 2026, peneliti mendemonstrasikan sandbox escape dan eksekusi kode lewat bug use-after-free di QuickJS-NG pada widget bot Telegram, dan Telegram merilis perbaikan darurat keesokan harinya. Nuansa verifikasi (koordinator): sumber Korvalis menyatakan kaitan quickjs-ng issue #1910 dengan fix Telegram BELUM terkonfirmasi, dan tanggal pasti fix/rollout ambigu (10/11 Nov fix, 11/12 Nov rollout). Sajikan insiden sebagai terkonfirmasi, kaitan #1910 sebagai belum terkonfirmasi.

**5. Siklus Red, Blue, Red memakai OWASP MASVS v2.1.0 (8 kategori, 24 kontrol) + MASTG v2.0.0.** Ronde terikat milestone: Red 1 setelah cari/streaming jalan, Red 2 setelah download/QuickJS, Red 3 di release candidate. Berhenti di nol temuan kritis/tinggi/sedang, maks 5 ronde. Ini adalah siklus keamanan dari struktur 45 tim owner, berlaku mulai ada kode (Fase 2).

### 6.2 Threat model ringkas

Aset (nilai tanpa login): cookie/token sesi YTM, tidak ada di v1 (nilai tinggi bila login ada); database lokal berisi playlist, riwayat dengar, riwayat cari, metadata unduhan (sedang, profil selera dan kebiasaan dengar); file audio unduhan dan cache (rendah, konten publik yang bisa diunduh ulang); pengaturan app dan state pemutar (rendah); signing key rilis dan kredensial GitHub (tinggi, di luar perangkat pengguna, di tangan owner; kebocorannya merusak semua pengguna sekaligus lewat APK palsu yang terlihat sebagai update resmi); artefak rilis di GitHub/F-Droid (tinggi, target pemalsuan dan repackaging).

Penyerang yang dimodelkan: penyerang jaringan (WiFi publik, ISP nakal, hotspot palsu); app lain di perangkat yang sama (UID berbeda; di perangkat root bisa membaca data app mana pun); pencuri perangkat; pembuat APK palsu (repackager); penyerang supply chain (akun maintainer paket pub.dev diretas, paket typosquat); Google/YouTube sebagai pengendali server (ancaman pemutusan layanan dan risiko akun, sudah dibahas tim C8 di riset kompetitor); penyedia pihak ketiga seperti lirik dan metadata (melihat IP dan judul lagu). Yang TIDAK masuk threat model: penyerang dengan akses root penuh dan waktu tak terbatas di perangkat korban (tidak ada pertahanan client-side yang menang melawan root), dan serangan terhadap infrastruktur Google sendiri.

Skenario serangan yang realistis, diurutkan dari yang paling mungkin: S1 token bocor lewat backup atau file polos (alasan utama login ditunda); S2 data sensitif bocor lewat log (larangan total logging data sensitif); S3 APK palsu hasil repackaging (pertahanan di sisi distribusi: signing key aman, checksum rilis dipublikasikan, pengguna diarahkan ke GitHub/F-Droid resmi, README memperingatkan soal APK palsu); S4 MITM lewat CA yang dipasang pengguna (Network Security Config tidak mempercayai user CA di build rilis); S5 respons InnerTube jahat atau rusak (parsing defensif dengan validasi tipe dan batas ukuran, timeout di semua request, tanpa `eval` di luar jalur QuickJS yang dibatasi); S6 path traversal lewat metadata (sanitasi nama file; nama file memakai ID video, judul asli disimpan di database); S7 dependensi jahat atau rentan (kurasi dependensi, lockfile di-commit, audit berkala); S8 pencurian sesi lewat WebView login (skenario ini hilang bila login ditunda); S9 eksploitasi mesin QuickJS (lihat keputusan 4 di atas); S10 abuse kuota dan rate limit (retry dengan exponential backoff dan jitter, batasi request bersamaan, hormati respons 429).

### 6.3 Izin Android minimal v1 (7 buah)

`INTERNET`, `FOREGROUND_SERVICE`, `FOREGROUND_SERVICE_MEDIA_PLAYBACK`, `FOREGROUND_SERVICE_DATA_SYNC`, `WAKE_LOCK`, `POST_NOTIFICATIONS`, dan `READ_MEDIA_AUDIO` hanya bila pemutar lokal masuk v1. Izin baru butuh alasan tertulis dan persetujuan tim keamanan. Semua Activity, Service, dan Receiver yang tidak perlu diakses app lain memakai `android:exported="false"`. `android:allowBackup="false"`. `android:usesCleartextTraffic="false"` dan Network Security Config tanpa trust ke user CA di build rilis, dengan pengecualian localhost untuk proxy just_audio yang diatur eksplisit (bagian 2.1).

### 6.4 Checklist secure coding Flutter (24 item, wajib di Fase 2)

Pelanggaran checklist adalah temuan di tiap ronde Red (severity ditentukan tim Red berdasarkan dampaknya).

Penyimpanan dan kripto: 1. Token dan cookie hanya di flutter_secure_storage. 2. Tidak ada secret yang di-hardcode di source, asset, atau file konfigurasi yang masuk repo; secret build hanya di CI secrets dan penyimpanan rahasia owner. 3. Tidak menulis implementasi kripto sendiri; pakai library standar (bila butuh hash, SHA-256 dari `package:crypto` atau `dart:convert`; bila butuh random, `Random.secure()`). 4. Kunci enkripsi database (bila dipakai) berupa raw key acak dari Keystore, bukan passphrase.

Jaringan: 5. Semua request memakai HTTPS; tidak ada `http://` di kode, konfigurasi, atau asset. 6. Semua request punya timeout eksplisit (connect, receive, send); tidak ada instance Dio atau HttpClient baru di luar composition root. Dio 5.10.0 terverifikasi: nilai timeout `null` berarti tanpa batas, jadi wajib diisi eksplisit. 7. Semua respons JSON divalidasi tipe dan nullability-nya sebelum dipakai. 8. Batas ukuran respons dan batas jumlah item diterapkan di lapisan parsing. 9. Retry maksimal 3 kali dengan backoff dan jitter; tidak ada retry tanpa batas. 10. URL stream divalidasi skema dan host-nya sebelum diputar.

Input dan file: 11. Nama file dari metadata selalu disanitasi atau diganti ID konten. 12. Deep link dan intent yang diterima app divalidasi sebelum diproses. 13. Tidak ada `eval`, `Function()`, atau eksekusi kode dinamis dari data jaringan di luar jalur QuickJS yang dibatasi.

Logging dan error: 14. Tidak ada logging data sensitif: cookie, token, URL stream lengkap, isi respons InnerTube mentah, path file internal, atau isi database; log interceptor HTTP wajib menutupi header `Authorization` dan `Cookie`. 15. Pesan error ke pengguna memakai bahasa yang bisa dipahami dan tidak menampilkan stack trace, URL internal, atau detail teknis.

Platform Android: 16. Manifest menyatakan izin minimal sesuai bagian 6.3. 17. Semua komponen yang tidak perlu diakses app lain memakai `android:exported="false"`. 18. `android:allowBackup="false"`. 19. `android:usesCleartextTraffic="false"` dan Network Security Config tanpa trust ke user CA di build rilis.

Build dan dependensi: 20. Dependensi baru melewati checklist kurasi A6 bagian 5.1 dan dicatat di `docs/dependencies.md`. 21. `pubspec.lock` di-commit; tidak ada dependensi `any` atau git tanpa commit hash yang dipin. 22. Build rilis memakai code shrinking dan obfuscation Flutter (`--obfuscate` dan `--split-debug-info`); obfuscation memperlambat reverse engineering, bukan menghentikannya, dan tidak boleh dijadikan pengganti kontrol lain; simpan file mapping debug-info di luar repo.

Pengujian: 23. Setiap perbaikan temuan Red disertai tes regresi yang gagal sebelum perbaikan dan lolos sesudahnya. 24. Sebelum rilis, jalankan `flutter analyze` tanpa warning, dan jalankan pemindai kerentanan dependensi yang tersedia di toolchain Dart/Flutter saat itu (nama perintahnya wajib dicatat; perintah audit pub belum terverifikasi di ronde riset ini).

### 6.5 Supply chain dan rilis

Dependensi baru melewati checklist kurasi (bagian 5.1 laporan A6) dan dicatat di `docs/dependencies.md`. Larangan dependensi proprietary untuk build F-Droid (bagian 5.2 laporan A6): toolchain 100% FLOSS, tanpa tracker proprietary; binary prebuilt Flutter SDK diizinkan oleh kebijakan F-Droid. Signing key rilis hanya di CI secrets dan penyimpanan rahasia owner; checksum rilis dipublikasikan; reproducible build Flutter di F-Droid belum terverifikasi (bagian 9).

## 7. Keputusan koordinator atas selisih antar tim

Selisih yang ditemukan saat menggabungkan lima laporan, dan keputusan koordinator atas masing-masing. Keputusan ini mengikat dokumen ini; bila bukti baru muncul di Fase 2, keputusan dibuka ulang dengan bukti, bukan dengan pendapat.

1. **minSdk: API 26 (Android 8.0), dengan API 24 sebagai fallback yang sah.** Tim A2 audio merekomendasikan API 24 (lantai ExoPlayer API 23, syarat mpv_audio_kit 24, selaras InnerTune; tidak ada alasan teknis dari sisi library audio yang memaksa API 26). Analisis arsitektur kompetitor Paket 1 merekomendasikan API 26 (selaras SimpMusic dan OuterTune 0.11.1). Koordinator memutuskan API 26: selaras dengan dua kompetitor yang masih dirawat, notification channels native di API 26+ (audio_service memakai notification channel; di bawah API 26 channel tidak ada dan perilaku notifikasi berbeda), dan semua library audio dan extractor bekerja di API 26 (lantai teknis terendah adalah API 23-24, jadi API 26 tidak menutup satu pun jalur yang dipilih). API 24 tetap fallback yang sah bila owner menginginkan jangkauan perangkat maksimal; tidak ada blocker teknis dari sisi library audio untuk API 24. Koreksi atribusi: rekomendasi API 26 berasal dari tim arsitektur kompetitor Paket 1, bukan dari C8 seperti ditulis laporan A2 audio. Konteks tambahan: mulai Android 15, perangkat memblokir instalasi aplikasi dengan targetSdk di bawah 24, terlepas dari sumber instalasi; itu aturan targetSdk, bukan minSdk, tetapi targetSdk app wajib 24 atau lebih agar bisa diinstal di perangkat Android 15, 16, dan 17.
2. **Batas QuickJS: angka SimpMusic (memori 192 MiB, stack 8 MiB, timeout 10 detik, eksekusi serial).** Tim A6 mengusulkan memori 16 MB dan waktu 5 detik. Tim A4 membuktikan dari source SimpMusic bahwa membangun AST `base.js` (sekitar 2,6 MiB) butuh lebih dari 128 MiB, dan limit produksi SimpMusic adalah 192 MiB + stack 8 MiB + timeout 10 detik. Batas 16 MB akan memecahkan solver. Diputuskan: pakai angka SimpMusic sebagai batas operasi, dengan pagar keamanan A6 yang tetap berlaku (isolate/thread terpisah, tanpa callback host, validasi output, hash player dicocokkan, eksekusi serial). Preferensi A6 untuk porting logika decipher ke Dart murni ditolak sebagai jalur utama, karena player JS ter-obfuscate dan berubah tiap rilis; menjalankan script player asli di QuickJS adalah jalur yang terbukti di produksi.
3. **Pinning host config remote milik sendiri diizinkan.** Larangan pinning A6 berlaku untuk endpoint yang TIDAK dikendalikan tim (Google/YouTube). Host config remote adalah GitHub Releases repo app sendiri, yang dikendalikan tim, jadi pinning di sana diizinkan dan dianjurkan. Kedua aturan selaras; tidak ada konflik setelah dibedakan.
4. **Versi audio_service 0.18.19 dan audio_session 0.2.4 (A2) menggantikan 0.18.18 dan 0.2.2 (A13).** Angka A2 lebih baru dan disertai stempel `Updated` pub.dev yang cocok persis (audio_session 29 Jun 2026 13:10:31 UTC, terverifikasi koordinator).
5. **just_audio 0.10.6 terkonfirmasi** oleh riset A2 yang didedikasikan (menutup catatan gabung sebelumnya).
6. **dio 5.11.1 sebagai versi terbaru (A13, 4 Sep 2026), API timeout terverifikasi di 5.10.0 (A6).** Kedua klaim dipakai bersama: versi terbaru 5.11.1, perilaku API terverifikasi di 5.10.0.
7. **drift_dev 2.35.3 (A5, dari docs setup resmi drift) dipakai sebagai versi terbaru**, menggantikan 2.35.2 (A13, dari changelog 7 Okt 2026). Cek ulang saat Fase 2 dimulai.
8. **flutter_cache_manager: selisih 3.5.0 (A5) vs 3.4.7 (A13) ditandai cek ulang Fase 2.** Hanya relevan bila memakai cached_network_image asli, bukan `_ce` (yang memakai Hive CE).
9. **Pagination standar 50 item per halaman (A13, keyset pagination).** Laporan A5 menyebut 100 baris per halaman untuk daftar lagu dan 50 entri untuk riwayat. Diputuskan 50 sebagai standar untuk semua daftar (konservatif, selaras desain A13); 100 hanya bila pengukuran di perangkat RAM 3 GB membuktikan aman.
10. **Lisensi drift MIT terverifikasi koordinator** dari metadata repo simolus3/drift; status "belum terverifikasi" di laporan A13 untuk lisensi drift tidak berlaku lagi.
11. **Klaim audio_service memakai MediaBrowserServiceCompat disajikan sebagai "sangat terindikasi, belum dibaca dari source".** Buktinya DeepWiki (ringkasan AI, sekunder) + pola manifest README. Deprecation androidx.media-nya sendiri terkonfirmasi dari Google (bagian 2.2).
12. **Insiden QuickJS Telegram 11 Nov 2026 disajikan sebagai terkonfirmasi, kaitan quickjs-ng issue #1910 sebagai belum terkonfirmasi**, dengan tanggal fix/rollout yang ambigu (bagian 6.1).
13. **Angka SimpMusic QuickJS, rilis NewPipeExtractor v0.27.1, dan detail darttubefix/ytdlp_flutter/itag/SABR adalah hasil baca tim A4 dari sumber live** (GitHub API + pub.dev). Koordinator memverifikasi titik-titik penopangnya (faraday, quickjs_engine, youtube_explode_dart, NewPipeExtractor) dan spike Fase 2 dirancang untuk membuktikan angka-angka yang paling berbobot secara empiris sebelum komitmen penuh.

## 8. Yang sengaja TIDAK masuk v1

Daftar ini mengikat. Tiap butir punya alasan yang tercatat; menambahkan satu butir ke v1 butuh keputusan eksplisit dengan alasan baru.

- Login YouTube Music (tanpa OAuth; menunda berarti tanpa kredensial di perangkat; spesifikasi penyimpanan login sudah ditulis untuk rilis berikutnya).
- Minting poToken / BotGuard (pekerjaan besar dan rapuh; hindari client yang membutuhkannya selama masih ada client yang tidak).
- Client SABR (protobuf + UMP; v1 menolak format SABR, bukan memutarnya).
- Unduhan video (app ini audio saja).
- Normalisasi volume antar lagu berbasis ReplayGain/EBU R128 (hanya tersedia di mpv_audio_kit; ditunda pasca-v1).
- Equalizer 10 band yang konsisten lintas perangkat (hanya tersedia di mpv_audio_kit; v1 memakai AndroidEqualizer yang mengikuti perangkat).
- Enkripsi database (tidak wajib sampai satu dari tiga pemicu di bagian 6.1 terpenuhi).
- Certificate pinning ke YouTube/Google (dilarang; lihat bagian 6.1).
- API Spotify dalam bentuk apa pun (preseden cease-and-desist Spotify ke Spotube 2025; lihat riset kompetitor).
- Akun, sinkronisasi cloud, telemetri, iklan, dan server milik app (batas proyek: Rp0, tanpa server).
- Pemutar lokal file audio sebagai fitur wajib v1 (izin `READ_MEDIA_AUDIO` hanya ditambahkan bila fitur ini masuk v1; keputusan ada di PRD).

## 9. Yang belum terverifikasi

Daftar gabungan dari kelima tim. Tiap butir adalah pekerjaan verifikasi di Fase 2, bukan detail yang boleh ditebak. Butir yang sudah terselesaikan koordinator dicatat terselesaikan agar tidak dikerjakan ulang.

**Stack audio (A2):** versi media3 persis di file build just_audio 0.10.6 (changelog mendukung 1.4.1, file build tidak dibuka; cek `android/build.gradle.kts` di repo ryanheise/just_audio pada tag 0.10.6); nilai minSdk yang dideklarasikan just_audio dan audio_service di file build masing-masing; lisensi audio_service dan audio_session (halaman lisensi keduanya tidak dibuka; wajib dicek sebelum pengumuman lisensi proyek); nomor versi terakhir audioplayers (6.7.1 terverifikasi, rilis 27 Jun 2026 ada, nomornya tidak terverifikasi); lisensi libmpv yang dibundel `media_kit_libs_audio`; ukuran native libs media_kit per ABI; ukuran APK aplikasi (tidak ada angka sampai ada build release nyata yang diukur); kontribusi ukuran dependensi Media3 ExoPlayer pada APK just_audio; dukungan gapless media_kit dan dukungan antrean mpv_audio_kit; aktivitas repo GitHub media-kit setelah rilis pub.dev terakhir (Des 2025); klaim fork audio_service_13 soal custom actions yang rusak di Android SDK 33; signature lengkap per parameter untuk `setPitch` dan `setSkipSilenceEnabled`; jumlah band dan frekuensi tengah `AndroidEqualizer` di perangkat nyata; status kebijakan F-Droid terhadap build mpv_audio_kit yang mengunduh biner libmpv saat build; pembacaan source langsung atas pemakaian MediaBrowserServiceCompat di audio_service.

**Ekstraksi stream (A4):** nomor versi persis darttubefix yang terbit di pub.dev (yang terverifikasi adalah versi repo 1.0.8 dan tanggal update pub.dev 15 Sep 2026); lisensi muzoapi, youtube_explode_dart_plus, android_new_pipe_extractor, pytubefix, innertube (patlytics), zerodytrash/YouTube-Internal-Clients, dan quickjs-kt (dokar3); nomor versi flutter_qjs_next dan gg_quickjs; apakah client iOS memberi URL langsung tanpa signature decoding; apakah F-Droid menerima config remote yang mengubah perilaku ekstraksi; isi file `ZemerCipherSolver.kt` di SimpMusic; besaran ukuran APK tambahan dari NewPipeExtractor dan dari quickjs_engine; tanggal rilis persis youtube_explode_dart 3.1.0 di pub.dev selain tanggal update halaman (9 Mei 2026). Terselesaikan (spike P1, 15-16 Nov 2026): syarat persis tiap client InnerTube saat ini (WEB_REMIX + MWEB memberi format konvensional; ANDROID/IOS SABR-only; ANDROID_MUSIC/IOS_MUSIC/WEB LOGIN_REQUIRED; bukti di `docs/spike-ekstraksi.md` di repo Laras); klaim semua permukaan web YouTube sudah pindah ke SABR TERBANTAH untuk WEB_REMIX dan MWEB (keduanya masih memberi format konvensional cipher 5/5 lagu kanari). BARU belum terverifikasi (spike P1, 16 Nov 2026): apakah batas 1 MiB googlevideo juga berlaku di IP residensial HP (hanya uji perangkat owner yang bisa memutuskan); waktu resolve di jaringan HP langsung (median VM 4.049 ms, target <2.000 ms); bunyi QuickJS di perangkat nyata (tidak bisa dites di host Linux); ukuran APK rilis + kontribusi QuickJS (menunggu CI pasca-push P1).

**Storage lokal (A5):** pilihan antara audiotags dan flutter_taglib untuk penulisan tag metadata (diputuskan setelah uji Fase 2); ambang memori persis untuk uji regresi anti-OOM (diputuskan di Fase 2 setelah pengukuran pertama di perangkat nyata). Terselesaikan: lisensi drift MIT (terverifikasi koordinator dari metadata repo).

**Keamanan (A6):** apakah Network Security Config berlaku untuk lalu lintas Dio/HttpClient Dart; changelog flutter_secure_storage v11; perintah audit kerentanan dependensi di toolchain Dart; reproducible build Flutter di F-Droid; penambahan ukuran APK dari library enkripsi. Terselesaikan: versi pasti audio_service (0.18.19) dan just_audio (0.10.6) melalui riset A2.

**Performa (A13):** lisensi audio_service, audio_session, dan just_audio_background; angka versi pasti paket `_ce`; tanggal rilis persis 4 paket; ukuran file thumbnail YTM nyata (asumsi 100 KB perlu diukur); eviction otomatis LockCachingAudioSource; ukuran APK nyata kombinasi dependensi; paket deteksi konektivitas (`connectivity_plus` kandidat, versi dan status belum dicek); klaim backlog 300+ issue paket cached_network_image asli. Terselesaikan: lisensi drift MIT (terverifikasi koordinator).

## 10. Daftar sumber

Semua sumber dibuka dan dicek pada 15 November 2026, kecuali dinyatakan lain. Daftar lengkap per tim ada di laporan masing-masing tim (bagian Daftar sumber di tiap laporan).

**Dokumen proyek:** `docs/riset-kompetitor.md` (gabungan C1, C8, A2 Paket 1, tanggal cek 15 Nov 2026).

**pub.dev, audio:** https://pub.dev/packages/just_audio, https://pub.dev/packages/just_audio/changelog, https://pub.dev/packages/just_audio/versions/0.9.45/changelog, https://pub.dev/packages/just_audio/license, https://pub.dev/documentation/just_audio/latest/, https://pub.dev/packages/audio_service, https://pub.dev/packages/audio_session, https://pub.dev/packages/media_kit, https://pub.dev/packages/audioplayers, https://pub.dev/packages/mpv_audio_kit, https://pub.dev/packages/just_audio_media_kit, https://pub.dev/packages/mt_audio, https://pub.dev/packages/flutter_soloud/versions/1.2.5.

**pub.dev, ekstraksi dan QuickJS:** https://pub.dev/packages/youtube_explode_dart, https://pub.dev/packages/darttubefix, https://pub.dev/packages/youtube_extractor_muzo, https://pub.dev/packages/muzoapi, https://pub.dev/packages/youtube_explode_dart_plus, https://pub.dev/packages/ytdlp_flutter, https://pub.dev/packages/extractor, https://pub.dev/packages/android_new_pipe_extractor, https://pub.dev/packages/zen_engine/score, https://pub.dev/packages/yt, https://pub.dev/packages/flutter_js, https://pub.dev/packages/quickjs_engine, https://pub.dev/packages/flutter_qjs_next, https://pub.dev/packages/gg_quickjs.

**pub.dev, storage dan performa:** docs setup resmi drift (drift 2.35.4, drift_dev 2.35.3, drift_flutter 0.3.1, sqlite3 3.9.1, path_provider 2.1.6, build_runner 2.16.2), https://pub.dev/packages/cached_network_image_ce, https://pub.dev/packages/dio, https://pub.dev/packages/flutter_secure_storage.

**Repo GitHub:** https://github.com/Hexer10/youtube_explode_dart, https://github.com/MrTG-CodeBot/darttubefix, https://github.com/statecs/ytdlp_flutter, https://github.com/TeamNewPipe/NewPipeExtractor, https://github.com/maxrave-dev/SimpMusic, https://github.com/maxrave-dev/core, https://github.com/MetrolistGroup/faraday, https://github.com/LuanRT/YouTube.js, https://github.com/zerodytrash/YouTube-Internal-Clients, https://github.com/smolus3/drift, https://github.com/z-huang/InnerTune/issues/1792, https://github.com/anandnet/Harmony-Music.

**Dokumentasi resmi Android dan Flutter:** https://developer.android.com/jetpack/androidx/releases/media (androidx.media 1.8.0, 6 Mei 2026), https://developer.android.com/jetpack/androidx/releases/media3 (Media3 1.11.1, 11 Nov 2026), https://developer.android.com/reference/androidx/media/MediaBrowserServiceCompat, https://developer.android.com/media/media3/exoplayer/supported-devices, https://developer.android.com/media/media3/exoplayer/migration-guide, https://docs.flutter.dev/resources/faq.

**Dokumentasi dan referensi ekstraksi:** https://pypi.org/project/innertube/, https://pypi.org/project/ytmusicapi/, https://pytubefix.readthedocs.io/ (dokumentasi versi 11.2.1, bagian PoToken), https://ytjs.dev/, https://dev.to/0012303/youtubes-secret-innertube-api-extract-comments-transcripts-channel-data-without-api-keys-mil (26 Mar 2026), https://gist.github.com/MartinEesmaa/2f4b261cb90a47e9c41ba115a011a4aa (daftar itag, 11 Okt 2026), https://dev.to/yt320mp3/what-audio-quality-does-youtube-actually-stream-and-how-to-spot-a-fake-320kbps-mp3-4i4f (Okt 2026).

## 11. Checklist tujuh skill anti-slop

Ketujuh skill anti-slop owner dibaca koordinator sebelum Paket 1 dimulai (local-design-taste-frontend, local-impeccable, local-humanizer, local-stop-slop, local-no-ai-slop, local-avoid-ai-writing, local-anti-slop, plus rulebook local-anti-slop/skills/antislop/SKILL.md). Checklist per skill untuk dokumen gabungan ini:

**local-design-taste-frontend**

- [x] Nol karakter em dash di seluruh dokumen (aturan 9.G, non-negotiable). Rentang angka memakai hyphen biasa. Diverifikasi dengan grep sesudah penulisan.
- [x] Tanpa angka fake-perfect dan tanpa statistik tanpa sumber (aturan 9.D, R-17). Setiap angka membawa sumber dan tanggal cek, atau dilabeli target desain, asumsi yang dinyatakan jelas, atau tidak terverifikasi.
- [x] Tanpa filler verb (elevate, seamless, unleash, next-gen, revolutionize) dan tanpa nama generik.
- [x] Tanpa klaim pemasaran dan tanpa label versi sebagai hiasan. Nomor versi yang tercantum adalah data riset, bukan dekorasi.

**local-impeccable**

- [x] Struktur dokumen mengikuti hierarki yang jelas: ringkasan dulu, detail per komponen, keputusan koordinator, lalu yang tidak masuk v1, yang belum terverifikasi, sumber, dan checklist.
- [x] Setiap bagian menjawab satu pertanyaan spesifik. Selisih antar tim tidak disembunyikan, melainkan diselesaikan terbuka di bagian 7 dengan alasan.
- [x] Tabel memakai satu format yang konsisten dan setiap sel bisa dilacak ke laporan tim atau sumber live.

**local-humanizer**

- [x] Kalimat ditulis langsung dan spesifik, dengan suara manusia yang memberi penilaian, termasuk pengakuan terbuka saat bukti tidak ada.
- [x] Tanpa pola kalimat template AI yang berulang dan tanpa paragraf pembuka robotik.

**local-stop-slop**

- [x] Tanpa retorika dan filler. Tidak ada paragraf yang hanya mengulang ringkasan dengan kata berbeda.
- [x] Kalimat pasif diminimalkan. Subjek setiap klaim jelas (paket, dokumen, atau tim).
- [x] Tanpa false agency: library tidak "memutuskan" atau "menginginkan" apa pun. Keputusan dinyatakan sebagai keputusan tim atau koordinator.

**local-no-ai-slop**

- [x] Tanpa pola not-X-but-Y. Rekomendasi dan penolakan dinyatakan langsung sebagai pernyataan positif.
- [x] Tanpa klaim berlebihan ("terbaik", "sempurna", "revolusioner"). Penilaian memakai bukti API, tanggal rilis, dan source yang dibaca.
- [x] Tanpa frasa pembuka robotik ("Tentu!", "Berikut adalah...") dan tanpa penutup kosong.

**local-avoid-ai-writing**

- [x] Tanpa AI-isms yang umum: tidak ada "penting untuk dicatat" yang berulang, tidak ada "di era digital", tidak ada "lanskap".
- [x] Istilah teknis dipertahankan dalam bahasa Inggris sesuai standar laporan, tanpa terjemahan kaku.
- [x] Nada konsisten: tajam, faktual, dan terus terang tentang kelemahan dan yang belum terverifikasi.

**local-anti-slop dan rulebook**

- [x] R-02: nol em dash di seluruh teks.
- [x] R-17: tidak ada statistik tanpa sumber nyata. Target dan asumsi dilabeli sebagai target dan asumsi.
- [x] R-36: tidak ada klaim keamanan, kepatuhan, performa, atau customer yang difabrikasi.
- [x] R-38: tidak ada konten bergaya realistis yang difabrikasi. Semua fitur yang diklaim ada dilacak ke dokumentasi, changelog, atau source yang dibaca, dengan URL dan tanggal cek.
- [x] C-5 (Evidence Over Claims): setiap klaim teknis membawa sumber. Daftar "belum terverifikasi" ditulis eksplisit agar tidak ada klaim yang mengambang.
