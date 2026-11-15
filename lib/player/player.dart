/// Lapisan player Laras: pemutaran audio lewat interface milik app.
///
/// Isi paket P2: `AudioPlayerPort` (interface player milik app),
/// implementasi just_audio + audio_service + audio_session di balik interface
/// itu, MediaSession, notifikasi media, kontrol headset dan Bluetooth,
/// antrean 200 item, shuffle, repeat, kecepatan, pitch, skip silence,
/// dan re-resolve otomatis saat pemutaran gagal di tengah lagu.
///
/// Aturan yang mengikat: semua akses audio lewat `AudioPlayerPort`. Widget
/// tidak pernah memanggil just_audio langsung. URL stream hanya ada di memori,
/// tidak pernah disimpan di database, file, atau log.
library;

export 'audio_handler.dart';
export 'audio_player_port.dart';
export 'audio_session_port.dart';
export 'just_audio_player.dart';
export 'player_engine.dart';
export 'player_scope.dart';
export 'player_service.dart';
export 'player_state.dart';
export 'queue_controller.dart';
export 'track.dart';
