/// Tes channel file salinan (P8): berbagi + pemilih file lewat
/// MethodChannel tiruan (tanpa Android).
library;

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:laras/data/backup_format.dart';
import 'package:laras/features/backup/backup_file_channel.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const MethodChannel channel = MethodChannel(
    'id.my.adipmusic.laras/backup_files',
  );
  final TestDefaultBinaryMessengerBinding binding =
      TestDefaultBinaryMessengerBinding.instance;

  tearDown(() {
    binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, null);
  });

  void mock(Future<Object?> Function(MethodCall) handler) {
    binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, handler);
  }

  group('shareFile', () {
    test('true bila chooser terbuka; argumen path + fileName diteruskan',
        () async {
      String? gotPath;
      String? gotName;
      mock((MethodCall call) async {
        expect(call.method, 'shareFile');
        final Map<dynamic, dynamic> args =
            call.arguments as Map<dynamic, dynamic>;
        gotPath = args['path'] as String?;
        gotName = args['fileName'] as String?;
        expect(args['mimeType'], 'application/json');
        return true;
      });
      final bool result = await BackupFileChannel().shareFile(
        path: '/tmp/cache/backup-musik-20261117-043805.json',
        fileName: 'backup-musik-20261117-043805.json',
      );
      expect(result, isTrue);
      expect(gotPath, '/tmp/cache/backup-musik-20261117-043805.json');
      expect(gotName, 'backup-musik-20261117-043805.json');
    });

    test('false bila platform mengembalikan false / null / error', () async {
      mock((MethodCall call) async => false);
      expect(
        await BackupFileChannel().shareFile(path: '/x', fileName: 'x'),
        isFalse,
      );
      mock((MethodCall call) async => null);
      expect(
        await BackupFileChannel().shareFile(path: '/x', fileName: 'x'),
        isFalse,
      );
      mock((MethodCall call) async {
        throw PlatformException(code: 'SHARE_FAILED');
      });
      expect(
        await BackupFileChannel().shareFile(path: '/x', fileName: 'x'),
        isFalse,
      );
    });
  });

  group('pickFile', () {
    test('mengembalikan byte + nama file', () async {
      final Uint8List bytes = Uint8List.fromList(<int>[1, 2, 3]);
      mock((MethodCall call) async {
        expect(call.method, 'pickFile');
        return <String, Object?>{'bytes': bytes, 'name': 'salinan.json'};
      });
      final PickedFile? picked = await BackupFileChannel().pickFile();
      expect(picked, isNotNull);
      expect(picked!.bytes, bytes);
      expect(picked.name, 'salinan.json');
    });

    test('null bila pengguna membatalkan', () async {
      mock((MethodCall call) async => null);
      expect(await BackupFileChannel().pickFile(), isNull);
    });

    test('TOO_LARGE -> BackupException tooLarge', () async {
      mock((MethodCall call) async {
        throw PlatformException(code: 'TOO_LARGE');
      });
      await expectLater(
        BackupFileChannel().pickFile(),
        throwsA(
          isA<BackupException>().having(
            (BackupException e) => e.kind,
            'kind',
            BackupErrorKind.tooLarge,
          ),
        ),
      );
    });

    test('BUSY -> BackupFileException', () async {
      mock((MethodCall call) async {
        throw PlatformException(code: 'BUSY');
      });
      await expectLater(
        BackupFileChannel().pickFile(),
        throwsA(isA<BackupFileException>()),
      );
    });

    test('error platform lain -> BackupFileException', () async {
      mock((MethodCall call) async {
        throw PlatformException(code: 'READ_FAILED', message: 'rusak');
      });
      await expectLater(
        BackupFileChannel().pickFile(),
        throwsA(isA<BackupFileException>()),
      );
    });

    test('isi bukan byte -> BackupFileException', () async {
      mock((MethodCall call) async =>
          <String, Object?>{'bytes': 'bukan-byte', 'name': 'x.json'});
      await expectLater(
        BackupFileChannel().pickFile(),
        throwsA(isA<BackupFileException>()),
      );
    });
  });
}
