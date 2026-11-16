/// Tes kode diagnostik singkat (P6, tambahan verdict owner 18:56 WIB).
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:laras/extractor/canary.dart';
import 'package:laras/extractor/errors.dart';
import 'package:laras/extractor/models.dart';
import 'package:laras/player/player_state.dart';
import 'package:laras/resilience/diagnostic_code.dart';

ResolveLogEntry entry({
  required DateTime at,
  required String videoId,
  required String client,
  String outcome = 'GAGAL',
  ResolveFailureCause? cause,
  bool network = false,
  bool timeout = false,
  bool skipped = false,
}) {
  return ResolveLogEntry(
    timestamp: at,
    videoId: videoId,
    clientName: client,
    outcome: outcome,
    durationMs: 100,
    cause: cause,
    isNetworkError: network,
    isTimeout: timeout,
    skipped: skipped,
  );
}

void main() {
  // DateTime tidak punya konstruktor const — pakai final (bukan const).
  final DateTime t = DateTime(2026, 11, 16, 19, 5);

  group('buildDiagnosticCode', () {
    test('data lengkap -> kode persis sesuai legenda', () {
      final String code = buildDiagnosticCode(
        DiagnosticData(
          kind: PlaybackFailureKind.unplayable,
          cause: ResolveFailureCause.parseFailed,
          failedAt: t,
          clientsTried: <String>['WEB_REMIX', 'MWEB', 'ANDROID_VR'],
          appVersion: '0.9.0',
          appBuild: 1,
          configVersion: '1.20261110.04.00',
          configIsRemote: true,
          serviceStatus: CanaryStatus.degraded,
        ),
      );
      expect(code, 'LRS1-UPF-16111905-WMV-0901-R20261110-D');
    });

    test('tanpa kegagalan tercatat -> X/XX + waktu pembuatan + B + ?', () {
      final String code = buildDiagnosticCode(
        const DiagnosticData(appVersion: '0.9.0', appBuild: 1),
        now: t,
      );
      expect(code, 'LRS1-XXX-16111905-X-0901-B-?');
    });

    test('ketiga jenis + keenam penyebab terpetakan', () {
      const Map<PlaybackFailureKind, String> kinds =
          <PlaybackFailureKind, String>{
            PlaybackFailureKind.network: 'N',
            PlaybackFailureKind.timeout: 'T',
            PlaybackFailureKind.unplayable: 'U',
          };
      const Map<ResolveFailureCause, String> causes =
          <ResolveFailureCause, String>{
            ResolveFailureCause.httpForbidden: 'FH',
            ResolveFailureCause.emptyResponse: 'ER',
            ResolveFailureCause.parseFailed: 'PF',
            ResolveFailureCause.sabrOnly: 'SB',
            ResolveFailureCause.solverTimeout: 'ST',
            ResolveFailureCause.unknownPlayerHash: 'UH',
          };
      for (final MapEntry<PlaybackFailureKind, String> k in kinds.entries) {
        for (final MapEntry<ResolveFailureCause, String> c in causes.entries) {
          final String code = buildDiagnosticCode(
            DiagnosticData(
              kind: k.key,
              cause: c.key,
              appVersion: '0.9.0',
              appBuild: 1,
            ),
            now: t,
          );
          expect(
            code,
            startsWith('LRS1-${k.value}${c.value}-16111905-'),
            reason: '${k.key} + ${c.key}',
          );
        }
      }
    });

    test('client tidak dikenal -> ?, tanpa client -> X', () {
      final String unknown = buildDiagnosticCode(
        const DiagnosticData(
          clientsTried: <String>['WEB_REMIX', 'CLIENT_BARU'],
          appVersion: '0.9.0',
          appBuild: 1,
        ),
        now: t,
      );
      expect(unknown.split('-')[3], 'W?');
      final String none = buildDiagnosticCode(
        const DiagnosticData(appVersion: '0.9.0', appBuild: 1),
        now: t,
      );
      expect(none.split('-')[3], 'X');
    });

    test('config: remote bertanggal -> R+tanggal, remote lain -> R, '
        'bawaan -> B', () {
      String seg(String? version, bool remote) {
        return buildDiagnosticCode(
          DiagnosticData(
            appVersion: '0.9.0',
            appBuild: 1,
            configVersion: version,
            configIsRemote: remote,
          ),
          now: t,
        ).split('-')[5];
      }

      expect(seg('1.20261110.04.00', true), 'R20261110');
      expect(seg('2.20260708.05.00', true), 'R20260708');
      expect(seg('2.0.0', true), 'R');
      expect(seg(null, true), 'R');
      expect(seg('1.20261110.04.00', false), 'B');
      expect(seg(null, false), 'B');
    });

    test('status layanan: O/D/B/?', () {
      String seg(CanaryStatus? status) {
        return buildDiagnosticCode(
          DiagnosticData(
            appVersion: '0.9.0',
            appBuild: 1,
            serviceStatus: status,
          ),
          now: t,
        ).split('-')[6];
      }

      expect(seg(CanaryStatus.ok), 'O');
      expect(seg(CanaryStatus.degraded), 'D');
      expect(seg(CanaryStatus.broken), 'B');
      expect(seg(null), '?');
    });

    test('kode satu baris tanpa spasi, tanpa data sensitif', () {
      final String code = buildDiagnosticCode(
        DiagnosticData(
          kind: PlaybackFailureKind.unplayable,
          cause: ResolveFailureCause.parseFailed,
          failedAt: t,
          clientsTried: <String>['WEB_REMIX'],
          appVersion: '0.9.0',
          appBuild: 1,
        ),
      );
      expect(code, isNot(contains(' ')));
      expect(code, isNot(contains('\n')));
      expect(code, isNot(contains('http')));
      expect(code.length, lessThanOrEqualTo(45));
    });
  });

  group('collectDiagnosticData', () {
    test('hanya lastFailure: jenis + penyebab dari failure, tanpa log', () {
      final DiagnosticData data = collectDiagnosticData(
        lastFailure: const PlaybackFailure(
          kind: PlaybackFailureKind.network,
          trackTitle: 'Lagu X',
        ),
        appVersion: '0.9.0',
        appBuild: 1,
      );
      expect(data.kind, PlaybackFailureKind.network);
      expect(data.cause, isNull);
      expect(data.failedAt, isNull);
      expect(data.clientsTried, isEmpty);
      final String code = buildDiagnosticCode(data, now: t);
      expect(code, startsWith('LRS1-NXX-16111905-X-'));
    });

    test(
      'log gagal: putaran terakhir dikelompokkan per videoId + 60 detik',
      () {
        final DiagnosticData data = collectDiagnosticData(
          recentLog: <ResolveLogEntry>[
            // Putaran lama (2 jam lalu, videoId sama) -> di luar jendela.
            entry(
              at: t.subtract(const Duration(hours: 2)),
              videoId: 'v1',
              client: 'WEB_REMIX',
              cause: ResolveFailureCause.httpForbidden,
            ),
            // Video lain di waktu sama -> bukan putaran ini.
            entry(
              at: t,
              videoId: 'v2',
              client: 'MWEB',
              cause: ResolveFailureCause.parseFailed,
            ),
            // Putaran gagal terakhir (videoId v1).
            entry(
              at: t,
              videoId: 'v1',
              client: 'WEB_REMIX',
              cause: ResolveFailureCause.parseFailed,
            ),
            entry(
              at: t.add(const Duration(seconds: 3)),
              videoId: 'v1',
              client: 'MWEB',
              cause: ResolveFailureCause.parseFailed,
            ),
            entry(
              at: t.add(const Duration(seconds: 6)),
              videoId: 'v1',
              client: 'ANDROID_VR',
              cause: ResolveFailureCause.parseFailed,
            ),
          ],
          appVersion: '0.9.0',
          appBuild: 1,
        );
        expect(data.clientsTried, <String>['WEB_REMIX', 'MWEB', 'ANDROID_VR']);
        expect(data.failedAt, t.add(const Duration(seconds: 6)));
        expect(data.cause, ResolveFailureCause.parseFailed);
        expect(data.kind, PlaybackFailureKind.unplayable);
        expect(buildDiagnosticCode(data), 'LRS1-UPF-16111905-WMV-0901-B-?');
      },
    );

    test('entri skipped tidak dihitung sebagai client yang dicoba', () {
      final DiagnosticData data = collectDiagnosticData(
        recentLog: <ResolveLogEntry>[
          entry(
            at: t,
            videoId: 'v1',
            client: 'WEB_REMIX',
            cause: ResolveFailureCause.parseFailed,
          ),
          entry(
            at: t.add(const Duration(seconds: 1)),
            videoId: 'v1',
            client: 'ANDROID_VR',
            outcome: 'LEWATI (butuh script)',
            skipped: true,
          ),
        ],
        appVersion: '0.9.0',
        appBuild: 1,
      );
      expect(data.clientsTried, <String>['WEB_REMIX']);
    });

    test('entri SCRIPT bukan client: tidak masuk segmen KLIEN, '
        'tapi penyebab + waktunya dipakai', () {
      final DiagnosticData data = collectDiagnosticData(
        recentLog: <ResolveLogEntry>[
          entry(
            at: t,
            videoId: 'v1',
            client: 'SCRIPT',
            cause: ResolveFailureCause.solverTimeout,
          ),
          entry(
            at: t.add(const Duration(seconds: 2)),
            videoId: 'v1',
            client: 'MWEB',
            cause: ResolveFailureCause.parseFailed,
          ),
        ],
        appVersion: '0.9.0',
        appBuild: 1,
      );
      expect(data.clientsTried, <String>['MWEB']);
      expect(data.cause, ResolveFailureCause.parseFailed);
      // Bila SCRIPT adalah satu-satunya entri gagal, penyebabnya
      // (solverTimeout) tetap terbaca dan client menjadi X.
      final DiagnosticData onlyScript = collectDiagnosticData(
        recentLog: <ResolveLogEntry>[
          entry(
            at: t,
            videoId: 'v1',
            client: 'SCRIPT',
            cause: ResolveFailureCause.solverTimeout,
          ),
        ],
        appVersion: '0.9.0',
        appBuild: 1,
      );
      expect(onlyScript.clientsTried, isEmpty);
      expect(onlyScript.cause, ResolveFailureCause.solverTimeout);
      expect(
        buildDiagnosticCode(onlyScript),
        startsWith('LRS1-UST-16111905-X-'),
      );
    });

    test('resolve lambat tidak terbelah: rantai jeda 50 detik tetap '
        'satu putaran walau total 150 detik', () {
      final DiagnosticData data = collectDiagnosticData(
        recentLog: <ResolveLogEntry>[
          entry(
            at: t,
            videoId: 'v1',
            client: 'WEB_REMIX',
            cause: ResolveFailureCause.parseFailed,
          ),
          entry(
            at: t.add(const Duration(seconds: 50)),
            videoId: 'v1',
            client: 'MWEB',
            cause: ResolveFailureCause.parseFailed,
          ),
          entry(
            at: t.add(const Duration(seconds: 100)),
            videoId: 'v1',
            client: 'ANDROID_VR',
            cause: ResolveFailureCause.parseFailed,
          ),
          entry(
            at: t.add(const Duration(seconds: 150)),
            videoId: 'v1',
            client: 'ANDROID_VR',
            cause: ResolveFailureCause.parseFailed,
          ),
        ],
        appVersion: '0.9.0',
        appBuild: 1,
      );
      expect(data.clientsTried, <String>['WEB_REMIX', 'MWEB', 'ANDROID_VR']);
    });

    test('jeda > 60 detik memutus rantai: putaran lama tidak ikut', () {
      final DiagnosticData data = collectDiagnosticData(
        recentLog: <ResolveLogEntry>[
          entry(
            at: t,
            videoId: 'v1',
            client: 'WEB_REMIX',
            cause: ResolveFailureCause.parseFailed,
          ),
          entry(
            at: t.add(const Duration(seconds: 61)),
            videoId: 'v1',
            client: 'MWEB',
            cause: ResolveFailureCause.parseFailed,
          ),
        ],
        appVersion: '0.9.0',
        appBuild: 1,
      );
      expect(data.clientsTried, <String>['MWEB']);
    });

    test('gagal jaringan tanpa penyebab -> jenis network, penyebab XX', () {
      final DiagnosticData data = collectDiagnosticData(
        recentLog: <ResolveLogEntry>[
          entry(at: t, videoId: 'v1', client: 'MWEB', network: true),
        ],
        appVersion: '0.9.0',
        appBuild: 1,
      );
      expect(data.kind, PlaybackFailureKind.network);
      expect(data.cause, isNull);
      expect(buildDiagnosticCode(data), startsWith('LRS1-NXX-16111905-M-'));
    });

    test('penyebab lastFailure menang atas penyebab log', () {
      final DiagnosticData data = collectDiagnosticData(
        lastFailure: const PlaybackFailure(
          kind: PlaybackFailureKind.unplayable,
          trackTitle: 'Lagu X',
          cause: ResolveFailureCause.sabrOnly,
        ),
        recentLog: <ResolveLogEntry>[
          entry(
            at: t,
            videoId: 'v1',
            client: 'WEB_REMIX',
            cause: ResolveFailureCause.parseFailed,
          ),
        ],
        appVersion: '0.9.0',
        appBuild: 1,
      );
      // lastFailure adalah error yang tampil ke pengguna: penyebabnya
      // yang dipakai; log tetap menyumbang waktu + client.
      expect(data.cause, ResolveFailureCause.sabrOnly);
      expect(data.failedAt, t);
      expect(data.clientsTried, <String>['WEB_REMIX']);
    });

    test('log sukses saja -> tidak ada kegagalan dari log', () {
      final DiagnosticData data = collectDiagnosticData(
        recentLog: <ResolveLogEntry>[
          entry(
            at: t,
            videoId: 'v1',
            client: 'WEB_REMIX',
            outcome: 'OK itag 251',
          ),
        ],
        appVersion: '0.9.0',
        appBuild: 1,
      );
      expect(data.kind, isNull);
      expect(data.cause, isNull);
      expect(data.failedAt, isNull);
      expect(data.clientsTried, isEmpty);
    });
  });
}
