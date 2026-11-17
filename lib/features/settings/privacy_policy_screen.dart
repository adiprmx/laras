/// Layar Kebijakan privasi (P10).
///
/// Menampilkan isi kebijakan privasi dari aset
/// `assets/privacy_policy_id.md` sebagai teks biasa yang bisa dipilih
/// (SelectableText). Isi aset ini SAMA dengan `PRIVACY_POLICY.md` di
/// root repo: satu versi, bukan dua. Kesamaan itu dikunci oleh tes
/// di `test/features/settings/privacy_policy_screen_test.dart`.
///
/// Sengaja TANPA flutter_markdown (nol dependensi baru): file
/// kebijakannya ditulis sebagai markdown minimal yang tetap enak
/// dibaca sebagai teks mentah (judul `#`, poin `-`, tautan dan email
/// ditulis utuh, tanpa `**tebal**` atau `[teks](tautan)`).
///
/// [policyLoader] hanya untuk tes: layar produksi selalu membaca
/// aset lewat rootBundle. Tes tanpa loader membuktikan asetnya
/// benar-benar terbungkus di app; tes dengan loader membuktikan
/// status memuat dan gagal tanpa bergantung pada aset.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:laras/core/theme/app_colors.dart';
import 'package:laras/core/theme/app_theme.dart';
import 'package:laras/l10n/generated/app_localizations.dart';

/// Path aset kebijakan privasi Bahasa Indonesia.
const String kPrivacyPolicyAssetPath = 'assets/privacy_policy_id.md';

class PrivacyPolicyScreen extends StatefulWidget {
  const PrivacyPolicyScreen({super.key, this.policyLoader});

  /// Pemuat isi kebijakan. Bila null, layar membaca aset
  /// [kPrivacyPolicyAssetPath] lewat rootBundle.
  final Future<String> Function()? policyLoader;

  @override
  State<PrivacyPolicyScreen> createState() => _PrivacyPolicyScreenState();
}

class _PrivacyPolicyScreenState extends State<PrivacyPolicyScreen> {
  String? _policy;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final String policy = await (widget.policyLoader?.call() ??
          rootBundle.loadString(kPrivacyPolicyAssetPath));
      if (!mounted) return;
      setState(() {
        _policy = policy;
        _failed = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _failed = true;
      });
    }
  }

  void _retry() {
    setState(() {
      _policy = null;
      _failed = false;
    });
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations strings = AppLocalizations.of(context)!;
    final ThemeData theme = Theme.of(context);
    final String? policy = _policy;
    return Scaffold(
      appBar: AppBar(title: Text(strings.privacyPolicyTitle)),
      body: _failed
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    const Icon(
                      Icons.description_outlined,
                      size: 48,
                      color: AppColors.textMuted,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      strings.privacyPolicyLoadFailed,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    FilledButton(
                      onPressed: _retry,
                      child: Text(strings.retry),
                    ),
                  ],
                ),
              ),
            )
          : policy == null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      const CircularProgressIndicator(),
                      const SizedBox(height: AppSpacing.md),
                      Text(
                        strings.privacyPolicyLoading,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: SelectableText(
                    policy,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: AppColors.textSecondary,
                      height: 1.5,
                    ),
                  ),
                ),
    );
  }
}
