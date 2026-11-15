/// Kerangka muat statis: baris-baris abu yang meniru bentuk daftar lagu
/// selagi data dimuat dari database.
///
/// Sengaja statis (tanpa animasi berulang): animasi tanpa henti membuat
/// `pumpAndSettle()` di tes widget tidak pernah selesai. Bentuknya saja
/// sudah memberi tahu pengguna bahwa daftar sedang disiapkan, bukan
/// layar kosong.
library;

import 'package:flutter/material.dart';
import 'package:laras/core/theme/app_colors.dart';
import 'package:laras/core/theme/app_theme.dart';

class LoadingRows extends StatelessWidget {
  const LoadingRows({super.key, this.count = 5});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: List<Widget>.generate(count, (int index) {
        return Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.xs,
          ),
          child: Row(
            children: <Widget>[
              Container(
                width: 48,
                height: 48,
                decoration: const BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.all(
                    Radius.circular(AppRadius.coverSmall),
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Container(
                      width: 140,
                      height: 14,
                      decoration: const BoxDecoration(
                        color: AppColors.pressed,
                        borderRadius: BorderRadius.all(Radius.circular(4)),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xxs),
                    Container(
                      width: 90,
                      height: 12,
                      decoration: const BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.all(Radius.circular(4)),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      }),
    );
  }
}
