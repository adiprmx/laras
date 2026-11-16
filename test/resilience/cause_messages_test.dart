/// Tes pemetaan 6 penyebab ke pesan pengguna (P6, tugas 2).
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:laras/extractor/errors.dart';
import 'package:laras/l10n/generated/app_localizations.dart';
import 'package:laras/l10n/generated/app_localizations_id.dart';
import 'package:laras/resilience/cause_messages.dart';

void main() {
  final AppLocalizations strings = AppLocalizationsId();

  test('keenam penyebab punya pesan berbeda dan tanpa jargon', () {
    final Set<String> seen = <String>{};
    for (final ResolveFailureCause cause in ResolveFailureCause.values) {
      final String message = causeMessage(strings, cause);
      expect(message, isNotEmpty);
      expect(seen.add(message), isTrue, reason: '$cause duplikat pesan');
      // Jargon teknis dilarang di string UI (aturan tes ARB).
      expect(
        message.toLowerCase(),
        isNot(contains('resolve')),
        reason: '$cause',
      );
      expect(message.toLowerCase(), isNot(contains('client')), reason: '$cause');
      expect(message.toLowerCase(), isNot(contains('server')), reason: '$cause');
      expect(message.toLowerCase(), isNot(contains('cache')), reason: '$cause');
      expect(message.toLowerCase(), isNot(contains('spike')), reason: '$cause');
      expect(message.toLowerCase(), isNot(contains('log')), reason: '$cause');
    }
  });

  test('pesan per penyebab sesuai ARB', () {
    expect(causeMessage(strings, ResolveFailureCause.httpForbidden),
        strings.causeForbidden);
    expect(causeMessage(strings, ResolveFailureCause.emptyResponse),
        strings.causeEmptyResponse);
    expect(causeMessage(strings, ResolveFailureCause.parseFailed),
        strings.causeParseFailed);
    expect(causeMessage(strings, ResolveFailureCause.sabrOnly),
        strings.causeSabrOnly);
    expect(causeMessage(strings, ResolveFailureCause.solverTimeout),
        strings.causeSolverTimeout);
    expect(causeMessage(strings, ResolveFailureCause.unknownPlayerHash),
        strings.causeUnknownPlayerHash);
  });

  test('causeSuggestsUpdate benar hanya untuk penyebab "YouTube berubah"',
      () {
    expect(causeSuggestsUpdate(ResolveFailureCause.parseFailed), isTrue);
    expect(causeSuggestsUpdate(ResolveFailureCause.unknownPlayerHash), isTrue);
    expect(causeSuggestsUpdate(ResolveFailureCause.sabrOnly), isTrue);
    expect(causeSuggestsUpdate(ResolveFailureCause.httpForbidden), isFalse);
    expect(causeSuggestsUpdate(ResolveFailureCause.emptyResponse), isFalse);
    expect(causeSuggestsUpdate(ResolveFailureCause.solverTimeout), isFalse);
  });

  test('varian singkat: berbeda per penyebab, muat satu baris, tanpa jargon',
      () {
    final Set<String> seen = <String>{};
    for (final ResolveFailureCause cause in ResolveFailureCause.values) {
      final String short = causeShortMessage(strings, cause);
      expect(short, isNotEmpty);
      expect(seen.add(short), isTrue, reason: '$cause duplikat pesan singkat');
      expect(short.length, lessThanOrEqualTo(25),
          reason: '$cause terlalu panjang untuk mini-player: "$short"');
      expect(short.toLowerCase(), isNot(contains('resolve')), reason: '$cause');
      expect(short.toLowerCase(), isNot(contains('client')), reason: '$cause');
      expect(short.toLowerCase(), isNot(contains('server')), reason: '$cause');
      expect(short.toLowerCase(), isNot(contains('cache')), reason: '$cause');
      expect(short.toLowerCase(), isNot(contains('spike')), reason: '$cause');
      expect(short.toLowerCase(), isNot(contains('log')), reason: '$cause');
    }
  });
}
