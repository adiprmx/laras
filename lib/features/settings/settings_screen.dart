import 'package:flutter/material.dart';
import 'package:laras/core/widgets/empty_state.dart';
import 'package:laras/l10n/generated/app_localizations.dart';

/// Layar Pengaturan. Pengaturan belum dibangun di P0, jadi layar ini berkata
/// jujur soal itu. Kelompok pengaturan (pemutaran, unduhan dan penyimpanan,
/// layanan, app) datang bersama paket P2, P3, P5, dan P6.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final AppLocalizations strings = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(title: Text(strings.settings)),
      body: EmptyState(
        icon: Icons.settings_outlined,
        title: strings.settings,
        body: strings.settingsComingSoon,
      ),
    );
  }
}
