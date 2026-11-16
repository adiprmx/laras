/// Tes regresi solver QuickJS (R1-H1) + verifikasi perilaku gg_quickjs.
///
/// - Versi engine: QuickJS-ng yang dibundel WAJIB >= 0.16.0 (versi
///   perbaikan CVE-2026-120438/120439/120440). `quickjsNgVersion`
///   adalah konstanta Dart, jadi tes ini jalan tanpa memuat lib native.
/// - Batas: stack WAJIB <= 512 KiB (peringatan README gg_quickjs:
///   limit lebih besar bisa crash proses native).
/// - Smoke runtime: gg_quickjs mendukung Linux host (build hook
///   mengompilasi dari source), jadi evaluate + timeout + sandbox
///   bisa diuji langsung di `flutter test`.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:gg_quickjs/gg_quickjs.dart';
import 'package:laras/extractor/cipher/signature_solver.dart';

void main() {
  group('R1-H1: versi engine QuickJS-ng', () {
    test('quickjsNgVersion >= 0.16.0 (versi perbaikan CVE)', () {
      // CVE-2026-120438/120439/120440 diperbaiki di QuickJS-NG 0.16.0.
      // quickjs_engine 0.1.7 membundel 0.14.0 (rentan); gg_quickjs
      // 0.1.0 membundel 0.17.0. Tes ini menangkap regresi ke engine
      // lama bila dependensi diganti lagi.
      List<int> parse(String v) =>
          v.split('.').map((e) => int.parse(e)).toList();
      final List<int> actual = parse(quickjsNgVersion);
      const List<int> minimum = <int>[0, 16, 0];
      expect(actual.length, 3);
      var atLeastMinimum = false;
      for (var i = 0; i < 3; i++) {
        if (actual[i] > minimum[i]) {
          atLeastMinimum = true;
          break;
        }
        if (actual[i] < minimum[i]) break;
        if (i == 2) atLeastMinimum = true;
      }
      expect(
        atLeastMinimum,
        isTrue,
        reason: 'engine $quickjsNgVersion masih di bawah 0.16.0',
      );
    });

    test('batas runtime aman untuk gg_quickjs', () {
      expect(QuickJsLimits.memoryBytes, 192 * 1024 * 1024);
      expect(QuickJsLimits.timeout, const Duration(seconds: 10));
      // README gg_quickjs: maxStackSize > 512 KiB bisa crash native.
      expect(QuickJsLimits.stackBytes, lessThanOrEqualTo(512 * 1024));
    });
  });

  group('gg_quickjs: perilaku runtime di host', () {
    test('evaluate mengembalikan nilai Dart', () {
      final JsRuntime rt = JsRuntime(
        options: const JsRuntimeOptions(
          memoryLimit: 32 * 1024 * 1024,
          timeout: Duration(seconds: 5),
        ),
      );
      addTearDown(rt.dispose);
      expect(rt.evaluate('1 + 41'), 42);
      expect(rt.evaluate('"halo"'), 'halo');
      // Codec gg_quickjs memetakan undefined JS ke null Dart.
      expect(rt.evaluate('undefined'), isNull);
    });

    test('error JS melempar JsException bertipe', () {
      final JsRuntime rt = JsRuntime(
        options: const JsRuntimeOptions(
          memoryLimit: 32 * 1024 * 1024,
          timeout: Duration(seconds: 5),
        ),
      );
      addTearDown(rt.dispose);
      expect(() => rt.evaluate('var = ;'), throwsA(isA<JsSyntaxError>()));
      expect(
        () => rt.evaluate('tidakAda()'),
        throwsA(isA<JsReferenceError>()),
      );
    });

    test('timeout ditegakkan runtime (JsInterruptedError)', () {
      final JsRuntime rt = JsRuntime(
        options: const JsRuntimeOptions(
          memoryLimit: 32 * 1024 * 1024,
          timeout: Duration(seconds: 1),
        ),
      );
      addTearDown(rt.dispose);
      // Berbeda dari quickjs_engine 0.1.7 yang timeout-nya tidak
      // berfungsi: gg_quickjs memakai interrupt handler QuickJS-ng.
      final Stopwatch sw = Stopwatch()..start();
      expect(
        () => rt.evaluate('while (true) {}'),
        throwsA(isA<JsInterruptedError>()),
      );
      sw.stop();
      expect(sw.elapsed, lessThan(const Duration(seconds: 10)));
      // Runtime tetap bisa dipakai setelah interrupt.
      expect(rt.evaluate('2 + 2'), 4);
    });

    test('sandbox: tanpa fetch/console/timer', () {
      final JsRuntime rt = JsRuntime(
        options: const JsRuntimeOptions(
          memoryLimit: 32 * 1024 * 1024,
          timeout: Duration(seconds: 5),
        ),
      );
      addTearDown(rt.dispose);
      expect(rt.evaluate('typeof fetch'), 'undefined');
      expect(rt.evaluate('typeof console'), 'undefined');
      expect(rt.evaluate('typeof setTimeout'), 'undefined');
      expect(rt.evaluate('typeof require'), 'undefined');
    });
  });
}
