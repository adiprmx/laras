# Verifikasi K1-K15, Laras v1.0.0

Tanggal: 17 November 2026. Commit kerja: b85915ee + perubahan
dokumen P10 (README, PRIVACY_POLICY.md, CHANGELOG, bump versi
1.0.0+2, layar kebijakan privasi). Kriteria dari PRD bagian 7.
Status ditulis jujur: yang belum bisa dibuktikan di HP owner
ditandai TERTUNDA, bukan lolos.

Ringkasan: LOLOS 6 (K4, K7, K9, K12, K13, K14), LOLOS TES 2
(K6, K10), TERTUNDA 6 (K1, K2, K3, K5, K8, K11), SEBAGIAN 1 (K15).

| ID | Kriteria | Status |
|----|----------|--------|
| K1 | Kecepatan resolve | TERTUNDA |
| K2 | Cold start | TERTUNDA |
| K3 | Pemutaran pertama | TERTUNDA |
| K4 | Ukuran APK | LOLOS |
| K5 | Keberhasilan pemutaran | TERTUNDA |
| K6 | Fallback antar client | LOLOS TES, bukti live TERTUNDA |
| K7 | Config remote | LOLOS |
| K8 | Offline penuh | TERTUNDA |
| K9 | Cache tidak menghapus unduhan | LOLOS |
| K10 | Antrean persisten | LOLOS TES, cek perangkat TERTUNDA |
| K11 | Ketahanan memori | TERTUNDA |
| K12 | Keamanan | LOLOS |
| K13 | Kualitas kode | LOLOS |
| K14 | Copy bahasa sehari-hari | LOLOS |
| K15 | Distribusi dan dokumen | SEBAGIAN (menunggu persetujuan owner) |

## K1: Kecepatan resolve (TERTUNDA)

Target: median di bawah 2 detik per lagu (uji 60 lagu).
Bukti yang ada: median resolve di VM 4.049 ms (spike P1, 16 Nov),
dengan median solver 10,5 ms. Angka VM tidak dipakai sebagai
bukti: VM dibatasi egress, jadi angka itu mengukur jaringan VM,
bukan kecepatan app. Tidak ada pengukuran resolve di HP.
Yang membuka item ini: uji 60 lagu di HP owner, hitung median
waktu resolve dari log resolve per client.

## K2: Cold start (TERTUNDA)

Target: TTID 1,5 detik, TTFD 2,5 detik (protokol 5 kali ukur,
buang min dan maks, perangkat kelas menengah).
Bukti yang ada: belum ada pengukuran `--trace-startup` atau
`adb am start -W` di perangkat.
Yang membuka item ini: ukur di HP owner dengan protokol PRD.

## K3: Pemutaran pertama (TERTUNDA)

Target: di bawah 2 detik di koneksi baik (uji 20 lagu dari
keadaan dingin).
Bukti yang ada: belum ada pengukuran di perangkat.
Yang membuka item ini: uji 20 lagu dari keadaan dingin di HP
owner, di koneksi baik.

## K4: Ukuran APK (LOLOS)

Target: maks 25 MB per ABI (arm64); target regang 20 MB.
Bukti: APK rilis dari CI p8b4 (run 43974047464, commit
b85915ee): arm64-v8a 23.922.360 byte (22,81 MiB), armeabi-v7a
21.335.252 byte (20,35 MiB). Batas 25 MiB = 26.214.400 byte.
Kedua ABI di bawah batas; arm64 menyisakan 2,19 MiB. Target
regang 20 MB tidak tercapai dan tidak diklaim tercapai.
Catatan: x86_64 tidak dirilis (hanya dipakai emulator).

## K5: Keberhasilan pemutaran (TERTUNDA)

Target: 57 dari 60 lagu berhasil (95 persen); uji 60 lagu
populer dan kurang populer, 20 lagu per hari selama 3 hari.
Bukti yang ada: tes kanari harian dan tes resolve lolos di
otomasi, tapi itu bukan uji 60 lagu di perangkat selama 3 hari.
Yang membuka item ini: uji 3 hari di HP owner sesuai protokol
PRD.

## K6: Fallback antar client (LOLOS TES, bukti live TERTUNDA)

Target: 10 dari 10 lagu tetap jalan tanpa error terlihat saat
client utama dimatikan di config.
Bukti: tes fallback lolos (spike P1 tes 3 + tes orchestrator
fallback): client gagal satu per satu, client berikutnya
mengambil alih, tanpa error terlihat. Pola fallback yang sama
dipakai jalur unduhan (perbaikan Blue 2 R2-L5).
Yang membuka bukti live: matikan client utama di config remote
di HP owner, putar 10 lagu, pastikan semuanya jalan.

## K7: Config remote (LOLOS)

Target: config baru dipakai dalam 6 jam tanpa install ulang.
Bukti: TTL 6 jam terbukti di tes P1 (spike 4) dan tes K7 P6
(tes menunggu refresh latar selesai menulis config baru ke
cache, tidak flaky lagi). Rotasi hash 17 Nov membuktikan jalur
ini di produksi: tag `config-v1` diperbarui ke 3 hash
(fad7e4e9 sts 20767, ad8d59ae sts 20768, b559f50c sts 20770)
dan URL raw terverifikasi; solver terbukti live di ketiga hash
(reproduksi koordinator). Tombol "Periksa pembaruan" memaksa
refresh di luar TTL.

