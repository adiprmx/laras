/// Alur pengenalan (onboarding) pengguna baru (Rombak UI-2).
///
/// Empat halaman, sekali tampil saat pertama membuka app (orkestrasi
/// first-run di HomeShell: onboarding -> lembar kejujuran -> beranda).
/// Bisa dibuka lagi dari Pengaturan ("Lihat pengenalan lagi", P6) lewat
/// entri publik [OnboardingFlow.show].
///
/// Isi empat halaman (verdict owner 17:56 WIB + tambahan 18:56 WIB):
/// sambutan + penjelasan singkat (gratis, tanpa iklan, offline, tanpa
/// login/akun), fitur utama (cari, putar, unduh offline), tombol lewati,
/// dan SATU HALAMAN PENUH model unduh-dulu (halaman 4, terakhir):
/// lagu BUKAN bawaan aplikasi, pertama kali butuh internet, unduh
/// sekali saat online, setelah itu putar tanpa internet. Halaman 4
/// mencegah kesalahpahaman owner 18:56 WIB ("harus online?! percuma
/// dong! kan tujuan nya offline!") — ia halaman sendiri yang tidak
/// bisa terlewat (halaman terakhir sebelum tombol "Mulai
/// mendengarkan"), bukan teks kecil di sudut.
///
/// Desain (impeccable onboard: show, don't tell): tiap halaman dipimpin
/// sampul lagu kanari NYATA, bukan ilustrasi generik — halaman 1 kolase
/// 2x2 empat sampul (lagu adalah gambarnya), halaman 2 satu sampul besar
/// (metafora "sedang diputar" tanpa tombol palsu), halaman 3 sampul besar
/// + lencana unduh-selesai (bagian dari ilustrasi, bukan kontrol),
/// halaman 4 sampul besar + lencana panah-unduh (tindakan yang harus
/// dilakukan dulu: unduh saat online). Tidak ada tombol yang tidak
/// berfungsi: "Lanjut" menggeser halaman, "Lewati" menutup alur,
/// "Mulai mendengarkan" menutup alur ke beranda.
///
/// [OnboardingFlow.show] TIDAK menyentuh flag: HomeShell menandai
/// [kOnboardingShownKey] sesudah alur kembali (ditutup dengan cara apa
/// pun, termasuk tombol kembali sistem = lewati). Pemanggilan dari
/// Pengaturan tidak perlu logika flag.
library;

import 'package:flutter/material.dart';
import 'package:laras/core/theme/app_colors.dart';
import 'package:laras/core/theme/app_theme.dart';
import 'package:laras/core/widgets/album_cover.dart';
import 'package:laras/extractor/extractor.dart';
import 'package:laras/l10n/generated/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Kunci SharedPreferences: pengenalan sudah pernah tampil.
/// Kontrak dengan Tim P6 + koordinator (verdict owner 17:56 WIB).
const String kOnboardingShownKey = 'onboarding_shown_v1';

/// Apakah pengenalan sudah pernah tampil. Gagal baca dianggap belum
/// tampil (lebih aman menampilkan sekali lagi daripada tidak pernah
/// menampilkan).
Future<bool> isOnboardingShown() async {
  try {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getBool(kOnboardingShownKey) ?? false;
  } on Object {
    return false;
  }
}

/// Tandai pengenalan sudah tampil.
Future<void> markOnboardingShown() async {
  try {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setBool(kOnboardingShownKey, true);
  } on Object {
    // Gagal simpan bukan alasan crash: pengenalan sudah tampil, flag
    // akan ditandai lagi di pemanggilan berikutnya.
  }
}

/// Sampul lagu kanari ke-[index] sebagai URL thumbnail YouTube
/// (pola yang sama dengan beranda). Null bila daftar kanari lebih
/// pendek dari yang diharapkan — AlbumCover lalu menampilkan
/// placeholder not balok, bukan crash.
Uri? _canaryCoverUri(int index) {
  if (index < 0 || index >= kCanarySongs.length) return null;
  return Uri.parse(
    'https://i.ytimg.com/vi/${kCanarySongs[index].videoId}/hqdefault.jpg',
  );
}

/// Entri publik alur pengenalan.
class OnboardingFlow {
  const OnboardingFlow._();

  /// Tampilkan alur pengenalan dari [context].
  ///
  /// Future selesai setelah alur ditutup dengan cara apa pun (selesai,
  /// lewati, atau tombol kembali). TIDAK menandai flag — pemanggil
  /// (HomeShell) yang menandai sesudah future kembali.
  static Future<void> show(BuildContext context) {
    return Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (BuildContext context) => const _OnboardingScreen(),
      ),
    );
  }
}

class _OnboardingScreen extends StatefulWidget {
  const _OnboardingScreen();

