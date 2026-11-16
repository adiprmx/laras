import 'package:flutter_test/flutter_test.dart';
import 'package:laras/downloads/downloads.dart';

void main() {
  group('formatBytes', () {
    test('byte di bawah 1024 tanpa satuan besar', () {
      expect(formatBytes(0), '0 B');
      expect(formatBytes(512), '512 B');
      expect(formatBytes(1023), '1023 B');
    });

    test('KB tanpa desimal, dibulatkan ke bawah', () {
      expect(formatBytes(1024), '1 KB');
      expect(formatBytes(1536), '1 KB');
      expect(formatBytes(1024 * 1024 - 1), '1023 KB');
    });

    test('MB satu desimal koma', () {
      expect(formatBytes(1024 * 1024), '1,0 MB');
      // 4.200.000 byte = 4,005 MB -> "4,0 MB".
      expect(formatBytes(4200000), '4,0 MB');
    });

    test('GB satu desimal koma', () {
      expect(formatBytes(1024 * 1024 * 1024), '1,0 GB');
      expect(formatBytes((1.5 * 1024 * 1024 * 1024).toInt()), '1,5 GB');
    });

    test('negatif diperlakukan sebagai nol', () {
      expect(formatBytes(-5), '0 B');
    });
  });
}
