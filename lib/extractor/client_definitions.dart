/// Definisi client InnerTube dan daftar lagu kanari.
///
/// Versi client di sini adalah nilai BAWAAAN (fallback bila config remote
/// belum pernah berhasil diunduh). Nilai yang dipakai saat berjalan berasal
/// dari config remote ([RemotePlayerConfig]); tabel ini hanya cadangan.
///
/// Semua versi di bawah diverifikasi dari sumber live pada 15 November
/// 2026 (lihat `docs/spike-ekstraksi.md` untuk bukti per versi). Versi
/// tebakan dan versi pin extractor lama GAGAL di probe (LOGIN_REQUIRED),
/// jadi jangan mengubah angka ini tanpa bukti probe baru.
///
/// Urutan fallback (dari bukti probe ronde 2, 5/5 lagu):
/// 1. WEB_REMIX - satu-satunya client web yang memberi format audio
///    konvensional (cipher) dengan versi live dari HTML.
/// 2. MWEB - cadangan, juga memberi format audio konvensional (cipher).
/// 3. ANDROID_VR - cadangan kedua (P0, 16 Nov 2026): memberi URL audio
///    LANGSUNG (tanpa cipher, tanpa perlu solver) untuk itag 139/140/
///    249/251; terbukti 206 + byte audio nyata dari VM. P1 sempat
///    mengecualikannya karena LOGIN_REQUIRED, tapi probe ulang P0 dengan
///    sts + visitorData segar lolos. Dipakai hanya bila kedua client web
///    gagal.
///
/// Client yang TIDAK masuk fallback dan alasannya (terbukti di probe):
/// - ANDROID_MUSIC / IOS_MUSIC: LOGIN_REQUIRED ("Please sign in") untuk
///   semua versi yang dicoba (7.27.52, 8.05.53, 7.27.0), dengan atau tanpa
///   visitorData, SDK 30 maupun 34.
/// - ANDROID / IOS: playability OK tapi SEMUA format audio hanya SABR
///   (tanpa `url` dan tanpa `signatureCipher`); v1 menolak SABR.
/// - WEB: LOGIN_REQUIRED ("Sign in to confirm you're not a bot").
/// - WEB_EMBEDDED_PLAYER: ERROR ("This video is unavailable").
/// - TVHTML5_SIMPLY_EMBEDDED_PLAYER: ERROR ("no longer supported").
library;

/// Satu client InnerTube: nama, versi, konteks JSON, user agent, dan ID
/// header `X-YouTube-Client-Name`.
class ClientDefinition {
  const ClientDefinition({
    required this.name,
    required this.version,
    required this.context,
    required this.userAgent,
    required this.clientId,
    this.requiresScript = true,
  });

  /// Nama client di `context.client.clientName`, mis. `WEB_REMIX`.
  final String name;

  /// Versi client, mis. `1.20261110.04.00`.
  final String version;

  /// Isi `context.client` untuk request player/search (tanpa visitorData;
  /// visitorData ditambahkan saat request bila tersedia).
  final Map<String, dynamic> context;

  /// Header `User-Agent` untuk client ini.
  final String userAgent;

  /// Nilai header `X-YouTube-Client-Name`.
  final String clientId;

  /// Benar bila client ini butuh script player (sts untuk request player
  /// dan/atau solver untuk format cipher). Client yang memberi URL
  /// langsung tanpa sts (saat ini hanya ANDROID_VR, terbukti probe P0f)
  /// memakai false: orkestrator tetap mencobanya saat script gagal
  /// dimuat (mode terdegradasi).
  final bool requiresScript;

  Map<String, dynamic> contextWithVisitorData(String? visitorData) {
    if (visitorData == null || visitorData.isEmpty) return context;
    return <String, dynamic>{...context, 'visitorData': visitorData};
  }

  @override
  String toString() => 'ClientDefinition($name $version)';
}

/// Kunci API InnerTube publik. Kunci ini tertanam di halaman youtube.com
/// dan dipakai semua client web YouTube; bukan secret (sama dengan kunci
/// yang dipakai yt-dlp dan pytubefix). Tidak ada kunci lain yang dipakai.
const String kInnertubeApiKey =
    'AIzaSyAO_FJ2SlqU8Q4STEHLGCilw_Y9_11qcW8';

