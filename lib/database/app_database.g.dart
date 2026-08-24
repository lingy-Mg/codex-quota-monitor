// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
class $QuotaSnapshotsTable extends QuotaSnapshots
    with TableInfo<$QuotaSnapshotsTable, QuotaSnapshot> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $QuotaSnapshotsTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _bucketIdMeta = const VerificationMeta(
    'bucketId',
  );
  @override
  late final GeneratedColumn<String> bucketId = GeneratedColumn<String>(
    'bucket_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _bucketNameMeta = const VerificationMeta(
    'bucketName',
  );
  @override
  late final GeneratedColumn<String> bucketName = GeneratedColumn<String>(
    'bucket_name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _windowTypeMeta = const VerificationMeta(
    'windowType',
  );
  @override
  late final GeneratedColumn<String> windowType = GeneratedColumn<String>(
    'window_type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _windowDurationSecondsMeta =
      const VerificationMeta('windowDurationSeconds');
  @override
  late final GeneratedColumn<int> windowDurationSeconds = GeneratedColumn<int>(
    'window_duration_seconds',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _usedPercentMeta = const VerificationMeta(
    'usedPercent',
  );
  @override
  late final GeneratedColumn<double> usedPercent = GeneratedColumn<double>(
    'used_percent',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _remainingPercentMeta = const VerificationMeta(
    'remainingPercent',
  );
  @override
  late final GeneratedColumn<double> remainingPercent = GeneratedColumn<double>(
    'remaining_percent',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _resetAtMeta = const VerificationMeta(
    'resetAt',
  );
  @override
  late final GeneratedColumn<DateTime> resetAt = GeneratedColumn<DateTime>(
    'reset_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _planTypeMeta = const VerificationMeta(
    'planType',
  );
  @override
  late final GeneratedColumn<String> planType = GeneratedColumn<String>(
    'plan_type',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    timestamp,
    bucketId,
    bucketName,
    windowType,
    windowDurationSeconds,
    usedPercent,
    remainingPercent,
    resetAt,
    planType,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'quota_snapshots';
  @override
  VerificationContext validateIntegrity(
    Insertable<QuotaSnapshot> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('timestamp')) {
      context.handle(
        _timestampMeta,
        timestamp.isAcceptableOrUnknown(data['timestamp']!, _timestampMeta),
      );
    } else if (isInserting) {
      context.missing(_timestampMeta);
    }
    if (data.containsKey('bucket_id')) {
      context.handle(
        _bucketIdMeta,
        bucketId.isAcceptableOrUnknown(data['bucket_id']!, _bucketIdMeta),
      );
    } else if (isInserting) {
      context.missing(_bucketIdMeta);
    }
    if (data.containsKey('bucket_name')) {
      context.handle(
        _bucketNameMeta,
        bucketName.isAcceptableOrUnknown(data['bucket_name']!, _bucketNameMeta),
      );
    } else if (isInserting) {
      context.missing(_bucketNameMeta);
    }
    if (data.containsKey('window_type')) {
      context.handle(
        _windowTypeMeta,
        windowType.isAcceptableOrUnknown(data['window_type']!, _windowTypeMeta),
      );
    } else if (isInserting) {
      context.missing(_windowTypeMeta);
    }
    if (data.containsKey('window_duration_seconds')) {
      context.handle(
        _windowDurationSecondsMeta,
        windowDurationSeconds.isAcceptableOrUnknown(
          data['window_duration_seconds']!,
          _windowDurationSecondsMeta,
        ),
      );
    }
    if (data.containsKey('used_percent')) {
      context.handle(
        _usedPercentMeta,
        usedPercent.isAcceptableOrUnknown(
          data['used_percent']!,
          _usedPercentMeta,
        ),
      );
    }
    if (data.containsKey('remaining_percent')) {
      context.handle(
        _remainingPercentMeta,
        remainingPercent.isAcceptableOrUnknown(
          data['remaining_percent']!,
          _remainingPercentMeta,
        ),
      );
    }
    if (data.containsKey('reset_at')) {
      context.handle(
        _resetAtMeta,
        resetAt.isAcceptableOrUnknown(data['reset_at']!, _resetAtMeta),
      );
    }
    if (data.containsKey('plan_type')) {
      context.handle(
        _planTypeMeta,
        planType.isAcceptableOrUnknown(data['plan_type']!, _planTypeMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  QuotaSnapshot map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return QuotaSnapshot(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      timestamp: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}timestamp'],
      )!,
      bucketId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}bucket_id'],
      )!,
      bucketName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}bucket_name'],
      )!,
      windowType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}window_type'],
      )!,
      windowDurationSeconds: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}window_duration_seconds'],
      ),
      usedPercent: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}used_percent'],
      ),
      remainingPercent: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}remaining_percent'],
      ),
      resetAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}reset_at'],
      ),
      planType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}plan_type'],
      ),
    );
  }

  @override
  $QuotaSnapshotsTable createAlias(String alias) {
    return $QuotaSnapshotsTable(attachedDatabase, alias);
  }
}

