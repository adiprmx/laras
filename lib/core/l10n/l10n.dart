/// Lokalisasi Laras.
///
/// String UI tinggal di `lib/l10n/app_id.arb` (template, Bahasa Indonesia).
/// `flutter gen-l10n` (jalan otomatis saat `flutter pub get`, `flutter run`,
/// dan `flutter test` karena `generate: true` di pubspec) menghasilkan kode
/// ke `lib/l10n/generated/`. File hasil generate tidak masuk repo.
///
/// Widget memakai string lewat `AppLocalizations.of(context)`, tidak pernah
/// hardcode. Bahasa Inggris pasca-v1 hanya menambah satu file ARB
/// (`app_en.arb`) dan satu locale di `supportedLocales`, tanpa mengubah
/// kode tampilan.
library;
