/// Tes pengaturan pengguna (P6, tugas 7).
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:laras/resilience/app_settings.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    prefs = await SharedPreferences.getInstance();
  });

  test('nilai bawaan: hemat data mati, kualitas terbaik, WiFi saja mati, '
      'batas 500 MB', () {
    final AppSettings settings = AppSettings.forTest(prefs);
    expect(settings.dataSaver.value, isFalse);
    expect(settings.defaultQuality.value, kQualityBest);
    expect(settings.wifiOnly.value, isFalse);
    expect(settings.cacheLimitBytes.value, 500 * 1024 * 1024);
  });

  test('setter memperbarui notifier + tersimpan di prefs', () async {
    final AppSettings settings = AppSettings.forTest(prefs);
    await settings.setDataSaver(true);
    await settings.setDefaultQuality(kQualityDataSaver);
    await settings.setWifiOnly(true);
    await settings.setCacheLimitBytes(1024 * 1024 * 1024);

    expect(settings.dataSaver.value, isTrue);
    expect(settings.defaultQuality.value, kQualityDataSaver);
    expect(settings.wifiOnly.value, isTrue);
    expect(settings.cacheLimitBytes.value, 1024 * 1024 * 1024);

    // Nilai bertahan bila settings dibuat ulang dari prefs yang sama.
    final AppSettings again = AppSettings.forTest(prefs);
    expect(again.dataSaver.value, isTrue);
    expect(again.defaultQuality.value, kQualityDataSaver);
    expect(again.wifiOnly.value, isTrue);
    expect(again.cacheLimitBytes.value, 1024 * 1024 * 1024);
  });

  test('kualitas tidak valid diabaikan', () async {
    final AppSettings settings = AppSettings.forTest(prefs);
    await settings.setDefaultQuality('ultra-hd');
    expect(settings.defaultQuality.value, kQualityBest);
  });

  test('batas di luar daftar dijepit ke pilihan terdekat', () async {
    final AppSettings settings = AppSettings.forTest(prefs);
    await settings.setCacheLimitBytes(700 * 1024 * 1024);
    // 700 MB lebih dekat ke 500 MB daripada ke 1 GB.
    expect(settings.cacheLimitBytes.value, 500 * 1024 * 1024);
    await settings.setCacheLimitBytes(900 * 1024 * 1024);
    expect(settings.cacheLimitBytes.value, 1024 * 1024 * 1024);
  });
}
