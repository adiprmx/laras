# Rencana Fase 2: Build Laras

**Tanggal tulis:** 15 November 2026.
**Status:** Fase 1 selesai untuk dokumen ini. Build dimulai setelah dokumen ini dibaca dan repo dibuat.
**Dokumen acuan:** `docs/prd-v1.md`, `docs/arsitektur.md`, `docs/riset-kompetitor.md`, `docs/nama-app.md`.

## Keputusan yang sudah diputuskan (dibawa dari Fase 1)

- **Nama app:** Laras. **Repo:** `adiprmx/laras` (publik). **ApplicationId:** `id.my.adipmusic.laras`. **Lisensi:** GPL-3.0-only.
- **Stack:** Flutter 3.47.8 / Dart 3.13.7; just_audio 0.10.6 + audio_service 0.18.19 + audio_session 0.2.4; InnerTube kustom + quickjs_engine 0.1.7; drift 2.35.4; dio 5.11.1; cached_network_image_ce. MinSdk API 26. Target APK maks 25 MB per ABI.
- **Distribusi:** GitHub Release + IzzyOnDroid dulu; F-Droid setelah 3 bulan pengembangan aktif.
- **Penomoran:** 0.9.x untuk build uji, v1.0.0 rilis publik pertama.
- **Tanpa server, tanpa akun, tanpa telemetri, tanpa iklan di v1.** Tanpa API Spotify dalam bentuk apa pun.

## Urutan paket kerja (P0-P10, memetakan milestone M0-M10 di PRD)

Aturan yang mengikat: scope freeze setelah P4; login tidak boleh menyelinap lewat P3 atau P8; tiap paket diakhiri demo APK ke owner (paket tanpa APK yang bisa diuji owner dianggap belum selesai); tidak ada tanggal (estimasi waktu tanpa bukti build pertama adalah tebakan; ukuran paket dinyatakan relatif di bagian 8).

### P0. Fondasi repo

- Buat repo publik `adiprmx/laras` (main branch, README, LICENSE GPL-3.0-only, CONTRIBUTING, SECURITY, .gitignore Flutter, CHANGELOG).
- Skeleton Flutter: struktur folder (lib/features, lib/core, lib/data, lib/player, lib/extractor), token desain A12, pemisahan string ke ARB sejak awal, `flutter analyze` bersih.
- CI dasar (bagian 4) hijau di push pertama.
- Mirror repo cadangan ke forge kedua (keputusan D12).
- **Kriteria selesai:** repo publik + CI hijau + APK skeleton terpasang di HP owner.

### P1. Spike ekstraksi (gate go atau no-go)

- 6 spike arsitektur bagian 3.6: (1) player request ANDROID_MUSIC + WEB_REMIX mengembalikan adaptiveFormats itag 251 + 140 untuk 5 video musik; (2) QuickJS menjalankan n-transform dari base.js asli, 1 lagu 3 menit diputar sampai habis tanpa HTTP 403; (3) fallback antar client (matikan client utama di config, lagu tetap jalan); (4) tabel config remote (ubah entri di GitHub Release, app mengambil dalam TTL tanpa install ulang); (5) SABR (panggil player dengan WEB, buktikan app tidak memilih format SABR); (6) ukur ukuran APK tambahan quickjs_engine + waktu resolve rata-rata (target desain di bawah 2 detik per lagu).
- **Gate:** bila spike gagal, pindah ke jalur cadangan sebelum komitmen penuh (fork youtube_explode_dart + solver QuickJS; ytdlp_flutter; NewPipeExtractor via Gradle + Pigeon). Keputusan cadangan dicatat dengan bukti.
- **Kriteria selesai:** 6 spike lolos atau cadangan dipilih dengan bukti; demo APK memutar 5 lagu dari YouTube Music.

### P2. Player core (bisa paralel dengan P1 setelah AudioPlayerPort disepakati)

- `AudioPlayerPort` (interface player milik app), just_audio + audio_service + MediaSession, notifikasi media, kontrol headset dan Bluetooth, antrean 200 item, shuffle, repeat, kecepatan, pitch, skip silence, gapless.
- **Kriteria selesai:** APK memutar lagu, jeda, lanjut, next, prev, dengan notifikasi media yang benar di lock screen.

### P3. Database dan library

- drift, 15 tabel skema v1, migrasi teruji, library (lagu, album, artis), playlist, favorit, riwayat putar, FTS5, pagination 50 per halaman.
- **Kriteria selesai:** APK menyimpan 1.000 lagu contoh, pencarian lokal jalan, playlist bisa dibuat dan diedit.

### P4. Pencarian dan browse

- Pencarian YTM (hanya saat kueri dikirim eksplisit), saran pencarian, riwayat 100 query, beranda (6 seksi), Jelajah dari browse YTM.
- **Scope freeze setelah paket ini.**
- **Kriteria selesai:** APK mencari lagu, menampilkan beranda, dan membuka hasil browse; Red 1 keamanan jalan setelah paket ini.

### P5. Unduhan dan cache

