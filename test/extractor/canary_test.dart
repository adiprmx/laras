import 'package:flutter_test/flutter_test.dart';
import 'package:laras/extractor/extractor.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Resolver palsu: gagal/sukses sesuai skrip per videoId.
class ScriptedResolver extends StreamResolver {
  ScriptedResolver({required this.script, required SharedPreferences prefs})
    : super(
        innertube: InnertubeClient(),
        solver: _NullSolver(),
        configLoader: _NullConfigLoader(prefs),
        scriptLoader: _NullScriptLoader(),
      );

  /// videoId -> null (sukses) atau ExtractorException (gagal).
  final Map<String, ExtractorException?> script;

  @override
  Future<ResolvedAudio> resolve(String videoId, {bool dataSaver = false}) async {
    final ExtractorException? error = script[videoId];
    if (error != null) throw error;
    return ResolvedAudio(
      videoId: videoId,
      url: 'https://example.invalid/audio',
      itag: 251,
      mimeType: 'audio/webm; codecs="opus"',
      bitrate: 154822,
      clientName: 'WEB_REMIX',
      resolveDuration: const Duration(milliseconds: 100),
    );
  }
}

class _NullSolver implements SignatureSolver {
  @override
  Future<String> solve({required PlayerScript script, required AudioFormat format}) async => '';
  @override
  Future<void> dispose() async {}
}

class _NullConfigLoader extends RemoteConfigLoader {
  _NullConfigLoader(SharedPreferences prefs) : super(prefs: prefs);
  @override
  Future<RemotePlayerConfig> current({bool forceRefresh = false}) async =>
      RemotePlayerConfig.defaults();
}

class _NullScriptLoader extends PlayerScriptLoader {
  _NullScriptLoader() : super(client: InnertubeClient());
}

const List<String> kIds = <String>['aaaaaaa-aaa', 'bbbbbbb-bbb', 'ccccccc-ccc', 'ddddddd-ddd', 'eeeeeee-eee'];

const ExtractorException sabrError = ExtractorException(ResolveFailureCause.sabrOnly);
const ExtractorException networkError = ExtractorException(
  ResolveFailureCause.emptyResponse,
  isNetworkError: true,
);
const ExtractorException parseError = ExtractorException(ResolveFailureCause.parseFailed);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    prefs = await SharedPreferences.getInstance();
  });

  CanaryChecker checkerWith(Map<String, ExtractorException?> script) {
    return CanaryChecker(
      resolver: ScriptedResolver(script: script, prefs: prefs),
      prefs: prefs,
      videoIds: kIds,
    );
  }

  group('CanaryChecker', () {
    test('semua sukses -> ok', () async {
      final CanaryCheckResult result = await checkerWith(<String, ExtractorException?>{}).check();
      expect(result.status, CanaryStatus.ok);
      expect(result.succeeded, 5);
      expect(result.failed, 0);
    });

    test('1-2 gagal non-jaringan -> degraded', () async {
      final CanaryCheckResult result = await checkerWith(
        <String, ExtractorException?>{'aaaaaaa-aaa': sabrError},
      ).check();
      expect(result.status, CanaryStatus.degraded);
      expect(result.failed, 1);
      expect(result.dominantCause, ResolveFailureCause.sabrOnly);
    });

    test('gagal jaringan saja -> ok (diabaikan)', () async {
      final CanaryCheckResult result = await checkerWith(
        <String, ExtractorException?>{
          'aaaaaaa-aaa': networkError,
          'bbbbbbb-bbb': networkError,
          'ccccccc-ccc': networkError,
          'ddddddd-ddd': networkError,
          'eeeeeee-eee': networkError,
        },
      ).check();
      expect(result.status, CanaryStatus.ok);
      expect(result.networkFailures, 5);
      expect(result.failed, 0);
    });

    test('>50% gagal dalam 1 jam -> broken', () async {
      final CanaryCheckResult result = await checkerWith(
        <String, ExtractorException?>{
          'aaaaaaa-aaa': sabrError,
          'bbbbbbb-bbb': sabrError,
          'ccccccc-ccc': sabrError,
        },
      ).check();
      // 3 dari 5 gagal = 60% > 50%.
      expect(result.status, CanaryStatus.broken);
    });

    test('3 cek berturut-turut penyebab sama -> broken', () async {
      // Tiap cek hanya 2 gagal (40%, di bawah ambang 50%) tapi penyebab
      // sama 3x berturut-turut -> ambang streak tercapai.
      final Map<String, ExtractorException?> script = <String, ExtractorException?>{
        'aaaaaaa-aaa': parseError,
        'bbbbbbb-bbb': parseError,
      };
      final CanaryCheckResult r1 = await checkerWith(script).check();
      expect(r1.status, CanaryStatus.degraded);
      final CanaryCheckResult r2 = await checkerWith(script).check();
      expect(r2.status, CanaryStatus.degraded);
      final CanaryCheckResult r3 = await checkerWith(script).check();
      expect(r3.status, CanaryStatus.broken);
    });

    test('cek bersih me-reset streak', () async {
      final Map<String, ExtractorException?> script = <String, ExtractorException?>{
        'aaaaaaa-aaa': parseError,
        'bbbbbbb-bbb': parseError,
      };
      await checkerWith(script).check();
      await checkerWith(script).check();
      // Cek bersih.
      final CanaryCheckResult clean = await checkerWith(<String, ExtractorException?>{}).check();
      expect(clean.status, CanaryStatus.ok);
      // Dua cek gagal lagi: streak mulai dari 1, belum broken.
      await checkerWith(script).check();
      final CanaryCheckResult r2 = await checkerWith(script).check();
      expect(r2.status, CanaryStatus.degraded);
    });
  });
}
