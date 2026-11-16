/// Solver signature + n challenge: interface dan implementasi QuickJS.
///
/// Jalur yang dipakai (terbukti di Node, spike 2):
/// 1. Runtime QuickJS dievaluasi sekali dengan stub DOM + seluruh base.js
///    + prelude signature minimal (tabel string + 3 fungsi + helper).
/// 2. Tiap solve menjalankan driver: hitung signature dari cipher
///    (`LUAR(TENGAH(DALAM(s)))`), bangun URL lewat kelas URL internal
///    player (`new _yt_player.tf(cipherUrl, true)`), set parameter
///    signature, serialisasi (`gf()`) - serialisasi inilah yang
///    menjalankan transform `n`.
///
/// Batas SimpMusic (arsitektur 3.3, keputusan koordinator bagian 7):
/// memori 192 MiB, stack 256 KiB, timeout 10 detik, eksekusi serial, tanpa
/// callback host, tanpa fetch dari dalam JS.
///
/// Mesin: gg_quickjs 0.1.0 (QuickJS-ng 0.17.0) — menggantikan
/// quickjs_engine 0.1.7 (QuickJS-NG 0.14.0) yang rentan CVE-2026-120438 /
/// CVE-2026-120439 / CVE-2026-120440 (R1-H1; ketiganya diperbaiki di
/// 0.16.0). Timeout gg_quickjs BERFUNGSI (ditegakkan via interrupt handler
/// QuickJS-ng): evaluate yang melewati batas melempar JsInterruptedError
/// dan runtime tetap bisa dipakai. Isolate kill 10 detik di Dart
/// dipertahankan sebagai backstop (defense in depth) untuk kasus native
/// call yang nyangkut.
///
/// Stack 256 KiB adalah default gg_quickjs dan batas aman praktis:
/// README paket memperingatkan limit > 512 KiB bisa crash proses native
/// (stack isolate Dart ~1 MiB di 64-bit). Solver lama memakai 8 MiB di
/// quickjs_engine — nilai itu TIDAK aman di gg_quickjs, jangan dikembalikan.
///
/// Peringatan README gg_quickjs: QuickJS-ng tidak selalu pulih dari OOM
/// saat compile — eval setelah memori habis bisa crash proses. Mitigasi:
/// batas memori 192 MiB jauh di atas kebutuhan nyata solver (base.js
/// ~2,6 MB + prelude kecil), dan eksekusi serial satu runtime.
///
/// gg_quickjs mendukung Linux host (build hook mengompilasi QuickJS-ng
/// dari source dengan gcc), jadi tes solver bisa jalan di `flutter test`
/// bila native asset berhasil dibangun — tidak seperti quickjs_engine
/// yang tidak membawa lib native Linux.
library;

import 'dart:async';
import 'dart:isolate';

import 'package:gg_quickjs/gg_quickjs.dart';

import '../errors.dart';
import '../models.dart';
import '../url_allowlist.dart';
import 'player_script.dart';

/// Solver signature + n challenge: dari format cipher menjadi URL final.
abstract class SignatureSolver {
  /// Hitung URL final yang bisa diputar dari [format] cipher.
  ///
  /// [script] adalah script player yang sudah diekstrak (menyediakan
  /// sumber base.js + rantai signature). Melempar [ExtractorException]
  /// penyebab [ResolveFailureCause.solverTimeout] bila eksekusi melewati
  /// batas waktu, atau penyebab [ResolveFailureCause.unknownPlayerHash]
  /// bila script tidak bisa dipakai.
  Future<String> solve({
    required PlayerScript script,
    required AudioFormat format,
  });

  /// Bebaskan resource (matikan isolate pekerja).
  Future<void> dispose();
}

/// Batas SimpMusic untuk runtime QuickJS.
class QuickJsLimits {
  /// Memori maksimum runtime: 192 MiB.
  static const int memoryBytes = 192 * 1024 * 1024;

  /// Stack maksimum runtime: 256 KiB (default gg_quickjs).
  ///
  /// Jangan naikkan: README gg_quickjs memperingatkan limit > 512 KiB
  /// bisa crash proses native (stack isolate Dart ~1 MiB di 64-bit).
  static const int stackBytes = 256 * 1024;

