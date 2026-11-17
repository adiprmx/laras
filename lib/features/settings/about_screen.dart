/// Layar Tentang (B11.1, P6).
///
/// Nama app, versi, penjelasan singkat, disclaimer non-afiliasi +
/// legal, lisensi GPL-3.0-only, tautan kode sumber, ringkasan privasi
/// singkat, dan alamat email kontak.
///
/// Baris "Kebijakan privasi" (P10) membuka layar kebijakan lengkap
/// dari aset; isinya sama dengan PRIVACY_POLICY.md di root repo.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:laras/core/app_info.dart';
import 'package:laras/core/theme/app_colors.dart';
import 'package:laras/core/theme/app_theme.dart';
import 'package:laras/features/settings/privacy_policy_screen.dart';
import 'package:laras/l10n/generated/app_localizations.dart';
import 'package:laras/resilience/report_email.dart';
import 'package:laras/resilience/resilience_scope.dart';

/// Tautan kode sumber Laras.
const String kLarasRepoUrl = 'https://github.com/adiprmx/laras';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final AppLocalizations strings = AppLocalizations.of(context)!;
    final ThemeData theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(strings.aboutTitle)),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: <Widget>[
          Text('Laras', style: theme.textTheme.headlineSmall),
          const SizedBox(height: AppSpacing.xs),
          Text(
            strings.aboutVersion('$kAppVersion ($kAppBuild)'),
            style: theme.textTheme.bodyMedium?.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            strings.aboutBody,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            strings.aboutDisclaimer,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            strings.aboutLicense,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            strings.aboutPrivacyNote,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            strings.supportArtists,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.shield_outlined),
            title: Text(strings.privacyPolicyTitle),
            trailing: const Icon(
              Icons.chevron_right,
              size: 18,
              color: AppColors.textMuted,
            ),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const PrivacyPolicyScreen(),
                ),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.code),
            title: Text(strings.aboutRepo),
            subtitle: const Text('github.com/adiprmx/laras'),
            trailing: const Icon(
              Icons.open_in_new,
              size: 18,
              color: AppColors.textMuted,
            ),
            onTap: () {
              ResilienceScope.externalLinksOf(context)?.openLink(kLarasRepoUrl);
            },
          ),
          ListTile(
            leading: const Icon(Icons.email_outlined),
            title: Text(strings.aboutEmail),
            subtitle: const Text(kReportEmailAddress),
            trailing: const Icon(
              Icons.copy,
              size: 18,
              color: AppColors.textMuted,
            ),
            onTap: () async {
              await Clipboard.setData(
                const ClipboardData(text: kReportEmailAddress),
              );
              if (!context.mounted) return;
              ScaffoldMessenger.of(context)
                  .showSnackBar(SnackBar(content: Text(strings.emailCopied)));
            },
          ),
        ],
      ),
    );
  }
}
