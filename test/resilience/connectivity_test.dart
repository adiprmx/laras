/// Tes gerbang WiFi + monitor konektivitas (P6, B8.4).
library;

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:laras/resilience/connectivity.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('WifiGate', () {
    test('saklar mati: selalu boleh, tanpa memeriksa WiFi', () async {
      bool checked = false;
      final WifiGate gate = WifiGate(
        wifiOnly: () => false,
        isWifiConnected: () async {
          checked = true;
          return false;
        },
      );
      expect(await gate.mayDownload, isTrue);
      expect(checked, isFalse);
    });

    test('saklar hidup + WiFi: boleh; bukan WiFi: tidak boleh', () async {
      bool wifi = true;
      final WifiGate gate = WifiGate(
        wifiOnly: () => true,
        isWifiConnected: () async => wifi,
      );
      expect(await gate.mayDownload, isTrue);
      wifi = false;
      expect(await gate.mayDownload, isFalse);
    });

    test('status tidak diketahui: fail-open (boleh)', () async {
      final WifiGate gate = WifiGate(
        wifiOnly: () => true,
        isWifiConnected: () async => null,
      );
      expect(await gate.mayDownload, isTrue);
    });

    test('wifiOnly membaca pengaturan terkini (bukan salinan awal)',
        () async {
      bool flag = false;
      final WifiGate gate = WifiGate(
        wifiOnly: () => flag,
        isWifiConnected: () async => false,
      );
      expect(await gate.mayDownload, isTrue);
      flag = true;
      expect(await gate.mayDownload, isFalse);
    });
  });

  group('ConnectivityMonitor', () {
    const MethodChannel channel = MethodChannel(
      'id.my.adipmusic.laras/connectivity',
    );

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });

    test('isWifi meneruskan jawaban platform', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (MethodCall call) async {
            expect(call.method, 'isWifi');
            return true;
          });
      final ConnectivityMonitor monitor = ConnectivityMonitor();
      expect(await monitor.isWifi(), isTrue);
    });

    test('isWifi mengembalikan null bila platform error', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (MethodCall call) async {
            throw PlatformException(code: 'GAGAL');
          });
      final ConnectivityMonitor monitor = ConnectivityMonitor();
      expect(await monitor.isWifi(), isNull);
    });

    test('isWifi mengembalikan null bila tidak ada handler', () async {
      final ConnectivityMonitor monitor = ConnectivityMonitor();
      expect(await monitor.isWifi(), isNull);
    });
  });
}
