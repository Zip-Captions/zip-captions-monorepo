// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'transcript_database.dart';

// ignore_for_file: type=lint
class $TranscriptSessionsTable extends TranscriptSessions
    with TableInfo<$TranscriptSessionsTable, TranscriptSessionRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $TranscriptSessionsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _sessionIdMeta = const VerificationMeta(
    'sessionId',
  );
  @override
  late final GeneratedColumn<String> sessionId = GeneratedColumn<String>(
    'session_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _dateMeta = const VerificationMeta('date');
  @override
  late final GeneratedColumn<DateTime> date = GeneratedColumn<DateTime>(
    'date',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
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
  static const VerificationMeta _durationMsMeta = const VerificationMeta(
    'durationMs',
  );
  @override
  late final GeneratedColumn<int> durationMs = GeneratedColumn<int>(
    'duration_ms',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _segmentCountMeta = const VerificationMeta(
    'segmentCount',
  );
  @override
  late final GeneratedColumn<int> segmentCount = GeneratedColumn<int>(
    'segment_count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  @override
  List<GeneratedColumn> get $columns => [
    sessionId,
    date,
    title,
    durationMs,
    segmentCount,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'transcript_sessions';
  @override
  VerificationContext validateIntegrity(
    Insertable<TranscriptSessionRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('session_id')) {
      context.handle(
        _sessionIdMeta,
        sessionId.isAcceptableOrUnknown(data['session_id']!, _sessionIdMeta),
      );
    } else if (isInserting) {
      context.missing(_sessionIdMeta);
    }
    if (data.containsKey('date')) {
      context.handle(
        _dateMeta,
        date.isAcceptableOrUnknown(data['date']!, _dateMeta),
      );
    } else if (isInserting) {
      context.missing(_dateMeta);
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    }
    if (data.containsKey('duration_ms')) {
      context.handle(
        _durationMsMeta,
        durationMs.isAcceptableOrUnknown(data['duration_ms']!, _durationMsMeta),
      );
    }
    if (data.containsKey('segment_count')) {
      context.handle(
        _segmentCountMeta,
        segmentCount.isAcceptableOrUnknown(
          data['segment_count']!,
          _segmentCountMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {sessionId};
  @override
  TranscriptSessionRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return TranscriptSessionRow(
      sessionId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}session_id'],
      )!,
      date: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}date'],
      )!,
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      ),
      durationMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}duration_ms'],
      )!,
      segmentCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}segment_count'],
      )!,
    );
  }

  @override
  $TranscriptSessionsTable createAlias(String alias) {
    return $TranscriptSessionsTable(attachedDatabase, alias);
  }
}