  /// Timeout satu eksekusi (init maupun solve): 10 detik.
  static const Duration timeout = Duration(seconds: 10);
}

/// Implementasi [SignatureSolver] di atas gg_quickjs.
///
/// Satu isolate pekerja memegang satu runtime QuickJS; semua solve
/// dieksekusi serial lewat antrean Future di isolate utama.
class QuickJsSignatureSolver implements SignatureSolver {
  QuickJsSignatureSolver();

  Isolate? _isolate;
  SendPort? _workerPort;
  ReceivePort? _receivePort;
  StreamSubscription<dynamic>? _subscription;

  /// Antrean serial: solve berikutnya menunggu yang berjalan selesai.
  Future<void> _queue = Future<void>.value();

  /// Hash script yang sudah dimuat di runtime pekerja (null = belum init).
  String? _loadedHash;

  /// Completer untuk request yang sedang berjalan (hanya satu).
  Completer<String>? _pending;
  Timer? _pendingTimer;

  bool _disposed = false;

  @override
  Future<String> solve({
    required PlayerScript script,
    required AudioFormat format,
  }) {
    final String? cipherUrl = format.cipherUrl;
    final String? ciphered = format.cipheredSignature;
    final String sigParam = format.cipherParamName ?? 'sig';
    if (cipherUrl == null || ciphered == null) {
      throw const ExtractorException(
        ResolveFailureCause.parseFailed,
        detail: 'format tidak membawa signatureCipher lengkap',
      );
    }
    // Serial: rangkai ke antrean.
    final Future<String> job = _queue.then(
      (_) => _solveLocked(
        script: script,
        cipherUrl: cipherUrl,
        ciphered: ciphered,
        sigParam: sigParam,
      ),
    );
    // Antrean tidak boleh macet karena satu job gagal.
    _queue = job.then<void>((_) {}).catchError((_) {});
    return job;
  }

  Future<String> _solveLocked({
    required PlayerScript script,
    required String cipherUrl,
    required String ciphered,
    required String sigParam,
  }) async {
    if (_disposed) {
      throw const ExtractorException(
        ResolveFailureCause.solverTimeout,
        detail: 'solver sudah ditutup',
      );
    }
    await _ensureWorker();
    if (_loadedHash != script.hash) {
      await _requestInit(script);
      _loadedHash = script.hash;
    }
    final String driver = buildSolveDriver(
      script,
      cipherUrl: cipherUrl,
      cipheredS: ciphered,
      sigParam: sigParam,
    );
    final String result = await _requestSolve(driver);
    // R1-M1: hasil solver adalah URL dari JS jaringan — host-nya harus
    // googlevideo.com, bukan sekadar ber-skema https.
    if (result.isEmpty || !isAllowedStreamUrl(result)) {
      throw const ExtractorException(
        ResolveFailureCause.parseFailed,
        detail: 'solver mengembalikan URL di luar host yang diizinkan',
      );
    }
    return result;
  }

  Future<void> _ensureWorker() async {
    if (_isolate != null && _workerPort != null) return;
    _receivePort = ReceivePort();
    _isolate = await Isolate.spawn(
      _workerEntry,
      _receivePort!.sendPort,
      debugName: 'laras-quickjs-solver',
    );
    final Completer<SendPort> portCompleter = Completer<SendPort>();
    _subscription = _receivePort!.listen((dynamic message) {
      if (message is SendPort && !portCompleter.isCompleted) {
        portCompleter.complete(message);
        return;
      }
      if (message is List && message.length == 2) {
        final String type = message[0] as String;
        final String payload = message[1] as String;
        final Completer<String>? pending = _pending;
        if (pending == null || pending.isCompleted) return;
        _pendingTimer?.cancel();
        _pending = null;
        if (type == 'ok') {
          pending.complete(payload);
        } else {
          pending.completeError(
            ExtractorException(
              ResolveFailureCause.solverTimeout,
              detail: 'QuickJS error: $payload',
            ),
          );
        }
      }
    });
    _workerPort = await portCompleter.future.timeout(
      QuickJsLimits.timeout,
      onTimeout: () {
        throw const ExtractorException(
          ResolveFailureCause.solverTimeout,
          detail: 'isolate solver tidak merespons saat start',
        );
      },
    );
  }

