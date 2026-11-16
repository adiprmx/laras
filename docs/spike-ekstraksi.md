# Laporan Spike Ekstraksi (P1) - Laras

Tanggal: 15–16 November 2026. Penulis: Tim P1 Spike Ekstraksi.
Status dokumen: final untuk gate GO/NO-GO. Semua angka di sini nyata
(dari probe, tes, atau log CI) - tidak ada angka karangan.

## Ringkasan putusan

| Spike | Hasil | Bukti ringkas |
|---|---|---|
| 1. Player request mengembalikan audio | **PASS** | WEB_REMIX live 5/5 lagu kanari OK, itag 251 + 140 (cipher); MWEB 5/5 OK |
| 2. Solver QuickJS + URL bisa diputar penuh | **PARTIAL** | Sig + n tervalidasi oracle (pytubefix identik); byte audio asli terbukti; TAPI unduh penuh dari VM mentok 1 MiB lalu 403 - penyebab (reputasi IP vs poToken) hanya bisa diputuskan uji perangkat owner |
| 3. Fallback antar client | **PASS** | Tes: WEB_REMIX dimatikan paksa -> MWEB otomatis, lagu tetap jalan; log fallback tercatat |
| 4. Config remote | **PASS (dengan catatan)** | Pre-release `config-v1` dibuat; loader mengambil config nyata dari tag (terbukti live test); aset rilis belum terunggah (blokir auth API) - config dilayani dari tree tag sebagai cadangan |
| 5. Penolakan SABR | **PASS** | Parser menandai format SABR-only (fixture ANDROID asli); pemilih itag tidak pernah memilih SABR |
| 6. Ukuran APK + waktu resolve | **PARTIAL** | Waktu resolve median 4.049 ms dari VM (target <2.000 ms tidak tercapai dari VM; bottleneck jaringan egress, bukan solver); ukuran APK menunggu CI pasca-push |

**Putusan: GO BERSYARAT.** Ekstraksi terbukti bekerja ujung-ke-ujung
dari sisi protokol (player + solver + fallback + config). Dua hal yang
belum bisa diputuskan dari VM dan wajib diuji di perangkat owner lewat
APK demo: (1) apakah batas 1 MiB googlevideo juga berlaku di IP
residensial HP (bila ya, pemutaran lagu penuh butuh re-resolve di tengah
pemutaran - pekerjaan P2); (2) bunyi QuickJS di perangkat nyata +
waktu resolve di jaringan HP.

## Spike 1 - Player request

### Versi client (sumber + tanggal cek)

| Client | Versi | Sumber | Tanggal |
|---|---|---|---|
| WEB_REMIX | 1.20261110.04.00 | HTML music.youtube.com (`INNERTUBE_CLIENT_VERSION`) | 15 Nov 2026, diverifikasi ulang 16 Nov 2026 (tidak berubah) |
| WEB | 2.20261112.10.00 | HTML youtube.com | 15 Nov 2026 |
| MWEB | 2.20260708.05.00 | yt-dlp master `_base.py` | 15 Nov 2026 |
| ANDROID_MUSIC | 7.27.52 | pytubefix main `innertube.py` | 15 Nov 2026 |
| ANDROID | 21.26.364 | yt-dlp master + pytubefix main | 15 Nov 2026 |
| IOS | 21.26.4 | yt-dlp master + pytubefix main | 15 Nov 2026 |
| ANDROID_VR | 1.65.10 | yt-dlp master (komentar: semua format 403 sejak 2026.08.17) | 15 Nov 2026 |
| TVHTML5_SIMPLY | 2.0 | yt-dlp master | 15 Nov 2026 |

base.js: hash `fad7e4e9`, 2.677.001 byte, sha256
`dbfabdafd8587a526fca22fcdff2c508aff368c10d3af483e7a8b31218b3b450`,
signatureTimestamp (sts) 20767. Hash dan versi TIDAK berubah antara
15 Nov dan 16 Nov 2026.

### Hasil probe (5 videoId terverifikasi lewat search)

Lagu kanari (judul + durasi dari respons player, bukan hafalan):

