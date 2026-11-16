# Dependensi Laras — tinjauan keamanan supply chain

Dokumen ini adalah catatan tinjauan dependensi per rencana keamanan §5.1
(setiap dependensi baru wajib ditinjau SEBELUM masuk `pubspec.yaml`).
Tinjauan terakhir: **16 November 2026** (Tim Blue 1, ronde Red 1).
Angka pub points / likes / unduhan dibaca dari API pub.dev pada tanggal
itu; versi terbaru dibaca dari API paket pub.dev pada tanggal yang sama.
Lisensi dibaca dari file `LICENSE` paket di pub cache lokal.

Aturan proyek yang berlaku:

- `pubspec.yaml` mem-pin versi secara persis; `pubspec.lock` di-commit
  supaya build reproducible. Update dependensi dilakukan secara sengaja
  (`flutter pub outdated`, tinjau changelog, uji), bukan otomatis.
- Target minimal pub points 130/160 untuk dependensi inti (§5.1).
- Daftar larangan dependensi (§5.2): `.github/banned-dependencies.txt`,
  diperiksa otomatis oleh `.github/workflows/vulncheck.yml` (CI gagal
  bila ada paket larangan di `pubspec.lock` atau file Gradle).
- Pemindaian kerentanan CI: `dartvulncheck` 0.4.0 atas `pubspec.lock` +
  SDK, tiap push/PR ke main dan mingguan (Senin 02:00 UTC).

## 1. Dependensi langsung (tinjauan §5.1)

Semua versi terkunci di bawah ini adalah versi terbaru di pub.dev pada
16 November 2026 (tidak ada yang tertinggal).

| Paket | Versi | Pub points | Likes | Unduhan/30 hari | Publisher | Lisensi | Rilis terakhir |
|---|---|---|---|---|---|---|---|
| dio | 5.11.1 | 160/160 | 8.374 | 5.487.789 | flutter.cn | MIT | 2026-09-04 |
| just_audio | 0.10.6 | 150/160 | 4.152 | 1.628.096 | ryanheise.com | MIT (+ Apache-2.0 di bagian Android) | 2026-06-29 |
| audio_service | 0.18.19 | 140/160 | 1.335 | 350.459 | ryanheise.com | MIT | 2026-06-29 |
| audio_session | 0.2.4 | 150/160 | 367 | 1.844.573 | ryanheise.com | MIT | 2026-06-29 |
| drift | 2.35.4 | 160/160 | 2.492 | 2.000.930 | simonbinder.eu | MIT | 2026-11-08 |
| drift_flutter | 0.3.1 | 160/160 | 70 | 652.909 | simonbinder.eu | MIT | 2026-07-11 |
| sqlite3 | 3.9.1 | 150/160 | 466 | 3.768.906 | simonbinder.eu | MIT | 2026-11-08 |
| gg_quickjs | 0.1.1 (fork git, §2.1) | 160/160 | 0 | 105 | — (tanpa publisher terverifikasi) | MIT | 2026-11-16 |
| cached_network_image_ce | 4.13.2 | 160/160 | 109 | 187.471 | erengun.dev | MIT | 2026-10-31 |
| path_provider | 2.1.6 | 160/160 | 5.574 | 10.738.928 | flutter.dev | BSD-3-Clause | 2026-06-15 |
| shared_preferences | 2.5.6 | 160/160 | 10.590 | 9.467.789 | flutter.dev | BSD-3-Clause | 2026-10-05 |

Catatan per paket:

- **dio 5.11.1** — HTTP client. Perilaku penting yang diverifikasi dari
  source-nya (Blue 1, R1-M3): `handleResponseStream` memompa body secara
  eager ke `StreamController` internal, jadi batas ukuran respons
  ditegakkan lewat `CancelToken` + `onReceiveProgress`
  (`ResponseSizeCap` di `lib/extractor/response_limits.dart`), bukan
  hanya lewat pembacaan stream.
