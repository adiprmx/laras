import 'package:flutter_test/flutter_test.dart';
import 'package:laras/extractor/extractor.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Innertube palsu: respons player yang diprogram per client.
class FakeInnertube extends InnertubeClient {
  FakeInnertube({required this.responses}) : super();

  /// clientName -> hasil fetchPlayer (ParsedPlayerResponse atau
  /// ExtractorException untuk dilempar).
  final Map<String, Object> responses;
  final List<String> playerCalls = <String>[];
  int visitorDataRefreshes = 0;

  @override
  Future<String?> ensureVisitorData(ClientDefinition client) async => 'vd-palsu';

  @override
  Future<String?> refreshVisitorData(ClientDefinition client) async {
    visitorDataRefreshes++;
    return 'vd-segar';
  }

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

/// Solver palsu: mengembalikan URL final kalengan.
class FakeSolver implements SignatureSolver {
  int solveCalls = 0;
  ExtractorException? errorToThrow;

  @override
  Future<String> solve({
    required PlayerScript script,
    required AudioFormat format,
  }) async {
    solveCalls++;
    if (errorToThrow != null) throw errorToThrow!;
    return 'https://rr1---sn-palsu.googlevideo.com/videoplayback?itag=${format.itag}';
  }

  @override
  Future<void> dispose() async {}
}

/// Loader config palsu: mengembalikan urutan client yang diprogram.
class FakeConfigLoader extends RemoteConfigLoader {
  FakeConfigLoader({required this.config, required super.prefs});

  final RemotePlayerConfig config;

  @override
  Future<RemotePlayerConfig> current({bool forceRefresh = false}) async =>
      config;

  @override
  Future<RemotePlayerConfig> refresh({bool force = false}) async => config;
}

/// Loader script palsu: mengembalikan script dummy.
class FakeScriptLoader extends PlayerScriptLoader {
  FakeScriptLoader() : super(client: InnertubeClient());

  /// Bila diisi, load() melempar error ini (simulasi gagal memuat script).
  ExtractorException? errorToThrow;

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
  Future<PlayerScript> load({bool forceRefresh = false}) async {
    if (errorToThrow != null) throw errorToThrow!;
    return dummy;
  }
}

ParsedPlayerResponse okResponse({bool cipher = true, bool sabrOnly = false}) {
  return ParsedPlayerResponse(
    playability: Playability.ok,
    audioFormats: <AudioFormat>[
      if (sabrOnly)
        const AudioFormat(
          itag: 251,
          mimeType: 'audio/webm; codecs="opus"',
          bitrate: 154822,
          isSabr: true,
        )
      else if (cipher)
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
          url: 'https://rr1---sn-palsu.googlevideo.com/videoplayback?langsung=1',
        ),
    ],
    title: 'Lagu Tes',
    lengthSeconds: 200,
  );
}

const ParsedPlayerResponse loginRequiredResponse = ParsedPlayerResponse(
  playability: Playability.loginRequired,
  reason: 'Sign in to confirm you\u2019re not a bot',
  audioFormats: <AudioFormat>[],
);

RemotePlayerConfig configWith(List<ClientDefinition> clients) =>
    RemotePlayerConfig(
      clients: clients,
      playerHashes: const <String, int>{},
      canaryVideoIds: const <String>[],
      fetchedAt: DateTime.now(),
      isRemote: true,
    );

