# PRD v1: Aplikasi Musik Android Gratis, Tanpa Iklan, Bisa Offline

**Tanggal tulis:** 15 November 2026.
**Status:** Fase 1 selesai untuk dokumen ini. Belum ada kode, belum ada repo, belum ada nama app final (nama diputuskan di Paket 4).
**Dokumen acuan:** `docs/riset-kompetitor.md` (tanggal cek 15 November 2026) dan `docs/arsitektur.md` (tanggal cek 15 November 2026). Semua angka arsitektur di PRD ini disalin dari kedua dokumen itu.
**Sumber gabungan:** 6 laporan tim Paket 3 (total 8.062 baris) di `hidden_files/tim/`: D1 Product Management, D2 User Research, A12 UI/UX dan Design System, B1-3, B4-6, B7-11. PRD ini adalah ringkasan keputusan yang mengikat; detail perilaku lengkap tiap fitur ada di laporan tim masing-masing, dan bila ada selisih antara laporan tim dan PRD ini, PRD ini yang menang karena PRD ini sudah menyelesaikan konflik antar tim.

## Otoritas keputusan

Owner mendelegasikan penuh pada 15 November 2026 20:55 WIB: semua keputusan diputuskan sendiri dengan standar hasil terbaik, semaksimal mungkin, anti pengorbanan, termasuk nama app. Karena itu seluruh keputusan di PRD ini berstatus DIPUTUSKAN oleh koordinator atas otoritas delegasi tersebut, bukan "menunggu owner". Owner tetap bisa membatalkan keputusan apa pun. Satu-satunya butir yang benar-benar butuh tindakan owner adalah kanal kontak kebijakan privasi (D9), karena tim tidak bisa mengarang alamat kontak publik.

## Cara baca

- **USULAN** berarti angka atau pilihan itu adalah usulan tim dengan alasan tertulis, dan boleh diubah koordinator atau owner dengan alasan baru. Tanpa label USULAN, angka itu dikutip dari arsitektur atau riset kompetitor, atau sudah diputuskan koordinator.
- **Target** berarti angka yang dituju, bukan janji dan bukan hasil ukur. Target diuji di Fase 2 dan tidak boleh diturunkan diam-diam bila pengukuran pertama lebih rendah.
- Copy yang menghadap pengguna ditulis dalam tanda kutip dan memakai bahasa Indonesia sehari-hari, tanpa istilah teknis. Istilah teknis (itag, InnerTube, drift, audio_service) hanya muncul di penjelasan untuk tim.
- Kata "cache" tidak pernah tampil di copy pengguna. Kata "perpustakaan" tidak pernah tampil di copy pengguna; pakai "Library". Label kanonis untuk tombol refresh config remote adalah "Periksa pembaruan" di semua tempat.

## 1. Visi

Satu app pemutar musik Android yang gratis, tanpa iklan, dan bisa dipakai offline, untuk orang Indonesia yang sering kehabisan kuota atau sinyal. App ini adalah client: tidak menyimpan lagu sendiri, mengambil audio dari YouTube dan YouTube Music lewat akses tidak resmi (InnerTube), menyimpan lagu di HP lewat unduhan dan cache, dan tidak punya server, akun, atau telemetri.

Tiga dari lima app sejenis mati atau membeku (InnerTune tanpa rilis lebih dari 2 tahun, ViMusic diarsipkan 15 Maret 2026, OuterTune berhenti untuk YouTube Music). App ini dibangun supaya tidak bernasib sama: arsitektur tahan rusak saat YouTube berubah, backup yang kompatibel selamanya, dan kode yang bisa dipelihara satu orang.

### Kondisi "v1 selesai" (semua wajib terpenuhi)

1. Enam spike ekstraksi arsitektur bagian 3.6 lolos, atau jalur cadangan sudah dipilih dengan bukti bila spike gagal.
2. Semua fitur Must (bagian 5) berfungsi di APK rilis dan lolos kriteria K1-K15 (bagian 8).
3. Siklus keamanan Red-Blue-Red mencapai nol temuan kritis, tinggi, dan sedang (maks 5 ronde).
4. `flutter analyze` tanpa warning, dan tes jalur resolve, fallback, unduhan, dan migrasi lolos.
5. Dokumen rilis lengkap: README, PRIVACY_POLICY.md, CHANGELOG, metadata F-Droid, dan catatan rilis GitHub dengan checksum.
6. Owner menyetujui APK rilis setelah mencoba sendiri. Gate ini tidak bisa digantikan tes otomatis.

## 2. Persona

Empat arketipe, tanpa nama atau umur karangan. Tiap persona dilabeli mana yang bukti dan mana yang asumsi.

**P1. Pendengar yang sering tanpa internet.** Bukti: motivasi owner sendiri (offline saat tidak ada internet). Kebutuhan inti: unduhan yang bisa diandalkan, pemutaran offline yang tidak pernah mengecewakan, pesan jelas saat lagu belum tersimpan. Asumsi: memakai HP Android kelas menengah dan mendengar musik tiap hari.

**P2. Pengguna HP ruang dan memori sempit.** Bukti: ukuran APK kompetitor (ViMusic sekitar 2,6 MB, InnerTune 6,5 MiB) dan crash OOM Spotube issue 3193. Kebutuhan inti: APK kecil (target maks 25 MB per ABI), batas cache yang bisa diatur, hitungan ruang yang jujur, tidak ada memori yang membengkak diam-diam. Asumsi: HP RAM 3 GB mewakili perangkat awal (A3).

**P3. Pendengar yang sudah pindah app berkali-kali.** Bukti: InnerTune beku lebih dari 2 tahun, ViMusic diarsipkan, backup OuterTune 0.11.x tidak kompatibel dengan 0.10.x. Kebutuhan inti: backup yang bisa dipulihkan selamanya, antrean yang tidak hilang saat app ditutup, pesan jujur saat app rusak karena YouTube berubah. Asumsi: pengguna ini pernah kehilangan playlist karena app ditinggalkan pengembangnya.

**P4. Pengguna baru dari luar Play Store.** Bukti: tidak satu pun kompetitor ada di Play Store; distribusi app ini adalah GitHub dan F-Droid. Kebutuhan inti: pemasangan dari APK yang tidak membingungkan, penjelasan jujur soal status tidak resmi, dan app yang langsung berguna tanpa login. Asumsi: pengguna ini belum pernah memasang app dari luar Play Store.

## 3. User journey

Lima alur utama, tiap alur merujuk ke spesifikasi fitur dan arsitektur.

**J1. Cari dan putar pertama.** Pengguna baru membuka app, melihat beranda terisi tanpa login, mengetik judul lagu di tab Cari, melihat saran saat mengetik, mengirim kueri, mengetuk lagu, dan lagu berbunyi dalam target 2 detik di koneksi baik. Alur ini memakai B1.1, B1.2, B2.1, dan B2.8.

**J2. Unduh lalu putar offline.** Pengguna mengunduh lagu dari dialog unduh (pilih kualitas, lihat perkiraan ukuran), melihat progress di tab Unduhan, mematikan internet, dan lagu tetap berbunyi dari file lokal. Alur ini memakai B3.1, B3.2, B3.3, dan B3.6.

**J3. Buat playlist.** Pengguna membuat playlist dari Library, menambah lagu dari hasil cari dan dari lagu yang sedang diputar, mengubah urutan dengan seret, dan playlist tersimpan di database lokal. Alur ini memakai B4.1 dan B4.2.

**J4. Lanjutkan setelah app ditutup.** Pengguna menutup app di tengah lagu, membukanya lagi besok, melihat lagu terakhir di mini-player, menekan putar, dan lagu lanjut dari posisi tersimpan dengan antrean yang utuh. Alur ini memakai B2.3 dan B2.7.

**J5. Hadapi lagu gagal karena YouTube berubah.** Pengguna membuka app saat YouTube baru berubah, melihat banner jujur di beranda (bukan layar kosong misterius), menekan "Periksa pembaruan", dan bila belum ada perbaikan, tetap bisa memutar lagu yang sudah diunduh. Alur ini memakai B1.7, B2.6, B6.5, dan B11.5.

## 4. Cakupan v1 (MoSCoW)

Daftar ini adalah konsolidasi keputusan D1 dan spesifikasi tim B, setelah konflik diselesaikan koordinator. Butir yang berubah dari penempatan awal D1 diberi catatan.

### Must (13, wajib ada di v1)

1. **Pencarian YouTube Music** dengan saran saat mengetik, riwayat lokal, dan pencarian library lokal FTS5.
2. **Pemutaran streaming** lewat InnerTube kustom dengan fallback antar client dan resolve ulang dari videoId.
3. **Player dan antrean persisten** (maks 200 item metadata, tahan restart, tersimpan di tabel queue_items).
4. **Unduhan lagu, album, dan playlist** dengan antrean unduhan tahan restart, resume Range, dan retry otomatis.
5. **Cache streaming LRU** dan pemutaran offline penuh sesuai tabel offline-first arsitektur.
6. **Playlist lokal, library, favorit, dan riwayat putar** dengan sortir, filter, dan pencarian lokal.
7. **Beranda** dengan seksi lokal dan seksi Jelajah dari browse YouTube Music, tanpa login.
8. **Pengaturan** (kualitas unduhan, cache, unduh WiFi saja, audio, tampilan, bahasa).
9. **Notifikasi media, kontrol lock screen, headset, dan Bluetooth** dengan interupsi panggilan yang benar.
10. **Impor playlist Spotify tanpa API** (jalur file sebagai utama, jalur tautan publik sebagai sekunder yang wajib dibuktikan) dan impor backup.
11. **Info dan bantuan**: layar Tentang, kebijakan privasi, FAQ, dan laporkan kerusakan.
12. **Ketahanan**: tabel config remote, deteksi kanari, klasifikasi error, dan pesan jujur beserta tombol "Periksa pembaruan".
13. **Tautan dalam**: tautan youtu.be dan music.youtube.com yang dibagikan ke app membuka lagu atau playlist yang dituju (tambahan A12, validasi per checklist keamanan A6 butir 12).

