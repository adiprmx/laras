/// Pemetaan penyebab kegagalan resolve ke pesan pengguna.
///
/// Semua string berasal dari ARB (bahasa sehari-hari, tanpa jargon).
/// Pemetaan ini murni: tidak ada I/O, mudah diuji.
library;

import 'package:laras/extractor/errors.dart';
import 'package:laras/l10n/generated/app_localizations.dart';

/// Pesan untuk pengguna saat SEMUA client gagal dengan [cause].
///
/// Dipakai banner error pemutaran dan layar status layanan. Pesan tidak
/// pernah menyebut detail teknis (nama client, hash, atau URL).
String causeMessage(AppLocalizations strings, ResolveFailureCause cause) {
  switch (cause) {
    case ResolveFailureCause.httpForbidden:
      return strings.causeForbidden;
    case ResolveFailureCause.emptyResponse:
      return strings.causeEmptyResponse;
    case ResolveFailureCause.parseFailed:
      return strings.causeParseFailed;
    case ResolveFailureCause.sabrOnly:
      return strings.causeSabrOnly;
    case ResolveFailureCause.solverTimeout:
      return strings.causeSolverTimeout;
    case ResolveFailureCause.unknownPlayerHash:
      return strings.causeUnknownPlayerHash;
  }
}

/// Apakah [cause] kemungkinan besar teratasi dengan memeriksa pembaruan
/// (perbaikan config jarak jauh)?
///
/// Benar untuk penyebab "YouTube berubah" (parse/hash/format baru);
/// salah untuk penolakan sementara dan timeout yang biasanya pulih
/// sendiri dengan menunggu.
bool causeSuggestsUpdate(ResolveFailureCause cause) {
  switch (cause) {
    case ResolveFailureCause.parseFailed:
    case ResolveFailureCause.unknownPlayerHash:
    case ResolveFailureCause.sabrOnly:
      return true;
    case ResolveFailureCause.httpForbidden:
    case ResolveFailureCause.emptyResponse:
    case ResolveFailureCause.solverTimeout:
      return false;
  }
}

/// Varian satu baris [causeMessage] untuk mini-player (ruang hanya satu
/// baris teks; semua varian <= 25 karakter). Jenis gagal tetap terlihat
/// jelas di mini-player, bukan hanya di layar pemutar penuh.
String causeShortMessage(AppLocalizations strings, ResolveFailureCause cause) {
  switch (cause) {
    case ResolveFailureCause.httpForbidden:
      return strings.causeForbiddenShort;
    case ResolveFailureCause.emptyResponse:
      return strings.causeEmptyResponseShort;
    case ResolveFailureCause.parseFailed:
      return strings.causeParseFailedShort;
    case ResolveFailureCause.sabrOnly:
      return strings.causeSabrOnlyShort;
    case ResolveFailureCause.solverTimeout:
      return strings.causeSolverTimeoutShort;
    case ResolveFailureCause.unknownPlayerHash:
      return strings.causeUnknownPlayerHashShort;
  }
}