StreamResolver makeResolver({
  required FakeInnertube innertube,
  required FakeSolver solver,
  required List<ClientDefinition> clients,
  required SharedPreferences prefs,
  PlayerScriptLoader? scriptLoader,
}) {
  return StreamResolver(
    innertube: innertube,
    solver: solver,
    configLoader: FakeConfigLoader(config: configWith(clients), prefs: prefs),
    scriptLoader: scriptLoader ?? FakeScriptLoader(),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late SharedPreferences prefs;

  setUpAll(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    prefs = await SharedPreferences.getInstance();
  });

  group('StreamResolver fallback', () {
    test('client utama OK -> selesai tanpa fallback', () async {
      final FakeInnertube innertube = FakeInnertube(
        responses: <String, Object>{'WEB_REMIX': okResponse(cipher: false)},
      );
      final FakeSolver solver = FakeSolver();
      final StreamResolver resolver = makeResolver(
        innertube: innertube,
        solver: solver,
        clients: const <ClientDefinition>[kWebRemixClient, kMwebClient],
        prefs: prefs,
      );
      final ResolvedAudio result = await resolver.resolve('hhn-nGSuenM');
      expect(result.clientName, 'WEB_REMIX');
      expect(result.itag, 251);
      expect(innertube.playerCalls, <String>['WEB_REMIX']);
      expect(solver.solveCalls, 0);
      expect(resolver.recentLog.length, 1);
      expect(resolver.recentLog.first.outcome, contains('OK'));
    });

    test('client utama LOGIN_REQUIRED -> pindah ke MWEB', () async {
      final FakeInnertube innertube = FakeInnertube(
        responses: <String, Object>{
          'WEB_REMIX': loginRequiredResponse,
          'MWEB': okResponse(cipher: false),
        },
      );
      final StreamResolver resolver = makeResolver(
        innertube: innertube,
        solver: FakeSolver(),
        clients: const <ClientDefinition>[kWebRemixClient, kMwebClient],
        prefs: prefs,
      );
      final ResolvedAudio result = await resolver.resolve('hhn-nGSuenM');
      expect(result.clientName, 'MWEB');
      // WEB_REMIX dicoba 2x (awal + sesudah refresh visitorData), lalu MWEB.
      expect(
        innertube.playerCalls,
        <String>['WEB_REMIX', 'WEB_REMIX', 'MWEB'],
      );
      expect(innertube.visitorDataRefreshes, 1);
    });

    test('client utama SABR-only -> pindah ke MWEB', () async {
      final FakeInnertube innertube = FakeInnertube(
        responses: <String, Object>{
          'WEB_REMIX': okResponse(sabrOnly: true),
          'MWEB': okResponse(cipher: false),
        },
      );
      final StreamResolver resolver = makeResolver(
        innertube: innertube,
        solver: FakeSolver(),
        clients: const <ClientDefinition>[kWebRemixClient, kMwebClient],
        prefs: prefs,
      );
      final ResolvedAudio result = await resolver.resolve('hhn-nGSuenM');
      expect(result.clientName, 'MWEB');
    });

    test('format cipher -> solver dipanggil sekali', () async {
      final FakeInnertube innertube = FakeInnertube(
        responses: <String, Object>{'WEB_REMIX': okResponse(cipher: true)},
      );
      final FakeSolver solver = FakeSolver();
      final StreamResolver resolver = makeResolver(
        innertube: innertube,
        solver: solver,
        clients: const <ClientDefinition>[kWebRemixClient],
        prefs: prefs,
      );
      final ResolvedAudio result = await resolver.resolve('hhn-nGSuenM');
      expect(result.url, contains('itag=251'));
      expect(solver.solveCalls, 1);
    });

    test('semua client gagal -> lempar penyebab non-jaringan terakhir', () async {
      final FakeInnertube innertube = FakeInnertube(
        responses: <String, Object>{
          'WEB_REMIX': const ExtractorException(
            ResolveFailureCause.emptyResponse,
            isNetworkError: true,
          ),
          'MWEB': loginRequiredResponse,
        },
      );
      final StreamResolver resolver = makeResolver(
        innertube: innertube,
        solver: FakeSolver(),
        clients: const <ClientDefinition>[kWebRemixClient, kMwebClient],
        prefs: prefs,
      );
      // Tangkap dengan try/catch eksplisit (bukan expectLater+throwsA):
      // expectLater di flutter_test melaporkan error Future ini sebagai
      // unhandled walau matcher cocok - try/catch tidak.
      ExtractorException? caught;
      try {
        await resolver.resolve('hhn-nGSuenM');
        fail('resolve seharusnya melempar');
      } on ExtractorException catch (e) {
        caught = e;
      }
      expect(caught, isNotNull);
      expect(caught.cause, ResolveFailureCause.httpForbidden);
      expect(caught.isNetworkError, isFalse);
    });

    test('single-flight: dua resolve bersamaan -> satu panggilan player', () async {
      final FakeInnertube innertube = FakeInnertube(
        responses: <String, Object>{'WEB_REMIX': okResponse(cipher: false)},
      );
      final StreamResolver resolver = makeResolver(
        innertube: innertube,
        solver: FakeSolver(),
        clients: const <ClientDefinition>[kWebRemixClient],
        prefs: prefs,
      );
      final List<ResolvedAudio> results = await Future.wait(<Future<ResolvedAudio>>[
        resolver.resolve('hhn-nGSuenM'),
        resolver.resolve('hhn-nGSuenM'),
      ]);
      expect(results.length, 2);
      expect(innertube.playerCalls, <String>['WEB_REMIX']);
    });

    test('ANDROID_VR cadangan kedua: URL langsung, solver tidak dipanggil (P0)', () async {
      final FakeInnertube innertube = FakeInnertube(
        responses: <String, Object>{
          'WEB_REMIX': loginRequiredResponse,
          'MWEB': loginRequiredResponse,
          'ANDROID_VR': okResponse(cipher: false),
        },
      );
      final FakeSolver solver = FakeSolver();
      final StreamResolver resolver = makeResolver(
        innertube: innertube,
        solver: solver,
        clients: const <ClientDefinition>[
          kWebRemixClient,
          kMwebClient,
          kAndroidVrClient,
        ],
        prefs: prefs,
      );
      final ResolvedAudio result = await resolver.resolve('k2XdBPv0D3Y');
      expect(result.clientName, 'ANDROID_VR');
      expect(result.url, contains('langsung=1'));
      // URL langsung: tidak ada cipher yang perlu dipecahkan.
      expect(solver.solveCalls, 0);
      expect(innertube.playerCalls.last, 'ANDROID_VR');
    });

    test('waktu resolve diukur', () async {
      final FakeInnertube innertube = FakeInnertube(
        responses: <String, Object>{'WEB_REMIX': okResponse(cipher: false)},
      );
      final StreamResolver resolver = makeResolver(
        innertube: innertube,
        solver: FakeSolver(),
        clients: const <ClientDefinition>[kWebRemixClient],
        prefs: prefs,
      );
      final ResolvedAudio result = await resolver.resolve('hhn-nGSuenM');
      expect(result.resolveDuration.inMilliseconds, greaterThanOrEqualTo(0));
    });
  });

  group('StreamResolver rotasi client (P0)', () {
    /// Kedua client gagal total: WEB_REMIX error jaringan (1 panggilan),
    /// MWEB LOGIN_REQUIRED (2 panggilan: awal + sesudah refresh vd).
    FakeInnertube failingInnertube() => FakeInnertube(
      responses: <String, Object>{
        'WEB_REMIX': const ExtractorException(
          ResolveFailureCause.emptyResponse,
          isNetworkError: true,
        ),
        'MWEB': loginRequiredResponse,
      },
    );

    Future<ExtractorException?> resolveFails(
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

    test('kegagalan total menggeser client awal ke berikutnya', () async {
      final FakeInnertube innertube = failingInnertube();
      final StreamResolver resolver = makeResolver(
        innertube: innertube,
        solver: FakeSolver(),
        clients: const <ClientDefinition>[kWebRemixClient, kMwebClient],
        prefs: prefs,
      );
      // Resolve 1: urutan default [W, M].
      expect(await resolveFails(resolver, 'v1'), isNotNull);
      expect(innertube.playerCalls, <String>['WEB_REMIX', 'MWEB', 'MWEB']);
      // Resolve 2 (retry): mulai dari MWEB, bukan mengulang W dulu.
      innertube.playerCalls.clear();
      expect(await resolveFails(resolver, 'v1'), isNotNull);
      expect(innertube.playerCalls, <String>['MWEB', 'MWEB', 'WEB_REMIX']);
      // Resolve 3: kembali ke urutan default [W, M] (rotasi melingkar).
      innertube.playerCalls.clear();
      expect(await resolveFails(resolver, 'v1'), isNotNull);
      expect(innertube.playerCalls, <String>['WEB_REMIX', 'MWEB', 'MWEB']);
    });

    test('sukses menghapus rotasi, resolve berikutnya urutan default', () async {
      final FakeInnertube innertube = failingInnertube();
      final StreamResolver resolver = makeResolver(
        innertube: innertube,
        solver: FakeSolver(),
        clients: const <ClientDefinition>[kWebRemixClient, kMwebClient],
        prefs: prefs,
      );
      expect(await resolveFails(resolver, 'v1'), isNotNull);
      // MWEB kini OK: retry mulai dari MWEB dan langsung sukses.
      innertube.responses['MWEB'] = okResponse(cipher: false);
      innertube.playerCalls.clear();
      final ResolvedAudio result = await resolver.resolve('v1');
      expect(result.clientName, 'MWEB');
      expect(innertube.playerCalls, <String>['MWEB']);
      // Rotasi terhapus: resolve berikutnya mulai dari WEB_REMIX lagi.
      innertube.responses['MWEB'] = loginRequiredResponse;
      innertube.playerCalls.clear();
      expect(await resolveFails(resolver, 'v1'), isNotNull);
      expect(innertube.playerCalls.first, 'WEB_REMIX');
    });

    test('rotasi per lagu: lagu lain tidak ikut bergeser', () async {
      final FakeInnertube innertube = failingInnertube();
      final StreamResolver resolver = makeResolver(
        innertube: innertube,
        solver: FakeSolver(),
        clients: const <ClientDefinition>[kWebRemixClient, kMwebClient],
        prefs: prefs,
      );
      expect(await resolveFails(resolver, 'v1'), isNotNull);
      // Lagu v2 belum pernah gagal: urutan default [W, M].
      innertube.playerCalls.clear();
      expect(await resolveFails(resolver, 'v2'), isNotNull);
      expect(innertube.playerCalls, <String>['WEB_REMIX', 'MWEB', 'MWEB']);
    });
  });

  group('StreamResolver mode terdegradasi (P0)', () {
    FakeScriptLoader failingScriptLoader() => FakeScriptLoader()
      ..errorToThrow = const ExtractorException(
        ResolveFailureCause.unknownPlayerHash,
        detail: 'ekstraksi base.js gagal',
      );

    test('script gagal + tanpa client bebas-script -> lempar error script, '
        'tanpa request player', () async {
      final FakeInnertube innertube = FakeInnertube(
        responses: <String, Object>{'WEB_REMIX': okResponse(cipher: false)},
      );
      final StreamResolver resolver = makeResolver(
        innertube: innertube,
        solver: FakeSolver(),
        clients: const <ClientDefinition>[kWebRemixClient, kMwebClient],
        prefs: prefs,
        scriptLoader: failingScriptLoader(),
      );
      ExtractorException? caught;
      try {
        await resolver.resolve('k2XdBPv0D3Y');
        fail('resolve seharusnya melempar');
      } on ExtractorException catch (e) {
        caught = e;
      }
      expect(caught, isNotNull);
      expect(caught.cause, ResolveFailureCause.unknownPlayerHash);
      // Tanpa sts, request player client web DIJAMIN UNPLAYABLE: tidak
      // ada satu pun request player yang dibuang.
      expect(innertube.playerCalls, isEmpty);
    });

    test('script gagal + ANDROID_VR tersedia -> VR dicoba dan berhasil', () async {
      final FakeInnertube innertube = FakeInnertube(
        responses: <String, Object>{
          'WEB_REMIX': okResponse(cipher: false),
          'MWEB': okResponse(cipher: false),
          'ANDROID_VR': okResponse(cipher: false),
        },
      );
      final FakeSolver solver = FakeSolver();
      final StreamResolver resolver = makeResolver(
        innertube: innertube,
        solver: solver,
        clients: const <ClientDefinition>[
          kWebRemixClient,
          kMwebClient,
          kAndroidVrClient,
        ],
        prefs: prefs,
        scriptLoader: failingScriptLoader(),
      );
      // Skenario insiden P0: ekstraksi base.js gagal total, tapi lagu
      // tetap bisa diputar lewat VR (URL langsung, tanpa sts).
      final ResolvedAudio result = await resolver.resolve('k2XdBPv0D3Y');
      expect(result.clientName, 'ANDROID_VR');
      expect(innertube.playerCalls, <String>['ANDROID_VR']);
      expect(solver.solveCalls, 0);
    });

    test('script gagal + VR ikut gagal -> lempar error VR', () async {
      final FakeInnertube innertube = FakeInnertube(
        responses: <String, Object>{'ANDROID_VR': loginRequiredResponse},
      );
      final StreamResolver resolver = makeResolver(
        innertube: innertube,
        solver: FakeSolver(),
        clients: const <ClientDefinition>[
          kWebRemixClient,
          kMwebClient,
          kAndroidVrClient,
        ],
        prefs: prefs,
        scriptLoader: failingScriptLoader(),
      );
      ExtractorException? caught;
      try {
        await resolver.resolve('k2XdBPv0D3Y');
        fail('resolve seharusnya melempar');
      } on ExtractorException catch (e) {
        caught = e;
      }
      expect(caught, isNotNull);
      expect(caught.cause, ResolveFailureCause.httpForbidden);
      // Hanya VR yang dicoba (2x karena retry LOGIN_REQUIRED); client
      // web dilewati.
      expect(innertube.playerCalls, <String>['ANDROID_VR', 'ANDROID_VR']);
    });
  });
}