### Should (5, masuk v1 bila memungkinkan, yang pertama dipotong bila terdesak)

1. **Lirik** tersinkron dan biasa dengan cache lokal (penyedia final belum terverifikasi; LRCLIB hanya kandidat).
2. **Sleep timer** dengan pilihan durasi dan opsi sampai lagu selesai.
3. **Equalizer Android** yang membaca kapabilitas perangkat saat runtime.
4. **Skip silence** (default mati).
5. **Backup JSON berversi** dengan impor merge (D1 menempatkannya sebagai Should; catatan koordinator: ini Should prioritas tertinggi karena backup adalah satu-satunya jalan memindahkan data tanpa akun).

Catatan: D1 menempatkan tema sebagai Should keenam. Keputusan gabung (k) menyelesaikan butir ini: v1 hanya memakai mode gelap, dan itu adalah desain yang diputuskan, bukan fitur Should. Mode terang pindah ke pasca-v1.

### Could (5, bukan v1, dicatat sebagai pekerjaan berikut)

1. **Widget layar beranda** (item spike Fase 2, bukan janji v1; butuh kode native Android).
2. **Browsing penuh Android Auto** (Auto dasar masuk v1 sebagai konsekuensi MediaSession; pencarian dan library di mobil adalah Could).
3. **Impor playlist dari URL YouTube Music.**
4. **Statistik dengar lokal** (ringkasan lagu teratas dari play_events, tanpa server).
5. **Putar otomatis lagu terkait saat antrean habis** (A12 merancang toggle-nya; tim player tidak menspesifikasikannya, dan perilaku v1 adalah berhenti di akhir antrean).

Catatan: saklar hemat data awalnya ada di daftar Could D1. Keputusan gabung (m) mempromosikannya ke v1 sebagai saklar tunggal streaming hemat data, sehingga butir ini keluar dari Could.

### Tidak masuk v1 (Won't)

1. Login YouTube Music (pasca-v1 v1.2 bila diputuskan; tanpa login, tidak ada kredensial di perangkat).
2. Minting poToken atau BotGuard.
3. Client SABR (format SABR ditolak; app tidak memilih format SABR).
4. Unduhan video (app audio saja).
5. Normalisasi volume antar lagu (`AndroidLoudnessEnhancer` adalah boost, bukan normalisasi, dan tidak boleh dilabeli normalisasi).
6. Equalizer 10 band yang konsisten lintas perangkat (butuh mpv_audio_kit atau setara).
7. Enkripsi database (sampai pemicu terpenuhi: login masuk, owner menilai profil selera sensitif, atau regulasi mewajibkan).
8. Certificate pinning ke YouTube atau Google (Google merotasi kunci tanpa pemberitahuan).
9. API Spotify dalam bentuk apa pun (permanen, bukan penundaan; preseden cease-and-desist ke Spotube 2025).
10. Akun, sinkronisasi cloud, telemetri, iklan, dan server.
11. Pemutar file audio lokal (v1.1; spesifikasi B10.2 disimpan utuh sebagai spesifikasi v1.1).
12. Discovery berbasis artis lewat jaringan (v1.1; "Lagu yang mungkin kamu suka" B1.8).
13. Sampul playlist dari galeri pengguna (pasca-v1; butuh izin baca gambar yang tidak ada di 7 izin v1).
14. Pemilih kualitas streaming 3 opsi (digantikan saklar hemat data tunggal).
15. Lirik di layar kunci dan notifikasi (pasca-v1, menunggu bukti ukur).
16. Terjemahan lirik, lirik kata per kata, dan edit lirik oleh pengguna.

## 5. Spesifikasi fitur

Bagian ini merangkum perilaku yang mengikat per area. Detail lengkap (user stories, edge cases, semua kriteria penerimaan dengan cara mengujinya) ada di laporan tim di `hidden_files/tim/`. Bila laporan tim dan PRD ini selisih, PRD ini yang menang.

### 5.1 B1. Pencarian dan Discovery

Laporan lengkap: `hidden_files/tim/fitur-pencarian-player-offline.md` (B1.1-B1.8).

- **Pencarian jaringan hanya jalan saat pengguna mengirim kueri secara eksplisit** (tombol cari di keyboard, ketuk saran, atau ketuk riwayat). Pencarian jaringan tidak jalan tiap ketikan, karena tiap ketikan yang memicu request memboroskan kuota dan memicu rate limit. Umpan balik saat mengetik berasal dari saran pencarian dan hasil lokal.
- **Saran pencarian** dari endpoint `music/get_search_suggestions` setelah debounce 300 ms, paling banyak 8 saran (USULAN). Kegagalan saran hilang diam-diam dan tidak pernah menampilkan error. Saat offline, saran berasal dari riwayat lokal yang cocok dengan awalan teks.
- **Riwayat pencarian lokal**: maks 100 query, dedup (beda kapitalisasi dianggap sama), hapus per baris dengan Urungkan 5 detik (USULAN), hapus semua dengan konfirmasi. Query yang gagal total karena jaringan tidak masuk riwayat. Riwayat MASUK file backup (B7.2 menang atas usulan B1.3).
- **Pencarian library lokal (FTS5)**: jalan di tab yang sama, kelompok hasil berlabel "Dari Library-mu", tampil sebelum hasil jaringan, jalan penuh saat offline, di background isolate drift, maks 50 item per halaman dengan keyset pagination. Lagu yang diunduh menampilkan penanda unduhan.
- **Hasil pencarian**: dikelompokkan (lagu, album, artis, playlist), tiap kelompok menampilkan paling banyak 10 item di layar hasil dengan tombol "Lihat semua" ke daftar penuh 50 per halaman. Mengetuk lagu memutar lagu itu dan memasukkan sisa hasil lagu ke antrean. Parser yang gagal di satu kelompok tidak mengosongkan kelompok lain.
- **Pagination**: keyset 50 per halaman untuk lokal, continuation token InnerTube untuk jaringan, prefetch saat 10 item sebelum akhir. Gagal memuat halaman berikut menampilkan baris "Coba lagi" tanpa menghapus hasil lama.
- **State**: kosong ("Tidak ada hasil untuk 'xxx'. Coba kata kunci lain atau periksa ejaannya."), error jaringan dengan tombol "Coba lagi", offline dengan indikator "Kamu sedang offline", loading skeleton 6 baris (maks 15 detik, lalu error). Tidak ada kode error atau istilah teknis di pesan mana pun.
- **Saat YouTube berubah**: kegagalan diklasifikasikan ke 6 penyebab (HTTP 403, respons kosong, parse gagal, hanya format SABR, timeout solver, hash player tak dikenal). Satu client gagal lalu client berikut berhasil tidak terlihat pengguna. Semua client gagal menampilkan pesan jujur sesuai penyebab. Ambang rusak tercapai (3 resolve kanari gagal berturut-turut dengan penyebab sama, atau lebih dari separuh resolve dalam 1 jam gagal) menampilkan banner di layar utama dengan tombol "Periksa pembaruan" yang memicu refresh config remote di luar TTL 6 jam.
- **Discovery tanpa login**: beranda menampilkan rak lokal (Baru diputar, Sering diputar) dan rak jaringan (Tangga lagu, Rilisan baru, Jelajahi mood dan genre) di dalam seksi Jelajah. Rak jaringan hilang saat offline tanpa pesan error. Riwayat dengar tidak pernah keluar dari HP; yang dikirim ke jaringan hanyalah permintaan halaman biasa.

### 5.2 B2. Player dan Antrean

Laporan lengkap: `hidden_files/tim/fitur-pencarian-player-offline.md` (B2.1-B2.8).