class QuotaSnapshot extends DataClass implements Insertable<QuotaSnapshot> {
  final int id;
  final DateTime timestamp;
  final String bucketId;
  final String bucketName;
  final String windowType;
  final int? windowDurationSeconds;
  final double? usedPercent;
  final double? remainingPercent;
  final DateTime? resetAt;
  final String? planType;
  const QuotaSnapshot({
    required this.id,
    required this.timestamp,
    required this.bucketId,
    required this.bucketName,
    required this.windowType,
    this.windowDurationSeconds,
    this.usedPercent,
    this.remainingPercent,
    this.resetAt,
    this.planType,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['timestamp'] = Variable<DateTime>(timestamp);
    map['bucket_id'] = Variable<String>(bucketId);
    map['bucket_name'] = Variable<String>(bucketName);
    map['window_type'] = Variable<String>(windowType);
    if (!nullToAbsent || windowDurationSeconds != null) {
      map['window_duration_seconds'] = Variable<int>(windowDurationSeconds);
    }
    if (!nullToAbsent || usedPercent != null) {
      map['used_percent'] = Variable<double>(usedPercent);
    }
    if (!nullToAbsent || remainingPercent != null) {
      map['remaining_percent'] = Variable<double>(remainingPercent);
    }
    if (!nullToAbsent || resetAt != null) {
      map['reset_at'] = Variable<DateTime>(resetAt);
    }
    if (!nullToAbsent || planType != null) {
      map['plan_type'] = Variable<String>(planType);
    }
    return map;
  }

  QuotaSnapshotsCompanion toCompanion(bool nullToAbsent) {
    return QuotaSnapshotsCompanion(
      id: Value(id),
      timestamp: Value(timestamp),
      bucketId: Value(bucketId),
      bucketName: Value(bucketName),
      windowType: Value(windowType),
      windowDurationSeconds: windowDurationSeconds == null && nullToAbsent
          ? const Value.absent()
          : Value(windowDurationSeconds),
      usedPercent: usedPercent == null && nullToAbsent
          ? const Value.absent()
          : Value(usedPercent),
      remainingPercent: remainingPercent == null && nullToAbsent
          ? const Value.absent()
          : Value(remainingPercent),
      resetAt: resetAt == null && nullToAbsent
          ? const Value.absent()
          : Value(resetAt),
      planType: planType == null && nullToAbsent
          ? const Value.absent()
          : Value(planType),
    );
  }

  factory QuotaSnapshot.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return QuotaSnapshot(
      id: serializer.fromJson<int>(json['id']),
      timestamp: serializer.fromJson<DateTime>(json['timestamp']),
      bucketId: serializer.fromJson<String>(json['bucketId']),
      bucketName: serializer.fromJson<String>(json['bucketName']),
      windowType: serializer.fromJson<String>(json['windowType']),
      windowDurationSeconds: serializer.fromJson<int?>(
        json['windowDurationSeconds'],
      ),
      usedPercent: serializer.fromJson<double?>(json['usedPercent']),
      remainingPercent: serializer.fromJson<double?>(json['remainingPercent']),
      resetAt: serializer.fromJson<DateTime?>(json['resetAt']),
      planType: serializer.fromJson<String?>(json['planType']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'timestamp': serializer.toJson<DateTime>(timestamp),
      'bucketId': serializer.toJson<String>(bucketId),
      'bucketName': serializer.toJson<String>(bucketName),
      'windowType': serializer.toJson<String>(windowType),
      'windowDurationSeconds': serializer.toJson<int?>(windowDurationSeconds),
      'usedPercent': serializer.toJson<double?>(usedPercent),
      'remainingPercent': serializer.toJson<double?>(remainingPercent),
      'resetAt': serializer.toJson<DateTime?>(resetAt),
      'planType': serializer.toJson<String?>(planType),
    };
  }

  QuotaSnapshot copyWith({
    int? id,
    DateTime? timestamp,
    String? bucketId,
    String? bucketName,
    String? windowType,
    Value<int?> windowDurationSeconds = const Value.absent(),
    Value<double?> usedPercent = const Value.absent(),
    Value<double?> remainingPercent = const Value.absent(),
    Value<DateTime?> resetAt = const Value.absent(),
    Value<String?> planType = const Value.absent(),
  }) => QuotaSnapshot(
    id: id ?? this.id,
    timestamp: timestamp ?? this.timestamp,
    bucketId: bucketId ?? this.bucketId,
    bucketName: bucketName ?? this.bucketName,
    windowType: windowType ?? this.windowType,
    windowDurationSeconds: windowDurationSeconds.present
        ? windowDurationSeconds.value
        : this.windowDurationSeconds,
    usedPercent: usedPercent.present ? usedPercent.value : this.usedPercent,
    remainingPercent: remainingPercent.present
        ? remainingPercent.value
        : this.remainingPercent,
    resetAt: resetAt.present ? resetAt.value : this.resetAt,
    planType: planType.present ? planType.value : this.planType,
  );
  QuotaSnapshot copyWithCompanion(QuotaSnapshotsCompanion data) {
    return QuotaSnapshot(
      id: data.id.present ? data.id.value : this.id,
      timestamp: data.timestamp.present ? data.timestamp.value : this.timestamp,
      bucketId: data.bucketId.present ? data.bucketId.value : this.bucketId,
      bucketName: data.bucketName.present
          ? data.bucketName.value
          : this.bucketName,
      windowType: data.windowType.present
          ? data.windowType.value
          : this.windowType,
      windowDurationSeconds: data.windowDurationSeconds.present
          ? data.windowDurationSeconds.value
          : this.windowDurationSeconds,
      usedPercent: data.usedPercent.present
          ? data.usedPercent.value
          : this.usedPercent,
      remainingPercent: data.remainingPercent.present
          ? data.remainingPercent.value
          : this.remainingPercent,
      resetAt: data.resetAt.present ? data.resetAt.value : this.resetAt,
      planType: data.planType.present ? data.planType.value : this.planType,
    );
  }

  @override
  String toString() {
    return (StringBuffer('QuotaSnapshot(')
          ..write('id: $id, ')
          ..write('timestamp: $timestamp, ')
          ..write('bucketId: $bucketId, ')
          ..write('bucketName: $bucketName, ')
          ..write('windowType: $windowType, ')
          ..write('windowDurationSeconds: $windowDurationSeconds, ')
          ..write('usedPercent: $usedPercent, ')
          ..write('remainingPercent: $remainingPercent, ')
          ..write('resetAt: $resetAt, ')
          ..write('planType: $planType')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    timestamp,
    bucketId,
    bucketName,
    windowType,
    windowDurationSeconds,
    usedPercent,
    remainingPercent,
    resetAt,
    planType,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is QuotaSnapshot &&
          other.id == this.id &&
          other.timestamp == this.timestamp &&
          other.bucketId == this.bucketId &&
          other.bucketName == this.bucketName &&
          other.windowType == this.windowType &&
          other.windowDurationSeconds == this.windowDurationSeconds &&
          other.usedPercent == this.usedPercent &&
          other.remainingPercent == this.remainingPercent &&
          other.resetAt == this.resetAt &&
          other.planType == this.planType);
}

class QuotaSnapshotsCompanion extends UpdateCompanion<QuotaSnapshot> {
  final Value<int> id;
  final Value<DateTime> timestamp;
  final Value<String> bucketId;
  final Value<String> bucketName;
  final Value<String> windowType;
  final Value<int?> windowDurationSeconds;
  final Value<double?> usedPercent;
  final Value<double?> remainingPercent;
  final Value<DateTime?> resetAt;
  final Value<String?> planType;
  const QuotaSnapshotsCompanion({
    this.id = const Value.absent(),
    this.timestamp = const Value.absent(),
    this.bucketId = const Value.absent(),
    this.bucketName = const Value.absent(),
    this.windowType = const Value.absent(),
    this.windowDurationSeconds = const Value.absent(),
    this.usedPercent = const Value.absent(),
    this.remainingPercent = const Value.absent(),
    this.resetAt = const Value.absent(),
    this.planType = const Value.absent(),
  });
  QuotaSnapshotsCompanion.insert({
    this.id = const Value.absent(),
    required DateTime timestamp,
    required String bucketId,
    required String bucketName,
    required String windowType,
    this.windowDurationSeconds = const Value.absent(),
    this.usedPercent = const Value.absent(),
    this.remainingPercent = const Value.absent(),
    this.resetAt = const Value.absent(),
    this.planType = const Value.absent(),
  }) : timestamp = Value(timestamp),
       bucketId = Value(bucketId),
       bucketName = Value(bucketName),
       windowType = Value(windowType);
  static Insertable<QuotaSnapshot> custom({
    Expression<int>? id,
    Expression<DateTime>? timestamp,
    Expression<String>? bucketId,
    Expression<String>? bucketName,
    Expression<String>? windowType,
    Expression<int>? windowDurationSeconds,
    Expression<double>? usedPercent,
    Expression<double>? remainingPercent,
    Expression<DateTime>? resetAt,
    Expression<String>? planType,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (timestamp != null) 'timestamp': timestamp,
      if (bucketId != null) 'bucket_id': bucketId,
      if (bucketName != null) 'bucket_name': bucketName,
      if (windowType != null) 'window_type': windowType,
      if (windowDurationSeconds != null)
        'window_duration_seconds': windowDurationSeconds,
      if (usedPercent != null) 'used_percent': usedPercent,
      if (remainingPercent != null) 'remaining_percent': remainingPercent,
      if (resetAt != null) 'reset_at': resetAt,
      if (planType != null) 'plan_type': planType,
    });
  }

  QuotaSnapshotsCompanion copyWith({
    Value<int>? id,
    Value<DateTime>? timestamp,
    Value<String>? bucketId,
    Value<String>? bucketName,
    Value<String>? windowType,
    Value<int?>? windowDurationSeconds,
    Value<double?>? usedPercent,
    Value<double?>? remainingPercent,
    Value<DateTime?>? resetAt,
    Value<String?>? planType,
  }) {
    return QuotaSnapshotsCompanion(
      id: id ?? this.id,
      timestamp: timestamp ?? this.timestamp,
      bucketId: bucketId ?? this.bucketId,
      bucketName: bucketName ?? this.bucketName,
      windowType: windowType ?? this.windowType,
      windowDurationSeconds:
          windowDurationSeconds ?? this.windowDurationSeconds,
      usedPercent: usedPercent ?? this.usedPercent,
      remainingPercent: remainingPercent ?? this.remainingPercent,
      resetAt: resetAt ?? this.resetAt,
      planType: planType ?? this.planType,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (timestamp.present) {
      map['timestamp'] = Variable<DateTime>(timestamp.value);
    }
    if (bucketId.present) {
      map['bucket_id'] = Variable<String>(bucketId.value);
    }
    if (bucketName.present) {
      map['bucket_name'] = Variable<String>(bucketName.value);
    }
    if (windowType.present) {
      map['window_type'] = Variable<String>(windowType.value);
    }
    if (windowDurationSeconds.present) {
      map['window_duration_seconds'] = Variable<int>(
        windowDurationSeconds.value,
      );
    }
    if (usedPercent.present) {
      map['used_percent'] = Variable<double>(usedPercent.value);
    }
    if (remainingPercent.present) {
      map['remaining_percent'] = Variable<double>(remainingPercent.value);
    }
    if (resetAt.present) {
      map['reset_at'] = Variable<DateTime>(resetAt.value);
    }
    if (planType.present) {
      map['plan_type'] = Variable<String>(planType.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('QuotaSnapshotsCompanion(')
          ..write('id: $id, ')
          ..write('timestamp: $timestamp, ')
          ..write('bucketId: $bucketId, ')
          ..write('bucketName: $bucketName, ')
          ..write('windowType: $windowType, ')
          ..write('windowDurationSeconds: $windowDurationSeconds, ')
          ..write('usedPercent: $usedPercent, ')
          ..write('remainingPercent: $remainingPercent, ')
          ..write('resetAt: $resetAt, ')
          ..write('planType: $planType')
          ..write(')'))
        .toString();
  }
}

class $ActivityEventsTable extends ActivityEvents
    with TableInfo<$ActivityEventsTable, ActivityEvent> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ActivityEventsTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _typeMeta = const VerificationMeta('type');
  @override
  late final GeneratedColumn<String> type = GeneratedColumn<String>(
    'type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _bucketIdMeta = const VerificationMeta(
    'bucketId',
  );
  @override
  late final GeneratedColumn<String> bucketId = GeneratedColumn<String>(
    'bucket_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
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
  static const VerificationMeta _descriptionMeta = const VerificationMeta(
    'description',
  );
  @override
  late final GeneratedColumn<String> description = GeneratedColumn<String>(
    'description',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _oldValueMeta = const VerificationMeta(
    'oldValue',
  );
  @override
  late final GeneratedColumn<double> oldValue = GeneratedColumn<double>(
    'old_value',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _newValueMeta = const VerificationMeta(
    'newValue',
  );
  @override
  late final GeneratedColumn<double> newValue = GeneratedColumn<double>(
    'new_value',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    timestamp,
    type,
    bucketId,
    title,
    description,
    oldValue,
    newValue,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'activity_events';
  @override
  VerificationContext validateIntegrity(
    Insertable<ActivityEvent> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('timestamp')) {
      context.handle(
        _timestampMeta,
        timestamp.isAcceptableOrUnknown(data['timestamp']!, _timestampMeta),
      );
    } else if (isInserting) {
      context.missing(_timestampMeta);
    }
    if (data.containsKey('type')) {
      context.handle(
        _typeMeta,
        type.isAcceptableOrUnknown(data['type']!, _typeMeta),
      );
    } else if (isInserting) {
      context.missing(_typeMeta);
    }
    if (data.containsKey('bucket_id')) {
      context.handle(
        _bucketIdMeta,
        bucketId.isAcceptableOrUnknown(data['bucket_id']!, _bucketIdMeta),
      );
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('description')) {
      context.handle(
        _descriptionMeta,
        description.isAcceptableOrUnknown(
          data['description']!,
          _descriptionMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_descriptionMeta);
    }
    if (data.containsKey('old_value')) {
      context.handle(
        _oldValueMeta,
        oldValue.isAcceptableOrUnknown(data['old_value']!, _oldValueMeta),
      );
    }
    if (data.containsKey('new_value')) {
      context.handle(
        _newValueMeta,
        newValue.isAcceptableOrUnknown(data['new_value']!, _newValueMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ActivityEvent map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ActivityEvent(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      timestamp: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}timestamp'],
      )!,
      type: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}type'],
      )!,
      bucketId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}bucket_id'],
      ),
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      )!,
      description: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}description'],
      )!,
      oldValue: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}old_value'],
      ),
      newValue: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}new_value'],
      ),
    );
  }

  @override
  $ActivityEventsTable createAlias(String alias) {
    return $ActivityEventsTable(attachedDatabase, alias);
  }
}

