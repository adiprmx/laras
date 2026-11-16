// Tes regresi P0-2: mode terdegradasi di TENGAH loop client.
//
// Lubang yang ditutup (16 Nov 2026): bila load script gagal di tengah
// loop — mis. hash player baru muncul saat load ulang di jalur cipher
// sesudah load awal berhasil — orkestrator lama `break` dari loop dan
// ANDROID_VR (client bebas-script) TIDAK PERNAH dicoba, walau VR tidak
// butuh script sama sekali. Perilaku benar: masuk mode terdegradasi
// (lewati client yang butuh script, tetap coba client bebas-script).
import 'package:flutter_test/flutter_test.dart';
import 'package:laras/extractor/extractor.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Innertube palsu: respons player yang diprogram per client.
class _FakeInnertube extends InnertubeClient {
  _FakeInnertube({required this.responses}) : super();

  final Map<String, Object> responses;
  final List<String> playerCalls = <String>[];

  @override
  Future<String?> ensureVisitorData(ClientDefinition client) async =>
      'vd-palsu';

  @override
  Future<String?> refreshVisitorData(ClientDefinition client) async =>
      'vd-segar';

  @override
  Future<ParsedPlayerResponse> fetchPlayer(
    String videoId,
    ClientDefinition client, {
    int? signatureTimestamp,
    String? visitorData,
  }) async {
    playerCalls.add(client.name);
    final Object? response = responses[client.name];
    if (response is ExtractorException) throw response;
    if (response is ParsedPlayerResponse) return response;
    throw const ExtractorException(ResolveFailureCause.emptyResponse);
  }
}

/// Solver palsu: mengembalikan URL final kalengan atau melempar.
class _FakeSolver implements SignatureSolver {
  int solveCalls = 0;
  ExtractorException? errorToThrow;

  @override
  Future<String> solve({
    required PlayerScript script,
    required AudioFormat format,
  }) async {
    solveCalls++;
    if (errorToThrow != null) throw errorToThrow!;
    return 'https://rr1---sn-palsu.googlevideo.com/videoplayback'
        '?itag=${format.itag}';
  }

  @override
  Future<void> dispose() async {}
}

/// Loader config palsu: urutan client yang diprogram.
class _FakeConfigLoader extends RemoteConfigLoader {
  _FakeConfigLoader({required this.config, required super.prefs});

  final RemotePlayerConfig config;

  @override
  Future<RemotePlayerConfig> current({bool forceRefresh = false}) async =>
      config;

  @override
  Future<RemotePlayerConfig> refresh({bool force = false}) async => config;
}

/// Loader script palsu: load() berhasil [succeedCalls] kali pertama,
/// lalu melempar [errorToThrow] di setiap panggilan berikutnya.
/// [succeedCalls] = 0 berarti selalu gagal (mode terdegradasi sejak awal).
class _FlakyScriptLoader extends PlayerScriptLoader {
  _FlakyScriptLoader({this.succeedCalls = 999999, this.errorToThrow})
    : super(client: InnertubeClient());

  final int succeedCalls;
  final ExtractorException? errorToThrow;
  int loadCalls = 0;

  static final PlayerScript dummy = PlayerScript(
    jsUrl: '/s/player/palsu/base.js',
    hash: 'palsu',
    signatureTimestamp: 1,
    source: '',
    sigCallSite: const SigCallSite(
      innerName: 'a',
      innerA: 1,
      innerB: 2,
      middleName: 'b',
      middleA: 3,
      middleB: 4,
      outerName: 'c',
      outerA: 5,
      outerB: 6,
      helperObjectName: 'h',
    ),
    preludeCode: '',
  );

  @override
  Future<PlayerScript> load({
    bool forceRefresh = false,
    Set<String>? allowedHashes,
  }) async {
    loadCalls++;
    if (loadCalls > succeedCalls && errorToThrow != null) {
      throw errorToThrow!;
    }
    return dummy;
  }
}

ParsedPlayerResponse _okResponse({bool cipher = true}) {
  return ParsedPlayerResponse(
    playability: Playability.ok,
    audioFormats: <AudioFormat>[
      if (cipher)
        const AudioFormat(
          itag: 251,
          mimeType: 'audio/webm; codecs="opus"',
          bitrate: 154822,
          cipheredSignature: 'cipher-palsu',
          cipherParamName: 'sig',
          cipherUrl: 'https://rr1---sn-palsu.googlevideo.com/videoplayback',
        )
      else
        const AudioFormat(
          itag: 251,
          mimeType: 'audio/webm; codecs="opus"',
          bitrate: 154822,
          url:
              'https://rr1---sn-palsu.googlevideo.com/videoplayback?langsung=1',
        ),
    ],
    title: 'Lagu Tes',
    lengthSeconds: 200,
  );
}