- **Urutan sumber audio**: file unduhan dulu, lalu file cache streaming, lalu resolve URL stream dari videoId. URL stream hanya ada di memori, tidak pernah disimpan di database, file, atau log. Prefetch 1 lagu ke depan (USULAN) dengan `useLazyPreparation`; perilaku pastinya wajib verifikasi Fase 2.
- **Kontrol dasar**: play, pause, seek (angka waktu mengikuti drag, seek dikirim sekali saat drag dilepas), next, prev. Prev: posisi lebih dari 3 detik kembali ke awal lagu yang sama, posisi 3 detik atau kurang pindah ke lagu sebelumnya (USULAN ambang 3 detik). Mengetuk lagu yang sedang diputar tidak me-restart lagu itu. Semua akses audio lewat `AudioPlayerPort`, tidak pernah memanggil just_audio langsung dari widget.
- **Shuffle, repeat, kecepatan, pitch, skip silence, gapless**: shuffle memakai `shuffleOrder` bawaan just_audio (mematikan shuffle mengembalikan urutan asli); repeat 3 keadaan (mati, semua, satu) yang tersinkron ke audio_service; kecepatan 7 pilihan (0,5x, 0,75x, 1x, 1,25x, 1,5x, 1,75x, 2x); pitch slider 0,5 sampai 2,0 default 1,0 (Android saja; rentang mengikuti yang diterima API, signature wajib verifikasi Fase 2); skip silence toggle default mati (Android saja); gapless perilaku bawaan engine tanpa toggle; tidak ada toggle normalisasi volume.
- **Antrean**: maks 200 item metadata di memori; tersimpan di tabel `queue_items` sebagai sumber kebenaran (player adalah cerminnya); "Tambah ke antrean" menaruh di akhir, "Putar berikutnya" menyisip sesudah lagu yang sedang diputar, mengetuk lagu dari daftar mengganti seluruh antrean; hapus dengan geser atau menu; pindah dengan drag and drop (saat shuffle aktif, drag mengubah urutan tampil dan mematikan shuffle mengembalikan urutan asli, USULAN); "Hapus semua" mengosongkan kecuali lagu yang sedang diputar; layar antrean menampilkan total durasi sisa. Antrean tahan restart app dan matinya proses Android.
- **Latar, notifikasi, headset, panggilan**: foreground service tipe `mediaPlayback`; notifikasi media (judul, artis, sampul 512 px, prev, play/pause, next, tombol tutup di tampilan lengkap); lock screen lewat MediaSession; tombol headset dan Bluetooth lewat `MediaButtonReceiver`; headset dicabut atau Bluetooth terputus menjeda seketika; panggilan masuk menjeda dan TIDAK lanjut otomatis sesudahnya; duck menurunkan volume sementara tanpa jeda; app lain yang mengambil fokus audio membuat app ini jeda dan tidak merebut fokus.
- **Sleep timer**: pilihan 5, 10, 15, 30, 45, 60 menit dan "Sampai lagu ini selesai" (USULAN); sisa waktu tampil di player dan diperbarui tiap menit; saat habis, volume turun perlahan 10 detik terakhir (fade out, USULAN), lalu pemutaran dijeda DAN foreground service dihentikan (notifikasi hilang); antrean dan posisi tersimpan di drift sehingga besok tinggal tekan play; tidak ada bunyi, pesan, atau getar saat timer habis. Opsi "sampai lagu selesai" mengunci ke lagu yang sedang diputar saat timer dipasang; menekan next atau prev membatalkan timer dengan pesan "Timer dibatalkan karena kamu ganti lagu."
- **Stream gagal di tengah lagu**: pemulihan diam-diam berurutan (tunggu 2 detik lalu resume, USULAN; resolve ulang dari videoId; pindah ke lagu berikut). Lagu yang jelas-jelas tidak tersedia (dihapus, dibatasi wilayah) langsung dilewati dengan snackbar sekali. Setelah 3 lagu berturut-turut gagal, app berhenti dan menampilkan "Lagu tidak bisa diputar sekarang. Periksa koneksi internet kamu, lalu coba lagi." dengan tombol "Coba lagi" dan "Buka lagu yang diunduh". Perintah next dari pengguna selalu menang atas pemulihan otomatis. Repeat one yang gagal berhenti dengan pesan, bukan pindah lagu.
- **Resume posisi**: posisi disimpan tiap 5 detik (USULAN) dan saat jeda, masuk latar, timer habis, dan service berhenti. Saat app dibuka lagi, mini-player menampilkan lagu terakhir dan play melanjutkan dari posisi tersimpan (lagu tidak mulai sendiri). Posisi di bawah 10 detik mulai dari awal; posisi kurang dari 10 detik dari akhir pindah ke lagu berikut (USULAN ambang 10 detik, dengan aturan proporsional sepertiga durasi untuk lagu di bawah 30 detik). Play event dicatat bila lagu diputar lebih dari 10 detik (USULAN) atau sampai selesai. Kolom posisi (`last_position_ms`, `last_played_at`, `current_position_ms`) adalah usulan skema Fase 2, bukan perubahan skema v1.
- **URL kedaluwarsa**: resolve ulang dari videoId setiap kali giliran lagu tiba atau setelah jeda panjang (misal jeda 6 jam lalu play). Antrean kemarin tetap bisa diputar hari ini. Single-flight mencegah dua resolve untuk videoId yang sama.

### 5.3 B3. Download Offline dan Cache

Laporan lengkap: `hidden_files/tim/fitur-pencarian-player-offline.md` (B3.1-B3.7).

- **Unduh lagu, album, playlist**: tombol unduh di player, menu konteks lagu, halaman album dan playlist, dan daftar library. Unduh album atau playlist menampilkan dialog ringkas ("Unduh 12 lagu (sekitar 50 MB)?") dari durasi nyata tiap lagu; lagu yang sudah diunduh dilewati. Unduhan berjalan serial 1 file dalam satu waktu (USULAN). Foreground service tipe `dataSync` dengan notifikasi progress. File ditulis `.part` lalu rename setelah ukuran cocok; tag metadata ditulis setelah selesai bila library tag sudah dipilih (audiotags atau flutter_taglib, keputusan Fase 2). Pembatalan menghapus job dan file `.part`. Dedup job memakai videoId.
- **Kualitas unduhan** (label kanonis): "Terbaik" (itag 251, Opus sampai sekitar 160 kbps, sekitar 4,2 MB per lagu 3,5 menit), "Seimbang" (itag 140, AAC 128 kbps, sekitar 3,4 MB), "Hemat data" (itag 249 atau 139, Opus sekitar 50 kbps atau AAC 48 kbps, sekitar 1,3 MB). Hitungan memakai rumus bitrate x durasi / 8 dengan asumsi durasi 210 detik. Default "Terbaik" (USULAN). Pilihan ada di Pengaturan (default) dan dialog unduh (khusus unduhan itu). Itag yang dipilih tidak tersedia turun ke itag berikut tanpa bertanya. Kata "itag", "bitrate", "codec", "Opus", "AAC", dan angka kbps tidak pernah tampil di antarmuka.
- **Antrean unduhan**: tabel `download_jobs` (videoId, kualitas, status, byte terunduh, total byte, jumlah percobaan, waktu dibuat). Resume via header `Range` dari ukuran file `.part`; server yang tidak mendukung Range memicu unduh ulang dari awal. Retry otomatis maks 3 kali dengan backoff 1 detik lalu 2 detik ditambah jitter; setelah itu job berstatus gagal sampai pengguna menekan "Coba lagi". Koneksi kembali memulai job tertunda otomatis dalam 10 detik. Layar unduhan menampilkan 4 kelompok (Mengunduh, Menunggu, Selesai, Gagal); kelompok kosong tidak tampil. Job selesai dihapus dari riwayat setelah 7 hari (USULAN); lagu tetap di library.
- **Manajemen storage**: layar Penyimpanan menampilkan total unduhan, total cache dengan batasnya, dan ruang kosong HP, semuanya dihitung dari database (bukan pemindaian filesystem). Hapus unduhan dari daftar (geser atau menu), dari player (dialog konfirmasi), atau hapus semua (dialog menyebut jumlah dan ukuran). Menghapus unduhan menghapus file dan mengosongkan `download_state`, lagu tetap di library. Sebelum unduh, app memeriksa ruang kosong: kurang dari perkiraan ditambah 100 MB (USULAN buffer 100 MB) berarti unduhan ditolak dengan pesan jelas. Ruang turun di bawah 100 MB saat unduhan berjalan menjeda unduhan otomatis dengan notifikasi. Daftar unduhan default terurut dari file terbesar (USULAN).
- **Cache streaming LRU**: default 500 MB, pilihan 250 MB, 500 MB, 1 GB, 2 GB (1 GB = 1.024 MB; hitungan kanonis sekitar 59, 119, 243, 487 lagu). Cache manual (file `.part` lalu rename), bukan `LockCachingAudioSource` yang masih eksperimental. Manifest di tabel `cache_entries`, bukan file JSON. Eviction LRU tidak pernah menyentuh file unduhan dan tidak pernah menghapus file yang sedang diputar. Cache sebagian dilanjutkan saat lagu diputar lagi (resume Range). Tombol hapus cache mengosongkan cache tanpa menyentuh unduhan. Lagu dari cache bisa diputar offline tapi tidak menampilkan penanda "Sudah diunduh" dan tidak muncul di daftar unduhan.
- **Perilaku offline penuh**: mengikuti tabel offline-first arsitektur tanpa tambah atau kurang. Yang jalan offline: putar unduhan, putar cache, browsing library, pencarian lokal FTS5, playlist, favorit, riwayat, antrean, pengaturan. Yang tidak jalan: pencarian YTM baru, streaming belum di-cache, metadata atau sampul baru, unduhan baru (masuk antrean, jalan otomatis saat online), rak jaringan, saran jaringan (diganti saran lokal), refresh config (pakai cache config terakhir yang valid). Indikator "Kamu sedang offline" tampil di layar utama dan pencarian. Tombol yang butuh jaringan tetap bisa diketuk dan menjelaskan keadaannya ("Lagu ini butuh internet. Unduh dulu supaya bisa didengar offline." dengan tombol "Unduh"), bukan tombol mati tanpa penjelasan.
- **Rekonsiliasi saat start**: jalan di latar saat start dingin, tanpa memblokir layar utama. File unduhan hilang atau ukurannya tidak cocok menurunkan `download_state` ke 0 tanpa menghapus lagu dari library (file rusak dihapus). File cache yatim dan file `.part` tanpa job dihapus. Job berstatus "mengunduh" kembali ke "antre". Tanpa pemeriksaan hash file di v1 (USULAN; ukuran cocok cukup untuk file yang ditulis app sendiri). Snackbar muncul bila ada file unduhan yang hilang (angka persis disebut bila 5 atau kurang, USULAN ambang 5). Rekonsiliasi bersifat idempotent dan memakai batch supaya tidak membuat UI tersendat di library 10.000 lagu.