## K8: Offline penuh (TERTUNDA)

Target: unduh 10 lagu, aktifkan mode pesawat, putar semuanya.
Bukti yang ada: tes unduhan dan cache lolos di otomasi. Tes
unduh live dari VM gagal 403 di 0 byte karena IP egress VM
ditolak googlevideo. Itu masalah lingkungan, bukan bug app,
tapi artinya bukti unduh end-to-end belum ada.
Yang membuka item ini: uji di HP owner, yaitu unduh 10 lagu,
aktifkan mode pesawat, putar semuanya.

## K9: Cache tidak menghapus unduhan (LOLOS)

Target: 0 unduhan terhapus oleh eviction.
Bukti: tes eviction P5. Cache diisi sampai batas, semua
unduhan diperiksa masih ada. Unduhan dan cache memakai
penyimpanan terpisah dengan batas masing-masing.

## K10: Antrean persisten (LOLOS TES, cek perangkat TERTUNDA)

Target: antrean 50 lagu utuh setelah app ditutup paksa dan
dibuka lagi.
Bukti: restore antrean P7 + tes (schema v4, tabel
PlaybackState; migrasi v3 ke v4 hanya membuat tabel).
Lagu unduhan pulih offline; lagu streaming butuh satu resolve
jaringan. Dengan shuffle aktif, urutan pulih diacak ulang
(lagu yang sama, lagu yang sama diputar pertama).
Yang membuka cek perangkat: buat antrean 50 lagu di HP owner,
tutup paksa app, buka lagi, bandingkan antreannya.

## K11: Ketahanan memori (TERTUNDA)

Target: 10.000 lagu, 1.000 entri riwayat, antrean 500, tanpa
OOM, di RAM 3 GB.
Bukti yang ada: belum ada uji stress di perangkat RAM 3 GB.
Ambang memori diputuskan Fase 2 setelah pengukuran pertama
(sesuai PRD). Pengukuran pertama itu belum terjadi.
Yang membuka item ini: uji stress di perangkat RAM 3 GB,
lalu tetapkan ambang dari hasil ukur.

## K12: Keamanan (LOLOS)

Target: nol temuan kritis, tinggi, dan sedang (siklus
Red-Blue-Red, maks 5 ronde).
Bukti: siklus selesai dalam 4 ronde. Red 3 (17 Nov):
0 kritis / 0 tinggi / 0 sedang / 1 rendah / 4 info; Blue 3
menutup keempat item info dan item rendah. Red 4 (17 Nov):
0 kritis / 0 tinggi / 0 sedang / 0 rendah / 3 info, 4/4 item
Blue 3 tertutup; Blue 4 menutup ketiga item info. Tidak ada
temuan kritis/tinggi/sedang yang tersisa.

## K13: Kualitas kode (LOLOS)

Target: `flutter analyze` tanpa warning; tes jalur resolve,
fallback, unduhan, migrasi lolos (CI GitHub Actions).
Bukti: `flutter analyze` bersih ("No issues found!"), suite
penuh `flutter test --exclude-tags live` 892/892 lolos
(885 di commit b85915ee + 7 tes baru P10: layar kebijakan
privasi, navigasi dari Tentang, invarian isi kebijakan).
CI run 43974047464 (commit b85915ee) sukses. Tes live
dikecualikan dari suite sesuai kebijakan (butuh jaringan
dan perangkat).

## K14: Copy bahasa sehari-hari (LOLOS)

Target: 0 istilah teknis di teks layar.
Bukti: tes `arb_no_jargon_test.dart` lolos (scan batas kata
atas nilai ARB: spike, resolve, log, demo, build, client,
cache, server; 0 pelanggar). ARB kini 426 kunci (423 +
3 kunci baru P10: privacyPolicyTitle, privacyPolicyLoading,
privacyPolicyLoadFailed, semuanya bahasa sehari-hari).
Audit copy manual tiap layar mengikuti checklist PRD bagian 6;
kata "cache" tidak pernah muncul di teks user.

## K15: Distribusi dan dokumen (SEBAGIAN)

Target: README, PRIVACY_POLICY.md, CHANGELOG, metadata
F-Droid, GitHub Release dengan checksum.
Bukti: README ditulis ulang untuk v1.0.0; PRIVACY_POLICY.md
baru (kontak adiprmx@gmail.com, menyebut LRCLIB); CHANGELOG
difinalisasi dengan header `## [1.0.0]` tanpa tanggal
(ekstraksi release.yml terverifikasi dengan simulasi awk);
dokumen ini; metadata fastlane dikerjakan tim lain.
Yang membuka item ini: persetujuan owner (gerbang akhir),
lalu GitHub Release v1.0.0 dengan checksum SHA-256 dari
workflow rilis. Rilis TIDAK diterbitkan sebelum owner
menyetujui.
