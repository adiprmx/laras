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
/// memori 192 MiB, stack 8 MiB, timeout 10 detik, eksekusi serial, tanpa
/// callback host, tanpa fetch dari dalam JS.
///
/// CATATAN PENTING (temuan spike, diverifikasi di source quickjs_engine
/// 0.1.7): parameter `timeout` di konstruktor `QuickJsRuntime2` TIDAK
/// BERFUNGSI - sisi Dart meneruskan timeout ke fungsi native
/// `jsNewRuntime`, tapi implementasi C-nya hanya menerima channel dan tidak
/// memasang interrupt handler sama sekali. Karena itu timeout 10 detik
/// ditegakkan di Dart: runtime hidup di isolate pekerja, dan bila satu
/// solve melewati 10 detik, isolate dimatikan paksa lalu dibuat ulang
/// (runtime berikutnya diinisialisasi ulang). Batas memori dan stack
/// ditegakkan native (`JS_SetMemoryLimit`, `JS_SetMaxStackSize`) dan
/// berfungsi.
///
/// Runtime QuickJS tidak bisa dites di `flutter test` host Linux (paket
/// tidak membawa lib native Linux; lib hanya dibangun untuk Android/iOS).
/// Logika murni (ekstraksi, prelude, driver) dites tanpa QuickJS; wiring
/// QuickJS diverifikasi lewat build CI + APK demo di perangkat owner.
library;

import 'dart:async';
import 'dart:isolate';

import 'package:quickjs_engine/quickjs_engine.dart';

import '../errors.dart';
import '../models.dart';
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

  /// Stack maksimum runtime: 8 MiB.
  static const int stackBytes = 8 * 1024 * 1024;

  /// Timeout satu eksekusi (init maupun solve): 10 detik.
  static const Duration timeout = Duration(seconds: 10);
}

/// Implementasi [SignatureSolver] di atas quickjs_engine.
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
    if (result.isEmpty || !result.startsWith('https://')) {
      throw const ExtractorException(
        ResolveFailureCause.parseFailed,
        detail: 'solver mengembalikan bukan URL',
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
      // Timeout ditegakkan di sini (bukan oleh runtime): matikan isolate
      // supaya eksekusi JS yang nyangkut ikut mati.
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

/// Entry point isolate pekerja: memegang satu [QuickJsRuntime2].
///
/// Protokol pesan (List 2 elemen):
/// - `['init', skrip]` → jalankan stub + base.js + prelude; balas
///   `['ok', '']` atau `['error', pesan]`.
/// - `['solve', driver]` → jalankan driver, balas `['ok', url]` atau
///   `['error', pesan]`.
///
/// Tidak ada callback host yang didaftarkan (`setupBridge` tidak pernah
/// dipanggil) dan fetch tidak diaktifkan: JS tidak bisa memanggil Dart dan
/// tidak bisa mengakses jaringan.
void _workerEntry(SendPort mainPort) {
  final ReceivePort workerPort = ReceivePort();
  mainPort.send(workerPort.sendPort);
  QuickJsRuntime2? runtime;

  QuickJsRuntime2 ensureRuntime() {
    return runtime ??= QuickJsRuntime2(
      stackSize: QuickJsLimits.stackBytes,
      memoryLimit: QuickJsLimits.memoryBytes,
      // timeout konstruktor TIDAK berfungsi (lihat catatan di atas);
      // timeout ditegakkan isolate utama dengan mematikan isolate ini.
      timeout: QuickJsLimits.timeout.inMilliseconds,
    );
  }

  workerPort.listen((dynamic message) {
    if (message is! List || message.length != 2) return;
    // Elemen pertama adalah tipe ('init'/'solve'); keduanya dievaluasi
    // dengan cara yang sama, jadi tipenya tidak dipakai di sini.
    final String code = message[1] as String;
    try {
      final QuickJsRuntime2 rt = ensureRuntime();
      final JsEvalResult result = rt.evaluate(code);
      if (result.isError) {
        mainPort.send(<Object?>['error', result.stringResult]);
        return;
      }
      mainPort.send(<Object?>['ok', result.stringResult]);
    } catch (e) {
      mainPort.send(<Object?>['error', e.toString()]);
    }
  });
}
