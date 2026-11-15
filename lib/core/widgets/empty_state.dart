import 'package:flutter/material.dart';
import 'package:laras/core/theme/app_colors.dart';
import 'package:laras/core/theme/app_theme.dart';

/// Empty state jujur: menyatakan apa yang belum ada dan satu langkah berikut.
///
/// Tidak pernah menampilkan data contoh. Tombol aksi hanya tampil bila ada
/// langkah berikut yang nyata.
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.body,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String body;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final String? actionLabel = this.actionLabel;
    final VoidCallback? onAction = this.onAction;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(icon, size: 48, color: AppColors.textMuted),
            const SizedBox(height: AppSpacing.md),
            Text(
              title,
              style: theme.textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              body,
              style: theme.textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            if (actionLabel != null && onAction != null) ...<Widget>[
              const SizedBox(height: AppSpacing.xl),
              ElevatedButton(
                onPressed: onAction,
                child: Text(actionLabel),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