| videoId | Judul | Durasi |
|---|---|---|
| hhn-nGSuenM | Semua Tentang Kita | 268 dtk |
| qkC4waEZVt4 | Rahasia Hati | 251 dtk |
| k2XdBPv0D3Y | Surat Cinta Untuk Starla | 308 dtk |
| NL8WUtq_NDY | Ya Sudahlah | 254 dtk |
| YsGwU8vTRsE | Tak Ingin Usai | 278 dtk |

Ronde 2 (8 client x 5 video, 15 Nov 2026):

| Client | Hasil |
|---|---|
| WEB_REMIX live | OK 5/5, audio 140/249/250/251 semua cipher |
| MWEB | OK 5/5, audio cipher (140/249/250/251 + 599/600) |
| ANDROID 21.26.364 | OK playability 5/5, TAPI SABR-only |
| IOS 21.26.4 | OK playability 5/5, TAPI SABR-only |
| IOS_MUSIC 7.27.0 | LOGIN_REQUIRED 5/5 |
| ANDROID_MUSIC 7.27.52 (+ visitorData / SDK 34) | LOGIN_REQUIRED 5/5 |
| WEB_EMBEDDED_PLAYER live | ERROR 5/5 "This video is unavailable" |

Ronde 1 (satu video): WEB_REMIX dengan versi PIN yt-dlp
(1.20260707.12.00) kena LOGIN_REQUIRED - hanya versi LIVE dari HTML
yang bekerja. Ini memvalidasi desain config remote: versi client tidak
boleh di-pin lama.

### Urutan fallback (dari bukti)

WEB_REMIX -> MWEB saja. ANDROID/IOS dikecualikan (SABR-only);
ANDROID_MUSIC/IOS_MUSIC dikecualikan (LOGIN_REQUIRED); WEB,
WEB_EMBEDDED_PLAYER, ANDROID_VR, TVHTML5_SIMPLY dikecualikan
(LOGIN_REQUIRED/ERROR).

### signatureTimestamp WAJIB (temuan 16 Nov 2026)

Request player TANPA `signatureTimestamp` dibalas UNPLAYABLE
("The page needs to be reloaded.") - terbukti 4 kombinasi
(`diag-sts-vd.js`, 16 Nov 2026):

| Kombinasi | Hasil |
|---|---|
| sts + visitorData | OK, 4 format audio |
| tanpa sts + visitorData | UNPLAYABLE |
| sts + tanpa visitorData | OK, 4 format audio |
| tanpa sts + tanpa visitorData | UNPLAYABLE |

