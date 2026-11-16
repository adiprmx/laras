/// Tes EqualizerService (P7): attach/init, preset, level pita, persistensi
/// pengaturan, dan perangkat tanpa equalizer. Platform dipalsukan lewat
/// mock MethodChannel.
library;

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:laras/player/equalizer_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Perangkat EQ palsu: 5 pita + 3 preset, level bisa diubah.
class FakeEqualizerPlatform {
  FakeEqualizerPlatform({this.available = true});

  final bool available;
  List<int> levels = <int>[0, 0, 0, 0, 0];
  int currentPreset = 0;
  bool enabled = false;
  int initCount = 0;
  int releaseCount = 0;

  static const List<int> freqs = <int>[60000, 230000, 910000, 3600000, 14000000];
  static const List<String> presets = <String>['Normal', 'Rock', 'Jazz'];

  Future<Object?> handle(MethodCall call) async {
    switch (call.method) {
      case 'init':
        initCount++;
        if (!available) return <String, Object>{'available': false};
        return <String, Object>{
          'available': true,
          'centerFreqs': freqs,
          'levels': levels,
          'minLevel': -1500,
          'maxLevel': 1500,
          'presets': presets,
          'currentPreset': currentPreset,
        };
      case 'setEnabled':
        enabled = (call.arguments as Map)['enabled'] as bool;
        return true;
      case 'setPreset':
        final int preset = (call.arguments as Map)['preset'] as int;
        currentPreset = preset;
        // Preset mengubah level (simulasi perangkat).
        levels = List<int>.generate(5, (int i) => preset * 100 + i * 10);
        return levels;
      case 'setBandLevel':
        final Map args = call.arguments as Map;
        levels[args['band'] as int] = args['level'] as int;
        return true;
      case 'release':
        releaseCount++;
        return null;
      default:
        throw MissingPluginException();
    }
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const MethodChannel channel = MethodChannel(
    'id.my.adipmusic.laras/equalizer',
  );

  late FakeEqualizerPlatform platform;

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    platform = FakeEqualizerPlatform();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, platform.handle);
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  Future<EqualizerService> service() async {
    return EqualizerService(
      prefs: await SharedPreferences.getInstance(),
    );
  }

  group('formatEqualizerFrequency', () {
    test('Hz di bawah 1000', () {
      expect(formatEqualizerFrequency(60000), '60 Hz');
      expect(formatEqualizerFrequency(910000), '910 Hz');
    });

    test('kHz bulat tanpa desimal', () {
      expect(formatEqualizerFrequency(1000000), '1 kHz');
      expect(formatEqualizerFrequency(14000000), '14 kHz');
    });

    test('kHz pecahan memakai koma desimal', () {
      expect(formatEqualizerFrequency(3600000), '3,6 kHz');
    });
  });

  group('EqualizerService', () {
    test('attach mengisi info dari platform', () async {
      final EqualizerService eq = await service();
      await eq.attach(123);
      final EqualizerInfo? info = eq.info.value;
      expect(info, isNotNull);
      expect(info!.bands, hasLength(5));
      expect(info.bands[0].centerFreqMilliHz, 60000);
      expect(info.bands[4].centerFreqMilliHz, 14000000);
      expect(info.minLevelMillibels, -1500);
      expect(info.maxLevelMillibels, 1500);
      expect(info.presets, FakeEqualizerPlatform.presets);
      expect(info.currentPreset, 0);
      expect(platform.initCount, 1);
      await eq.dispose();
    });

    test('attach id sama adalah no-op; id baru me-release + init ulang',
        () async {
      final EqualizerService eq = await service();
      await eq.attach(123);
      await eq.attach(123);
      expect(platform.initCount, 1);
      expect(platform.releaseCount, 0);
      await eq.attach(456);
      expect(platform.initCount, 2);
      expect(platform.releaseCount, 1);
      await eq.dispose();
    });

    test('attach null melepas dan mengosongkan info', () async {
      final EqualizerService eq = await service();
      await eq.attach(123);
      expect(eq.info.value, isNotNull);
      await eq.attach(null);
      expect(eq.info.value, isNull);
      expect(platform.releaseCount, 1);
      await eq.dispose();
    });

    test('perangkat tanpa EQ menghasilkan info null', () async {
      platform = FakeEqualizerPlatform(available: false);
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, platform.handle);
      final EqualizerService eq = await service();
      await eq.attach(123);
      expect(eq.info.value, isNull);
      await eq.dispose();
    });

    test('setPreset mengubah level + menyimpan preset', () async {
      final EqualizerService eq = await service();
      await eq.attach(123);
      await eq.setPreset(1);
      expect(eq.info.value!.currentPreset, 1);
      expect(eq.info.value!.bands[0].levelMillibels, 100);
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      expect(prefs.getInt('laras.eq_preset'), 1);
      await eq.dispose();
    });

    test('setBandLevel mengubah level + preset menjadi kustom (-1)',
        () async {
      final EqualizerService eq = await service();
      await eq.attach(123);
      await eq.setBandLevel(2, 500);
      expect(eq.info.value!.bands[2].levelMillibels, 500);
      expect(eq.info.value!.currentPreset, -1);
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      expect(prefs.getInt('laras.eq_preset'), -1);
      expect(
        prefs.getStringList('laras.eq_levels'),
        <String>['0', '0', '500', '0', '0'],
      );
      await eq.dispose();
    });

    test('setBandLevel menjepit ke rentang perangkat', () async {
      final EqualizerService eq = await service();
      await eq.attach(123);
      await eq.setBandLevel(0, 99999);
      expect(eq.info.value!.bands[0].levelMillibels, 1500);
      await eq.setBandLevel(0, -99999);
      expect(eq.info.value!.bands[0].levelMillibels, -1500);
      await eq.dispose();
    });

    test('setEnabled menyimpan status aktif', () async {
      final EqualizerService eq = await service();
      await eq.attach(123);
      await eq.setEnabled(true);
      expect(eq.enabled.value, isTrue);
      expect(platform.enabled, isTrue);
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('laras.eq_enabled'), isTrue);
      await eq.dispose();
    });

    test('pengaturan tersimpan diterapkan ulang saat attach', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        'laras.eq_enabled': true,
        'laras.eq_preset': 2,
      });
      final EqualizerService eq = await service();
      await eq.attach(123);
      expect(eq.info.value!.currentPreset, 2);
      expect(eq.enabled.value, isTrue);
      expect(platform.enabled, isTrue);
      await eq.dispose();
    });

    test('level kustom tersimpan diterapkan ulang saat attach', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        'laras.eq_preset': -1,
        'laras.eq_levels': <String>['100', '200', '300', '400', '500'],
      });
      final EqualizerService eq = await service();
      await eq.attach(123);
      expect(eq.info.value!.currentPreset, -1);
      expect(
        eq.info.value!.bands.map((EqualizerBand b) => b.levelMillibels).toList(),
        <int>[100, 200, 300, 400, 500],
      );
      await eq.dispose();
    });
  });
}