### 5.4 B4. Playlist dan Library

Laporan lengkap: `hidden_files/tim/fitur-playlist-lirik-beranda.md` (B4.1-B4.9).

- **Playlist** (B4.1-B4.3): nama maks 100 karakter, deskripsi maks 500 karakter (USULAN); nama yang sama boleh dipakai dua playlist (identitas adalah baris database). Sampul playlist memakai kolase 2x2 sampul 4 lagu pertama di halaman detail, dan sampul lagu pertama di baris atau kartu daftar (kolase A12 menang di header detail; sampul lagu pertama B4.1 menang di daftar). Tambah lagu dari menu konteks lagu (pilih playlist atau buat baru), dari halaman album ("Tambah semua ke playlist"), dari player, dan dari layar antrean. Urutan lagu diubah dengan drag and drop; hapus lagu dari playlist hanya menghapus dari playlist itu (lagu tetap di library). Urungkan 5 detik (USULAN) tersedia untuk hapus playlist dan hapus lagu dari playlist. Favorit adalah playlist virtual tersendiri ("Favorit", tombol hati di player dan menu konteks), bukan tag pada playlist.
- **Library** (B4.4-B4.5): tab Library menampilkan Lagu, Album, Artis, Playlist, Favorit, dan Unduhan (jalan pintas ke tab Unduhan). Daftar 50 per halaman dengan keyset pagination (FTS5 untuk pencarian lokal). Sortir diingat per daftar (terbaru, nama, artis, paling sering diputar). Filter "Semua" atau "Library saja" pada hasil cari. Library 10.000 lagu wajib tetap lancar (uji stress, K11).
- **Riwayat putar** (B4.6): tersimpan di `play_events`, maks 10.000 entri (USULAN ambang 10.000; entri lama dihapus otomatis dengan batas kode). "Putaran bermakna" adalah lagu yang diputar 30 detik atau lebih (USULAN), dipakai rumus rekomendasi. Ambang ini berbeda dari ambang 10 detik pencatatan play event (B2.7); keduanya wajib dinyatakan jelas agar tidak tertukar.
- **Lagu yang tidak bisa diputar** (B4.7): diklasifikasikan dari `playabilityStatus` (dihapus, privat, dibatasi wilayah). Kegagalan jaringan TIDAK menandai lagu. Kerusakan massal YouTube TIDAK menandai lagu satu per satu (ikuti B6.5). Lagu tetap ada, tampil redup dengan label "Tidak bisa diputar", dilewati otomatis saat putar berurutan dengan pesan jumlah ("1 lagu dilewati karena tidak bisa diputar"), dan bisa dihapus massal dengan konfirmasi ("Hapus lagu yang tidak bisa diputar"). Lagu unduhan tetap bisa diputar walau sumber online hilang. Status dibersihkan saat satu resolve berhasil.
- **Backup playlist** (B4.8) digugurkan sebagai fitur terpisah dan digantikan satu sistem backup lengkap (keputusan ee, bagian 5.7). Aturan merge B4.8 dipertahankan: playlist dengan nama sama dari backup ditambahkan lagunya yang belum ada ke playlist yang sama (bukan membuat salinan "(salinan)"), karena alur utamanya adalah pengguna memulihkan backup-nya sendiri.

### 5.5 B5. Lirik

Laporan lengkap: `hidden_files/tim/fitur-playlist-lirik-beranda.md` (B5.1-B5.6). Fitur Should.

- **Penyedia lirik final BELUM dipasang dan BELUM diverifikasi.** LRCLIB adalah kandidat yang disebut di riset kompetitor (dipakai InnerTune dan SimpMusic). Fase 2 wajib memeriksa penyedia final sebelum satu baris kode lirik ditulis: syarat API, cakupan, rate limit, lisensi. Tidak ada klaim cakupan atau SLA yang boleh ditulis di PRD ini atau di app.
- **Tampilan** (B5.1): lirik tersinkron (baris aktif mengikuti posisi lagu) bila tersedia, lirik biasa bila tidak. Baris aktif adalah baris dengan timestamp terakhir yang sama dengan atau lebih kecil dari posisi lagu. Ketuk baris mencari ke timestamp baris itu. Geser manual menghentikan geser otomatis 5 detik (USULAN). Teks lirik di-cache lokal di tabel `lyrics` (tidak ada batas jumlah lirik tersimpan di v1; lirik dibaca per baris dari disk, bukan dimuat semua ke memori).
- **Pengambilan** (B5.2): cache-first; hanya meminta lirik untuk lagu yang sedang diputar atau dibuka; tanpa pengenal pengguna atau perangkat di request. Penanda "tidak ditemukan" disimpan 7 hari (USULAN) supaya app tidak menanyakan lagu yang sama berulang-ulang.
- **Pesan jujur** (B5.3): "Lirik lagu ini belum ada." bila penyedia tidak punya; "Lirik belum bisa dimuat. Periksa koneksimu lalu coba lagi." bila jaringan gagal; "Lirik belum tersimpan. Sambungkan internet sekali untuk mengambilnya." bila offline dan lirik belum di-cache. Tidak ada teks lirik contoh atau lirik karangan di state kosong.
- **Sinkronisasi** (B5.4): dari `positionStream` just_audio, bukan jam dinding; berlaku di semua kecepatan putar.
- **Privasi** (B5.5): sebelum request lirik pertama, app menampilkan pemberitahuan satu kali: "Lirik diambil dari layanan luar. Layanan itu bisa melihat judul lagu yang kamu putar dan alamat internetmu." dengan tombol "Mengerti" (USULAN teks). PRIVACY_POLICY.md wajib menyebut penyedia final setelah diputuskan. Saklar hidup atau mati lirik ada di Pengaturan (default hidup, keputusan D3); saklar dan pemberitahuan ini bersama memenuhi D3.
- **Lirik di notifikasi** (B5.6): tidak masuk v1. Alasan: menulis ulang notifikasi tiap pergantian baris membebani sistem dan berisiko mengganggu kontrol media dan baterai. Pasca-v1, satu baris aktif di notifikasi yang diperluas adalah usulan, menunggu bukti ukur.

### 5.6 B6. Beranda dan Rekomendasi

Laporan lengkap: `hidden_files/tim/fitur-playlist-lirik-beranda.md` (B6.1-B6.5).

- **Seksi** (B6.1): 5 seksi lokal ditambah 1 seksi jaringan, urutan final: "Baru diputar", "Lagu untukmu", "Sering diputar", "Playlist kamu", "Unduhan", "Jelajah". Seksi lokal selalu tersedia; "Jelajah" (browse YouTube Music) terakhir karena butuh jaringan. Tiap seksi menampilkan paling banyak 10 item (USULAN) dengan tombol "Lihat semua" ke daftar penuh 50 per halaman. Seksi lokal yang kosong tidak tampil. Beranda tidak pernah loading penuh; seksi lokal tampil dulu dari database.
- **"Lagu untukmu"** (B6.2, rumus lokal, USULAN): skor awal sama dengan jumlah putaran bermakna (30 detik atau lebih) dalam 30 hari terakhir; tambah 5 bila difavoritkan; tambah 2 bila diunduh; urutan skor tertinggi dulu, seri dipecah waktu putar terakhir; ambil 20 teratas; bila kurang dari 20, isi sisa dengan lagu library terbaru. Dihitung ulang tiap beranda dibuka dan tiap data berubah, dalam satu query agregasi (bukan memuat play_events ke memori). Tanpa nama artis, genre, kesamaan audio, dan tanpa machine learning. Bila library kosong, seksi tidak tampil. Contoh hitung (terverifikasi koordinator): lagu B dengan 9 putaran bermakna, lagu A dengan 3 putaran dan difavoritkan (3 tambah 5 sama dengan 8), lagu C dengan 1 putaran dan diunduh (1 tambah 2 sama dengan 3); urutan B, A, C.
- **Perilaku offline** (B6.3): seksi lokal tampil penuh; "Jelajah" diganti pesan "Bagian jelajah butuh internet. Sambungkan internet untuk melihatnya." dengan indikator "Kamu sedang offline" dan tanpa tombol "Coba lagi" (tombol itu tidak melakukan apa-apa saat offline). Lagu yang belum tersimpan menampilkan "Lagu ini belum tersimpan di HP-mu. Sambungkan internet untuk memutarnya." "Jelajah" dimuat otomatis saat kembali online. Empty state pengguna baru yang offline memakai pesan A12 ditambah tombol "Cari lagu": "Belum ada yang bisa ditampilkan. Sambungkan internet sekali untuk mulai, atau buka Unduhan bila kamu sudah punya lagu tersimpan."
- **Refresh** (B6.4): seksi lokal diperbarui otomatis lewat drift watch saat data berubah. "Jelajah" dimuat ulang otomatis bila datanya lebih dari 6 jam (USULAN, selaras TTL config remote); tarik ke bawah hanya memuat ulang "Jelajah"; gagal refresh menampilkan data terakhir dengan pesan "Gagal memperbarui. Menampilkan data terakhir." Waktu muat terakhir disimpan di shared_preferences.
- **Browse gagal** (B6.5): diklasifikasikan (jaringan, tidak bisa di-parse, HTTP error). Tidak bisa di-parse menampilkan "Bagian jelajah belum bisa dimuat. YouTube mungkin mengubah layanannya." dengan tombol "Periksa pembaruan". HTTP error menampilkan "Bagian jelajah belum bisa dimuat. Coba lagi nanti." dengan tombol "Coba lagi". Seksi lokal tidak terpengaruh kegagalan browse. Tanpa detail teknis di pesan. Log internal maks 1 MB dengan rotasi.
- **Discovery berbasis artis** ("Lagu yang mungkin kamu suka" B1.8) pindah ke v1.1 (keputusan rr). **Rak jaringan B1.8** (Tangga lagu, Rilisan baru, Jelajahi mood dan genre) hidup di dalam seksi "Jelajah" sebagai sub-seksi, nama seksi mengikuti respons browse (keputusan ss).

