/// Format ukuran byte ke teks bahasa Indonesia ("4,2 MB").
///
/// Basis 1024 (1 KB = 1024 byte). Desimal memakai koma, satu angka di
/// belakang koma untuk MB/GB, tanpa desimal untuk B/KB. Fungsi murni,
/// dites eksak di `format_bytes_test.dart`.
library;

/// Format [bytes] menjadi teks ukuran ("512 KB", "4,2 MB", "1,2 GB").
String formatBytes(int bytes) {
  if (bytes < 0) return formatBytes(0);
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) {
    final int kb = bytes ~/ 1024;
    return '$kb KB';
  }
  if (bytes < 1024 * 1024 * 1024) {
    return '${_oneDecimal(bytes / (1024 * 1024))} MB';
  }
  return '${_oneDecimal(bytes / (1024 * 1024 * 1024))} GB';
}

String _oneDecimal(double value) {
  return value.toStringAsFixed(1).replaceAll('.', ',');
}
