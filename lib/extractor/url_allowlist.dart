/// Validasi URL dari jaringan sebelum dipakai (R1-M1 + R1-L2).
///
/// Satu-satunya helper validasi URL di lapisan ekstraksi: semua jalur yang
/// menerima URL dari respons InnerTube atau dari solver WAJIB lewat sini
/// sebelum URL itu dipakai (diputar ExoPlayer atau di-fetch sebagai gambar).
/// Aturan rencana keamanan §3.3 + checklist #10: skema harus HTTPS dan host
/// harus masuk daftar yang diharapkan.
///
/// Daftar host (dibuktikan dari respons nyata, bukan tebakan):
/// - Stream audio: `*.googlevideo.com` — semua URL audio dari InnerTube
///   (langsung maupun hasil solver) memakai host ini (terbukti di fixture
///   `player-web-remix-ok.json` + probe P0/P1). Host lain (termasuk
///   youtube.com dan host config GitHub) TIDAK diizinkan sebagai URL
///   stream: pemutar tidak pernah butuh memutar dari sana, dan URL config
///   adalah konstanta di kode (`kRemoteConfigUrl`), bukan data dari
///   jaringan, sehingga tidak butuh keanggotaan allowlist.
/// - Thumbnail: `*.ytimg.com`, `*.googleusercontent.com`, `*.ggpht.com` —
///   ketiga host ini yang muncul di fixture respons search/browse
///   (`i.ytimg.com`, `lh3.googleusercontent.com`, `yt3.ggpht.com`,
///   `yt3.googleusercontent.com`).
///
/// Yang ditolak selain skema/host yang salah: URL dengan userinfo
/// (`https://user@host/...`) — userinfo di URL stream/thumbnail tidak pernah
/// sah dan pola `https://googlevideo.com@evil.com/` menipu pembaca.
library;

/// Benar bila [rawUrl] adalah URL stream audio yang boleh diputar:
/// skema HTTPS, tanpa userinfo, host `googlevideo.com` atau subdomainnya.
bool isAllowedStreamUrl(String rawUrl) =>
    _isAllowedHost(rawUrl, const <String>{'googlevideo.com'});

/// Benar bila [rawUrl] adalah URL thumbnail yang boleh di-fetch:
/// skema HTTPS, tanpa userinfo, host di daftar thumbnail YouTube/Google.
bool isAllowedThumbnailUrl(String rawUrl) => _isAllowedHost(rawUrl, const <String>{
  'ytimg.com',
  'googleusercontent.com',
  'ggpht.com',
});

bool _isAllowedHost(String rawUrl, Set<String> allowedBases) {
  final Uri? uri = Uri.tryParse(rawUrl);
  if (uri == null) return false;
  if (uri.scheme != 'https') return false;
  if (!uri.hasAuthority) return false;
  if (uri.userInfo.isNotEmpty) return false;
  final String host = uri.host.toLowerCase();
  if (host.isEmpty) return false;
  for (final String base in allowedBases) {
    // Persis `googlevideo.com.evil.com` dan `evilgooglevideo.com` harus
    // ditolak: yang lolos hanya host yang sama persis atau subdomain
    // (dipisah titik) dari basis yang diizinkan.
    if (host == base || host.endsWith('.$base')) return true;
  }
  return false;
}