  Future<void> _requestInit(PlayerScript script) async {
    final String initScript = buildSolverInitScript(script);
    await _request(<Object?>['init', initScript]);
  }

  Future<String> _requestSolve(String driver) => _request(<Object?>['solve', driver]);

  Future<String> _request(List<Object?> message) {
    final Completer<String> completer = Completer<String>();
    _pending = completer;
    _pendingTimer = Timer(QuickJsLimits.timeout, () {
      // Backstop: runtime gg_quickjs sendiri sudah melempar
      // JsInterruptedError bila evaluate melewati batas; timer ini hanya
      // berjaga bila native call nyangkut dan worker tidak merespons.
      // Matikan isolate supaya eksekusi JS yang nyangkut ikut mati.
      _killWorker();
      if (!completer.isCompleted) {
        completer.completeError(
          const ExtractorException(
            ResolveFailureCause.solverTimeout,
            detail: 'eksekusi QuickJS melewati 10 detik',
          ),
        );
      }
      _pending = null;
    });
    _workerPort!.send(message);
    return completer.future;
  }

  void _killWorker() {
    _pendingTimer?.cancel();
    _pendingTimer = null;
    _pending = null;
    _loadedHash = null;
    _workerPort = null;
    _subscription?.cancel();
    _subscription = null;
    _receivePort?.close();
    _receivePort = null;
    _isolate?.kill(priority: Isolate.immediate);
    _isolate = null;
  }

  @override
  Future<void> dispose() async {
    _disposed = true;
    _killWorker();
  }
}

/// Entry point isolate pekerja: memegang satu [JsRuntime].
///
/// Protokol pesan (List 2 elemen):
/// - `['init', skrip]` → jalankan stub + base.js + prelude; balas
///   `['ok', '']` atau `['error', pesan]`. Nilai penyelesaian skrip init
///   (undefined) tidak dipakai.
/// - `['solve', driver]` → jalankan driver, balas `['ok', url]` atau
///   `['error', pesan]`. Driver wajib mengembalikan String
///   (`__u.gf()`); nilai bukan string adalah error solver.
///
/// Tidak ada callback host yang didaftarkan (`registerFunction` tidak
/// pernah dipanggil) dan fetch tidak diaktifkan (tanpa `network` di
/// opsi): JS tidak bisa memanggil Dart dan tidak bisa mengakses jaringan.
/// Timer juga mati (default `timers: false`) dan tidak ada `console`.
void _workerEntry(SendPort mainPort) {
  final ReceivePort workerPort = ReceivePort();
  mainPort.send(workerPort.sendPort);
  JsRuntime? runtime;

  JsRuntime ensureRuntime() {
    return runtime ??= JsRuntime(
      options: JsRuntimeOptions(
        memoryLimit: QuickJsLimits.memoryBytes,
        maxStackSize: QuickJsLimits.stackBytes,
        // Timeout gg_quickjs BERFUNGSI (interrupt handler QuickJS-ng):
        // evaluate yang melewati batas melempar JsInterruptedError.
        // Isolate kill di isolate utama tetap dipertahankan sebagai
        // backstop bila native call nyangkut.
        timeout: QuickJsLimits.timeout,
      ),
    );
  }

  workerPort.listen((dynamic message) {
    if (message is! List || message.length != 2) return;
    final String type = message[0] as String;
    final String code = message[1] as String;
    try {
      final JsRuntime rt = ensureRuntime();
      final Object? result = rt.evaluate(code);
      if (type == 'init') {
        mainPort.send(<Object?>['ok', '']);
        return;
      }
      if (result is! String) {
        mainPort.send(<Object?>[
          'error',
          'driver solver mengembalikan nilai bukan string',
        ]);
        return;
      }
      mainPort.send(<Object?>['ok', result]);
    } catch (e) {
      mainPort.send(<Object?>['error', e.toString()]);
    }
  });
}
