/// Tes PlaybackPrefs (P7, sisa P2): default, simpan-muat, dan sanitasi
/// nilai rusak.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:laras/player/playback_prefs.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  Future<PlaybackPrefs> prefs() async {
    return PlaybackPrefs(prefs: await SharedPreferences.getInstance());
  }

  test('default: kecepatan 1.0, nada 1.0, lewati-hening mati', () async {
    final PlaybackPrefs p = await prefs();
    expect(p.speed, 1.0);
    expect(p.pitch, 1.0);
    expect(p.skipSilence, isFalse);
  });

  test('nilai tersimpan dibaca kembali', () async {
    final PlaybackPrefs p = await prefs();
    await p.saveAll(speed: 1.5, pitch: 0.75, skipSilence: true);
    final PlaybackPrefs again = await prefs();
    expect(again.speed, 1.5);
    expect(again.pitch, 0.75);
    expect(again.skipSilence, isTrue);
  });

  test('setter menjepit ke rentang port', () async {
    final PlaybackPrefs p = await prefs();
    await p.setSpeed(99);
    expect(p.speed, 3.0);
    await p.setSpeed(0.01);
    expect(p.speed, 0.25);
    await p.setPitch(99);
    expect(p.pitch, 2.0);
    await p.setPitch(0.01);
    expect(p.pitch, 0.5);
  });

  test('nilai tersimpan di luar rentang dijepit saat dibaca', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'laras.playback_speed': 99.0,
      'laras.playback_pitch': -5.0,
    });
    final PlaybackPrefs p = await prefs();
    expect(p.speed, 3.0);
    expect(p.pitch, 0.5);
  });

  test('NaN jatuh ke default 1.0', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'laras.playback_speed': double.nan,
      'laras.playback_pitch': double.nan,
    });
    final PlaybackPrefs p = await prefs();
    expect(p.speed, 1.0);
    expect(p.pitch, 1.0);
  });
}
