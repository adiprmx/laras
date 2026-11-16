/// Tes pesan kegagalan putar: lengkap (banner) + singkat (mini-player).
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:laras/extractor/errors.dart';
import 'package:laras/l10n/generated/app_localizations.dart';
import 'package:laras/l10n/generated/app_localizations_id.dart';
import 'package:laras/player/playback_failure_messages.dart';
import 'package:laras/player/player_state.dart';

void main() {
  final AppLocalizations strings = AppLocalizationsId();

  group('playbackFailureShortMessage (mini-player)', () {
    test('network + timeout memakai pesan singkat bawaan', () {
      expect(
        playbackFailureShortMessage(
          strings,
          const PlaybackFailure(
            kind: PlaybackFailureKind.network,
            trackTitle: 'X',
          ),
        ),
        strings.playFailedNetworkShort,
      );
      expect(
        playbackFailureShortMessage(
          strings,
          const PlaybackFailure(
            kind: PlaybackFailureKind.timeout,
            trackTitle: 'X',
          ),
        ),
        strings.playFailedTimeoutShort,
      );
    });

    test('unplayable tanpa penyebab -> pesan singkat generik', () {
      expect(
        playbackFailureShortMessage(
          strings,
          const PlaybackFailure(
            kind: PlaybackFailureKind.unplayable,
            trackTitle: 'X',
          ),
        ),
        strings.playFailedCannotPlayShort,
      );
    });

    test('unplayable dengan penyebab -> varian singkat per penyebab', () {
      expect(
        playbackFailureShortMessage(
          strings,
          const PlaybackFailure(
            kind: PlaybackFailureKind.unplayable,
            trackTitle: 'X',
            cause: ResolveFailureCause.httpForbidden,
          ),
        ),
        strings.causeForbiddenShort,
      );
      expect(
        playbackFailureShortMessage(
          strings,
          const PlaybackFailure(
            kind: PlaybackFailureKind.unplayable,
            trackTitle: 'X',
            cause: ResolveFailureCause.emptyResponse,
          ),
        ),
        strings.causeEmptyResponseShort,
      );
      expect(
        playbackFailureShortMessage(
          strings,
          const PlaybackFailure(
            kind: PlaybackFailureKind.unplayable,
            trackTitle: 'X',
            cause: ResolveFailureCause.parseFailed,
          ),
        ),
        strings.causeParseFailedShort,
      );
      expect(
        playbackFailureShortMessage(
          strings,
          const PlaybackFailure(
            kind: PlaybackFailureKind.unplayable,
            trackTitle: 'X',
            cause: ResolveFailureCause.sabrOnly,
          ),
        ),
        strings.causeSabrOnlyShort,
      );
      expect(
        playbackFailureShortMessage(
          strings,
          const PlaybackFailure(
            kind: PlaybackFailureKind.unplayable,
            trackTitle: 'X',
            cause: ResolveFailureCause.solverTimeout,
          ),
        ),
        strings.causeSolverTimeoutShort,
      );
      expect(
        playbackFailureShortMessage(
          strings,
          const PlaybackFailure(
            kind: PlaybackFailureKind.unplayable,
            trackTitle: 'X',
            cause: ResolveFailureCause.unknownPlayerHash,
          ),
        ),
        strings.causeUnknownPlayerHashShort,
      );
    });
  });

  group('playbackFailureMessage (banner)', () {
    test('unplayable dengan penyebab -> pesan lengkap per penyebab', () {
      expect(
        playbackFailureMessage(
          strings,
          const PlaybackFailure(
            kind: PlaybackFailureKind.unplayable,
            trackTitle: 'X',
            cause: ResolveFailureCause.parseFailed,
          ),
        ),
        strings.causeParseFailed,
      );
    });

    test('jumlah lagu dilewati ditambahkan di akhir pesan', () {
      expect(
        playbackFailureMessage(
          strings,
          const PlaybackFailure(
            kind: PlaybackFailureKind.unplayable,
            trackTitle: 'X',
            skippedCount: 2,
          ),
        ),
        '${strings.songCannotPlay} ${strings.skippedUnplayable(2)}',
      );
    });
  });
}
