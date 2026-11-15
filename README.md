# Laras

Pemutar musik Android yang gratis, tanpa iklan, dan bisa dipakai offline.

Laras memutar lagu dari YouTube dan YouTube Music, menyimpan lagu di HP lewat unduhan, dan tidak punya server, akun, atau iklan. App ini masih dalam pengembangan awal. Versi yang ada di repo ini adalah fondasi (0.9.x). Rilis publik pertama adalah v1.0.0.

[English version](#english)

## Fitur yang direncanakan untuk v1

- Cari dan putar lagu dari YouTube Music, tanpa login.
- Unduh lagu, album, dan playlist, lalu putar tanpa internet.
- Library, playlist, favorit, dan riwayat putar, semuanya tersimpan di HP.
- Antrean putar yang tidak hilang saat app ditutup.
- Notifikasi media, kontrol layar kunci, headset, dan Bluetooth.
- Backup dan impor data dalam satu file.
- Tanpa akun, tanpa telemetri, tanpa iklan, tanpa server.

Daftar ini adalah rencana, bukan janji. Fitur masuk v1 bila sudah jadi dan teruji. Yang belum jadi tidak tampil di app.

## Bukan produk resmi

Laras adalah client tidak resmi. Laras bukan produk YouTube atau Google, dan tidak berafiliasi dengan keduanya.

Laras memakai akses tidak resmi ke layanan YouTube dan YouTube Music. Cara ini melanggar ketentuan layanan YouTube. YouTube bisa mengubah layanannya kapan saja tanpa pemberitahuan, dan perubahan itu bisa membuat Laras berhenti berfungsi sebagian atau seluruhnya. Lagu yang sudah diunduh tetap bisa diputar bila itu terjadi.

Nama dan logo YouTube adalah milik Google. Laras tidak memakai nama, logo, atau merek YouTube atau Spotify di nama app, ikon, atau judul.

## Privasi

- Laras tidak mengumpulkan data pengguna. Tidak ada akun, tidak ada telemetri, tidak ada pelacak.
- Semua data app (library, playlist, favorit, riwayat, antrean, pengaturan) tersimpan lokal di HP. Data itu tidak dikirim ke server milik app, karena app ini tidak punya server.
- Saat app dipakai, pihak ketiga menerima sebagian data: Google dan YouTube menerima alamat IP, kueri pencarian, dan permintaan stream. Penyedia lirik (bila lirik diaktifkan) menerima alamat IP dan judul lagu. Host config remote (GitHub Releases) menerima alamat IP saat app memeriksa pembaruan konfigurasi.
- Pengguna bisa menghapus semua data dari dalam app.

Kebijakan privasi lengkap ada di `PRIVACY_POLICY.md` (ditulis di P10, sebelum rilis v1.0.0).

## Cara pasang

Unduh APK dari [GitHub Releases](https://github.com/adiprmx/laras/releases), lalu pasang di HP Android (API 26 ke atas). Belum ada rilis sampai v1.0.0 diterbitkan. Build uji 0.9.x diterbitkan sebagai pre-release dan bisa berubah sewaktu-waktu.

Laras tidak ada di Play Store. Pengajuan ke IzzyOnDroid dan F-Droid menyusul setelah rilis.

## Cara build dari source

Prasyarat: Flutter 3.47.8 (versi yang dipakai CI; lihat `.github/workflows/ci.yml`).

```sh
git clone https://github.com/adiprmx/laras.git
cd laras
flutter pub get
flutter run
```

Build APK debug split per ABI:

```sh
flutter build apk --debug --split-per-abi
```

Target ukuran APK: maks 25 MB per ABI untuk APK rilis. CI memeriksa batas itu pada APK rilis; ukuran APK debug hanya dilaporkan (APK debug memang jauh lebih besar karena mesin debug dan simbol debug).

## Cara kontribusi

Baca [CONTRIBUTING.md](CONTRIBUTING.md) sebelum mengirim pull request. Kode perilaku kontributor ada di [CODE_OF_CONDUCT.md](CODE_OF_CONDUCT.md). Laporan keamanan mengikuti [SECURITY.md](SECURITY.md).

## Lisensi

Laras dilisensikan di bawah GNU General Public License v3.0 only (GPL-3.0-only). Lihat [LICENSE](LICENSE) untuk teks lengkapnya.

---

<a id="english"></a>

# Laras (English)

A free Android music player with no ads that works offline.

Laras plays music from YouTube and YouTube Music, stores songs on your phone through downloads, and has no server, no account, and no ads. The app is in early development. What is in this repo is the foundation (0.9.x). The first public release is v1.0.0.

## Planned features for v1

- Search and play songs from YouTube Music, without logging in.
- Download songs, albums, and playlists, then play them without internet.
- Library, playlists, favorites, and play history, all stored on your phone.
- A play queue that survives closing the app.
- Media notification, lock screen controls, headset, and Bluetooth controls.
- Backup and import of your data in one file.
- No account, no telemetry, no ads, no server.

This list is a plan, not a promise. A feature ships in v1 once it is done and tested. Unfinished features do not appear in the app.

## Not an official product

Laras is an unofficial client. It is not a YouTube or Google product, and it is not affiliated with either.

Laras uses unofficial access to YouTube and YouTube Music services. This violates YouTube's terms of service. YouTube can change its service at any time without notice, and such a change can partly or fully break Laras. Downloaded songs keep playing if that happens.

YouTube names and logos belong to Google. Laras does not use YouTube or Spotify names, logos, or brands in the app name, icon, or title.

## Privacy

- Laras collects no user data. No account, no telemetry, no trackers.
- All app data (library, playlists, favorites, history, queue, settings) stays on your phone. None of it goes to an app server, because the app has no server.
- While you use the app, third parties receive some data: Google and YouTube receive your IP address, search queries, and stream requests. The lyrics provider (if lyrics are enabled) receives your IP address and song titles. The remote config host (GitHub Releases) receives your IP address when the app checks for config updates.
- You can delete all data from inside the app.

The full privacy policy lives in `PRIVACY_POLICY.md` (written in P10, before the v1.0.0 release).

## Install

Download the APK from [GitHub Releases](https://github.com/adiprmx/laras/releases) and install it on an Android phone (API 26 and up). There is no release until v1.0.0 ships. Test builds (0.9.x) ship as pre-releases and can change at any time.

Laras is not on the Play Store. IzzyOnDroid and F-Droid submissions follow after release.

## Build from source

Prerequisite: Flutter 3.47.8 (the version CI uses; see `.github/workflows/ci.yml`).

```sh
git clone https://github.com/adiprmx/laras.git
cd laras
flutter pub get
flutter run
```

Build a debug APK, split per ABI:

```sh
flutter build apk --debug --split-per-abi
```

APK size target: 25 MB max per ABI for the release APK. CI checks that limit on release APKs; debug APK sizes are reported only (debug APKs are inherently much larger — unstripped engine and debug symbols).

## Contribute

Read [CONTRIBUTING.md](CONTRIBUTING.md) before opening a pull request. The contributor code of conduct is in [CODE_OF_CONDUCT.md](CODE_OF_CONDUCT.md). Security reports follow [SECURITY.md](SECURITY.md).

## License

Laras is licensed under the GNU General Public License v3.0 only (GPL-3.0-only). See [LICENSE](LICENSE) for the full text.