- **just_audio 0.10.6 / audio_service 0.18.19 / audio_session 0.2.4** —
  satu maintainer (Ryan Heise), publisher terverifikasi, dirawat aktif.
  `audio_service` 140 poin masih di atas lantai 130.
- **drift 2.35.4 / drift_flutter 0.3.1 / sqlite3 3.9.1** — satu
  maintainer (Simon Binder), publisher terverifikasi. `sqlite3` 3.x
  membangun library native SQLite dari source amalgamation saat build
  (hook `build.dart` + `native_toolchain_c`); tidak ada `.so` prebuilt
  di dalam paket — memenuhi aturan §5.2 soal binary blob.
- **gg_quickjs 0.1.1 (fork git, R2-M3, lihat §2.1)** — mesin JavaScript
  (QuickJS-ng 0.18.0), pengganti quickjs_engine 0.1.7 (R1-H1, lihat
  §2). Fork dari `ggsuite/gg_quickjs` 0.1.0 (160 pub points, tapi
  adopsi masih tipis: 0 likes, 105 unduhan/30 hari, tanpa publisher
  terverifikasi) — dicatat sebagai risiko yang diterima karena tidak
  ada alternatif bermesin ≥ 0.16.0 yang lebih mapan. Build hook
  mengompilasi dari source (NDK di Android, Clang di host); tidak
  ada biner prebuilt. **Catatan dev:** `flutter test` /
  `flutter build` di host Linux butuh **Clang** — resolver compiler
  Dart hanya mencari clang untuk build host (gcc tidak dicoba);
  runner CI Ubuntu sudah membawa clang.
- **quickjs_engine 0.1.7 (DIHAPUS)** — mesin lama (QuickJS-NG 0.14.0,
  rentan CVE-2026-120438/120439/120440). Dihapus dari `pubspec.yaml`
  16 Nov 2026 (tepat di lantai 130 poin, 4 likes, tanpa publisher
  terverifikasi, sub-paket dari repo SVG satu maintainer). Entri
  `pub:quickjs_engine` di `.github/banned-dependencies.txt`
  dipertahankan sebagai penjaga agar mesin rentan tidak masuk lagi.
- **cached_network_image_ce 4.13.2** — fork Community Edition dari
  `cached_network_image` (paket aslinya tidak dirawat); dirawat aktif
  (rilis terakhir 16 hari sebelum tinjauan).
- **path_provider 2.1.6 / shared_preferences 2.5.6** — paket resmi
  Flutter (flutter.dev), Flutter Favorite, 160 poin.

## 2. Mesin JavaScript: quickjs_engine → gg_quickjs (R1-H1)

### Verifikasi CVE (dari sumber primer, 16 Nov 2026)

| CVE | Dampak | CVSS v4 | Status di 0.14.0 |
|---|---|---|---|
| CVE-2026-120438 | Integer overflow `js_proxy_get_own_property_names()` → heap buffer overflow (host 32-bit) | 8.5 High | Terpengaruh (OSV mencantumkan v0.14.0) |
| CVE-2026-120439 | Integer overflow `js_typed_array_sort()` | 8.3 High | Terpengaruh |
| CVE-2026-120440 | Memory leak `js_atomics_store()` | — (GHSA-wm7w-r6qf-3c9w) | Terpengaruh |

