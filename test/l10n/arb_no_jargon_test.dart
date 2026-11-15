/// Regresi K-F2-08(b): nilai string ARB yang tampil ke user bebas
/// jargon teknis ("spike", "demo spike", "resolve", "log", dan sejenisnya).
///
/// Hanya nilai yang dicek, bukan metadata `@key` (description tidak
/// tampil ke user). Bila tes ini gagal, ada string jargon yang lolos ke
/// permukaan dan harus diganti dengan bahasa sehari-hari.
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('nilai ARB bebas jargon teknis', () {
    final File arb = File('lib/l10n/app_id.arb');
    expect(arb.existsSync(), isTrue);
    final Map<String, Object?> json =
        jsonDecode(arb.readAsStringSync()) as Map<String, Object?>;
    // Batas kata (\b) supaya "dialog" tidak tertangkap "log".
    final RegExp banned = RegExp(
      r'\b(spike|resolve|log|demo|build|client|cache|server)\b',
      caseSensitive: false,
    );
    final List<String> offenders = <String>[];
    for (final MapEntry<String, Object?> entry in json.entries) {
      if (entry.key.startsWith('@')) continue;
      final Object? value = entry.value;
      if (value is String && banned.hasMatch(value)) {
        offenders.add('${entry.key}: "$value"');
      }
    }
    expect(offenders, isEmpty);
  });

  test('kunci jargon demo spike sudah dihapus', () {
    final File arb = File('lib/l10n/app_id.arb');
    final Map<String, Object?> json =
        jsonDecode(arb.readAsStringSync()) as Map<String, Object?>;
    for (final String key in <String>[
      'spikeDemoOpen',
      'spikeDemoTitle',
      'spikeDemoResolving',
      'spikeDemoPlaying',
      'spikeDemoPaused',
      'spikeDemoLogTitle',
      'spikeDemoLogEmpty',
      'spikeDemoNote',
      'spikeDemoBanner',
      'spikeDemoReadyIn',
      'showTechnicalLog',
      'hideTechnicalLog',
      'searchSongs',
    ]) {
      expect(json.containsKey(key), isFalse, reason: key);
    }
  });
}
