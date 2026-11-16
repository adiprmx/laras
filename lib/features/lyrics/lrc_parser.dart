/// Parser format LRC (lirik tersinkron) — Dart murni, tanpa I/O.
///
/// Format per baris: `[mm:ss.xx]teks` atau `[mm:ss.xxx]teks`; pecahan
/// detik boleh tidak ada (`[mm:ss]`). Satu baris boleh membawa beberapa
/// timestamp (`[00:01.00][00:05.00]teks`) — tiap timestamp menjadi satu
/// entri dengan teks yang sama. Tag metadata (`[ti:...]`, `[ar:...]`,
/// `[offset:...]`, ...) diabaikan, begitu juga baris tanpa timestamp yang
/// valid dan baris yang teksnya kosong sesudah dipangkas. Hasil diurutkan
/// menaik berdasarkan waktu.
///
/// Tag `[offset:...]` sengaja tidak diterapkan: LRCLIB tidak
/// mengeluarkannya, dan menerapkan offset dari sumber yang tidak
/// terverifikasi akan menggeser semua baris tanpa bisa dibuktikan.
library;

/// Satu baris lirik tersinkron.
class LyricLine {
  const LyricLine({required this.time, required this.text});

  /// Waktu mulai baris ini dinyanyikan.
  final Duration time;

  final String text;

  @override
  bool operator ==(Object other) =>
      other is LyricLine && other.time == time && other.text == text;

  @override
  int get hashCode => Object.hash(time, text);

  @override
  String toString() => 'LyricLine($time, $text)';
}

/// Pola satu timestamp LRC: `[mm:ss.xx]`, `[mm:ss.xxx]`, atau `[mm:ss]`.
/// Titik atau koma diterima sebagai pemisah pecahan (keduanya beredar).
final RegExp _timestampPattern = RegExp(
  r'\[(\d{1,2}):(\d{2})(?:[.,](\d{1,3}))?\]',
);

/// Parse teks LRC menjadi daftar baris tersinkron, urut waktu.
///
/// Mengembalikan daftar kosong bila tidak ada baris yang valid.
List<LyricLine> parseLrc(String input) {
  final List<LyricLine> lines = <LyricLine>[];
  for (final String rawLine in input.split('\n')) {
    final String line = rawLine.trim();
    if (line.isEmpty) continue;
    final Iterable<RegExpMatch> matches = _timestampPattern.allMatches(line);
    if (matches.isEmpty) continue;
    // Teks adalah sisa sesudah timestamp terakhir; baris yang hanya
    // berisi timestamp (tanpa teks) dilewati.
    final String text = line.substring(matches.last.end).trim();
    if (text.isEmpty) continue;
    for (final RegExpMatch match in matches) {
      final int minutes = int.parse(match.group(1)!);
      final int seconds = int.parse(match.group(2)!);
      final String? fraction = match.group(3);
      // Pecahan 1 digit = persepuluh detik, 2 = perseratus, 3 = milidetik.
      final int millis = fraction == null
          ? 0
          : (int.parse(fraction) * switch (fraction.length) {
              1 => 100,
              2 => 10,
              _ => 1,
            });
      lines.add(
        LyricLine(
          time: Duration(minutes: minutes, seconds: seconds, milliseconds: millis),
          text: text,
        ),
      );
    }
  }
  lines.sort((LyricLine a, LyricLine b) => a.time.compareTo(b.time));
  return lines;
}

/// Indeks baris yang sedang aktif pada [position]: baris terakhir yang
/// waktunya tidak lebih dari [position]. Mengembalikan -1 bila belum ada
/// baris yang mulai (mis. posisi sebelum baris pertama).
int lyricLineIndexAt(List<LyricLine> lines, Duration position) {
  int active = -1;
  for (int i = 0; i < lines.length; i++) {
    if (lines[i].time <= position) {
      active = i;
    } else {
      break;
    }
  }
  return active;
}
