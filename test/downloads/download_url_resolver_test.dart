import 'package:flutter_test/flutter_test.dart';
import 'package:laras/downloads/downloads.dart';
import 'package:laras/extractor/extractor.dart';
import 'package:shared_preferences/shared_preferences.dart';

AudioFormat format(
  int itag, {
  int bitrate = 100000,
  bool sabr = false,
  bool direct = true,
}) {
  return AudioFormat(
    itag: itag,
    mimeType: itag == 140 || itag == 139
        ? 'audio/mp4; codecs="mp4a.40.2"'
        : 'audio/webm; codecs="opus"',
    bitrate: bitrate,
    url: direct ? 'https://example.invalid/audio/$itag' : null,
    cipheredSignature: direct ? null : 'cipher-$itag',
    cipherParamName: direct ? null : 'sig',
    cipherUrl: direct ? null : 'https://example.invalid/cipher/$itag',
    isSabr: sabr,
  );
}

void main() {
  group('pickFormatForQuality', () {
    final List<AudioFormat> all = <AudioFormat>[
      format(140, bitrate: 130000),
      format(251, bitrate: 155000),
      format(250, bitrate: 70000),
      format(249, bitrate: 59000),
      format(139, bitrate: 48000),
    ];

    test('Terbaik memilih 251', () {
      expect(
        pickFormatForQuality(all, DownloadQuality.best)?.itag,
        251,
      );
    });

    test('Seimbang memilih 140', () {
      expect(
        pickFormatForQuality(all, DownloadQuality.balanced)?.itag,
        140,
      );
    });

    test('Hemat data memilih 249', () {
      expect(
        pickFormatForQuality(all, DownloadQuality.dataSaver)?.itag,
        249,
      );
    });

    test('Terbaik tanpa 251 jatuh ke 140', () {
      final List<AudioFormat> formats = all
          .where((AudioFormat f) => f.itag != 251)
          .toList();
      expect(
        pickFormatForQuality(formats, DownloadQuality.best)?.itag,
        140,
      );
    });

    test('Seimbang tanpa 140 jatuh ke 250', () {
      final List<AudioFormat> formats = all
          .where((AudioFormat f) => f.itag != 140)
          .toList();
      expect(
        pickFormatForQuality(formats, DownloadQuality.balanced)?.itag,
        250,
      );
    });

    test('Hemat data tanpa 249 jatuh ke 139', () {
      final List<AudioFormat> formats = all
          .where((AudioFormat f) => f.itag != 249)
          .toList();
      expect(
        pickFormatForQuality(formats, DownloadQuality.dataSaver)?.itag,
        139,
      );
    });

    test('format SABR tidak pernah dipilih', () {
      final List<AudioFormat> formats = <AudioFormat>[
        format(251, bitrate: 155000, sabr: true),
        format(139, bitrate: 48000),
      ];
      expect(
        pickFormatForQuality(formats, DownloadQuality.best)?.itag,
        139,
      );
    });

    test('hanya format SABR -> null', () {
      final List<AudioFormat> formats = <AudioFormat>[
        format(251, bitrate: 155000, sabr: true),
      ];
      expect(pickFormatForQuality(formats, DownloadQuality.best), isNull);
    });

    test('format tanpa URL dan tanpa cipher tidak bisa dipakai', () {
      const AudioFormat broken = AudioFormat(
        itag: 251,
        mimeType: 'audio/webm; codecs="opus"',
        bitrate: 155000,
      );
      expect(
        pickFormatForQuality(
          <AudioFormat>[broken],
          DownloadQuality.best,
        ),
        isNull,
      );
    });

    test('format cipher (butuh solver) bisa dipakai', () {
      final List<AudioFormat> formats = <AudioFormat>[
        format(251, bitrate: 155000, direct: false),
      ];
      expect(
        pickFormatForQuality(formats, DownloadQuality.best)?.itag,
        251,
      );
    });

    test('itag tak dikenal: jalan terakhir bitrate tertinggi', () {
      final List<AudioFormat> formats = <AudioFormat>[
        format(999, bitrate: 200000),
        format(888, bitrate: 100000),
      ];
      expect(
        pickFormatForQuality(formats, DownloadQuality.best)?.itag,
        999,
      );
    });

    test('daftar kosong -> null', () {
      expect(
        pickFormatForQuality(const <AudioFormat>[], DownloadQuality.best),
        isNull,
      );
    });
  });

  _sourceTests();
}