- Download jobs (serial 1 file, resume Range, retry 3 kali), kualitas unduhan 3 opsi, cache streaming LRU 500 MB default, layar Penyimpanan, rekonsiliasi saat start.
- **Kriteria selesai:** APK mengunduh 10 lagu, memutar semuanya dalam mode pesawat (K8), dan eviction cache tidak menghapus unduhan (K9).

### P6. Ketahanan

- Config remote (GitHub Releases, TTL 6 jam), deteksi kanari (video kanari saat start dingin pertama hari itu), klasifikasi error 6 penyebab, banner status 3 tingkat, tombol "Periksa pembaruan", pesan jujur.
- **Kriteria selesai:** matikan client utama di config, 10 lagu tetap jalan tanpa error terlihat (K6); ubah entri config, app mengambil dalam 6 jam (K7).

### P7. Fitur Should

- Lirik (penyedia final diverifikasi dulu; LRCLIB hanya kandidat), sleep timer, EQ Android, skip silence.
- **Kriteria selesai:** lirik tersinkron tampil untuk lagu yang punya lirik; sleep timer menghentikan service sesuai PRD.

### P8. Backup dan ekspor

- Backup JSON berversi (backupVersion, batas 10 MB), impor merge satu transaksi, hapus semua data (2 konfirmasi), pindah HP.
- **Kriteria selesai:** ekspor backup, hapus data, impor kembali, library dan playlist pulih utuh.

### P9. Keamanan (Red-Blue-Red)

- Red 1 setelah P4, Red 2 setelah P5 dan P6, Red 3 di release candidate. Kerangka OWASP MASVS v2.1.0 + MASTG v2.0.0 (rencana A6). Berhenti di nol temuan kritis, tinggi, sedang; maks 5 ronde.
- **Kriteria selesai:** nol temuan kritis, tinggi, dan sedang (K12).

### P10. Rilis v1.0.0

- Dokumen rilis (README, PRIVACY_POLICY.md dengan kanal kontak D9 dari owner, CHANGELOG), GitHub Release v1.0.0 dengan checksum, metadata F-Droid, pengajuan IzzyOnDroid.
- Verifikasi K1-K15 lengkap sebelum rilis.
- **Kriteria selesai:** owner menyetujui APK rilis setelah mencoba sendiri (gate terakhir PRD).

## Repo (publik, diputuskan)

- **Publik.** Alasan: F-Droid mewajibkan source publik; GPL-3.0-only mewajibkan source tersedia untuk pengguna; copyleft GPL adalah perlindungan terhadap pencurian source (fork wajib share-alike); kelima kompetitor publik; repo privat akan mengorbankan F-Droid dan kepercayaan komunitas. Kekhawatiran owner soal pencurian source (kasus adip-cinema-web) dicatat, tapi konteksnya berbeda (app FOSS GPL vs proyek web).
- **Mirror cadangan** ke forge kedua saat rilis pertama (mitigasi takedown, R7).
- **Branch:** main sebagai satu-satunya branch kerja di awal (satu pengembang); tag `v0.9.x` dan `v1.0.0` untuk rilis. Tidak ada branch develop yang terpisah sebelum tim membesar.
- **Secrets:** signing key rilis dan token apa pun TIDAK PERNAH masuk repo; signing key di GitHub Actions secrets; tidak ada secret di kode atau di file yang ter-commit (cek dengan skill check_secrets_before_push sebelum tiap push).

## CI GitHub Actions

Mengikuti pola repo owner (ayoqris-mobile, dokter-hp: build APK via GitHub Actions, rilis lewat tag).

- **Workflow `ci.yml` (setiap push dan pull request):** checkout, setup Flutter (versi dipin 3.47.8), `flutter pub get`, `flutter analyze` (gagal bila ada warning), `flutter test`, build APK debug split per ABI (verifikasi ukuran, gagal bila di atas 25 MB per ABI), upload APK sebagai artifact.
- **Workflow `release.yml` (saat tag `v*` dibuat):** build APK rilis split per ABI + AAB (bila diperlukan F-Droid), tanda tangan dengan key dari secrets, hitung checksum SHA-256, buat GitHub Release dengan CHANGELOG dan checksum, upload APK.
- **Cache:** pub cache dan Gradle cache diaktifkan supaya build tidak mengunduh ulang tiap kali.
- **Flutter version pin:** versi Flutter dipin di workflow; bump versi Flutter adalah perubahan yang disengaja, bukan otomatis.
- **Screenshot test:** job terpisah yang menjalankan screenshot per layar (bagian 5) di emulator, artifact berupa gambar yang bisa diperiksa owner.

## Strategi tes

