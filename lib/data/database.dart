/// Lapisan data Laras: database lokal drift di atas SQLite.
///
/// Isi paket P3: 15 tabel skema v1 (lagu, album, artis, playlist, favorit,
/// riwayat putar, riwayat pencarian, antrean, lirik, manifest cache,
/// antrean unduhan), migrasi teruji lewat `drift_dev schema steps`, FTS5
/// untuk pencarian lokal, dan background isolate.
///
/// Aturan yang mengikat: semua koleksi tinggal di SQLite, tidak pernah di
/// key-value store. shared_preferences hanya untuk 11 kunci pengaturan kecil.
/// Tidak ada akses drift langsung dari widget; widget berbicara ke service.
library;
