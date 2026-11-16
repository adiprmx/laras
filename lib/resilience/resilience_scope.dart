/// Scope layanan ketahanan (P6).
///
/// Membawa layanan P6 ke seluruh widget tanpa mengubah konstruktor
/// setiap layar. Semua layanan nullable: widget test yang memompa
/// [LarasApp] tanpa scope menyembunyikan fitur terkait secara anggun
/// (tanpa tombol mati), bukan crash.
library;

import 'package:flutter/widgets.dart';

import 'package:laras/resilience/app_settings.dart';
import 'package:laras/resilience/connectivity.dart';
import 'package:laras/resilience/data_wipe.dart';
import 'package:laras/resilience/external_links.dart';
import 'package:laras/resilience/internal_log.dart';
import 'package:laras/resilience/service_status.dart';

/// InheritedWidget pembawa layanan ketahanan.
class ResilienceScope extends InheritedWidget {
  const ResilienceScope({
    super.key,
    required super.child,
    this.settings,
    this.serviceStatus,
    this.wifiGate,
    this.externalLinks,
    this.dataWipe,
    this.internalLog,
  });

  final AppSettings? settings;
  final ServiceStatusService? serviceStatus;
  final WifiGate? wifiGate;
  final ExternalLinks? externalLinks;
  final DataWipeService? dataWipe;
  final InternalLog? internalLog;

  static ResilienceScope? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<ResilienceScope>();

  static AppSettings? settingsOf(BuildContext context) =>
      maybeOf(context)?.settings;

  static ServiceStatusService? serviceStatusOf(BuildContext context) =>
      maybeOf(context)?.serviceStatus;

  static ExternalLinks? externalLinksOf(BuildContext context) =>
      maybeOf(context)?.externalLinks;

  static DataWipeService? dataWipeOf(BuildContext context) =>
      maybeOf(context)?.dataWipe;

  @override
  bool updateShouldNotify(ResilienceScope oldWidget) =>
      settings != oldWidget.settings ||
      serviceStatus != oldWidget.serviceStatus ||
      wifiGate != oldWidget.wifiGate ||
      externalLinks != oldWidget.externalLinks ||
      dataWipe != oldWidget.dataWipe ||
      internalLog != oldWidget.internalLog;
}
