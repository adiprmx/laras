/// Lapisan player Laras: pemutaran audio lewat interface milik app.
///
/// Isi paket P2: `AudioPlayerPort` (interface player milik app),
/// implementasi just_audio + audio_service + audio_session di balik interface
/// itu, MediaSession, notifikasi media, kontrol headset dan Bluetooth,
/// antrean 200 item, shuffle, repeat, kecepatan, pitch, skip silence.
///
/// Aturan yang mengikat: semua akses audio lewat `AudioPlayerPort`. Widget
/// tidak pernah memanggil just_audio langsung. URL stream hanya ada di memori,
/// tidak pernah disimpan di database, file, atau log.
library;
