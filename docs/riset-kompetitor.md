# Riset Kompetitor: 5 Aplikasi Musik Open Source

Fase 1, proyek aplikasi musik Android gratis, tanpa iklan, bisa offline.
Tanggal cek: 15 November 2026. Semua angka diambil dari sumber live yang dibuka
pada tanggal itu, kecuali dinyatakan lain (sekunder atau tidak terverifikasi).
Laporan ini menggabungkan tiga laporan tim: C1 Riset dan Perbandingan (fitur
dan status), A2 Mobile dan Aplikasi (arsitektur dari source code), C8 Legal
dan Privasi (lisensi, ToS, privasi, distribusi).

Laporan tim ini bukan nasihat hukum formal. Tim bukan pengacara. Keputusan yang
berdampak hukum tetap perlu dikonsultasikan ke penasihat hukum bila owner
menganggap perlu.

## Ringkasan eksekutif

Lima kompetitor yang diteardown: InnerTune, OuterTune, Spotube, ViMusic,
SimpMusic. Semuanya client musik yang mengambil audio dari YouTube atau
YouTube Music lewat akses tidak resmi (InnerTube), bukan dari server sendiri.

- SimpMusic adalah satu-satunya yang masih rilis rutin sampai November 2026
  (v2.5.0, 1 November 2026; commit terakhir 13 November 2026).
- Spotube baru saja rilis besar v6.0.0 (9 November 2026) dan pindah total dari
  Flutter ke Kotlin Multiplatform + Compose Multiplatform, sekaligus ganti
  lisensi BSD-4-Clause ke AGPL-3.0-or-later. Komunitas terbesar: 50.781 bintang.
- InnerTune hidup pelan: rilis terakhir v0.5.10 (1 September 2024), lebih dari
  2 tahun tanpa rilis, tapi repo belum diarsipkan.
- OuterTune menyatakan di README "This app is no longer in active
  development" dan sejak v0.11.x menghapus YouTube Music, menjadi pemutar
  lokal saja.
- ViMusic mati: rilis terakhir v0.5.4 (4 November 2022), repo diarsipkan
  pemiliknya 15 Maret 2026 dan sekarang read-only.
- Empat dari lima memakai GPL-3.0. Spotube memakai AGPL-3.0-or-later.
- Tidak satu pun ada di Play Store. Semuanya lewat GitHub, F-Droid, dan
  IzzyOnDroid.
- Tidak satu pun masih memakai Flutter. Spotube, satu-satunya yang pernah
  Flutter, sudah pindah. Alasan pindahnya tidak terverifikasi, jadi jangan
  dijadikan argumen pro atau kontra Flutter.
- Risiko terbesar bukan gugatan, melainkan app yang rusak berulang saat
  YouTube mengubah sisi servernya. Ini beban maintenance permanen.

## Tabel perbandingan

Semua bintang dicek 15 November 2026 di halaman repo GitHub masing-masing.

| Aspek | InnerTune | OuterTune | Spotube | ViMusic | SimpMusic |
|---|---|---|---|---|---|
| Repo | z-huang/InnerTune | OuterTune/OuterTune | team-spotube/spotube | vfsfitvnm/ViMusic | maxrave-dev/SimpMusic |
| Platform | Android | Android | Android, Windows, macOS, Linux, iOS | Android | Android, Windows, macOS, Linux |
| Stack | Kotlin, Jetpack Compose | Kotlin, Jetpack Compose | Kotlin, Compose Multiplatform (dulu Flutter) | Kotlin, Jetpack Compose | Kotlin, Compose Multiplatform |
| Sumber audio | YouTube Music (InnerTube) | YouTube Music sampai 0.10.x, lalu lokal saja | Plugin (YouTube, Invidious, Piped) | YouTube Music (InnerTube) | YouTube Music (InnerTube) + NewPipeExtractor |
| Cari | Ya | Ya (sampai 0.10.x) | Ya, lewat plugin | Ya | Ya |
| Putar background | Ya | Ya | Ya | Ya | Ya |
| Offline/download | Ya, cache dan download | Ya, sampai 0.10.x | Ya, download dengan metadata (klaim README) | Ya, cache audio 2 GB | Ya, cache dan Smart downloads |
| Lirik | Tersinkron, ada penerjemah | Tersinkron, kata per kata | Tersinkron | Tersinkron, bisa diedit | Tersinkron, kata per kata, romanisasi |
| Playlist | Ya, kelola library | Ya, sinkron akun | Ya, lewat plugin | Ya, lokal dan impor | Ya, sinkron YouTube Music |
| Sinkron akun | Login YouTube Music | Ya, sampai 0.10.x | Tidak ada login Spotify lagi | Tidak disebut | Multi akun YouTube |
| Pemutar lokal | Tidak | Ya, MP3, OGG, FLAC | Ya, On Device | Tidak | Terbatas, bukan fitur utama |
| Lisensi | GPL-3.0 | GPL-3.0 | AGPL-3.0-or-later | GPL-3.0 | GPL-3.0 |
| Rilis terakhir | v0.5.10, 1 Sep 2024 | v0.11.1, 6 Sep 2026 (lokal saja) | v6.0.0, 9 Nov 2026 | v0.5.4, 4 Nov 2022 | v2.5.0, 1 Nov 2026 |
| Commit terakhir | Tidak terverifikasi | 12 Okt 2026 | 10 Nov 2026 | 15 Jul 2024 (push terakhir) | 13 Nov 2026 |
| Status | Jalan pelan, tanpa rilis 2 tahun lebih | Berhenti untuk YouTube Music | Aktif | Diarsipkan 15 Mar 2026 | Aktif, paling rutin rilis |
| F-Droid | Ya, 0.5.10 | Ya, 0.10.1 | Ya, 5.1.2 (tertinggal dari GitHub) | Ya, badge di README | Ya, 2.5.0 |
| Ukuran APK | 6,5 MiB | 9 MiB (0.10.1, F-Droid) | 128,6 MB (build F-Droid 5.1.2, sekunder) | 2,6 MB (sekunder) | 53 MiB |
| Bintang GitHub | 6.149 | 5.456 | 50.781 | 9.474 | 13.392 |
| Fork | 457 | 378 | 2.407 | 1.350 | 781 |
| Total rilis | 26 | 37 | 46 | 20 | 62 |
| Android minimum | API 24 (7.0) | API 26 (8.0) di 0.11.1 | API 28 (9.0) di v6.0.0 | API 21 (5.0) | API 26 (8.0) |
| Pemutar | Media3 ExoPlayer 1.4.1 | Media3 ExoPlayer | Media3 ExoPlayer 1.10.1 (Android) | Media3 ExoPlayer | Media3 ExoPlayer 1.11.1 (Android) |
| Database lokal | Room 2.6.1 | Room | DataStore Preferences (JSON) | Room | Room 2.8.5 + DataStore |

## 1. InnerTune

Repo: https://github.com/z-huang/InnerTune (branch default `dev`, GPL-3.0).
Pengembangnya Zion Huang. App ini yang memulai garis keturunan InnerTune,
OuterTune, InterTune, Metrolist, dan banyak fork lain.

Fitur utama, dari README repo: putar lagu dari YouTube dan YouTube Music tanpa
iklan dengan background playback; cari lagu, video, album, dan playlist dari
YouTube Music; login akun YouTube Music; cache dan download lagu untuk putar
offline; lirik tersinkron dan penerjemah lirik; skip silence, normalisasi
audio, atur tempo dan pitch; tema dinamis, Android Auto, quick picks personal,
Discord Rich Presence. Pemutar file lokal tidak ada di daftar fitur README.

Arsitektur (dari source live): Kotlin dengan Jetpack Compose, Android saja.
Modul di root repo: `app`, `innertube`, `kizzy`, `kugou`, `lrclib`,
`material-color-utilities`. Modul `innertube` adalah client InnerTube buatan
sendiri (Ktor client core/okhttp/content-negotiation, ktor-serialization-json,
brotli), terpisah dari modul `app`. Pemutar Media3 ExoPlayer 1.4.1 lewat
`MusicService` (809 baris, `MediaLibraryService` + `MediaSession` +
`DefaultMediaNotificationProvider`, foreground service type `mediaPlayback`).
Download lewat Media3 DownloadService (`ExoDownloadService`, foreground type
`dataSync`, action `androidx.media3.exoplayer.downloadService.action.RESTART`),
dengan dua `SimpleCache` terpisah: satu untuk cache pemutar, satu untuk
unduhan. Database Room 2.6.1 dengan entitas Song, Album, Artist, Playlist,
Format, Lyrics, Event, SearchHistory, LocalItem, plus tabel pemetaan. Build
Gradle Kotlin DSL, AGP 8.6.0, Kotlin 2.0.10, Java 17, Hilt, KSP + kapt.
Flavor `full` dan `foss`; flavor `full` menambah Firebase dan ML Kit.

Status perawatan: rilis stabil terakhir v0.5.10, 1 September 2024. Sudah lebih
dari 2 tahun tanpa rilis. Repo belum diarsipkan dan branch `dev` masih
menerima commit sesekali (53 commit ke `dev` sesudah v0.5.10). Tanggal commit
terakhir tidak berhasil diverifikasi. Statusnya: hidup pelan, bukan mati
total, tapi pengguna hanya mendapat build baru dari fork.

