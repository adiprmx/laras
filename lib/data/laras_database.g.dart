// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'laras_database.dart';

// ignore_for_file: type=lint
class LibrarySearch extends Table
    with
        TableInfo<LibrarySearch, LibrarySearchData>,
        VirtualTableInfo<LibrarySearch, LibrarySearchData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  LibrarySearch(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _kindMeta = const VerificationMeta('kind');
  late final GeneratedColumn<String> kind = GeneratedColumn<String>(
    'kind',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: '',
  );
  static const VerificationMeta _refIdMeta = const VerificationMeta('refId');
  late final GeneratedColumn<String> refId = GeneratedColumn<String>(
    'ref_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: '',
  );
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: '',
  );
  static const VerificationMeta _namesMeta = const VerificationMeta('names');
  late final GeneratedColumn<String> names = GeneratedColumn<String>(
    'names',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: '',
  );
  @override
  List<GeneratedColumn> get $columns => [kind, refId, title, names];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'library_search';
  @override
  VerificationContext validateIntegrity(
    Insertable<LibrarySearchData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('kind')) {
      context.handle(
        _kindMeta,
        kind.isAcceptableOrUnknown(data['kind']!, _kindMeta),
      );
    } else if (isInserting) {
      context.missing(_kindMeta);
    }
    if (data.containsKey('ref_id')) {
      context.handle(
        _refIdMeta,
        refId.isAcceptableOrUnknown(data['ref_id']!, _refIdMeta),
      );
    } else if (isInserting) {
      context.missing(_refIdMeta);
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('names')) {
      context.handle(
        _namesMeta,
        names.isAcceptableOrUnknown(data['names']!, _namesMeta),
      );
    } else if (isInserting) {
      context.missing(_namesMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => const {};
  @override
  LibrarySearchData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LibrarySearchData(
      kind: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}kind'],
      )!,
      refId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}ref_id'],
      )!,
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      )!,
      names: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}names'],
      )!,
    );
  }

  @override
  LibrarySearch createAlias(String alias) {
    return LibrarySearch(attachedDatabase, alias);
  }

  @override
  bool get dontWriteConstraints => true;
  @override
  String get moduleAndArgs =>
      'fts5(kind UNINDEXED, ref_id UNINDEXED, title, names, tokenize = \'unicode61\')';
}

