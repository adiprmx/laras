# Laras

Pemutar musik Android yang gratis, tanpa iklan, dan bisa dipakai offline.

Laras memutar lagu dari YouTube dan YouTube Music. Lagu yang kamu unduh tersimpan di HP dan bisa diputar tanpa internet. Laras tidak punya server, akun, atau iklan.

[English version](#english)

## Fitur

- Cari lagu dari YouTube Music tanpa login, dengan saran saat mengetik dan riwayat pencarian.
- Cari di Library-mu sendiri, termasuk saat offline.
- Putar lagu lewat internet, atau unduh dulu lalu putar tanpa internet.
- Unduhan bisa dijeda dan dilanjutkan, dengan tiga pilihan kualitas dan pilihan unduh WiFi saja.
- Lagu yang pernah diputar bisa diputar lagi tanpa internet, sampai batas ruang yang kamu atur.
- Library, playlist, favorit, dan riwayat putar, semuanya tersimpan di HP.
- Antrean putar kembali seperti semula setelah app ditutup.
- Lirik tersinkron dan lirik biasa, dari LRCLIB.
- Sleep timer, equalizer perangkat, kecepatan dan nada putar.
- Salinan data dalam satu file, bisa dipulihkan di HP lain.
- Impor playlist Spotify dari file milikmu atau dari tautan playlist publik, tanpa API Spotify dan tanpa login. Tautan publik hanya bisa dibaca 30 lagu pertamanya.
- Notifikasi media, kontrol layar kunci, headset, dan Bluetooth.
- Tautan youtu.be dan music.youtube.com yang dibuka dari luar app memutar lagunya di Laras.

Yang belum ada di versi ini: unduh album atau playlist sekaligus (unduh per lagu sudah bisa), pemutar file audio di HP, dan widget layar beranda.

## Cara pasang

Unduh APK dari [GitHub Releases](https://github.com/adiprmx/laras/releases), lalu pasang di HP Android (API 26 ke atas, Android 8.0+). Pilih APK sesuai HP kamu: arm64-v8a untuk hampir semua HP baru, armeabi-v7a untuk HP lama 32-bit. APK rilis di bawah 25 MB per ABI.

Laras tidak ada di Play Store. Pengajuan ke IzzyOnDroid menyusul.

## Bukan produk resmi

Laras adalah client tidak resmi. Laras bukan produk YouTube atau Google, dan tidak berafiliasi dengan keduanya.

Laras memakai akses tidak resmi ke layanan YouTube dan YouTube Music. Cara ini melanggar ketentuan layanan YouTube. YouTube bisa mengubah layanannya kapan saja tanpa pemberitahuan, dan perubahan itu bisa membuat Laras berhenti berfungsi sebagian atau seluruhnya. Lagu yang sudah diunduh tetap bisa diputar bila itu terjadi.

Nama dan logo YouTube adalah milik Google. Laras tidak memakai nama, logo, atau merek YouTube atau Spotify di nama app, ikon, atau judul.

Suka lagu yang kamu dengar? Dukung artisnya dengan mendengarkan di layanan resmi atau membeli karyanya.

## Privasi

- Laras tidak mengumpulkan data pengguna. Tidak ada akun, tidak ada telemetri, tidak ada pelacak.
- Semua data app (library, playlist, favorit, riwayat, antrean, pengaturan, unduhan) tersimpan lokal di HP. Data itu tidak dikirim ke server milik app, karena app ini tidak punya server.
- Saat app dipakai, pihak ketiga menerima sebagian data: Google dan YouTube menerima alamat IP, kueri pencarian, dan permintaan stream; LRCLIB menerima alamat IP dan judul, artis, dan durasi lagu saat kamu membuka lirik; GitHub menerima alamat IP saat app memeriksa pembaruan konfigurasi; open.spotify.com menerima alamat IP hanya bila kamu mengimpor playlist dari tautan publik.
- Pengguna bisa menghapus semua data dari dalam app.

Kebijakan privasi lengkap ada di [PRIVACY_POLICY.md](PRIVACY_POLICY.md), dan bisa dibaca di dalam app dari Pengaturan, lalu Tentang, lalu Kebijakan privasi.

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

Target ukuran APK: maks 25 MB per ABI untuk APK rilis (arm64-v8a dan armeabi-v7a; x86_64 tidak dirilis karena hanya dipakai emulator). CI memeriksa batas itu pada APK rilis; ukuran APK debug hanya dilaporkan (APK debug memang jauh lebih besar karena mesin debug dan simbol debug).

## Cara kontribusi

Baca [CONTRIBUTING.md](CONTRIBUTING.md) sebelum mengirim pull request. Kode perilaku kontributor ada di [CODE_OF_CONDUCT.md](CODE_OF_CONDUCT.md). Laporan keamanan mengikuti [SECURITY.md](SECURITY.md).

## Lisensi

Laras dilisensikan di bawah GNU General Public License v3.0 only (GPL-3.0-only). Lihat [LICENSE](LICENSE) untuk teks lengkapnya.

---

<a id="english"></a>

# Laras (English)

A free Android music player with no ads that works offline.

Laras plays music from YouTube and YouTube Music. Songs you download stay on your phone and play without internet. Laras has no server, no account, and no ads.

## Features

- Search YouTube Music without logging in, with suggestions as you type and search history.
- Search your own Library, including offline.
- Stream songs, or download them first and play them without internet.
- Downloads can pause and resume, with three quality choices and a WiFi-only option.
- Songs you have played before can play again offline, up to the space limit you set.
- Library, playlists, favorites, and play history, all stored on your phone.
- The play queue comes back as it was after the app is closed.
- Synced and plain lyrics, from LRCLIB.
- Sleep timer, device equalizer, playback speed and pitch.
- Backup of your data in one file, restorable on another phone.
- Spotify playlist import from your own file or from a public playlist link, without any Spotify API and without logging in. A public link only reads the first 30 tracks.
- Media notification, lock screen controls, headset, and Bluetooth controls.
- youtu.be and music.youtube.com links opened from outside the app play that song in Laras.

Not in this version yet: downloading a whole album or playlist at once (downloading one song at a time works), a player for audio files on your phone, and a home screen widget.

## Install

Download the APK from [GitHub Releases](https://github.com/adiprmx/laras/releases) and install it on an Android phone (API 26 and up, Android 8.0+). Pick the APK for your phone: arm64-v8a for almost all newer phones, armeabi-v7a for older 32-bit phones. Release APKs stay under 25 MB per ABI.

Laras is not on the Play Store. An IzzyOnDroid submission follows.

## Not an official product

Laras is an unofficial client. It is not a YouTube or Google product, and it is not affiliated with either.

Laras uses unofficial access to YouTube and YouTube Music services. This violates YouTube's terms of service. YouTube can change its service at any time without notice, and such a change can partly or fully break Laras. Downloaded songs keep playing if that happens.

YouTube names and logos belong to Google. Laras does not use YouTube or Spotify names, logos, or brands in the app name, icon, or title.

Like a song you hear? Support the artist by listening on an official service or buying their work.

## Privacy

- Laras collects no user data. No account, no telemetry, no trackers.
- All app data (library, playlists, favorites, history, queue, settings, downloads) stays on your phone. None of it goes to an app server, because the app has no server.
- While you use the app, third parties receive some data: Google and YouTube receive your IP address, search queries, and stream requests; LRCLIB receives your IP address and the title, artist, and duration of a song when you open its lyrics; GitHub receives your IP address when the app checks for config updates; open.spotify.com receives your IP address only when you import a playlist from a public link.
- You can delete all data from inside the app.

The full privacy policy lives in [PRIVACY_POLICY.md](PRIVACY_POLICY.md) (Indonesian), and can be read inside the app from Settings, then About, then Privacy Policy.

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

APK size target: 25 MB max per ABI for the release APK (arm64-v8a and armeabi-v7a; x86_64 is not shipped, emulator-only). CI checks that limit on release APKs; debug APK sizes are reported only (debug APKs are inherently much larger, unstripped engine and debug symbols).

## Contribute

Read [CONTRIBUTING.md](CONTRIBUTING.md) before opening a pull request. The contributor code of conduct is in [CODE_OF_CONDUCT.md](CODE_OF_CONDUCT.md). Security reports follow [SECURITY.md](SECURITY.md).

## License

Laras is licensed under the GNU General Public License v3.0 only (GPL-3.0-only). See [LICENSE](LICENSE) for the full text.
