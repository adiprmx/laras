/// Batas ukuran respons jaringan + pembaca stream berbatas (R1-M3).
///
/// Rencana §3.3 mewajibkan batas ukuran respons supaya satu respons
/// raksasa dari server yang dikompromikan tidak menghabiskan memori app
/// (DoS lokal, pola OOM Spotube). Batas HARUS ditegakkan saat byte
/// mengalir (streaming), bukan setelah seluruh body terunduh: cek
/// pasca-download mencegah pemakaian data raksasa tapi tidak mencegah
/// kehabisan memori saat mengunduhnya (itu yang diperbaiki di sini).
library;

import 'dart:async';
import 'dart:typed_data';

import 'package:dio/dio.dart';

import 'errors.dart';

/// Batas ukuran respons jaringan (rencana §3.3).
class ResponseLimits {
  /// Respons JSON youtubei (player/search/browse/suggest): 10 MB.
  /// Respons normal jauh di bawah itu.
  static const int youtubeiJsonBytes = 10 * 1024 * 1024;

  /// base.js player: 8 MB (ukuran nyata ~2,7 MB).
  static const int playerScriptBytes = 8 * 1024 * 1024;

  /// Config remote player: 4 MB.
  static const int remoteConfigBytes = 4 * 1024 * 1024;

  /// HTML youtube.com (untuk jsUrl): 4 MB (ukuran nyata ~1 MB).
  static const int youtubeHtmlBytes = 4 * 1024 * 1024;
}

/// Penegak batas ukuran yang bekerja SAMA DENGAN pompa stream Dio.
///
/// Kenapa kelas ini ada (ditemukan saat menulis tes regresi R1-M3):
/// `handleResponseStream` Dio 5.11.1 men-subscribe stream sumber secara
/// EAGER dan memompa seluruh body ke StreamController internal begitu
/// header tiba — pembaca yang lambat tidak menghentikan pompa itu
/// (backpressure dari await-for tidak mencapai adapter). Akibatnya cap
/// di [readCappedResponseBody] saja tidak cukup: ia membatasi apa yang
/// dikumpulkan kode kita, tapi Dio sudah lebih dulu menampung seluruh
/// body raksasa di memorinya sendiri.
///
/// Mekanisme: [onReceiveProgress] dipanggil Dio per chunk yang ditarik
/// dari sumber. Begitu total yang ditarik melewati [maxBytes], token
/// dibatalkan — handler Dio menutup respons dan membatalkan subscription
/// sumber, jadi download BERHENTI (buffer Dio ≤ batas + 1 chunk).
/// Stream lalu error dengan DioException cancel; pemanggil memetakan
/// [exceeded] menjadi parseFailed lewat [throwIfExceeded].
///
/// Selalu dipakai BERPASANGAN dengan [readCappedResponseBody] (sabuk
/// kedua bila perilaku pompa Dio berubah di versi mendatang), dan
/// [checkContentLength] (tolak dini bila server mendeklarasikan ukuran
/// raksasa). Satu instance per percobaan request — token yang sudah
/// dibatalkan tidak bisa dipakai ulang.
class ResponseSizeCap {
  ResponseSizeCap(this.maxBytes);

  final int maxBytes;

  /// Token yang diteruskan ke pemanggilan Dio (`cancelToken:`).
  final CancelToken cancelToken = CancelToken();

  /// True begitu batas terlampaui (pembatalan sudah diminta).
  bool exceeded = false;

  /// Callback untuk `onReceiveProgress` Dio.
  void onReceiveProgress(int received, int total) {
    if (!exceeded && received > maxBytes) {
      exceeded = true;
      cancelToken.cancel('respons melebihi batas $maxBytes byte');
    }
  }

  /// Lempar parseFailed bila pembatalan ini disebabkan cap ini.
  /// Dipanggil pemanggil saat membaca stream melempar DioException
  /// (biasanya cancel dari token ini). No-op bila batas tidak terlampaui.
  void throwIfExceeded() {
    if (exceeded) {
      throw const ExtractorException(
        ResolveFailureCause.parseFailed,
        detail: 'respons melebihi batas ukuran',
      );
    }
  }
}

/// Baca seluruh [body] dengan batas ukuran.
///
/// Byte dibaca per chunk dan dihitung saat mengalir: begitu total
/// melewati [maxBytes], pembacaan dibatalkan dan melempar
/// [ExtractorException] parseFailed — respons raksasa tidak pernah utuh
/// di memori. Jeda antar chunk lebih lama dari [chunkTimeout] melempar
/// [DioException] receiveTimeout supaya pemanggil bisa me-retry seperti
/// timeout biasa (dengan ResponseType.stream, receiveTimeout Dio hanya
/// mengikat pengiriman header, bukan badan).
///
/// WAJIB dipakai berpasangan dengan [ResponseSizeCap] pada pemanggilan
/// Dio yang sama: tanpa cap, pompa eager Dio menampung seluruh body
/// sebelum pembacaan ini sempat berjalan (lihat doc [ResponseSizeCap]).
Future<Uint8List> readCappedResponseBody(
  ResponseBody body, {
  required RequestOptions requestOptions,
  required int maxBytes,
  required Duration chunkTimeout,
}) async {
  final BytesBuilder builder = BytesBuilder(copy: false);
  try {
    await for (final Uint8List chunk in body.stream.timeout(chunkTimeout)) {
      builder.add(chunk);
      if (builder.length > maxBytes) {
        throw const ExtractorException(
          ResolveFailureCause.parseFailed,
          detail: 'respons melebihi batas ukuran',
        );
      }
    }
  } on TimeoutException {
    throw DioException(
      requestOptions: requestOptions,
      type: DioExceptionType.receiveTimeout,
      error:
          'stream respons macet lebih dari ${chunkTimeout.inSeconds} detik',
    );
  }
  return builder.takeBytes();
}

/// Cek awal `Content-Length`: bila server mendeklarasikan ukuran di atas
/// [maxBytes], tolak tanpa membaca satu byte pun. Bukan pengganti batas
/// streaming (header bisa bohong) — hanya jalan pintas.
void checkContentLength(Response<ResponseBody> response, int maxBytes) {
  final String? declared = response.headers.value(
    Headers.contentLengthHeader,
  );
  final int? length = declared == null ? null : int.tryParse(declared);
  if (length != null && length > maxBytes) {
    throw const ExtractorException(
      ResolveFailureCause.parseFailed,
      detail: 'Content-Length melebihi batas ukuran',
    );
  }
}
