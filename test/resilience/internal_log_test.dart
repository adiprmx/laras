/// Tes log internal (P6, tugas 10): batas 1 MB, rotasi, redaksi URL.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:laras/resilience/internal_log.dart';

void main() {
  late Directory temp;

  setUp(() {
    temp = Directory.systemTemp.createTempSync('laras-log-test');
  });

  tearDown(() {
    if (temp.existsSync()) temp.deleteSync(recursive: true);
  });

  test('menulis baris dengan tag dan waktu', () async {
    final InternalLog log = InternalLog(directory: temp);
    await log.write('kanari', 'cek selesai: ok');
    final String content =
        File('${temp.path}/$kInternalLogFileName').readAsStringSync();
    expect(content, contains('[kanari] cek selesai: ok'));
  });

  test('URL http(s) disensor — tidak pernah ada URL stream di log', () async {
    final InternalLog log = InternalLog(directory: temp);
    await log.write(
      'resolve',
      'gagal https://rr1---sn.googlevideo.com/videoplayback?x=1 dan http://a.b/c',
    );
    final String content =
        File('${temp.path}/$kInternalLogFileName').readAsStringSync();
    expect(content, isNot(contains('googlevideo')));
    expect(content, isNot(contains('https://')));
    expect(content, isNot(contains('http://')));
    expect(content, contains('[tautan]'));
  });

  test('rotasi: file tidak pernah melewati batas jauh; isi terbaru bertahan',
      () async {
    // Batas kecil supaya rotasi terpicu cepat.
    final InternalLog log = InternalLog(directory: temp, maxBytes: 200);
    for (int i = 0; i < 30; i++) {
      await log.write('t', 'baris ke-$i xxxxxxxxxxxxxxxxxxxx');
    }
    final File file = File('${temp.path}/$kInternalLogFileName');
    final int size = file.lengthSync();
    expect(size, lessThanOrEqualTo(200 + 60));
    final String content = file.readAsStringSync();
    // Baris terbaru bertahan, baris terlama terbuang.
    expect(content, contains('baris ke-29'));
    expect(content, isNot(contains('baris ke-0 ')));
    // Tidak ada baris setengah di awal (rotasi di batas baris).
    expect(content.startsWith('['), isTrue);
  });

  test('tulis berurutan tidak saling menimpa', () async {
    final InternalLog log = InternalLog(directory: temp);
    await Future.wait(<Future<void>>[
      for (int i = 0; i < 20; i++) log.write('t', 'pesan $i'),
    ]);
    final String content =
        File('${temp.path}/$kInternalLogFileName').readAsStringSync();
    for (int i = 0; i < 20; i++) {
      expect(content, contains('pesan $i'));
    }
  });

  test('write tidak pernah melempar walau direktori tidak bisa ditulis',
      () async {
    // Direktori dihapus sesudah log dibuat: parent.create akan gagal
    // bila path sudah dipakai file (bukan direktori).
    final File blocker = File('${temp.path}/blocker');
    blocker.writeAsStringSync('x');
    final InternalLog log = InternalLog(
      directory: Directory('${blocker.path}/sub'),
    );
    await log.write('t', 'ini tidak boleh melempar');
  });
}
