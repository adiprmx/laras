/// Masuk halus satu tembak: konten muncul dengan fade + geser naik kecil.
///
/// Dipakai seksi beranda dan halaman onboarding supaya layar terasa hidup
/// saat pertama tampil, tanpa animasi tanpa henti: animasi selesai dalam
/// 300 ms dan tidak pernah mengulang, jadi `pumpAndSettle()` di tes
/// widget tetap selesai (konvensi yang sama dengan [LoadingRows] statis).
///
/// [delay] memberi ritme berjenjang antar seksi (mis. seksi kedua
/// tertunda 60 ms dari yang pertama). Konten tetap ada di tree sejak
/// frame pertama (hanya transparan), jadi tes finder tidak bergantung
/// pada animasi.
library;

import 'package:flutter/material.dart';

class FadeIn extends StatefulWidget {
  const FadeIn({
    super.key,
    required this.child,
    this.delay = Duration.zero,
  });

  final Widget child;

  /// Jeda sebelum animasi mulai.
  final Duration delay;

  @override
  State<FadeIn> createState() => _FadeInState();
}

class _FadeInState extends State<FadeIn> {
  bool _visible = false;

  @override
  void initState() {
    super.initState();
    if (widget.delay == Duration.zero) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _visible = true);
      });
    } else {
      Future<void>.delayed(widget.delay).then((_) {
        if (mounted) setState(() => _visible = true);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Hormati pengaturan "kurangi gerakan" perangkat (taste §6.B):
    // bila animasi dimatikan sistem, konten langsung tampil utuh.
    if (MediaQuery.disableAnimationsOf(context)) return widget.child;
    return AnimatedOpacity(
      opacity: _visible ? 1.0 : 0.0,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
      child: AnimatedSlide(
        offset: _visible ? Offset.zero : const Offset(0, 0.04),
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
        child: widget.child,
      ),
    );
  }
}