- **Analyze:** `flutter analyze` tanpa warning di CI (K13). Warning sama dengan gagal.
- **Unit test:** logika murni (pemilih itag, rumus skor "lagu untukmu", klasifikasi error, merge backup, migrasi backup, LRU eviction). Target: semua fungsi murni punya tes.
- **Widget test:** tiap layar utama (20 layar) punya widget test untuk keempat state (loading, kosong, error, offline) bila relevan.
- **Integration test:** alur ujung ke ujung J1-J5 (cari dan putar, unduh lalu offline, buat playlist, lanjutkan setelah ditutup, hadapi kerusakan) di emulator.
- **Screenshot per layar:** 20 layar dipotret di 2 ukuran (360 dp dan tablet) tiap rilis; owner memeriksa hasil potret sebelum menyetujui rilis. Klaim "sudah fix" wajib bukti screenshot gejala nyata, bukan bacaan kode.
- **Perangkat nyata:** uji di HP RAM 3 GB dan API 26 (perangkat target PRD); uji stress 10.000 lagu (K11); uji pemasangan APK dari nol (unduh dari GitHub Release, pasang, buka pertama kali).
- **Uji pemahaman copy:** 5 pengguna (atau owner + 4 orang) membaca pesan error dan label tombol tanpa penjelasan; label "Periksa pembaruan" wajib dipahami.
- **Uji aksesibilitas:** TalkBack di 3 alur utama, skala font 1,3x, target sentuh 48 dp, kontras AA.
- **Keamanan:** Red-Blue-Red sesuai P9; audit dependensi sebelum tiap rilis (perintah audit toolchain Dart diverifikasi di P0).

## Rilis

- **Penomoran:** 0.9.x build uji, v1.0.0 rilis publik pertama (D13).
- **Checklist rilis:** K1-K15 lolos; Red-Blue-Red nol temuan kritis, tinggi, sedang; README + PRIVACY_POLICY.md + CHANGELOG mutakhir; checksum SHA-256 di catatan rilis; metadata F-Droid lengkap; pengajuan IzzyOnDroid.
- **F-Droid:** pengajuan setelah 3 bulan pengembangan aktif (kebijakan F-Droid); flag NonFreeNet pasti menempel (app mengakses layanan jaringan non-free) dan bukan penghalang.
- **Hotfix config:** config remote bisa diperbarui tanpa rilis app (TTL 6 jam); bila owner tidak bisa dihubungi lebih dari 30 hari saat kerusakan aktif, tim menerbitkan hotfix config sesuai otorisasi delegasi (R9).

## Risiko yang dibawa ke Fase 2 (ringkas, detail di PRD bagian 9)

R1 YouTube berubah; R2 satu maintainer paket audio; R3 audio_service di atas androidx.media deprecated; R4 F-Droid atas config remote; R5 just_audio di Media3 1.4.1; R6 kerentanan QuickJS; R7 tindakan hukum; R8 scope creep; R9 ketergantungan satu owner; R10 pengguna mengira app rusak total; R11 impor Spotify jalur A.

## Ukuran paket (relatif, tanpa tanggal)

PRD memutuskan tanpa tanggal karena estimasi waktu tanpa bukti build pertama adalah tebakan. Ukuran relatif di bawah ini untuk urutan dan perencanaan, bukan janji:

| Paket | Ukuran relatif | Alasan |
|-------|---------------|--------|
| P0 Fondasi | Kecil | Repo + skeleton + CI dasar |
| P1 Spike ekstraksi | Besar | 6 spike, ketidakpastian tertinggi, gate go atau no-go |
| P2 Player core | Sedang | Stack audio terverifikasi, tapi integrasi MediaSession dan notifikasi butuh uji perangkat |
| P3 Database dan library | Sedang | Skema 15 tabel sudah dirancang; migrasi dan FTS5 butuh tes |
| P4 Pencarian dan browse | Sedang | Parser respons InnerTube butuh penyesuaian dengan respons nyata |
| P5 Unduhan dan cache | Sedang | DownloadService, resume, rekonsiliasi |
| P6 Ketahanan | Kecil sampai sedang | Config remote + kanari + klasifikasi |
| P7 Fitur Should | Sedang | Lirik bergantung verifikasi penyedia |
| P8 Backup dan ekspor | Kecil | Format JSON sudah dirancang |
| P9 Keamanan | Sedang | 3 ronde Red, perbaikan temuan |
| P10 Rilis | Kecil | Dokumen + metadata + pengajuan |

Setelah P1 selesai, ukuran paket berikutnya dihitung ulang dengan bukti (kecepatan build nyata, kesulitan parser nyata). Revisi ukuran dicatat, bukan disembunyikan.

## Checklist 7 skill anti-slop

- **local-design-taste-frontend**: tidak relevan langsung (dokumen rencana, bukan desain); token desain A12 dirujuk, tidak dibuat ulang.
- **local-impeccable**: tiap paket punya kriteria selesai yang bisa diuji; tidak ada paket "selesai" tanpa APK demo.
- **local-humanizer**: rencana ditulis dengan kalimat biasa; istilah teknis dijelaskan saat pertama muncul.
- **local-stop-slop**: tidak ada kata haram; tidak ada klaim kecepatan tanpa bukti.
- **local-no-ai-slop**: tidak ada tanggal karangan; ukuran relatif dinyatakan sebagai ukuran relatif, bukan janji hari.
- **local-avoid-ai-writing**: kalimat aktif dan pendek.
- **local-anti-slop (rulebook)**: tanpa em dash, tanpa en dash, tanpa karakter persen; tanpa emoji.
