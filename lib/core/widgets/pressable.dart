/// Pembungkus efek tekan: elemen mengecil sedikit saat jari menyentuh,
/// kembali saat dilepas.
///
/// Dipakai semua baris dan tombol kustom yang bisa diketuk (baris lagu,
/// kartu playlist, tombol putar bundar). Elemen yang [onTap]-nya null
/// tidak mendapat efek apa pun: kontrol yang tidak berfungsi tidak boleh
/// terlihat bisa ditekan.
library;

import 'package:flutter/material.dart';

class Pressable extends StatefulWidget {
  const Pressable({
    super.key,
    required this.child,
    this.onTap,
    this.scale = 0.97,
  });

  final Widget child;

  /// Aksi ketuk. Null berarti elemen tidak bisa ditekan (tanpa efek).
  final VoidCallback? onTap;

  /// Skala saat ditekan (1.0 = tidak berubah).
  final double scale;

  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (_pressed != value) setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    final VoidCallback? onTap = widget.onTap;
    final Widget animated = AnimatedScale(
      scale: _pressed ? widget.scale : 1.0,
      duration: const Duration(milliseconds: 100),
      curve: Curves.easeOut,
      child: widget.child,
    );
    if (onTap == null) return animated;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      onTapDown: (_) => _setPressed(true),
      onTapUp: (_) => _setPressed(false),
      onTapCancel: () => _setPressed(false),
      child: animated,
    );
  }
}