### 5.7 B7. Akun dan Sinkronisasi

Laporan lengkap: `hidden_files/tim/fitur-akun-pengaturan-notifikasi-impor-info.md` (B7.1-B7.6).

- **Tidak ada akun di v1** (dan tidak ada sinkronisasi cloud, telemetri, atau iklan). App langsung bisa dipakai tanpa login, tanpa email, tanpa nomor telepon. Layar Pengaturan tidak menampilkan baris Akun di v1; saat login masuk pasca-v1, baris Akun ditambahkan tanpa mengubah tab navigasi.
- **Backup JSON berversi** (satu sistem backup lengkap, keputusan ee): berisi playlist, favorit, riwayat putar, riwayat pencarian, antrean, dan pengaturan (termasuk search_history, keputusan ww). Field `backupVersion` wajib ada; migrator per versi di sisi impor; backup dari versi app yang lebih baru ditolak dengan pesan jelas. Batas file 10 MB (USULAN; 10 juta byte dibagi 200 byte per lagu sama dengan 50.000 lagu, jauh di atas library wajar). Nama file `backup-musik-YYYYMMDD-HHmmss.json` (USULAN). Impor dalam satu transaksi; gagal berarti tidak ada yang berubah. Merge, bukan timpa buta (aturan merge playlist memakai B4.8; antrean backup ditambahkan di belakang antrean yang ada, bukan menimpa; pengaturan dari backup bersifat opsional).
- **Hapus semua data** (B7.3): dua konfirmasi bertingkat dengan tombol "Simpan salinan dulu" di dialog pertama. Menghapus database, cache, unduhan, dan seluruh preferensi. Tidak ada jalan kembali setelah konfirmasi kedua.
- **Pindah HP** (B7.4): pengguna mengekspor backup, memindahkan file ke HP baru (berbagi file atau kabel), lalu mengimpor. File lagu yang diunduh TIDAK ikut di backup (hanya metadata dan status unduhan); lagu harus diunduh ulang di HP baru. Fakta ini dinyatakan jelas di layar backup.
- **Kirim riwayat dengar kembali ke Google** (B7.6): TIDAK akan diimplementasikan, sesuai rekomendasi C8, berlaku juga pasca-v1 sampai ada keputusan baru owner. Alasannya: mengirim riwayat ke Google bertentangan dengan janji privasi app.
- **Daftar host yang diizinkan** (B7.1-K4) wajib mencakup host config remote (GitHub Releases) di samping host YouTube, Google, dan penyedia lirik.

### 5.8 B8. Pengaturan dan Audio

Laporan lengkap: `hidden_files/tim/fitur-akun-pengaturan-notifikasi-impor-info.md` (B8.1-B8.11).

- **Kualitas streaming** (B8.1, direvisi keputusan m): streaming memakai kualitas terbaik otomatis (itag 251 bila tersedia, turun ke 140, 250, 249, 139 bila tidak). Satu saklar "Hemat data" di Pengaturan beralih ke urutan hemat data (249, 139, 250, 140, 251; naik bila perlu supaya lagu tetap bisa diputar). Pemilih kualitas streaming 3 opsi digantikan saklar ini. Pemakaian data per jam (sekitar): Terbaik 72 MB, Seimbang 58 MB, Hemat data 22 MB.
- **Kualitas unduhan** (B8.1): 3 opsi kanonis (Terbaik, Seimbang, Hemat data; label dan hitungan di bagian 5.3). Pilihan default di Pengaturan, pilihan per unduhan di dialog.
- **Cache** (B8.3): label layar "Ruang untuk lagu yang pernah diputar" (tanpa kata "cache" di antarmuka); tombol hapus berlabel "Kosongkan ruang lagu yang pernah diputar". Batas 250 MB, 500 MB (default), 1 GB, 2 GB. Layar menampilkan pemakaian cache dan unduhan nyata dari database.
- **Unduh WiFi saja** (B8.4): default nonaktif (USULAN). Bila aktif, unduhan berjalan hanya saat tersambung WiFi; saat berpindah ke data seluler, unduhan dijeda dan dilanjutkan saat WiFi kembali.
- **Audio** (B8.5-B8.7): equalizer perangkat (`AndroidEqualizer`, Android saja, band mengikuti perangkat; B8.6); skip silence default mati (Android saja, B8.7); kecepatan 7 pilihan dan pitch 0,5 sampai 2,0 (bagian 5.2); volume app terpisah dari tombol volume HP dengan label jujur "Volume di app ini"; saklar "Buat suara lebih keras" memakai `AndroidLoudnessEnhancer` dengan keterangan "Bukan penyeimbang volume antar lagu".
- **Sleep timer** (B8.8): spesifikasi di bagian 5.2. Catatan verifikasi Fase 2: klaim bahwa timer tetap berjalan setelah app ditutup dari recent apps bergantung pada OEM dan wajib diuji di perangkat nyata.
- **Tema** (B8.9, direvisi keputusan k): v1 hanya mode gelap. Spesifikasi 3 opsi (Gelap default, Terang, Ikuti HP) disimpan sebagai spesifikasi pasca-v1. Token warna semantik membuat mode terang bisa ditambah nanti tanpa rombak.
- **Bahasa** (B8.10, keputusan q): v1 hanya Bahasa Indonesia. Semua string di file ARB sejak awal sehingga Bahasa Inggris bisa ditambah pasca-v1 tanpa mengubah kode tampilan.
- **Penyimpanan pengaturan** (B8.11): 11 kunci shared_preferences, semuanya nilai kecil jauh di bawah batas 1 KB per nilai dan 100 KB total (aturan anti-OOM).

### 5.9 B9. Notifikasi dan Widget

Laporan lengkap: `hidden_files/tim/fitur-akun-pengaturan-notifikasi-impor-info.md` (B9.1-B9.5).

- **Notifikasi media** (B9.1): tampil saat lagu diputar dan tetap tampil saat lagu dijeda (`androidStopForegroundOnPause` false, USULAN). Empat kontrol di tampilan lengkap (prev, play/pause, next, tombol tutup). Notifikasi hilang saat antrean habis atau sleep timer selesai (service dihentikan).
- **Izin notifikasi** (B9.5): diminta saat lagu pertama diputar, dengan layar penjelasan app sendiri terlebih dahulu. Tombol "Nanti saja" tersedia paling banyak 3 kali (USULAN); setelah itu izin diminta lewat Pengaturan sistem. Bila izin ditolak, pemutaran tetap jalan; pengguna tidak pernah melihat kontrol media yang tidak berfungsi tanpa penjelasan. Catatan verifikasi Fase 2: perilaku foreground service saat izin ditolak masih ditandai belum pasti oleh tim dan wajib diuji.
- **Perilaku jeda dan antrean habis** (B9.2): saat antrean habis, notifikasi dihapus dan service dihentikan. Lagu terakhir tetap tampil di mini-player untuk pemutaran ulang manual.
- **Android Auto** (B9.3, keputusan t): Auto dasar masuk v1 sebagai konsekuensi MediaSession (lagu yang sedang diputar, kontrol dasar, antrean). Browsing penuh (pencarian dan library di layar mobil) adalah Could pasca-v1. Panggilan masuk menjeda tanpa lanjut otomatis (sepakat dengan B2.4).
- **Widget layar beranda** (B9.4): item spike Fase 2, bukan janji v1. Alasan: widget butuh kode native Android di luar Flutter, dengan 5 pertanyaan spike yang wajib dijawab (ukuran, refresh, interaksi, biaya baterai, cakupan API).

### 5.10 B10. Impor

Laporan lengkap: `hidden_files/tim/fitur-akun-pengaturan-notifikasi-impor-info.md` (B10.1-B10.4).

- **Impor playlist Spotify tanpa API** (B10.1): larangan yang mengikat dan berlaku selamanya. App TIDAK BOLEH memanggil `api.spotify.com` atau `accounts.spotify.com`; TIDAK BOLEH memakai client ID, client secret, atau token Spotify; TIDAK BOLEH login Spotify; TIDAK BOLEH memakai library pembungkus Spotify Web API. Pelanggaran adalah alasan menghentikan rilis. Satu-satunya request ke domain Spotify yang diizinkan adalah mengambil satu halaman publik playlist yang dibagikan pengguna (jalur A).
  - **Jalur B (utama, aman)**: pengguna menempelkan atau memilih file ekspor miliknya (teks "Artis - Judul" per baris, CSV, atau JSON ekspor data Spotify). Tidak ada request ke Spotify sama sekali.
  - **Jalur A (sekunder, berisiko)**: pengguna menempelkan tautan playlist publik Spotify; app mengambil halaman publik itu dan mengekstrak daftar lagu. Ditandai risiko ToS dan kerapuhan; wajib dibuktikan di Fase 2 sebelum dikapalkan; bila tidak bisa dibuktikan, jalur A gugur dan jalur B berdiri sendiri. Risiko dicatat sebagai R11.
  - **Pencocokan**: lagu dicocokkan ke katalog YouTube Music. Cocok yakin (judul dan artis sama persis) langsung diterima. Tidak yakin menampilkan sampai 3 kandidat dan pengguna memilih atau menekan "Lewati lagu ini". Tidak ada kandidat berarti gagal dengan alasan "tidak ditemukan". App tidak pernah menebak diam-diam.
