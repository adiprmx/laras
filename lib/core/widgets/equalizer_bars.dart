/// Penanda "sedang berbunyi": tiga batang vertikal setinggi berbeda,
/// seperti equalizer yang dibekukan di satu momen.
///
/// Sengaja statis, bukan animasi berulang: animasi tanpa henti membuat
/// `pumpAndSettle()` di tes widget tidak pernah selesai (konvensi yang
/// sama dengan [LoadingRows] statis). Bentuknya saja sudah membedakan
/// lagu yang berbunyi dari lagu yang diam; status putar yang bergerak
/// ditunjukkan progres mini-player dan ikon jeda, bukan di sini.
library;

import 'package:flutter/material.dart';
import 'package:laras/core/theme/app_colors.dart';

class EqualizerBars extends StatelessWidget {
  const EqualizerBars({super.key, this.color = AppColors.textPrimary});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 14,
      height: 14,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: <Widget>[
          _bar(6),
          const SizedBox(width: 2),
          _bar(14),
          const SizedBox(width: 2),
          _bar(9),
        ],
      ),
    );
  }

  Widget _bar(double height) {
    return Container(
      width: 3,
      height: height,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(1.5),
      ),
    );
  }
}