class TranscriptSessionRow extends DataClass
    implements Insertable<TranscriptSessionRow> {
  /// UUID primary key identifying the session.
  final String sessionId;

  /// Wall-clock timestamp when the session started.
  final DateTime date;

  /// Optional user-assigned session title.
  final String? title;

  /// Total session duration in milliseconds.
  final int durationMs;

  /// Number of segments persisted for this session.
  final int segmentCount;
  const TranscriptSessionRow({
    required this.sessionId,
    required this.date,
    this.title,
    required this.durationMs,
    required this.segmentCount,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['session_id'] = Variable<String>(sessionId);
    map['date'] = Variable<DateTime>(date);
    if (!nullToAbsent || title != null) {
      map['title'] = Variable<String>(title);
    }
    map['duration_ms'] = Variable<int>(durationMs);
    map['segment_count'] = Variable<int>(segmentCount);
    return map;
  }

  TranscriptSessionsCompanion toCompanion(bool nullToAbsent) {
    return TranscriptSessionsCompanion(
      sessionId: Value(sessionId),
      date: Value(date),
      title: title == null && nullToAbsent
          ? const Value.absent()
          : Value(title),
      durationMs: Value(durationMs),
      segmentCount: Value(segmentCount),
    );
  }

  factory TranscriptSessionRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return TranscriptSessionRow(
      sessionId: serializer.fromJson<String>(json['sessionId']),
      date: serializer.fromJson<DateTime>(json['date']),
      title: serializer.fromJson<String?>(json['title']),
      durationMs: serializer.fromJson<int>(json['durationMs']),
      segmentCount: serializer.fromJson<int>(json['segmentCount']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'sessionId': serializer.toJson<String>(sessionId),
      'date': serializer.toJson<DateTime>(date),
      'title': serializer.toJson<String?>(title),
      'durationMs': serializer.toJson<int>(durationMs),
      'segmentCount': serializer.toJson<int>(segmentCount),
    };
  }

  TranscriptSessionRow copyWith({
    String? sessionId,
    DateTime? date,
    Value<String?> title = const Value.absent(),
    int? durationMs,
    int? segmentCount,
  }) => TranscriptSessionRow(
    sessionId: sessionId ?? this.sessionId,
    date: date ?? this.date,
    title: title.present ? title.value : this.title,
    durationMs: durationMs ?? this.durationMs,
    segmentCount: segmentCount ?? this.segmentCount,
  );
  TranscriptSessionRow copyWithCompanion(TranscriptSessionsCompanion data) {
    return TranscriptSessionRow(
      sessionId: data.sessionId.present ? data.sessionId.value : this.sessionId,
      date: data.date.present ? data.date.value : this.date,
      title: data.title.present ? data.title.value : this.title,
      durationMs: data.durationMs.present
          ? data.durationMs.value
          : this.durationMs,
      segmentCount: data.segmentCount.present
          ? data.segmentCount.value
          : this.segmentCount,
    );
  }

  @override
  String toString() {
    return (StringBuffer('TranscriptSessionRow(')
          ..write('sessionId: $sessionId, ')
          ..write('date: $date, ')
          ..write('title: $title, ')
          ..write('durationMs: $durationMs, ')
          ..write('segmentCount: $segmentCount')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(sessionId, date, title, durationMs, segmentCount);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is TranscriptSessionRow &&
          other.sessionId == this.sessionId &&
          other.date == this.date &&
          other.title == this.title &&
          other.durationMs == this.durationMs &&
          other.segmentCount == this.segmentCount);
}

class TranscriptSessionsCompanion
    extends UpdateCompanion<TranscriptSessionRow> {
  final Value<String> sessionId;
  final Value<DateTime> date;
  final Value<String?> title;
  final Value<int> durationMs;
  final Value<int> segmentCount;
  final Value<int> rowid;
  const TranscriptSessionsCompanion({
    this.sessionId = const Value.absent(),
    this.date = const Value.absent(),
    this.title = const Value.absent(),
    this.durationMs = const Value.absent(),
    this.segmentCount = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  TranscriptSessionsCompanion.insert({
    required String sessionId,
    required DateTime date,
    this.title = const Value.absent(),
    this.durationMs = const Value.absent(),
    this.segmentCount = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : sessionId = Value(sessionId),
       date = Value(date);
  static Insertable<TranscriptSessionRow> custom({
    Expression<String>? sessionId,
    Expression<DateTime>? date,
    Expression<String>? title,
    Expression<int>? durationMs,
    Expression<int>? segmentCount,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (sessionId != null) 'session_id': sessionId,
      if (date != null) 'date': date,
      if (title != null) 'title': title,
      if (durationMs != null) 'duration_ms': durationMs,
      if (segmentCount != null) 'segment_count': segmentCount,
      if (rowid != null) 'rowid': rowid,
    });
  }

  TranscriptSessionsCompanion copyWith({
    Value<String>? sessionId,
    Value<DateTime>? date,
    Value<String?>? title,
    Value<int>? durationMs,
    Value<int>? segmentCount,
    Value<int>? rowid,
  }) {
    return TranscriptSessionsCompanion(
      sessionId: sessionId ?? this.sessionId,
      date: date ?? this.date,
      title: title ?? this.title,
      durationMs: durationMs ?? this.durationMs,
      segmentCount: segmentCount ?? this.segmentCount,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (sessionId.present) {
      map['session_id'] = Variable<String>(sessionId.value);
    }
    if (date.present) {
      map['date'] = Variable<DateTime>(date.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (durationMs.present) {
      map['duration_ms'] = Variable<int>(durationMs.value);
    }
    if (segmentCount.present) {
      map['segment_count'] = Variable<int>(segmentCount.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('TranscriptSessionsCompanion(')
          ..write('sessionId: $sessionId, ')
          ..write('date: $date, ')
          ..write('title: $title, ')
          ..write('durationMs: $durationMs, ')
          ..write('segmentCount: $segmentCount, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $TranscriptSegmentsTable extends TranscriptSegments
    with TableInfo<$TranscriptSegmentsTable, TranscriptSegmentRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $TranscriptSegmentsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _segmentIdMeta = const VerificationMeta(
    'segmentId',
  );
  @override
  late final GeneratedColumn<String> segmentId = GeneratedColumn<String>(
    'segment_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sessionIdMeta = const VerificationMeta(
    'sessionId',
  );
  @override
  late final GeneratedColumn<String> sessionId = GeneratedColumn<String>(
    'session_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints:
        'NOT NULL REFERENCES transcript_sessions(session_id) ON DELETE CASCADE',
  );
  static const VerificationMeta _segmentTextMeta = const VerificationMeta(
    'segmentText',
  );
  @override
  late final GeneratedColumn<String> segmentText = GeneratedColumn<String>(
    'text',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sourceIdMeta = const VerificationMeta(
    'sourceId',
  );
  @override
  late final GeneratedColumn<String> sourceId = GeneratedColumn<String>(
    'source_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _startTimeMsMeta = const VerificationMeta(
    'startTimeMs',
  );
  @override
  late final GeneratedColumn<int> startTimeMs = GeneratedColumn<int>(
    'start_time_ms',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _endTimeMsMeta = const VerificationMeta(
    'endTimeMs',
  );
  @override
  late final GeneratedColumn<int> endTimeMs = GeneratedColumn<int>(
    'end_time_ms',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    segmentId,
    sessionId,
    segmentText,
    sourceId,
    startTimeMs,
    endTimeMs,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'transcript_segments';
  @override
  VerificationContext validateIntegrity(
    Insertable<TranscriptSegmentRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('segment_id')) {
      context.handle(
        _segmentIdMeta,
        segmentId.isAcceptableOrUnknown(data['segment_id']!, _segmentIdMeta),
      );
    } else if (isInserting) {
      context.missing(_segmentIdMeta);
    }
    if (data.containsKey('session_id')) {
      context.handle(
        _sessionIdMeta,
        sessionId.isAcceptableOrUnknown(data['session_id']!, _sessionIdMeta),
      );
    } else if (isInserting) {
      context.missing(_sessionIdMeta);
    }
    if (data.containsKey('text')) {
      context.handle(
        _segmentTextMeta,
        segmentText.isAcceptableOrUnknown(data['text']!, _segmentTextMeta),
      );
    } else if (isInserting) {
      context.missing(_segmentTextMeta);
    }
    if (data.containsKey('source_id')) {
      context.handle(
        _sourceIdMeta,
        sourceId.isAcceptableOrUnknown(data['source_id']!, _sourceIdMeta),
      );
    } else if (isInserting) {
      context.missing(_sourceIdMeta);
    }
    if (data.containsKey('start_time_ms')) {
      context.handle(
        _startTimeMsMeta,
        startTimeMs.isAcceptableOrUnknown(
          data['start_time_ms']!,
          _startTimeMsMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_startTimeMsMeta);
    }
    if (data.containsKey('end_time_ms')) {
      context.handle(
        _endTimeMsMeta,
        endTimeMs.isAcceptableOrUnknown(data['end_time_ms']!, _endTimeMsMeta),
      );
    } else if (isInserting) {
      context.missing(_endTimeMsMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {segmentId};
  @override
  TranscriptSegmentRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return TranscriptSegmentRow(
      segmentId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}segment_id'],
      )!,
      sessionId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}session_id'],
      )!,
      segmentText: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}text'],
      )!,
      sourceId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source_id'],
      )!,
      startTimeMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}start_time_ms'],
      )!,
      endTimeMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}end_time_ms'],
      )!,
    );
  }

  @override
  $TranscriptSegmentsTable createAlias(String alias) {
    return $TranscriptSegmentsTable(attachedDatabase, alias);
  }
}

class TranscriptSegmentRow extends DataClass
    implements Insertable<TranscriptSegmentRow> {
  /// UUID primary key identifying the segment.
  final String segmentId;

  /// Foreign key to [TranscriptSessions]; cascades on delete.
  final String sessionId;

  /// Transcript text for this segment.
  final String segmentText;

  /// Identifier of the audio source that produced this segment.
  final String sourceId;

  /// Segment start offset in milliseconds relative to session start.
  final int startTimeMs;

  /// Segment end offset in milliseconds relative to session start.
  final int endTimeMs;
  const TranscriptSegmentRow({
    required this.segmentId,
    required this.sessionId,
    required this.segmentText,
    required this.sourceId,
    required this.startTimeMs,
    required this.endTimeMs,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['segment_id'] = Variable<String>(segmentId);
    map['session_id'] = Variable<String>(sessionId);
    map['text'] = Variable<String>(segmentText);
    map['source_id'] = Variable<String>(sourceId);
    map['start_time_ms'] = Variable<int>(startTimeMs);
    map['end_time_ms'] = Variable<int>(endTimeMs);
    return map;
  }

  TranscriptSegmentsCompanion toCompanion(bool nullToAbsent) {
    return TranscriptSegmentsCompanion(
      segmentId: Value(segmentId),
      sessionId: Value(sessionId),
      segmentText: Value(segmentText),
      sourceId: Value(sourceId),
      startTimeMs: Value(startTimeMs),
      endTimeMs: Value(endTimeMs),
    );
  }

  factory TranscriptSegmentRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return TranscriptSegmentRow(
      segmentId: serializer.fromJson<String>(json['segmentId']),
      sessionId: serializer.fromJson<String>(json['sessionId']),
      segmentText: serializer.fromJson<String>(json['segmentText']),
      sourceId: serializer.fromJson<String>(json['sourceId']),
      startTimeMs: serializer.fromJson<int>(json['startTimeMs']),
      endTimeMs: serializer.fromJson<int>(json['endTimeMs']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'segmentId': serializer.toJson<String>(segmentId),
      'sessionId': serializer.toJson<String>(sessionId),
      'segmentText': serializer.toJson<String>(segmentText),
      'sourceId': serializer.toJson<String>(sourceId),
      'startTimeMs': serializer.toJson<int>(startTimeMs),
      'endTimeMs': serializer.toJson<int>(endTimeMs),
    };
  }

  TranscriptSegmentRow copyWith({
    String? segmentId,
    String? sessionId,
    String? segmentText,
    String? sourceId,
    int? startTimeMs,
    int? endTimeMs,
  }) => TranscriptSegmentRow(
    segmentId: segmentId ?? this.segmentId,
    sessionId: sessionId ?? this.sessionId,
    segmentText: segmentText ?? this.segmentText,
    sourceId: sourceId ?? this.sourceId,
    startTimeMs: startTimeMs ?? this.startTimeMs,
    endTimeMs: endTimeMs ?? this.endTimeMs,
  );
  TranscriptSegmentRow copyWithCompanion(TranscriptSegmentsCompanion data) {
    return TranscriptSegmentRow(
      segmentId: data.segmentId.present ? data.segmentId.value : this.segmentId,
      sessionId: data.sessionId.present ? data.sessionId.value : this.sessionId,
      segmentText: data.segmentText.present
          ? data.segmentText.value
          : this.segmentText,
      sourceId: data.sourceId.present ? data.sourceId.value : this.sourceId,
      startTimeMs: data.startTimeMs.present
          ? data.startTimeMs.value
          : this.startTimeMs,
      endTimeMs: data.endTimeMs.present ? data.endTimeMs.value : this.endTimeMs,
    );
  }

  @override
  String toString() {
    return (StringBuffer('TranscriptSegmentRow(')
          ..write('segmentId: $segmentId, ')
          ..write('sessionId: $sessionId, ')
          ..write('segmentText: $segmentText, ')
          ..write('sourceId: $sourceId, ')
          ..write('startTimeMs: $startTimeMs, ')
          ..write('endTimeMs: $endTimeMs')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    segmentId,
    sessionId,
    segmentText,
    sourceId,
    startTimeMs,
    endTimeMs,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is TranscriptSegmentRow &&
          other.segmentId == this.segmentId &&
          other.sessionId == this.sessionId &&
          other.segmentText == this.segmentText &&
          other.sourceId == this.sourceId &&
          other.startTimeMs == this.startTimeMs &&
          other.endTimeMs == this.endTimeMs);
}

class TranscriptSegmentsCompanion
    extends UpdateCompanion<TranscriptSegmentRow> {
  final Value<String> segmentId;
  final Value<String> sessionId;
  final Value<String> segmentText;
  final Value<String> sourceId;
  final Value<int> startTimeMs;
  final Value<int> endTimeMs;
  final Value<int> rowid;
  const TranscriptSegmentsCompanion({
    this.segmentId = const Value.absent(),
    this.sessionId = const Value.absent(),
    this.segmentText = const Value.absent(),
    this.sourceId = const Value.absent(),
    this.startTimeMs = const Value.absent(),
    this.endTimeMs = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  TranscriptSegmentsCompanion.insert({
    required String segmentId,
    required String sessionId,
    required String segmentText,
    required String sourceId,
    required int startTimeMs,
    required int endTimeMs,
    this.rowid = const Value.absent(),
  }) : segmentId = Value(segmentId),
       sessionId = Value(sessionId),
       segmentText = Value(segmentText),
       sourceId = Value(sourceId),
       startTimeMs = Value(startTimeMs),
       endTimeMs = Value(endTimeMs);
  static Insertable<TranscriptSegmentRow> custom({
    Expression<String>? segmentId,
    Expression<String>? sessionId,
    Expression<String>? segmentText,
    Expression<String>? sourceId,
    Expression<int>? startTimeMs,
    Expression<int>? endTimeMs,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (segmentId != null) 'segment_id': segmentId,
      if (sessionId != null) 'session_id': sessionId,
      if (segmentText != null) 'text': segmentText,
      if (sourceId != null) 'source_id': sourceId,
      if (startTimeMs != null) 'start_time_ms': startTimeMs,
      if (endTimeMs != null) 'end_time_ms': endTimeMs,
      if (rowid != null) 'rowid': rowid,
    });
  }

  TranscriptSegmentsCompanion copyWith({
    Value<String>? segmentId,
    Value<String>? sessionId,
    Value<String>? segmentText,
    Value<String>? sourceId,
    Value<int>? startTimeMs,
    Value<int>? endTimeMs,
    Value<int>? rowid,
  }) {
    return TranscriptSegmentsCompanion(
      segmentId: segmentId ?? this.segmentId,
      sessionId: sessionId ?? this.sessionId,
      segmentText: segmentText ?? this.segmentText,
      sourceId: sourceId ?? this.sourceId,
      startTimeMs: startTimeMs ?? this.startTimeMs,
      endTimeMs: endTimeMs ?? this.endTimeMs,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (segmentId.present) {
      map['segment_id'] = Variable<String>(segmentId.value);
    }
    if (sessionId.present) {
      map['session_id'] = Variable<String>(sessionId.value);
    }
    if (segmentText.present) {
      map['text'] = Variable<String>(segmentText.value);
    }
    if (sourceId.present) {
      map['source_id'] = Variable<String>(sourceId.value);
    }
    if (startTimeMs.present) {
      map['start_time_ms'] = Variable<int>(startTimeMs.value);
    }
    if (endTimeMs.present) {
      map['end_time_ms'] = Variable<int>(endTimeMs.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('TranscriptSegmentsCompanion(')
          ..write('segmentId: $segmentId, ')
          ..write('sessionId: $sessionId, ')
          ..write('segmentText: $segmentText, ')
          ..write('sourceId: $sourceId, ')
          ..write('startTimeMs: $startTimeMs, ')
          ..write('endTimeMs: $endTimeMs, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$TranscriptDatabase extends GeneratedDatabase {
  _$TranscriptDatabase(QueryExecutor e) : super(e);
  $TranscriptDatabaseManager get managers => $TranscriptDatabaseManager(this);
  late final $TranscriptSessionsTable transcriptSessions =
      $TranscriptSessionsTable(this);
  late final $TranscriptSegmentsTable transcriptSegments =
      $TranscriptSegmentsTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    transcriptSessions,
    transcriptSegments,
  ];
  @override
  StreamQueryUpdateRules get streamUpdateRules => const StreamQueryUpdateRules([
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'transcript_sessions',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('transcript_segments', kind: UpdateKind.delete)],
    ),
  ]);
}

typedef $$TranscriptSessionsTableCreateCompanionBuilder =
    TranscriptSessionsCompanion Function({
      required String sessionId,
      required DateTime date,
      Value<String?> title,
      Value<int> durationMs,
      Value<int> segmentCount,
      Value<int> rowid,
    });
typedef $$TranscriptSessionsTableUpdateCompanionBuilder =
    TranscriptSessionsCompanion Function({
      Value<String> sessionId,
      Value<DateTime> date,
      Value<String?> title,
      Value<int> durationMs,
      Value<int> segmentCount,
      Value<int> rowid,
    });

final class $$TranscriptSessionsTableReferences
    extends
        BaseReferences<
          _$TranscriptDatabase,
          $TranscriptSessionsTable,
          TranscriptSessionRow
        > {
  $$TranscriptSessionsTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static MultiTypedResultKey<
    $TranscriptSegmentsTable,
    List<TranscriptSegmentRow>
  >
  _transcriptSegmentsRefsTable(_$TranscriptDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.transcriptSegments,
        aliasName: $_aliasNameGenerator(
          db.transcriptSessions.sessionId,
          db.transcriptSegments.sessionId,
        ),
      );

  $$TranscriptSegmentsTableProcessedTableManager get transcriptSegmentsRefs {
    final manager =
        $$TranscriptSegmentsTableTableManager(
          $_db,
          $_db.transcriptSegments,
        ).filter(
          (f) => f.sessionId.sessionId.sqlEquals(
            $_itemColumn<String>('session_id')!,
          ),
        );

    final cache = $_typedResult.readTableOrNull(
      _transcriptSegmentsRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$TranscriptSessionsTableFilterComposer
    extends Composer<_$TranscriptDatabase, $TranscriptSessionsTable> {
  $$TranscriptSessionsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get sessionId => $composableBuilder(
    column: $table.sessionId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get date => $composableBuilder(
    column: $table.date,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get durationMs => $composableBuilder(
    column: $table.durationMs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get segmentCount => $composableBuilder(
    column: $table.segmentCount,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> transcriptSegmentsRefs(
    Expression<bool> Function($$TranscriptSegmentsTableFilterComposer f) f,
  ) {
    final $$TranscriptSegmentsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.sessionId,
      referencedTable: $db.transcriptSegments,
      getReferencedColumn: (t) => t.sessionId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TranscriptSegmentsTableFilterComposer(
            $db: $db,
            $table: $db.transcriptSegments,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$TranscriptSessionsTableOrderingComposer
    extends Composer<_$TranscriptDatabase, $TranscriptSessionsTable> {
  $$TranscriptSessionsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get sessionId => $composableBuilder(
    column: $table.sessionId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get date => $composableBuilder(
    column: $table.date,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get durationMs => $composableBuilder(
    column: $table.durationMs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get segmentCount => $composableBuilder(
    column: $table.segmentCount,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$TranscriptSessionsTableAnnotationComposer
    extends Composer<_$TranscriptDatabase, $TranscriptSessionsTable> {
  $$TranscriptSessionsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get sessionId =>
      $composableBuilder(column: $table.sessionId, builder: (column) => column);

  GeneratedColumn<DateTime> get date =>
      $composableBuilder(column: $table.date, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<int> get durationMs => $composableBuilder(
    column: $table.durationMs,
    builder: (column) => column,
  );

  GeneratedColumn<int> get segmentCount => $composableBuilder(
    column: $table.segmentCount,
    builder: (column) => column,
  );

  Expression<T> transcriptSegmentsRefs<T extends Object>(
    Expression<T> Function($$TranscriptSegmentsTableAnnotationComposer a) f,
  ) {
    final $$TranscriptSegmentsTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.sessionId,
          referencedTable: $db.transcriptSegments,
          getReferencedColumn: (t) => t.sessionId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$TranscriptSegmentsTableAnnotationComposer(
                $db: $db,
                $table: $db.transcriptSegments,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }
}

class $$TranscriptSessionsTableTableManager
    extends
        RootTableManager<
          _$TranscriptDatabase,
          $TranscriptSessionsTable,
          TranscriptSessionRow,
          $$TranscriptSessionsTableFilterComposer,
          $$TranscriptSessionsTableOrderingComposer,
          $$TranscriptSessionsTableAnnotationComposer,
          $$TranscriptSessionsTableCreateCompanionBuilder,
          $$TranscriptSessionsTableUpdateCompanionBuilder,
          (TranscriptSessionRow, $$TranscriptSessionsTableReferences),
          TranscriptSessionRow,
          PrefetchHooks Function({bool transcriptSegmentsRefs})
        > {
  $$TranscriptSessionsTableTableManager(
    _$TranscriptDatabase db,
    $TranscriptSessionsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$TranscriptSessionsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$TranscriptSessionsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$TranscriptSessionsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> sessionId = const Value.absent(),
                Value<DateTime> date = const Value.absent(),
                Value<String?> title = const Value.absent(),
                Value<int> durationMs = const Value.absent(),
                Value<int> segmentCount = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => TranscriptSessionsCompanion(
                sessionId: sessionId,
                date: date,
                title: title,
                durationMs: durationMs,
                segmentCount: segmentCount,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String sessionId,
                required DateTime date,
                Value<String?> title = const Value.absent(),
                Value<int> durationMs = const Value.absent(),
                Value<int> segmentCount = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => TranscriptSessionsCompanion.insert(
                sessionId: sessionId,
                date: date,
                title: title,
                durationMs: durationMs,
                segmentCount: segmentCount,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$TranscriptSessionsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({transcriptSegmentsRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [
                if (transcriptSegmentsRefs) db.transcriptSegments,
              ],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (transcriptSegmentsRefs)
                    await $_getPrefetchedData<
                      TranscriptSessionRow,
                      $TranscriptSessionsTable,
                      TranscriptSegmentRow
                    >(
                      currentTable: table,
                      referencedTable: $$TranscriptSessionsTableReferences
                          ._transcriptSegmentsRefsTable(db),
                      managerFromTypedResult: (p0) =>
                          $$TranscriptSessionsTableReferences(
                            db,
                            table,
                            p0,
                          ).transcriptSegmentsRefs,
                      referencedItemsForCurrentItem: (item, referencedItems) =>
                          referencedItems.where(
                            (e) => e.sessionId == item.sessionId,
                          ),
                      typedResults: items,
                    ),
                ];
              },
            );
          },
        ),
      );
}

typedef $$TranscriptSessionsTableProcessedTableManager =
    ProcessedTableManager<
      _$TranscriptDatabase,
      $TranscriptSessionsTable,
      TranscriptSessionRow,
      $$TranscriptSessionsTableFilterComposer,
      $$TranscriptSessionsTableOrderingComposer,
      $$TranscriptSessionsTableAnnotationComposer,
      $$TranscriptSessionsTableCreateCompanionBuilder,
      $$TranscriptSessionsTableUpdateCompanionBuilder,
      (TranscriptSessionRow, $$TranscriptSessionsTableReferences),
      TranscriptSessionRow,
      PrefetchHooks Function({bool transcriptSegmentsRefs})
    >;
typedef $$TranscriptSegmentsTableCreateCompanionBuilder =
    TranscriptSegmentsCompanion Function({
      required String segmentId,
      required String sessionId,
      required String segmentText,
      required String sourceId,
      required int startTimeMs,
      required int endTimeMs,
      Value<int> rowid,
    });
typedef $$TranscriptSegmentsTableUpdateCompanionBuilder =
    TranscriptSegmentsCompanion Function({
      Value<String> segmentId,
      Value<String> sessionId,
      Value<String> segmentText,
      Value<String> sourceId,
      Value<int> startTimeMs,
      Value<int> endTimeMs,
      Value<int> rowid,
    });

final class $$TranscriptSegmentsTableReferences
    extends
        BaseReferences<
          _$TranscriptDatabase,
          $TranscriptSegmentsTable,
          TranscriptSegmentRow
        > {
  $$TranscriptSegmentsTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $TranscriptSessionsTable _sessionIdTable(_$TranscriptDatabase db) =>
      db.transcriptSessions.createAlias(
        $_aliasNameGenerator(
          db.transcriptSegments.sessionId,
          db.transcriptSessions.sessionId,
        ),
      );

  $$TranscriptSessionsTableProcessedTableManager get sessionId {
    final $_column = $_itemColumn<String>('session_id')!;

    final manager = $$TranscriptSessionsTableTableManager(
      $_db,
      $_db.transcriptSessions,
    ).filter((f) => f.sessionId.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_sessionIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$TranscriptSegmentsTableFilterComposer
    extends Composer<_$TranscriptDatabase, $TranscriptSegmentsTable> {
  $$TranscriptSegmentsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get segmentId => $composableBuilder(
    column: $table.segmentId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get segmentText => $composableBuilder(
    column: $table.segmentText,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sourceId => $composableBuilder(
    column: $table.sourceId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get startTimeMs => $composableBuilder(
    column: $table.startTimeMs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get endTimeMs => $composableBuilder(
    column: $table.endTimeMs,
    builder: (column) => ColumnFilters(column),
  );

  $$TranscriptSessionsTableFilterComposer get sessionId {
    final $$TranscriptSessionsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.sessionId,
      referencedTable: $db.transcriptSessions,
      getReferencedColumn: (t) => t.sessionId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TranscriptSessionsTableFilterComposer(
            $db: $db,
            $table: $db.transcriptSessions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$TranscriptSegmentsTableOrderingComposer
    extends Composer<_$TranscriptDatabase, $TranscriptSegmentsTable> {
  $$TranscriptSegmentsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get segmentId => $composableBuilder(
    column: $table.segmentId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get segmentText => $composableBuilder(
    column: $table.segmentText,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sourceId => $composableBuilder(
    column: $table.sourceId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get startTimeMs => $composableBuilder(
    column: $table.startTimeMs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get endTimeMs => $composableBuilder(
    column: $table.endTimeMs,
    builder: (column) => ColumnOrderings(column),
  );

  $$TranscriptSessionsTableOrderingComposer get sessionId {
    final $$TranscriptSessionsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.sessionId,
      referencedTable: $db.transcriptSessions,
      getReferencedColumn: (t) => t.sessionId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TranscriptSessionsTableOrderingComposer(
            $db: $db,
            $table: $db.transcriptSessions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$TranscriptSegmentsTableAnnotationComposer
    extends Composer<_$TranscriptDatabase, $TranscriptSegmentsTable> {
  $$TranscriptSegmentsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get segmentId =>
      $composableBuilder(column: $table.segmentId, builder: (column) => column);

  GeneratedColumn<String> get segmentText => $composableBuilder(
    column: $table.segmentText,
    builder: (column) => column,
  );

  GeneratedColumn<String> get sourceId =>
      $composableBuilder(column: $table.sourceId, builder: (column) => column);

  GeneratedColumn<int> get startTimeMs => $composableBuilder(
    column: $table.startTimeMs,
    builder: (column) => column,
  );

  GeneratedColumn<int> get endTimeMs =>
      $composableBuilder(column: $table.endTimeMs, builder: (column) => column);

  $$TranscriptSessionsTableAnnotationComposer get sessionId {
    final $$TranscriptSessionsTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.sessionId,
          referencedTable: $db.transcriptSessions,
          getReferencedColumn: (t) => t.sessionId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$TranscriptSessionsTableAnnotationComposer(
                $db: $db,
                $table: $db.transcriptSessions,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return composer;
  }
}

class $$TranscriptSegmentsTableTableManager
    extends
        RootTableManager<
          _$TranscriptDatabase,
          $TranscriptSegmentsTable,
          TranscriptSegmentRow,
          $$TranscriptSegmentsTableFilterComposer,
          $$TranscriptSegmentsTableOrderingComposer,
          $$TranscriptSegmentsTableAnnotationComposer,
          $$TranscriptSegmentsTableCreateCompanionBuilder,
          $$TranscriptSegmentsTableUpdateCompanionBuilder,
          (TranscriptSegmentRow, $$TranscriptSegmentsTableReferences),
          TranscriptSegmentRow,
          PrefetchHooks Function({bool sessionId})
        > {
  $$TranscriptSegmentsTableTableManager(
    _$TranscriptDatabase db,
    $TranscriptSegmentsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$TranscriptSegmentsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$TranscriptSegmentsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$TranscriptSegmentsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> segmentId = const Value.absent(),
                Value<String> sessionId = const Value.absent(),
                Value<String> segmentText = const Value.absent(),
                Value<String> sourceId = const Value.absent(),
                Value<int> startTimeMs = const Value.absent(),
                Value<int> endTimeMs = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => TranscriptSegmentsCompanion(
                segmentId: segmentId,
                sessionId: sessionId,
                segmentText: segmentText,
                sourceId: sourceId,
                startTimeMs: startTimeMs,
                endTimeMs: endTimeMs,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String segmentId,
                required String sessionId,
                required String segmentText,
                required String sourceId,
                required int startTimeMs,
                required int endTimeMs,
                Value<int> rowid = const Value.absent(),
              }) => TranscriptSegmentsCompanion.insert(
                segmentId: segmentId,
                sessionId: sessionId,
                segmentText: segmentText,
                sourceId: sourceId,
                startTimeMs: startTimeMs,
                endTimeMs: endTimeMs,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$TranscriptSegmentsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({sessionId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (sessionId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.sessionId,
                                referencedTable:
                                    $$TranscriptSegmentsTableReferences
                                        ._sessionIdTable(db),
                                referencedColumn:
                                    $$TranscriptSegmentsTableReferences
                                        ._sessionIdTable(db)
                                        .sessionId,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$TranscriptSegmentsTableProcessedTableManager =
    ProcessedTableManager<
      _$TranscriptDatabase,
      $TranscriptSegmentsTable,
      TranscriptSegmentRow,
      $$TranscriptSegmentsTableFilterComposer,
      $$TranscriptSegmentsTableOrderingComposer,
      $$TranscriptSegmentsTableAnnotationComposer,
      $$TranscriptSegmentsTableCreateCompanionBuilder,
      $$TranscriptSegmentsTableUpdateCompanionBuilder,
      (TranscriptSegmentRow, $$TranscriptSegmentsTableReferences),
      TranscriptSegmentRow,
      PrefetchHooks Function({bool sessionId})
    >;

class $TranscriptDatabaseManager {
  final _$TranscriptDatabase _db;
  $TranscriptDatabaseManager(this._db);
  $$TranscriptSessionsTableTableManager get transcriptSessions =>
      $$TranscriptSessionsTableTableManager(_db, _db.transcriptSessions);
  $$TranscriptSegmentsTableTableManager get transcriptSegments =>
      $$TranscriptSegmentsTableTableManager(_db, _db.transcriptSegments);
}