- **Pemutar file audio lokal** (B10.2): ditunda ke v1.1 (keputusan D1 menang). Spesifikasi B10.2 disimpan utuh sebagai spesifikasi v1.1: pemindaian file audio di HP, tag extractor sendiri (pola OuterTune; MediaStore tidak bisa diandalkan), izin READ_MEDIA_AUDIO diminta saat baris "File di HP" di Library pertama kali dibuka, dengan dialog penjelasan app dulu. Izin READ_MEDIA_AUDIO tidak masuk izin v1.
- **Impor backup** (B10.3): spesifikasi di bagian 5.7. Aturan merge nama playlist memakai B4.8 (tambahkan lagu yang belum ada ke playlist yang sama).
- **Laporan hasil impor** (B10.4): setelah impor, app menampilkan ringkasan (berhasil, sudah ada, gagal) dengan alasan per lagu yang gagal. Ringkasan bisa ditutup dan tidak disimpan permanen.

### 5.11 B11. Info dan Bantuan

Laporan lengkap: `hidden_files/tim/fitur-akun-pengaturan-notifikasi-impor-info.md` (B11.1-B11.5).

- **Tentang** (B11.1): nama app, nomor versi dan build, penjelasan singkat apa app ini, disclaimer non-afiliasi (app ini bukan produk YouTube atau Google), disclaimer legal (app memakai akses tidak resmi dan bisa berhenti berfungsi kapan saja), lisensi GPL-3.0-only, tautan repo, tautan kebijakan privasi, dan satu baris ajakan mendukung kreator ("Suka lagu ini? Dukung artisnya dengan mendengarkan di layanan resmi atau membeli karyanya." USULAN teks, mengikuti contoh SimpMusic, tanpa pengingat berulang).
- **Kebijakan privasi** (B11.2): 8 butir. (1) App tidak mengumpulkan data pengguna. (2) Semua data tersimpan lokal di HP. (3) Pihak ketiga yang menerima data: Google dan YouTube menerima IP, kueri pencarian, dan permintaan stream; penyedia lirik menerima IP dan judul lagu; host config remote (GitHub Releases) menerima IP saat pemeriksaan pembaruan. (4) Tidak ada login di v1. (5) Pengguna bisa menghapus semua data dari app. (6) App tidak ditujukan untuk anak di bawah umur tanpa pendampingan orang tua. (7) Kanal kontak (D9, menunggu owner). (8) Tanggal berlaku dan cara pemberitahuan perubahan.
- **FAQ** (B11.3, layar 20): 12 pertanyaan nyata untuk app ini, dengan jawaban bahasa sehari-hari. Q1 menjelaskan cara melaporkan kerusakan dan tombolnya (tanpa janji kecepatan respons; frasa "dalam beberapa hari" dihapus karena tidak bisa diverifikasi). Q12 soal kode sumber terbuka ditandai tertunda sampai keputusan lisensi dan repo final (keduanya kini diputuskan: GPL-3.0-only, repo publik).
- **Laporkan kerusakan** (B11.4): pengguna bisa mengirim laporan dengan 8 butir info diagnostik (versi app, versi Android, model HP, langkah yang dilakukan, pesan yang muncul, waktu kejadian, apakah lagu unduhan atau streaming, apakah masalahnya berulang). Yang TIDAK BOLEH ikut terkirim: alamat IP, email, cookie, token, URL stream, isi respons InnerTube, path internal, judul lagu, isi database.
- **Kejujuran** (B11.5, direvisi keputusan y): tidak ada baris permanen yang tidak bisa ditutup di beranda. Diganti lembar kejujuran satu kali saat pertama kali membuka app (bisa ditutup, tampil sekali, dengan tautan ke FAQ 1 dan 2). Banner saat layanan terganggu dan tombol "Periksa pembaruan" tetap ada sesuai B1.7 dan B6.5.

## 6. Desain UI dan UX

Laporan lengkap: `hidden_files/tim/desain-ui-ux.md` (A12). Ringkasan yang mengikat di sini; token dan spesifikasi komponen lengkap ada di laporan.

- **Design system monokrom** sesuai design lock owner: canvas hitam murni `#000000`, surface `#121214`, elevated `#1C1C1E`, teks `#FFFFFF` (utama), `#A1A1AA` (sekunder), `#8E8E93` (redup), aksen putih. Warna hanya untuk status: hijau `#34D399` (sukses), kuning `#FBBF24` (peringatan), merah `#F87171` (error), biru `#60A5FA` (info). Rasio kontras terverifikasi koordinator dengan rumus WCAG: teks utama 21,0:1, sekunder 8,19:1, redup 6,44:1, status hijau 10,92:1, kuning 12,58:1, merah 7,59:1, biru 8,26:1. `#71717A` (4,35:1) dilarang untuk teks karena di bawah AA.
- **Font sistem Android** (tanpa biaya APK); skala 8 token dari 12 sp sampai 24 sp (lantai 12 sp untuk semua teks yang menghadap pengguna; token 11 sp A12 dinaikkan ke 12 sp). Grid 4 dp; satu sistem radius yang didokumentasikan; ikon Material Symbols outlined; gerak MOTION 1 (dial ENERGY 2, RHYTHM 2, MOTION 1).
- **Navigasi**: tab bawah 4 tab (Beranda, Cari, Library, Unduhan). Pengaturan lewat ikon gerigi di Library. 20 layar (19 dari A12 ditambah FAQ sebagai layar 20) dan 9 dialog atau sheet. Peta navigasi lengkap ada di laporan A12.
- **Layar utama**: Beranda (seksi bagian 5.6), Pencarian (bagian 5.1), Player (sampul, judul, artis, kontrol, slider seek, antrean, lirik, sleep timer, sheet Suara), Library (bagian 5.4), Detail playlist, Pengaturan, Unduhan. Tiap layar punya keempat state: skeleton, empty state jujur (tanpa data contoh), error bahasa sehari-hari dengan tombol coba lagi, dan state offline.
- **Komponen kunci**: kartu 158 dp di layar 360 dp (terverifikasi: (360 dikurangi 32 dikurangi 12) dibagi 2); daftar virtual 50 item per halaman; mini-player 64 dp (tidak bisa dihapus dengan geser ke samping); antrean maks 200 item; kontrol putar, acak, ulang; slider seek; volume, kecepatan, pitch, dan EQ perangkat di sheet Suara; dialog unduh dengan label "Terbaik", "Seimbang", "Hemat data" (pemetaan ke itag hanya di dokumen, tidak di layar); indikator status 3 tingkat saat YouTube berubah (Normal, Terganggu, Bermasalah, ambang dari arsitektur 3.5).
- **Aksesibilitas**: target sentuh 48 dp; kontras AA; teks minimal 12 sp; label TalkBack per kontrol; status tidak pernah hanya warna (6 pasangan penanda teks dan ikon); skala font sampai 1,3x; reduced motion dihormati; fokus keyboard jelas.
- **Perangkat nyata**: baseline 360 dp; tablet adaptif (lebar maks 720 dp, rail navigasi di 840 dp ke atas landscape); rotasi mempertahankan state; gelap saja di v1 dengan 3 alasan tertulis (design lock owner berbasis hitam, satu mode yang diperiksa penuh lebih baik dari dua mode setengah jadi, token semantik membuat mode terang bisa ditambah nanti tanpa rombak).
- **Aturan copy**: 7 aturan dengan 12 contoh benar vs salah di laporan A12. Ringkasnya: bahasa sehari-hari, tanpa istilah teknis, tanpa kata "cache" di layar, tanpa kata "perpustakaan" (pakai "Library"), kata kerja "Periksa" distandarkan (bukan "Cek"), tanpa angka yang tidak perlu, tanpa klaim yang tidak bisa dibuktikan.

## 7. Kriteria sukses v1 (K1-K15)

Tiap kriteria punya target dan cara ukur. Target tidak boleh diturunkan diam-diam bila pengukuran pertama lebih rendah; perubahan target wajib dicatat dengan alasan.