Karena itu `StreamResolver` memuat script player DULU (untuk sts)
sebelum request player pertama. Desain awal ("tanpa sts dulu, ulangi
bila LOGIN_REQUIRED") SALAH - tanpa sts, server membalas UNPLAYABLE,
bukan LOGIN_REQUIRED, sehingga retry tidak pernah terpicu.

### visitorData

Saat reputasi IP rendah, request player tanpa visitorData dibalas
LOGIN_REQUIRED untuk SEMUA client; dengan visitorData segar dari
endpoint search, WEB_REMIX lolos. App mengambil visitorData lewat
search (cache 6 jam); bila player LOGIN_REQUIRED, refresh sekali lalu
ulangi sekali.

## Spike 2 - Solver signature + n-transform

### (a) Bukti Node.js

Rantai signature di base.js fad7e4e9 (ditemukan + dibuktikan):
`vf(2,6827,Ne(56,7789,uf(9,8472,s)))` - `uf` = decodeURIComponent,
`Ne` = cabang 4 (splice 2, swap 69, splice 1, swap 9, splice 1,
swap 46), `vf` = encodeURIComponent, helper `jB` (splice/swap/reverse).
Nama fungsi + parameter numerik DIEKSTRAK dari base.js saat berjalan
(regex call-site + pencocokan kurung), bukan di-hardcode.

Transform n: lewat kelas URL player utuh (`_yt_player.tf`):
`new tf(cipherUrl, true)` -> `set('sig', ...)` -> `gf()` menjalankan
transform n saat serialisasi.

Validasi oracle pytubefix 11.2.1 (15 Nov 2026): signature IDENTIK
dengan solver (modulo encoding `%3D` vs `=`), n IDENTIK
(`AN4ZrqC9mKvCumNnl` -> `4kdLuLGx-Us4iQ`), pytubefix juga
mengidentifikasi sig fn = `Ne`, nsig fn = `hz`. **Solver sig+n
TERBUKTI BENAR.**

Bukti byte audio: URL final (sig decipher + n transform), Range
0-999 -> HTTP 206, `audio/webm`, head hex `1a45dfa3` (magic EBML/WebM),
content-length benar. Tanpa header Range: HTTP 403.

### Batas 1 MiB (temuan kritis)

Unduh penuh 4,8 MB TIDAK tercapai dari VM: googlevideo membatasi
tepat 1 MiB per URL lalu 403 (terbukti di URL segar WEB_REMIX dan
MWEB; URL segar yang LANGSUNG diminta 1 MiB @offset 1 MiB sebagai
request pertama juga 403). Batasnya BUKAN anggaran per-URL dan BUKAN
single-use n. Polanya cocok dengan token bucket per-IP (IP egress
datacenter bersama yang reputasinya buruk) ATAU penegakan poToken.
yt-dlp menandai format HTTPS web_music dan MWEB sebagai
`GVS_PO_TOKEN_POLICY required=True` ("may yield HTTP 403" tanpa
poToken). Tugas MELARANG minting poToken/BotGuard.

**Hanya uji perangkat owner yang bisa memutuskan:** bila batas 1 MiB
adalah penegakan poToken, batas itu juga berlaku di HP; bila soal
reputasi IP, HP (IP residensial) mungkin bebas. Implikasi produk dari
VM: 1 MiB ~ 55 detik audio itag 251 dari lagu 268 detik, lalu 403 -
KECUALI app re-resolve di tengah pemutaran (pekerjaan P2+; re-resolve
tidak membantu dari VM karena anggaran bukan per-URL).

### (b) Integrasi Flutter (quickjs_engine 0.1.7)

API diverifikasi dari pub cache (15 Nov 2026):

- `QuickJsRuntime2({stackSize, timeout, memoryLimit, ...})` - stack
  dan memori ditegakkan native (nyata di C++).
- **Parameter `timeout` TIDAK BERFUNGSI**: sisi Dart meneruskannya ke
  `jsNewRuntime`, tapi implementasi C hanya menerima channel dan tidak
  memasang interrupt handler sama sekali (tidak ada
  `JS_SetInterruptHandler`). Karena itu timeout 10 detik ditegakkan di
  Dart: runtime hidup di isolate pekerja; bila satu solve melewati
  10 detik, isolate dimatikan paksa lalu dibuat ulang.
- Batas SimpMusic dipakai: memori 192 MiB, stack 8 MiB, timeout
  10 detik, eksekusi serial, tanpa callback host, tanpa fetch.
- QuickJS TIDAK BISA dites di `flutter test` host Linux (paket tidak
  membawa lib native Linux; Android membangun dari source `native/`
  via CMake). Wiring QuickJS diverifikasi lewat build CI + APK demo
  di perangkat owner. Logika murni (ekstraksi, prelude, driver) dites
  tanpa QuickJS.

## Spike 3 - Fallback antar client

Bukti tes (`fallback_orchestrator_test.dart`, fake client):

- Client utama OK -> selesai tanpa fallback (1 panggilan player).
- Client utama LOGIN_REQUIRED -> pindah ke MWEB otomatis
  (WEB_REMIX dicoba 2x: awal + sesudah refresh visitorData, lalu
  MWEB); lagu tetap jalan.
- Client utama SABR-only -> pindah ke MWEB otomatis.
- Format cipher -> solver dipanggil sekali.
- Semua client gagal -> lempar penyebab non-jaringan terakhir
  (bukan penyebab jaringan).
- Single-flight: dua resolve bersamaan -> satu panggilan player.
- Log resolve (tanpa URL) tercatat per client: hasil + durasi ms.

## Spike 4 - Config remote

Pre-release dibuat 16 Nov 2026:

- Tag: `config-v1` (bukan tag `v*`, tidak memicu workflow rilis).
- Rilis: https://github.com/adiprmx/laras/releases/tag/config-v1
  (pre-release, "Player config v1 (bukan rilis aplikasi)").
- Isi config: 2 client (WEB_REMIX 1.20261110.04.00, MWEB
  2.20260708.05.00) + `playerHashes` (fad7e4e9 -> sts 20767) +
  5 videoId kanari + TTL 21600 detik (6 jam).
- Commit config: `5b2da5746cbebaae9543ac4004158a088f4edef2`
  (parent = main HEAD `b78c1d2e...`; TIDAK ada di branch mana pun,
  hanya dijangkau lewat tag - tidak mengganggu main maupun alur push
  koordinator).

**Catatan upload aset:** upload aset rilis ke `uploads.github.com`
DITOLAK 401 3/3 - surrogate kredensial GitHub hanya berlaku untuk
`api.github.com` (CONNECTOR.md: "Restrict authenticated requests to:
api.github.com"). Aset `player-config.json` BELUM ada di rilis.
Koordinator bisa mengunggahnya lewat browser (GitHub web UI, 1 menit)
dari file `hidden_files/tim-p1-spike/player-config.json`.

**Cadangan yang sudah live:** file config yang sama ada di tree tag
`config-v1`, dilayani di
`https://raw.githubusercontent.com/adiprmx/laras/config-v1/player-config.json`
(terverifikasi 200, isi sama persis). Loader mencoba URL rilis dulu,
lalu URL raw ini. Live test "fetch config remote nyata" LOLOS -
membuktikan loader mengambil config nyata dari tag dan memakai
nilainya tanpa install ulang.

Perilaku loader (dites): TTL 6 jam, timeout 5 detik, maks 4 MB,
single-flight, rate limit 5 menit, stale-while-revalidate, fallback
cache terakhir yang valid lalu nilai bawaan.

## Spike 5 - Penolakan SABR

- Fixture respons ASLI client ANDROID (SABR-only) direkam di
  `test/fixtures/player-android-sabr-only.json`: 6 format audio
  (139/140/249/251/599/600) TANPA `url`, TANPA `signatureCipher`,
  TANPA `serverAbrStreamingUrl` per format - satu-satunya jalur
  putar adalah URL SABR tingkat atas.
- Parser menandai format seperti itu sebagai SABR (aturan: format
  punya URL SABR sendiri, ATAU tidak punya URL langsung maupun cipher
  sementara respons membawa URL SABR tingkat atas). URL SABR tingkat
  atas SAJA bukan penanda SABR-only - respons WEB_REMIX membawa URL
  tingkat atas SEKALIGUS format konvensional.
- Pemilih itag tidak pernah memilih format SABR (tes: semua SABR ->
  null; campuran -> pilih yang konvensional).
- `serverAbrStreamingUrl` tidak pernah dipakai sebagai URL putar di
  kode mana pun (tidak ada referensi pemakaian selain deteksi).

## Spike 6 - Ukuran APK + waktu resolve

### Waktu resolve (10 resolve nyata, Node di VM, 16 Nov 2026)

`measure-resolve.js`: 5 lagu kanari x 2 putaran, steady-state
(visitorData + script sudah hangat; warm-up tidak dihitung).
Hasil lengkap: `hidden_files/tim-p1-spike/measure-resolve.json`.

| Metrik | Nilai |
|---|---|
| Berhasil | 10/10 |
| Median total | 4.049 ms |
| Median player | 4.028,5 ms |
| Median solve | 10,5 ms |
| Min total | 2.440 ms |
| Max total | 20.482 ms |
| Target desain | <2.000 ms |

Target TIDAK tercapai dari VM. Bottleneck-nya panggilan player HTTP
lewat proxy egress VM (median 4 detik), BUKAN solver (median 10,5 ms
- komputasi QuickJS/Node tidak signifikan). Putaran ke-2 jauh lebih
cepat dari putaran ke-1 (median 2.807 ms vs 7.939 ms) - koneksi hangat
membantu. Angka perangkat owner di jaringan HP langsung hampir pasti
lebih baik, tapi WAJIB diukur di sana (APK demo mencatat waktu resolve
per lagu).

### Ukuran APK

quickjs_engine 0.1.7 SUDAH ada di `pubspec.yaml` sejak P0, jadi tidak
ada baseline "sebelum" dari CI untuk dihitung selisihnya. Paket tidak
membawa `.so` prebuilt (Android membangun QuickJS-NG 0.14.0 dari
source `native/` via CMake), jadi ukurannya hanya bisa dibaca dari
artifact CI sesudah push P1:

- **Menunggu koordinator push + CI:** baca ukuran APK rilis per ABI
  dari log CI ("Check release APK size") dan kontribusi QuickJS dari
  langkah "APK contents breakdown" (entri `libquickjs` di dalam APK).
- Baseline konteks (P0, debug APK, run CI 43728749979): arm64-v8a
  90,3 MB, armeabi-v7a 68,7 MB, x86_64 76,4 MB (debug jauh lebih besar
  by design; batas K4 25 MB hanya untuk APK rilis).

## Verifikasi

- `flutter analyze`: No issues found!
- `flutter test --exclude-tags live`: 64 tes, semua lolos.
- `flutter test --tags live`: 3/3 lolos dalam sekali jalan
  (16 Nov 2026, 75 detik: player WEB_REMIX nyata 40 dtk, load script
  player nyata 21 dtk, fetch config remote nyata 14 dtk).
  Catatan kejujuran: live test sempat gagal 3x karena jaringan VM
  (connectionTimeout di jendela egress lambat, run 2/6/7) dan 2x
  karena bug tes/aplikasi yang sudah diperbaiki (HttpClient palsu
  binding, lalu ketiadaan sts). Setiap kegagalan jaringan diulang
  sampai lolos; bukti Node independen (10/10 resolve, 4/4 kombinasi
  sts/visitorData) menguatkan bahwa kegagalan itu berasal dari VM,
  bukan dari endpoint YouTube.
- Scan secrets atas semua file baru/ubah: bersih (satu-satunya temuan
  pola adalah string 'secret' di dalam assertion tes; kunci API
  Innertube adalah kunci publik yang tertanam di halaman youtube.com
  dan dipakai yt-dlp/pytubefix, bukan secret).

## Bug yang ditemukan tes (diperbaiki dalam P1)

1. **Parser SABR salah:** format SABR-only ANDROID tidak terdeteksi
   (tidak punya `serverAbrStreamingUrl` per format). Aturan deteksi
   diperbaiki (lihat Spike 5).
2. **`whenComplete` tanpa penangan error** di `StreamResolver` dan
   `PlayerScriptLoader`: Future turunan membawa error job tanpa
   pendengar -> unhandled async error. Diganti `then<void>` +
   `onError` dengan badan blok.
3. **Arrow function `Map.remove` di `onError`:** `remove` mengembalikan
   `job` (Future yang error); nilai itu diadopsi Future turunan dan
   ikut error tanpa pendengar. Callback WAJIB badan blok.
4. **`catchError((_) {})` di Future bertipe:** penangan wajib
   mengembalikan nilai bertipe future; di Future<ResolvedAudio> ini
   melempar ArgumentError saat runtime. Tidak dipakai.
5. **Live test + TestWidgetsFlutterBinding:** binding memasang
   HttpClient palsu (semua request 400). Tes live menggantinya dengan
   HttpOverrides asli.

## Yang butuh uji perangkat owner (APK demo 5 lagu)

1. Putar 5 lagu kanari sampai habis: apakah lagu penuh bisa diputar
   (batas 1 MiB) atau berhenti di ~55 detik?
2. Waktu resolve per lagu di jaringan HP (target <2 detik).
3. QuickJS: solver jalan di perangkat (bunyi + tidak crash).
4. Ukuran APK rilis + kontribusi QuickJS (dari CI pasca-push).

## File kerja spike

Skrip probe + bukti mentah:
`~/workspace/music-app/hidden_files/tim-p1-spike/` (probe-player.js,
probe2.js + 40 respons, base-fad7e4e9.js, e2e-proof.js,
measure-resolve.js + measure-resolve.json, diag-sts-vd.js,
make_config_release.py, make_config_commit.py, player-config.json).

## Adendum P0 — 16 Nov 2026 (insiden: demo P3 tidak bisa memutar di HP owner)

### Akar: YouTube mengganti varian base.js

Hash base.js SAMA (`fad7e4e9`) tapi isi berubah: 2.677.001 -> 2.876.993
byte, path `player_es6.vflset` -> **`player_es6_tcl.vflset`**, sts 20767
-> **20767001**. Varian `tcl` memakai obfuscation baru (tabel string
`g.d='...'.split("{")` + indeks XOR + dispatcher `pa`); pola ekstraksi
perilaku app tidak cocok (callSite NULL, table NULL) -> `ExtractorException`
(unknownPlayerHash) SEBELUM request player. Rantai bunuh: resolve gagal ->
`_doLoad` emit status error + lastError -> mini-player/beranda diam total
(pesan error hanya ada di layar pemutar penuh).

### Bukti probe P0 (VM, 16 Nov 2026; skrip di `hidden_files/tim-p0-debug/`)

- Player WEB_REMIX + MWEB `k2XdBPv0D3Y` dengan sts + visitorData: OK
  (format cipher 140/249/250/251). Tanpa sts: UNPLAYABLE. sts lama 20767
  MASIH diterima.
- Path non-tcl lama MASIH dilayani (200, 2.677.001 byte, w-table + rantai
  signature ada, sts 20767) -> fallback varian di `PlayerScriptLoader`.
- **Rantai lama MASIH VALID (probe-p0e):** solve base.js lama -> Range
  0-999 URL final -> HTTP 206 + byte audio nyata (itag 140 audio/mp4
  magic `00000018`; itag 251 audio/webm magic `1a45dfa3`). Satu 403
  itag 251 di probe-p0b terbukti pengukuran sekali yang menyesatkan
  (tanpa ikuti redirect); probe ber-redirect 4/4 berakhir 206.
- **ANDROID_VR 1.65.10 (probe-p0d/p0f):** playability OK, URL LANGSUNG
  139/140/249/251 (tanpa cipher); Range -> 206 + byte audio nyata.
  Lolos TANPA `androidSdkVersion` dan TANPA sts -> client ke-3 fallback
  + mode terdegradasi (dicoba saat script gagal dimuat). P1 sempat
  mengecualikannya (LOGIN_REQUIRED); keadaan berubah dengan sts + vd.
- Waktu request sah dari VM: HTML 41,2 dtk; base.js 52 dtk; player
  16,2/22,2/26,5 dtk -> timeout app dinaikkan (player/search 15->30 dtk,
  HTML 30->60 dtk, base.js 60->90 dtk; connect tetap 10 dtk).

### Perbaikan P0 (hotfix, belum push saat adendum ditulis)

1. Fallback varian non-tcl di `PlayerScriptLoader` (hanya bila ekstraksi
   unknownPlayerHash; infiks `player_es6_tcl` -> `player_es6`).
2. Mode terdegradasi orkestrator: script gagal -> lewati client
   `requiresScript`, coba ANDROID_VR (`requiresScript: false`); bila
   tidak ada client yang dicoba, error script yang dilempar.
3. ANDROID_VR sebagai client fallback ke-3 (definisi + urutan bawaan).
   Config remote (`config-v1/player-config.json`) BELUM memuat VR saat
   adendum ditulis - koordinator perlu menambahkannya (name ANDROID_VR,
   version 1.65.10, clientId 14, requiresScript false, UA Android).
4. Rotasi client antar-resolve (`_rotationStart`, per videoId).
5. Klasifikasi error 3 jenis (network/timeout/unplayable) + pesan
   terpusat + state error di mini-player, banner di beranda (lagu
   pilihan) dan Player layar penuh, errorMessage MediaSession.
6. Jalur lokal dipagari: error engine lagu lokal langsung gagal tanpa
   re-resolve jaringan (`_onEngineError`).

### Masih belum diketahui (jujur)

- Apakah QuickJS solver berjalan di HP owner (hanya uji perangkat).
- Apakah batas 1 MiB googlevideo berlaku di IP residensial HP owner
  (hanya uji perangkat; re-resolve P2 menanganinya bila ya).
- Berapa lama varian non-tcl lama tetap dilayani YouTube (fallback ini
  rapuh; VR adalah jaring pengaman yang tidak bergantung base.js).
