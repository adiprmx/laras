/// Tes penyusun email laporan kerusakan (B11.4, P6).
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:laras/resilience/report_email.dart';

void main() {
  test('email berisi 8 item diagnostik yang diizinkan, tanpa data terlarang',
      () {
    final ReportEmail email = buildReportEmail(
      deviceModel: 'Pixel 8',
      androidVersion: '14',
      now: DateTime(2026, 11, 16, 10, 15),
    );
    expect(email.to, 'adiprmx@gmail.com');
    expect(email.subject, 'Laporan kerusakan Laras');
    expect(email.body, contains('Versi app: 1.0.0 (2)'));
    expect(email.body, contains('Model HP: Pixel 8'));
    expect(email.body, contains('Versi Android: 14'));
    expect(email.body, contains('Waktu: 16-11-2026 10:15'));
    expect(email.body, contains('Lagu yang diputar: diunduh / lewat internet'));
    expect(email.body, contains('Apakah kejadiannya berulang?'));
    // Data terlarang PRD B11.4 tidak pernah muncul.
    expect(email.body, isNot(contains('http')));
    expect(email.body, isNot(contains('@')));
    expect(email.body, isNot(contains('/data/')));
    expect(email.body, isNot(contains('/storage/')));
  });

  test('kode diagnostik ditambahkan sebagai baris sendiri bila ada', () {
    final ReportEmail withCode = buildReportEmail(
      deviceModel: 'Pixel 8',
      androidVersion: '14',
      diagnosticCode: 'LRS1-UPF-16111905-WMV-1002-R20261110-D',
    );
    expect(
      withCode.body,
      contains('Kode diagnostik: LRS1-UPF-16111905-WMV-1002-R20261110-D'),
    );
    final ReportEmail withoutCode = buildReportEmail(
      deviceModel: 'Pixel 8',
      androidVersion: '14',
    );
    expect(withoutCode.body, isNot(contains('Kode diagnostik')));
  });
}