| ID | Kriteria | Target | Cara ukur |
|----|----------|--------|-----------|
| K1 | Kecepatan resolve | Median di bawah 2 detik per lagu | Uji 60 lagu, hitung median waktu resolve |
| K2 | Cold start | TTID 1,5 detik, TTFD 2,5 detik | `--trace-startup` dan `adb am start -W`, protokol 5 kali ukur buang min dan maks, perangkat kelas menengah |
| K3 | Pemutaran pertama | Di bawah 2 detik di koneksi baik | Uji 20 lagu dari keadaan dingin |
| K4 | Ukuran APK | Maks 25 MB per ABI (arm64) | Ukur APK rilis split per ABI; target regang 20 MB |
| K5 | Keberhasilan pemutaran | 57 dari 60 lagu berhasil (95 persen) | Uji 60 lagu populer dan kurang populer, 20 lagu per hari selama 3 hari |
| K6 | Fallback antar client | 10 dari 10 tanpa error terlihat | Matikan client utama di config, 10 lagu tetap jalan |
| K7 | Config remote | Dipakai dalam 6 jam | Ubah entri di GitHub Release, app mengambil dalam TTL tanpa install ulang |
| K8 | Offline penuh | 10 lagu mode pesawat | Unduh 10 lagu, aktifkan mode pesawat, putar semuanya |
| K9 | Cache tidak menghapus unduhan | 0 unduhan terhapus oleh eviction | Isi cache sampai batas, periksa semua unduhan masih ada |
| K10 | Antrean persisten | Antrean utuh setelah restart | Buat antrean 50 lagu, tutup paksa app, buka lagi, antrean sama |
| K11 | Ketahanan memori | 10.000 lagu, 1.000 entri riwayat, antrean 500, tanpa OOM | Uji stress di RAM 3 GB, ambang memori diputuskan Fase 2 setelah pengukuran pertama |
| K12 | Keamanan | Nol temuan kritis, tinggi, dan sedang | Siklus Red-Blue-Red, maks 5 ronde |
| K13 | Kualitas kode | `flutter analyze` tanpa warning; tes jalur resolve, fallback, unduhan, migrasi lolos | CI GitHub Actions |
| K14 | Copy bahasa sehari-hari | 0 istilah teknis di teks layar | Audit copy manual tiap layar, checklist bagian 6 |
| K15 | Distribusi dan dokumen | README, PRIVACY_POLICY.md, CHANGELOG, metadata F-Droid, GitHub Release dengan checksum | Periksa satu per satu sebelum rilis |

## 8. Milestone (M0-M10)

Berbasis dependensi, tanpa tanggal. Estimasi waktu tanpa bukti build pertama adalah tebakan, jadi PRD ini tidak memberi tanggal. Aturan: scope freeze setelah M4; login tidak boleh menyelinap lewat M3 atau M8; tiap milestone diakhiri demo APK ke owner (milestone tanpa APK yang bisa diuji owner dianggap belum selesai).

- **M0 Fondasi**: repo, CI, skeleton app, token desain, pemisahan string ke ARB.
- **M1 Spike ekstraksi**: 6 spike arsitektur bagian 3.6. Gate go atau no-go sebelum komitmen penuh; bila spike gagal, pindah ke jalur cadangan (fork youtube_explode_dart dengan solver QuickJS, ytdlp_flutter, atau NewPipeExtractor).
- **M2 Player core**: bisa paralel dengan M1 setelah interface `AudioPlayerPort` disepakati. just_audio, audio_service, MediaSession, notifikasi, antrean.
- **M3 Database dan library**: drift, 15 tabel, migrasi, library, playlist, favorit, riwayat.
- **M4 Pencarian dan browse**: pencarian YTM, saran, FTS5 lokal, beranda, Jelajah.
- **M5 Unduhan dan cache**: download jobs, cache LRU, layar Penyimpanan, rekonsiliasi.
- **M6 Ketahanan**: config remote, kanari, klasifikasi error, pesan jujur.
- **M7 Fitur Should**: lirik, sleep timer, EQ Android, skip silence.
- **M8 Backup dan ekspor**: backup JSON berversi, impor merge, hapus semua data.
- **M9 Keamanan**: Red 1 setelah M4, Red 2 setelah M5 dan M6, Red 3 di release candidate. Siklus Red-Blue-Red sampai nol temuan kritis, tinggi, sedang.
- **M10 Rilis**: dokumen rilis, GitHub Release dengan checksum, metadata F-Droid, pengajuan IzzyOnDroid.

**Pasca-v1**: v1.1 pemutar file audio lokal dan discovery berbasis artis; v1.2 login YouTube Music bila diputuskan; lalu normalisasi volume, EQ 10 band, Android Auto browsing penuh, widget.

## 9. Risiko (R1-R11)

| ID | Risiko | Mitigasi | Pemicu eskalasi |
|----|--------|----------|-----------------|
| R1 | YouTube berubah dan merusak ekstraksi | Fallback antar client, config remote, kanari, pesan jujur | Ambang rusak tercapai; owner diberi tahu di hari yang sama |
| R2 | Satu maintainer paket audio (Ryan Heise) | Interface `AudioPlayerPort` milik app; cadangan just_audio_media_kit, media_kit, mpv_audio_kit | Tidak ada rilis 12 bulan dan ada bug blocker, atau repo diarsipkan |
| R3 | audio_service di atas androidx.media yang deprecated | Pantau rilis; cadangan handler custom | Notifikasi rusak di Android 15 atau 16, atau Google mengumumkan penghapusan |
| R4 | F-Droid menolak config remote | Varian config dibundel; fallback GitHub dan IzzyOnDroid | F-Droid menolak atau meminta config dihapus |
| R5 | just_audio tertinggal di Media3 1.4.1 | Pantau changelog; cadangan media_kit | Bug decoder yang sudah diperbaiki di Media3 baru, atau just_audio mengumumkan tidak akan bump |
| R6 | Kerentanan QuickJS | Isolate terpisah, batas memori dan waktu, tanpa callback host, validasi output, hash player dicocokkan | CVE baru atau quickjs_engine tertinggal perbaikan; bila tidak ada perbaikan, solver dimatikan sementara dan app hanya memakai client yang tidak butuh signature |
| R7 | Tindakan hukum (C and D, takedown repo) | Clean-room, tanpa merek YouTube atau Spotify, disclaimer, mirror repo cadangan | Surat hukum apa pun atau takedown repo; owner memutuskan langsung; tim tidak melawan tanpa penasihat hukum dan tidak mengabaikan diam-diam |
| R8 | Scope creep | Scope freeze setelah M4; usulan baru masuk backlog | Usulan fitur baru di tengah Fase 2; owner memutuskan |
| R9 | Ketergantungan satu owner | Hotfix config bisa diterbitkan tim bila owner tidak bisa dihubungi lebih dari 30 hari saat kerusakan aktif | Owner tidak bisa mengambil keputusan lebih dari 30 hari di tengah kerusakan aktif; otorisasi ini tercakup dalam delegasi penuh 15 November 2026 20:55 WIB |
| R10 | Pengguna mengira app rusak total | Catatan status di README dan Releases dalam 24 jam, tanpa janji tanggal | Laporan kerusakan massal |
| R11 | Impor Spotify jalur A (halaman publik) melanggar ToS atau rapuh | Jalur B (file ekspor) sebagai utama; jalur A wajib dibuktikan Fase 2 sebelum dikapalkan | Jalur A tidak bisa dibuktikan; jalur A gugur dan jalur B berdiri sendiri |

## 10. Keputusan

Seluruh keputusan di bawah ini DIPUTUSKAN koordinator atas otoritas delegasi penuh owner 15 November 2026 20:55 WIB. Owner bisa membatalkan keputusan apa pun.

| ID | Keputusan | Isi |
|----|-----------|-----|
| D1 | Lisensi | GPL-3.0-only (norma ekosistem: 4 dari 5 kompetitor GPL-3.0; copyleft melindungi dari fork tertutup; F-Droid menerimanya) |
| D2 | Pemutar lokal | Ditunda ke v1.1; spesifikasi B10.2 disimpan utuh |
| D3 | Lirik | LRCLIB hanya kandidat yang wajib verifikasi Fase 2; saklar hidup atau mati di Pengaturan default hidup, plus pemberitahuan satu kali; PRIVACY_POLICY.md menyebut penyedia final |
| D4 | Equalizer | AndroidEqualizer mengikuti perangkat; tanpa EQ 10 band di v1 |
| D5 | Sleep timer | Pause dan hentikan foreground service saat habis (disepakati D1, B8.8, B2.5; A12 netral) |
| D6 | Bahasa UI | Indonesia saja di v1; semua string di ARB sejak awal; Inggris pasca-v1 |
| D7 | Kualitas audio | Unduhan 3 opsi (Terbaik, Seimbang, Hemat data); streaming terbaik otomatis plus satu saklar hemat data (keputusan m revisi) |
| D8 | Distribusi | GitHub dan IzzyOnDroid dulu; F-Droid setelah 3 bulan pengembangan aktif |
| D9 | Kanal kontak privasi | MENUNGGU OWNER. Tim tidak bisa mengarang alamat kontak publik. Satu-satunya butir yang butuh tindakan owner |
| D10 | ApplicationId | Diputuskan bersama nama app di Paket 4 dan 5; tidak bisa diubah setelah rilis tanpa memutus update |
| D11 | Dukung kreator | Satu baris di layar Tentang, mengikuti contoh SimpMusic, tanpa pengingat berulang |
| D12 | Mirror repo | Mirror cadangan ke forge kedua saat rilis pertama (mitigasi R7) |
| D13 | Penomoran versi | 0.9.x untuk build uji, v1.0.0 rilis publik pertama (pelajaran OuterTune 0.10.1 vs 0.10.1-b1) |
| D14 | Repo | PUBLIK. F-Droid mewajibkan source publik; GPL mewajibkan source tersedia; copyleft adalah perlindungan terhadap pencurian source; kelima kompetitor publik |
| D15 | Tema | Mode gelap saja di v1; mode terang pasca-v1 (keputusan k) |
| D16 | Nama app | Diputuskan tim Brand (C11) dari kandidat terverifikasi di Paket 4, sesuai delegasi eksplisit |