  @override
  State<_OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<_OnboardingScreen> {
  static const int _pageCount = 4;

  final PageController _controller = PageController();
  int _page = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _close() => Navigator.of(context).pop();

  void _nextOrFinish() {
    if (_page == _pageCount - 1) {
      _close();
      return;
    }
    _controller.nextPage(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations strings = AppLocalizations.of(context)!;
    final bool lastPage = _page == _pageCount - 1;
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: <Widget>[
            // "Lewati" selalu terlihat di semua halaman (onboard: jangan
            // sembunyikan jalan keluar) — kanan atas, sejajar judul.
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: _close,
                child: Text(strings.skip),
              ),
            ),
            Expanded(
              child: PageView(
                controller: _controller,
                onPageChanged: (int index) {
                  setState(() => _page = index);
                },
                children: <Widget>[
                  _OnboardingPage(
                    key: const Key('onboarding-page-1'),
                    visual: const _CoverCollage(),
                    title: strings.onboardingTitle1,
                    body: strings.onboardingBody1,
                  ),
                  _OnboardingPage(
                    key: const Key('onboarding-page-2'),
                    visual: _LargeCover(
                      artUri: _canaryCoverUri(4),
                    ),
                    title: strings.onboardingTitle2,
                    body: strings.onboardingBody2,
                  ),
                  _OnboardingPage(
                    key: const Key('onboarding-page-3'),
                    visual: _LargeCover(
                      artUri: _canaryCoverUri(0),
                      badge: const _CoverBadge(icon: Icons.download_done),
                    ),
                    title: strings.onboardingTitle3,
                    body: strings.onboardingBody3,
                  ),
                  _OnboardingPage(
                    key: const Key('onboarding-page-4'),
                    visual: _LargeCover(
                      artUri: _canaryCoverUri(1),
                      badge: const _CoverBadge(icon: Icons.download),
                    ),
                    title: strings.onboardingTitle4,
                    body: strings.onboardingBody4,
                  ),
                ],
              ),
            ),
            // Titik halaman: yang aktif memanjang (pil), sisanya bulat.
            // Perubahan lebar beranimasi 200 ms (finite, tes-aman).
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List<Widget>.generate(_pageCount, (int index) {
                final bool active = index == _page;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeOut,
                  width: active ? 20 : 8,
                  height: 8,
                  margin: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.xxs,
                  ),
                  decoration: BoxDecoration(
                    color: active
                        ? AppColors.accent
                        : AppColors.textMuted,
                    borderRadius: const BorderRadius.all(
                      Radius.circular(4),
                    ),
                  ),
                );
              }),
            ),
            const SizedBox(height: AppSpacing.md),
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
              ),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _nextOrFinish,
                  child: Text(
                    lastPage ? strings.onboardingStart : strings.onboardingNext,
                  ),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
          ],
        ),
      ),
    );
  }
}

/// Satu halaman pengenalan: visual sampul + judul + isi.
///
/// Konten bisa di-scroll (SingleChildScrollView) supaya tidak overflow
/// di layar pendek: visual 200 dp + judul + isi muat di 640 dp, dan
/// layar yang lebih pendek menggulir, bukan memotong.
class _OnboardingPage extends StatelessWidget {
  const _OnboardingPage({
    super.key,
    required this.visual,
    required this.title,
    required this.body,
  });

  final Widget visual;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const SizedBox(height: AppSpacing.sm),
          Center(child: visual),
          const SizedBox(height: AppSpacing.xl),
          Text(title, style: theme.textTheme.displayLarge),
          const SizedBox(height: AppSpacing.sm),
          Text(
            body,
            style: theme.textTheme.bodyLarge?.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
        ],
      ),
    );
  }
}

/// Kolase 2x2 empat sampul kanari (halaman 1): lagu adalah gambarnya.
/// Empat sampul nyata terasa seperti koleksi, bukan satu ilustrasi.
class _CoverCollage extends StatelessWidget {
  const _CoverCollage();

  static const double _tile = 104;

  @override
  Widget build(BuildContext context) {
    Widget tile(int index) => AlbumCover(
      artUri: _canaryCoverUri(index),
      size: _tile,
      radius: AppRadius.coverLarge,
      memCacheWidth: 208,
    );
    return SizedBox(
      width: _tile * 2 + AppSpacing.xs,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              tile(0),
              const SizedBox(width: AppSpacing.xs),
              tile(1),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              tile(2),
              const SizedBox(width: AppSpacing.xs),
              tile(3),
            ],
          ),
        ],
      ),
    );
  }
}

/// Lencana lingkaran putih dengan satu ikon, menempel di sudut sampul
/// besar sebagai bagian ilustrasi (BUKAN kontrol — tidak bisa diketuk).
/// Ikonnya membedakan makna: download_done = sudah terunduh (halaman 3),
/// download = tindakan mengunduh yang harus dilakukan dulu (halaman 4).
class _CoverBadge extends StatelessWidget {
  const _CoverBadge({required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: AppSizes.touchTarget,
      height: AppSizes.touchTarget,
      decoration: const BoxDecoration(
        color: AppColors.accent,
        shape: BoxShape.circle,
      ),
      child: Icon(icon, color: AppColors.textOnAccent),
    );
  }
}

/// Satu sampul besar 200 dp dengan bayangan (halaman 2-4), bahasa yang
/// sama dengan sampul layar Player. [badge] opsional menempel di sudut
/// kanan bawah sebagai bagian ilustrasi (bukan kontrol).
class _LargeCover extends StatelessWidget {
  const _LargeCover({this.artUri, this.badge});

  final Uri? artUri;
  final Widget? badge;

  static const double _size = 200;

  @override
  Widget build(BuildContext context) {
    final Widget? badge = this.badge;
    final Widget cover = Container(
      decoration: const BoxDecoration(
        borderRadius: BorderRadius.all(
          Radius.circular(AppRadius.heroCard),
        ),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Color(0x66000000),
            blurRadius: 24,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: AlbumCover(
        artUri: artUri,
        size: _size,
        radius: AppRadius.heroCard,
        iconSize: 64,
        memCacheWidth: 400,
      ),
    );
    if (badge == null) return cover;
    return Stack(
      clipBehavior: Clip.none,
      children: <Widget>[
        cover,
        Positioned(right: -8, bottom: -8, child: badge),
      ],
    );
  }
}
