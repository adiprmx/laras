/// Aksi "Laporkan kerusakan" bersama (B11.4, P6).
///
/// Dipakai baris Pengaturan dan tautan bawah FAQ: tampilkan dialog
/// dengan kode diagnostik singkat (bisa disalin dan ditempel di chat),
/// lalu bila pengguna memilih, buka aplikasi email dengan kode yang
/// sama di badan email. Bila tidak ada aplikasi email, alamat disalin
/// ke clipboard dan pengguna diberitahu lewat snackbar (tidak ada
/// jalan buntu diam-diam).
///
/// Semua data kode diagnostik bersifat lokal (snapshot player + log
/// resolve + status kanari + versi config) — dialog berfungsi penuh
/// saat offline.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:laras/core/app_info.dart';
import 'package:laras/extractor/models.dart';
import 'package:laras/l10n/generated/app_localizations.dart';
import 'package:laras/player/player_scope.dart';
import 'package:laras/player/player_service.dart';
import 'package:laras/player/player_state.dart';
import 'package:laras/resilience/diagnostic_code.dart';
import 'package:laras/resilience/external_links.dart';
import 'package:laras/resilience/report_email.dart';
import 'package:laras/resilience/resilience_scope.dart';
import 'package:laras/resilience/service_status.dart';

/// Tampilkan dialog laporan kerusakan (kode diagnostik + aksi).
/// Tidak melakukan apa-apa bila layanan tautan keluar tidak tersedia
/// (baris pemanggil disembunyikan dalam kondisi itu).
Future<void> openReportProblem(BuildContext context) async {
  final ExternalLinks? links = ResilienceScope.externalLinksOf(context);
  if (links == null) return;
  final AppLocalizations strings = AppLocalizations.of(context)!;
  final String code = await _collectCode(context);
  if (!context.mounted) return;
  final bool? sendEmail = await showDialog<bool>(
    context: context,
    builder: (BuildContext dialogContext) =>
        _ReportDialog(code: code, strings: strings),
  );
  if (sendEmail != true || !context.mounted) return;
  final (String, String) info = await links.deviceInfo();
  final ReportEmail email = buildReportEmail(
    deviceModel: info.$1,
    androidVersion: info.$2,
    diagnosticCode: code,
  );
  final bool opened = await links.openMail(
    to: email.to,
    subject: email.subject,
    body: email.body,
  );
  if (opened || !context.mounted) return;
  await Clipboard.setData(const ClipboardData(text: kReportEmailAddress));
  if (!context.mounted) return;
  ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(content: Text(strings.reportProblemNoMail)));
}

/// Rakit kode diagnostik dari snapshot player + status layanan yang
/// tersedia di tree. Tidak pernah melempar: bila tidak ada player atau
/// config tidak bisa dibaca, kode tetap dibuat dengan segmen "tidak
/// diketahui" (X / XX / B / ?).
Future<String> _collectCode(BuildContext context) async {
  PlaybackFailure? lastFailure;
  try {
    final PlayerService? player = PlayerScope.maybeOf(context);
    lastFailure = player?.port.snapshot.lastError;
    final ServiceStatusService? service = ResilienceScope.serviceStatusOf(
      context,
    );
    final ({String version, bool isRemote}) config = service == null
        ? (version: '', isRemote: false)
        : await service.currentConfigInfo();
    final DiagnosticData data = collectDiagnosticData(
      lastFailure: lastFailure,
      recentLog: player?.resolver.recentLog ?? const <ResolveLogEntry>[],
      serviceStatus: service?.status.value.status,
      configVersion: config.version.isEmpty ? null : config.version,
      configIsRemote: config.isRemote,
      appVersion: kAppVersion,
      appBuild: kAppBuild,
    );
    return buildDiagnosticCode(data);
  } on Object {
    // Gagal baca snapshot (mis. port belum siap): kode kosong tetap
    // lebih berguna daripada dialog tanpa kode.
    return buildDiagnosticCode(
      const DiagnosticData(appVersion: kAppVersion, appBuild: kAppBuild),
    );
  }
}

/// Dialog kode diagnostik: penjelasan singkat, kode yang bisa dipilih,
/// tombol salin, dan aksi kirim lewat email.
class _ReportDialog extends StatelessWidget {
  const _ReportDialog({required this.code, required this.strings});

  final String code;
  final AppLocalizations strings;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return AlertDialog(
      title: Text(strings.reportProblem),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(strings.reportDialogBody),
          const SizedBox(height: 16),
          Text(strings.diagnosticCodeLabel, style: theme.textTheme.bodySmall),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(8),
            ),
            child: SelectableText(
              code,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontFamily: 'monospace',
              ),
            ),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: code));
              if (!context.mounted) return;
              ScaffoldMessenger.of(context)
                  .showSnackBar(SnackBar(content: Text(strings.codeCopied)));
            },
            icon: const Icon(Icons.copy_outlined),
            label: Text(strings.copyCode),
          ),
        ],
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(strings.cancel),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(strings.sendViaEmail),
        ),
      ],
    );
  }
}