## 11. Asumsi dan fakta

**Asumsi** (bila salah, PRD ini perlu revisi):
- A1. Pengguna sudah tahu app ini tidak resmi dan tidak berafiliasi dengan YouTube atau Spotify.
- A2. Durasi lagu rata-rata 210 detik (dipakai semua hitungan ukuran file).
- A3. RAM 3 GB mewakili perangkat awal pengguna.
- A4. Pengguna terutama mendengar lagu yang sudah dikenal, bukan menjelajah katalog baru.
- A5. Koneksi pengguna kadang lambat atau putus.
- A6. Owner adalah satu-satunya pengambil keputusan akhir.
- A7. YouTube tidak memblokir seluruh client InnerTube sekaligus dalam waktu dekat. Bila salah, v1 gagal dan tim beralih ke cadangan atau menghentikan proyek.
- A8. F-Droid menerima config remote.
- A9. Thumbnail YouTube Music sekitar 100 KB (belum diukur).

**Fakta** (terverifikasi 15 November 2026):
- F1. Kelima kompetitor memakai Media3 ExoPlayer; tidak ada yang masih Flutter.
- F2. Tidak satu pun kompetitor ada di Play Store.
- F3. Kualitas audio publik terbaik dari YouTube adalah itag 251 Opus sampai sekitar 160 kbps; tidak ada 320 kbps atau lossless.
- F4. Spotube kena cease-and-desist Spotify 2025 dan membuang Spotify di v5.
- F5. F-Droid mewajibkan 3 bulan pengembangan aktif (dengan pengecualian yang tercantum di kebijakan).
- F6. Tiga dari lima kompetitor mati atau membeku.
- F7. ToS YouTube (berlaku 15 Desember 2023) melarang akses tidak resmi, automated means, dan mengakali fitur keamanan; app ini melanggar di beberapa titik sekaligus.

## 12. Tabel angka dan batas

| Butir | Nilai | Sumber |
|-------|-------|--------|
| itag audio | 139 AAC 48 kbps, 140 AAC 128 kbps, 141 AAC 256 kbps (Premium saja, tidak dijanjikan), 249 Opus sekitar 50 kbps, 250 Opus sekitar 70 kbps, 251 Opus sekitar 128 sampai 160 kbps | A4, gist itag 11 Oktober 2026 |
| Urutan pemilihan itag | 251, 140, 250, 249, 139 | A4 |
| Ukuran lagu 3,5 menit | 251 sama dengan 4,2 MB; 140 sama dengan 3,36 MB; 250 sama dengan 1,84 MB; 249 sama dengan 1,31 MB; 139 sama dengan 1,26 MB | Rumus bitrate x 210 detik / 8 |
| Data streaming per jam (sekitar) | Terbaik 72 MB; Seimbang 58 MB; Hemat data 22 MB | B7-11 |
| Cache streaming | Default 500 MB; pilihan 250 MB, 500 MB, 1 GB, 2 GB; isi sekitar 59, 119, 243, 487 lagu (1 GB = 1.024 MB) | A13, B7-11, keputusan oo |
| Antrean | Maks 200 item metadata | A13, B2.3 |
| Riwayat putar | Maks 10.000 entri | A5, B4.6 |
| Riwayat pencarian | Maks 100 query | B1.3 |
| Pagination | 50 item per halaman, keyset | A13, B1.5 |
| Debounce | 300 ms (pencarian lokal dan saran) | A13, B1.2 |
| Timeout | Connect 10 detik, receive 15 detik (API JSON); 30 detik (stream dan gambar, inactivity unduhan) | A13 |
| Retry | Maks 3 kali, backoff 1 detik dan 2 detik ditambah jitter, hanya error jaringan, 5xx, 429 | A13, B3.3 |
| Batas anti-OOM | shared_preferences maks 1 KB per nilai dan 100 KB total; kolom JSON maks 4 KB per baris; log internal 1 MB rotasi; cache sampul 200 MB disk; thumbnail 200 px, now-playing 512 px; ImageCache 200 gambar dan 50 MiB | A5, A13 |
| Config remote | TTL 6 jam; timeout request 5 detik; maks respons 4 MB; single-flight dan rate limit untuk refresh yang dipicu kegagalan | A4 |
| QuickJS | Timeout 10 detik; memori 192 MiB; stack 8 MiB; eksekusi serial | A4 (angka SimpMusic) |
| Ambang rusak (usulan desain) | 3 resolve kanari gagal berturut-turut dengan penyebab sama, atau lebih dari separuh resolve dalam 1 jam gagal | A4, arsitektur 3.5 |
| Izin v1 | 6 izin: INTERNET, FOREGROUND_SERVICE, FOREGROUND_SERVICE_MEDIA_PLAYBACK, FOREGROUND_SERVICE_DATA_SYNC, WAKE_LOCK, POST_NOTIFICATIONS (READ_MEDIA_AUDIO tidak masuk karena pemutar lokal ditunda ke v1.1) | A6 |
| MinSdk | API 26 (Android 8.0); fallback API 24 tanpa blocker teknis dari library audio | Arsitektur, A2 |
| Target APK | Maks 25 MB per ABI (arm64), regang 20 MB | A13, K4 |
| Target performa | Resolve median di bawah 2 detik; TTID 1,5 detik; TTFD 2,5 detik; pemutaran pertama 2 detik | A13, K1-K3 |

## 13. Yang belum terverifikasi dan verifikasi Fase 2

Daftar ini wajib diselesaikan sebelum atau saat Fase 2, bukan ditebak.

1. Penyedia lirik final (syarat API, cakupan, rate limit, lisensi); LRCLIB hanya kandidat.
2. Penerimaan F-Droid atas config remote yang mengubah perilaku ekstraksi.
3. Kewajiban UU PDP Indonesia untuk app ini (belum diperiksa dari sumber live).
4. Library tag metadata: audiotags vs flutter_taglib (uji Fase 2).
5. Paket pendeteksi koneksi (`connectivity_plus` kandidat, versi dan status belum dicek).
6. Ukuran file thumbnail YouTube Music nyata (asumsi 100 KB belum diukur).
7. Ukuran APK nyata kombinasi dependensi (wajib ukur sejak build pertama).
8. Ambang memori persis uji regresi anti-OOM (diputuskan setelah pengukuran pertama).
9. Perilaku foreground service saat izin notifikasi ditolak.
10. Timer tidur tetap berjalan setelah app ditutup dari recent apps (bergantung OEM).
11. Signature lengkap `setPitch` dan `setSkipSilenceEnabled`; band `AndroidEqualizer` per perangkat.
12. Browse charts, rilisan, dan mood tanpa login (butir 5 B1-3).
13. Saran pencarian tanpa login (butir 6 B1-3).
14. Continuation token dari client ANDROID_MUSIC (butir 7 B1-3).
15. Perilaku `useLazyPreparation` untuk prefetch 1 lagu ke depan (butir 10 B1-3).
16. Versi persis Media3 di file build just_audio 0.10.6; apakah audio_service sudah migrasi ke Media3.
17. Lisensi audio_service dan audio_session.
18. Nama app dan ApplicationId (Paket 4 dan 5).
19. Model HP owner belum tercatat (untuk uji perangkat nyata).
20. Label tombol "Periksa pembaruan" dipahami pengguna (uji pemahaman Fase 2, D2).
21. Apakah Network Security Config berlaku untuk lalu lintas Dio dan HttpClient Dart.
22. Reproducible build Flutter di F-Droid.

## 14. Checklist 7 skill anti-slop

Dokumen ini ditulis dengan 7 skill anti-slop owner (mode during). Checklist per skill:

- **local-design-taste-frontend**: token desain A12 dipakai apa adanya (monokrom, hitam murni, aksen putih); tidak ada gradasi dekoratif, tidak ada glassmorphism, tidak ada shadow tebal; aturan owner menang atas default generik skill (klausul override).
- **local-impeccable**: tiap fitur punya state lengkap (loading, kosong, error, offline); tiap angka punya sumber atau label USULAN; edge cases (lagu tidak bisa diputar, file hilang, antrean penuh, ruang habis) dispesifikasikan, bukan diabaikan.
- **local-humanizer**: copy pengguna dalam bahasa Indonesia sehari-hari; tidak ada kalimat template ("Berikut adalah", "Senantiasa"); pesan error menjelaskan apa yang terjadi dan apa yang bisa dilakukan pengguna.
- **local-stop-slop**: tidak ada kata haram (komprehensif, sinergi, transformasi, dan kawan-kawan); tidak ada filler; tiap paragraf membawa keputusan atau angka.
- **local-no-ai-slop**: tidak ada klaim yang tidak bisa dibuktikan ("dalam beberapa hari" dihapus dari FAQ); tidak ada angka karangan (semua angka dikutip dari arsitektur atau riset, atau berlabel USULAN dengan rumus); tidak ada label bergaya AI.
- **local-avoid-ai-writing**: kalimat aktif dan pendek; tidak ada pola "tidak hanya X tapi juga Y"; tidak ada daftar klise AI.
- **local-anti-slop (rulebook)**: tidak ada em dash, tidak ada en dash, tidak ada karakter persen (ditulis kata "persen"); tidak ada emoji; tidak ada kata "cache" atau "perpustakaan" di copy pengguna; istilah teknis hanya di penjelasan untuk tim.
