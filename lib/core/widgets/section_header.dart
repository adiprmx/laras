/// Kepala seksi bersama: judul besar + keterangan opsional + aksi kanan
/// opsional (tombol putar, "Lihat semua").
///
/// Satu bahasa kepala seksi di beranda: judul 20 sp tebal memberi
/// hierarki yang terbaca sekilas; keterangan satu baris menjelaskan isi
/// seksi dengan bahasa sehari-hari; aksi kanan tidak pernah berupa teks
/// kecil yang mengambang tanpa kesejajaran (taste: no floating
/// top-right sub-text — keterangan selalu di bawah judul, aksi kanan
/// selalu berupa kontrol nyata).
library;

import 'package:flutter/material.dart';
import 'package:laras/core/theme/app_colors.dart';
import 'package:laras/core/theme/app_text_styles.dart';
import 'package:laras/core/theme/app_theme.dart';

class SectionHeader extends StatelessWidget {
  const SectionHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.trailing,
  });

  /// Judul seksi.
  final String title;

  /// Keterangan satu baris di bawah judul, null bila tidak ada.
  final String? subtitle;

  /// Kontrol di kanan judul (tombol putar / "Lihat semua").
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final String? subtitle = this.subtitle;
    final Widget? trailing = this.trailing;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: <Widget>[
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                title,
                style: AppTextStyles.section.copyWith(
                  color: AppColors.textPrimary,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              if (subtitle != null) ...<Widget>[
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: Theme.of(context).textTheme.bodySmall,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ],
          ),
        ),
        if (trailing != null) ...<Widget>[
          const SizedBox(width: AppSpacing.sm),
          trailing,
        ],
      ],
    );
  }
}
