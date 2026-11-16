/// Lembar kejujuran satu kali (B11.5, P6) — komponen callable.
///
/// Orkestrasi first-run (onboarding -> lembar kejujuran -> beranda)
/// MILIK Tim Rombak UI-2: mereka yang memanggil [showHonestySheet] dari
/// main.dart/app shell. Komponen ini TIDAK auto-show dari mana pun.
///
/// [showHonestySheet] menandai flag [kHonestySheetShownKey] setelah
/// lembar ditutup dengan cara apa pun, dan tidak tampil lagi bila flag
/// sudah true. Lembar bisa ditutup dengan menekan di luar lembar,
/// tombol "Mengerti", atau tombol kembali. Berisi penjelasan jujur
/// singkat + tautan ke FAQ 1 dan 2.
///
/// TIDAK ADA baris permanen yang tidak bisa ditutup di beranda (keputusan
/// y PRD): lembar ini menggantikan baris permanen tersebut.
library;

import 'package:flutter/material.dart';
import 'package:laras/core/theme/app_colors.dart';
import 'package:laras/core/theme/app_theme.dart';
import 'package:laras/features/settings/faq_screen.dart';
import 'package:laras/l10n/generated/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Kunci SharedPreferences: lembar kejujuran sudah pernah tampil.
/// Kontrak dengan Tim Rombak UI-2 (verdict owner 17:56 WIB).
const String kHonestySheetShownKey = 'honesty_sheet_shown_v1';

/// Apakah lembar kejujuran sudah pernah tampil. Gagal baca dianggap
/// belum tampil (lebih aman menampilkan sekali lagi daripada tidak
/// pernah menampilkan).
Future<bool> isHonestySheetShown() async {
  try {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getBool(kHonestySheetShownKey) ?? false;
  } on Object {
    return false;
  }
}

Future<void> _markHonestySheetShown() async {
  try {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setBool(kHonestySheetShownKey, true);
  } on Object {
    // Gagal simpan bukan alasan crash: lembar sudah tampil, flag
    // akan ditandai lagi di pemanggilan berikutnya.
  }
}

/// Tampilkan lembar kejujuran. Tidak tampil bila sudah pernah tampil
/// sebelumnya. Mengembalikan future yang selesai setelah lembar
/// ditutup dengan cara apa pun DAN flag sudah ditandai.
Future<void> showHonestySheet(BuildContext context) async {
  if (await isHonestySheetShown()) return;
  if (!context.mounted) return;
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.elevated,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(
        top: Radius.circular(AppRadius.sheet),
      ),
    ),
    builder: (BuildContext context) => const _HonestySheet(),
  );
  await _markHonestySheetShown();
}

class _HonestySheet extends StatelessWidget {
  const _HonestySheet();

  @override
  Widget build(BuildContext context) {
    final AppLocalizations strings = AppLocalizations.of(context)!;
    final ThemeData theme = Theme.of(context);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.md,
          AppSpacing.lg,
          AppSpacing.lg,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.hairline,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(strings.honestyTitle, style: theme.textTheme.titleLarge),
            const SizedBox(height: AppSpacing.sm),
            Text(
              strings.honestyBody,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            _FaqLink(label: strings.faq1q, index: 0),
            _FaqLink(label: strings.faq2q, index: 1),
            const SizedBox(height: AppSpacing.lg),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(strings.understood),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FaqLink extends StatelessWidget {
  const _FaqLink({required this.label, required this.index});

  final String label;
  final int index;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return ListTile(
      contentPadding: EdgeInsets.zero,
      dense: true,
      leading: const Icon(Icons.help_outline, color: AppColors.textSecondary),
      title: Text(
        label,
        style: theme.textTheme.bodyMedium?.copyWith(
          color: AppColors.textPrimary,
        ),
      ),
      trailing: const Icon(Icons.chevron_right, color: AppColors.textMuted),
      onTap: () {
        Navigator.of(context).pop();
        Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (BuildContext context) => FaqScreen(initialIndex: index),
          ),
        );
      },
    );
  }
}
