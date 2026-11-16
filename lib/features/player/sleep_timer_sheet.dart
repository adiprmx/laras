/// Lembar pemilih timer tidur (P7): preset menit, waktu lain (slider),
/// dan mode "sesudah lagu ini habis".
///
/// Bila timer sedang aktif, bagian atas lembar menampilkan statusnya
/// (hitung mundur yang bergerak, atau mode akhir-lagu) + tombol
/// mematikan. Mengetuk pilihan langsung memulai timer itu dan menutup
/// lembar — tanpa tombol konfirmasi tambahan.
library;

import 'package:flutter/material.dart';
import 'package:laras/core/theme/app_colors.dart';
import 'package:laras/core/theme/app_theme.dart';
import 'package:laras/l10n/generated/app_localizations.dart';
import 'package:laras/player/sleep_timer.dart';

/// Lembar bawah timer tidur. Dibuka lewat [SleepTimerSheet.show].
class SleepTimerSheet extends StatefulWidget {
  const SleepTimerSheet({super.key, required this.service});

  /// Buka lembar pemilih timer tidur.
  static Future<void> show(
    BuildContext context, {
    required SleepTimerService service,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.elevated,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppRadius.sheet),
        ),
      ),
      builder: (BuildContext sheetContext) {
        return SleepTimerSheet(service: service);
      },
    );
  }

  final SleepTimerService service;

  @override
  State<SleepTimerSheet> createState() => _SleepTimerSheetState();
}

class _SleepTimerSheetState extends State<SleepTimerSheet> {
  double _customMinutes = 30;

  /// Sisa waktu dibulatkan ke atas dalam menit (paling kecil 1).
  static int _ceilMinutes(Duration remaining) {
    final int minutes = (remaining.inSeconds + 59) ~/ 60;
    return minutes < 1 ? 1 : minutes;
  }

  void _startTimed(int minutes) {
    widget.service.startTimed(Duration(minutes: minutes));
    Navigator.of(context).maybePop();
  }

  void _startAfterSong() {
    widget.service.startAfterSong();
    Navigator.of(context).maybePop();
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations strings = AppLocalizations.of(context)!;
    final ThemeData theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  strings.sleepTimer,
                  style: theme.textTheme.titleMedium,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close),
                tooltip: strings.close,
                onPressed: () => Navigator.of(context).maybePop(),
              ),
            ],
          ),
          ValueListenableBuilder<SleepTimerMode?>(
            valueListenable: widget.service.mode,
            builder:
                (
                  BuildContext context,
                  SleepTimerMode? mode,
                  Widget? child,
                ) {
                  if (mode == null) return const SizedBox.shrink();
                  return Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.md),
                    child: Container(
                      decoration: const BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.all(
                          Radius.circular(AppRadius.card),
                        ),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.md,
                        vertical: AppSpacing.sm,
                      ),
                      child: Row(
                        children: <Widget>[
                          const Icon(
                            Icons.bedtime_outlined,
                            color: AppColors.textSecondary,
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Expanded(
                            child: mode == SleepTimerMode.afterSong
                                ? Text(
                                    strings.sleepTimerStopsAfterSong,
                                    style: theme.textTheme.bodyMedium,
                                  )
                                : ValueListenableBuilder<Duration?>(
                                    valueListenable:
                                        widget.service.remaining,
                                    builder:
                                        (
                                          BuildContext context,
                                          Duration? remaining,
                                          Widget? child,
                                        ) {
                                          final Duration left =
                                              remaining ?? Duration.zero;
                                          return Text(
                                            strings.sleepTimerStopsIn(
                                              _ceilMinutes(left),
                                            ),
                                            style: theme.textTheme.bodyMedium,
                                          );
                                        },
                                  ),
                          ),
                          TextButton(
                            onPressed: () {
                              widget.service.cancel();
                              Navigator.of(context).maybePop();
                            },
                            child: Text(strings.sleepTimerOff),
                          ),
                        ],
                      ),
                    ),
                  );
                },
          ),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: kSleepTimerPresets.map((int minutes) {
              return ActionChip(
                label: Text(strings.sleepTimerMinutes(minutes)),
                onPressed: () => _startTimed(minutes),
              );
            }).toList(growable: false),
          ),
          const SizedBox(height: AppSpacing.sm),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(
              Icons.music_note_outlined,
              color: AppColors.textSecondary,
            ),
            title: Text(strings.sleepTimerAfterSong),
            trailing: const Icon(
              Icons.chevron_right,
              color: AppColors.textMuted,
            ),
            onTap: _startAfterSong,
          ),
          const Divider(color: AppColors.hairline),
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  strings.sleepTimerCustom,
                  style: theme.textTheme.titleSmall,
                ),
              ),
              Text(
                strings.sleepTimerMinutes(_customMinutes.round()),
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontFeatures: const <FontFeature>[
                    FontFeature.tabularFigures(),
                  ],
                ),
              ),
            ],
          ),
          Row(
            children: <Widget>[
              Text(
                strings.sleepTimerMinutes(kSleepTimerMinMinutes),
                style: theme.textTheme.bodySmall,
              ),
              Expanded(
                child: Slider(
                  value: _customMinutes,
                  min: kSleepTimerMinMinutes.toDouble(),
                  max: kSleepTimerMaxMinutes.toDouble(),
                  divisions:
                      kSleepTimerMaxMinutes - kSleepTimerMinMinutes,
                  label: strings.sleepTimerMinutes(_customMinutes.round()),
                  onChanged: (double value) {
                    setState(() => _customMinutes = value);
                  },
                  onChangeEnd: (double value) {
                    _startTimed(value.round());
                  },
                ),
              ),
              Text(
                strings.sleepTimerMinutes(kSleepTimerMaxMinutes),
                style: theme.textTheme.bodySmall,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
        ],
      ),
    );
  }
}