Ketiganya diperbaiki di QuickJS-NG **0.16.0** (rilis QuickJS-NG
mencantumkan ketiga perbaikan: #1609, #1610, #1611). Sumber: OSV
(osv.dev) untuk CVE-2026-120438/120439, VulnCheck + VulDB untuk
CVE-2026-120440, dan halaman rilis v0.16.0 QuickJS-NG.
Bundled engine terkonfirmasi di pub cache: `quickjs.h` QJS_VERSION
0.14.0.

### Putusan migrasi

- Jalur upgrade paket yang sama **buntu**: `quickjs_engine` masih 0.1.7
  (terbaru, 5 Nov 2026), README-nya menyatakan membundel QuickJS-NG
  0.14.0. Tidak ada versi baru yang membawa 0.16.0+.
- Pengganti: **gg_quickjs 0.1.0** (dipublikasi 2026-10-19, 160 pub
  points, MIT, repo github.com/ggsuite/gg_quickjs), membawa QuickJS-ng
  **0.17.0** (≥ 0.16.0 fix). Catatan penamaan: 0.1.0 adalah versi
  PAKET; 0.17.0 adalah versi QuickJS-ng yang dibawanya.
- Semua dependensi gg_quickjs sudah ada di `pubspec.lock` dengan versi
  yang memenuhi constraint (ffi 2.2.0, code_assets 2.2.0, hooks 2.2.0,
  logging 1.3.0, meta 1.19.0, native_toolchain_c 0.19.6, path 1.9.1,
  record_use 1.1.1) — resolusi trivial.
- API terverifikasi dari README + API reference pub.dev: `JsRuntime`
  dengan `JsRuntimeOptions` (`memoryLimit`, `maxStackSize`,
  `gcThreshold`, `timeout`), `evaluate()` melempar `JsException`
  bertipe, `JsRuntime.spawn()` untuk isolate latar, `interrupt()`,
  `dispose()`. Timeout gg_quickjs BERFUNGSI (ditegakkan via interrupt
  handler QuickJS-ng) — berbeda dari quickjs_engine 0.1.7 yang
  parameter `timeout`-nya tidak berfungsi (pelajaran P1).
- Sandbox: tanpa console/timers/fetch/fs secara default; dibangun tanpa
  quickjs-libc (tanpa modul `std`/`os`); build hook mengompilasi dari
  source dengan NDK — tidak ada prebuilt binary.
- Peringatan dari README gg_quickjs: `maxStackSize` default 256 KiB;
  limit > 512 KiB bisa crash native (stack isolate Dart ~1 MiB).
  Migrasi memakai 256 KiB eksplisit. QuickJS-ng 0.17.0 tidak selalu
  pulih dari OOM saat compile — catat di kode saat migrasi.

### Dampak ukuran APK (terukur, 16 Nov 2026)

Kompilasi proxy dengan gcc -O2 (x86-64, stripped) dari source 0.14.0
di pub cache:

| Komponen | Ukuran (stripped) |
|---|---|
| Core QuickJS-NG 0.14.0 saja (quickjs.c + libregexp.c + libunicode.c + dtoa.c) | 1.069.256 byte (1.044 KiB) |
| Core + bridge C++ quickjs_engine | 1.085.960 byte (1.061 KiB) |
| Kontribusi bridge | 16.704 byte (16 KiB) |

Catatan: quickjs_engine sudah core-only (quickjs-libc.c TIDAK
diikutkan di `native/CMakeLists.txt`), jadi perbandingan yang benar
adalah core 0.14.0 vs core 0.17.0 + bridge gg_quickjs. Catatan rilis
v0.17.0 hanya berisi perbaikan kecil/optimasi — tidak ada subsistem
baru yang membengkakkan biner. Delta yang diperkirakan **< ±100 KB**
(label: estimasi, bukan pengukuran — source 0.17.0 belum bisa diunduh
saat tinjauan karena egress VM mati), jauh di dalam headroom arm64
~2,7 MB (batas 25 MB, demo P3 24,5 MB). Ukuran final WAJIB dibaca dari
langkah "APK contents breakdown" CI setelah migrasi mendarat.

### Status

**Migrasi MENDARAT 16 November 2026** (Blue 1; push oleh koordinator):
`pubspec.yaml` memakai `gg_quickjs: 0.1.0`; `quickjs_engine` +
`sync_http` keluar dari tree. `_workerEntry`
`lib/extractor/cipher/signature_solver.dart` ditulis ulang ke API
`JsRuntime` (isolate pekerja + kill-on-timeout dipertahankan sebagai
backstop; `memoryLimit` 192 MiB, `timeout` 10 detik, `maxStackSize`
256 KiB; tanpa `registerFunction`; hasil solve wajib String).

### 2.1. Fork QuickJS-ng 0.18.0 (R2-M3, Blue 2, 16–17 Nov 2026)

**Masalah:** `gg_quickjs` 0.1.0 (terbaru di pub.dev) membundel
QuickJS-ng 0.17.0, tertinggal satu rilis dari 0.18.0 (1 Nov 2026).
Perbaikan 0.18.0 yang relevan: use-after-free #1781 (JS_NewContext
saat OOM) dan #1844 (WeakMap + symbol), OOM yang tidak bisa ditangkap
#1810, InternalErrors yang tidak bisa ditangkap #1814, infinite loop
#1829. Belum ada CVE untuk temuan-temuan ini (per Red 2).

