import 'package:flutter_test/flutter_test.dart';
import 'package:laras/extractor/extractor.dart';

void main() {
  group('ResolveFailureCause', () {
    test('tepat 6 penyebab', () {
      expect(ResolveFailureCause.values.length, 6);
    });
  });

  group('ExtractorException', () {
    test('toString tidak pernah berisi URL stream', () {
      const ExtractorException e = ExtractorException(
        ResolveFailureCause.httpForbidden,
        clientName: 'WEB_REMIX',
        detail: 'HTTP 403 dari server',
      );
      final String text = e.toString();
      expect(text, contains('httpForbidden'));
      expect(text, contains('WEB_REMIX'));
      expect(text, isNot(contains('googlevideo')));
      // 'httpForbidden' sendiri mengandung kata http, jadi yang dicek
      // adalah bentuk URL (skema + ://), bukan kata http.
      expect(text, isNot(contains('://')));
    });

    test('flag isNetworkError membedakan jaringan putus', () {
      const ExtractorException network = ExtractorException(
        ResolveFailureCause.emptyResponse,
        isNetworkError: true,
      );
      const ExtractorException empty = ExtractorException(
        ResolveFailureCause.emptyResponse,
      );
      expect(network.isNetworkError, isTrue);
      expect(empty.isNetworkError, isFalse);
      expect(network.cause, empty.cause);
    });
  });

  group('ResolvedAudio', () {
    test('toString tidak mencetak URL', () {
      const ResolvedAudio resolved = ResolvedAudio(
        videoId: 'hhn-nGSuenM',
        url: 'https://rr1---sn-xxxx.googlevideo.com/videoplayback?secret=abc',
        itag: 251,
        mimeType: 'audio/webm; codecs="opus"',
        bitrate: 154822,
        clientName: 'WEB_REMIX',
        resolveDuration: Duration(milliseconds: 1200),
      );
      final String text = resolved.toString();
      expect(text, contains('hhn-nGSuenM'));
      expect(text, contains('251'));
      expect(text, isNot(contains('googlevideo')));
      expect(text, isNot(contains('secret')));
    });
  });

  group('AudioFormat', () {
    test('toString tidak mencetak URL atau cipher', () {
      const AudioFormat format = AudioFormat(
        itag: 251,
        mimeType: 'audio/webm; codecs="opus"',
        bitrate: 154822,
        url: 'https://rr1---sn-xxxx.googlevideo.com/videoplayback?x=1',
        cipheredSignature: 'rahasia-signature',
        cipherUrl: 'https://rr1---sn-xxxx.googlevideo.com/videoplayback?y=2',
      );
      final String text = format.toString();
      expect(text, isNot(contains('googlevideo')));
      expect(text, isNot(contains('rahasia-signature')));
    });
  });
}