/// Host untuk semua panggilan youtubei.
///
/// POST ke `music.youtube.com` STALL TOTAL dari VM (0 byte dalam 120 detik,
/// 2x, temuan koordinator). Semua client memakai `www.youtube.com`, termasuk
/// WEB_REMIX - terbukti bekerja di probe.
const String kInnertubeHost = 'www.youtube.com';

/// Definisi WEB_REMIX (client utama).
///
/// Versi dari HTML `music.youtube.com` 15 Nov 2026
/// (`INNERTUBE_CLIENT_VERSION`). Versi pin yt-dlp/pytubefix
/// (1.20260707.12.00) sudah terlalu tua dan kena LOGIN_REQUIRED.
const ClientDefinition kWebRemixClient = ClientDefinition(
  name: 'WEB_REMIX',
  version: '1.20261110.04.00',
  context: <String, dynamic>{
    'clientName': 'WEB_REMIX',
    'clientVersion': '1.20261110.04.00',
  },
  userAgent:
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
      '(KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36',
  clientId: '67',
);

/// Definisi MWEB (client cadangan).
///
/// Versi dari yt-dlp master 15 Nov 2026 (2.20260708.05.00).
const ClientDefinition kMwebClient = ClientDefinition(
  name: 'MWEB',
  version: '2.20260708.05.00',
  context: <String, dynamic>{
    'clientName': 'MWEB',
    'clientVersion': '2.20260708.05.00',
  },
  userAgent:
      'Mozilla/5.0 (Linux; Android 11; Pixel 5) AppleWebKit/537.36 '
      '(KHTML, like Gecko) Chrome/131.0.0.0 Mobile Safari/537.36',
  clientId: '2',
);

/// Definisi ANDROID_VR (cadangan kedua, P0 16 Nov 2026).
///
/// Versi 1.65.10. Context menyertakan `androidSdkVersion: 34` seperti di
/// probe yang lolos. Probe P0f 16 Nov 2026 membuktikan VR juga lolos
/// TANPA androidSdkVersion (bentuk context config remote) dan TANPA
/// signatureTimestamp - jadi VR tetap bisa dicoba saat script player
/// gagal dimuat (mode terdegradasi orkestrator).
/// Memberi URL audio langsung (tanpa cipher) - satu-satunya client yang
/// tidak butuh solver signature.
const ClientDefinition kAndroidVrClient = ClientDefinition(
  name: 'ANDROID_VR',
  version: '1.65.10',
  context: <String, dynamic>{
    'clientName': 'ANDROID_VR',
    'clientVersion': '1.65.10',
    'androidSdkVersion': 34,
  },
  userAgent:
      'com.google.android.youtube/21.26.364 (Linux; U; Android 14; '
      'Pixel 8) gzip',
  clientId: '14',
  requiresScript: false,
);

/// Urutan fallback bawaan: WEB_REMIX dulu, MWEB cadangan, ANDROID_VR
/// cadangan kedua (URL langsung, tanpa solver).
const List<ClientDefinition> kDefaultClientFallbackOrder =
    <ClientDefinition>[kWebRemixClient, kMwebClient, kAndroidVrClient];

/// Satu lagu kanari: videoId terverifikasi + judul yang tampil di demo.
///
/// Judul dan durasi berasal dari respons player probe ronde 2 (15 Nov 2026),
/// bukan hafalan. Kelima lagu ini mengembalikan format audio itag 251 + 140
/// lewat WEB_REMIX dan MWEB.
class CanarySong {
  const CanarySong({
    required this.videoId,
    required this.title,
    required this.lengthSeconds,
  });

  final String videoId;
  final String title;
  final int lengthSeconds;
}

/// Lima lagu kanari (dipakai deteksi kanari dan layar demo spike).
const List<CanarySong> kCanarySongs = <CanarySong>[
  CanarySong(
    videoId: 'hhn-nGSuenM',
    title: 'Semua Tentang Kita',
    lengthSeconds: 268,
  ),
  CanarySong(
    videoId: 'qkC4waEZVt4',
    title: 'Rahasia Hati',
    lengthSeconds: 251,
  ),
  CanarySong(
    videoId: 'k2XdBPv0D3Y',
    title: 'Surat Cinta Untuk Starla',
    lengthSeconds: 308,
  ),
  CanarySong(
    videoId: 'NL8WUtq_NDY',
    title: 'Ya Sudahlah',
    lengthSeconds: 254,
  ),
  CanarySong(
    videoId: 'YsGwU8vTRsE',
    title: 'Tak Ingin Usai',
    lengthSeconds: 278,
  ),
];
