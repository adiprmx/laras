/// Pembukaan koneksi database produksi: malas + isolate latar.
///
/// File database tinggal di direktori dokumen app (`laras.sqlite`).
/// [NativeDatabase.createInBackground] menjalankan SQLite di isolate
/// latar, jadi query besar tidak menyendat UI thread. Pembukaan ditunda
/// sampai query pertama lewat [LazyDatabase], supaya start app tidak
/// menunggu I/O disk.
library;

import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';

import 'laras_database.dart';

/// Nama file database di perangkat.
const String kDatabaseFileName = 'laras.sqlite';

/// Buka database produksi. Gagal bila direktori dokumen tidak bisa dibaca;
/// pemanggil wajib menangani kegagalan itu (app tetap jalan tanpa library).
Future<LarasDatabase> openLarasDatabase() async {
  final LarasDatabase db = LarasDatabase(
    LazyDatabase(() async {
      final Directory dir = await getApplicationDocumentsDirectory();
      final File file = File('${dir.path}/$kDatabaseFileName');
      return NativeDatabase.createInBackground(file);
    }),
  );
  return db;
}
