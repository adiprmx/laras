/// Versi aplikasi sebagai konstanta.
///
/// Sengaja TIDAK memakai package_info_plus (nol dependensi baru, P6):
/// nilai ini disinkronkan manual dengan `version:` di pubspec.yaml
/// setiap kali versi naik. Dipakai layar Tentang dan email laporan
/// kerusakan.
library;

/// Versi aplikasi (tanpa build number), sinkron dengan pubspec.yaml.
const String kAppVersion = '0.9.0';

/// Build number, sinkron dengan pubspec.yaml.
const int kAppBuild = 1;