**Jalur upgrade:** fork resmi-didokumentasikan paket — jalankan
`node tool/update-quickjs-ng.js v0.18.0` di salinan repo, lalu pakai
fork itu sebagai dependensi git. Upstream (`ggsuite/gg_quickjs`)
terakhir push 19 Okt 2026 dan belum merilis paket 0.18.0.

**Fork ini:**
- Repo: `github.com/adiprmx/gg_quickjs` (fork dari
  `ggsuite/gg_quickjs`, dibuat 16 Nov 2026 via API GitHub).
- Commit: `0bb8b583ea543b1bf3687a6a0d36ef0d655f9d89`
  ("fix: JSInterruptHandler signature for QuickJS-ng 0.18.0
  (JSContext*)"), di atas `c84a5011` ("QuickJS-ng 0.18.0 (fork
  Laras): UAF #1781/#1844 + OOM fixes, package 0.1.1"), 13 file
  berubah vs upstream `b96fc56`.
- Versi paket fork: 0.1.1 (bump dari 0.1.0; perubahan hanya
  QuickJS-ng 0.17.0 → 0.18.0 + dokumen fork + perbaikan signature
  interrupt handler).
- Pin di `pubspec.yaml`: dependensi git dengan `ref` commit penuh
  (BUKAN branch) supaya build reproduksibel:
  `url: https://github.com/adiprmx/gg_quickjs.git`,
  `ref: 0bb8b583ea543b1bf3687a6a0d36ef0d655f9d89`.
- Catatan 0.18.0: `JSInterruptHandler` kini `int (*)(JSContext *,
  void *)` (dulu `JSRuntime *`); `interrupt_handler` di
  `src/gg_quickjs.c` disesuaikan (parameter tidak dipakai — hanya
  `opaque` yang dibaca). Clang 16+ menolak signature lama sebagai
  error (CI run 43941844119 gagal di langkah Test karena ini);
  GCC menerimanya sebagai warning, jadi kegagalan ini lolos dari
  tes lokal yang memakai shim gcc.
- Workdir fork (clone lokal, bukan bagian repo Laras):
  `~/workspace/music-app/gg_quickjs-fork/`.

**Jalur update fork (bila QuickJS-ng / upstream merilis baru):**
1. Di workdir fork: `git fetch upstream` (remote upstream =
   `ggsuite/gg_quickjs`) lalu merge/rebasi perbaikan upstream.
2. `node tool/update-quickjs-ng.js vX.Y.Z` untuk versi QuickJS-ng
   baru; skrip memperbarui `src/quickjs-ng/` +
   `lib/src/quickjs_ng_version.dart`.
3. Bump versi paket di `pubspec.yaml` fork + entri CHANGELOG.
4. `dart test` di fork (versi + native + runtime + build hook;
   build hook butuh timeout panjang di VM lambat:
   `dart test --timeout 300s test/quickjs_ng_build_test.dart`).
5. Push fork, lalu bump `ref` di `pubspec.yaml` Laras +
   `flutter pub get` + jalankan `signature_solver_test.dart`.
6. **Kembali ke upstream** bila upstream merilis paket dengan
   QuickJS-ng ≥ 0.18.0: ganti dependensi git ke versi hosted biasa
   dan hapus catatan ini (instruksi yang sama tertulis di CHANGELOG
   fork).

**Verifikasi (16–17 Nov 2026):**
- Tes fork sendiri: 82/82 lolos — versi (1), native + runtime +
  exception + opsi (77), build hook (4). Satu kegagalan awal tes
  build hook terbukti timeout default 30 dtk di VM lambat (kompilasi
  quickjs.c butuh 2:44), bukan cacat fork.
- Tes solver Laras dengan fork: `signature_solver_test.dart` 6/6
  lolos; library native `libgg_quickjs.so` ter-build dari source
  0.18.0; `quickjsNgVersion` di checkout git = `'0.18.0'`.
- Tes kanari live 5/5: lihat catatan koordinator (dijalankan terpisah
  bila egress hidup).

Verifikasi:
- Tes unit `test/extractor/signature_solver_test.dart` (6 tes):
  `quickjsNgVersion` 0.17.0 ≥ 0.16.0, batas stack ≤ 512 KiB,
  evaluate + error bertipe + timeout (JsInterruptedError, runtime
  tetap bisa dipakai) + sandbox (tanpa fetch/console/timer).
- Tes live (egress sempat hidup 16 Nov 09:25–~10:28 WIB):
  `live_extractor_test.dart` + `live_search_test.dart` 7/7 lolos,
  termasuk resolve end-to-end lagu P0 (k2XdBPv0D3Y) dengan solver
  gg_quickjs nyata. Tes kanari 5/5 baru
  (`live_extractor_test.dart`, dengan retry 1x untuk kegagalan
  jaringan): percobaan pertama 4/5 — YsGwU8vTRsE gagal
  `connectionTimeout` saat egress mati (~10:30 WIB); jalankan ulang
  tes itu saat egress pulih untuk 5/5 bersih.
- Simulasi cek larangan lokal: 0 HIT (vulncheck tidak lagi merah
  karena mesin rentan; entri `pub:quickjs_engine` tetap sebagai
  penjaga).
- Ukuran final WAJIB dibaca dari langkah "APK contents breakdown"
  CI setelah migrasi mendarat (estimasi delta < ±100 KB, lihat di
  atas).

## 3. Daftar larangan (§5.2)

Daftar lengkap yang bisa dibaca mesin: `.github/banned-dependencies.txt`.
Ringkasan alasan:

- **Firebase (semua bentuk), Google Play Services/GMS, Sentry/Bugsnag/
  Instabug, analytics apa pun, SDK iklan apa pun** — dilarang keras
  oleh Inclusion Policy F-Droid untuk tracking/iklan; app ini satu
  varian tanpa tracker sama sekali (crash report memakai salin log
  manual, bukan pengiriman otomatis).
- **Library dengan binary blob yang tidak bisa dibangun dari source** —
  setiap dependensi native wajib bisa dibangun ulang dari source
  publik. Diverifikasi: quickjs_engine (Android dari source, NDK
  CMake), sqlite3 (amalgamation dikompilasi saat build).
- **quickjs_engine** — mesin JS rentan (R1-H1, lihat §2).

## 4. CI & supply chain (R1-L5/L6/L8)

- **Pin SHA action (L5):** semua `uses:` di `ci.yml`, `release.yml`,
  dan `vulncheck.yml` dipin ke commit SHA penuh (bukan tag yang bisa
  digeser), dengan tag aslinya di komentar. SHA diverifikasi dari
  GitHub API 16 Nov 2026: checkout v7.0.1
  `3d3c42e5aac5ba805825da76410c181273ba90b1`, setup-java v6.3.0
  `d1374f8ac74474200d16ef8ecee22c7ae7a51880`, flutter-action v2.23.0
  `1a449444c387b1966244ae4d4f8c696479add0b2`, cache v6.1.0
  `55cc8345863c7cc4c66a329aec7e433d2d1c52a9`, upload-artifact v7.0.2
  `cf430e030ddbb5b0abf93d22962f4752f3646cd9`.
- **Pemindaian kerentanan (L5):** `.github/workflows/vulncheck.yml` —
  `dartvulncheck` 0.4.0 (pub.dev, 2026-11-07) atas `pubspec.lock` +
  SDK, exit 3 bila ada kerentanan; `GITHUB_TOKEN` (default Actions)
  untuk repository advisories. Dipilih atas `flutter pub audit`
  karena juga mencakup SDK dan menggagalkan build saat ada temuan.
- **Obfuscation AAB (L6):** `release.yml` membangun AAB dengan
  `--obfuscate --split-debug-info=build/app/outputs/symbols-aab`,
  dan `symbols-aab.zip` ikut di-checksum + dipublikasikan bersama
  rilis (seperti `symbols.zip` untuk APK).
- **Gradle wrapper (L8):** diputuskan berbasis bukti — **gradlew +
  wrapper jar TIDAK ditambahkan ke repo**. Source Flutter 3.47.8
  (`gradle_utils.dart`) membuktikan `flutter build` meng-inject
  wrapper dari cache Flutter (`injectGradleWrapperIfNeeded`) bila
  file belum ada, dan `gradle-wrapper.properties` repo sudah ada
  sehingga Gradle 9.3.1 dari repo dihormati. File yang dikelola tool
  akan basi bila di-commit. Yang DITAMBAHKAN sebagai perbaikan
  integritas nyata: `distributionSha256Sum` di
  `gradle-wrapper.properties` (SHA-256 Gradle 9.3.1-all.zip
  `17f277867f6914d61b1aa02efab1ba7bb439ad652ca485cd8ca6842fccec6e43`,
  dari services.gradle.org) — Gradle memverifikasi checksum distribusi
  bila properti ini ada. CI adalah build dari clone bersih
  (actions/checkout di runner segar).

## 5. Keputusan keamanan lain (Red 1)

- **Network Security Config (R1-L3):** ditambahkan
  `android/app/src/main/res/xml/network_security_config.xml`
  (`base-config cleartextTrafficPermitted="false"` + trust anchors
  system only; `debug-overrides` trust user CA hanya untuk build
  debug) + atribut `android:networkSecurityConfig` di manifest.
  Deklarasi eksplisit dari default platform — tidak ada perubahan
  perilaku (cleartext sudah false di manifest, user CA sudah tidak
  dipercaya secara default API 24+). **Caveat:** NSC TIDAK berlaku
  untuk lalu lintas Dio (Dart `HttpClient` memakai BoringSSL sendiri)
  — NSC melindungi jalur platform (ExoPlayer). Diverifikasi juga
  bahwa player TIDAK memakai fitur just_audio yang butuh proxy HTTP
  localhost (`player_engine.dart` memakai `AudioSource.uri` tanpa
  header), jadi NSC tidak merusak pemutaran.
- **MediaBrowserService audio_service (R1-L4): DITERIMA DENGAN
  ALASAN.** `onGetRoot` audio_service 0.18.19 mengembalikan root
  untuk SEMUA pemanggil tanpa cek `clientPackageName`/`clientUid`
  (kode allowlist dikomentari di paket — tidak ada respons sinkron
  dari lapisan Dart); tidak ada hook sinkron dari kode app, jadi
  perilaku paket ini tidak bisa diubah dari app. Dampak terbatas:
  root yang diekspos hanya berisi antrean/media item app sendiri,
  bukan file atau kredensial.
  SISA KERJA (di luar file Blue 1, laporkan ke koordinator): validasi
  input di `lib/player/audio_handler.dart` (~baris 181–270:
  `playMediaItem`, `addQueueItem(s)`, `insertQueueItem`,
  `updateQueue` menerima `mediaItem.id` apa adanya sebagai videoId;
  `setSpeed` ~baris 260 meneruskan nilai apa adanya). Yang
  dibutuhkan: validasi format videoId 11 karakter `[A-Za-z0-9_-]`,
  clamp speed 0.5–2.0, seek ≥ 0.
- **Integritas config remote (R1-L1):** yang sudah dipasang — bounds
  di `tryParse` (maks 10 client, string client maks 200 karakter,
  maks 100 hash player, kanari dipotong ke 50), cap streaming 4 MB,
  dan penutupan jalur TypeError `_fetchOne`. Verifikasi hash sidecar
  TIDAK diimplementasikan: security theater (penyerang yang
  mengompromikan rilis bisa memalsukan sidecar dari trust domain
  yang sama); hash yang dipin di kode akan membunuh tujuan config
  remote. **Tindak lanjut yang benar: tanda tangan Ed25519**
  (kunci publik dipin di kode, penandatanganan offline oleh owner)
  — butuh dependensi pub baru (mis. paket `cryptography`), workflow
  penandatanganan, dan keputusan manajemen kunci owner. Belum
  dikerjakan (terblokir egress + butuh keputusan owner).
- **Kunci InnerTube (K-F2-10):** kunci di `client_definitions.dart`
  adalah kunci PUBLIK YouTube (InnerTube web-client), bukan
  kredensial owner — tidak bisa dicabut dan tidak perlu dirotasi.
  Alert "Google API Key bocor" adalah salah nilai.

## 6. Sisa untuk Red 2

- Verifikasi hash KONTEN base.js (SHA-256 per versi) sebagai
  hardening lanjutan gerbang hash R1-M2 (saat ini gerbang memeriksa
  hash dari URL jsUrl, bukan hash konten yang diunduh).
- Uji QuickJS (gg_quickjs) dengan JS berbahaya di perangkat nyata
  (fuzz ringan: loop tak berujung, alokasi raksasa, stack dalam).
- Audit merged manifest Android (izin yang ditambahkan diam-diam
  oleh plugin, §5.1 butir 6) — belum dilakukan ronde ini.
- Tanda tangan Ed25519 untuk config remote (lihat §5, R1-L1).
- Cabang `hasError` di FutureBuilder browse (`browse_detail_screen.dart`)
  — celah laten untuk error non-ExtractorException.

## 7. P8: nol dependensi baru (17 Nov 2026)

Kebutuhan P8: berbagi satu file JSON lewat lembar berbagi Android +
memilih satu file lewat pemilih dokumen sistem. Kandidat pub yang
biasa dipakai — `share_plus` dan `file_picker` — DITOLAK dan TIDAK
masuk `pubspec.yaml`:

- `share_plus` 12.0.2 ada di pub cache lokal, tapi
  `share_plus_android` (platform interface yang dibutuhkannya) TIDAK
  ada; `file_picker` tidak ada sama sekali di cache. Egress VM
  flapping per-menit membuat `pub get` untuk mengunduhnya tidak bisa
  diandalkan pada saat itu.
- Kebutuhan P8 hanya dua aksi native sederhana (chooser ACTION_SEND +
  SAF ACTION_OPEN_DOCUMENT), dan pola MethodChannel ke MainActivity
  sudah mapan di proyek ini (P5 storage, P6 connectivity/external,
  P7 equalizer/deep-link) — preseden P6 memakai MethodChannel
  daripada `url_launcher`/`connectivity_plus` untuk alasan yang sama.
- Dampak F-Droid: nol dependensi baru berarti nol permukaan
  supply-chain baru dan nol izin baru (FileProvider + SAF tidak butuh
  izin penyimpanan).

Yang dibangun sebagai ganti: MethodChannel
`id.my.adipmusic.laras/backup_files` (`lib/features/backup/backup_file_channel.dart`
+ `MainActivity.kt` + FileProvider `res/xml/file_paths.xml`, hanya
`cache-path`). Batas baca native 10.000.001 byte (1 byte di atas
batas impor Dart 10 MB) supaya file raksasa ditolak sebelum dimuat
utuh ke memori. Pembatalan berbagi tidak terdeteksi (keterbatasan
ACTION_SEND) dan didokumentasikan di kode + UI memperlakukan
"sukses" sebagai "lembar berbagi berhasil dibuka".

**Catatan untuk tim berikutnya:** bila suatu saat `share_plus` /
`file_picker` tetap ingin dipakai (mis. butuh berbagi ke iOS atau
pemilih multi-file), tinjau dulu sesuai §5.1 (pub points, lisensi,
riwayat pemeliharaan) — jangan tambahkan diam-diam.