const ParsedPlayerResponse _loginRequiredResponse = ParsedPlayerResponse(
  playability: Playability.loginRequired,
  reason: 'Sign in to confirm you\u2019re not a bot',
  audioFormats: <AudioFormat>[],
);

const ExtractorException _unknownHashError = ExtractorException(
  ResolveFailureCause.unknownPlayerHash,
  detail: 'hash player baru muncul saat load ulang',
);

RemotePlayerConfig _configWith(List<ClientDefinition> clients) =>
    RemotePlayerConfig(
      clients: clients,
      playerHashes: const <String, int>{},
      canaryVideoIds: const <String>[],
      fetchedAt: DateTime.now(),
      isRemote: true,
    );

StreamResolver _makeResolver({
  required _FakeInnertube innertube,
  required _FakeSolver solver,
  required List<ClientDefinition> clients,
  required SharedPreferences prefs,
  required PlayerScriptLoader scriptLoader,
}) {
  return StreamResolver(
    innertube: innertube,
    solver: solver,
    configLoader: _FakeConfigLoader(
      config: _configWith(clients),
      prefs: prefs,
    ),
    scriptLoader: scriptLoader,
  );
}

Future<ExtractorException?> _resolveFails(
  StreamResolver resolver,
  String videoId,
) async {
  try {
    await resolver.resolve(videoId);
    return null;
  } on ExtractorException catch (e) {
    return e;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late SharedPreferences prefs;

  setUpAll(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    prefs = await SharedPreferences.getInstance();
  });

  group('P0-2: hash tak dikenal di tengah loop (bukan break, tapi degradasi)',
      () {
    test('load awal OK, load ulang cipher hash tak dikenal -> VR tetap '
        'dicoba dan berhasil', () async {
      final _FakeInnertube innertube = _FakeInnertube(
        responses: <String, Object>{
          'WEB_REMIX': _okResponse(cipher: true),
          'MWEB': _okResponse(cipher: true),
          'ANDROID_VR': _okResponse(cipher: false),
        },
      );
      final _FakeSolver solver = _FakeSolver();
      final StreamResolver resolver = _makeResolver(
        innertube: innertube,
        solver: solver,
        clients: const <ClientDefinition>[
          kWebRemixClient,
          kMwebClient,
          kAndroidVrClient,
        ],
        prefs: prefs,
        // Load #1 (awal, sts) berhasil; load #2 (jalur cipher WEB_REMIX)
        // melempar hash tak dikenal — simulasi rotasi player di tengah
        // satu resolve.
        scriptLoader: _FlakyScriptLoader(
          succeedCalls: 1,
          errorToThrow: _unknownHashError,
        ),
      );
      final ResolvedAudio result = await resolver.resolve('k2XdBPv0D3Y');
      expect(result.clientName, 'ANDROID_VR');
      expect(result.url, contains('langsung=1'));
      // MWEB dilewati (butuh script, mode terdegradasi); VR dicoba.
      expect(innertube.playerCalls, <String>['WEB_REMIX', 'ANDROID_VR']);
      // Solver tidak pernah tercapai: load gagal sebelum solve.
      expect(solver.solveCalls, 0);
      expect(
        resolver.recentLog
            .where((ResolveLogEntry e) => e.outcome.contains('LEWATI'))
            .map((ResolveLogEntry e) => e.clientName),
        <String>['MWEB'],
      );
    });

    test('hash tak dikenal di tengah loop + tanpa client bebas-script -> '
        'error hash, client berikutnya dilewati', () async {
      final _FakeInnertube innertube = _FakeInnertube(
        responses: <String, Object>{
          'WEB_REMIX': _okResponse(cipher: true),
          'MWEB': _okResponse(cipher: false),
        },
      );
      final StreamResolver resolver = _makeResolver(
        innertube: innertube,
        solver: _FakeSolver(),
        clients: const <ClientDefinition>[kWebRemixClient, kMwebClient],
        prefs: prefs,
        scriptLoader: _FlakyScriptLoader(
          succeedCalls: 1,
          errorToThrow: _unknownHashError,
        ),
      );
      final ExtractorException? caught = await _resolveFails(
        resolver,
        'k2XdBPv0D3Y',
      );
      expect(caught, isNotNull);
      expect(caught!.cause, ResolveFailureCause.unknownPlayerHash);
      // MWEB tidak dicoba: sesudah hash gagal, client butuh-script
      // dilewati (bukan dicoba lalu gagal dengan error menyesatkan).
      expect(innertube.playerCalls, <String>['WEB_REMIX']);
    });
  });

  group('P0-2: solver gagal total -> VR tetap menyelamatkan', () {
    test('solver timeout di WEB + MWEB -> VR URL langsung berhasil', () async {
      final _FakeInnertube innertube = _FakeInnertube(
        responses: <String, Object>{
          'WEB_REMIX': _okResponse(cipher: true),
          'MWEB': _okResponse(cipher: true),
          'ANDROID_VR': _okResponse(cipher: false),
        },
      );
      final _FakeSolver solver = _FakeSolver()
        ..errorToThrow = const ExtractorException(
          ResolveFailureCause.solverTimeout,
          detail: 'QuickJS error di perangkat',
        );
      final StreamResolver resolver = _makeResolver(
        innertube: innertube,
        solver: solver,
        clients: const <ClientDefinition>[
          kWebRemixClient,
          kMwebClient,
          kAndroidVrClient,
        ],
        prefs: prefs,
        scriptLoader: _FlakyScriptLoader(),
      );
      // Skenario HP: solver native bermasalah di perangkat — kedua
      // client web gagal di solver, tapi lagu tetap berbunyi via VR.
      final ResolvedAudio result = await resolver.resolve('k2XdBPv0D3Y');
      expect(result.clientName, 'ANDROID_VR');
      expect(solver.solveCalls, 2);
      expect(
        innertube.playerCalls,
        <String>['WEB_REMIX', 'MWEB', 'ANDROID_VR'],
      );
    });
  });

  group('P0-2: retry dalam mode terdegradasi tetap mencoba VR', () {
    test('script gagal + VR gagal, retry berikutnya tetap mencoba VR',
        () async {
      final _FakeInnertube innertube = _FakeInnertube(
        responses: <String, Object>{'ANDROID_VR': _loginRequiredResponse},
      );
      final StreamResolver resolver = _makeResolver(
        innertube: innertube,
        solver: _FakeSolver(),
        clients: const <ClientDefinition>[
          kWebRemixClient,
          kMwebClient,
          kAndroidVrClient,
        ],
        prefs: prefs,
        scriptLoader: _FlakyScriptLoader(
          succeedCalls: 0,
          errorToThrow: _unknownHashError,
        ),
      );
      // Resolve 1: hanya VR dicoba (2x karena retry LOGIN_REQUIRED).
      expect(await _resolveFails(resolver, 'k2XdBPv0D3Y'), isNotNull);
      expect(innertube.playerCalls, <String>['ANDROID_VR', 'ANDROID_VR']);
      // Resolve 2 (tombol "Coba lagi" / re-resolve): rotasi menggeser
      // urutan, tapi VR tetap dicoba — rotasi tidak boleh "memutar
      // pergi" satu-satunya client yang bisa jalan.
      innertube.playerCalls.clear();
      expect(await _resolveFails(resolver, 'k2XdBPv0D3Y'), isNotNull);
      expect(innertube.playerCalls, contains('ANDROID_VR'));
    });
  });

  group('P0-2 lanjutan (19:01 WIB): snapshot kegagalan terakhir + log '
      'terstruktur', () {
    test('semua client gagal -> snapshot berisi penyebab + upaya per '
        'client + kode diagnostik', () async {
      final _FakeInnertube innertube = _FakeInnertube(
        responses: <String, Object>{
          'WEB_REMIX': const ExtractorException(
            ResolveFailureCause.emptyResponse,
            isNetworkError: true,
            detail: 'jaringan putus',
          ),
          'MWEB': _loginRequiredResponse,
          'ANDROID_VR': _loginRequiredResponse,
        },
      );
      final StreamResolver resolver = _makeResolver(
        innertube: innertube,
        solver: _FakeSolver(),
        clients: const <ClientDefinition>[
          kWebRemixClient,
          kMwebClient,
          kAndroidVrClient,
        ],
        prefs: prefs,
        scriptLoader: _FlakyScriptLoader(),
      );
      expect(await _resolveFails(resolver, 'k2XdBPv0D3Y'), isNotNull);
      final ResolveFailureSnapshot? snapshot = resolver.lastFailure;
      expect(snapshot, isNotNull);
      expect(snapshot!.videoId, 'k2XdBPv0D3Y');
      // Penyebab akhir = non-jaringan terakhir (aturan orkestrator).
      expect(snapshot.cause, ResolveFailureCause.httpForbidden);
      expect(snapshot.isNetworkError, isFalse);
      // Upaya per client, sesuai urutan dicoba, dengan penyebab
      // terstruktur (bukan parse string outcome).
      expect(
        snapshot.attempts.map((ResolveLogEntry e) => e.clientName),
        <String>['WEB_REMIX', 'MWEB', 'ANDROID_VR'],
      );
      expect(snapshot.attempts[0].cause, ResolveFailureCause.emptyResponse);
      expect(snapshot.attempts[0].isNetworkError, isTrue);
      expect(snapshot.attempts[1].cause, ResolveFailureCause.httpForbidden);
      expect(snapshot.attempts[2].cause, ResolveFailureCause.httpForbidden);
      expect(
        snapshot.diagnosticCode,
        'R1/httpForbidden/NOVD/WEB_REMIX:emptyResponse/MWEB:httpForbidden/'
        'ANDROID_VR:httpForbidden',
      );
      // Fake tidak pernah menyimpan visitorData (ensureVisitorData
      // di-override tanpa menulis _visitorData) — NOVD di kode
      // membuktikan flag-nya terbaca.
      expect(snapshot.hadVisitorData, isFalse);
      // Kode tidak membawa videoId (data internal saja).
      expect(snapshot.diagnosticCode, isNot(contains('k2XdBPv0D3Y')));
      // Entri log yang sama juga ada di recentLog (jalur baca P6 kedua).
      expect(
        resolver.recentLog.last.cause,
        ResolveFailureCause.httpForbidden,
      );
    });

    test('script gagal + VR gagal -> snapshot memuat SCRIPT + LEWATI + VR',
        () async {
      final _FakeInnertube innertube = _FakeInnertube(
        responses: <String, Object>{'ANDROID_VR': _loginRequiredResponse},
      );
      final StreamResolver resolver = _makeResolver(
        innertube: innertube,
        solver: _FakeSolver(),
        clients: const <ClientDefinition>[
          kWebRemixClient,
          kMwebClient,
          kAndroidVrClient,
        ],
        prefs: prefs,
        scriptLoader: _FlakyScriptLoader(
          succeedCalls: 0,
          errorToThrow: _unknownHashError,
        ),
      );
      expect(await _resolveFails(resolver, 'k2XdBPv0D3Y'), isNotNull);
      final ResolveFailureSnapshot? snapshot = resolver.lastFailure;
      expect(snapshot, isNotNull);
      expect(
        snapshot!.attempts.map((ResolveLogEntry e) => e.clientName),
        <String>['SCRIPT', 'WEB_REMIX', 'MWEB', 'ANDROID_VR'],
      );
      expect(snapshot.attempts[0].cause, ResolveFailureCause.unknownPlayerHash);
      expect(snapshot.attempts[1].skipped, isTrue);
      expect(snapshot.attempts[1].cause, isNull);
      expect(snapshot.attempts[2].skipped, isTrue);
      expect(snapshot.attempts[3].cause, ResolveFailureCause.httpForbidden);
      expect(
        snapshot.diagnosticCode,
        'R1/httpForbidden/NOVD/SCRIPT:unknownPlayerHash/WEB_REMIX:SKIP/'
        'MWEB:SKIP/ANDROID_VR:httpForbidden',
      );
      expect(snapshot.hadVisitorData, isFalse);
    });

    test('resolve sukses sesudah gagal -> snapshot dibersihkan', () async {
      final _FakeInnertube innertube = _FakeInnertube(
        responses: <String, Object>{
          'WEB_REMIX': _loginRequiredResponse,
          'MWEB': _loginRequiredResponse,
          'ANDROID_VR': _loginRequiredResponse,
        },
      );
      final StreamResolver resolver = _makeResolver(
        innertube: innertube,
        solver: _FakeSolver(),
        clients: const <ClientDefinition>[
          kWebRemixClient,
          kMwebClient,
          kAndroidVrClient,
        ],
        prefs: prefs,
        scriptLoader: _FlakyScriptLoader(),
      );
      expect(await _resolveFails(resolver, 'k2XdBPv0D3Y'), isNotNull);
      expect(resolver.lastFailure, isNotNull);
      // Lagu lain sukses: tidak ada lagi kegagalan yang belum disusul
      // sukses.
      innertube.responses['WEB_REMIX'] = _okResponse(cipher: false);
      final ResolvedAudio result = await resolver.resolve('hhn-nGSuenM');
      expect(result.clientName, 'WEB_REMIX');
      expect(resolver.lastFailure, isNull);
    });
  });
}