class LibrarySearchData extends DataClass
    implements Insertable<LibrarySearchData> {
  final String kind;
  final String refId;
  final String title;
  final String names;
  const LibrarySearchData({
    required this.kind,
    required this.refId,
    required this.title,
    required this.names,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['kind'] = Variable<String>(kind);
    map['ref_id'] = Variable<String>(refId);
    map['title'] = Variable<String>(title);
    map['names'] = Variable<String>(names);
    return map;
  }

  LibrarySearchCompanion toCompanion(bool nullToAbsent) {
    return LibrarySearchCompanion(
      kind: Value(kind),
      refId: Value(refId),
      title: Value(title),
      names: Value(names),
    );
  }

  factory LibrarySearchData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LibrarySearchData(
      kind: serializer.fromJson<String>(json['kind']),
      refId: serializer.fromJson<String>(json['ref_id']),
      title: serializer.fromJson<String>(json['title']),
      names: serializer.fromJson<String>(json['names']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'kind': serializer.toJson<String>(kind),
      'ref_id': serializer.toJson<String>(refId),
      'title': serializer.toJson<String>(title),
      'names': serializer.toJson<String>(names),
    };
  }

  LibrarySearchData copyWith({
    String? kind,
    String? refId,
    String? title,
    String? names,
  }) => LibrarySearchData(
    kind: kind ?? this.kind,
    refId: refId ?? this.refId,
    title: title ?? this.title,
    names: names ?? this.names,
  );
  LibrarySearchData copyWithCompanion(LibrarySearchCompanion data) {
    return LibrarySearchData(
      kind: data.kind.present ? data.kind.value : this.kind,
      refId: data.refId.present ? data.refId.value : this.refId,
      title: data.title.present ? data.title.value : this.title,
      names: data.names.present ? data.names.value : this.names,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LibrarySearchData(')
          ..write('kind: $kind, ')
          ..write('refId: $refId, ')
          ..write('title: $title, ')
          ..write('names: $names')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(kind, refId, title, names);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LibrarySearchData &&
          other.kind == this.kind &&
          other.refId == this.refId &&
          other.title == this.title &&
          other.names == this.names);
}

class LibrarySearchCompanion extends UpdateCompanion<LibrarySearchData> {
  final Value<String> kind;
  final Value<String> refId;
  final Value<String> title;
  final Value<String> names;
  final Value<int> rowid;
  const LibrarySearchCompanion({
    this.kind = const Value.absent(),
    this.refId = const Value.absent(),
    this.title = const Value.absent(),
    this.names = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  LibrarySearchCompanion.insert({
    required String kind,
    required String refId,
    required String title,
    required String names,
    this.rowid = const Value.absent(),
  }) : kind = Value(kind),
       refId = Value(refId),
       title = Value(title),
       names = Value(names);
  static Insertable<LibrarySearchData> custom({
    Expression<String>? kind,
    Expression<String>? refId,
    Expression<String>? title,
    Expression<String>? names,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (kind != null) 'kind': kind,
      if (refId != null) 'ref_id': refId,
      if (title != null) 'title': title,
      if (names != null) 'names': names,
      if (rowid != null) 'rowid': rowid,
    });
  }

  LibrarySearchCompanion copyWith({
    Value<String>? kind,
    Value<String>? refId,
    Value<String>? title,
    Value<String>? names,
    Value<int>? rowid,
  }) {
    return LibrarySearchCompanion(
      kind: kind ?? this.kind,
      refId: refId ?? this.refId,
      title: title ?? this.title,
      names: names ?? this.names,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (kind.present) {
      map['kind'] = Variable<String>(kind.value);
    }
    if (refId.present) {
      map['ref_id'] = Variable<String>(refId.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (names.present) {
      map['names'] = Variable<String>(names.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LibrarySearchCompanion(')
          ..write('kind: $kind, ')
          ..write('refId: $refId, ')
          ..write('title: $title, ')
          ..write('names: $names, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $AlbumsTable extends Albums with TableInfo<$AlbumsTable, Album> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AlbumsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _yearMeta = const VerificationMeta('year');
  @override
  late final GeneratedColumn<int> year = GeneratedColumn<int>(
    'year',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _thumbnailUrlMeta = const VerificationMeta(
    'thumbnailUrl',
  );
  @override
  late final GeneratedColumn<String> thumbnailUrl = GeneratedColumn<String>(
    'thumbnail_url',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _likedMeta = const VerificationMeta('liked');
  @override
  late final GeneratedColumn<bool> liked = GeneratedColumn<bool>(
    'liked',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("liked" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _dateAddedMeta = const VerificationMeta(
    'dateAdded',
  );
  @override
  late final GeneratedColumn<DateTime> dateAdded = GeneratedColumn<DateTime>(
    'date_added',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    title,
    year,
    thumbnailUrl,
    liked,
    dateAdded,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'albums';
  @override
  VerificationContext validateIntegrity(
    Insertable<Album> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('year')) {
      context.handle(
        _yearMeta,
        year.isAcceptableOrUnknown(data['year']!, _yearMeta),
      );
    }
    if (data.containsKey('thumbnail_url')) {
      context.handle(
        _thumbnailUrlMeta,
        thumbnailUrl.isAcceptableOrUnknown(
          data['thumbnail_url']!,
          _thumbnailUrlMeta,
        ),
      );
    }
    if (data.containsKey('liked')) {
      context.handle(
        _likedMeta,
        liked.isAcceptableOrUnknown(data['liked']!, _likedMeta),
      );
    }
    if (data.containsKey('date_added')) {
      context.handle(
        _dateAddedMeta,
        dateAdded.isAcceptableOrUnknown(data['date_added']!, _dateAddedMeta),
      );
    } else if (isInserting) {
      context.missing(_dateAddedMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Album map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Album(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      )!,
      year: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}year'],
      ),
      thumbnailUrl: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}thumbnail_url'],
      ),
      liked: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}liked'],
      )!,
      dateAdded: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}date_added'],
      )!,
    );
  }

  @override
  $AlbumsTable createAlias(String alias) {
    return $AlbumsTable(attachedDatabase, alias);
  }
}

class Album extends DataClass implements Insertable<Album> {
  /// browseId album YouTube Music.
  final String id;
  final String title;
  final int? year;
  final String? thumbnailUrl;
  final bool liked;
  final DateTime dateAdded;
  const Album({
    required this.id,
    required this.title,
    this.year,
    this.thumbnailUrl,
    required this.liked,
    required this.dateAdded,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['title'] = Variable<String>(title);
    if (!nullToAbsent || year != null) {
      map['year'] = Variable<int>(year);
    }
    if (!nullToAbsent || thumbnailUrl != null) {
      map['thumbnail_url'] = Variable<String>(thumbnailUrl);
    }
    map['liked'] = Variable<bool>(liked);
    map['date_added'] = Variable<DateTime>(dateAdded);
    return map;
  }

  AlbumsCompanion toCompanion(bool nullToAbsent) {
    return AlbumsCompanion(
      id: Value(id),
      title: Value(title),
      year: year == null && nullToAbsent ? const Value.absent() : Value(year),
      thumbnailUrl: thumbnailUrl == null && nullToAbsent
          ? const Value.absent()
          : Value(thumbnailUrl),
      liked: Value(liked),
      dateAdded: Value(dateAdded),
    );
  }

  factory Album.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Album(
      id: serializer.fromJson<String>(json['id']),
      title: serializer.fromJson<String>(json['title']),
      year: serializer.fromJson<int?>(json['year']),
      thumbnailUrl: serializer.fromJson<String?>(json['thumbnailUrl']),
      liked: serializer.fromJson<bool>(json['liked']),
      dateAdded: serializer.fromJson<DateTime>(json['dateAdded']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'title': serializer.toJson<String>(title),
      'year': serializer.toJson<int?>(year),
      'thumbnailUrl': serializer.toJson<String?>(thumbnailUrl),
      'liked': serializer.toJson<bool>(liked),
      'dateAdded': serializer.toJson<DateTime>(dateAdded),
    };
  }

  Album copyWith({
    String? id,
    String? title,
    Value<int?> year = const Value.absent(),
    Value<String?> thumbnailUrl = const Value.absent(),
    bool? liked,
    DateTime? dateAdded,
  }) => Album(
    id: id ?? this.id,
    title: title ?? this.title,
    year: year.present ? year.value : this.year,
    thumbnailUrl: thumbnailUrl.present ? thumbnailUrl.value : this.thumbnailUrl,
    liked: liked ?? this.liked,
    dateAdded: dateAdded ?? this.dateAdded,
  );
  Album copyWithCompanion(AlbumsCompanion data) {
    return Album(
      id: data.id.present ? data.id.value : this.id,
      title: data.title.present ? data.title.value : this.title,
      year: data.year.present ? data.year.value : this.year,
      thumbnailUrl: data.thumbnailUrl.present
          ? data.thumbnailUrl.value
          : this.thumbnailUrl,
      liked: data.liked.present ? data.liked.value : this.liked,
      dateAdded: data.dateAdded.present ? data.dateAdded.value : this.dateAdded,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Album(')
          ..write('id: $id, ')
          ..write('title: $title, ')
          ..write('year: $year, ')
          ..write('thumbnailUrl: $thumbnailUrl, ')
          ..write('liked: $liked, ')
          ..write('dateAdded: $dateAdded')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, title, year, thumbnailUrl, liked, dateAdded);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Album &&
          other.id == this.id &&
          other.title == this.title &&
          other.year == this.year &&
          other.thumbnailUrl == this.thumbnailUrl &&
          other.liked == this.liked &&
          other.dateAdded == this.dateAdded);
}

class AlbumsCompanion extends UpdateCompanion<Album> {
  final Value<String> id;
  final Value<String> title;
  final Value<int?> year;
  final Value<String?> thumbnailUrl;
  final Value<bool> liked;
  final Value<DateTime> dateAdded;
  final Value<int> rowid;
  const AlbumsCompanion({
    this.id = const Value.absent(),
    this.title = const Value.absent(),
    this.year = const Value.absent(),
    this.thumbnailUrl = const Value.absent(),
    this.liked = const Value.absent(),
    this.dateAdded = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  AlbumsCompanion.insert({
    required String id,
    required String title,
    this.year = const Value.absent(),
    this.thumbnailUrl = const Value.absent(),
    this.liked = const Value.absent(),
    required DateTime dateAdded,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       title = Value(title),
       dateAdded = Value(dateAdded);
  static Insertable<Album> custom({
    Expression<String>? id,
    Expression<String>? title,
    Expression<int>? year,
    Expression<String>? thumbnailUrl,
    Expression<bool>? liked,
    Expression<DateTime>? dateAdded,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (title != null) 'title': title,
      if (year != null) 'year': year,
      if (thumbnailUrl != null) 'thumbnail_url': thumbnailUrl,
      if (liked != null) 'liked': liked,
      if (dateAdded != null) 'date_added': dateAdded,
      if (rowid != null) 'rowid': rowid,
    });
  }

  AlbumsCompanion copyWith({
    Value<String>? id,
    Value<String>? title,
    Value<int?>? year,
    Value<String?>? thumbnailUrl,
    Value<bool>? liked,
    Value<DateTime>? dateAdded,
    Value<int>? rowid,
  }) {
    return AlbumsCompanion(
      id: id ?? this.id,
      title: title ?? this.title,
      year: year ?? this.year,
      thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
      liked: liked ?? this.liked,
      dateAdded: dateAdded ?? this.dateAdded,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (year.present) {
      map['year'] = Variable<int>(year.value);
    }
    if (thumbnailUrl.present) {
      map['thumbnail_url'] = Variable<String>(thumbnailUrl.value);
    }
    if (liked.present) {
      map['liked'] = Variable<bool>(liked.value);
    }
    if (dateAdded.present) {
      map['date_added'] = Variable<DateTime>(dateAdded.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AlbumsCompanion(')
          ..write('id: $id, ')
          ..write('title: $title, ')
          ..write('year: $year, ')
          ..write('thumbnailUrl: $thumbnailUrl, ')
          ..write('liked: $liked, ')
          ..write('dateAdded: $dateAdded, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $FormatsTable extends Formats with TableInfo<$FormatsTable, Format> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $FormatsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _songIdMeta = const VerificationMeta('songId');
  @override
  late final GeneratedColumn<String> songId = GeneratedColumn<String>(
    'song_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES songs (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _itagMeta = const VerificationMeta('itag');
  @override
  late final GeneratedColumn<int> itag = GeneratedColumn<int>(
    'itag',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _mimeTypeMeta = const VerificationMeta(
    'mimeType',
  );
  @override
  late final GeneratedColumn<String> mimeType = GeneratedColumn<String>(
    'mime_type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _codecsMeta = const VerificationMeta('codecs');
  @override
  late final GeneratedColumn<String> codecs = GeneratedColumn<String>(
    'codecs',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _bitrateMeta = const VerificationMeta(
    'bitrate',
  );
  @override
  late final GeneratedColumn<int> bitrate = GeneratedColumn<int>(
    'bitrate',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _loudnessDbMeta = const VerificationMeta(
    'loudnessDb',
  );
  @override
  late final GeneratedColumn<double> loudnessDb = GeneratedColumn<double>(
    'loudness_db',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _contentLengthMeta = const VerificationMeta(
    'contentLength',
  );
  @override
  late final GeneratedColumn<int> contentLength = GeneratedColumn<int>(
    'content_length',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _lastModifiedMeta = const VerificationMeta(
    'lastModified',
  );
  @override
  late final GeneratedColumn<DateTime> lastModified = GeneratedColumn<DateTime>(
    'last_modified',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    songId,
    itag,
    mimeType,
    codecs,
    bitrate,
    loudnessDb,
    contentLength,
    lastModified,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'formats';
  @override
  VerificationContext validateIntegrity(
    Insertable<Format> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('song_id')) {
      context.handle(
        _songIdMeta,
        songId.isAcceptableOrUnknown(data['song_id']!, _songIdMeta),
      );
    } else if (isInserting) {
      context.missing(_songIdMeta);
    }
    if (data.containsKey('itag')) {
      context.handle(
        _itagMeta,
        itag.isAcceptableOrUnknown(data['itag']!, _itagMeta),
      );
    } else if (isInserting) {
      context.missing(_itagMeta);
    }
    if (data.containsKey('mime_type')) {
      context.handle(
        _mimeTypeMeta,
        mimeType.isAcceptableOrUnknown(data['mime_type']!, _mimeTypeMeta),
      );
    } else if (isInserting) {
      context.missing(_mimeTypeMeta);
    }
    if (data.containsKey('codecs')) {
      context.handle(
        _codecsMeta,
        codecs.isAcceptableOrUnknown(data['codecs']!, _codecsMeta),
      );
    }
    if (data.containsKey('bitrate')) {
      context.handle(
        _bitrateMeta,
        bitrate.isAcceptableOrUnknown(data['bitrate']!, _bitrateMeta),
      );
    }
    if (data.containsKey('loudness_db')) {
      context.handle(
        _loudnessDbMeta,
        loudnessDb.isAcceptableOrUnknown(data['loudness_db']!, _loudnessDbMeta),
      );
    }
    if (data.containsKey('content_length')) {
      context.handle(
        _contentLengthMeta,
        contentLength.isAcceptableOrUnknown(
          data['content_length']!,
          _contentLengthMeta,
        ),
      );
    }
    if (data.containsKey('last_modified')) {
      context.handle(
        _lastModifiedMeta,
        lastModified.isAcceptableOrUnknown(
          data['last_modified']!,
          _lastModifiedMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_lastModifiedMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Format map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Format(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      songId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}song_id'],
      )!,
      itag: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}itag'],
      )!,
      mimeType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}mime_type'],
      )!,
      codecs: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}codecs'],
      ),
      bitrate: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}bitrate'],
      ),
      loudnessDb: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}loudness_db'],
      ),
      contentLength: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}content_length'],
      ),
      lastModified: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}last_modified'],
      )!,
    );
  }

  @override
  $FormatsTable createAlias(String alias) {
    return $FormatsTable(attachedDatabase, alias);
  }
}

class Format extends DataClass implements Insertable<Format> {
  /// Gabungan videoId dan itag.
  final String id;
  final String songId;
  final int itag;
  final String mimeType;
  final String? codecs;
  final int? bitrate;
  final double? loudnessDb;
  final int? contentLength;
  final DateTime lastModified;
  const Format({
    required this.id,
    required this.songId,
    required this.itag,
    required this.mimeType,
    this.codecs,
    this.bitrate,
    this.loudnessDb,
    this.contentLength,
    required this.lastModified,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['song_id'] = Variable<String>(songId);
    map['itag'] = Variable<int>(itag);
    map['mime_type'] = Variable<String>(mimeType);
    if (!nullToAbsent || codecs != null) {
      map['codecs'] = Variable<String>(codecs);
    }
    if (!nullToAbsent || bitrate != null) {
      map['bitrate'] = Variable<int>(bitrate);
    }
    if (!nullToAbsent || loudnessDb != null) {
      map['loudness_db'] = Variable<double>(loudnessDb);
    }
    if (!nullToAbsent || contentLength != null) {
      map['content_length'] = Variable<int>(contentLength);
    }
    map['last_modified'] = Variable<DateTime>(lastModified);
    return map;
  }

  FormatsCompanion toCompanion(bool nullToAbsent) {
    return FormatsCompanion(
      id: Value(id),
      songId: Value(songId),
      itag: Value(itag),
      mimeType: Value(mimeType),
      codecs: codecs == null && nullToAbsent
          ? const Value.absent()
          : Value(codecs),
      bitrate: bitrate == null && nullToAbsent
          ? const Value.absent()
          : Value(bitrate),
      loudnessDb: loudnessDb == null && nullToAbsent
          ? const Value.absent()
          : Value(loudnessDb),
      contentLength: contentLength == null && nullToAbsent
          ? const Value.absent()
          : Value(contentLength),
      lastModified: Value(lastModified),
    );
  }

  factory Format.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Format(
      id: serializer.fromJson<String>(json['id']),
      songId: serializer.fromJson<String>(json['songId']),
      itag: serializer.fromJson<int>(json['itag']),
      mimeType: serializer.fromJson<String>(json['mimeType']),
      codecs: serializer.fromJson<String?>(json['codecs']),
      bitrate: serializer.fromJson<int?>(json['bitrate']),
      loudnessDb: serializer.fromJson<double?>(json['loudnessDb']),
      contentLength: serializer.fromJson<int?>(json['contentLength']),
      lastModified: serializer.fromJson<DateTime>(json['lastModified']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'songId': serializer.toJson<String>(songId),
      'itag': serializer.toJson<int>(itag),
      'mimeType': serializer.toJson<String>(mimeType),
      'codecs': serializer.toJson<String?>(codecs),
      'bitrate': serializer.toJson<int?>(bitrate),
      'loudnessDb': serializer.toJson<double?>(loudnessDb),
      'contentLength': serializer.toJson<int?>(contentLength),
      'lastModified': serializer.toJson<DateTime>(lastModified),
    };
  }

  Format copyWith({
    String? id,
    String? songId,
    int? itag,
    String? mimeType,
    Value<String?> codecs = const Value.absent(),
    Value<int?> bitrate = const Value.absent(),
    Value<double?> loudnessDb = const Value.absent(),
    Value<int?> contentLength = const Value.absent(),
    DateTime? lastModified,
  }) => Format(
    id: id ?? this.id,
    songId: songId ?? this.songId,
    itag: itag ?? this.itag,
    mimeType: mimeType ?? this.mimeType,
    codecs: codecs.present ? codecs.value : this.codecs,
    bitrate: bitrate.present ? bitrate.value : this.bitrate,
    loudnessDb: loudnessDb.present ? loudnessDb.value : this.loudnessDb,
    contentLength: contentLength.present
        ? contentLength.value
        : this.contentLength,
    lastModified: lastModified ?? this.lastModified,
  );
  Format copyWithCompanion(FormatsCompanion data) {
    return Format(
      id: data.id.present ? data.id.value : this.id,
      songId: data.songId.present ? data.songId.value : this.songId,
      itag: data.itag.present ? data.itag.value : this.itag,
      mimeType: data.mimeType.present ? data.mimeType.value : this.mimeType,
      codecs: data.codecs.present ? data.codecs.value : this.codecs,
      bitrate: data.bitrate.present ? data.bitrate.value : this.bitrate,
      loudnessDb: data.loudnessDb.present
          ? data.loudnessDb.value
          : this.loudnessDb,
      contentLength: data.contentLength.present
          ? data.contentLength.value
          : this.contentLength,
      lastModified: data.lastModified.present
          ? data.lastModified.value
          : this.lastModified,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Format(')
          ..write('id: $id, ')
          ..write('songId: $songId, ')
          ..write('itag: $itag, ')
          ..write('mimeType: $mimeType, ')
          ..write('codecs: $codecs, ')
          ..write('bitrate: $bitrate, ')
          ..write('loudnessDb: $loudnessDb, ')
          ..write('contentLength: $contentLength, ')
          ..write('lastModified: $lastModified')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    songId,
    itag,
    mimeType,
    codecs,
    bitrate,
    loudnessDb,
    contentLength,
    lastModified,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Format &&
          other.id == this.id &&
          other.songId == this.songId &&
          other.itag == this.itag &&
          other.mimeType == this.mimeType &&
          other.codecs == this.codecs &&
          other.bitrate == this.bitrate &&
          other.loudnessDb == this.loudnessDb &&
          other.contentLength == this.contentLength &&
          other.lastModified == this.lastModified);
}

class FormatsCompanion extends UpdateCompanion<Format> {
  final Value<String> id;
  final Value<String> songId;
  final Value<int> itag;
  final Value<String> mimeType;
  final Value<String?> codecs;
  final Value<int?> bitrate;
  final Value<double?> loudnessDb;
  final Value<int?> contentLength;
  final Value<DateTime> lastModified;
  final Value<int> rowid;
  const FormatsCompanion({
    this.id = const Value.absent(),
    this.songId = const Value.absent(),
    this.itag = const Value.absent(),
    this.mimeType = const Value.absent(),
    this.codecs = const Value.absent(),
    this.bitrate = const Value.absent(),
    this.loudnessDb = const Value.absent(),
    this.contentLength = const Value.absent(),
    this.lastModified = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  FormatsCompanion.insert({
    required String id,
    required String songId,
    required int itag,
    required String mimeType,
    this.codecs = const Value.absent(),
    this.bitrate = const Value.absent(),
    this.loudnessDb = const Value.absent(),
    this.contentLength = const Value.absent(),
    required DateTime lastModified,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       songId = Value(songId),
       itag = Value(itag),
       mimeType = Value(mimeType),
       lastModified = Value(lastModified);
  static Insertable<Format> custom({
    Expression<String>? id,
    Expression<String>? songId,
    Expression<int>? itag,
    Expression<String>? mimeType,
    Expression<String>? codecs,
    Expression<int>? bitrate,
    Expression<double>? loudnessDb,
    Expression<int>? contentLength,
    Expression<DateTime>? lastModified,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (songId != null) 'song_id': songId,
      if (itag != null) 'itag': itag,
      if (mimeType != null) 'mime_type': mimeType,
      if (codecs != null) 'codecs': codecs,
      if (bitrate != null) 'bitrate': bitrate,
      if (loudnessDb != null) 'loudness_db': loudnessDb,
      if (contentLength != null) 'content_length': contentLength,
      if (lastModified != null) 'last_modified': lastModified,
      if (rowid != null) 'rowid': rowid,
    });
  }

  FormatsCompanion copyWith({
    Value<String>? id,
    Value<String>? songId,
    Value<int>? itag,
    Value<String>? mimeType,
    Value<String?>? codecs,
    Value<int?>? bitrate,
    Value<double?>? loudnessDb,
    Value<int?>? contentLength,
    Value<DateTime>? lastModified,
    Value<int>? rowid,
  }) {
    return FormatsCompanion(
      id: id ?? this.id,
      songId: songId ?? this.songId,
      itag: itag ?? this.itag,
      mimeType: mimeType ?? this.mimeType,
      codecs: codecs ?? this.codecs,
      bitrate: bitrate ?? this.bitrate,
      loudnessDb: loudnessDb ?? this.loudnessDb,
      contentLength: contentLength ?? this.contentLength,
      lastModified: lastModified ?? this.lastModified,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (songId.present) {
      map['song_id'] = Variable<String>(songId.value);
    }
    if (itag.present) {
      map['itag'] = Variable<int>(itag.value);
    }
    if (mimeType.present) {
      map['mime_type'] = Variable<String>(mimeType.value);
    }
    if (codecs.present) {
      map['codecs'] = Variable<String>(codecs.value);
    }
    if (bitrate.present) {
      map['bitrate'] = Variable<int>(bitrate.value);
    }
    if (loudnessDb.present) {
      map['loudness_db'] = Variable<double>(loudnessDb.value);
    }
    if (contentLength.present) {
      map['content_length'] = Variable<int>(contentLength.value);
    }
    if (lastModified.present) {
      map['last_modified'] = Variable<DateTime>(lastModified.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('FormatsCompanion(')
          ..write('id: $id, ')
          ..write('songId: $songId, ')
          ..write('itag: $itag, ')
          ..write('mimeType: $mimeType, ')
          ..write('codecs: $codecs, ')
          ..write('bitrate: $bitrate, ')
          ..write('loudnessDb: $loudnessDb, ')
          ..write('contentLength: $contentLength, ')
          ..write('lastModified: $lastModified, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $SongsTable extends Songs with TableInfo<$SongsTable, Song> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SongsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _albumIdMeta = const VerificationMeta(
    'albumId',
  );
  @override
  late final GeneratedColumn<String> albumId = GeneratedColumn<String>(
    'album_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES albums (id) ON DELETE SET NULL',
    ),
  );
  static const VerificationMeta _durationSecondsMeta = const VerificationMeta(
    'durationSeconds',
  );
  @override
  late final GeneratedColumn<int> durationSeconds = GeneratedColumn<int>(
    'duration_seconds',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _thumbnailUrlMeta = const VerificationMeta(
    'thumbnailUrl',
  );
  @override
  late final GeneratedColumn<String> thumbnailUrl = GeneratedColumn<String>(
    'thumbnail_url',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _likedMeta = const VerificationMeta('liked');
  @override
  late final GeneratedColumn<bool> liked = GeneratedColumn<bool>(
    'liked',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("liked" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _totalPlayTimeMsMeta = const VerificationMeta(
    'totalPlayTimeMs',
  );
  @override
  late final GeneratedColumn<int> totalPlayTimeMs = GeneratedColumn<int>(
    'total_play_time_ms',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _inLibraryMeta = const VerificationMeta(
    'inLibrary',
  );
  @override
  late final GeneratedColumn<bool> inLibrary = GeneratedColumn<bool>(
    'in_library',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("in_library" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _dateAddedMeta = const VerificationMeta(
    'dateAdded',
  );
  @override
  late final GeneratedColumn<DateTime> dateAdded = GeneratedColumn<DateTime>(
    'date_added',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _dateModifiedMeta = const VerificationMeta(
    'dateModified',
  );
  @override
  late final GeneratedColumn<DateTime> dateModified = GeneratedColumn<DateTime>(
    'date_modified',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _downloadStateMeta = const VerificationMeta(
    'downloadState',
  );
  @override
  late final GeneratedColumn<int> downloadState = GeneratedColumn<int>(
    'download_state',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(DownloadState.notDownloaded),
  );
  static const VerificationMeta _filePathMeta = const VerificationMeta(
    'filePath',
  );
  @override
  late final GeneratedColumn<String> filePath = GeneratedColumn<String>(
    'file_path',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _fileSizeBytesMeta = const VerificationMeta(
    'fileSizeBytes',
  );
  @override
  late final GeneratedColumn<int> fileSizeBytes = GeneratedColumn<int>(
    'file_size_bytes',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _downloadedAtMeta = const VerificationMeta(
    'downloadedAt',
  );
  @override
  late final GeneratedColumn<DateTime> downloadedAt = GeneratedColumn<DateTime>(
    'downloaded_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _formatIdMeta = const VerificationMeta(
    'formatId',
  );
  @override
  late final GeneratedColumn<String> formatId = GeneratedColumn<String>(
    'format_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES formats (id) ON DELETE SET NULL',
    ),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    title,
    albumId,
    durationSeconds,
    thumbnailUrl,
    liked,
    totalPlayTimeMs,
    inLibrary,
    dateAdded,
    dateModified,
    downloadState,
    filePath,
    fileSizeBytes,
    downloadedAt,
    formatId,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'songs';
  @override
  VerificationContext validateIntegrity(
    Insertable<Song> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('album_id')) {
      context.handle(
        _albumIdMeta,
        albumId.isAcceptableOrUnknown(data['album_id']!, _albumIdMeta),
      );
    }
    if (data.containsKey('duration_seconds')) {
      context.handle(
        _durationSecondsMeta,
        durationSeconds.isAcceptableOrUnknown(
          data['duration_seconds']!,
          _durationSecondsMeta,
        ),
      );
    }
    if (data.containsKey('thumbnail_url')) {
      context.handle(
        _thumbnailUrlMeta,
        thumbnailUrl.isAcceptableOrUnknown(
          data['thumbnail_url']!,
          _thumbnailUrlMeta,
        ),
      );
    }
    if (data.containsKey('liked')) {
      context.handle(
        _likedMeta,
        liked.isAcceptableOrUnknown(data['liked']!, _likedMeta),
      );
    }
    if (data.containsKey('total_play_time_ms')) {
      context.handle(
        _totalPlayTimeMsMeta,
        totalPlayTimeMs.isAcceptableOrUnknown(
          data['total_play_time_ms']!,
          _totalPlayTimeMsMeta,
        ),
      );
    }
    if (data.containsKey('in_library')) {
      context.handle(
        _inLibraryMeta,
        inLibrary.isAcceptableOrUnknown(data['in_library']!, _inLibraryMeta),
      );
    }
    if (data.containsKey('date_added')) {
      context.handle(
        _dateAddedMeta,
        dateAdded.isAcceptableOrUnknown(data['date_added']!, _dateAddedMeta),
      );
    } else if (isInserting) {
      context.missing(_dateAddedMeta);
    }
    if (data.containsKey('date_modified')) {
      context.handle(
        _dateModifiedMeta,
        dateModified.isAcceptableOrUnknown(
          data['date_modified']!,
          _dateModifiedMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_dateModifiedMeta);
    }
    if (data.containsKey('download_state')) {
      context.handle(
        _downloadStateMeta,
        downloadState.isAcceptableOrUnknown(
          data['download_state']!,
          _downloadStateMeta,
        ),
      );
    }
    if (data.containsKey('file_path')) {
      context.handle(
        _filePathMeta,
        filePath.isAcceptableOrUnknown(data['file_path']!, _filePathMeta),
      );
    }
    if (data.containsKey('file_size_bytes')) {
      context.handle(
        _fileSizeBytesMeta,
        fileSizeBytes.isAcceptableOrUnknown(
          data['file_size_bytes']!,
          _fileSizeBytesMeta,
        ),
      );
    }
    if (data.containsKey('downloaded_at')) {
      context.handle(
        _downloadedAtMeta,
        downloadedAt.isAcceptableOrUnknown(
          data['downloaded_at']!,
          _downloadedAtMeta,
        ),
      );
    }
    if (data.containsKey('format_id')) {
      context.handle(
        _formatIdMeta,
        formatId.isAcceptableOrUnknown(data['format_id']!, _formatIdMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Song map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Song(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      )!,
      albumId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}album_id'],
      ),
      durationSeconds: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}duration_seconds'],
      ),
      thumbnailUrl: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}thumbnail_url'],
      ),
      liked: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}liked'],
      )!,
      totalPlayTimeMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}total_play_time_ms'],
      )!,
      inLibrary: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}in_library'],
      )!,
      dateAdded: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}date_added'],
      )!,
      dateModified: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}date_modified'],
      )!,
      downloadState: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}download_state'],
      )!,
      filePath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}file_path'],
      ),
      fileSizeBytes: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}file_size_bytes'],
      ),
      downloadedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}downloaded_at'],
      ),
      formatId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}format_id'],
      ),
    );
  }

  @override
  $SongsTable createAlias(String alias) {
    return $SongsTable(attachedDatabase, alias);
  }
}

class Song extends DataClass implements Insertable<Song> {
  final String id;
  final String title;
  final String? albumId;
  final int? durationSeconds;
  final String? thumbnailUrl;
  final bool liked;
  final int totalPlayTimeMs;
  final bool inLibrary;
  final DateTime dateAdded;
  final DateTime dateModified;
  final int downloadState;

  /// Path RELATIF terhadap direktori unduhan, bukan path absolut.
  final String? filePath;
  final int? fileSizeBytes;
  final DateTime? downloadedAt;
  final String? formatId;
  const Song({
    required this.id,
    required this.title,
    this.albumId,
    this.durationSeconds,
    this.thumbnailUrl,
    required this.liked,
    required this.totalPlayTimeMs,
    required this.inLibrary,
    required this.dateAdded,
    required this.dateModified,
    required this.downloadState,
    this.filePath,
    this.fileSizeBytes,
    this.downloadedAt,
    this.formatId,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['title'] = Variable<String>(title);
    if (!nullToAbsent || albumId != null) {
      map['album_id'] = Variable<String>(albumId);
    }
    if (!nullToAbsent || durationSeconds != null) {
      map['duration_seconds'] = Variable<int>(durationSeconds);
    }
    if (!nullToAbsent || thumbnailUrl != null) {
      map['thumbnail_url'] = Variable<String>(thumbnailUrl);
    }
    map['liked'] = Variable<bool>(liked);
    map['total_play_time_ms'] = Variable<int>(totalPlayTimeMs);
    map['in_library'] = Variable<bool>(inLibrary);
    map['date_added'] = Variable<DateTime>(dateAdded);
    map['date_modified'] = Variable<DateTime>(dateModified);
    map['download_state'] = Variable<int>(downloadState);
    if (!nullToAbsent || filePath != null) {
      map['file_path'] = Variable<String>(filePath);
    }
    if (!nullToAbsent || fileSizeBytes != null) {
      map['file_size_bytes'] = Variable<int>(fileSizeBytes);
    }
    if (!nullToAbsent || downloadedAt != null) {
      map['downloaded_at'] = Variable<DateTime>(downloadedAt);
    }
    if (!nullToAbsent || formatId != null) {
      map['format_id'] = Variable<String>(formatId);
    }
    return map;
  }

  SongsCompanion toCompanion(bool nullToAbsent) {
    return SongsCompanion(
      id: Value(id),
      title: Value(title),
      albumId: albumId == null && nullToAbsent
          ? const Value.absent()
          : Value(albumId),
      durationSeconds: durationSeconds == null && nullToAbsent
          ? const Value.absent()
          : Value(durationSeconds),
      thumbnailUrl: thumbnailUrl == null && nullToAbsent
          ? const Value.absent()
          : Value(thumbnailUrl),
      liked: Value(liked),
      totalPlayTimeMs: Value(totalPlayTimeMs),
      inLibrary: Value(inLibrary),
      dateAdded: Value(dateAdded),
      dateModified: Value(dateModified),
      downloadState: Value(downloadState),
      filePath: filePath == null && nullToAbsent
          ? const Value.absent()
          : Value(filePath),
      fileSizeBytes: fileSizeBytes == null && nullToAbsent
          ? const Value.absent()
          : Value(fileSizeBytes),
      downloadedAt: downloadedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(downloadedAt),
      formatId: formatId == null && nullToAbsent
          ? const Value.absent()
          : Value(formatId),
    );
  }

  factory Song.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Song(
      id: serializer.fromJson<String>(json['id']),
      title: serializer.fromJson<String>(json['title']),
      albumId: serializer.fromJson<String?>(json['albumId']),
      durationSeconds: serializer.fromJson<int?>(json['durationSeconds']),
      thumbnailUrl: serializer.fromJson<String?>(json['thumbnailUrl']),
      liked: serializer.fromJson<bool>(json['liked']),
      totalPlayTimeMs: serializer.fromJson<int>(json['totalPlayTimeMs']),
      inLibrary: serializer.fromJson<bool>(json['inLibrary']),
      dateAdded: serializer.fromJson<DateTime>(json['dateAdded']),
      dateModified: serializer.fromJson<DateTime>(json['dateModified']),
      downloadState: serializer.fromJson<int>(json['downloadState']),
      filePath: serializer.fromJson<String?>(json['filePath']),
      fileSizeBytes: serializer.fromJson<int?>(json['fileSizeBytes']),
      downloadedAt: serializer.fromJson<DateTime?>(json['downloadedAt']),
      formatId: serializer.fromJson<String?>(json['formatId']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'title': serializer.toJson<String>(title),
      'albumId': serializer.toJson<String?>(albumId),
      'durationSeconds': serializer.toJson<int?>(durationSeconds),
      'thumbnailUrl': serializer.toJson<String?>(thumbnailUrl),
      'liked': serializer.toJson<bool>(liked),
      'totalPlayTimeMs': serializer.toJson<int>(totalPlayTimeMs),
      'inLibrary': serializer.toJson<bool>(inLibrary),
      'dateAdded': serializer.toJson<DateTime>(dateAdded),
      'dateModified': serializer.toJson<DateTime>(dateModified),
      'downloadState': serializer.toJson<int>(downloadState),
      'filePath': serializer.toJson<String?>(filePath),
      'fileSizeBytes': serializer.toJson<int?>(fileSizeBytes),
      'downloadedAt': serializer.toJson<DateTime?>(downloadedAt),
      'formatId': serializer.toJson<String?>(formatId),
    };
  }

  Song copyWith({
    String? id,
    String? title,
    Value<String?> albumId = const Value.absent(),
    Value<int?> durationSeconds = const Value.absent(),
    Value<String?> thumbnailUrl = const Value.absent(),
    bool? liked,
    int? totalPlayTimeMs,
    bool? inLibrary,
    DateTime? dateAdded,
    DateTime? dateModified,
    int? downloadState,
    Value<String?> filePath = const Value.absent(),
    Value<int?> fileSizeBytes = const Value.absent(),
    Value<DateTime?> downloadedAt = const Value.absent(),
    Value<String?> formatId = const Value.absent(),
  }) => Song(
    id: id ?? this.id,
    title: title ?? this.title,
    albumId: albumId.present ? albumId.value : this.albumId,
    durationSeconds: durationSeconds.present
        ? durationSeconds.value
        : this.durationSeconds,
    thumbnailUrl: thumbnailUrl.present ? thumbnailUrl.value : this.thumbnailUrl,
    liked: liked ?? this.liked,
    totalPlayTimeMs: totalPlayTimeMs ?? this.totalPlayTimeMs,
    inLibrary: inLibrary ?? this.inLibrary,
    dateAdded: dateAdded ?? this.dateAdded,
    dateModified: dateModified ?? this.dateModified,
    downloadState: downloadState ?? this.downloadState,
    filePath: filePath.present ? filePath.value : this.filePath,
    fileSizeBytes: fileSizeBytes.present
        ? fileSizeBytes.value
        : this.fileSizeBytes,
    downloadedAt: downloadedAt.present ? downloadedAt.value : this.downloadedAt,
    formatId: formatId.present ? formatId.value : this.formatId,
  );
  Song copyWithCompanion(SongsCompanion data) {
    return Song(
      id: data.id.present ? data.id.value : this.id,
      title: data.title.present ? data.title.value : this.title,
      albumId: data.albumId.present ? data.albumId.value : this.albumId,
      durationSeconds: data.durationSeconds.present
          ? data.durationSeconds.value
          : this.durationSeconds,
      thumbnailUrl: data.thumbnailUrl.present
          ? data.thumbnailUrl.value
          : this.thumbnailUrl,
      liked: data.liked.present ? data.liked.value : this.liked,
      totalPlayTimeMs: data.totalPlayTimeMs.present
          ? data.totalPlayTimeMs.value
          : this.totalPlayTimeMs,
      inLibrary: data.inLibrary.present ? data.inLibrary.value : this.inLibrary,
      dateAdded: data.dateAdded.present ? data.dateAdded.value : this.dateAdded,
      dateModified: data.dateModified.present
          ? data.dateModified.value
          : this.dateModified,
      downloadState: data.downloadState.present
          ? data.downloadState.value
          : this.downloadState,
      filePath: data.filePath.present ? data.filePath.value : this.filePath,
      fileSizeBytes: data.fileSizeBytes.present
          ? data.fileSizeBytes.value
          : this.fileSizeBytes,
      downloadedAt: data.downloadedAt.present
          ? data.downloadedAt.value
          : this.downloadedAt,
      formatId: data.formatId.present ? data.formatId.value : this.formatId,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Song(')
          ..write('id: $id, ')
          ..write('title: $title, ')
          ..write('albumId: $albumId, ')
          ..write('durationSeconds: $durationSeconds, ')
          ..write('thumbnailUrl: $thumbnailUrl, ')
          ..write('liked: $liked, ')
          ..write('totalPlayTimeMs: $totalPlayTimeMs, ')
          ..write('inLibrary: $inLibrary, ')
          ..write('dateAdded: $dateAdded, ')
          ..write('dateModified: $dateModified, ')
          ..write('downloadState: $downloadState, ')
          ..write('filePath: $filePath, ')
          ..write('fileSizeBytes: $fileSizeBytes, ')
          ..write('downloadedAt: $downloadedAt, ')
          ..write('formatId: $formatId')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    title,
    albumId,
    durationSeconds,
    thumbnailUrl,
    liked,
    totalPlayTimeMs,
    inLibrary,
    dateAdded,
    dateModified,
    downloadState,
    filePath,
    fileSizeBytes,
    downloadedAt,
    formatId,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Song &&
          other.id == this.id &&
          other.title == this.title &&
          other.albumId == this.albumId &&
          other.durationSeconds == this.durationSeconds &&
          other.thumbnailUrl == this.thumbnailUrl &&
          other.liked == this.liked &&
          other.totalPlayTimeMs == this.totalPlayTimeMs &&
          other.inLibrary == this.inLibrary &&
          other.dateAdded == this.dateAdded &&
          other.dateModified == this.dateModified &&
          other.downloadState == this.downloadState &&
          other.filePath == this.filePath &&
          other.fileSizeBytes == this.fileSizeBytes &&
          other.downloadedAt == this.downloadedAt &&
          other.formatId == this.formatId);
}

class SongsCompanion extends UpdateCompanion<Song> {
  final Value<String> id;
  final Value<String> title;
  final Value<String?> albumId;
  final Value<int?> durationSeconds;
  final Value<String?> thumbnailUrl;
  final Value<bool> liked;
  final Value<int> totalPlayTimeMs;
  final Value<bool> inLibrary;
  final Value<DateTime> dateAdded;
  final Value<DateTime> dateModified;
  final Value<int> downloadState;
  final Value<String?> filePath;
  final Value<int?> fileSizeBytes;
  final Value<DateTime?> downloadedAt;
  final Value<String?> formatId;
  final Value<int> rowid;
  const SongsCompanion({
    this.id = const Value.absent(),
    this.title = const Value.absent(),
    this.albumId = const Value.absent(),
    this.durationSeconds = const Value.absent(),
    this.thumbnailUrl = const Value.absent(),
    this.liked = const Value.absent(),
    this.totalPlayTimeMs = const Value.absent(),
    this.inLibrary = const Value.absent(),
    this.dateAdded = const Value.absent(),
    this.dateModified = const Value.absent(),
    this.downloadState = const Value.absent(),
    this.filePath = const Value.absent(),
    this.fileSizeBytes = const Value.absent(),
    this.downloadedAt = const Value.absent(),
    this.formatId = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SongsCompanion.insert({
    required String id,
    required String title,
    this.albumId = const Value.absent(),
    this.durationSeconds = const Value.absent(),
    this.thumbnailUrl = const Value.absent(),
    this.liked = const Value.absent(),
    this.totalPlayTimeMs = const Value.absent(),
    this.inLibrary = const Value.absent(),
    required DateTime dateAdded,
    required DateTime dateModified,
    this.downloadState = const Value.absent(),
    this.filePath = const Value.absent(),
    this.fileSizeBytes = const Value.absent(),
    this.downloadedAt = const Value.absent(),
    this.formatId = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       title = Value(title),
       dateAdded = Value(dateAdded),
       dateModified = Value(dateModified);
  static Insertable<Song> custom({
    Expression<String>? id,
    Expression<String>? title,
    Expression<String>? albumId,
    Expression<int>? durationSeconds,
    Expression<String>? thumbnailUrl,
    Expression<bool>? liked,
    Expression<int>? totalPlayTimeMs,
    Expression<bool>? inLibrary,
    Expression<DateTime>? dateAdded,
    Expression<DateTime>? dateModified,
    Expression<int>? downloadState,
    Expression<String>? filePath,
    Expression<int>? fileSizeBytes,
    Expression<DateTime>? downloadedAt,
    Expression<String>? formatId,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (title != null) 'title': title,
      if (albumId != null) 'album_id': albumId,
      if (durationSeconds != null) 'duration_seconds': durationSeconds,
      if (thumbnailUrl != null) 'thumbnail_url': thumbnailUrl,
      if (liked != null) 'liked': liked,
      if (totalPlayTimeMs != null) 'total_play_time_ms': totalPlayTimeMs,
      if (inLibrary != null) 'in_library': inLibrary,
      if (dateAdded != null) 'date_added': dateAdded,
      if (dateModified != null) 'date_modified': dateModified,
      if (downloadState != null) 'download_state': downloadState,
      if (filePath != null) 'file_path': filePath,
      if (fileSizeBytes != null) 'file_size_bytes': fileSizeBytes,
      if (downloadedAt != null) 'downloaded_at': downloadedAt,
      if (formatId != null) 'format_id': formatId,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SongsCompanion copyWith({
    Value<String>? id,
    Value<String>? title,
    Value<String?>? albumId,
    Value<int?>? durationSeconds,
    Value<String?>? thumbnailUrl,
    Value<bool>? liked,
    Value<int>? totalPlayTimeMs,
    Value<bool>? inLibrary,
    Value<DateTime>? dateAdded,
    Value<DateTime>? dateModified,
    Value<int>? downloadState,
    Value<String?>? filePath,
    Value<int?>? fileSizeBytes,
    Value<DateTime?>? downloadedAt,
    Value<String?>? formatId,
    Value<int>? rowid,
  }) {
    return SongsCompanion(
      id: id ?? this.id,
      title: title ?? this.title,
      albumId: albumId ?? this.albumId,
      durationSeconds: durationSeconds ?? this.durationSeconds,
      thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
      liked: liked ?? this.liked,
      totalPlayTimeMs: totalPlayTimeMs ?? this.totalPlayTimeMs,
      inLibrary: inLibrary ?? this.inLibrary,
      dateAdded: dateAdded ?? this.dateAdded,
      dateModified: dateModified ?? this.dateModified,
      downloadState: downloadState ?? this.downloadState,
      filePath: filePath ?? this.filePath,
      fileSizeBytes: fileSizeBytes ?? this.fileSizeBytes,
      downloadedAt: downloadedAt ?? this.downloadedAt,
      formatId: formatId ?? this.formatId,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (albumId.present) {
      map['album_id'] = Variable<String>(albumId.value);
    }
    if (durationSeconds.present) {
      map['duration_seconds'] = Variable<int>(durationSeconds.value);
    }
    if (thumbnailUrl.present) {
      map['thumbnail_url'] = Variable<String>(thumbnailUrl.value);
    }
    if (liked.present) {
      map['liked'] = Variable<bool>(liked.value);
    }
    if (totalPlayTimeMs.present) {
      map['total_play_time_ms'] = Variable<int>(totalPlayTimeMs.value);
    }
    if (inLibrary.present) {
      map['in_library'] = Variable<bool>(inLibrary.value);
    }
    if (dateAdded.present) {
      map['date_added'] = Variable<DateTime>(dateAdded.value);
    }
    if (dateModified.present) {
      map['date_modified'] = Variable<DateTime>(dateModified.value);
    }
    if (downloadState.present) {
      map['download_state'] = Variable<int>(downloadState.value);
    }
    if (filePath.present) {
      map['file_path'] = Variable<String>(filePath.value);
    }
    if (fileSizeBytes.present) {
      map['file_size_bytes'] = Variable<int>(fileSizeBytes.value);
    }
    if (downloadedAt.present) {
      map['downloaded_at'] = Variable<DateTime>(downloadedAt.value);
    }
    if (formatId.present) {
      map['format_id'] = Variable<String>(formatId.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SongsCompanion(')
          ..write('id: $id, ')
          ..write('title: $title, ')
          ..write('albumId: $albumId, ')
          ..write('durationSeconds: $durationSeconds, ')
          ..write('thumbnailUrl: $thumbnailUrl, ')
          ..write('liked: $liked, ')
          ..write('totalPlayTimeMs: $totalPlayTimeMs, ')
          ..write('inLibrary: $inLibrary, ')
          ..write('dateAdded: $dateAdded, ')
          ..write('dateModified: $dateModified, ')
          ..write('downloadState: $downloadState, ')
          ..write('filePath: $filePath, ')
          ..write('fileSizeBytes: $fileSizeBytes, ')
          ..write('downloadedAt: $downloadedAt, ')
          ..write('formatId: $formatId, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ArtistsTable extends Artists with TableInfo<$ArtistsTable, Artist> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ArtistsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _thumbnailUrlMeta = const VerificationMeta(
    'thumbnailUrl',
  );
  @override
  late final GeneratedColumn<String> thumbnailUrl = GeneratedColumn<String>(
    'thumbnail_url',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _likedMeta = const VerificationMeta('liked');
  @override
  late final GeneratedColumn<bool> liked = GeneratedColumn<bool>(
    'liked',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("liked" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _dateAddedMeta = const VerificationMeta(
    'dateAdded',
  );
  @override
  late final GeneratedColumn<DateTime> dateAdded = GeneratedColumn<DateTime>(
    'date_added',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    name,
    thumbnailUrl,
    liked,
    dateAdded,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'artists';
  @override
  VerificationContext validateIntegrity(
    Insertable<Artist> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('thumbnail_url')) {
      context.handle(
        _thumbnailUrlMeta,
        thumbnailUrl.isAcceptableOrUnknown(
          data['thumbnail_url']!,
          _thumbnailUrlMeta,
        ),
      );
    }
    if (data.containsKey('liked')) {
      context.handle(
        _likedMeta,
        liked.isAcceptableOrUnknown(data['liked']!, _likedMeta),
      );
    }
    if (data.containsKey('date_added')) {
      context.handle(
        _dateAddedMeta,
        dateAdded.isAcceptableOrUnknown(data['date_added']!, _dateAddedMeta),
      );
    } else if (isInserting) {
      context.missing(_dateAddedMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Artist map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Artist(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      thumbnailUrl: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}thumbnail_url'],
      ),
      liked: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}liked'],
      )!,
      dateAdded: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}date_added'],
      )!,
    );
  }

  @override
  $ArtistsTable createAlias(String alias) {
    return $ArtistsTable(attachedDatabase, alias);
  }
}

class Artist extends DataClass implements Insertable<Artist> {
  final String id;
  final String name;
  final String? thumbnailUrl;
  final bool liked;
  final DateTime dateAdded;
  const Artist({
    required this.id,
    required this.name,
    this.thumbnailUrl,
    required this.liked,
    required this.dateAdded,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['name'] = Variable<String>(name);
    if (!nullToAbsent || thumbnailUrl != null) {
      map['thumbnail_url'] = Variable<String>(thumbnailUrl);
    }
    map['liked'] = Variable<bool>(liked);
    map['date_added'] = Variable<DateTime>(dateAdded);
    return map;
  }

  ArtistsCompanion toCompanion(bool nullToAbsent) {
    return ArtistsCompanion(
      id: Value(id),
      name: Value(name),
      thumbnailUrl: thumbnailUrl == null && nullToAbsent
          ? const Value.absent()
          : Value(thumbnailUrl),
      liked: Value(liked),
      dateAdded: Value(dateAdded),
    );
  }

  factory Artist.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Artist(
      id: serializer.fromJson<String>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      thumbnailUrl: serializer.fromJson<String?>(json['thumbnailUrl']),
      liked: serializer.fromJson<bool>(json['liked']),
      dateAdded: serializer.fromJson<DateTime>(json['dateAdded']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'name': serializer.toJson<String>(name),
      'thumbnailUrl': serializer.toJson<String?>(thumbnailUrl),
      'liked': serializer.toJson<bool>(liked),
      'dateAdded': serializer.toJson<DateTime>(dateAdded),
    };
  }

  Artist copyWith({
    String? id,
    String? name,
    Value<String?> thumbnailUrl = const Value.absent(),
    bool? liked,
    DateTime? dateAdded,
  }) => Artist(
    id: id ?? this.id,
    name: name ?? this.name,
    thumbnailUrl: thumbnailUrl.present ? thumbnailUrl.value : this.thumbnailUrl,
    liked: liked ?? this.liked,
    dateAdded: dateAdded ?? this.dateAdded,
  );
  Artist copyWithCompanion(ArtistsCompanion data) {
    return Artist(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      thumbnailUrl: data.thumbnailUrl.present
          ? data.thumbnailUrl.value
          : this.thumbnailUrl,
      liked: data.liked.present ? data.liked.value : this.liked,
      dateAdded: data.dateAdded.present ? data.dateAdded.value : this.dateAdded,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Artist(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('thumbnailUrl: $thumbnailUrl, ')
          ..write('liked: $liked, ')
          ..write('dateAdded: $dateAdded')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, name, thumbnailUrl, liked, dateAdded);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Artist &&
          other.id == this.id &&
          other.name == this.name &&
          other.thumbnailUrl == this.thumbnailUrl &&
          other.liked == this.liked &&
          other.dateAdded == this.dateAdded);
}

class ArtistsCompanion extends UpdateCompanion<Artist> {
  final Value<String> id;
  final Value<String> name;
  final Value<String?> thumbnailUrl;
  final Value<bool> liked;
  final Value<DateTime> dateAdded;
  final Value<int> rowid;
  const ArtistsCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.thumbnailUrl = const Value.absent(),
    this.liked = const Value.absent(),
    this.dateAdded = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ArtistsCompanion.insert({
    required String id,
    required String name,
    this.thumbnailUrl = const Value.absent(),
    this.liked = const Value.absent(),
    required DateTime dateAdded,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       name = Value(name),
       dateAdded = Value(dateAdded);
  static Insertable<Artist> custom({
    Expression<String>? id,
    Expression<String>? name,
    Expression<String>? thumbnailUrl,
    Expression<bool>? liked,
    Expression<DateTime>? dateAdded,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (thumbnailUrl != null) 'thumbnail_url': thumbnailUrl,
      if (liked != null) 'liked': liked,
      if (dateAdded != null) 'date_added': dateAdded,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ArtistsCompanion copyWith({
    Value<String>? id,
    Value<String>? name,
    Value<String?>? thumbnailUrl,
    Value<bool>? liked,
    Value<DateTime>? dateAdded,
    Value<int>? rowid,
  }) {
    return ArtistsCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
      liked: liked ?? this.liked,
      dateAdded: dateAdded ?? this.dateAdded,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (thumbnailUrl.present) {
      map['thumbnail_url'] = Variable<String>(thumbnailUrl.value);
    }
    if (liked.present) {
      map['liked'] = Variable<bool>(liked.value);
    }
    if (dateAdded.present) {
      map['date_added'] = Variable<DateTime>(dateAdded.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ArtistsCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('thumbnailUrl: $thumbnailUrl, ')
          ..write('liked: $liked, ')
          ..write('dateAdded: $dateAdded, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $SongArtistsTable extends SongArtists
    with TableInfo<$SongArtistsTable, SongArtist> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SongArtistsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _songIdMeta = const VerificationMeta('songId');
  @override
  late final GeneratedColumn<String> songId = GeneratedColumn<String>(
    'song_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES songs (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _artistIdMeta = const VerificationMeta(
    'artistId',
  );
  @override
  late final GeneratedColumn<String> artistId = GeneratedColumn<String>(
    'artist_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES artists (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _positionMeta = const VerificationMeta(
    'position',
  );
  @override
  late final GeneratedColumn<int> position = GeneratedColumn<int>(
    'position',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [songId, artistId, position];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'song_artists';
  @override
  VerificationContext validateIntegrity(
    Insertable<SongArtist> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('song_id')) {
      context.handle(
        _songIdMeta,
        songId.isAcceptableOrUnknown(data['song_id']!, _songIdMeta),
      );
    } else if (isInserting) {
      context.missing(_songIdMeta);
    }
    if (data.containsKey('artist_id')) {
      context.handle(
        _artistIdMeta,
        artistId.isAcceptableOrUnknown(data['artist_id']!, _artistIdMeta),
      );
    } else if (isInserting) {
      context.missing(_artistIdMeta);
    }
    if (data.containsKey('position')) {
      context.handle(
        _positionMeta,
        position.isAcceptableOrUnknown(data['position']!, _positionMeta),
      );
    } else if (isInserting) {
      context.missing(_positionMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {songId, artistId};
  @override
  SongArtist map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SongArtist(
      songId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}song_id'],
      )!,
      artistId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}artist_id'],
      )!,
      position: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}position'],
      )!,
    );
  }

  @override
  $SongArtistsTable createAlias(String alias) {
    return $SongArtistsTable(attachedDatabase, alias);
  }
}

class SongArtist extends DataClass implements Insertable<SongArtist> {
  final String songId;
  final String artistId;
  final int position;
  const SongArtist({
    required this.songId,
    required this.artistId,
    required this.position,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['song_id'] = Variable<String>(songId);
    map['artist_id'] = Variable<String>(artistId);
    map['position'] = Variable<int>(position);
    return map;
  }

  SongArtistsCompanion toCompanion(bool nullToAbsent) {
    return SongArtistsCompanion(
      songId: Value(songId),
      artistId: Value(artistId),
      position: Value(position),
    );
  }

  factory SongArtist.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SongArtist(
      songId: serializer.fromJson<String>(json['songId']),
      artistId: serializer.fromJson<String>(json['artistId']),
      position: serializer.fromJson<int>(json['position']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'songId': serializer.toJson<String>(songId),
      'artistId': serializer.toJson<String>(artistId),
      'position': serializer.toJson<int>(position),
    };
  }

  SongArtist copyWith({String? songId, String? artistId, int? position}) =>
      SongArtist(
        songId: songId ?? this.songId,
        artistId: artistId ?? this.artistId,
        position: position ?? this.position,
      );
  SongArtist copyWithCompanion(SongArtistsCompanion data) {
    return SongArtist(
      songId: data.songId.present ? data.songId.value : this.songId,
      artistId: data.artistId.present ? data.artistId.value : this.artistId,
      position: data.position.present ? data.position.value : this.position,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SongArtist(')
          ..write('songId: $songId, ')
          ..write('artistId: $artistId, ')
          ..write('position: $position')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(songId, artistId, position);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SongArtist &&
          other.songId == this.songId &&
          other.artistId == this.artistId &&
          other.position == this.position);
}

class SongArtistsCompanion extends UpdateCompanion<SongArtist> {
  final Value<String> songId;
  final Value<String> artistId;
  final Value<int> position;
  final Value<int> rowid;
  const SongArtistsCompanion({
    this.songId = const Value.absent(),
    this.artistId = const Value.absent(),
    this.position = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SongArtistsCompanion.insert({
    required String songId,
    required String artistId,
    required int position,
    this.rowid = const Value.absent(),
  }) : songId = Value(songId),
       artistId = Value(artistId),
       position = Value(position);
  static Insertable<SongArtist> custom({
    Expression<String>? songId,
    Expression<String>? artistId,
    Expression<int>? position,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (songId != null) 'song_id': songId,
      if (artistId != null) 'artist_id': artistId,
      if (position != null) 'position': position,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SongArtistsCompanion copyWith({
    Value<String>? songId,
    Value<String>? artistId,
    Value<int>? position,
    Value<int>? rowid,
  }) {
    return SongArtistsCompanion(
      songId: songId ?? this.songId,
      artistId: artistId ?? this.artistId,
      position: position ?? this.position,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (songId.present) {
      map['song_id'] = Variable<String>(songId.value);
    }
    if (artistId.present) {
      map['artist_id'] = Variable<String>(artistId.value);
    }
    if (position.present) {
      map['position'] = Variable<int>(position.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SongArtistsCompanion(')
          ..write('songId: $songId, ')
          ..write('artistId: $artistId, ')
          ..write('position: $position, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $AlbumArtistsTable extends AlbumArtists
    with TableInfo<$AlbumArtistsTable, AlbumArtist> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AlbumArtistsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _albumIdMeta = const VerificationMeta(
    'albumId',
  );
  @override
  late final GeneratedColumn<String> albumId = GeneratedColumn<String>(
    'album_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES albums (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _artistIdMeta = const VerificationMeta(
    'artistId',
  );
  @override
  late final GeneratedColumn<String> artistId = GeneratedColumn<String>(
    'artist_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES artists (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _positionMeta = const VerificationMeta(
    'position',
  );
  @override
  late final GeneratedColumn<int> position = GeneratedColumn<int>(
    'position',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [albumId, artistId, position];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'album_artists';
  @override
  VerificationContext validateIntegrity(
    Insertable<AlbumArtist> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('album_id')) {
      context.handle(
        _albumIdMeta,
        albumId.isAcceptableOrUnknown(data['album_id']!, _albumIdMeta),
      );
    } else if (isInserting) {
      context.missing(_albumIdMeta);
    }
    if (data.containsKey('artist_id')) {
      context.handle(
        _artistIdMeta,
        artistId.isAcceptableOrUnknown(data['artist_id']!, _artistIdMeta),
      );
    } else if (isInserting) {
      context.missing(_artistIdMeta);
    }
    if (data.containsKey('position')) {
      context.handle(
        _positionMeta,
        position.isAcceptableOrUnknown(data['position']!, _positionMeta),
      );
    } else if (isInserting) {
      context.missing(_positionMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {albumId, artistId};
  @override
  AlbumArtist map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return AlbumArtist(
      albumId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}album_id'],
      )!,
      artistId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}artist_id'],
      )!,
      position: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}position'],
      )!,
    );
  }

  @override
  $AlbumArtistsTable createAlias(String alias) {
    return $AlbumArtistsTable(attachedDatabase, alias);
  }
}

class AlbumArtist extends DataClass implements Insertable<AlbumArtist> {
  final String albumId;
  final String artistId;
  final int position;
  const AlbumArtist({
    required this.albumId,
    required this.artistId,
    required this.position,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['album_id'] = Variable<String>(albumId);
    map['artist_id'] = Variable<String>(artistId);
    map['position'] = Variable<int>(position);
    return map;
  }

  AlbumArtistsCompanion toCompanion(bool nullToAbsent) {
    return AlbumArtistsCompanion(
      albumId: Value(albumId),
      artistId: Value(artistId),
      position: Value(position),
    );
  }

  factory AlbumArtist.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return AlbumArtist(
      albumId: serializer.fromJson<String>(json['albumId']),
      artistId: serializer.fromJson<String>(json['artistId']),
      position: serializer.fromJson<int>(json['position']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'albumId': serializer.toJson<String>(albumId),
      'artistId': serializer.toJson<String>(artistId),
      'position': serializer.toJson<int>(position),
    };
  }

  AlbumArtist copyWith({String? albumId, String? artistId, int? position}) =>
      AlbumArtist(
        albumId: albumId ?? this.albumId,
        artistId: artistId ?? this.artistId,
        position: position ?? this.position,
      );
  AlbumArtist copyWithCompanion(AlbumArtistsCompanion data) {
    return AlbumArtist(
      albumId: data.albumId.present ? data.albumId.value : this.albumId,
      artistId: data.artistId.present ? data.artistId.value : this.artistId,
      position: data.position.present ? data.position.value : this.position,
    );
  }

  @override
  String toString() {
    return (StringBuffer('AlbumArtist(')
          ..write('albumId: $albumId, ')
          ..write('artistId: $artistId, ')
          ..write('position: $position')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(albumId, artistId, position);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AlbumArtist &&
          other.albumId == this.albumId &&
          other.artistId == this.artistId &&
          other.position == this.position);
}

class AlbumArtistsCompanion extends UpdateCompanion<AlbumArtist> {
  final Value<String> albumId;
  final Value<String> artistId;
  final Value<int> position;
  final Value<int> rowid;
  const AlbumArtistsCompanion({
    this.albumId = const Value.absent(),
    this.artistId = const Value.absent(),
    this.position = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  AlbumArtistsCompanion.insert({
    required String albumId,
    required String artistId,
    required int position,
    this.rowid = const Value.absent(),
  }) : albumId = Value(albumId),
       artistId = Value(artistId),
       position = Value(position);
  static Insertable<AlbumArtist> custom({
    Expression<String>? albumId,
    Expression<String>? artistId,
    Expression<int>? position,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (albumId != null) 'album_id': albumId,
      if (artistId != null) 'artist_id': artistId,
      if (position != null) 'position': position,
      if (rowid != null) 'rowid': rowid,
    });
  }

  AlbumArtistsCompanion copyWith({
    Value<String>? albumId,
    Value<String>? artistId,
    Value<int>? position,
    Value<int>? rowid,
  }) {
    return AlbumArtistsCompanion(
      albumId: albumId ?? this.albumId,
      artistId: artistId ?? this.artistId,
      position: position ?? this.position,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (albumId.present) {
      map['album_id'] = Variable<String>(albumId.value);
    }
    if (artistId.present) {
      map['artist_id'] = Variable<String>(artistId.value);
    }
    if (position.present) {
      map['position'] = Variable<int>(position.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AlbumArtistsCompanion(')
          ..write('albumId: $albumId, ')
          ..write('artistId: $artistId, ')
          ..write('position: $position, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $PlaylistsTable extends Playlists
    with TableInfo<$PlaylistsTable, Playlist> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PlaylistsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _descriptionMeta = const VerificationMeta(
    'description',
  );
  @override
  late final GeneratedColumn<String> description = GeneratedColumn<String>(
    'description',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _browseIdMeta = const VerificationMeta(
    'browseId',
  );
  @override
  late final GeneratedColumn<String> browseId = GeneratedColumn<String>(
    'browse_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _thumbnailUrlMeta = const VerificationMeta(
    'thumbnailUrl',
  );
  @override
  late final GeneratedColumn<String> thumbnailUrl = GeneratedColumn<String>(
    'thumbnail_url',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    name,
    description,
    browseId,
    thumbnailUrl,
    createdAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'playlists';
  @override
  VerificationContext validateIntegrity(
    Insertable<Playlist> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('description')) {
      context.handle(
        _descriptionMeta,
        description.isAcceptableOrUnknown(
          data['description']!,
          _descriptionMeta,
        ),
      );
    }
    if (data.containsKey('browse_id')) {
      context.handle(
        _browseIdMeta,
        browseId.isAcceptableOrUnknown(data['browse_id']!, _browseIdMeta),
      );
    }
    if (data.containsKey('thumbnail_url')) {
      context.handle(
        _thumbnailUrlMeta,
        thumbnailUrl.isAcceptableOrUnknown(
          data['thumbnail_url']!,
          _thumbnailUrlMeta,
        ),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Playlist map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Playlist(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      description: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}description'],
      ),
      browseId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}browse_id'],
      ),
      thumbnailUrl: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}thumbnail_url'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $PlaylistsTable createAlias(String alias) {
    return $PlaylistsTable(attachedDatabase, alias);
  }
}

class Playlist extends DataClass implements Insertable<Playlist> {
  final int id;

  /// Nama playlist, maks 100 karakter (PRD B4.1, ditegakkan service).
  final String name;

  /// Deskripsi playlist, maks 500 karakter (PRD B4.1, ditegakkan service).
  final String? description;

  /// browseId bila playlist berasal dari YouTube Music.
  final String? browseId;
  final String? thumbnailUrl;
  final DateTime createdAt;
  final DateTime updatedAt;
  const Playlist({
    required this.id,
    required this.name,
    this.description,
    this.browseId,
    this.thumbnailUrl,
    required this.createdAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['name'] = Variable<String>(name);
    if (!nullToAbsent || description != null) {
      map['description'] = Variable<String>(description);
    }
    if (!nullToAbsent || browseId != null) {
      map['browse_id'] = Variable<String>(browseId);
    }
    if (!nullToAbsent || thumbnailUrl != null) {
      map['thumbnail_url'] = Variable<String>(thumbnailUrl);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  PlaylistsCompanion toCompanion(bool nullToAbsent) {
    return PlaylistsCompanion(
      id: Value(id),
      name: Value(name),
      description: description == null && nullToAbsent
          ? const Value.absent()
          : Value(description),
      browseId: browseId == null && nullToAbsent
          ? const Value.absent()
          : Value(browseId),
      thumbnailUrl: thumbnailUrl == null && nullToAbsent
          ? const Value.absent()
          : Value(thumbnailUrl),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory Playlist.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Playlist(
      id: serializer.fromJson<int>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      description: serializer.fromJson<String?>(json['description']),
      browseId: serializer.fromJson<String?>(json['browseId']),
      thumbnailUrl: serializer.fromJson<String?>(json['thumbnailUrl']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'name': serializer.toJson<String>(name),
      'description': serializer.toJson<String?>(description),
      'browseId': serializer.toJson<String?>(browseId),
      'thumbnailUrl': serializer.toJson<String?>(thumbnailUrl),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  Playlist copyWith({
    int? id,
    String? name,
    Value<String?> description = const Value.absent(),
    Value<String?> browseId = const Value.absent(),
    Value<String?> thumbnailUrl = const Value.absent(),
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => Playlist(
    id: id ?? this.id,
    name: name ?? this.name,
    description: description.present ? description.value : this.description,
    browseId: browseId.present ? browseId.value : this.browseId,
    thumbnailUrl: thumbnailUrl.present ? thumbnailUrl.value : this.thumbnailUrl,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  Playlist copyWithCompanion(PlaylistsCompanion data) {
    return Playlist(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      description: data.description.present
          ? data.description.value
          : this.description,
      browseId: data.browseId.present ? data.browseId.value : this.browseId,
      thumbnailUrl: data.thumbnailUrl.present
          ? data.thumbnailUrl.value
          : this.thumbnailUrl,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Playlist(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('description: $description, ')
          ..write('browseId: $browseId, ')
          ..write('thumbnailUrl: $thumbnailUrl, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    name,
    description,
    browseId,
    thumbnailUrl,
    createdAt,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Playlist &&
          other.id == this.id &&
          other.name == this.name &&
          other.description == this.description &&
          other.browseId == this.browseId &&
          other.thumbnailUrl == this.thumbnailUrl &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class PlaylistsCompanion extends UpdateCompanion<Playlist> {
  final Value<int> id;
  final Value<String> name;
  final Value<String?> description;
  final Value<String?> browseId;
  final Value<String?> thumbnailUrl;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  const PlaylistsCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.description = const Value.absent(),
    this.browseId = const Value.absent(),
    this.thumbnailUrl = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
  });
  PlaylistsCompanion.insert({
    this.id = const Value.absent(),
    required String name,
    this.description = const Value.absent(),
    this.browseId = const Value.absent(),
    this.thumbnailUrl = const Value.absent(),
    required DateTime createdAt,
    required DateTime updatedAt,
  }) : name = Value(name),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<Playlist> custom({
    Expression<int>? id,
    Expression<String>? name,
    Expression<String>? description,
    Expression<String>? browseId,
    Expression<String>? thumbnailUrl,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (description != null) 'description': description,
      if (browseId != null) 'browse_id': browseId,
      if (thumbnailUrl != null) 'thumbnail_url': thumbnailUrl,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
    });
  }

  PlaylistsCompanion copyWith({
    Value<int>? id,
    Value<String>? name,
    Value<String?>? description,
    Value<String?>? browseId,
    Value<String?>? thumbnailUrl,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
  }) {
    return PlaylistsCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      browseId: browseId ?? this.browseId,
      thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (description.present) {
      map['description'] = Variable<String>(description.value);
    }
    if (browseId.present) {
      map['browse_id'] = Variable<String>(browseId.value);
    }
    if (thumbnailUrl.present) {
      map['thumbnail_url'] = Variable<String>(thumbnailUrl.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PlaylistsCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('description: $description, ')
          ..write('browseId: $browseId, ')
          ..write('thumbnailUrl: $thumbnailUrl, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }
}

class $PlaylistSongsTable extends PlaylistSongs
    with TableInfo<$PlaylistSongsTable, PlaylistSong> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PlaylistSongsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _playlistIdMeta = const VerificationMeta(
    'playlistId',
  );
  @override
  late final GeneratedColumn<int> playlistId = GeneratedColumn<int>(
    'playlist_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES playlists (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _songIdMeta = const VerificationMeta('songId');
  @override
  late final GeneratedColumn<String> songId = GeneratedColumn<String>(
    'song_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES songs (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _positionMeta = const VerificationMeta(
    'position',
  );
  @override
  late final GeneratedColumn<int> position = GeneratedColumn<int>(
    'position',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _dateAddedMeta = const VerificationMeta(
    'dateAdded',
  );
  @override
  late final GeneratedColumn<DateTime> dateAdded = GeneratedColumn<DateTime>(
    'date_added',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    playlistId,
    songId,
    position,
    dateAdded,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'playlist_songs';
  @override
  VerificationContext validateIntegrity(
    Insertable<PlaylistSong> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('playlist_id')) {
      context.handle(
        _playlistIdMeta,
        playlistId.isAcceptableOrUnknown(data['playlist_id']!, _playlistIdMeta),
      );
    } else if (isInserting) {
      context.missing(_playlistIdMeta);
    }
    if (data.containsKey('song_id')) {
      context.handle(
        _songIdMeta,
        songId.isAcceptableOrUnknown(data['song_id']!, _songIdMeta),
      );
    } else if (isInserting) {
      context.missing(_songIdMeta);
    }
    if (data.containsKey('position')) {
      context.handle(
        _positionMeta,
        position.isAcceptableOrUnknown(data['position']!, _positionMeta),
      );
    } else if (isInserting) {
      context.missing(_positionMeta);
    }
    if (data.containsKey('date_added')) {
      context.handle(
        _dateAddedMeta,
        dateAdded.isAcceptableOrUnknown(data['date_added']!, _dateAddedMeta),
      );
    } else if (isInserting) {
      context.missing(_dateAddedMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {playlistId, songId};
  @override
  PlaylistSong map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PlaylistSong(
      playlistId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}playlist_id'],
      )!,
      songId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}song_id'],
      )!,
      position: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}position'],
      )!,
      dateAdded: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}date_added'],
      )!,
    );
  }

  @override
  $PlaylistSongsTable createAlias(String alias) {
    return $PlaylistSongsTable(attachedDatabase, alias);
  }
}

class PlaylistSong extends DataClass implements Insertable<PlaylistSong> {
  final int playlistId;
  final String songId;
  final int position;
  final DateTime dateAdded;
  const PlaylistSong({
    required this.playlistId,
    required this.songId,
    required this.position,
    required this.dateAdded,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['playlist_id'] = Variable<int>(playlistId);
    map['song_id'] = Variable<String>(songId);
    map['position'] = Variable<int>(position);
    map['date_added'] = Variable<DateTime>(dateAdded);
    return map;
  }

  PlaylistSongsCompanion toCompanion(bool nullToAbsent) {
    return PlaylistSongsCompanion(
      playlistId: Value(playlistId),
      songId: Value(songId),
      position: Value(position),
      dateAdded: Value(dateAdded),
    );
  }

  factory PlaylistSong.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PlaylistSong(
      playlistId: serializer.fromJson<int>(json['playlistId']),
      songId: serializer.fromJson<String>(json['songId']),
      position: serializer.fromJson<int>(json['position']),
      dateAdded: serializer.fromJson<DateTime>(json['dateAdded']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'playlistId': serializer.toJson<int>(playlistId),
      'songId': serializer.toJson<String>(songId),
      'position': serializer.toJson<int>(position),
      'dateAdded': serializer.toJson<DateTime>(dateAdded),
    };
  }

  PlaylistSong copyWith({
    int? playlistId,
    String? songId,
    int? position,
    DateTime? dateAdded,
  }) => PlaylistSong(
    playlistId: playlistId ?? this.playlistId,
    songId: songId ?? this.songId,
    position: position ?? this.position,
    dateAdded: dateAdded ?? this.dateAdded,
  );
  PlaylistSong copyWithCompanion(PlaylistSongsCompanion data) {
    return PlaylistSong(
      playlistId: data.playlistId.present
          ? data.playlistId.value
          : this.playlistId,
      songId: data.songId.present ? data.songId.value : this.songId,
      position: data.position.present ? data.position.value : this.position,
      dateAdded: data.dateAdded.present ? data.dateAdded.value : this.dateAdded,
    );
  }

  @override
  String toString() {
    return (StringBuffer('PlaylistSong(')
          ..write('playlistId: $playlistId, ')
          ..write('songId: $songId, ')
          ..write('position: $position, ')
          ..write('dateAdded: $dateAdded')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(playlistId, songId, position, dateAdded);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PlaylistSong &&
          other.playlistId == this.playlistId &&
          other.songId == this.songId &&
          other.position == this.position &&
          other.dateAdded == this.dateAdded);
}

class PlaylistSongsCompanion extends UpdateCompanion<PlaylistSong> {
  final Value<int> playlistId;
  final Value<String> songId;
  final Value<int> position;
  final Value<DateTime> dateAdded;
  final Value<int> rowid;
  const PlaylistSongsCompanion({
    this.playlistId = const Value.absent(),
    this.songId = const Value.absent(),
    this.position = const Value.absent(),
    this.dateAdded = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  PlaylistSongsCompanion.insert({
    required int playlistId,
    required String songId,
    required int position,
    required DateTime dateAdded,
    this.rowid = const Value.absent(),
  }) : playlistId = Value(playlistId),
       songId = Value(songId),
       position = Value(position),
       dateAdded = Value(dateAdded);
  static Insertable<PlaylistSong> custom({
    Expression<int>? playlistId,
    Expression<String>? songId,
    Expression<int>? position,
    Expression<DateTime>? dateAdded,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (playlistId != null) 'playlist_id': playlistId,
      if (songId != null) 'song_id': songId,
      if (position != null) 'position': position,
      if (dateAdded != null) 'date_added': dateAdded,
      if (rowid != null) 'rowid': rowid,
    });
  }

  PlaylistSongsCompanion copyWith({
    Value<int>? playlistId,
    Value<String>? songId,
    Value<int>? position,
    Value<DateTime>? dateAdded,
    Value<int>? rowid,
  }) {
    return PlaylistSongsCompanion(
      playlistId: playlistId ?? this.playlistId,
      songId: songId ?? this.songId,
      position: position ?? this.position,
      dateAdded: dateAdded ?? this.dateAdded,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (playlistId.present) {
      map['playlist_id'] = Variable<int>(playlistId.value);
    }
    if (songId.present) {
      map['song_id'] = Variable<String>(songId.value);
    }
    if (position.present) {
      map['position'] = Variable<int>(position.value);
    }
    if (dateAdded.present) {
      map['date_added'] = Variable<DateTime>(dateAdded.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PlaylistSongsCompanion(')
          ..write('playlistId: $playlistId, ')
          ..write('songId: $songId, ')
          ..write('position: $position, ')
          ..write('dateAdded: $dateAdded, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $LyricsTable extends Lyrics with TableInfo<$LyricsTable, Lyric> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LyricsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _songIdMeta = const VerificationMeta('songId');
  @override
  late final GeneratedColumn<String> songId = GeneratedColumn<String>(
    'song_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES songs (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _lyricsMeta = const VerificationMeta('lyrics');
  @override
  late final GeneratedColumn<String> lyrics = GeneratedColumn<String>(
    'lyrics',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _syncedLyricsMeta = const VerificationMeta(
    'syncedLyrics',
  );
  @override
  late final GeneratedColumn<String> syncedLyrics = GeneratedColumn<String>(
    'synced_lyrics',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _fetchedAtMeta = const VerificationMeta(
    'fetchedAt',
  );
  @override
  late final GeneratedColumn<DateTime> fetchedAt = GeneratedColumn<DateTime>(
    'fetched_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    songId,
    lyrics,
    syncedLyrics,
    fetchedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'lyrics';
  @override
  VerificationContext validateIntegrity(
    Insertable<Lyric> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('song_id')) {
      context.handle(
        _songIdMeta,
        songId.isAcceptableOrUnknown(data['song_id']!, _songIdMeta),
      );
    } else if (isInserting) {
      context.missing(_songIdMeta);
    }
    if (data.containsKey('lyrics')) {
      context.handle(
        _lyricsMeta,
        lyrics.isAcceptableOrUnknown(data['lyrics']!, _lyricsMeta),
      );
    } else if (isInserting) {
      context.missing(_lyricsMeta);
    }
    if (data.containsKey('synced_lyrics')) {
      context.handle(
        _syncedLyricsMeta,
        syncedLyrics.isAcceptableOrUnknown(
          data['synced_lyrics']!,
          _syncedLyricsMeta,
        ),
      );
    }
    if (data.containsKey('fetched_at')) {
      context.handle(
        _fetchedAtMeta,
        fetchedAt.isAcceptableOrUnknown(data['fetched_at']!, _fetchedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_fetchedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {songId};
  @override
  Lyric map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Lyric(
      songId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}song_id'],
      )!,
      lyrics: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}lyrics'],
      )!,
      syncedLyrics: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}synced_lyrics'],
      ),
      fetchedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}fetched_at'],
      )!,
    );
  }

  @override
  $LyricsTable createAlias(String alias) {
    return $LyricsTable(attachedDatabase, alias);
  }
}

class Lyric extends DataClass implements Insertable<Lyric> {
  final String songId;
  final String lyrics;

  /// Lirik dengan timestamp (format LRC).
  final String? syncedLyrics;
  final DateTime fetchedAt;
  const Lyric({
    required this.songId,
    required this.lyrics,
    this.syncedLyrics,
    required this.fetchedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['song_id'] = Variable<String>(songId);
    map['lyrics'] = Variable<String>(lyrics);
    if (!nullToAbsent || syncedLyrics != null) {
      map['synced_lyrics'] = Variable<String>(syncedLyrics);
    }
    map['fetched_at'] = Variable<DateTime>(fetchedAt);
    return map;
  }

  LyricsCompanion toCompanion(bool nullToAbsent) {
    return LyricsCompanion(
      songId: Value(songId),
      lyrics: Value(lyrics),
      syncedLyrics: syncedLyrics == null && nullToAbsent
          ? const Value.absent()
          : Value(syncedLyrics),
      fetchedAt: Value(fetchedAt),
    );
  }

  factory Lyric.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Lyric(
      songId: serializer.fromJson<String>(json['songId']),
      lyrics: serializer.fromJson<String>(json['lyrics']),
      syncedLyrics: serializer.fromJson<String?>(json['syncedLyrics']),
      fetchedAt: serializer.fromJson<DateTime>(json['fetchedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'songId': serializer.toJson<String>(songId),
      'lyrics': serializer.toJson<String>(lyrics),
      'syncedLyrics': serializer.toJson<String?>(syncedLyrics),
      'fetchedAt': serializer.toJson<DateTime>(fetchedAt),
    };
  }

  Lyric copyWith({
    String? songId,
    String? lyrics,
    Value<String?> syncedLyrics = const Value.absent(),
    DateTime? fetchedAt,
  }) => Lyric(
    songId: songId ?? this.songId,
    lyrics: lyrics ?? this.lyrics,
    syncedLyrics: syncedLyrics.present ? syncedLyrics.value : this.syncedLyrics,
    fetchedAt: fetchedAt ?? this.fetchedAt,
  );
  Lyric copyWithCompanion(LyricsCompanion data) {
    return Lyric(
      songId: data.songId.present ? data.songId.value : this.songId,
      lyrics: data.lyrics.present ? data.lyrics.value : this.lyrics,
      syncedLyrics: data.syncedLyrics.present
          ? data.syncedLyrics.value
          : this.syncedLyrics,
      fetchedAt: data.fetchedAt.present ? data.fetchedAt.value : this.fetchedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Lyric(')
          ..write('songId: $songId, ')
          ..write('lyrics: $lyrics, ')
          ..write('syncedLyrics: $syncedLyrics, ')
          ..write('fetchedAt: $fetchedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(songId, lyrics, syncedLyrics, fetchedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Lyric &&
          other.songId == this.songId &&
          other.lyrics == this.lyrics &&
          other.syncedLyrics == this.syncedLyrics &&
          other.fetchedAt == this.fetchedAt);
}

class LyricsCompanion extends UpdateCompanion<Lyric> {
  final Value<String> songId;
  final Value<String> lyrics;
  final Value<String?> syncedLyrics;
  final Value<DateTime> fetchedAt;
  final Value<int> rowid;
  const LyricsCompanion({
    this.songId = const Value.absent(),
    this.lyrics = const Value.absent(),
    this.syncedLyrics = const Value.absent(),
    this.fetchedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  LyricsCompanion.insert({
    required String songId,
    required String lyrics,
    this.syncedLyrics = const Value.absent(),
    required DateTime fetchedAt,
    this.rowid = const Value.absent(),
  }) : songId = Value(songId),
       lyrics = Value(lyrics),
       fetchedAt = Value(fetchedAt);
  static Insertable<Lyric> custom({
    Expression<String>? songId,
    Expression<String>? lyrics,
    Expression<String>? syncedLyrics,
    Expression<DateTime>? fetchedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (songId != null) 'song_id': songId,
      if (lyrics != null) 'lyrics': lyrics,
      if (syncedLyrics != null) 'synced_lyrics': syncedLyrics,
      if (fetchedAt != null) 'fetched_at': fetchedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  LyricsCompanion copyWith({
    Value<String>? songId,
    Value<String>? lyrics,
    Value<String?>? syncedLyrics,
    Value<DateTime>? fetchedAt,
    Value<int>? rowid,
  }) {
    return LyricsCompanion(
      songId: songId ?? this.songId,
      lyrics: lyrics ?? this.lyrics,
      syncedLyrics: syncedLyrics ?? this.syncedLyrics,
      fetchedAt: fetchedAt ?? this.fetchedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (songId.present) {
      map['song_id'] = Variable<String>(songId.value);
    }
    if (lyrics.present) {
      map['lyrics'] = Variable<String>(lyrics.value);
    }
    if (syncedLyrics.present) {
      map['synced_lyrics'] = Variable<String>(syncedLyrics.value);
    }
    if (fetchedAt.present) {
      map['fetched_at'] = Variable<DateTime>(fetchedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LyricsCompanion(')
          ..write('songId: $songId, ')
          ..write('lyrics: $lyrics, ')
          ..write('syncedLyrics: $syncedLyrics, ')
          ..write('fetchedAt: $fetchedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $PlayEventsTable extends PlayEvents
    with TableInfo<$PlayEventsTable, PlayEvent> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PlayEventsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _songIdMeta = const VerificationMeta('songId');
  @override
  late final GeneratedColumn<String> songId = GeneratedColumn<String>(
    'song_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES songs (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _timestampMeta = const VerificationMeta(
    'timestamp',
  );
  @override
  late final GeneratedColumn<DateTime> timestamp = GeneratedColumn<DateTime>(
    'timestamp',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _playTimeMsMeta = const VerificationMeta(
    'playTimeMs',
  );
  @override
  late final GeneratedColumn<int> playTimeMs = GeneratedColumn<int>(
    'play_time_ms',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [id, songId, timestamp, playTimeMs];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'play_events';
  @override
  VerificationContext validateIntegrity(
    Insertable<PlayEvent> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('song_id')) {
      context.handle(
        _songIdMeta,
        songId.isAcceptableOrUnknown(data['song_id']!, _songIdMeta),
      );
    } else if (isInserting) {
      context.missing(_songIdMeta);
    }
    if (data.containsKey('timestamp')) {
      context.handle(
        _timestampMeta,
        timestamp.isAcceptableOrUnknown(data['timestamp']!, _timestampMeta),
      );
    } else if (isInserting) {
      context.missing(_timestampMeta);
    }
    if (data.containsKey('play_time_ms')) {
      context.handle(
        _playTimeMsMeta,
        playTimeMs.isAcceptableOrUnknown(
          data['play_time_ms']!,
          _playTimeMsMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_playTimeMsMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  PlayEvent map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PlayEvent(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      songId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}song_id'],
      )!,
      timestamp: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}timestamp'],
      )!,
      playTimeMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}play_time_ms'],
      )!,
    );
  }

  @override
  $PlayEventsTable createAlias(String alias) {
    return $PlayEventsTable(attachedDatabase, alias);
  }
}

class PlayEvent extends DataClass implements Insertable<PlayEvent> {
  final int id;
  final String songId;
  final DateTime timestamp;
  final int playTimeMs;
  const PlayEvent({
    required this.id,
    required this.songId,
    required this.timestamp,
    required this.playTimeMs,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['song_id'] = Variable<String>(songId);
    map['timestamp'] = Variable<DateTime>(timestamp);
    map['play_time_ms'] = Variable<int>(playTimeMs);
    return map;
  }

  PlayEventsCompanion toCompanion(bool nullToAbsent) {
    return PlayEventsCompanion(
      id: Value(id),
      songId: Value(songId),
      timestamp: Value(timestamp),
      playTimeMs: Value(playTimeMs),
    );
  }

  factory PlayEvent.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PlayEvent(
      id: serializer.fromJson<int>(json['id']),
      songId: serializer.fromJson<String>(json['songId']),
      timestamp: serializer.fromJson<DateTime>(json['timestamp']),
      playTimeMs: serializer.fromJson<int>(json['playTimeMs']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'songId': serializer.toJson<String>(songId),
      'timestamp': serializer.toJson<DateTime>(timestamp),
      'playTimeMs': serializer.toJson<int>(playTimeMs),
    };
  }

  PlayEvent copyWith({
    int? id,
    String? songId,
    DateTime? timestamp,
    int? playTimeMs,
  }) => PlayEvent(
    id: id ?? this.id,
    songId: songId ?? this.songId,
    timestamp: timestamp ?? this.timestamp,
    playTimeMs: playTimeMs ?? this.playTimeMs,
  );
  PlayEvent copyWithCompanion(PlayEventsCompanion data) {
    return PlayEvent(
      id: data.id.present ? data.id.value : this.id,
      songId: data.songId.present ? data.songId.value : this.songId,
      timestamp: data.timestamp.present ? data.timestamp.value : this.timestamp,
      playTimeMs: data.playTimeMs.present
          ? data.playTimeMs.value
          : this.playTimeMs,
    );
  }

  @override
  String toString() {
    return (StringBuffer('PlayEvent(')
          ..write('id: $id, ')
          ..write('songId: $songId, ')
          ..write('timestamp: $timestamp, ')
          ..write('playTimeMs: $playTimeMs')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, songId, timestamp, playTimeMs);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PlayEvent &&
          other.id == this.id &&
          other.songId == this.songId &&
          other.timestamp == this.timestamp &&
          other.playTimeMs == this.playTimeMs);
}

class PlayEventsCompanion extends UpdateCompanion<PlayEvent> {
  final Value<int> id;
  final Value<String> songId;
  final Value<DateTime> timestamp;
  final Value<int> playTimeMs;
  const PlayEventsCompanion({
    this.id = const Value.absent(),
    this.songId = const Value.absent(),
    this.timestamp = const Value.absent(),
    this.playTimeMs = const Value.absent(),
  });
  PlayEventsCompanion.insert({
    this.id = const Value.absent(),
    required String songId,
    required DateTime timestamp,
    required int playTimeMs,
  }) : songId = Value(songId),
       timestamp = Value(timestamp),
       playTimeMs = Value(playTimeMs);
  static Insertable<PlayEvent> custom({
    Expression<int>? id,
    Expression<String>? songId,
    Expression<DateTime>? timestamp,
    Expression<int>? playTimeMs,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (songId != null) 'song_id': songId,
      if (timestamp != null) 'timestamp': timestamp,
      if (playTimeMs != null) 'play_time_ms': playTimeMs,
    });
  }

  PlayEventsCompanion copyWith({
    Value<int>? id,
    Value<String>? songId,
    Value<DateTime>? timestamp,
    Value<int>? playTimeMs,
  }) {
    return PlayEventsCompanion(
      id: id ?? this.id,
      songId: songId ?? this.songId,
      timestamp: timestamp ?? this.timestamp,
      playTimeMs: playTimeMs ?? this.playTimeMs,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (songId.present) {
      map['song_id'] = Variable<String>(songId.value);
    }
    if (timestamp.present) {
      map['timestamp'] = Variable<DateTime>(timestamp.value);
    }
    if (playTimeMs.present) {
      map['play_time_ms'] = Variable<int>(playTimeMs.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PlayEventsCompanion(')
          ..write('id: $id, ')
          ..write('songId: $songId, ')
          ..write('timestamp: $timestamp, ')
          ..write('playTimeMs: $playTimeMs')
          ..write(')'))
        .toString();
  }
}

class $SearchHistoryTable extends SearchHistory
    with TableInfo<$SearchHistoryTable, SearchHistoryData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SearchHistoryTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _queryMeta = const VerificationMeta('query');
  @override
  late final GeneratedColumn<String> query = GeneratedColumn<String>(
    'query',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _timestampMeta = const VerificationMeta(
    'timestamp',
  );
  @override
  late final GeneratedColumn<DateTime> timestamp = GeneratedColumn<DateTime>(
    'timestamp',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [query, timestamp];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'search_history';
  @override
  VerificationContext validateIntegrity(
    Insertable<SearchHistoryData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('query')) {
      context.handle(
        _queryMeta,
        query.isAcceptableOrUnknown(data['query']!, _queryMeta),
      );
    } else if (isInserting) {
      context.missing(_queryMeta);
    }
    if (data.containsKey('timestamp')) {
      context.handle(
        _timestampMeta,
        timestamp.isAcceptableOrUnknown(data['timestamp']!, _timestampMeta),
      );
    } else if (isInserting) {
      context.missing(_timestampMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {query};
  @override
  SearchHistoryData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SearchHistoryData(
      query: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}query'],
      )!,
      timestamp: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}timestamp'],
      )!,
    );
  }

  @override
  $SearchHistoryTable createAlias(String alias) {
    return $SearchHistoryTable(attachedDatabase, alias);
  }
}

class SearchHistoryData extends DataClass
    implements Insertable<SearchHistoryData> {
  final String query;
  final DateTime timestamp;
  const SearchHistoryData({required this.query, required this.timestamp});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['query'] = Variable<String>(query);
    map['timestamp'] = Variable<DateTime>(timestamp);
    return map;
  }

  SearchHistoryCompanion toCompanion(bool nullToAbsent) {
    return SearchHistoryCompanion(
      query: Value(query),
      timestamp: Value(timestamp),
    );
  }

  factory SearchHistoryData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SearchHistoryData(
      query: serializer.fromJson<String>(json['query']),
      timestamp: serializer.fromJson<DateTime>(json['timestamp']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'query': serializer.toJson<String>(query),
      'timestamp': serializer.toJson<DateTime>(timestamp),
    };
  }

  SearchHistoryData copyWith({String? query, DateTime? timestamp}) =>
      SearchHistoryData(
        query: query ?? this.query,
        timestamp: timestamp ?? this.timestamp,
      );
  SearchHistoryData copyWithCompanion(SearchHistoryCompanion data) {
    return SearchHistoryData(
      query: data.query.present ? data.query.value : this.query,
      timestamp: data.timestamp.present ? data.timestamp.value : this.timestamp,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SearchHistoryData(')
          ..write('query: $query, ')
          ..write('timestamp: $timestamp')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(query, timestamp);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SearchHistoryData &&
          other.query == this.query &&
          other.timestamp == this.timestamp);
}

class SearchHistoryCompanion extends UpdateCompanion<SearchHistoryData> {
  final Value<String> query;
  final Value<DateTime> timestamp;
  final Value<int> rowid;
  const SearchHistoryCompanion({
    this.query = const Value.absent(),
    this.timestamp = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SearchHistoryCompanion.insert({
    required String query,
    required DateTime timestamp,
    this.rowid = const Value.absent(),
  }) : query = Value(query),
       timestamp = Value(timestamp);
  static Insertable<SearchHistoryData> custom({
    Expression<String>? query,
    Expression<DateTime>? timestamp,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (query != null) 'query': query,
      if (timestamp != null) 'timestamp': timestamp,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SearchHistoryCompanion copyWith({
    Value<String>? query,
    Value<DateTime>? timestamp,
    Value<int>? rowid,
  }) {
    return SearchHistoryCompanion(
      query: query ?? this.query,
      timestamp: timestamp ?? this.timestamp,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (query.present) {
      map['query'] = Variable<String>(query.value);
    }
    if (timestamp.present) {
      map['timestamp'] = Variable<DateTime>(timestamp.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SearchHistoryCompanion(')
          ..write('query: $query, ')
          ..write('timestamp: $timestamp, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $QueueItemsTable extends QueueItems
    with TableInfo<$QueueItemsTable, QueueItem> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $QueueItemsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _positionMeta = const VerificationMeta(
    'position',
  );
  @override
  late final GeneratedColumn<int> position = GeneratedColumn<int>(
    'position',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _songIdMeta = const VerificationMeta('songId');
  @override
  late final GeneratedColumn<String> songId = GeneratedColumn<String>(
    'song_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES songs (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _sourceMeta = const VerificationMeta('source');
  @override
  late final GeneratedColumn<String> source = GeneratedColumn<String>(
    'source',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [position, songId, source];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'queue_items';
  @override
  VerificationContext validateIntegrity(
    Insertable<QueueItem> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('position')) {
      context.handle(
        _positionMeta,
        position.isAcceptableOrUnknown(data['position']!, _positionMeta),
      );
    }
    if (data.containsKey('song_id')) {
      context.handle(
        _songIdMeta,
        songId.isAcceptableOrUnknown(data['song_id']!, _songIdMeta),
      );
    } else if (isInserting) {
      context.missing(_songIdMeta);
    }
    if (data.containsKey('source')) {
      context.handle(
        _sourceMeta,
        source.isAcceptableOrUnknown(data['source']!, _sourceMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {position};
  @override
  QueueItem map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return QueueItem(
      position: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}position'],
      )!,
      songId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}song_id'],
      )!,
      source: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source'],
      ),
    );
  }

  @override
  $QueueItemsTable createAlias(String alias) {
    return $QueueItemsTable(attachedDatabase, alias);
  }
}

class QueueItem extends DataClass implements Insertable<QueueItem> {
  final int position;
  final String songId;

  /// Asal antrean (playlist, album, pencarian).
  final String? source;
  const QueueItem({required this.position, required this.songId, this.source});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['position'] = Variable<int>(position);
    map['song_id'] = Variable<String>(songId);
    if (!nullToAbsent || source != null) {
      map['source'] = Variable<String>(source);
    }
    return map;
  }

  QueueItemsCompanion toCompanion(bool nullToAbsent) {
    return QueueItemsCompanion(
      position: Value(position),
      songId: Value(songId),
      source: source == null && nullToAbsent
          ? const Value.absent()
          : Value(source),
    );
  }

  factory QueueItem.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return QueueItem(
      position: serializer.fromJson<int>(json['position']),
      songId: serializer.fromJson<String>(json['songId']),
      source: serializer.fromJson<String?>(json['source']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'position': serializer.toJson<int>(position),
      'songId': serializer.toJson<String>(songId),
      'source': serializer.toJson<String?>(source),
    };
  }

  QueueItem copyWith({
    int? position,
    String? songId,
    Value<String?> source = const Value.absent(),
  }) => QueueItem(
    position: position ?? this.position,
    songId: songId ?? this.songId,
    source: source.present ? source.value : this.source,
  );
  QueueItem copyWithCompanion(QueueItemsCompanion data) {
    return QueueItem(
      position: data.position.present ? data.position.value : this.position,
      songId: data.songId.present ? data.songId.value : this.songId,
      source: data.source.present ? data.source.value : this.source,
    );
  }

  @override
  String toString() {
    return (StringBuffer('QueueItem(')
          ..write('position: $position, ')
          ..write('songId: $songId, ')
          ..write('source: $source')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(position, songId, source);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is QueueItem &&
          other.position == this.position &&
          other.songId == this.songId &&
          other.source == this.source);
}

class QueueItemsCompanion extends UpdateCompanion<QueueItem> {
  final Value<int> position;
  final Value<String> songId;
  final Value<String?> source;
  const QueueItemsCompanion({
    this.position = const Value.absent(),
    this.songId = const Value.absent(),
    this.source = const Value.absent(),
  });
  QueueItemsCompanion.insert({
    this.position = const Value.absent(),
    required String songId,
    this.source = const Value.absent(),
  }) : songId = Value(songId);
  static Insertable<QueueItem> custom({
    Expression<int>? position,
    Expression<String>? songId,
    Expression<String>? source,
  }) {
    return RawValuesInsertable({
      if (position != null) 'position': position,
      if (songId != null) 'song_id': songId,
      if (source != null) 'source': source,
    });
  }

  QueueItemsCompanion copyWith({
    Value<int>? position,
    Value<String>? songId,
    Value<String?>? source,
  }) {
    return QueueItemsCompanion(
      position: position ?? this.position,
      songId: songId ?? this.songId,
      source: source ?? this.source,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (position.present) {
      map['position'] = Variable<int>(position.value);
    }
    if (songId.present) {
      map['song_id'] = Variable<String>(songId.value);
    }
    if (source.present) {
      map['source'] = Variable<String>(source.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('QueueItemsCompanion(')
          ..write('position: $position, ')
          ..write('songId: $songId, ')
          ..write('source: $source')
          ..write(')'))
        .toString();
  }
}

class $LocalItemsTable extends LocalItems
    with TableInfo<$LocalItemsTable, LocalItem> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LocalItemsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _pathMeta = const VerificationMeta('path');
  @override
  late final GeneratedColumn<String> path = GeneratedColumn<String>(
    'path',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _artistMeta = const VerificationMeta('artist');
  @override
  late final GeneratedColumn<String> artist = GeneratedColumn<String>(
    'artist',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _albumMeta = const VerificationMeta('album');
  @override
  late final GeneratedColumn<String> album = GeneratedColumn<String>(
    'album',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _durationSecondsMeta = const VerificationMeta(
    'durationSeconds',
  );
  @override
  late final GeneratedColumn<int> durationSeconds = GeneratedColumn<int>(
    'duration_seconds',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _dateAddedMeta = const VerificationMeta(
    'dateAdded',
  );
  @override
  late final GeneratedColumn<DateTime> dateAdded = GeneratedColumn<DateTime>(
    'date_added',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    path,
    title,
    artist,
    album,
    durationSeconds,
    dateAdded,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'local_items';
  @override
  VerificationContext validateIntegrity(
    Insertable<LocalItem> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('path')) {
      context.handle(
        _pathMeta,
        path.isAcceptableOrUnknown(data['path']!, _pathMeta),
      );
    } else if (isInserting) {
      context.missing(_pathMeta);
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    }
    if (data.containsKey('artist')) {
      context.handle(
        _artistMeta,
        artist.isAcceptableOrUnknown(data['artist']!, _artistMeta),
      );
    }
    if (data.containsKey('album')) {
      context.handle(
        _albumMeta,
        album.isAcceptableOrUnknown(data['album']!, _albumMeta),
      );
    }
    if (data.containsKey('duration_seconds')) {
      context.handle(
        _durationSecondsMeta,
        durationSeconds.isAcceptableOrUnknown(
          data['duration_seconds']!,
          _durationSecondsMeta,
        ),
      );
    }
    if (data.containsKey('date_added')) {
      context.handle(
        _dateAddedMeta,
        dateAdded.isAcceptableOrUnknown(data['date_added']!, _dateAddedMeta),
      );
    } else if (isInserting) {
      context.missing(_dateAddedMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {path};
  @override
  LocalItem map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LocalItem(
      path: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}path'],
      )!,
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      ),
      artist: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}artist'],
      ),
      album: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}album'],
      ),
      durationSeconds: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}duration_seconds'],
      ),
      dateAdded: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}date_added'],
      )!,
    );
  }

  @override
  $LocalItemsTable createAlias(String alias) {
    return $LocalItemsTable(attachedDatabase, alias);
  }
}

class LocalItem extends DataClass implements Insertable<LocalItem> {
  final String path;
  final String? title;
  final String? artist;
  final String? album;
  final int? durationSeconds;
  final DateTime dateAdded;
  const LocalItem({
    required this.path,
    this.title,
    this.artist,
    this.album,
    this.durationSeconds,
    required this.dateAdded,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['path'] = Variable<String>(path);
    if (!nullToAbsent || title != null) {
      map['title'] = Variable<String>(title);
    }
    if (!nullToAbsent || artist != null) {
      map['artist'] = Variable<String>(artist);
    }
    if (!nullToAbsent || album != null) {
      map['album'] = Variable<String>(album);
    }
    if (!nullToAbsent || durationSeconds != null) {
      map['duration_seconds'] = Variable<int>(durationSeconds);
    }
    map['date_added'] = Variable<DateTime>(dateAdded);
    return map;
  }

  LocalItemsCompanion toCompanion(bool nullToAbsent) {
    return LocalItemsCompanion(
      path: Value(path),
      title: title == null && nullToAbsent
          ? const Value.absent()
          : Value(title),
      artist: artist == null && nullToAbsent
          ? const Value.absent()
          : Value(artist),
      album: album == null && nullToAbsent
          ? const Value.absent()
          : Value(album),
      durationSeconds: durationSeconds == null && nullToAbsent
          ? const Value.absent()
          : Value(durationSeconds),
      dateAdded: Value(dateAdded),
    );
  }

  factory LocalItem.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LocalItem(
      path: serializer.fromJson<String>(json['path']),
      title: serializer.fromJson<String?>(json['title']),
      artist: serializer.fromJson<String?>(json['artist']),
      album: serializer.fromJson<String?>(json['album']),
      durationSeconds: serializer.fromJson<int?>(json['durationSeconds']),
      dateAdded: serializer.fromJson<DateTime>(json['dateAdded']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'path': serializer.toJson<String>(path),
      'title': serializer.toJson<String?>(title),
      'artist': serializer.toJson<String?>(artist),
      'album': serializer.toJson<String?>(album),
      'durationSeconds': serializer.toJson<int?>(durationSeconds),
      'dateAdded': serializer.toJson<DateTime>(dateAdded),
    };
  }

  LocalItem copyWith({
    String? path,
    Value<String?> title = const Value.absent(),
    Value<String?> artist = const Value.absent(),
    Value<String?> album = const Value.absent(),
    Value<int?> durationSeconds = const Value.absent(),
    DateTime? dateAdded,
  }) => LocalItem(
    path: path ?? this.path,
    title: title.present ? title.value : this.title,
    artist: artist.present ? artist.value : this.artist,
    album: album.present ? album.value : this.album,
    durationSeconds: durationSeconds.present
        ? durationSeconds.value
        : this.durationSeconds,
    dateAdded: dateAdded ?? this.dateAdded,
  );
  LocalItem copyWithCompanion(LocalItemsCompanion data) {
    return LocalItem(
      path: data.path.present ? data.path.value : this.path,
      title: data.title.present ? data.title.value : this.title,
      artist: data.artist.present ? data.artist.value : this.artist,
      album: data.album.present ? data.album.value : this.album,
      durationSeconds: data.durationSeconds.present
          ? data.durationSeconds.value
          : this.durationSeconds,
      dateAdded: data.dateAdded.present ? data.dateAdded.value : this.dateAdded,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LocalItem(')
          ..write('path: $path, ')
          ..write('title: $title, ')
          ..write('artist: $artist, ')
          ..write('album: $album, ')
          ..write('durationSeconds: $durationSeconds, ')
          ..write('dateAdded: $dateAdded')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(path, title, artist, album, durationSeconds, dateAdded);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LocalItem &&
          other.path == this.path &&
          other.title == this.title &&
          other.artist == this.artist &&
          other.album == this.album &&
          other.durationSeconds == this.durationSeconds &&
          other.dateAdded == this.dateAdded);
}

class LocalItemsCompanion extends UpdateCompanion<LocalItem> {
  final Value<String> path;
  final Value<String?> title;
  final Value<String?> artist;
  final Value<String?> album;
  final Value<int?> durationSeconds;
  final Value<DateTime> dateAdded;
  final Value<int> rowid;
  const LocalItemsCompanion({
    this.path = const Value.absent(),
    this.title = const Value.absent(),
    this.artist = const Value.absent(),
    this.album = const Value.absent(),
    this.durationSeconds = const Value.absent(),
    this.dateAdded = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  LocalItemsCompanion.insert({
    required String path,
    this.title = const Value.absent(),
    this.artist = const Value.absent(),
    this.album = const Value.absent(),
    this.durationSeconds = const Value.absent(),
    required DateTime dateAdded,
    this.rowid = const Value.absent(),
  }) : path = Value(path),
       dateAdded = Value(dateAdded);
  static Insertable<LocalItem> custom({
    Expression<String>? path,
    Expression<String>? title,
    Expression<String>? artist,
    Expression<String>? album,
    Expression<int>? durationSeconds,
    Expression<DateTime>? dateAdded,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (path != null) 'path': path,
      if (title != null) 'title': title,
      if (artist != null) 'artist': artist,
      if (album != null) 'album': album,
      if (durationSeconds != null) 'duration_seconds': durationSeconds,
      if (dateAdded != null) 'date_added': dateAdded,
      if (rowid != null) 'rowid': rowid,
    });
  }

  LocalItemsCompanion copyWith({
    Value<String>? path,
    Value<String?>? title,
    Value<String?>? artist,
    Value<String?>? album,
    Value<int?>? durationSeconds,
    Value<DateTime>? dateAdded,
    Value<int>? rowid,
  }) {
    return LocalItemsCompanion(
      path: path ?? this.path,
      title: title ?? this.title,
      artist: artist ?? this.artist,
      album: album ?? this.album,
      durationSeconds: durationSeconds ?? this.durationSeconds,
      dateAdded: dateAdded ?? this.dateAdded,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (path.present) {
      map['path'] = Variable<String>(path.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (artist.present) {
      map['artist'] = Variable<String>(artist.value);
    }
    if (album.present) {
      map['album'] = Variable<String>(album.value);
    }
    if (durationSeconds.present) {
      map['duration_seconds'] = Variable<int>(durationSeconds.value);
    }
    if (dateAdded.present) {
      map['date_added'] = Variable<DateTime>(dateAdded.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LocalItemsCompanion(')
          ..write('path: $path, ')
          ..write('title: $title, ')
          ..write('artist: $artist, ')
          ..write('album: $album, ')
          ..write('durationSeconds: $durationSeconds, ')
          ..write('dateAdded: $dateAdded, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $CacheEntriesTable extends CacheEntries
    with TableInfo<$CacheEntriesTable, CacheEntry> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CacheEntriesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _keyMeta = const VerificationMeta('key');
  @override
  late final GeneratedColumn<String> key = GeneratedColumn<String>(
    'key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _filePathMeta = const VerificationMeta(
    'filePath',
  );
  @override
  late final GeneratedColumn<String> filePath = GeneratedColumn<String>(
    'file_path',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sizeBytesMeta = const VerificationMeta(
    'sizeBytes',
  );
  @override
  late final GeneratedColumn<int> sizeBytes = GeneratedColumn<int>(
    'size_bytes',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _lastAccessedMeta = const VerificationMeta(
    'lastAccessed',
  );
  @override
  late final GeneratedColumn<DateTime> lastAccessed = GeneratedColumn<DateTime>(
    'last_accessed',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    key,
    filePath,
    sizeBytes,
    lastAccessed,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'cache_entries';
  @override
  VerificationContext validateIntegrity(
    Insertable<CacheEntry> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('key')) {
      context.handle(
        _keyMeta,
        key.isAcceptableOrUnknown(data['key']!, _keyMeta),
      );
    } else if (isInserting) {
      context.missing(_keyMeta);
    }
    if (data.containsKey('file_path')) {
      context.handle(
        _filePathMeta,
        filePath.isAcceptableOrUnknown(data['file_path']!, _filePathMeta),
      );
    } else if (isInserting) {
      context.missing(_filePathMeta);
    }
    if (data.containsKey('size_bytes')) {
      context.handle(
        _sizeBytesMeta,
        sizeBytes.isAcceptableOrUnknown(data['size_bytes']!, _sizeBytesMeta),
      );
    } else if (isInserting) {
      context.missing(_sizeBytesMeta);
    }
    if (data.containsKey('last_accessed')) {
      context.handle(
        _lastAccessedMeta,
        lastAccessed.isAcceptableOrUnknown(
          data['last_accessed']!,
          _lastAccessedMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_lastAccessedMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {key};
  @override
  CacheEntry map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CacheEntry(
      key: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}key'],
      )!,
      filePath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}file_path'],
      )!,
      sizeBytes: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}size_bytes'],
      )!,
      lastAccessed: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}last_accessed'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $CacheEntriesTable createAlias(String alias) {
    return $CacheEntriesTable(attachedDatabase, alias);
  }
}

class CacheEntry extends DataClass implements Insertable<CacheEntry> {
  /// videoId + itag.
  final String key;
  final String filePath;
  final int sizeBytes;
  final DateTime lastAccessed;
  final DateTime createdAt;
  const CacheEntry({
    required this.key,
    required this.filePath,
    required this.sizeBytes,
    required this.lastAccessed,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['key'] = Variable<String>(key);
    map['file_path'] = Variable<String>(filePath);
    map['size_bytes'] = Variable<int>(sizeBytes);
    map['last_accessed'] = Variable<DateTime>(lastAccessed);
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  CacheEntriesCompanion toCompanion(bool nullToAbsent) {
    return CacheEntriesCompanion(
      key: Value(key),
      filePath: Value(filePath),
      sizeBytes: Value(sizeBytes),
      lastAccessed: Value(lastAccessed),
      createdAt: Value(createdAt),
    );
  }

  factory CacheEntry.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CacheEntry(
      key: serializer.fromJson<String>(json['key']),
      filePath: serializer.fromJson<String>(json['filePath']),
      sizeBytes: serializer.fromJson<int>(json['sizeBytes']),
      lastAccessed: serializer.fromJson<DateTime>(json['lastAccessed']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'key': serializer.toJson<String>(key),
      'filePath': serializer.toJson<String>(filePath),
      'sizeBytes': serializer.toJson<int>(sizeBytes),
      'lastAccessed': serializer.toJson<DateTime>(lastAccessed),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  CacheEntry copyWith({
    String? key,
    String? filePath,
    int? sizeBytes,
    DateTime? lastAccessed,
    DateTime? createdAt,
  }) => CacheEntry(
    key: key ?? this.key,
    filePath: filePath ?? this.filePath,
    sizeBytes: sizeBytes ?? this.sizeBytes,
    lastAccessed: lastAccessed ?? this.lastAccessed,
    createdAt: createdAt ?? this.createdAt,
  );
  CacheEntry copyWithCompanion(CacheEntriesCompanion data) {
    return CacheEntry(
      key: data.key.present ? data.key.value : this.key,
      filePath: data.filePath.present ? data.filePath.value : this.filePath,
      sizeBytes: data.sizeBytes.present ? data.sizeBytes.value : this.sizeBytes,
      lastAccessed: data.lastAccessed.present
          ? data.lastAccessed.value
          : this.lastAccessed,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CacheEntry(')
          ..write('key: $key, ')
          ..write('filePath: $filePath, ')
          ..write('sizeBytes: $sizeBytes, ')
          ..write('lastAccessed: $lastAccessed, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(key, filePath, sizeBytes, lastAccessed, createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CacheEntry &&
          other.key == this.key &&
          other.filePath == this.filePath &&
          other.sizeBytes == this.sizeBytes &&
          other.lastAccessed == this.lastAccessed &&
          other.createdAt == this.createdAt);
}

class CacheEntriesCompanion extends UpdateCompanion<CacheEntry> {
  final Value<String> key;
  final Value<String> filePath;
  final Value<int> sizeBytes;
  final Value<DateTime> lastAccessed;
  final Value<DateTime> createdAt;
  final Value<int> rowid;
  const CacheEntriesCompanion({
    this.key = const Value.absent(),
    this.filePath = const Value.absent(),
    this.sizeBytes = const Value.absent(),
    this.lastAccessed = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  CacheEntriesCompanion.insert({
    required String key,
    required String filePath,
    required int sizeBytes,
    required DateTime lastAccessed,
    required DateTime createdAt,
    this.rowid = const Value.absent(),
  }) : key = Value(key),
       filePath = Value(filePath),
       sizeBytes = Value(sizeBytes),
       lastAccessed = Value(lastAccessed),
       createdAt = Value(createdAt);
  static Insertable<CacheEntry> custom({
    Expression<String>? key,
    Expression<String>? filePath,
    Expression<int>? sizeBytes,
    Expression<DateTime>? lastAccessed,
    Expression<DateTime>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (key != null) 'key': key,
      if (filePath != null) 'file_path': filePath,
      if (sizeBytes != null) 'size_bytes': sizeBytes,
      if (lastAccessed != null) 'last_accessed': lastAccessed,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  CacheEntriesCompanion copyWith({
    Value<String>? key,
    Value<String>? filePath,
    Value<int>? sizeBytes,
    Value<DateTime>? lastAccessed,
    Value<DateTime>? createdAt,
    Value<int>? rowid,
  }) {
    return CacheEntriesCompanion(
      key: key ?? this.key,
      filePath: filePath ?? this.filePath,
      sizeBytes: sizeBytes ?? this.sizeBytes,
      lastAccessed: lastAccessed ?? this.lastAccessed,
      createdAt: createdAt ?? this.createdAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (key.present) {
      map['key'] = Variable<String>(key.value);
    }
    if (filePath.present) {
      map['file_path'] = Variable<String>(filePath.value);
    }
    if (sizeBytes.present) {
      map['size_bytes'] = Variable<int>(sizeBytes.value);
    }
    if (lastAccessed.present) {
      map['last_accessed'] = Variable<DateTime>(lastAccessed.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CacheEntriesCompanion(')
          ..write('key: $key, ')
          ..write('filePath: $filePath, ')
          ..write('sizeBytes: $sizeBytes, ')
          ..write('lastAccessed: $lastAccessed, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $DownloadJobsTable extends DownloadJobs
    with TableInfo<$DownloadJobsTable, DownloadJob> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $DownloadJobsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _songIdMeta = const VerificationMeta('songId');
  @override
  late final GeneratedColumn<String> songId = GeneratedColumn<String>(
    'song_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES songs (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<int> status = GeneratedColumn<int>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _qualityMeta = const VerificationMeta(
    'quality',
  );
  @override
  late final GeneratedColumn<int> quality = GeneratedColumn<int>(
    'quality',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _bytesDownloadedMeta = const VerificationMeta(
    'bytesDownloaded',
  );
  @override
  late final GeneratedColumn<int> bytesDownloaded = GeneratedColumn<int>(
    'bytes_downloaded',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _totalBytesMeta = const VerificationMeta(
    'totalBytes',
  );
  @override
  late final GeneratedColumn<int> totalBytes = GeneratedColumn<int>(
    'total_bytes',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _attemptsMeta = const VerificationMeta(
    'attempts',
  );
  @override
  late final GeneratedColumn<int> attempts = GeneratedColumn<int>(
    'attempts',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _errorMessageMeta = const VerificationMeta(
    'errorMessage',
  );
  @override
  late final GeneratedColumn<String> errorMessage = GeneratedColumn<String>(
    'error_message',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    songId,
    status,
    quality,
    bytesDownloaded,
    totalBytes,
    attempts,
    errorMessage,
    createdAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'download_jobs';
  @override
  VerificationContext validateIntegrity(
    Insertable<DownloadJob> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('song_id')) {
      context.handle(
        _songIdMeta,
        songId.isAcceptableOrUnknown(data['song_id']!, _songIdMeta),
      );
    } else if (isInserting) {
      context.missing(_songIdMeta);
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    } else if (isInserting) {
      context.missing(_statusMeta);
    }
    if (data.containsKey('quality')) {
      context.handle(
        _qualityMeta,
        quality.isAcceptableOrUnknown(data['quality']!, _qualityMeta),
      );
    }
    if (data.containsKey('bytes_downloaded')) {
      context.handle(
        _bytesDownloadedMeta,
        bytesDownloaded.isAcceptableOrUnknown(
          data['bytes_downloaded']!,
          _bytesDownloadedMeta,
        ),
      );
    }
    if (data.containsKey('total_bytes')) {
      context.handle(
        _totalBytesMeta,
        totalBytes.isAcceptableOrUnknown(data['total_bytes']!, _totalBytesMeta),
      );
    }
    if (data.containsKey('attempts')) {
      context.handle(
        _attemptsMeta,
        attempts.isAcceptableOrUnknown(data['attempts']!, _attemptsMeta),
      );
    }
    if (data.containsKey('error_message')) {
      context.handle(
        _errorMessageMeta,
        errorMessage.isAcceptableOrUnknown(
          data['error_message']!,
          _errorMessageMeta,
        ),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {songId};
  @override
  DownloadJob map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return DownloadJob(
      songId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}song_id'],
      )!,
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}status'],
      )!,
      quality: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}quality'],
      ),
      bytesDownloaded: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}bytes_downloaded'],
      )!,
      totalBytes: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}total_bytes'],
      ),
      attempts: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}attempts'],
      )!,
      errorMessage: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}error_message'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      ),
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $DownloadJobsTable createAlias(String alias) {
    return $DownloadJobsTable(attachedDatabase, alias);
  }
}

class DownloadJob extends DataClass implements Insertable<DownloadJob> {
  final String songId;

  /// Lihat [DownloadJobStatus].
  final int status;

  /// Kualitas unduhan sebagai itag yang dipilih
  /// (251 Terbaik, 140 Seimbang, 249/139 Hemat data; lihat
  /// `DownloadQuality` di lib/downloads). Null berarti kualitas tidak
  /// diketahui (job dari skema v1).
  final int? quality;
  final int bytesDownloaded;
  final int? totalBytes;

  /// Jumlah percobaan unduh yang sudah dipakai (maks 3, PRD B3.2).
  final int attempts;
  final String? errorMessage;

  /// Waktu job dibuat: penentu urutan antrean FIFO. Null untuk job v1
  /// (diperlakukan sebagai yang paling tua).
  final DateTime? createdAt;
  final DateTime updatedAt;
  const DownloadJob({
    required this.songId,
    required this.status,
    this.quality,
    required this.bytesDownloaded,
    this.totalBytes,
    required this.attempts,
    this.errorMessage,
    this.createdAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['song_id'] = Variable<String>(songId);
    map['status'] = Variable<int>(status);
    if (!nullToAbsent || quality != null) {
      map['quality'] = Variable<int>(quality);
    }
    map['bytes_downloaded'] = Variable<int>(bytesDownloaded);
    if (!nullToAbsent || totalBytes != null) {
      map['total_bytes'] = Variable<int>(totalBytes);
    }
    map['attempts'] = Variable<int>(attempts);
    if (!nullToAbsent || errorMessage != null) {
      map['error_message'] = Variable<String>(errorMessage);
    }
    if (!nullToAbsent || createdAt != null) {
      map['created_at'] = Variable<DateTime>(createdAt);
    }
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  DownloadJobsCompanion toCompanion(bool nullToAbsent) {
    return DownloadJobsCompanion(
      songId: Value(songId),
      status: Value(status),
      quality: quality == null && nullToAbsent
          ? const Value.absent()
          : Value(quality),
      bytesDownloaded: Value(bytesDownloaded),
      totalBytes: totalBytes == null && nullToAbsent
          ? const Value.absent()
          : Value(totalBytes),
      attempts: Value(attempts),
      errorMessage: errorMessage == null && nullToAbsent
          ? const Value.absent()
          : Value(errorMessage),
      createdAt: createdAt == null && nullToAbsent
          ? const Value.absent()
          : Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory DownloadJob.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return DownloadJob(
      songId: serializer.fromJson<String>(json['songId']),
      status: serializer.fromJson<int>(json['status']),
      quality: serializer.fromJson<int?>(json['quality']),
      bytesDownloaded: serializer.fromJson<int>(json['bytesDownloaded']),
      totalBytes: serializer.fromJson<int?>(json['totalBytes']),
      attempts: serializer.fromJson<int>(json['attempts']),
      errorMessage: serializer.fromJson<String?>(json['errorMessage']),
      createdAt: serializer.fromJson<DateTime?>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'songId': serializer.toJson<String>(songId),
      'status': serializer.toJson<int>(status),
      'quality': serializer.toJson<int?>(quality),
      'bytesDownloaded': serializer.toJson<int>(bytesDownloaded),
      'totalBytes': serializer.toJson<int?>(totalBytes),
      'attempts': serializer.toJson<int>(attempts),
      'errorMessage': serializer.toJson<String?>(errorMessage),
      'createdAt': serializer.toJson<DateTime?>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  DownloadJob copyWith({
    String? songId,
    int? status,
    Value<int?> quality = const Value.absent(),
    int? bytesDownloaded,
    Value<int?> totalBytes = const Value.absent(),
    int? attempts,
    Value<String?> errorMessage = const Value.absent(),
    Value<DateTime?> createdAt = const Value.absent(),
    DateTime? updatedAt,
  }) => DownloadJob(
    songId: songId ?? this.songId,
    status: status ?? this.status,
    quality: quality.present ? quality.value : this.quality,
    bytesDownloaded: bytesDownloaded ?? this.bytesDownloaded,
    totalBytes: totalBytes.present ? totalBytes.value : this.totalBytes,
    attempts: attempts ?? this.attempts,
    errorMessage: errorMessage.present ? errorMessage.value : this.errorMessage,
    createdAt: createdAt.present ? createdAt.value : this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  DownloadJob copyWithCompanion(DownloadJobsCompanion data) {
    return DownloadJob(
      songId: data.songId.present ? data.songId.value : this.songId,
      status: data.status.present ? data.status.value : this.status,
      quality: data.quality.present ? data.quality.value : this.quality,
      bytesDownloaded: data.bytesDownloaded.present
          ? data.bytesDownloaded.value
          : this.bytesDownloaded,
      totalBytes: data.totalBytes.present
          ? data.totalBytes.value
          : this.totalBytes,
      attempts: data.attempts.present ? data.attempts.value : this.attempts,
      errorMessage: data.errorMessage.present
          ? data.errorMessage.value
          : this.errorMessage,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('DownloadJob(')
          ..write('songId: $songId, ')
          ..write('status: $status, ')
          ..write('quality: $quality, ')
          ..write('bytesDownloaded: $bytesDownloaded, ')
          ..write('totalBytes: $totalBytes, ')
          ..write('attempts: $attempts, ')
          ..write('errorMessage: $errorMessage, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    songId,
    status,
    quality,
    bytesDownloaded,
    totalBytes,
    attempts,
    errorMessage,
    createdAt,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DownloadJob &&
          other.songId == this.songId &&
          other.status == this.status &&
          other.quality == this.quality &&
          other.bytesDownloaded == this.bytesDownloaded &&
          other.totalBytes == this.totalBytes &&
          other.attempts == this.attempts &&
          other.errorMessage == this.errorMessage &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class DownloadJobsCompanion extends UpdateCompanion<DownloadJob> {
  final Value<String> songId;
  final Value<int> status;
  final Value<int?> quality;
  final Value<int> bytesDownloaded;
  final Value<int?> totalBytes;
  final Value<int> attempts;
  final Value<String?> errorMessage;
  final Value<DateTime?> createdAt;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const DownloadJobsCompanion({
    this.songId = const Value.absent(),
    this.status = const Value.absent(),
    this.quality = const Value.absent(),
    this.bytesDownloaded = const Value.absent(),
    this.totalBytes = const Value.absent(),
    this.attempts = const Value.absent(),
    this.errorMessage = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  DownloadJobsCompanion.insert({
    required String songId,
    required int status,
    this.quality = const Value.absent(),
    this.bytesDownloaded = const Value.absent(),
    this.totalBytes = const Value.absent(),
    this.attempts = const Value.absent(),
    this.errorMessage = const Value.absent(),
    this.createdAt = const Value.absent(),
    required DateTime updatedAt,
    this.rowid = const Value.absent(),
  }) : songId = Value(songId),
       status = Value(status),
       updatedAt = Value(updatedAt);
  static Insertable<DownloadJob> custom({
    Expression<String>? songId,
    Expression<int>? status,
    Expression<int>? quality,
    Expression<int>? bytesDownloaded,
    Expression<int>? totalBytes,
    Expression<int>? attempts,
    Expression<String>? errorMessage,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (songId != null) 'song_id': songId,
      if (status != null) 'status': status,
      if (quality != null) 'quality': quality,
      if (bytesDownloaded != null) 'bytes_downloaded': bytesDownloaded,
      if (totalBytes != null) 'total_bytes': totalBytes,
      if (attempts != null) 'attempts': attempts,
      if (errorMessage != null) 'error_message': errorMessage,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  DownloadJobsCompanion copyWith({
    Value<String>? songId,
    Value<int>? status,
    Value<int?>? quality,
    Value<int>? bytesDownloaded,
    Value<int?>? totalBytes,
    Value<int>? attempts,
    Value<String?>? errorMessage,
    Value<DateTime?>? createdAt,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return DownloadJobsCompanion(
      songId: songId ?? this.songId,
      status: status ?? this.status,
      quality: quality ?? this.quality,
      bytesDownloaded: bytesDownloaded ?? this.bytesDownloaded,
      totalBytes: totalBytes ?? this.totalBytes,
      attempts: attempts ?? this.attempts,
      errorMessage: errorMessage ?? this.errorMessage,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (songId.present) {
      map['song_id'] = Variable<String>(songId.value);
    }
    if (status.present) {
      map['status'] = Variable<int>(status.value);
    }
    if (quality.present) {
      map['quality'] = Variable<int>(quality.value);
    }
    if (bytesDownloaded.present) {
      map['bytes_downloaded'] = Variable<int>(bytesDownloaded.value);
    }
    if (totalBytes.present) {
      map['total_bytes'] = Variable<int>(totalBytes.value);
    }
    if (attempts.present) {
      map['attempts'] = Variable<int>(attempts.value);
    }
    if (errorMessage.present) {
      map['error_message'] = Variable<String>(errorMessage.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('DownloadJobsCompanion(')
          ..write('songId: $songId, ')
          ..write('status: $status, ')
          ..write('quality: $quality, ')
          ..write('bytesDownloaded: $bytesDownloaded, ')
          ..write('totalBytes: $totalBytes, ')
          ..write('attempts: $attempts, ')
          ..write('errorMessage: $errorMessage, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$LarasDatabase extends GeneratedDatabase {
  _$LarasDatabase(QueryExecutor e) : super(e);
  late final LibrarySearch librarySearch = LibrarySearch(this);
  late final $AlbumsTable albums = $AlbumsTable(this);
  late final $FormatsTable formats = $FormatsTable(this);
  late final $SongsTable songs = $SongsTable(this);
  late final $ArtistsTable artists = $ArtistsTable(this);
  late final $SongArtistsTable songArtists = $SongArtistsTable(this);
  late final $AlbumArtistsTable albumArtists = $AlbumArtistsTable(this);
  late final $PlaylistsTable playlists = $PlaylistsTable(this);
  late final $PlaylistSongsTable playlistSongs = $PlaylistSongsTable(this);
  late final $LyricsTable lyrics = $LyricsTable(this);
  late final $PlayEventsTable playEvents = $PlayEventsTable(this);
  late final $SearchHistoryTable searchHistory = $SearchHistoryTable(this);
  late final $QueueItemsTable queueItems = $QueueItemsTable(this);
  late final $LocalItemsTable localItems = $LocalItemsTable(this);
  late final $CacheEntriesTable cacheEntries = $CacheEntriesTable(this);
  late final $DownloadJobsTable downloadJobs = $DownloadJobsTable(this);
  late final Index songsTitleIdx = Index(
    'songs_title_idx',
    'CREATE INDEX songs_title_idx ON songs (title)',
  );
  late final Index songsLibraryIdx = Index(
    'songs_library_idx',
    'CREATE INDEX songs_library_idx ON songs (in_library, date_added)',
  );
  late final Index songsPlayedIdx = Index(
    'songs_played_idx',
    'CREATE INDEX songs_played_idx ON songs (in_library, total_play_time_ms)',
  );
  late final Index albumsTitleIdx = Index(
    'albums_title_idx',
    'CREATE INDEX albums_title_idx ON albums (title)',
  );
  late final Index artistsNameIdx = Index(
    'artists_name_idx',
    'CREATE INDEX artists_name_idx ON artists (name)',
  );
  late final Index songArtistsArtistIdx = Index(
    'song_artists_artist_idx',
    'CREATE INDEX song_artists_artist_idx ON song_artists (artist_id)',
  );
  late final Index albumArtistsArtistIdx = Index(
    'album_artists_artist_idx',
    'CREATE INDEX album_artists_artist_idx ON album_artists (artist_id)',
  );
  late final Index playlistSongsOrderIdx = Index(
    'playlist_songs_order_idx',
    'CREATE INDEX playlist_songs_order_idx ON playlist_songs (playlist_id, position)',
  );
  late final Index formatsSongIdx = Index(
    'formats_song_idx',
    'CREATE INDEX formats_song_idx ON formats (song_id)',
  );
  late final Index playEventsSongIdx = Index(
    'play_events_song_idx',
    'CREATE INDEX play_events_song_idx ON play_events (song_id, timestamp)',
  );
  late final Index playEventsRecentIdx = Index(
    'play_events_recent_idx',
    'CREATE INDEX play_events_recent_idx ON play_events (timestamp, id)',
  );
  late final Index cacheEntriesLruIdx = Index(
    'cache_entries_lru_idx',
    'CREATE INDEX cache_entries_lru_idx ON cache_entries (last_accessed)',
  );
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    librarySearch,
    albums,
    formats,
    songs,
    artists,
    songArtists,
    albumArtists,
    playlists,
    playlistSongs,
    lyrics,
    playEvents,
    searchHistory,
    queueItems,
    localItems,
    cacheEntries,
    downloadJobs,
    songsTitleIdx,
    songsLibraryIdx,
    songsPlayedIdx,
    albumsTitleIdx,
    artistsNameIdx,
    songArtistsArtistIdx,
    albumArtistsArtistIdx,
    playlistSongsOrderIdx,
    formatsSongIdx,
    playEventsSongIdx,
    playEventsRecentIdx,
    cacheEntriesLruIdx,
  ];
  @override
  StreamQueryUpdateRules get streamUpdateRules => const StreamQueryUpdateRules([
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'songs',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('formats', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'albums',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('songs', kind: UpdateKind.update)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'formats',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('songs', kind: UpdateKind.update)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'songs',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('song_artists', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'artists',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('song_artists', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'albums',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('album_artists', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'artists',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('album_artists', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'playlists',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('playlist_songs', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'songs',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('playlist_songs', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'songs',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('lyrics', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'songs',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('play_events', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'songs',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('queue_items', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'songs',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('download_jobs', kind: UpdateKind.delete)],
    ),
  ]);
}