class ActivityEvent extends DataClass implements Insertable<ActivityEvent> {
  final int id;
  final DateTime timestamp;
  final String type;
  final String? bucketId;
  final String title;
  final String description;
  final double? oldValue;
  final double? newValue;
  const ActivityEvent({
    required this.id,
    required this.timestamp,
    required this.type,
    this.bucketId,
    required this.title,
    required this.description,
    this.oldValue,
    this.newValue,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['timestamp'] = Variable<DateTime>(timestamp);
    map['type'] = Variable<String>(type);
    if (!nullToAbsent || bucketId != null) {
      map['bucket_id'] = Variable<String>(bucketId);
    }
    map['title'] = Variable<String>(title);
    map['description'] = Variable<String>(description);
    if (!nullToAbsent || oldValue != null) {
      map['old_value'] = Variable<double>(oldValue);
    }
    if (!nullToAbsent || newValue != null) {
      map['new_value'] = Variable<double>(newValue);
    }
    return map;
  }

  ActivityEventsCompanion toCompanion(bool nullToAbsent) {
    return ActivityEventsCompanion(
      id: Value(id),
      timestamp: Value(timestamp),
      type: Value(type),
      bucketId: bucketId == null && nullToAbsent
          ? const Value.absent()
          : Value(bucketId),
      title: Value(title),
      description: Value(description),
      oldValue: oldValue == null && nullToAbsent
          ? const Value.absent()
          : Value(oldValue),
      newValue: newValue == null && nullToAbsent
          ? const Value.absent()
          : Value(newValue),
    );
  }

  factory ActivityEvent.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ActivityEvent(
      id: serializer.fromJson<int>(json['id']),
      timestamp: serializer.fromJson<DateTime>(json['timestamp']),
      type: serializer.fromJson<String>(json['type']),
      bucketId: serializer.fromJson<String?>(json['bucketId']),
      title: serializer.fromJson<String>(json['title']),
      description: serializer.fromJson<String>(json['description']),
      oldValue: serializer.fromJson<double?>(json['oldValue']),
      newValue: serializer.fromJson<double?>(json['newValue']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'timestamp': serializer.toJson<DateTime>(timestamp),
      'type': serializer.toJson<String>(type),
      'bucketId': serializer.toJson<String?>(bucketId),
      'title': serializer.toJson<String>(title),
      'description': serializer.toJson<String>(description),
      'oldValue': serializer.toJson<double?>(oldValue),
      'newValue': serializer.toJson<double?>(newValue),
    };
  }

  ActivityEvent copyWith({
    int? id,
    DateTime? timestamp,
    String? type,
    Value<String?> bucketId = const Value.absent(),
    String? title,
    String? description,
    Value<double?> oldValue = const Value.absent(),
    Value<double?> newValue = const Value.absent(),
  }) => ActivityEvent(
    id: id ?? this.id,
    timestamp: timestamp ?? this.timestamp,
    type: type ?? this.type,
    bucketId: bucketId.present ? bucketId.value : this.bucketId,
    title: title ?? this.title,
    description: description ?? this.description,
    oldValue: oldValue.present ? oldValue.value : this.oldValue,
    newValue: newValue.present ? newValue.value : this.newValue,
  );
  ActivityEvent copyWithCompanion(ActivityEventsCompanion data) {
    return ActivityEvent(
      id: data.id.present ? data.id.value : this.id,
      timestamp: data.timestamp.present ? data.timestamp.value : this.timestamp,
      type: data.type.present ? data.type.value : this.type,
      bucketId: data.bucketId.present ? data.bucketId.value : this.bucketId,
      title: data.title.present ? data.title.value : this.title,
      description: data.description.present
          ? data.description.value
          : this.description,
      oldValue: data.oldValue.present ? data.oldValue.value : this.oldValue,
      newValue: data.newValue.present ? data.newValue.value : this.newValue,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ActivityEvent(')
          ..write('id: $id, ')
          ..write('timestamp: $timestamp, ')
          ..write('type: $type, ')
          ..write('bucketId: $bucketId, ')
          ..write('title: $title, ')
          ..write('description: $description, ')
          ..write('oldValue: $oldValue, ')
          ..write('newValue: $newValue')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    timestamp,
    type,
    bucketId,
    title,
    description,
    oldValue,
    newValue,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ActivityEvent &&
          other.id == this.id &&
          other.timestamp == this.timestamp &&
          other.type == this.type &&
          other.bucketId == this.bucketId &&
          other.title == this.title &&
          other.description == this.description &&
          other.oldValue == this.oldValue &&
          other.newValue == this.newValue);
}

class ActivityEventsCompanion extends UpdateCompanion<ActivityEvent> {
  final Value<int> id;
  final Value<DateTime> timestamp;
  final Value<String> type;
  final Value<String?> bucketId;
  final Value<String> title;
  final Value<String> description;
  final Value<double?> oldValue;
  final Value<double?> newValue;
  const ActivityEventsCompanion({
    this.id = const Value.absent(),
    this.timestamp = const Value.absent(),
    this.type = const Value.absent(),
    this.bucketId = const Value.absent(),
    this.title = const Value.absent(),
    this.description = const Value.absent(),
    this.oldValue = const Value.absent(),
    this.newValue = const Value.absent(),
  });
  ActivityEventsCompanion.insert({
    this.id = const Value.absent(),
    required DateTime timestamp,
    required String type,
    this.bucketId = const Value.absent(),
    required String title,
    required String description,
    this.oldValue = const Value.absent(),
    this.newValue = const Value.absent(),
  }) : timestamp = Value(timestamp),
       type = Value(type),
       title = Value(title),
       description = Value(description);
  static Insertable<ActivityEvent> custom({
    Expression<int>? id,
    Expression<DateTime>? timestamp,
    Expression<String>? type,
    Expression<String>? bucketId,
    Expression<String>? title,
    Expression<String>? description,
    Expression<double>? oldValue,
    Expression<double>? newValue,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (timestamp != null) 'timestamp': timestamp,
      if (type != null) 'type': type,
      if (bucketId != null) 'bucket_id': bucketId,
      if (title != null) 'title': title,
      if (description != null) 'description': description,
      if (oldValue != null) 'old_value': oldValue,
      if (newValue != null) 'new_value': newValue,
    });
  }

  ActivityEventsCompanion copyWith({
    Value<int>? id,
    Value<DateTime>? timestamp,
    Value<String>? type,
    Value<String?>? bucketId,
    Value<String>? title,
    Value<String>? description,
    Value<double?>? oldValue,
    Value<double?>? newValue,
  }) {
    return ActivityEventsCompanion(
      id: id ?? this.id,
      timestamp: timestamp ?? this.timestamp,
      type: type ?? this.type,
      bucketId: bucketId ?? this.bucketId,
      title: title ?? this.title,
      description: description ?? this.description,
      oldValue: oldValue ?? this.oldValue,
      newValue: newValue ?? this.newValue,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (timestamp.present) {
      map['timestamp'] = Variable<DateTime>(timestamp.value);
    }
    if (type.present) {
      map['type'] = Variable<String>(type.value);
    }
    if (bucketId.present) {
      map['bucket_id'] = Variable<String>(bucketId.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (description.present) {
      map['description'] = Variable<String>(description.value);
    }
    if (oldValue.present) {
      map['old_value'] = Variable<double>(oldValue.value);
    }
    if (newValue.present) {
      map['new_value'] = Variable<double>(newValue.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ActivityEventsCompanion(')
          ..write('id: $id, ')
          ..write('timestamp: $timestamp, ')
          ..write('type: $type, ')
          ..write('bucketId: $bucketId, ')
          ..write('title: $title, ')
          ..write('description: $description, ')
          ..write('oldValue: $oldValue, ')
          ..write('newValue: $newValue')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $QuotaSnapshotsTable quotaSnapshots = $QuotaSnapshotsTable(this);
  late final $ActivityEventsTable activityEvents = $ActivityEventsTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    quotaSnapshots,
    activityEvents,
  ];
}

typedef $$QuotaSnapshotsTableCreateCompanionBuilder =
    QuotaSnapshotsCompanion Function({
      Value<int> id,
      required DateTime timestamp,
      required String bucketId,
      required String bucketName,
      required String windowType,
      Value<int?> windowDurationSeconds,
      Value<double?> usedPercent,
      Value<double?> remainingPercent,
      Value<DateTime?> resetAt,
      Value<String?> planType,
    });
typedef $$QuotaSnapshotsTableUpdateCompanionBuilder =
    QuotaSnapshotsCompanion Function({
      Value<int> id,
      Value<DateTime> timestamp,
      Value<String> bucketId,
      Value<String> bucketName,
      Value<String> windowType,
      Value<int?> windowDurationSeconds,
      Value<double?> usedPercent,
      Value<double?> remainingPercent,
      Value<DateTime?> resetAt,
      Value<String?> planType,
    });

class $$QuotaSnapshotsTableFilterComposer
    extends Composer<_$AppDatabase, $QuotaSnapshotsTable> {
  $$QuotaSnapshotsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get timestamp => $composableBuilder(
    column: $table.timestamp,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get bucketId => $composableBuilder(
    column: $table.bucketId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get bucketName => $composableBuilder(
    column: $table.bucketName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get windowType => $composableBuilder(
    column: $table.windowType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get windowDurationSeconds => $composableBuilder(
    column: $table.windowDurationSeconds,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get usedPercent => $composableBuilder(
    column: $table.usedPercent,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get remainingPercent => $composableBuilder(
    column: $table.remainingPercent,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get resetAt => $composableBuilder(
    column: $table.resetAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get planType => $composableBuilder(
    column: $table.planType,
    builder: (column) => ColumnFilters(column),
  );
}

class $$QuotaSnapshotsTableOrderingComposer
    extends Composer<_$AppDatabase, $QuotaSnapshotsTable> {
  $$QuotaSnapshotsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get timestamp => $composableBuilder(
    column: $table.timestamp,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get bucketId => $composableBuilder(
    column: $table.bucketId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get bucketName => $composableBuilder(
    column: $table.bucketName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get windowType => $composableBuilder(
    column: $table.windowType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get windowDurationSeconds => $composableBuilder(
    column: $table.windowDurationSeconds,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get usedPercent => $composableBuilder(
    column: $table.usedPercent,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get remainingPercent => $composableBuilder(
    column: $table.remainingPercent,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get resetAt => $composableBuilder(
    column: $table.resetAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get planType => $composableBuilder(
    column: $table.planType,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$QuotaSnapshotsTableAnnotationComposer
    extends Composer<_$AppDatabase, $QuotaSnapshotsTable> {
  $$QuotaSnapshotsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<DateTime> get timestamp =>
      $composableBuilder(column: $table.timestamp, builder: (column) => column);

  GeneratedColumn<String> get bucketId =>
      $composableBuilder(column: $table.bucketId, builder: (column) => column);

  GeneratedColumn<String> get bucketName => $composableBuilder(
    column: $table.bucketName,
    builder: (column) => column,
  );

  GeneratedColumn<String> get windowType => $composableBuilder(
    column: $table.windowType,
    builder: (column) => column,
  );

  GeneratedColumn<int> get windowDurationSeconds => $composableBuilder(
    column: $table.windowDurationSeconds,
    builder: (column) => column,
  );

  GeneratedColumn<double> get usedPercent => $composableBuilder(
    column: $table.usedPercent,
    builder: (column) => column,
  );

  GeneratedColumn<double> get remainingPercent => $composableBuilder(
    column: $table.remainingPercent,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get resetAt =>
      $composableBuilder(column: $table.resetAt, builder: (column) => column);

  GeneratedColumn<String> get planType =>
      $composableBuilder(column: $table.planType, builder: (column) => column);
}

class $$QuotaSnapshotsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $QuotaSnapshotsTable,
          QuotaSnapshot,
          $$QuotaSnapshotsTableFilterComposer,
          $$QuotaSnapshotsTableOrderingComposer,
          $$QuotaSnapshotsTableAnnotationComposer,
          $$QuotaSnapshotsTableCreateCompanionBuilder,
          $$QuotaSnapshotsTableUpdateCompanionBuilder,
          (
            QuotaSnapshot,
            BaseReferences<_$AppDatabase, $QuotaSnapshotsTable, QuotaSnapshot>,
          ),
          QuotaSnapshot,
          PrefetchHooks Function()
        > {
  $$QuotaSnapshotsTableTableManager(
    _$AppDatabase db,
    $QuotaSnapshotsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$QuotaSnapshotsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$QuotaSnapshotsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$QuotaSnapshotsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<DateTime> timestamp = const Value.absent(),
                Value<String> bucketId = const Value.absent(),
                Value<String> bucketName = const Value.absent(),
                Value<String> windowType = const Value.absent(),
                Value<int?> windowDurationSeconds = const Value.absent(),
                Value<double?> usedPercent = const Value.absent(),
                Value<double?> remainingPercent = const Value.absent(),
                Value<DateTime?> resetAt = const Value.absent(),
                Value<String?> planType = const Value.absent(),
              }) => QuotaSnapshotsCompanion(
                id: id,
                timestamp: timestamp,
                bucketId: bucketId,
                bucketName: bucketName,
                windowType: windowType,
                windowDurationSeconds: windowDurationSeconds,
                usedPercent: usedPercent,
                remainingPercent: remainingPercent,
                resetAt: resetAt,
                planType: planType,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required DateTime timestamp,
                required String bucketId,
                required String bucketName,
                required String windowType,
                Value<int?> windowDurationSeconds = const Value.absent(),
                Value<double?> usedPercent = const Value.absent(),
                Value<double?> remainingPercent = const Value.absent(),
                Value<DateTime?> resetAt = const Value.absent(),
                Value<String?> planType = const Value.absent(),
              }) => QuotaSnapshotsCompanion.insert(
                id: id,
                timestamp: timestamp,
                bucketId: bucketId,
                bucketName: bucketName,
                windowType: windowType,
                windowDurationSeconds: windowDurationSeconds,
                usedPercent: usedPercent,
                remainingPercent: remainingPercent,
                resetAt: resetAt,
                planType: planType,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$QuotaSnapshotsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $QuotaSnapshotsTable,
      QuotaSnapshot,
      $$QuotaSnapshotsTableFilterComposer,
      $$QuotaSnapshotsTableOrderingComposer,
      $$QuotaSnapshotsTableAnnotationComposer,
      $$QuotaSnapshotsTableCreateCompanionBuilder,
      $$QuotaSnapshotsTableUpdateCompanionBuilder,
      (
        QuotaSnapshot,
        BaseReferences<_$AppDatabase, $QuotaSnapshotsTable, QuotaSnapshot>,
      ),
      QuotaSnapshot,
      PrefetchHooks Function()
    >;
typedef $$ActivityEventsTableCreateCompanionBuilder =
    ActivityEventsCompanion Function({
      Value<int> id,
      required DateTime timestamp,
      required String type,
      Value<String?> bucketId,
      required String title,
      required String description,
      Value<double?> oldValue,
      Value<double?> newValue,
    });
typedef $$ActivityEventsTableUpdateCompanionBuilder =
    ActivityEventsCompanion Function({
      Value<int> id,
      Value<DateTime> timestamp,
      Value<String> type,
      Value<String?> bucketId,
      Value<String> title,
      Value<String> description,
      Value<double?> oldValue,
      Value<double?> newValue,
    });

class $$ActivityEventsTableFilterComposer
    extends Composer<_$AppDatabase, $ActivityEventsTable> {
  $$ActivityEventsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get timestamp => $composableBuilder(
    column: $table.timestamp,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get bucketId => $composableBuilder(
    column: $table.bucketId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get oldValue => $composableBuilder(
    column: $table.oldValue,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get newValue => $composableBuilder(
    column: $table.newValue,
    builder: (column) => ColumnFilters(column),
  );
}

class $$ActivityEventsTableOrderingComposer
    extends Composer<_$AppDatabase, $ActivityEventsTable> {
  $$ActivityEventsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get timestamp => $composableBuilder(
    column: $table.timestamp,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get bucketId => $composableBuilder(
    column: $table.bucketId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get oldValue => $composableBuilder(
    column: $table.oldValue,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get newValue => $composableBuilder(
    column: $table.newValue,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ActivityEventsTableAnnotationComposer
    extends Composer<_$AppDatabase, $ActivityEventsTable> {
  $$ActivityEventsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<DateTime> get timestamp =>
      $composableBuilder(column: $table.timestamp, builder: (column) => column);

  GeneratedColumn<String> get type =>
      $composableBuilder(column: $table.type, builder: (column) => column);

  GeneratedColumn<String> get bucketId =>
      $composableBuilder(column: $table.bucketId, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => column,
  );

  GeneratedColumn<double> get oldValue =>
      $composableBuilder(column: $table.oldValue, builder: (column) => column);

  GeneratedColumn<double> get newValue =>
      $composableBuilder(column: $table.newValue, builder: (column) => column);
}

class $$ActivityEventsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ActivityEventsTable,
          ActivityEvent,
          $$ActivityEventsTableFilterComposer,
          $$ActivityEventsTableOrderingComposer,
          $$ActivityEventsTableAnnotationComposer,
          $$ActivityEventsTableCreateCompanionBuilder,
          $$ActivityEventsTableUpdateCompanionBuilder,
          (
            ActivityEvent,
            BaseReferences<_$AppDatabase, $ActivityEventsTable, ActivityEvent>,
          ),
          ActivityEvent,
          PrefetchHooks Function()
        > {
  $$ActivityEventsTableTableManager(
    _$AppDatabase db,
    $ActivityEventsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ActivityEventsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ActivityEventsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ActivityEventsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<DateTime> timestamp = const Value.absent(),
                Value<String> type = const Value.absent(),
                Value<String?> bucketId = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<String> description = const Value.absent(),
                Value<double?> oldValue = const Value.absent(),
                Value<double?> newValue = const Value.absent(),
              }) => ActivityEventsCompanion(
                id: id,
                timestamp: timestamp,
                type: type,
                bucketId: bucketId,
                title: title,
                description: description,
                oldValue: oldValue,
                newValue: newValue,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required DateTime timestamp,
                required String type,
                Value<String?> bucketId = const Value.absent(),
                required String title,
                required String description,
                Value<double?> oldValue = const Value.absent(),
                Value<double?> newValue = const Value.absent(),
              }) => ActivityEventsCompanion.insert(
                id: id,
                timestamp: timestamp,
                type: type,
                bucketId: bucketId,
                title: title,
                description: description,
                oldValue: oldValue,
                newValue: newValue,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$ActivityEventsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ActivityEventsTable,
      ActivityEvent,
      $$ActivityEventsTableFilterComposer,
      $$ActivityEventsTableOrderingComposer,
      $$ActivityEventsTableAnnotationComposer,
      $$ActivityEventsTableCreateCompanionBuilder,
      $$ActivityEventsTableUpdateCompanionBuilder,
      (
        ActivityEvent,
        BaseReferences<_$AppDatabase, $ActivityEventsTable, ActivityEvent>,
      ),
      ActivityEvent,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$QuotaSnapshotsTableTableManager get quotaSnapshots =>
      $$QuotaSnapshotsTableTableManager(_db, _db.quotaSnapshots);
  $$ActivityEventsTableTableManager get activityEvents =>
      $$ActivityEventsTableTableManager(_db, _db.activityEvents);
}