Distribusi: F-Droid (paket com.zionhuang.music, v0.5.10, APK 6,5 MiB, Android
7.0 ke atas), IzzyOnDroid, GitHub releases. Tidak ada di Play Store.

Kelebihan: APK kecil (6,5 MiB), antarmuka Material 3 yang rapi, modul
`innertube` terpisah sehingga gampang dipakai ulang, jadi referensi yang
ditiru hampir semua kompetitor di daftar ini.

Kekurangan: tidak ada rilis selama lebih dari 2 tahun, issue menumpuk, tidak
ada pemutar file lokal, nasib proyek bergantung pada satu maintainer.

Yang kami tiru: pisahkan kode akses InnerTube jadi modul sendiri; sediakan
lirik tersinkron plus penerjemah lirik; jaga ukuran APK tetap kecil; masuk
F-Droid sejak awal.

Yang kami hindari: bergantung pada satu orang tanpa rilis berkala. Begitu
maintainer sibuk, proyek membeku dan pengguna pindah ke fork.

## 2. OuterTune

Repo: https://github.com/OuterTune/OuterTune (branch default `lite`, GPL-3.0).
Fork InnerTune yang menambahkan pemutar file lokal. Pengembang utamanya
Davide Garberi.

Fitur utama, dari README repo: client YouTube Music (download lagu untuk
offline, putar tanpa iklan di background, sinkron akun); pemutar file lokal
MP3, OGG, FLAC, dan format lain, dengan lagu lokal dan lagu YouTube Music
dalam satu antrean; tag extractor sendiri, bukan bawaan MediaStore; beberapa
antrean; lirik tersinkron termasuk format kata per kata atau karaoke (LRC,
TTML); normalisasi audio, atur tempo dan pitch; Android Auto, Android 8 ke
atas.

Arsitektur (dari source live): Kotlin dengan Jetpack Compose, Android saja.
Di v0.10.1 (versi YTM terakhir): compileSdk 36, minSdk 24, Java 17, modul
`:innertube` (fork modul InnerTune) dengan Ktor, plus modul `:kugou`,
`:lrclib`, `:taglib`; flavor full menambah `:ffMetadataEx`. Di v0.11.1
(local-only): compileSdk 37, minSdk 26, Java 21, modul `innertube` sudah
dihapus. Pemutar Media3 ExoPlayer, database Room. File service pemutar,
manifest, dan folder db tidak dibuka, jadi nama class service dan entitas
database tidak terverifikasi. Log build F-Droid menyebut Gradle 9.1.0 untuk
build 0.10.0. File `Modules.md` mencatat tiga komponen yang dibundel dari
luar: `material-color-utilities`, Gramophone Lyrics parser, dan
TreeDocumentFile (dari Android Open Source Project).

Status perawatan: README repo menyatakan langsung, "This app is no longer in
active development", dan menyarankan pengganti: InterTune, AsterTune,
Metrolist, ArchiveTune, plus Gramophone untuk pemutar lokal. Rilis stabil
terakhir v0.11.1, 6 September 2026, pemutar lokal saja. Rilis stabil terakhir
yang masih punya YouTube Music adalah v0.10.1, 19 Desember 2025. Commit
terakhir 12 Oktober 2026 menurut appsgit.

Distribusi: GitHub releases, IzzyOnDroid, Obtainium, F-Droid (indeks repo
utama F-Droid masih mencantumkan 0.10.1, APK 9 MiB). Tidak ada di Play Store.
App bernama OuterTune di Play Store berasal dari pengembang lain.

Kelebihan: menggabungkan streaming dan file lokal dalam satu antrean, tag
extractor sendiri yang membaca tag lebih benar dari MediaStore, lirik kata
per kata, antrean ganda.

Kekurangan: versi YouTube Music ditinggalkan; penomoran versi sempat
berantakan sampai catatan rilis mengakui rilis 0.10.1 lebih tua dari build
0.10.1-b1; backup database 0.11.x tidak kompatibel dengan 0.10.x, jadi
pengguna yang upgrade tidak bisa kembali; maintainer secara terbuka
menawarkan proyeknya ke siapa saja yang mau mengambil alih.

Yang kami tiru: pemutar lokal berdampingan dengan streaming dalam satu
antrean; tag extractor sendiri; lirik kata per kata.

Yang kami hindari: menghapus fitur inti tanpa jalur migrasi data, dan
penomoran versi yang membingungkan pengguna. Sekali backup tidak bisa kembali,
kepercayaan pengguna hilang.

## 3. Spotube

Repo: https://github.com/KRTirtho/spotube (dialihkan ke
https://github.com/team-spotube/spotube, AGPL-3.0-or-later). Platform
streaming musik open source lintas platform yang bekerja lewat plugin.

Fitur utama, dari README repo: plugin untuk platform atau layanan musik apa
pun, buatan komunitas atau sendiri; download track dengan metadata tertag;
lirik tersinkron terlepas dari dukungan plugin; tanpa telemetri dan tanpa
pengumpulan data pengguna; kontrol playback lokal, bukan di server; Android
Auto penuh, jam session (dengar bareng tersinkron lewat room server), pemutar
file lokal (On Device), dukungan iOS lewat VLC. Sinkron akun: tidak ada login
Spotify lagi. Sejak v5, Spotube menghapus Spotify setelah menerima
cease-and-desist dari Spotify pada 2025. Plugin metadata resmi memakai
MusicBrainz dan ListenBrainz. Plugin audio YouTube terpisah
(spotube-plugin-youtube-audio, v1.0.0 dirilis 14 November 2026).

