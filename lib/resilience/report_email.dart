/// Penyusun email laporan kerusakan (B11.4, P6).
///
/// Murni (tanpa I/O): mudah diuji. Isi email HANYA berisi 8 item
/// diagnostik yang diizinkan PRD — tidak pernah berisi alamat IP, email
/// pengguna, cookie, token, URL stream, isi respons InnerTube, path
/// internal, judul lagu, atau isi database.
library;

import 'package:laras/core/app_info.dart';

/// Alamat tujuan laporan kerusakan (D9: dijawab owner).
const String kReportEmailAddress = 'adiprmx@gmail.com';

/// Email laporan kerusakan yang siap dibuka di aplikasi email.
class ReportEmail {
  const ReportEmail({
    required this.to,
    required this.subject,
    required this.body,
  });

  final String to;
  final String subject;
  final String body;
}

/// Susun email laporan kerusakan.
///
/// [deviceModel] dan [androidVersion] berasal dari platform
/// ([ExternalLinks.deviceInfo]); [now] disuntik untuk tes.
/// [diagnosticCode] adalah kode singkat dari `diagnostic_code.dart`
/// (bila ada, ditambahkan sebagai baris sendiri).
ReportEmail buildReportEmail({
  required String deviceModel,
  required String androidVersion,
  DateTime? now,
  String? diagnosticCode,
}) {
  final DateTime time = now ?? DateTime.now();
  final String when =
      '${time.day}-${time.month}-${time.year} '
      '${time.hour.toString().padLeft(2, '0')}:'
      '${time.minute.toString().padLeft(2, '0')}';
  final String codeLine = diagnosticCode == null
      ? ''
      : 'Kode diagnostik: $diagnosticCode\n';
  final String body =
      'Tulis apa yang terjadi di sini:\n'
      '\n'
      '\n'
      '---\n'
      'Versi app: $kAppVersion ($kAppBuild)\n'
      'Model HP: $deviceModel\n'
      'Versi Android: $androidVersion\n'
      'Waktu: $when\n'
      '$codeLine'
      'Lagu yang diputar: diunduh / lewat internet (pilih salah satu)\n'
      'Apakah kejadiannya berulang? (ya / tidak)\n';
  return ReportEmail(
    to: kReportEmailAddress,
    subject: 'Laporan kerusakan Laras',
    body: body,
  );
}