/// Innertube palsu: respons player yang diprogram per client, berurutan
/// (tiap pemanggilan mengambil respons berikutnya dari daftar client itu;
/// bila habis, memakai yang terakhir).
class _FakeInnertube extends InnertubeClient {
  _FakeInnertube({required this.responses}) : super();

  final Map<String, List<Object>> responses;
  final List<String> playerCalls = <String>[];
  final Map<String, int> _callIndex = <String, int>{};

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
    final List<Object>? queue = responses[client.name];
    if (queue == null || queue.isEmpty) {
      throw const ExtractorException(ResolveFailureCause.emptyResponse);
    }
    final int index = _callIndex[client.name] ?? 0;
    _callIndex[client.name] = index + 1;
    final Object response = queue[index < queue.length
        ? index
        : queue.length - 1];
    if (response is ExtractorException) throw response;
    if (response is ParsedPlayerResponse) return response;
    throw const ExtractorException(ResolveFailureCause.emptyResponse);
  }
}

/// Solver palsu: mengembalikan URL final yang diprogram.
class _FakeSolver implements SignatureSolver {
  _FakeSolver({this.resultUrl});

  String? resultUrl;
  int solveCalls = 0;

  @override
  Future<String> solve({
    required PlayerScript script,
    required AudioFormat format,
  }) async {
    solveCalls++;
    return resultUrl ??
        'https://rr1---sn-palsu.googlevideo.com/videoplayback'
            '?itag=${format.itag}';
  }

  @override
  Future<void> dispose() async {}
}

/// Loader config palsu: config yang diprogram.
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
/// lalu melempar [errorToThrow]; mencatat allowlist tiap pemanggilan.
class _RecordingScriptLoader extends PlayerScriptLoader {
  _RecordingScriptLoader({this.succeedCalls = 999999, this.errorToThrow})
    : super(client: InnertubeClient());

  final int succeedCalls;
  final ExtractorException? errorToThrow;
  int loadCalls = 0;
  final List<Set<String>?> allowedHashesSeen = <Set<String>?>[];

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
    allowedHashesSeen.add(allowedHashes);
    if (loadCalls > succeedCalls && errorToThrow != null) {
      throw errorToThrow!;
    }
    return dummy;
  }
}

ParsedPlayerResponse _okDirectResponse(String url) {
  return ParsedPlayerResponse(
    playability: Playability.ok,
    audioFormats: <AudioFormat>[
      AudioFormat(
        itag: 251,
        mimeType: 'audio/webm; codecs="opus"',
        bitrate: 154822,
        url: url,
      ),
    ],
    title: 'Lagu Tes',
    lengthSeconds: 200,
  );
}

const ParsedPlayerResponse _okCipherResponse = ParsedPlayerResponse(
  playability: Playability.ok,
  audioFormats: <AudioFormat>[
    AudioFormat(
      itag: 251,
      mimeType: 'audio/webm; codecs="opus"',
      bitrate: 154822,
      cipheredSignature: 'cipher-palsu',
      cipherParamName: 'sig',
      cipherUrl: 'https://rr1---sn-palsu.googlevideo.com/videoplayback',
    ),
  ],
  title: 'Lagu Tes',
  lengthSeconds: 200,
);

const ParsedPlayerResponse _loginRequiredResponse = ParsedPlayerResponse(
  playability: Playability.loginRequired,
  reason: 'Sign in to confirm you\u2019re not a bot',
  audioFormats: <AudioFormat>[],
);

const ExtractorException _unknownHashError = ExtractorException(
  ResolveFailureCause.unknownPlayerHash,
  detail: 'hash player baru muncul saat load ulang',
);