Arsitektur (dari source live): dulu Flutter dan Dart. Sejak v6.0.0 pindah ke
Kotlin Multiplatform + Compose Multiplatform (Android + iOS + Desktop).
Gradle multi-module: `:composeApp` (aplikasi utama), `:plugin_interfaces`
(kontrak API plugin), `:js_plugin_example` (template plugin JS Zipline).
Pemutar: abstraksi `AudioPlayerInterface` di commonMain; Android memakai
Media3 ExoPlayer 1.10.1 lewat `PlaybackService` (`MediaLibraryService` +
`MediaLibrarySession` + `DefaultMediaNotificationProvider`, foreground type
`mediaPlayback`), Desktop memakai vlcj, iOS memakai MobileVLCKit lewat
`VlcPlayerEngine.swift`. Ambil stream lewat NewPipeExtractor v0.26.5 (Android/
JVM) dan newpipe-extractor-kmp 1.3.0 (iOS); tidak ada modul innertube.
Database: tidak memakai Room atau SQLDelight, hanya tujuh DataStore
Preferences berisi JSON. Komentar di `Database.kt` menjelaskan DataStore
membaca seluruh file preferences ke heap, dan build sebelumnya menyimpan cover
full-size sebagai array angka JSON hingga ratusan MB sampai crash
OutOfMemoryError (issue #3193); karena itu ada fungsi `dropIfOversized` yang
membuang store antrean dan media lokal bila melebihi 8 MB. Build: Gradle
8.14.3, AGP 9.1.0, Kotlin 2.4.21, Ktor 3.5.1, Koin 4.2.2, Zipline 1.28.0,
JDK 21, Rust, GraalVM Native Image untuk desktop (build native sekitar 10
menit, puncak RAM sekitar 15 GB menurut README). File `AGENTS.md` mencatat
tidak ada file tes yang di-commit dan tidak ada task lint, typecheck, atau
formatter yang dikonfigurasi. Mekanisme download internal tidak terverifikasi
(tidak ada folder download di source yang dibuka; hanya klaim README).

Status perawatan: aktif. Rilis stabil terakhir v6.0.0, 9 November 2026.
Commit terakhir 10 November 2026 menurut appsgit. Rilis v6 adalah tulis ulang
besar: migrasi Flutter ke Compose Multiplatform, UI baru bernama Millennium
UI, Android Auto, jam session, dan relisensi ke AGPL-3.0-or-later dengan
alasan mencegah distribusi Spotube tertutup dan hasil modifikasi berbahaya.

Distribusi: F-Droid (paket oss.krtirtho.spotube, versi 5.1.2 dari 9 Juni 2026,
build F-Droid 128,6 MB, Android 7.0 ke atas; metadata F-Droid masih BSD yang
sudah stale), GitHub releases, situs spotube.cc, Flatpak, winget, Homebrew.
F-Droid tertinggal dari GitHub: F-Droid masih 5.1.2 sementara GitHub sudah
6.0.0. F-Droid memberi flag NonFreeNet pada app ini.

Kelebihan: komunitas terbesar, arsitektur plugin memisahkan app inti dari
sumber audio sehingga risiko hukum tidak menempel di satu tempat, tanpa
telemetri, berjalan di Android, Windows, macOS, Linux, dan iOS.

Kekurangan: APK F-Droid 128,6 MB, jauh lebih besar dari kompetitor; build
desktop berat (RAM 15 GB); kualitas plugin bervariasi karena repositori
komunitas tidak dikurasi; ada laporan track yang salah cocok untuk lagu kurang
populer; tidak ada tes yang di-commit.

Yang kami tiru: tanpa telemetri sama sekali; download dengan metadata tertag;
pisahkan sumber audio dari app inti supaya satu sumber bermasalah tidak
mematikan seluruh app.

Yang kami hindari: menyentuh API Spotify dalam bentuk apa pun. Spotube kena
cease-and-desist pada 2025 dan harus membuang Spotify dari app, lalu menulis
ulang arsitekturnya. Itu pelajaran paling mahal di daftar ini. Hindari juga
ukuran APK ratusan MB, build yang butuh mesin besar, dan merilis tanpa tes.

## 4. ViMusic

Repo: https://github.com/vfsfitvnm/ViMusic (branch `master`, GPL-3.0). Pelopor
di kategori ini: InnerTune secara terbuka mengaku belajar Jetpack Compose dari
ViMusic. Proyeknya sudah berakhir.

Fitur utama, dari README repo: putar hampir semua lagu atau video dari
YouTube Music dengan background playback; cache potongan audio untuk putar
offline; cari lagu, album, artis, video, dan playlist; bookmark artis dan
album, impor playlist, kelola playlist lokal; ambil, tampilkan, dan edit
lirik atau lirik tersinkron; susun ulang lagu di playlist atau antrean,
antrean persisten; tema terang, gelap, dan dinamis; skip silence; sleep
timer; normalisasi audio; Android Auto; buka link YouTube dan YouTube Music.
Pemutar file lokal tidak ada. Login akun tidak disebut di README.

Arsitektur (dari source live): Kotlin dengan Jetpack Compose, Android saja.
Modul: `app`, `compose-persist`, `compose-reordering`, `compose-routing`,
`innertube`, `ktor-client-brotli`, `kugou`. Pemutar Media3 ExoPlayer lewat
`PlayerService` (1.000 baris, pola lama: `android.media.session.MediaSession`
dari framework platform, bukan Media3 session, ditambah `NotificationChannel`
dan `NotificationManager` manual). Cache disk ExoPlayer 2 GB LRU
(`SimpleCache` di `cacheDir/exoPlayer` dengan `LeastRecentlyUsedCacheEvictor`).
Download eksplisit tidak terverifikasi. Database Room dengan entitas Song,
Album, Artist, Playlist, Lyrics, Format, Event, SearchQuery, QueuedMediaItem,
plus tabel pemetaan. Build: compileSdk 33, minSdk 21, targetSdk 33, Java 1.8,
minify + shrinkResources. File manifest tidak dibuka, jadi permission dan
deklarasi service di manifest tidak terverifikasi.

Status perawatan: mati. Rilis terakhir v0.5.4, 4 November 2022. Push sumber
terakhir 15 Juli 2024. Pemilik mengarsipkan repo pada 15 Maret 2026 sehingga
repo sekarang read-only. Fork Jigen-Ohtsusuki sempat menghidupkan ViMusic
pada pertengahan 2025, tapi fork itu juga diarsipkan pada 14 September 2025.

Distribusi: GitHub releases (APK v0.5.4 sekitar 2,6 MB, angka sekunder dari
anygen.io), F-Droid (badge di README; halaman F-Droid ViMusic mengembalikan
HTTP 404 pada 15 November 2026), IzzyOnDroid (badge di README). Versi ViMusic
yang tercantum di F-Droid saat ini tidak terverifikasi.

Kelebihan: pelopor arsitektur client YouTube Music di Android; APK sangat
kecil (2,6 MB); target Android lama (minSdk 21, Android 5.0); antrean
persisten dan manajemen playlist lokal yang rapi.

Kekurangan: proyek mati dan diarsipkan; target SDK 33 sudah ketinggalan; ada
laporan bug cache offline, lagu yang sudah didownload hilang setelah app
ditutup (issue #1371); tidak ada dukungan streaming bitrate tinggi menurut
ulasan pengguna di Lemmy.

Yang kami tiru: modul `innertube` yang bersih dan kecil; antrean persisten;
ukuran APK minimal.

Yang kami hindari: membiarkan proyek mati tanpa suksesor yang jelas. ViMusic
tidak menunjuk penerus, sehingga pengguna tersebar ke fork-fork yang juga
mati satu per satu.

## 5. SimpMusic

Repo: https://github.com/maxrave-dev/SimpMusic (branch default `dev`, GPL-3.0).
Client YouTube Music open source untuk Android dan desktop, dibangun dengan
Compose Multiplatform. Pengembangnya maxrave-dev (Nguyen Duc Tuan Minh). Ini
satu-satunya dari kelima app yang masih rilis rutin sampai November 2026.

Fitur utama, dari README repo: putar musik dari YouTube Music atau YouTube
gratis, tanpa iklan, di background; cari semua konten YouTube; jelajah Home,
Charts, Podcast, Moods dan Genre; cache dan offline playback, plus Smart
downloads untuk lagu yang paling sering diputar; lirik tersinkron dari
SimpMusic Lyrics, LRCLIB, BetterLyrics, Spotify (butuh login), dan transkrip
YouTube; lirik kata per kata gaya Apple Music; romanisasi 12 bahasa; tambah
lirik sendiri ke lagu yang belum punya lirik; impor playlist hasil konversi
dari Spotify dan app lain; multi akun YouTube; equalizer 10 band dengan preset
dan profil headphone AutoEq, plus efek Delay dan Reverb; pengenal lagu yang
sedang berbunyi di sekitar (Android, pakai Shazam); Spotify Canvas dan
animated album art; video 1080p dengan subtitle; SponsorBlock dan Return
YouTube Dislike; sleep timer; Android Auto; Discord Rich Presence; Listen
Together (ruang dengar bareng tersinkron, kompatibel dengan Metrolist);
SimpMusic Wrapped (rangkuman tahunan), analitik dengar di perangkat, widget
home screen; transfer login dari Android ke desktop dengan scan QR. Pemutar
file lokal: izin baca audio tercantum di halaman F-Droid, tapi README tidak
menonjolkannya sebagai fitur utama.

Arsitektur (dari source live): Kotlin Multiplatform dengan Compose
Multiplatform, Android + Desktop (JVM); target iOS ada di file build tetapi
dikomentari (tidak aktif). File `CLAUDE.md` (3.843 baris) mendokumentasikan
Clean Architecture + MVVM. Modul inti: `composeApp` (shared), `androidApp`,
`core/common`, `core/domain`, `core/data` (Room), `core/media/media3` (Media3
ExoPlayer 1.11.1, `CrossfadeExoPlayerAdapter`, `EqualizerAudioProcessor`),
`media-jvm` (libmpv via JNA untuk Desktop). Layanan di `core/service`:
`kotlinYtmusicScraper` (YouTube Music API scraper), `spotify` (Web API
Canvas/Lyrics), `lyricsService` (LRCLIB, SimpMusic Lyrics, BetterLyrics),
`listenTogether`, `loginSync` (QR, Ktor, AES-256-GCM, port 48517), `kizzy`
dan `discord`. Ambil stream lewat tiga jalur sekaligus: InnerTube kustom
(`kotlinYtmusicScraper`), NewPipeExtractor (v0.26.1 plus fork brave-newpipe
dan pipepipe), dan QuickJS (`quickjs-kt`) yang menjalankan player JS YouTube
di perangkat untuk memecahkan signature dan `n` challenge, dengan
`player_configs.json` sebagai pemetaan hash player. Download lewat Media3
DownloadService (`MusicDownloadService`, foreground type `dataSync`);
`song.downloadState` adalah satu-satunya penghubung file unduhan dengan baris
Room. Pemutaran latar lewat `SimpleMediaService` (`MediaLibraryService`,
foreground type `mediaPlayback`, `stopWithTask="false"`), plus Android Auto
dan receiver `MediaButtonReceiver`. Database Room 2.8.5 + DataStore
preferences 1.3.0 + sqlite-bundled 2.7.1. Build: compileSdk 37, minSdk 26,
Java 21, AGP 9.5.0, Kotlin 2.4.21, Ktor 3.6.0, Koin 4.2.2, multiDex, ABI
splits dengan universal APK.

Status perawatan: aktif dan paling sibuk di daftar ini. Rilis stabil terakhir
v2.5.0, 1 November 2026. Commit terakhir 13 November 2026 menurut appsgit.
Total 62 rilis sejak 2023.

Distribusi: F-Droid (paket com.maxrave.simpmusic, v2.5.0, APK 53 MiB, Android
8.0 ke atas), IzzyOnDroid, OpenAPK, GitHub releases, situs simpmusic.org. Ada
dua varian: Full (memakai Sentry untuk crashlytics, mengumpulkan data crash)
dan FOSS (tanpa tracker dan tanpa server pihak ketiga untuk data pengguna).

Kelebihan: paling aktif dirawat, fitur paling lengkap, Smart downloads, multi
akun, lirik kata per kata dengan romanisasi, Listen Together, pemisahan varian
Full dan FOSS yang jujur soal data.

Kekurangan: README sendiri menyebut app masih beta dan bisa crash; error
player dianggap normal karena bergantung pada YouTube Music; cakupan fitur
sangat besar sehingga beban perawatan berat; APK 53 MB; pemakaian Spotify Web
API untuk Canvas dan lirik membuka risiko hukum yang sama dengan yang menimpa
Spotube.

Yang kami tiru: Smart downloads berdasarkan lagu yang sering diputar; multi
akun; lirik kata per kata; pemisahan varian FOSS tanpa tracker dari varian
yang mengumpulkan data crash.

Yang kami hindari: menambah fitur tanpa henti sampai app selamanya berlabel
beta; memakai API Spotify untuk fitur apa pun; menganggap error player sebagai
hal normal yang tidak perlu diperbaiki.

## Pola arsitektur paling umum

Dari source code kelima kompetitor, pola yang berulang:

1. Media3 ExoPlayer dipakai 5 dari 5 kompetitor. InnerTune 1.4.1, SimpMusic
   1.11.1, Spotube 1.10.1 (angka dari version catalog masing-masing). ViMusic
   memakai alias `libs.exoplayer` yang di kode mengarah ke
   `androidx.media3.*`. Ini pola paling konsisten di seluruh kelompok.
2. MediaLibraryService + MediaSession + DefaultMediaNotificationProvider
   untuk pemutaran latar dipakai InnerTune, SimpMusic, dan Spotube. ViMusic
   adalah pengecualian dengan pola lama (MediaSession framework + notifikasi
   manual). OuterTune tidak terverifikasi detailnya.
3. Room untuk database lokal dipakai 4 dari 5 (InnerTune, OuterTune, ViMusic,
   SimpMusic). Spotube adalah pengecualian dengan DataStore Preferences berisi
   JSON, dan membayarnya dengan risiko OOM yang mereka tangani lewat
   `dropIfOversized` 8 MB.
4. Download lewat Media3 DownloadService dipakai InnerTune
   (`ExoDownloadService`) dan SimpMusic (`MusicDownloadService`), keduanya
   dengan foreground service type `dataSync` dan action
   `androidx.media3.exoplayer.downloadService.action.RESTART`. ViMusic hanya
   mengandalkan cache disk 2 GB LRU. Download Spotube dan OuterTune tidak
   terverifikasi.
5. Cache dan unduhan dipisah. InnerTune paling eksplisit: dua `SimpleCache`
   terpisah (`@PlayerCache` dan `@DownloadCache`). SimpMusic menghubungkan
   file unduhan ke baris Room lewat `song.downloadState`.
6. Dua pendekatan mengambil stream: InnerTube kustom dengan Ktor (InnerTune,
   ViMusic, OuterTune era YTM, SimpMusic) versus NewPipeExtractor (Spotube,
   dan SimpMusic sebagai jalur kedua). SimpMusic memakai keduanya sekaligus,
   ditambah QuickJS untuk memecahkan signature dan `n` challenge di
   perangkat.
7. Kotlin + Compose mendominasi 5 dari 5. Tiga memakai Kotlin Android native
   (InnerTune, OuterTune, ViMusic), dua memakai Kotlin Multiplatform +
   Compose Multiplatform (SimpMusic, Spotube). Tidak ada satu pun yang masih
   memakai Flutter.
8. Ktor adalah HTTP client di 4 dari 5 (InnerTune, ViMusic, SimpMusic,
   Spotube), dengan engine OkHttp di Android. Brotli muncul di InnerTune,
   ViMusic, dan SimpMusic.
9. Dependency injection: Hilt di InnerTune dan OuterTune, Koin di SimpMusic
   dan Spotube. ViMusic tidak terverifikasi memakai framework DI.
10. Android minimum terus naik seiring waktu: API 21 (ViMusic, 2022), API 24
    (InnerTune, OuterTune v0.10.1), API 26 (OuterTune v0.11.1, SimpMusic),
    API 28 (Spotube v6.0.0).
11. Ukuran APK sebanding dengan scope: InnerTune 6,5 MiB (Android saja,
    fokus), OuterTune v0.10.1 9 MiB, SimpMusic 53 MiB (KMP + Desktop + banyak
    fitur), Spotube v5.1.2 128,6 MB (sekunder). Scope kecil berarti APK
    kecil. InnerTune membuktikan client YouTube Music yang lengkap bisa muat
    di 6,5 MiB bila scope dijaga.
12. Android Auto didukung InnerTune, SimpMusic, Spotube, dan ViMusic.

Yang paling relevan untuk stack Flutter kami (tidak ada referensi arsitektur
Flutter langsung di kelompok ini):

- Pola pemutaran yang wajib ditiru strukturnya: player + foreground service
  mediaPlayback + MediaSession + notifikasi media. Padanan Flutter yang umum
  adalah just_audio + audio_service, tetapi ini rekomendasi tim yang perlu
  verifikasi lanjutan di Paket 2, bukan temuan dari source kompetitor.
- Pisahkan cache streaming dari file unduhan.
- Pakai database relasional untuk library (bukan JSON di key-value store,
  pelajaran dari OOM Spotube). Padanan Flutter yang umum adalah drift atau
  sqlite, rekomendasi tim yang perlu verifikasi lanjutan.
- Pisahkan modul pengambilan stream dari modul pemutar, supaya satu jalur
  bisa diganti tanpa merombak app (pola modul `innertube` terpisah di
  InnerTune dan ViMusic).
- Android minimum yang masuk akal untuk app baru: API 26 (Android 8.0),
  titik tengah kelompok ini (SimpMusic dan OuterTune v0.11.1). API 24 masih
  dipakai InnerTune; API 28 adalah yang paling agresif (Spotube v6.0.0).

## Lisensi: GPL-3.0 dan clean-room

Kelima file LICENSE dibaca langsung dari repo resmi pada 15 November 2026:
InnerTune GPL-3.0, OuterTune GPL-3.0, Spotube AGPL-3.0-or-later, ViMusic
GPL-3.0, SimpMusic GPL-3.0. Empat dari lima memakai GPL-3.0. Tidak ada yang
memakai MIT atau Apache-2.0 untuk app utamanya. Spotube dulu BSD-4-Clause
dan berubah ke AGPL-3.0-or-later di v6.

### Kalau kami fork atau menyalin kode GPL

Teks GPL-3.0, bagian 5, mengatur karya yang diubah: karya yang diubah wajib
memuat pemberitahuan jelas bahwa kami mengubahnya beserta tanggal yang
relevan; karya wajib memuat pemberitahuan jelas bahwa karya dirilis di bawah
lisensi ini; "You must license the entire work, as a whole, under this
License to anyone who comes into possession of a copy", seluruh karya sebagai
satu kesatuan wajib dilisensikan di bawah GPL-3.0; antarmuka pengguna
interaktif wajib menampilkan Appropriate Legal Notices. Bagian 6: bila kami
mendistribusikan app dalam bentuk bukan source code (APK), kami wajib
menyediakan Corresponding Source, yaitu semua source code yang dibutuhkan
untuk menghasilkan, menginstal, dan menjalankan app, termasuk script build.

Artinya dalam bahasa praktis: begitu satu baris kode GPL-3.0 masuk ke dalam
app kami dan kami mendistribusikan app itu, seluruh app kami wajib GPL-3.0
dan source code-nya wajib terbuka untuk siapa pun yang menerima APK. Tidak
ada jalan untuk mengambil kode GPL lalu menutup source app kami. Kewajiban
ini berlaku saat distribusi; sekadar membaca atau mempelajari kode GPL di
komputer sendiri tidak memicu kewajiban apa pun.

### Clean-room: implementasi mandiri tanpa menyalin kode

Clean-room design adalah metode menyalin sebuah desain lewat reverse
engineering lalu menciptakannya ulang tanpa melanggar hak cipta yang melekat
pada desain aslinya. Metode ini berguna sebagai pembelaan terhadap tuduhan
pelanggaran hak cipta karena bersandar pada independent creation (penciptaan
mandiri). Cara kerjanya: satu pihak memeriksa sistem yang akan dibuat ulang
dan menulis spesifikasi, spesifikasi itu ditinjau pengacara untuk memastikan
tidak ada materi berhak cipta di dalamnya, lalu tim lain yang tidak punya
hubungan dengan pemeriksa mengimplementasikan spesifikasi itu.

Batas-batas clean-room yang relevan untuk kami:

- Clean-room melindungi dari klaim hak cipta atas kode. Clean-room tidak
  melindungi dari pelanggaran Terms of Service YouTube. Dua hal ini sumbu
  yang berbeda. Kode kami bisa 100 persen orisinal dan tetap melanggar ToS
  YouTube karena cara app mengakses InnerTube.
- Independent creation bukan pembelaan terhadap paten. Clean-room tidak bisa
  dipakai untuk menghindari batasan paten.
- Clean-room yang ketat butuh pemisahan tim dan dokumentasi spesifikasi.
  Dalam proyek kecil dengan satu owner dan tim agent, pemisahan murni sulit
  dibuktikan. Yang masih bisa kami lakukan dan perlu didokumentasikan: jangan
  pernah menyalin potongan kode dari repo GPL ke repo kami, tulis
  implementasi dari spesifikasi perilaku (endpoint apa, format
  request/response apa), dan catat sumber spesifikasi itu di repo.
- Mempelajari cara kerja InnerTube dari dokumentasi publik, spesifikasi
  komunitas, atau pengamatan terhadap lalu lintas jaringan app resmi adalah
  reverse engineering terhadap layanan YouTube, bukan terhadap kode
  kompetitor. Ini tetap masuk wilayah ToS YouTube, bukan wilayah lisensi GPL.

### Rekomendasi lisensi untuk repo kami

PENILAIAN tim C8: pakai GPL-3.0-only untuk repo app kami. Ini rekomendasi
tim, bukan keputusan owner.

Alasannya: empat dari lima kompetitor memakai GPL-3.0, jadi lisensi ini
adalah norma ekosistem; GPL-3.0-only (bukan or-later) memberi kepastian
karena syaratnya terkunci di versi 3; copyleft melindungi proyek dari fork
tertutup; F-Droid menerima GPL-3.0 tanpa masalah.

Opsi yang tim tolak: MIT atau Apache-2.0 (tidak memberi perlindungan apa pun
terhadap fork tertutup yang mengambil hasil kerja kami tanpa berbagi balik);
AGPL-3.0 (klausul network tidak memberi manfaat praktis untuk client tanpa
server, hanya menambah beban pemahaman).

Catatan praktis: bila di masa depan kami memakai satu library GPL di dalam
app, keputusan lisensi ini sudah selaras. Bila kami memakai library
berlisensi lain, periksa kompatibilitasnya dengan GPL-3.0 sebelum
memasukkannya. Library MIT, BSD, dan Apache-2.0 umumnya kompatibel dengan
GPL-3.0 sebagai dependensi, tapi verifikasi per library tetap perlu
dilakukan saat pemilihan dependensi.

## Risiko Terms of Service YouTube

### Klausul yang dilanggar

YouTube Terms of Service, berlaku 15 Desember 2023, melarang pengguna untuk:
mengakses, mereproduksi, mengunduh, mendistribusikan, atau menggunakan
bagian mana pun dari Service atau Content, kecuali sebagaimana diizinkan
secara tegas oleh Service atau dengan izin tertulis sebelumnya dari YouTube;
mengakses Service menggunakan automated means (seperti robots, botnets, atau
scrapers), kecuali untuk mesin pencari publik sesuai robots.txt atau dengan
izin tertulis sebelumnya dari YouTube; mengakali, menonaktifkan, atau
mengganggu fitur keamanan atau fitur yang mencegah pembatasan penyalinan
konten dan membatasi penggunaan Service atau Content.

YouTube API Services Developer Policies, bagian III.D.7 Undocumented
Services, menambah dua larangan yang tepat mengenai InnerTube: "You must not
use undocumented APIs without express permission" dan "You must not reverse
engineer undocumented YouTube API services or otherwise attempt to derive the
underlying source code of these API services." Kebijakan yang sama melarang
API client mengunduh, mengimpor, mencadangkan, menyimpan (cache), atau
menyimpan salinan konten audiovisual tanpa persetujuan tertulis sebelumnya,
serta menawarkan pemutaran offline.

PENILAIAN tim C8: app kami melanggar ToS YouTube di beberapa titik sekaligus.
Akses ke InnerTube adalah akses ke undocumented API tanpa izin tertulis.
Pemutaran audio tanpa iklan dan pemutaran di background adalah penggunaan di
luar yang diizinkan Service. Fitur unduh untuk offline adalah pengunduhan
konten tanpa izin tertulis. Tidak ada pembacaan yang jujur terhadap teks di
atas yang membuat app ini patuh. README InnerTune, OuterTune, dan SimpMusic
semuanya mencantumkan disclaimer bahwa mereka tidak berafiliasi dengan
YouTube atau Google; disclaimer semacam itu tidak menghapus pelanggaran ToS,
hanya memperjelas status tidak resmi.

### Risiko praktis

Risiko terbesar dalam praktik bukan gugatan, melainkan app yang rusak
berulang kali. YouTube mengubah sisi servernya tanpa pemberitahuan, dan
setiap perubahan bisa memutus client tidak resmi. Bukti nyata:

- InnerTune issue #1792 berjudul "[SOLUTION] Unknown error / Song not
  playing / Youtube API broken". Pengguna melaporkan lagu tidak bisa diputar
  karena YouTube mengubah API.
- Diskusi InnerTune #1310 mencatat "Login feature isn't working" sebagai
  known issue pada rilis 0.5.4.
- README SimpMusic memperingatkan pengguna secara terbuka: "Because of
  depending on YouTube Music, the player error will happen and it's normally,
  please don't ask me about the stable state of this app."
- MakeUseOf, mengulas OuterTune 12 Oktober 2025, menulis bahwa karena app
  bergantung pada akses tidak resmi yang di-reverse-engineer ke sistem
  YouTube, perubahan apa pun di sisi Google bisa merusak fungsi untuk
  sementara.

Risiko kedua adalah penindakan teknis dari YouTube. Pada 15 April 2024,
YouTube mengumumkan memperkuat penindakan terhadap aplikasi pihak ketiga
yang melanggar ToS, khususnya app pemblokir iklan. Pengguna app semacam itu
"may experience buffering issues or see the error 'The following content is
not available on this app'". YouTube juga menegaskan hanya mengizinkan
aplikasi pihak ketiga memakai API-nya bila mengikuti API Services Terms of
Service, dan bila menemukan app yang melanggar, "we will take appropriate
action to protect our platform, creators, and viewers".

Risiko ketiga adalah risiko akun bila fitur login dipakai. ToS memberi
YouTube hak menghentikan akun yang melanggar ketentuan. Namun riset ini tidak
menemukan bukti terdokumentasi bahwa Google pernah memblokir akun pengguna
semata-mata karena memakai client musik pihak ketiga seperti InnerTune atau
ViMusic. Yang terdokumentasi adalah kerusakan fitur login, bukan pemblokiran
akun. PENILAIAN tim C8: karena tidak ada bukti, kami tidak boleh menulis di
README bahwa login "aman", dan kami juga tidak boleh menulis bahwa login
"pasti diblokir". Kalimat yang jujur: login memakai akun Google di client
tidak resmi membawa risiko yang tidak bisa kami ukur, dan pengguna menanggung
risiko itu sendiri.

### Preseden hukum yang bisa diverifikasi

Preseden terdekat dan terverifikasi adalah YouTube Vanced. Pada 13 Maret
2022, tim Vanced mengumumkan penghentian proyek setelah menerima surat
cease-and-desist dari tim legal Google. Vanced adalah salinan termodifikasi
dari app YouTube resmi Android, didistribusikan sebagai APK jadi dengan nama
dan logo bergaya YouTube, memblokir iklan dan membuka fitur Premium tanpa
berlangganan. Tuntutan dalam surat itu, menurut administrator Discord Vanced
kepada The Verge: hapus semua referensi ke "YouTube", ganti logo, dan hapus
semua link terkait produk YouTube. Tidak ada gugatan yang diajukan ke
pengadilan; proyek berakhir karena surat itu saja.

Perbedaan Vanced dengan proyek kami penting dan perlu dicatat. Vanced
mendistribusikan ulang kode milik Google (app resmi yang dimodifikasi) dan
memakai merek dagang YouTube. Proyek kami menulis kode sendiri dari nol dan
tidak memakai nama, logo, atau merek YouTube. Jadi preseden Vanced membuktikan
Google bersedia mengirim surat hukum terhadap client tidak resmi yang besar,
tapi tidak membuktikan Google akan melakukan hal yang sama terhadap client
clean-room yang tidak memakai mereknya.

Preseden kedua adalah youtube-dl. Pada 23 Oktober 2020, RIAA mengirim
takedown DMCA ke GitHub dengan argumen youtube-dl melanggar ketentuan
anti-circumvention DMCA section 1201. GitHub awalnya mematuhi dan menghapus
repo beserta 17 fork. Pada 16 November 2020, GitHub mengembalikan repo
setelah EFF mengirim surat yang membantah argumen RIAA, dan GitHub kemudian
merevisi proses klaim DMCA serta membuat dana pembelaan developer sebesar 1
juta dolar AS.

Pelajaran dari youtube-dl: tekanan hukum terhadap tool semacam ini biasanya
datang lewat platform hosting (GitHub), bukan lewat gugatan langsung ke
developer, dan tool dengan kegunaan non-pelanggaran yang substansial bisa
dipulihkan. Tapi prosesnya tetap memakan waktu (24 hari repo hilang) dan
bergantung pada dukungan lembaga seperti EFF.

Tentang gugatan pengadilan terhadap client clean-room seperti NewPipe,
InnerTune, ViMusic, atau SimpMusic: tidak ada bukti yang ditemukan. Riset
ini mencari dengan kata kunci "Google lawsuit NewPipe InnerTube third party
YouTube client" dan tidak menemukan satu pun gugatan yang diajukan Google
terhadap client semacam itu. NewPipe, InnerTune, ViMusic, dan SimpMusic
masih ada di GitHub dan F-Droid sampai hari pengecekan ini. Ketidakadaan
bukti bukan bukti ketidakadaan; ini hanya menyatakan apa yang ditemukan riset
ini.

Satu laporan sekunder menyebut app Echo Music (client YouTube Music lain)
menerima legal takedown notice pada Agustus 2026 dan dipulihkan setelah
mengubah kode dan dokumentasi, tanpa menyebut pengirim suratnya. Tim tidak
bisa memverifikasi klaim ini dari sumber primer, jadi klaim ini dicatat
sebagai laporan yang belum terverifikasi, bukan sebagai preseden yang
terbukti.

## Preseden cease-and-desist Spotify ke Spotube (2025)

Fakta yang terverifikasi dari beberapa sumber sekunder yang saling konsisten:

- Pada awal 2025, developer Spotube menerima surat cease-and-desist dari
  Spotify USA Inc. dan Spotify AB. README repo diubah pada 2 Mei 2025 untuk
  mengumumkan hal ini.
- Isi surat, sebagaimana dikutip dari pengumuman developer: menggabungkan
  Spotify API dengan konten YouTube untuk memungkinkan pemutaran musik tanpa
  iklan melanggar perjanjian Spotify dan dapat melanggar hak pemegang hak
  musik.
- Akibatnya: developer menghentikan distribusi resmi semua versi yang
  bergantung pada API Spotify, menghapusnya dari GitHub, app store, dan
  situs resmi. Login Spotify, playlist tersinkronisasi, dan track tersimpan
  tidak lagi didukung.
- Spotube lalu ditulis ulang total sebagai platform berbasis plugin (versi
  5). App inti tidak lagi berisi integrasi Spotify; fungsi Spotify hanya
  bisa ditambahkan kembali lewat plugin komunitas pihak ketiga.
- Sumber primer (arsip Wayback Machine atas README Spotube tanggal 3 Mei
  2025) tidak bisa diakses dalam riset ini karena server arsip menolak akses
  dengan HTTP 403. Jadi ringkasan di atas bersandar pada peliputan sekunder,
  bukan pada teks surat aslinya. Isi surat yang sebenarnya tidak pernah
  dipublikasikan secara penuh sejauh yang ditemukan riset ini.

Pelajaran untuk kami:

- Jangan sentuh API Spotify dalam bentuk apa pun, termasuk untuk metadata,
  lirik, atau gambar sampul. Ini sudah menjadi keputusan proyek dan preseden
  ini menguatkannya.
- Pola yang memicu surat Spotify adalah kombinasi spesifik: metadata dari
  satu platform dipasangkan dengan audio dari platform lain untuk melewati
  langganan. App kami tidak melakukan kombinasi itu karena kami hanya memakai
  YouTube/YouTube Music, tapi pola pikirnya sama: mengambil nilai dari satu
  layanan untuk menggantikan layanan berbayarnya adalah pemicu tindakan
  hukum.
- Surat cease-and-desist saja, tanpa gugatan, sudah cukup memaksa penulisan
  ulang total dan penghentian distribusi selama berbulan-bulan. Dampaknya
  nyata walau tidak ada pengadilan yang terlibat.
- Arsitektur plugin memindahkan risiko ke pengguna dan pembuat plugin, tapi
  tidak menghilangkannya. Sumber sekunder mencatat bahwa memakai plugin
  Spotify masih membawa risiko akun Spotify ditandai atau diblokir (klaim
  sekunder, belum diverifikasi dari sumber primer Spotify).

## Privasi

### Desain yang direncanakan

App dirancang tanpa akun, tanpa telemetri, dan semua data hanya lokal di HP
pengguna. Desain ini sejalan dengan kompetitor yang sejenis: README Spotube
mencantumkan "No telemetry, diagnostics or user data collection" sebagai
fitur; README SimpMusic menyatakan versi FOSS tidak punya tracker atau server
pihak ketiga untuk mengumpulkan data pengguna, dan data crash hanya
dikumpulkan di versi Full lewat Sentry; InnerTune tidak menyebut pengumpulan
data dalam README-nya, dan app tersedia di F-Droid tanpa flag Tracking.

PENILAIAN tim C8: desain tanpa akun dan tanpa telemetri adalah keputusan yang
benar dan harus dipertahankan sebagai janji yang bisa diverifikasi. Karena
source code terbuka, siapa pun bisa memeriksa bahwa tidak ada kode pengiriman
data. Janji privasi yang bisa diperiksa jauh lebih kuat daripada janji yang
hanya tertulis di dokumen.

### Data yang keluar dari HP

"Tanpa telemetri" tidak berarti "tidak ada data yang keluar". App ini,
menurut desainnya, harus berkomunikasi dengan server YouTube/Google untuk
berfungsi. Data berikut keluar dari HP pengguna saat app dipakai:

- Setiap pencarian, permintaan halaman artis/album/playlist, dan permintaan
  stream audio dikirim ke server Google/YouTube (endpoint InnerTube dan
  server stream). Google melihat alamat IP pengguna, isi permintaan (apa
  yang dicari dan diputar), waktu permintaan, dan metadata teknis seperti
  user agent dan model client yang dipakai app.
- Bila fitur login dipakai, Google juga melihat aktivitas itu terikat ke akun
  Google pengguna, termasuk riwayat dengar bila app mengirimkannya kembali.
  README SimpMusic menyebut fitur opt-in "Send back to Google" yang mengirim
  riwayat dengar ke YouTube Music Tracking API untuk rekomendasi yang lebih
  baik. App kami perlu memutuskan secara sadar apakah fitur semacam ini ada
  atau tidak; rekomendasi tim C8 adalah tidak ada.
- Bila app memakai sumber lirik pihak ketiga (misalnya LRCLIB, seperti yang
  dipakai SimpMusic dan InnerTune), penyedia lirik itu melihat alamat IP
  pengguna dan judul lagu yang dicari liriknya.
- Bila app memakai sumber gambar sampul atau metadata tambahan, penyedia itu
  melihat hal yang sama.
- Tidak ada data yang dikirim ke server milik kami, karena kami tidak punya
  server. Ini adalah fakta arsitektur, bukan janji kebijakan.

PENILAIAN tim C8: pernyataan privasi yang jujur harus menyebut Google/YouTube
sebagai pihak yang menerima data, bukan hanya menyatakan "kami tidak
mengumpulkan data". Pengguna perlu tahu bahwa privasi mereka terhadap kami
penuh, tapi privasi mereka terhadap Google terbatas pada apa yang Google
sendiri janjikan di kebijakan privasinya.

### Yang wajib ditulis di kebijakan privasi dan README

Kebijakan privasi perlu ada sebagai file PRIVACY_POLICY.md di repo, mengikuti
contoh Spotube, tapi ditulis ulang agar sesuai fakta app kami. Isi yang wajib
ada:

- Data yang kami kumpulkan: tidak ada. Tidak ada akun, tidak ada telemetri,
  tidak ada analytics, tidak ada crash report otomatis.
- Data yang tersimpan lokal: daftar putar, riwayat dengar, lagu yang
  diunduh, dan pengaturan. Semua tersimpan di penyimpanan HP pengguna dan
  tidak pernah dikirim ke mana pun oleh kami.
- Pihak ketiga yang menerima data: Google/YouTube menerima alamat IP, kueri
  pencarian, dan permintaan stream setiap kali app dipakai. Tautkan ke
  kebijakan privasi Google. Bila ada sumber lirik atau metadata lain,
  sebutkan satu per satu dengan tautan kebijakannya masing-masing.
- Login: jelaskan apa yang terjadi bila pengguna login (cookie/token
  tersimpan lokal, Google melihat aktivitas terikat akun), dan jelaskan bahwa
  login bersifat opsional.
- Penghapusan data: menghapus app menghapus semua data lokal. Tidak ada data
  di server kami yang perlu diminta penghapusannya, karena tidak ada server.
- Anak-anak: app tidak ditujukan khusus untuk anak di bawah umur, dan kami
  tidak mengumpulkan data dari siapa pun, termasuk anak.
- Kontak: alamat email atau kanal yang bisa dihubungi pengguna untuk
  pertanyaan privasi.
- Tanggal berlaku kebijakan dan cara pemberitahuan perubahan.

README wajib memuat disclaimer non-afiliasi, mengikuti pola yang dipakai
ketiga kompetitor. Kalimat InnerTune bisa dijadikan pola (bukan disalin kata
per kata tanpa penyesuaian): proyek ini tidak berafiliasi dengan, didanai,
diotorisasi, didukung oleh, atau dengan cara apa pun terkait dengan YouTube,
Google LLC, atau afiliasinya.

README juga wajib memuat disclaimer legal singkat: app ini adalah client
tidak resmi, memakai akses tidak resmi ke YouTube Music, melanggar Terms of
Service YouTube, dan dapat berhenti berfungsi kapan saja bila YouTube
mengubah layanannya. Menulis ini secara terbuka lebih baik daripada
membiarkan pengguna mengira app ini resmi atau stabil.

Satu hal yang belum diverifikasi tim: kewajiban berdasarkan UU Perlindungan
Data Pribadi Indonesia (UU PDP) untuk app yang dipakai pengguna Indonesia.
Karena kami tidak mengumpulkan data pribadi, kewajiban kami kemungkinan
minimal, tapi tim belum memeriksa teks UU-nya dari sumber live. Owner perlu
memastikan hal ini sebelum rilis, atau menugaskan tim lain untuk
memeriksanya.

## Distribusi: Play Store dan F-Droid

### Kenapa app ini tidak bisa masuk Play Store

Google Play Developer Program Policy, bagian Intellectual Property,
menyatakan Google tidak mengizinkan app atau akun developer yang melanggar
hak kekayaan intelektual pihak lain, termasuk hak cipta dan merek dagang, dan
tidak mengizinkan app yang mendorong pelanggaran hak kekayaan intelektual.
Bagian Unauthorized Use of Copyrighted Content secara spesifik menyebut dua
contoh yang tepat mengenai app kami: "Streaming apps that allow users to
download a local copy of copyrighted content without authorization" dan "Apps
that encourage users to stream and download copyrighted works, including
music and video, in violation of applicable copyright law".

Bagian Device and Network Abuse menambah larangan kedua: app tidak boleh
mengakses atau memakai layanan/API dengan cara yang melanggar Terms of
Service layanan itu. Contoh yang ditulis Google sendiri: app tidak boleh
mengunduh, memonetisasi, atau memutar video YouTube dengan cara yang
melanggar YouTube API Services Terms of Service, misalnya menghilangkan iklan
atau melewati batasan pemutaran.

Bukti dari lapangan: tidak satu pun dari lima kompetitor ada di Play Store.
SimpMusic menyatakan di FAQ-nya bahwa kebijakan Play berkonflik dengan cara
app melakukan streaming musik. OuterTune menyatakan di situsnya bahwa app
bernama OuterTune yang ada di Play Store berasal dari developer lain.
Preseden lama: GTunes Music Downloader, app pengunduh MP3, dihapus dari Play
Store sekitar 2015 karena mendistribusikan musik tanpa lisensi.

PENILAIAN tim C8: mencoba masuk Play Store bukan hanya akan ditolak, tapi
juga berisiko bagi akun developer owner. Google mencatat pelanggaran di
tingkat akun dan pelanggaran berulang dapat menyebabkan penghentian akun
developer beserta app lain di akun itu. Jangan pernah mengajukan app ini ke
Play Store dengan akun Google yang juga dipakai untuk hal penting lain.

### Syarat masuk F-Droid

F-Droid adalah jalur distribusi yang realistis. Inclusion Policy resmi
F-Droid, dibaca langsung 15 November 2026, menetapkan syarat berikut:

- Semua app di repo utama wajib Free, Libre and Open Source Software
  (FLOSS), misalnya di bawah lisensi GPL atau Apache.
- Semua dependensi biner, termasuk file JAR, wajib berasal dari kompilasi
  source atau unduhan repo Debian. Binary yang sudah jadi hanya boleh dari
  sumber tepercaya yang diizinkan.
- Implementasi library proprietary untuk tracking atau iklan dan tool
  analytics seperti Google Play Services, Firebase, dan Crashlytics dilarang
  keras di semua app. Bila fitur semacam itu diperlukan, developer wajib
  memakai alternatif FLOSS atau build flavour yang tidak memerlukan
  dependensi itu.
- F-Droid mengompilasi app dari source code yang bisa diakses publik untuk
  memverifikasi bahwa binary yang didistribusikan cocok dengan source-nya.
  Seluruh proses build wajib memakai toolchain 100 persen FLOSS.
- App tidak boleh melanggar hak pihak ketiga, termasuk hak kekayaan
  intelektual seperti hak cipta dan merek dagang.
- F-Droid memakai label Anti-Features sebagai indikator peringatan tentang
  kebebasan pengguna atau privasi, "without necessarily disqualifying
  applications from inclusion". Label ini tidak otomatis mendiskualifikasi
  app.
- Syarat kualitas: app harus aktif dipelihara saat dimasukkan dan author
  berkomitmen memberikan pemeliharaan berkelanjutan; app harus berfungsi dan
  mengimplementasikan semua fitur yang dideskripsikan; app harus berguna bagi
  pengguna akhir; app harus memberikan nilai unik (app yang hanya rebranding
  minor dari app lain yang aktif dipelihara tidak diterima); app harus sudah
  dikembangkan secara aktif selama minimal 3 bulan, kecuali bila sudah
  terbukti punya pengguna, author sudah memelihara app lain di F-Droid, atau
  app dibuat hanya untuk sebuah acara.
- Fork wajib memakai Application ID Android baru yang berbeda dari app
  aslinya, beserta perubahan nama, ikon, dan string yang sesuai.
- F-Droid tidak mendaftar untuk API key apa pun.

Tentang flag NonFreeNet: halaman Anti-Features resmi F-Droid mendefinisikan
Non-Free Network Services sebagai label untuk app yang "promote or depend
entirely on a proprietary network service". Label ini adalah peringatan bagi
pengguna, bukan penolakan. Client F-Droid menyembunyikan app berlabel
Tracking secara default, tapi tidak menyembunyikan app berlabel NonFreeNet.

App kami pasti mendapat flag NonFreeNet karena bergantung sepenuhnya pada
YouTube Music, layanan jaringan proprietary milik Google. Ini bukan masalah:
InnerTune, OuterTune, SimpMusic, dan Spotube semuanya membawa flag yang sama
dan tetap ada di F-Droid. Listing SimpMusic di F-Droid secara eksplisit
menulis "Relies on a non-free network service".

PENILAIAN tim C8: F-Droid repo utama adalah target yang tepat, dengan dua
catatan. Pertama, syarat 3 bulan pengembangan aktif berarti pengajuan tidak
bisa dilakukan pada hari pertama rilis; tim perlu merencanakan pengajuan
setelah app berjalan dan dipelihara selama minimal 3 bulan, atau mengandalkan
pengecualian bila sudah terbukti punya pengguna. Kedua, IzzyOnDroid adalah
jalur alternatif yang lebih longgar dan lebih cepat: InnerTune, OuterTune,
dan SimpMusic semuanya ada di IzzyOnDroid. Rilis awal bisa lewat GitHub dan
IzzyOnDroid sambil menunggu kelayakan F-Droid repo utama.

## Rekomendasi untuk app kami

PENILAIAN gabungan tiga tim. Daftar ini adalah pendapat tim berdasarkan riset
di atas, bukan nasihat hukum.

Hal yang BOLEH kami lakukan:

- Menulis seluruh kode app dari nol dalam Flutter, tanpa menyalin kode dari
  repo GPL mana pun.
- Memakai lisensi GPL-3.0-only untuk repo kami (rekomendasi tim, keputusan
  akhir di owner).
- Mempelajari perilaku InnerTube dari dokumentasi publik dan spesifikasi
  komunitas untuk menulis implementasi sendiri, dengan sumber spesifikasi
  dicatat di repo.
- Memakai library berlisensi MIT, BSD, atau Apache-2.0 sebagai dependensi,
  setelah memeriksa kompatibilitas masing-masing dengan GPL-3.0.
- Mendistribusikan app lewat GitHub Releases, F-Droid, dan IzzyOnDroid.
- Menulis README dan kebijakan privasi yang jujur tentang status tidak resmi
  app, pelanggaran ToS, dan data yang diterima Google.
- Memakai nama, logo, dan merek yang orisinal dan tidak menyerupai YouTube,
  YouTube Music, atau Spotify.
- Menyimpan semua data pengguna secara lokal tanpa akun dan tanpa telemetri.
- Mendorong pengguna berlangganan YouTube Premium untuk mendukung kreator,
  mengikuti contoh SimpMusic.
- Memisahkan modul pengambilan stream dari modul pemutar; memisahkan cache
  streaming dari file unduhan; memakai database relasional untuk library.

Hal yang TIDAK BOLEH kami lakukan:

- Menyalin kode apa pun dari InnerTune, OuterTune, ViMusic, SimpMusic, atau
  Spotube ke repo kami, kecuali bila kami siap menerima konsekuensi
  lisensinya (untuk kode GPL-3.0 berarti seluruh app wajib GPL-3.0 dengan
  source terbuka; untuk kode AGPL Spotube berarti kewajiban AGPL ikut
  berlaku).
- Memakai nama, logo, warna merek, atau kata "YouTube", "YouTube Music",
  atau "Spotify" di nama app, ikon, atau judul listing.
- Menyentuh API Spotify dalam bentuk apa pun, termasuk untuk metadata,
  lirik, gambar sampul, atau login.
- Mengajukan app ke Google Play Store.
- Menambahkan telemetri, analytics, crash reporting, iklan, atau SDK
  proprietary apa pun (Play Services, Firebase, Crashlytics) ke build
  F-Droid.
- Mengklaim app ini resmi, didukung, atau diotorisasi oleh Google atau
  YouTube.
- Mengklaim login di client tidak resmi "aman" atau "bebas risiko". Risiko
  akun tidak bisa kami ukur dan tidak boleh kami janjikan.
- Mengumpulkan data pengguna di server kami, atau membuat akun pengguna.
- Menjual app, memasang paywall, atau memonetisasi dengan cara apa pun.
  Proyek ini gratis dan non-komersial; monetisasi akan menambah target hukum
  dan melanggar janji proyek.
- Mengirim riwayat dengar pengguna kembali ke Google tanpa persetujuan
  eksplisit pengguna. Rekomendasi tim: jangan implementasikan fitur ini sama
  sekali.
- Menghapus atau mengubah atribusi dan pemberitahuan lisensi dari kode pihak
  ketiga yang kami pakai secara sah.
- Menghapus fitur inti tanpa jalur migrasi data, atau memakai penomoran
  versi yang membingungkan pengguna (pelajaran OuterTune).
- Menambah fitur tanpa henti sampai app selamanya berlabel beta, atau
  menganggap error player sebagai hal normal (pelajaran SimpMusic).
- Membiarkan proyek mati tanpa suksesor yang jelas (pelajaran ViMusic).
- Bergantung pada satu maintainer tanpa rilis berkala (pelajaran InnerTune).
- Merilis tanpa tes (Spotube v6 tidak punya file tes yang di-commit).

## Yang belum terverifikasi

Dicatat eksplisit, bukan ditebak:

- Tanggal commit terakhir InnerTune (yang terverifikasi: 53 commit ke branch
  `dev` sesudah v0.5.10; aktivitas repo tercatat sampai 2 November 2026 di
  GitHub Explorer, tapi itu hitungan event, bukan tanggal commit).
- Versi ViMusic yang tercantum di F-Droid saat ini (halaman F-Droid ViMusic
  mengembalikan HTTP 404 pada 15 November 2026).
- Ukuran APK ViMusic v0.5.4 dari sumber primer (hanya angka sekunder
  2.698.300 byte dari anygen.io).
- Isi lengkap surat cease-and-desist Spotify ke Spotube (arsip Wayback
  Machine README Spotube 3 Mei 2025 tidak bisa diakses, HTTP 403).
- Laporan takedown hukum terhadap Echo Music Agustus 2026 (satu sumber
  sekunder, Grokipedia, tanpa nama pengirim).
- Kewajiban UU PDP Indonesia untuk app ini (belum diperiksa dari sumber
  live, perlu pengecekan lanjutan sebelum rilis).
- Mekanisme download Spotube v6.0.0 dan OuterTune era YTM v0.10.1; download
  eksplisit ViMusic; ukuran APK Spotube v6.0.0 dan OuterTune v0.11.1; alasan
  Spotube pindah dari Flutter; nama class service pemutar dan database
  OuterTune; versi Gradle SimpMusic dan AGP/Gradle ViMusic dari sumber
  primer; klaim client `ANDROID_VR` OuterTune (sekunder); detail internal
  `ExoDownloadService` InnerTune; manifest ViMusic.

## Daftar sumber

Semua sumber diakses dan dibaca 15 November 2026, kecuali dinyatakan lain.

Repo dan rilis:

- https://github.com/z-huang/InnerTune
- https://github.com/OuterTune/OuterTune
- https://github.com/team-spotube/spotube (redirect dari KRTirtho/spotube)
- https://github.com/vfsfitvnm/ViMusic
- https://github.com/maxrave-dev/SimpMusic
- https://github.com/team-spotube/spotube/blob/master/CHANGELOG.md
- https://github.com/z-huang/InnerTune/releases/tag/v0.5.10
- https://github.com/OuterTune/OuterTune/releases
- https://github.com/vfsfitvnm/ViMusic/issues/1371
- https://github.com/z-huang/InnerTune/issues/1792
- https://github.com/z-huang/InnerTune/discussions/1310
- https://github.com/Jigen-Ohtsusuki/ViMusic/releases

File source yang dibaca (arsitektur):

- https://github.com/z-huang/InnerTune/blob/dev/app/src/main/AndroidManifest.xml
- https://github.com/z-huang/InnerTune/blob/dev/app/src/main/java/com/zionhuang/music/playback/MusicService.kt
- https://github.com/z-huang/InnerTune/blob/dev/innertube/build.gradle.kts
- https://github.com/OuterTune/OuterTune/blob/lite/app/build.gradle.kts
- https://github.com/OuterTune/OuterTune/blob/v0.10.1/app/build.gradle.kts
- https://github.com/OuterTune/OuterTune/blob/lite/Modules.md
- https://github.com/vfsfitvnm/ViMusic/blob/master/app/src/main/java/it/vfsfitvnm/vimusic/service/PlayerService.kt
- https://github.com/vfsfitvnm/ViMusic/blob/master/app/src/main/java/it/vfsfitvnm/vimusic/Database.kt
- https://github.com/maxrave-dev/SimpMusic/blob/dev/CLAUDE.md
- https://github.com/maxrave-dev/SimpMusic/blob/dev/androidApp/src/main/AndroidManifest.xml
- https://github.com/maxrave-dev/SimpMusic/blob/dev/gradle/libs.versions.toml
- https://github.com/team-spotube/spotube/blob/master/AGENTS.md
- https://github.com/team-spotube/spotube/blob/master/composeApp/src/commonMain/kotlin/org/spotube/spotube/core/db/Database.kt
- https://github.com/team-spotube/spotube/blob/master/composeApp/src/androidMain/kotlin/org/spotube/spotube/media/PlaybackService.kt

Lisensi:

- https://github.com/z-huang/InnerTune/blob/dev/LICENSE
- https://github.com/OuterTune/OuterTune/blob/lite/LICENSE
- https://github.com/KRTirtho/spotube/blob/master/LICENSE
- https://github.com/vfsfitvnm/ViMusic/blob/master/LICENSE
- https://github.com/maxrave-dev/SimpMusic/blob/dev/LICENSE
- https://en.wikipedia.org/wiki/Clean_room_design

ToS YouTube dan preseden:

- https://tostracker.app/document/youtube
- https://www.platform-policy-wiki.com/platforms/YouTube_Terms_of_Service/
- https://developers.google.com/youtube/terms/developer-policies
- https://www.makeuseof.com/open-source-music-player-outertune/
- https://9to5google.com/2024/04/15/youtube-app-block-ads/?extended-comments=1
- https://www.medianama.com/2024/04/223-youtube-to-limit-video-access-via-ad-blocking-apps/
- https://www.androidauthority.com/youtube-vanced-discontinued-3132147/
- https://simple.wikipedia.org/wiki/YouTube_Vanced
- https://en.wikipedia.org/wiki/Youtube-dl
- https://9to5google.com/2020/11/16/youtube-dl-github-riaa-takedown/
- https://grokipedia.com/page/Echo_Music (belum terverifikasi)

Spotube dan Spotify:

- https://en.linuxadictos.com/Spotify-contacts-the-Spotify-developer-who-can-no-longer-use-its-API.-The-app-will-be-rewritten..html
- https://www.drmare.com/spotify-music/spotube-review.html
- https://www.viwizard.com/spotify-music-tips/spotube-mod-apk.html
- https://www.noteburner.com/spotify-music-tips/spotube-not-working-alternatives.html

Privasi, Play Store, F-Droid:

- https://github.com/team-spotube/spotube/blob/master/PRIVACY_POLICY.md
- https://storage.googleapis.com/support-kms-prod/N2uMgGz8Dytu1V4JguICeo9iYJZ76uYxWLMO
- https://support.google.com/googleplay/android-developer/answer/17105854
- https://f-droid.org/docs/Inclusion_Policy/
- https://f-droid.org/docs/Anti-Features/
- https://f-droid.org/packages/com.zionhuang.music
- https://f-droid.org/packages/com.dd3boh.outertune/
- https://f-droid.org/packages/com.maxrave.simpmusic/
- https://apt.izzysoft.de/fdroid/index/apk/com.zionhuang.music
- https://apt.izzysoft.de/fdroid/index/apk/com.dd3boh.outertune?repo=main
- https://apt.izzysoft.de/fdroid/index/apk/com.maxrave.simpmusic/
- https://h5.2113.net/apps/spotube.html
- https://h5.2113.net/apps/simpmusic.html
- https://h5.2113.net/apps/outertune.html
- https://fone.tips/gtunes/

Lainnya:

- https://www.anygen.io/showcase/vi-music-github/index.html
- https://newreleases.io/project/github/maxrave-dev/SimpMusic/release/v2.5.0
- https://www.simpmusic.org/blogs/new-update-simpmusic-v250
- https://appsgit.com/mobile-apps/simpmusic
- https://appsgit.com/mobile-apps/category/youtube-clients
- https://appsgit.com/desktop-apps/spotube
- https://alternativeto.net/news/2026/11/spotube-v6-arrives-with-a-complete-redesign-android-auto-support-and-agpl-3-0-relicense/
- https://ghe.derekchia.com/repo/z-huang/InnerTune
- https://outertune.en.uptodown.com/android/download

## Checklist 7 skill anti-slop

- local-design-taste-frontend: dokumen riset, bukan landing page; yang
  dipakai adalah aturan copy self-audit, semua angka dicek ke sumber live
  sebelum ditulis, struktur ringkasan dulu lalu detail.
- local-impeccable: mode dokumen adalah Read; satu kompetitor satu bagian
  dengan urutan yang sama di tiap bagian; setiap klaim teknis membawa URL
  file sumber dan tanggal cek.
- local-humanizer: kalimat ditulis seperti penjelasan ke sesama engineer,
  tanpa frasa pembuka robotik dan tanpa penutup kosong, tanpa pola
  not-X-but-Y.
- local-stop-slop: tidak ada kata pengisi ("sangat", "penting sekali",
  "komprehensif"); setiap paragraf membawa fakta baru.
- local-no-ai-slop: tidak ada klaim berlebihan, tidak ada pola "bukan hanya
  X tetapi juga Y", tidak ada daftar fitur yang dikarang, tidak ada kata
  dari daftar larangan (delve, leverage, robust, cutting-edge).
- local-avoid-ai-writing: istilah teknis dipertahankan dalam bahasa Inggris
  aslinya, nama library dan class disalin persis dari source, tanpa
  atribusi samar; setiap angka menyebut sumber dan tanggal ceknya.
- local-anti-slop: tidak ada karakter em dash di seluruh dokumen; klaim yang
  tidak terverifikasi ditulis apa adanya di bagian khusus, bukan ditebak;
  penilaian tim diberi label PENILAIAN, bukan disamarkan sebagai fakta.
