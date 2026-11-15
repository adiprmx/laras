/// Layar "Segera hadir" yang dirancang: ikon dalam lingkaran permukaan,
/// judul, dan satu kalimat jujur yang hangat.
///
/// Dipakai tab Cari (pencarian online datang di P4) dan tab Unduhan
/// (unduhan datang di P5). Sengaja tanpa tombol apa pun: tidak ada aksi
/// yang bisa dilakukan di sini, jadi tidak ada kontrol yang pura-pura
/// bisa ditekan.
library;

import 'package:flutter/material.dart';
import 'package:laras/core/theme/app_colors.dart';
import 'package:laras/core/theme/app_theme.dart';

class ComingSoonScreen extends StatelessWidget {
  const ComingSoonScreen({
    super.key,
    required this.icon,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Container(
              width: 88,
              height: 88,
              decoration: const BoxDecoration(
                color: AppColors.surface,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 40, color: AppColors.textSecondary),
            ),
            const SizedBox(height: AppSpacing.xl),
            Text(
              title,
              style: theme.textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              body,
              style: theme.textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