RemotePlayerConfig _configWith(
  List<ClientDefinition> clients, {
  Map<String, int> playerHashes = const <String, int>{},
}) => RemotePlayerConfig(
  clients: clients,
  playerHashes: playerHashes,
  canaryVideoIds: const <String>[],
  fetchedAt: DateTime.now(),
  isRemote: true,
);

ExtractorDownloadUrlSource _makeSource({
  required _FakeInnertube innertube,
  required _FakeSolver solver,
  required List<ClientDefinition> clients,
  required SharedPreferences prefs,
  required PlayerScriptLoader scriptLoader,
  Map<String, int> playerHashes = const <String, int>{},
}) {
  return ExtractorDownloadUrlSource(
    innertube: innertube,
    solver: solver,
    configLoader: _FakeConfigLoader(
      config: _configWith(clients, playerHashes: playerHashes),
      prefs: prefs,
    ),
    scriptLoader: scriptLoader,
  );
}

Future<ExtractorException?> _resolveFails(
  DownloadUrlSource source,
  String videoId,
) async {
  try {
    await source.resolve(videoId, DownloadQuality.best);
    return null;
  } on ExtractorException catch (e) {
    return e;
  }
}

void _sourceTests() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late SharedPreferences prefs;

  setUpAll(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    prefs = await SharedPreferences.getInstance();
  });

  group('R2-M1: URL unduhan jalur langsung divalidasi host-nya', () {
    test('URL langsung di luar host yang diizinkan ditolak', () async {
      final _FakeInnertube innertube = _FakeInnertube(
        responses: <String, List<Object>>{
          'WEB_REMIX': <Object>[
            _okDirectResponse('https://evil.example/a.mp3'),
          ],
        },
      );
      final _FakeSolver solver = _FakeSolver();
      final DownloadUrlSource source = _makeSource(
        innertube: innertube,
        solver: solver,
        clients: const <ClientDefinition>[kWebRemixClient],
        prefs: prefs,
        scriptLoader: _RecordingScriptLoader(),
      );
      final ExtractorException? caught = await _resolveFails(
        source,
        'k2XdBPv0D3Y',
      );
      expect(caught, isNotNull);
      expect(caught!.cause, ResolveFailureCause.parseFailed);
      // Ditolak sebelum solver: tidak ada URL jahat yang keluar dari
      // resolver ke layanan unduhan.
      expect(solver.solveCalls, 0);
    });

    test('URL langsung subdomain googlevideo lolos', () async {
      final _FakeInnertube innertube = _FakeInnertube(
        responses: <String, List<Object>>{
          'ANDROID_VR': <Object>[
            _okDirectResponse(
              'https://rr1---sn-palsu.googlevideo.com/videoplayback'
              '?itag=251',
            ),
          ],
        },
      );
      final DownloadUrlSource source = _makeSource(
        innertube: innertube,
        solver: _FakeSolver(),
        clients: const <ClientDefinition>[kAndroidVrClient],
        prefs: prefs,
        scriptLoader: _RecordingScriptLoader(),
      );
      final DownloadUrl result = await source.resolve(
        'k2XdBPv0D3Y',
        DownloadQuality.best,
      );
      expect(result.clientName, 'ANDROID_VR');
      expect(result.url, contains('googlevideo.com'));
    });

    test('URL hasil solver di luar host yang diizinkan ditolak', () async {
      final _FakeInnertube innertube = _FakeInnertube(
        responses: <String, List<Object>>{
          'WEB_REMIX': <Object>[_okCipherResponse],
        },
      );
      final DownloadUrlSource source = _makeSource(
        innertube: innertube,
        solver: _FakeSolver(
          resultUrl: 'https://evil.example/hasil-solver.mp3',
        ),
        clients: const <ClientDefinition>[kWebRemixClient],
        prefs: prefs,
        scriptLoader: _RecordingScriptLoader(),
      );
      final ExtractorException? caught = await _resolveFails(
        source,
        'k2XdBPv0D3Y',
      );
      expect(caught, isNotNull);
      expect(caught!.cause, ResolveFailureCause.parseFailed);
    });
  });

  group('R2-L5: resolver cermin meniru degradasi P0-2 + hash remote', () {
    test('hash tak dikenal di tengah loop -> VR tetap dicoba dan berhasil',
        () async {
      final _FakeInnertube innertube = _FakeInnertube(
        responses: <String, List<Object>>{
          'WEB_REMIX': <Object>[_okCipherResponse],
          'MWEB': <Object>[_okCipherResponse],
          'ANDROID_VR': <Object>[
            _okDirectResponse(
              'https://rr1---sn-palsu.googlevideo.com/videoplayback'
              '?langsung=1',
            ),
          ],
        },
      );
      final DownloadUrlSource source = _makeSource(
        innertube: innertube,
        solver: _FakeSolver(),
        clients: const <ClientDefinition>[
          kWebRemixClient,
          kMwebClient,
          kAndroidVrClient,
        ],
        prefs: prefs,
        // Load #1 (awal, sts) berhasil; load #2 (jalur cipher WEB_REMIX)
        // melempar hash tak dikenal.
        scriptLoader: _RecordingScriptLoader(
          succeedCalls: 1,
          errorToThrow: _unknownHashError,
        ),
      );
      final DownloadUrl result = await source.resolve(
        'k2XdBPv0D3Y',
        DownloadQuality.best,
      );
      expect(result.clientName, 'ANDROID_VR');
      expect(result.url, contains('langsung=1'));
      // MWEB dilewati (butuh script, mode terdegradasi); VR dicoba.
      expect(innertube.playerCalls, <String>['WEB_REMIX', 'ANDROID_VR']);
    });

    test('hash tak dikenal + tanpa client bebas-script -> error hash, '
        'client berikutnya dilewati', () async {
      final _FakeInnertube innertube = _FakeInnertube(
        responses: <String, List<Object>>{
          'WEB_REMIX': <Object>[_okCipherResponse],
          'MWEB': <Object>[
            _okDirectResponse(
              'https://rr1---sn-palsu.googlevideo.com/videoplayback',
            ),
          ],
        },
      );
      final DownloadUrlSource source = _makeSource(
        innertube: innertube,
        solver: _FakeSolver(),
        clients: const <ClientDefinition>[kWebRemixClient, kMwebClient],
        prefs: prefs,
        scriptLoader: _RecordingScriptLoader(
          succeedCalls: 1,
          errorToThrow: _unknownHashError,
        ),
      );
      final ExtractorException? caught = await _resolveFails(
        source,
        'k2XdBPv0D3Y',
      );
      expect(caught, isNotNull);
      expect(caught!.cause, ResolveFailureCause.unknownPlayerHash);
      expect(innertube.playerCalls, <String>['WEB_REMIX']);
    });

    test('hash player dari config diteruskan ke semua pemuatan script',
        () async {
      final _FakeInnertube innertube = _FakeInnertube(
        responses: <String, List<Object>>{
          // LOGIN_REQUIRED dulu (memicu load ulang di jalur retry),
          // lalu respons cipher (memicu load di jalur solver).
          'WEB_REMIX': <Object>[
            _loginRequiredResponse,
            _okCipherResponse,
          ],
        },
      );
      final _RecordingScriptLoader loader = _RecordingScriptLoader();
      final DownloadUrlSource source = _makeSource(
        innertube: innertube,
        solver: _FakeSolver(),
        clients: const <ClientDefinition>[kWebRemixClient],
        prefs: prefs,
        scriptLoader: loader,
        playerHashes: const <String, int>{'hashbaru': 12345},
      );
      final DownloadUrl result = await source.resolve(
        'k2XdBPv0D3Y',
        DownloadQuality.best,
      );
      expect(result.clientName, 'WEB_REMIX');
      // Tiga pemuatan: awal + retry LOGIN_REQUIRED + jalur solver.
      expect(loader.loadCalls, 3);
      expect(loader.allowedHashesSeen, hasLength(3));
      for (final Set<String>? seen in loader.allowedHashesSeen) {
        expect(seen, contains('hashbaru'));
      }
    });
  });
}

