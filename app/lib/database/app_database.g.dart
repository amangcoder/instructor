// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
class $PlansTableTable extends PlansTable
    with TableInfo<$PlansTableTable, PlansTableData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PlansTableTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
      'id', aliasedName, false,
      hasAutoIncrement: true,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('PRIMARY KEY AUTOINCREMENT'));
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
      'name', aliasedName, false,
      additionalChecks:
          GeneratedColumn.checkTextLength(minTextLength: 1, maxTextLength: 100),
      type: DriftSqlType.string,
      requiredDuringInsert: true);
  static const VerificationMeta _descriptionMeta =
      const VerificationMeta('description');
  @override
  late final GeneratedColumn<String> description = GeneratedColumn<String>(
      'description', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _categoryMeta =
      const VerificationMeta('category');
  @override
  late final GeneratedColumn<String> category = GeneratedColumn<String>(
      'category', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant('custom'));
  @override
  late final GeneratedColumnWithTypeConverter<List<String>, String> tags =
      GeneratedColumn<String>('tags', aliasedName, false,
              type: DriftSqlType.string,
              requiredDuringInsert: false,
              defaultValue: const Constant('[]'))
          .withConverter<List<String>>($PlansTableTable.$convertertags);
  static const VerificationMeta _defaultVoiceMeta =
      const VerificationMeta('defaultVoice');
  @override
  late final GeneratedColumn<String> defaultVoice = GeneratedColumn<String>(
      'default_voice', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant('nova'));
  @override
  late final GeneratedColumnWithTypeConverter<List<PlanStep>, String> steps =
      GeneratedColumn<String>('steps', aliasedName, false,
              type: DriftSqlType.string,
              requiredDuringInsert: false,
              defaultValue: const Constant('[]'))
          .withConverter<List<PlanStep>>($PlansTableTable.$convertersteps);
  static const VerificationMeta _createdAtMeta =
      const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
      'created_at', aliasedName, false,
      type: DriftSqlType.dateTime,
      requiredDuringInsert: false,
      defaultValue: currentDateAndTime);
  static const VerificationMeta _updatedAtMeta =
      const VerificationMeta('updatedAt');
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
      'updated_at', aliasedName, false,
      type: DriftSqlType.dateTime,
      requiredDuringInsert: false,
      defaultValue: currentDateAndTime);
  static const VerificationMeta _lastUsedAtMeta =
      const VerificationMeta('lastUsedAt');
  @override
  late final GeneratedColumn<DateTime> lastUsedAt = GeneratedColumn<DateTime>(
      'last_used_at', aliasedName, true,
      type: DriftSqlType.dateTime, requiredDuringInsert: false);
  @override
  List<GeneratedColumn> get $columns => [
        id,
        name,
        description,
        category,
        tags,
        defaultVoice,
        steps,
        createdAt,
        updatedAt,
        lastUsedAt
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'plans';
  @override
  VerificationContext validateIntegrity(Insertable<PlansTableData> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('name')) {
      context.handle(
          _nameMeta, name.isAcceptableOrUnknown(data['name']!, _nameMeta));
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('description')) {
      context.handle(
          _descriptionMeta,
          description.isAcceptableOrUnknown(
              data['description']!, _descriptionMeta));
    }
    if (data.containsKey('category')) {
      context.handle(_categoryMeta,
          category.isAcceptableOrUnknown(data['category']!, _categoryMeta));
    }
    if (data.containsKey('default_voice')) {
      context.handle(
          _defaultVoiceMeta,
          defaultVoice.isAcceptableOrUnknown(
              data['default_voice']!, _defaultVoiceMeta));
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta,
          createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    }
    if (data.containsKey('updated_at')) {
      context.handle(_updatedAtMeta,
          updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta));
    }
    if (data.containsKey('last_used_at')) {
      context.handle(
          _lastUsedAtMeta,
          lastUsedAt.isAcceptableOrUnknown(
              data['last_used_at']!, _lastUsedAtMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  PlansTableData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PlansTableData(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      name: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}name'])!,
      description: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}description']),
      category: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}category'])!,
      tags: $PlansTableTable.$convertertags.fromSql(attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}tags'])!),
      defaultVoice: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}default_voice'])!,
      steps: $PlansTableTable.$convertersteps.fromSql(attachedDatabase
          .typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}steps'])!),
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}created_at'])!,
      updatedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}updated_at'])!,
      lastUsedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}last_used_at']),
    );
  }

  @override
  $PlansTableTable createAlias(String alias) {
    return $PlansTableTable(attachedDatabase, alias);
  }

  static TypeConverter<List<String>, String> $convertertags =
      const StringListConverter();
  static TypeConverter<List<PlanStep>, String> $convertersteps =
      const StepListConverter();
}

class PlansTableData extends DataClass implements Insertable<PlansTableData> {
  final int id;
  final String name;
  final String? description;

  /// [PlanCategory] stored as its string name.
  final String category;

  /// JSON array of tag strings.
  final List<String> tags;

  /// Voice identifier string (OpenAI voice name or 'platform').
  final String defaultVoice;

  /// JSON-encoded list of [PlanStep] objects.
  final List<PlanStep> steps;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? lastUsedAt;
  const PlansTableData(
      {required this.id,
      required this.name,
      this.description,
      required this.category,
      required this.tags,
      required this.defaultVoice,
      required this.steps,
      required this.createdAt,
      required this.updatedAt,
      this.lastUsedAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['name'] = Variable<String>(name);
    if (!nullToAbsent || description != null) {
      map['description'] = Variable<String>(description);
    }
    map['category'] = Variable<String>(category);
    {
      map['tags'] =
          Variable<String>($PlansTableTable.$convertertags.toSql(tags));
    }
    map['default_voice'] = Variable<String>(defaultVoice);
    {
      map['steps'] =
          Variable<String>($PlansTableTable.$convertersteps.toSql(steps));
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    if (!nullToAbsent || lastUsedAt != null) {
      map['last_used_at'] = Variable<DateTime>(lastUsedAt);
    }
    return map;
  }

  PlansTableCompanion toCompanion(bool nullToAbsent) {
    return PlansTableCompanion(
      id: Value(id),
      name: Value(name),
      description: description == null && nullToAbsent
          ? const Value.absent()
          : Value(description),
      category: Value(category),
      tags: Value(tags),
      defaultVoice: Value(defaultVoice),
      steps: Value(steps),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      lastUsedAt: lastUsedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(lastUsedAt),
    );
  }

  factory PlansTableData.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PlansTableData(
      id: serializer.fromJson<int>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      description: serializer.fromJson<String?>(json['description']),
      category: serializer.fromJson<String>(json['category']),
      tags: serializer.fromJson<List<String>>(json['tags']),
      defaultVoice: serializer.fromJson<String>(json['defaultVoice']),
      steps: serializer.fromJson<List<PlanStep>>(json['steps']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
      lastUsedAt: serializer.fromJson<DateTime?>(json['lastUsedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'name': serializer.toJson<String>(name),
      'description': serializer.toJson<String?>(description),
      'category': serializer.toJson<String>(category),
      'tags': serializer.toJson<List<String>>(tags),
      'defaultVoice': serializer.toJson<String>(defaultVoice),
      'steps': serializer.toJson<List<PlanStep>>(steps),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
      'lastUsedAt': serializer.toJson<DateTime?>(lastUsedAt),
    };
  }

  PlansTableData copyWith(
          {int? id,
          String? name,
          Value<String?> description = const Value.absent(),
          String? category,
          List<String>? tags,
          String? defaultVoice,
          List<PlanStep>? steps,
          DateTime? createdAt,
          DateTime? updatedAt,
          Value<DateTime?> lastUsedAt = const Value.absent()}) =>
      PlansTableData(
        id: id ?? this.id,
        name: name ?? this.name,
        description: description.present ? description.value : this.description,
        category: category ?? this.category,
        tags: tags ?? this.tags,
        defaultVoice: defaultVoice ?? this.defaultVoice,
        steps: steps ?? this.steps,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
        lastUsedAt: lastUsedAt.present ? lastUsedAt.value : this.lastUsedAt,
      );
  PlansTableData copyWithCompanion(PlansTableCompanion data) {
    return PlansTableData(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      description:
          data.description.present ? data.description.value : this.description,
      category: data.category.present ? data.category.value : this.category,
      tags: data.tags.present ? data.tags.value : this.tags,
      defaultVoice: data.defaultVoice.present
          ? data.defaultVoice.value
          : this.defaultVoice,
      steps: data.steps.present ? data.steps.value : this.steps,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      lastUsedAt:
          data.lastUsedAt.present ? data.lastUsedAt.value : this.lastUsedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('PlansTableData(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('description: $description, ')
          ..write('category: $category, ')
          ..write('tags: $tags, ')
          ..write('defaultVoice: $defaultVoice, ')
          ..write('steps: $steps, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('lastUsedAt: $lastUsedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, name, description, category, tags,
      defaultVoice, steps, createdAt, updatedAt, lastUsedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PlansTableData &&
          other.id == this.id &&
          other.name == this.name &&
          other.description == this.description &&
          other.category == this.category &&
          other.tags == this.tags &&
          other.defaultVoice == this.defaultVoice &&
          other.steps == this.steps &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.lastUsedAt == this.lastUsedAt);
}

class PlansTableCompanion extends UpdateCompanion<PlansTableData> {
  final Value<int> id;
  final Value<String> name;
  final Value<String?> description;
  final Value<String> category;
  final Value<List<String>> tags;
  final Value<String> defaultVoice;
  final Value<List<PlanStep>> steps;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<DateTime?> lastUsedAt;
  const PlansTableCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.description = const Value.absent(),
    this.category = const Value.absent(),
    this.tags = const Value.absent(),
    this.defaultVoice = const Value.absent(),
    this.steps = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.lastUsedAt = const Value.absent(),
  });
  PlansTableCompanion.insert({
    this.id = const Value.absent(),
    required String name,
    this.description = const Value.absent(),
    this.category = const Value.absent(),
    this.tags = const Value.absent(),
    this.defaultVoice = const Value.absent(),
    this.steps = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.lastUsedAt = const Value.absent(),
  }) : name = Value(name);
  static Insertable<PlansTableData> custom({
    Expression<int>? id,
    Expression<String>? name,
    Expression<String>? description,
    Expression<String>? category,
    Expression<String>? tags,
    Expression<String>? defaultVoice,
    Expression<String>? steps,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<DateTime>? lastUsedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (description != null) 'description': description,
      if (category != null) 'category': category,
      if (tags != null) 'tags': tags,
      if (defaultVoice != null) 'default_voice': defaultVoice,
      if (steps != null) 'steps': steps,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (lastUsedAt != null) 'last_used_at': lastUsedAt,
    });
  }

  PlansTableCompanion copyWith(
      {Value<int>? id,
      Value<String>? name,
      Value<String?>? description,
      Value<String>? category,
      Value<List<String>>? tags,
      Value<String>? defaultVoice,
      Value<List<PlanStep>>? steps,
      Value<DateTime>? createdAt,
      Value<DateTime>? updatedAt,
      Value<DateTime?>? lastUsedAt}) {
    return PlansTableCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      category: category ?? this.category,
      tags: tags ?? this.tags,
      defaultVoice: defaultVoice ?? this.defaultVoice,
      steps: steps ?? this.steps,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      lastUsedAt: lastUsedAt ?? this.lastUsedAt,
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
    if (category.present) {
      map['category'] = Variable<String>(category.value);
    }
    if (tags.present) {
      map['tags'] =
          Variable<String>($PlansTableTable.$convertertags.toSql(tags.value));
    }
    if (defaultVoice.present) {
      map['default_voice'] = Variable<String>(defaultVoice.value);
    }
    if (steps.present) {
      map['steps'] =
          Variable<String>($PlansTableTable.$convertersteps.toSql(steps.value));
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (lastUsedAt.present) {
      map['last_used_at'] = Variable<DateTime>(lastUsedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PlansTableCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('description: $description, ')
          ..write('category: $category, ')
          ..write('tags: $tags, ')
          ..write('defaultVoice: $defaultVoice, ')
          ..write('steps: $steps, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('lastUsedAt: $lastUsedAt')
          ..write(')'))
        .toString();
  }
}

class $TtsCacheTableTable extends TtsCacheTable
    with TableInfo<$TtsCacheTableTable, TtsCacheTableData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $TtsCacheTableTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
      'id', aliasedName, false,
      hasAutoIncrement: true,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('PRIMARY KEY AUTOINCREMENT'));
  static const VerificationMeta _textHashMeta =
      const VerificationMeta('textHash');
  @override
  late final GeneratedColumn<String> textHash = GeneratedColumn<String>(
      'text_hash', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: true,
      defaultConstraints: GeneratedColumn.constraintIsAlways('UNIQUE'));
  static const VerificationMeta _voiceIdMeta =
      const VerificationMeta('voiceId');
  @override
  late final GeneratedColumn<String> voiceId = GeneratedColumn<String>(
      'voice_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _filePathMeta =
      const VerificationMeta('filePath');
  @override
  late final GeneratedColumn<String> filePath = GeneratedColumn<String>(
      'file_path', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _fileSizeBytesMeta =
      const VerificationMeta('fileSizeBytes');
  @override
  late final GeneratedColumn<int> fileSizeBytes = GeneratedColumn<int>(
      'file_size_bytes', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
  static const VerificationMeta _planIdMeta = const VerificationMeta('planId');
  @override
  late final GeneratedColumn<int> planId = GeneratedColumn<int>(
      'plan_id', aliasedName, true,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultConstraints: GeneratedColumn.constraintIsAlways(
          'REFERENCES plans (id) ON DELETE SET NULL'));
  static const VerificationMeta _createdAtMeta =
      const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
      'created_at', aliasedName, false,
      type: DriftSqlType.dateTime,
      requiredDuringInsert: false,
      defaultValue: currentDateAndTime);
  @override
  List<GeneratedColumn> get $columns =>
      [id, textHash, voiceId, filePath, fileSizeBytes, planId, createdAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'tts_cache';
  @override
  VerificationContext validateIntegrity(Insertable<TtsCacheTableData> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('text_hash')) {
      context.handle(_textHashMeta,
          textHash.isAcceptableOrUnknown(data['text_hash']!, _textHashMeta));
    } else if (isInserting) {
      context.missing(_textHashMeta);
    }
    if (data.containsKey('voice_id')) {
      context.handle(_voiceIdMeta,
          voiceId.isAcceptableOrUnknown(data['voice_id']!, _voiceIdMeta));
    } else if (isInserting) {
      context.missing(_voiceIdMeta);
    }
    if (data.containsKey('file_path')) {
      context.handle(_filePathMeta,
          filePath.isAcceptableOrUnknown(data['file_path']!, _filePathMeta));
    } else if (isInserting) {
      context.missing(_filePathMeta);
    }
    if (data.containsKey('file_size_bytes')) {
      context.handle(
          _fileSizeBytesMeta,
          fileSizeBytes.isAcceptableOrUnknown(
              data['file_size_bytes']!, _fileSizeBytesMeta));
    }
    if (data.containsKey('plan_id')) {
      context.handle(_planIdMeta,
          planId.isAcceptableOrUnknown(data['plan_id']!, _planIdMeta));
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta,
          createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  TtsCacheTableData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return TtsCacheTableData(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      textHash: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}text_hash'])!,
      voiceId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}voice_id'])!,
      filePath: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}file_path'])!,
      fileSizeBytes: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}file_size_bytes'])!,
      planId: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}plan_id']),
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}created_at'])!,
    );
  }

  @override
  $TtsCacheTableTable createAlias(String alias) {
    return $TtsCacheTableTable(attachedDatabase, alias);
  }
}

class TtsCacheTableData extends DataClass
    implements Insertable<TtsCacheTableData> {
  final int id;

  /// SHA-256 hash of (voiceId + ":" + text) — used as the deduplication key.
  final String textHash;
  final String voiceId;

  /// Absolute path to the cached audio file on local storage.
  final String filePath;

  /// Size of the audio file in bytes.
  final int fileSizeBytes;

  /// Optional reference back to the owning Plan for bulk cache eviction.
  final int? planId;
  final DateTime createdAt;
  const TtsCacheTableData(
      {required this.id,
      required this.textHash,
      required this.voiceId,
      required this.filePath,
      required this.fileSizeBytes,
      this.planId,
      required this.createdAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['text_hash'] = Variable<String>(textHash);
    map['voice_id'] = Variable<String>(voiceId);
    map['file_path'] = Variable<String>(filePath);
    map['file_size_bytes'] = Variable<int>(fileSizeBytes);
    if (!nullToAbsent || planId != null) {
      map['plan_id'] = Variable<int>(planId);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  TtsCacheTableCompanion toCompanion(bool nullToAbsent) {
    return TtsCacheTableCompanion(
      id: Value(id),
      textHash: Value(textHash),
      voiceId: Value(voiceId),
      filePath: Value(filePath),
      fileSizeBytes: Value(fileSizeBytes),
      planId:
          planId == null && nullToAbsent ? const Value.absent() : Value(planId),
      createdAt: Value(createdAt),
    );
  }

  factory TtsCacheTableData.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return TtsCacheTableData(
      id: serializer.fromJson<int>(json['id']),
      textHash: serializer.fromJson<String>(json['textHash']),
      voiceId: serializer.fromJson<String>(json['voiceId']),
      filePath: serializer.fromJson<String>(json['filePath']),
      fileSizeBytes: serializer.fromJson<int>(json['fileSizeBytes']),
      planId: serializer.fromJson<int?>(json['planId']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'textHash': serializer.toJson<String>(textHash),
      'voiceId': serializer.toJson<String>(voiceId),
      'filePath': serializer.toJson<String>(filePath),
      'fileSizeBytes': serializer.toJson<int>(fileSizeBytes),
      'planId': serializer.toJson<int?>(planId),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  TtsCacheTableData copyWith(
          {int? id,
          String? textHash,
          String? voiceId,
          String? filePath,
          int? fileSizeBytes,
          Value<int?> planId = const Value.absent(),
          DateTime? createdAt}) =>
      TtsCacheTableData(
        id: id ?? this.id,
        textHash: textHash ?? this.textHash,
        voiceId: voiceId ?? this.voiceId,
        filePath: filePath ?? this.filePath,
        fileSizeBytes: fileSizeBytes ?? this.fileSizeBytes,
        planId: planId.present ? planId.value : this.planId,
        createdAt: createdAt ?? this.createdAt,
      );
  TtsCacheTableData copyWithCompanion(TtsCacheTableCompanion data) {
    return TtsCacheTableData(
      id: data.id.present ? data.id.value : this.id,
      textHash: data.textHash.present ? data.textHash.value : this.textHash,
      voiceId: data.voiceId.present ? data.voiceId.value : this.voiceId,
      filePath: data.filePath.present ? data.filePath.value : this.filePath,
      fileSizeBytes: data.fileSizeBytes.present
          ? data.fileSizeBytes.value
          : this.fileSizeBytes,
      planId: data.planId.present ? data.planId.value : this.planId,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('TtsCacheTableData(')
          ..write('id: $id, ')
          ..write('textHash: $textHash, ')
          ..write('voiceId: $voiceId, ')
          ..write('filePath: $filePath, ')
          ..write('fileSizeBytes: $fileSizeBytes, ')
          ..write('planId: $planId, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
      id, textHash, voiceId, filePath, fileSizeBytes, planId, createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is TtsCacheTableData &&
          other.id == this.id &&
          other.textHash == this.textHash &&
          other.voiceId == this.voiceId &&
          other.filePath == this.filePath &&
          other.fileSizeBytes == this.fileSizeBytes &&
          other.planId == this.planId &&
          other.createdAt == this.createdAt);
}

class TtsCacheTableCompanion extends UpdateCompanion<TtsCacheTableData> {
  final Value<int> id;
  final Value<String> textHash;
  final Value<String> voiceId;
  final Value<String> filePath;
  final Value<int> fileSizeBytes;
  final Value<int?> planId;
  final Value<DateTime> createdAt;
  const TtsCacheTableCompanion({
    this.id = const Value.absent(),
    this.textHash = const Value.absent(),
    this.voiceId = const Value.absent(),
    this.filePath = const Value.absent(),
    this.fileSizeBytes = const Value.absent(),
    this.planId = const Value.absent(),
    this.createdAt = const Value.absent(),
  });
  TtsCacheTableCompanion.insert({
    this.id = const Value.absent(),
    required String textHash,
    required String voiceId,
    required String filePath,
    this.fileSizeBytes = const Value.absent(),
    this.planId = const Value.absent(),
    this.createdAt = const Value.absent(),
  })  : textHash = Value(textHash),
        voiceId = Value(voiceId),
        filePath = Value(filePath);
  static Insertable<TtsCacheTableData> custom({
    Expression<int>? id,
    Expression<String>? textHash,
    Expression<String>? voiceId,
    Expression<String>? filePath,
    Expression<int>? fileSizeBytes,
    Expression<int>? planId,
    Expression<DateTime>? createdAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (textHash != null) 'text_hash': textHash,
      if (voiceId != null) 'voice_id': voiceId,
      if (filePath != null) 'file_path': filePath,
      if (fileSizeBytes != null) 'file_size_bytes': fileSizeBytes,
      if (planId != null) 'plan_id': planId,
      if (createdAt != null) 'created_at': createdAt,
    });
  }

  TtsCacheTableCompanion copyWith(
      {Value<int>? id,
      Value<String>? textHash,
      Value<String>? voiceId,
      Value<String>? filePath,
      Value<int>? fileSizeBytes,
      Value<int?>? planId,
      Value<DateTime>? createdAt}) {
    return TtsCacheTableCompanion(
      id: id ?? this.id,
      textHash: textHash ?? this.textHash,
      voiceId: voiceId ?? this.voiceId,
      filePath: filePath ?? this.filePath,
      fileSizeBytes: fileSizeBytes ?? this.fileSizeBytes,
      planId: planId ?? this.planId,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (textHash.present) {
      map['text_hash'] = Variable<String>(textHash.value);
    }
    if (voiceId.present) {
      map['voice_id'] = Variable<String>(voiceId.value);
    }
    if (filePath.present) {
      map['file_path'] = Variable<String>(filePath.value);
    }
    if (fileSizeBytes.present) {
      map['file_size_bytes'] = Variable<int>(fileSizeBytes.value);
    }
    if (planId.present) {
      map['plan_id'] = Variable<int>(planId.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('TtsCacheTableCompanion(')
          ..write('id: $id, ')
          ..write('textHash: $textHash, ')
          ..write('voiceId: $voiceId, ')
          ..write('filePath: $filePath, ')
          ..write('fileSizeBytes: $fileSizeBytes, ')
          ..write('planId: $planId, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }
}

class $ExecutionStateTableTable extends ExecutionStateTable
    with TableInfo<$ExecutionStateTableTable, ExecutionStateTableData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ExecutionStateTableTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
      'id', aliasedName, false,
      hasAutoIncrement: true,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('PRIMARY KEY AUTOINCREMENT'));
  static const VerificationMeta _planIdMeta = const VerificationMeta('planId');
  @override
  late final GeneratedColumn<int> planId = GeneratedColumn<int>(
      'plan_id', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: true,
      defaultConstraints: GeneratedColumn.constraintIsAlways(
          'REFERENCES plans (id) ON DELETE CASCADE'));
  static const VerificationMeta _currentStepIndexMeta =
      const VerificationMeta('currentStepIndex');
  @override
  late final GeneratedColumn<int> currentStepIndex = GeneratedColumn<int>(
      'current_step_index', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
  static const VerificationMeta _repeatCountersMeta =
      const VerificationMeta('repeatCounters');
  @override
  late final GeneratedColumn<String> repeatCounters = GeneratedColumn<String>(
      'repeat_counters', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant('{}'));
  static const VerificationMeta _elapsedMsMeta =
      const VerificationMeta('elapsedMs');
  @override
  late final GeneratedColumn<int> elapsedMs = GeneratedColumn<int>(
      'elapsed_ms', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
  static const VerificationMeta _ambientPositionMsMeta =
      const VerificationMeta('ambientPositionMs');
  @override
  late final GeneratedColumn<int> ambientPositionMs = GeneratedColumn<int>(
      'ambient_position_ms', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
      'status', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant('paused'));
  static const VerificationMeta _savedAtMeta =
      const VerificationMeta('savedAt');
  @override
  late final GeneratedColumn<DateTime> savedAt = GeneratedColumn<DateTime>(
      'saved_at', aliasedName, false,
      type: DriftSqlType.dateTime,
      requiredDuringInsert: false,
      defaultValue: currentDateAndTime);
  @override
  List<GeneratedColumn> get $columns => [
        id,
        planId,
        currentStepIndex,
        repeatCounters,
        elapsedMs,
        ambientPositionMs,
        status,
        savedAt
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'execution_state';
  @override
  VerificationContext validateIntegrity(
      Insertable<ExecutionStateTableData> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('plan_id')) {
      context.handle(_planIdMeta,
          planId.isAcceptableOrUnknown(data['plan_id']!, _planIdMeta));
    } else if (isInserting) {
      context.missing(_planIdMeta);
    }
    if (data.containsKey('current_step_index')) {
      context.handle(
          _currentStepIndexMeta,
          currentStepIndex.isAcceptableOrUnknown(
              data['current_step_index']!, _currentStepIndexMeta));
    }
    if (data.containsKey('repeat_counters')) {
      context.handle(
          _repeatCountersMeta,
          repeatCounters.isAcceptableOrUnknown(
              data['repeat_counters']!, _repeatCountersMeta));
    }
    if (data.containsKey('elapsed_ms')) {
      context.handle(_elapsedMsMeta,
          elapsedMs.isAcceptableOrUnknown(data['elapsed_ms']!, _elapsedMsMeta));
    }
    if (data.containsKey('ambient_position_ms')) {
      context.handle(
          _ambientPositionMsMeta,
          ambientPositionMs.isAcceptableOrUnknown(
              data['ambient_position_ms']!, _ambientPositionMsMeta));
    }
    if (data.containsKey('status')) {
      context.handle(_statusMeta,
          status.isAcceptableOrUnknown(data['status']!, _statusMeta));
    }
    if (data.containsKey('saved_at')) {
      context.handle(_savedAtMeta,
          savedAt.isAcceptableOrUnknown(data['saved_at']!, _savedAtMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ExecutionStateTableData map(Map<String, dynamic> data,
      {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ExecutionStateTableData(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      planId: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}plan_id'])!,
      currentStepIndex: attachedDatabase.typeMapping.read(
          DriftSqlType.int, data['${effectivePrefix}current_step_index'])!,
      repeatCounters: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}repeat_counters'])!,
      elapsedMs: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}elapsed_ms'])!,
      ambientPositionMs: attachedDatabase.typeMapping.read(
          DriftSqlType.int, data['${effectivePrefix}ambient_position_ms'])!,
      status: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}status'])!,
      savedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}saved_at'])!,
    );
  }

  @override
  $ExecutionStateTableTable createAlias(String alias) {
    return $ExecutionStateTableTable(attachedDatabase, alias);
  }
}

class ExecutionStateTableData extends DataClass
    implements Insertable<ExecutionStateTableData> {
  final int id;
  final int planId;

  /// Index into the Plan's flattened step list.
  final int currentStepIndex;

  /// JSON-encoded map of repeatStepId → current iteration count.
  final String repeatCounters;

  /// Total elapsed time in milliseconds since the Plan started.
  final int elapsedMs;

  /// Ambient audio playback position in milliseconds for resume-after-interrupt.
  final int ambientPositionMs;

  /// [ExecutionStatus] name string.
  final String status;
  final DateTime savedAt;
  const ExecutionStateTableData(
      {required this.id,
      required this.planId,
      required this.currentStepIndex,
      required this.repeatCounters,
      required this.elapsedMs,
      required this.ambientPositionMs,
      required this.status,
      required this.savedAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['plan_id'] = Variable<int>(planId);
    map['current_step_index'] = Variable<int>(currentStepIndex);
    map['repeat_counters'] = Variable<String>(repeatCounters);
    map['elapsed_ms'] = Variable<int>(elapsedMs);
    map['ambient_position_ms'] = Variable<int>(ambientPositionMs);
    map['status'] = Variable<String>(status);
    map['saved_at'] = Variable<DateTime>(savedAt);
    return map;
  }

  ExecutionStateTableCompanion toCompanion(bool nullToAbsent) {
    return ExecutionStateTableCompanion(
      id: Value(id),
      planId: Value(planId),
      currentStepIndex: Value(currentStepIndex),
      repeatCounters: Value(repeatCounters),
      elapsedMs: Value(elapsedMs),
      ambientPositionMs: Value(ambientPositionMs),
      status: Value(status),
      savedAt: Value(savedAt),
    );
  }

  factory ExecutionStateTableData.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ExecutionStateTableData(
      id: serializer.fromJson<int>(json['id']),
      planId: serializer.fromJson<int>(json['planId']),
      currentStepIndex: serializer.fromJson<int>(json['currentStepIndex']),
      repeatCounters: serializer.fromJson<String>(json['repeatCounters']),
      elapsedMs: serializer.fromJson<int>(json['elapsedMs']),
      ambientPositionMs: serializer.fromJson<int>(json['ambientPositionMs']),
      status: serializer.fromJson<String>(json['status']),
      savedAt: serializer.fromJson<DateTime>(json['savedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'planId': serializer.toJson<int>(planId),
      'currentStepIndex': serializer.toJson<int>(currentStepIndex),
      'repeatCounters': serializer.toJson<String>(repeatCounters),
      'elapsedMs': serializer.toJson<int>(elapsedMs),
      'ambientPositionMs': serializer.toJson<int>(ambientPositionMs),
      'status': serializer.toJson<String>(status),
      'savedAt': serializer.toJson<DateTime>(savedAt),
    };
  }

  ExecutionStateTableData copyWith(
          {int? id,
          int? planId,
          int? currentStepIndex,
          String? repeatCounters,
          int? elapsedMs,
          int? ambientPositionMs,
          String? status,
          DateTime? savedAt}) =>
      ExecutionStateTableData(
        id: id ?? this.id,
        planId: planId ?? this.planId,
        currentStepIndex: currentStepIndex ?? this.currentStepIndex,
        repeatCounters: repeatCounters ?? this.repeatCounters,
        elapsedMs: elapsedMs ?? this.elapsedMs,
        ambientPositionMs: ambientPositionMs ?? this.ambientPositionMs,
        status: status ?? this.status,
        savedAt: savedAt ?? this.savedAt,
      );
  ExecutionStateTableData copyWithCompanion(ExecutionStateTableCompanion data) {
    return ExecutionStateTableData(
      id: data.id.present ? data.id.value : this.id,
      planId: data.planId.present ? data.planId.value : this.planId,
      currentStepIndex: data.currentStepIndex.present
          ? data.currentStepIndex.value
          : this.currentStepIndex,
      repeatCounters: data.repeatCounters.present
          ? data.repeatCounters.value
          : this.repeatCounters,
      elapsedMs: data.elapsedMs.present ? data.elapsedMs.value : this.elapsedMs,
      ambientPositionMs: data.ambientPositionMs.present
          ? data.ambientPositionMs.value
          : this.ambientPositionMs,
      status: data.status.present ? data.status.value : this.status,
      savedAt: data.savedAt.present ? data.savedAt.value : this.savedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ExecutionStateTableData(')
          ..write('id: $id, ')
          ..write('planId: $planId, ')
          ..write('currentStepIndex: $currentStepIndex, ')
          ..write('repeatCounters: $repeatCounters, ')
          ..write('elapsedMs: $elapsedMs, ')
          ..write('ambientPositionMs: $ambientPositionMs, ')
          ..write('status: $status, ')
          ..write('savedAt: $savedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, planId, currentStepIndex, repeatCounters,
      elapsedMs, ambientPositionMs, status, savedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ExecutionStateTableData &&
          other.id == this.id &&
          other.planId == this.planId &&
          other.currentStepIndex == this.currentStepIndex &&
          other.repeatCounters == this.repeatCounters &&
          other.elapsedMs == this.elapsedMs &&
          other.ambientPositionMs == this.ambientPositionMs &&
          other.status == this.status &&
          other.savedAt == this.savedAt);
}

class ExecutionStateTableCompanion
    extends UpdateCompanion<ExecutionStateTableData> {
  final Value<int> id;
  final Value<int> planId;
  final Value<int> currentStepIndex;
  final Value<String> repeatCounters;
  final Value<int> elapsedMs;
  final Value<int> ambientPositionMs;
  final Value<String> status;
  final Value<DateTime> savedAt;
  const ExecutionStateTableCompanion({
    this.id = const Value.absent(),
    this.planId = const Value.absent(),
    this.currentStepIndex = const Value.absent(),
    this.repeatCounters = const Value.absent(),
    this.elapsedMs = const Value.absent(),
    this.ambientPositionMs = const Value.absent(),
    this.status = const Value.absent(),
    this.savedAt = const Value.absent(),
  });
  ExecutionStateTableCompanion.insert({
    this.id = const Value.absent(),
    required int planId,
    this.currentStepIndex = const Value.absent(),
    this.repeatCounters = const Value.absent(),
    this.elapsedMs = const Value.absent(),
    this.ambientPositionMs = const Value.absent(),
    this.status = const Value.absent(),
    this.savedAt = const Value.absent(),
  }) : planId = Value(planId);
  static Insertable<ExecutionStateTableData> custom({
    Expression<int>? id,
    Expression<int>? planId,
    Expression<int>? currentStepIndex,
    Expression<String>? repeatCounters,
    Expression<int>? elapsedMs,
    Expression<int>? ambientPositionMs,
    Expression<String>? status,
    Expression<DateTime>? savedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (planId != null) 'plan_id': planId,
      if (currentStepIndex != null) 'current_step_index': currentStepIndex,
      if (repeatCounters != null) 'repeat_counters': repeatCounters,
      if (elapsedMs != null) 'elapsed_ms': elapsedMs,
      if (ambientPositionMs != null) 'ambient_position_ms': ambientPositionMs,
      if (status != null) 'status': status,
      if (savedAt != null) 'saved_at': savedAt,
    });
  }

  ExecutionStateTableCompanion copyWith(
      {Value<int>? id,
      Value<int>? planId,
      Value<int>? currentStepIndex,
      Value<String>? repeatCounters,
      Value<int>? elapsedMs,
      Value<int>? ambientPositionMs,
      Value<String>? status,
      Value<DateTime>? savedAt}) {
    return ExecutionStateTableCompanion(
      id: id ?? this.id,
      planId: planId ?? this.planId,
      currentStepIndex: currentStepIndex ?? this.currentStepIndex,
      repeatCounters: repeatCounters ?? this.repeatCounters,
      elapsedMs: elapsedMs ?? this.elapsedMs,
      ambientPositionMs: ambientPositionMs ?? this.ambientPositionMs,
      status: status ?? this.status,
      savedAt: savedAt ?? this.savedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (planId.present) {
      map['plan_id'] = Variable<int>(planId.value);
    }
    if (currentStepIndex.present) {
      map['current_step_index'] = Variable<int>(currentStepIndex.value);
    }
    if (repeatCounters.present) {
      map['repeat_counters'] = Variable<String>(repeatCounters.value);
    }
    if (elapsedMs.present) {
      map['elapsed_ms'] = Variable<int>(elapsedMs.value);
    }
    if (ambientPositionMs.present) {
      map['ambient_position_ms'] = Variable<int>(ambientPositionMs.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (savedAt.present) {
      map['saved_at'] = Variable<DateTime>(savedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ExecutionStateTableCompanion(')
          ..write('id: $id, ')
          ..write('planId: $planId, ')
          ..write('currentStepIndex: $currentStepIndex, ')
          ..write('repeatCounters: $repeatCounters, ')
          ..write('elapsedMs: $elapsedMs, ')
          ..write('ambientPositionMs: $ambientPositionMs, ')
          ..write('status: $status, ')
          ..write('savedAt: $savedAt')
          ..write(')'))
        .toString();
  }
}

class $AppSettingsTableTable extends AppSettingsTable
    with TableInfo<$AppSettingsTableTable, AppSettingsTableData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AppSettingsTableTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
      'id', aliasedName, false,
      hasAutoIncrement: true,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('PRIMARY KEY AUTOINCREMENT'));
  static const VerificationMeta _keyMeta = const VerificationMeta('key');
  @override
  late final GeneratedColumn<String> key = GeneratedColumn<String>(
      'key', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: true,
      defaultConstraints: GeneratedColumn.constraintIsAlways('UNIQUE'));
  static const VerificationMeta _valueMeta = const VerificationMeta('value');
  @override
  late final GeneratedColumn<String> value = GeneratedColumn<String>(
      'value', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _updatedAtMeta =
      const VerificationMeta('updatedAt');
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
      'updated_at', aliasedName, false,
      type: DriftSqlType.dateTime,
      requiredDuringInsert: false,
      defaultValue: currentDateAndTime);
  @override
  List<GeneratedColumn> get $columns => [id, key, value, updatedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'app_settings';
  @override
  VerificationContext validateIntegrity(
      Insertable<AppSettingsTableData> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('key')) {
      context.handle(
          _keyMeta, key.isAcceptableOrUnknown(data['key']!, _keyMeta));
    } else if (isInserting) {
      context.missing(_keyMeta);
    }
    if (data.containsKey('value')) {
      context.handle(
          _valueMeta, value.isAcceptableOrUnknown(data['value']!, _valueMeta));
    } else if (isInserting) {
      context.missing(_valueMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(_updatedAtMeta,
          updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  AppSettingsTableData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return AppSettingsTableData(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      key: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}key'])!,
      value: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}value'])!,
      updatedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}updated_at'])!,
    );
  }

  @override
  $AppSettingsTableTable createAlias(String alias) {
    return $AppSettingsTableTable(attachedDatabase, alias);
  }
}

class AppSettingsTableData extends DataClass
    implements Insertable<AppSettingsTableData> {
  final int id;

  /// The settings key identifier.
  final String key;

  /// The settings value serialised as a string.
  final String value;
  final DateTime updatedAt;
  const AppSettingsTableData(
      {required this.id,
      required this.key,
      required this.value,
      required this.updatedAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['key'] = Variable<String>(key);
    map['value'] = Variable<String>(value);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  AppSettingsTableCompanion toCompanion(bool nullToAbsent) {
    return AppSettingsTableCompanion(
      id: Value(id),
      key: Value(key),
      value: Value(value),
      updatedAt: Value(updatedAt),
    );
  }

  factory AppSettingsTableData.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return AppSettingsTableData(
      id: serializer.fromJson<int>(json['id']),
      key: serializer.fromJson<String>(json['key']),
      value: serializer.fromJson<String>(json['value']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'key': serializer.toJson<String>(key),
      'value': serializer.toJson<String>(value),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  AppSettingsTableData copyWith(
          {int? id, String? key, String? value, DateTime? updatedAt}) =>
      AppSettingsTableData(
        id: id ?? this.id,
        key: key ?? this.key,
        value: value ?? this.value,
        updatedAt: updatedAt ?? this.updatedAt,
      );
  AppSettingsTableData copyWithCompanion(AppSettingsTableCompanion data) {
    return AppSettingsTableData(
      id: data.id.present ? data.id.value : this.id,
      key: data.key.present ? data.key.value : this.key,
      value: data.value.present ? data.value.value : this.value,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('AppSettingsTableData(')
          ..write('id: $id, ')
          ..write('key: $key, ')
          ..write('value: $value, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, key, value, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AppSettingsTableData &&
          other.id == this.id &&
          other.key == this.key &&
          other.value == this.value &&
          other.updatedAt == this.updatedAt);
}

class AppSettingsTableCompanion extends UpdateCompanion<AppSettingsTableData> {
  final Value<int> id;
  final Value<String> key;
  final Value<String> value;
  final Value<DateTime> updatedAt;
  const AppSettingsTableCompanion({
    this.id = const Value.absent(),
    this.key = const Value.absent(),
    this.value = const Value.absent(),
    this.updatedAt = const Value.absent(),
  });
  AppSettingsTableCompanion.insert({
    this.id = const Value.absent(),
    required String key,
    required String value,
    this.updatedAt = const Value.absent(),
  })  : key = Value(key),
        value = Value(value);
  static Insertable<AppSettingsTableData> custom({
    Expression<int>? id,
    Expression<String>? key,
    Expression<String>? value,
    Expression<DateTime>? updatedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (key != null) 'key': key,
      if (value != null) 'value': value,
      if (updatedAt != null) 'updated_at': updatedAt,
    });
  }

  AppSettingsTableCompanion copyWith(
      {Value<int>? id,
      Value<String>? key,
      Value<String>? value,
      Value<DateTime>? updatedAt}) {
    return AppSettingsTableCompanion(
      id: id ?? this.id,
      key: key ?? this.key,
      value: value ?? this.value,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (key.present) {
      map['key'] = Variable<String>(key.value);
    }
    if (value.present) {
      map['value'] = Variable<String>(value.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AppSettingsTableCompanion(')
          ..write('id: $id, ')
          ..write('key: $key, ')
          ..write('value: $value, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $PlansTableTable plansTable = $PlansTableTable(this);
  late final $TtsCacheTableTable ttsCacheTable = $TtsCacheTableTable(this);
  late final $ExecutionStateTableTable executionStateTable =
      $ExecutionStateTableTable(this);
  late final $AppSettingsTableTable appSettingsTable =
      $AppSettingsTableTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities =>
      [plansTable, ttsCacheTable, executionStateTable, appSettingsTable];
  @override
  StreamQueryUpdateRules get streamUpdateRules => const StreamQueryUpdateRules(
        [
          WritePropagation(
            on: TableUpdateQuery.onTableName('plans',
                limitUpdateKind: UpdateKind.delete),
            result: [
              TableUpdate('tts_cache', kind: UpdateKind.update),
            ],
          ),
          WritePropagation(
            on: TableUpdateQuery.onTableName('plans',
                limitUpdateKind: UpdateKind.delete),
            result: [
              TableUpdate('execution_state', kind: UpdateKind.delete),
            ],
          ),
        ],
      );
}

typedef $$PlansTableTableCreateCompanionBuilder = PlansTableCompanion Function({
  Value<int> id,
  required String name,
  Value<String?> description,
  Value<String> category,
  Value<List<String>> tags,
  Value<String> defaultVoice,
  Value<List<PlanStep>> steps,
  Value<DateTime> createdAt,
  Value<DateTime> updatedAt,
  Value<DateTime?> lastUsedAt,
});
typedef $$PlansTableTableUpdateCompanionBuilder = PlansTableCompanion Function({
  Value<int> id,
  Value<String> name,
  Value<String?> description,
  Value<String> category,
  Value<List<String>> tags,
  Value<String> defaultVoice,
  Value<List<PlanStep>> steps,
  Value<DateTime> createdAt,
  Value<DateTime> updatedAt,
  Value<DateTime?> lastUsedAt,
});

final class $$PlansTableTableReferences
    extends BaseReferences<_$AppDatabase, $PlansTableTable, PlansTableData> {
  $$PlansTableTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$TtsCacheTableTable, List<TtsCacheTableData>>
      _ttsCacheTableRefsTable(_$AppDatabase db) =>
          MultiTypedResultKey.fromTable(db.ttsCacheTable,
              aliasName: $_aliasNameGenerator(
                  db.plansTable.id, db.ttsCacheTable.planId));

  $$TtsCacheTableTableProcessedTableManager get ttsCacheTableRefs {
    final manager = $$TtsCacheTableTableTableManager($_db, $_db.ttsCacheTable)
        .filter((f) => f.planId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_ttsCacheTableRefsTable($_db));
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: cache));
  }

  static MultiTypedResultKey<$ExecutionStateTableTable,
      List<ExecutionStateTableData>> _executionStateTableRefsTable(
          _$AppDatabase db) =>
      MultiTypedResultKey.fromTable(db.executionStateTable,
          aliasName: $_aliasNameGenerator(
              db.plansTable.id, db.executionStateTable.planId));

  $$ExecutionStateTableTableProcessedTableManager get executionStateTableRefs {
    final manager =
        $$ExecutionStateTableTableTableManager($_db, $_db.executionStateTable)
            .filter((f) => f.planId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache =
        $_typedResult.readTableOrNull(_executionStateTableRefsTable($_db));
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: cache));
  }
}

class $$PlansTableTableFilterComposer
    extends Composer<_$AppDatabase, $PlansTableTable> {
  $$PlansTableTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get name => $composableBuilder(
      column: $table.name, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get description => $composableBuilder(
      column: $table.description, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get category => $composableBuilder(
      column: $table.category, builder: (column) => ColumnFilters(column));

  ColumnWithTypeConverterFilters<List<String>, List<String>, String> get tags =>
      $composableBuilder(
          column: $table.tags,
          builder: (column) => ColumnWithTypeConverterFilters(column));

  ColumnFilters<String> get defaultVoice => $composableBuilder(
      column: $table.defaultVoice, builder: (column) => ColumnFilters(column));

  ColumnWithTypeConverterFilters<List<PlanStep>, List<PlanStep>, String>
      get steps => $composableBuilder(
          column: $table.steps,
          builder: (column) => ColumnWithTypeConverterFilters(column));

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get lastUsedAt => $composableBuilder(
      column: $table.lastUsedAt, builder: (column) => ColumnFilters(column));

  Expression<bool> ttsCacheTableRefs(
      Expression<bool> Function($$TtsCacheTableTableFilterComposer f) f) {
    final $$TtsCacheTableTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.id,
        referencedTable: $db.ttsCacheTable,
        getReferencedColumn: (t) => t.planId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$TtsCacheTableTableFilterComposer(
              $db: $db,
              $table: $db.ttsCacheTable,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return f(composer);
  }

  Expression<bool> executionStateTableRefs(
      Expression<bool> Function($$ExecutionStateTableTableFilterComposer f) f) {
    final $$ExecutionStateTableTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.id,
        referencedTable: $db.executionStateTable,
        getReferencedColumn: (t) => t.planId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$ExecutionStateTableTableFilterComposer(
              $db: $db,
              $table: $db.executionStateTable,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return f(composer);
  }
}

class $$PlansTableTableOrderingComposer
    extends Composer<_$AppDatabase, $PlansTableTable> {
  $$PlansTableTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get name => $composableBuilder(
      column: $table.name, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get description => $composableBuilder(
      column: $table.description, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get category => $composableBuilder(
      column: $table.category, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get tags => $composableBuilder(
      column: $table.tags, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get defaultVoice => $composableBuilder(
      column: $table.defaultVoice,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get steps => $composableBuilder(
      column: $table.steps, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get lastUsedAt => $composableBuilder(
      column: $table.lastUsedAt, builder: (column) => ColumnOrderings(column));
}

class $$PlansTableTableAnnotationComposer
    extends Composer<_$AppDatabase, $PlansTableTable> {
  $$PlansTableTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get description => $composableBuilder(
      column: $table.description, builder: (column) => column);

  GeneratedColumn<String> get category =>
      $composableBuilder(column: $table.category, builder: (column) => column);

  GeneratedColumnWithTypeConverter<List<String>, String> get tags =>
      $composableBuilder(column: $table.tags, builder: (column) => column);

  GeneratedColumn<String> get defaultVoice => $composableBuilder(
      column: $table.defaultVoice, builder: (column) => column);

  GeneratedColumnWithTypeConverter<List<PlanStep>, String> get steps =>
      $composableBuilder(column: $table.steps, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get lastUsedAt => $composableBuilder(
      column: $table.lastUsedAt, builder: (column) => column);

  Expression<T> ttsCacheTableRefs<T extends Object>(
      Expression<T> Function($$TtsCacheTableTableAnnotationComposer a) f) {
    final $$TtsCacheTableTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.id,
        referencedTable: $db.ttsCacheTable,
        getReferencedColumn: (t) => t.planId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$TtsCacheTableTableAnnotationComposer(
              $db: $db,
              $table: $db.ttsCacheTable,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return f(composer);
  }

  Expression<T> executionStateTableRefs<T extends Object>(
      Expression<T> Function($$ExecutionStateTableTableAnnotationComposer a)
          f) {
    final $$ExecutionStateTableTableAnnotationComposer composer =
        $composerBuilder(
            composer: this,
            getCurrentColumn: (t) => t.id,
            referencedTable: $db.executionStateTable,
            getReferencedColumn: (t) => t.planId,
            builder: (joinBuilder,
                    {$addJoinBuilderToRootComposer,
                    $removeJoinBuilderFromRootComposer}) =>
                $$ExecutionStateTableTableAnnotationComposer(
                  $db: $db,
                  $table: $db.executionStateTable,
                  $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                  joinBuilder: joinBuilder,
                  $removeJoinBuilderFromRootComposer:
                      $removeJoinBuilderFromRootComposer,
                ));
    return f(composer);
  }
}

class $$PlansTableTableTableManager extends RootTableManager<
    _$AppDatabase,
    $PlansTableTable,
    PlansTableData,
    $$PlansTableTableFilterComposer,
    $$PlansTableTableOrderingComposer,
    $$PlansTableTableAnnotationComposer,
    $$PlansTableTableCreateCompanionBuilder,
    $$PlansTableTableUpdateCompanionBuilder,
    (PlansTableData, $$PlansTableTableReferences),
    PlansTableData,
    PrefetchHooks Function(
        {bool ttsCacheTableRefs, bool executionStateTableRefs})> {
  $$PlansTableTableTableManager(_$AppDatabase db, $PlansTableTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PlansTableTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PlansTableTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PlansTableTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<String> name = const Value.absent(),
            Value<String?> description = const Value.absent(),
            Value<String> category = const Value.absent(),
            Value<List<String>> tags = const Value.absent(),
            Value<String> defaultVoice = const Value.absent(),
            Value<List<PlanStep>> steps = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
            Value<DateTime> updatedAt = const Value.absent(),
            Value<DateTime?> lastUsedAt = const Value.absent(),
          }) =>
              PlansTableCompanion(
            id: id,
            name: name,
            description: description,
            category: category,
            tags: tags,
            defaultVoice: defaultVoice,
            steps: steps,
            createdAt: createdAt,
            updatedAt: updatedAt,
            lastUsedAt: lastUsedAt,
          ),
          createCompanionCallback: ({
            Value<int> id = const Value.absent(),
            required String name,
            Value<String?> description = const Value.absent(),
            Value<String> category = const Value.absent(),
            Value<List<String>> tags = const Value.absent(),
            Value<String> defaultVoice = const Value.absent(),
            Value<List<PlanStep>> steps = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
            Value<DateTime> updatedAt = const Value.absent(),
            Value<DateTime?> lastUsedAt = const Value.absent(),
          }) =>
              PlansTableCompanion.insert(
            id: id,
            name: name,
            description: description,
            category: category,
            tags: tags,
            defaultVoice: defaultVoice,
            steps: steps,
            createdAt: createdAt,
            updatedAt: updatedAt,
            lastUsedAt: lastUsedAt,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (
                    e.readTable(table),
                    $$PlansTableTableReferences(db, table, e)
                  ))
              .toList(),
          prefetchHooksCallback: (
              {ttsCacheTableRefs = false, executionStateTableRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [
                if (ttsCacheTableRefs) db.ttsCacheTable,
                if (executionStateTableRefs) db.executionStateTable
              ],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (ttsCacheTableRefs)
                    await $_getPrefetchedData<PlansTableData, $PlansTableTable,
                            TtsCacheTableData>(
                        currentTable: table,
                        referencedTable: $$PlansTableTableReferences
                            ._ttsCacheTableRefsTable(db),
                        managerFromTypedResult: (p0) =>
                            $$PlansTableTableReferences(db, table, p0)
                                .ttsCacheTableRefs,
                        referencedItemsForCurrentItem: (item,
                                referencedItems) =>
                            referencedItems.where((e) => e.planId == item.id),
                        typedResults: items),
                  if (executionStateTableRefs)
                    await $_getPrefetchedData<PlansTableData, $PlansTableTable,
                            ExecutionStateTableData>(
                        currentTable: table,
                        referencedTable: $$PlansTableTableReferences
                            ._executionStateTableRefsTable(db),
                        managerFromTypedResult: (p0) =>
                            $$PlansTableTableReferences(db, table, p0)
                                .executionStateTableRefs,
                        referencedItemsForCurrentItem: (item,
                                referencedItems) =>
                            referencedItems.where((e) => e.planId == item.id),
                        typedResults: items)
                ];
              },
            );
          },
        ));
}

typedef $$PlansTableTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $PlansTableTable,
    PlansTableData,
    $$PlansTableTableFilterComposer,
    $$PlansTableTableOrderingComposer,
    $$PlansTableTableAnnotationComposer,
    $$PlansTableTableCreateCompanionBuilder,
    $$PlansTableTableUpdateCompanionBuilder,
    (PlansTableData, $$PlansTableTableReferences),
    PlansTableData,
    PrefetchHooks Function(
        {bool ttsCacheTableRefs, bool executionStateTableRefs})>;
typedef $$TtsCacheTableTableCreateCompanionBuilder = TtsCacheTableCompanion
    Function({
  Value<int> id,
  required String textHash,
  required String voiceId,
  required String filePath,
  Value<int> fileSizeBytes,
  Value<int?> planId,
  Value<DateTime> createdAt,
});
typedef $$TtsCacheTableTableUpdateCompanionBuilder = TtsCacheTableCompanion
    Function({
  Value<int> id,
  Value<String> textHash,
  Value<String> voiceId,
  Value<String> filePath,
  Value<int> fileSizeBytes,
  Value<int?> planId,
  Value<DateTime> createdAt,
});

final class $$TtsCacheTableTableReferences extends BaseReferences<_$AppDatabase,
    $TtsCacheTableTable, TtsCacheTableData> {
  $$TtsCacheTableTableReferences(
      super.$_db, super.$_table, super.$_typedResult);

  static $PlansTableTable _planIdTable(_$AppDatabase db) =>
      db.plansTable.createAlias(
          $_aliasNameGenerator(db.ttsCacheTable.planId, db.plansTable.id));

  $$PlansTableTableProcessedTableManager? get planId {
    final $_column = $_itemColumn<int>('plan_id');
    if ($_column == null) return null;
    final manager = $$PlansTableTableTableManager($_db, $_db.plansTable)
        .filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_planIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: [item]));
  }
}

class $$TtsCacheTableTableFilterComposer
    extends Composer<_$AppDatabase, $TtsCacheTableTable> {
  $$TtsCacheTableTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get textHash => $composableBuilder(
      column: $table.textHash, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get voiceId => $composableBuilder(
      column: $table.voiceId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get filePath => $composableBuilder(
      column: $table.filePath, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get fileSizeBytes => $composableBuilder(
      column: $table.fileSizeBytes, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnFilters(column));

  $$PlansTableTableFilterComposer get planId {
    final $$PlansTableTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.planId,
        referencedTable: $db.plansTable,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$PlansTableTableFilterComposer(
              $db: $db,
              $table: $db.plansTable,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$TtsCacheTableTableOrderingComposer
    extends Composer<_$AppDatabase, $TtsCacheTableTable> {
  $$TtsCacheTableTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get textHash => $composableBuilder(
      column: $table.textHash, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get voiceId => $composableBuilder(
      column: $table.voiceId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get filePath => $composableBuilder(
      column: $table.filePath, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get fileSizeBytes => $composableBuilder(
      column: $table.fileSizeBytes,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnOrderings(column));

  $$PlansTableTableOrderingComposer get planId {
    final $$PlansTableTableOrderingComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.planId,
        referencedTable: $db.plansTable,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$PlansTableTableOrderingComposer(
              $db: $db,
              $table: $db.plansTable,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$TtsCacheTableTableAnnotationComposer
    extends Composer<_$AppDatabase, $TtsCacheTableTable> {
  $$TtsCacheTableTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get textHash =>
      $composableBuilder(column: $table.textHash, builder: (column) => column);

  GeneratedColumn<String> get voiceId =>
      $composableBuilder(column: $table.voiceId, builder: (column) => column);

  GeneratedColumn<String> get filePath =>
      $composableBuilder(column: $table.filePath, builder: (column) => column);

  GeneratedColumn<int> get fileSizeBytes => $composableBuilder(
      column: $table.fileSizeBytes, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  $$PlansTableTableAnnotationComposer get planId {
    final $$PlansTableTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.planId,
        referencedTable: $db.plansTable,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$PlansTableTableAnnotationComposer(
              $db: $db,
              $table: $db.plansTable,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$TtsCacheTableTableTableManager extends RootTableManager<
    _$AppDatabase,
    $TtsCacheTableTable,
    TtsCacheTableData,
    $$TtsCacheTableTableFilterComposer,
    $$TtsCacheTableTableOrderingComposer,
    $$TtsCacheTableTableAnnotationComposer,
    $$TtsCacheTableTableCreateCompanionBuilder,
    $$TtsCacheTableTableUpdateCompanionBuilder,
    (TtsCacheTableData, $$TtsCacheTableTableReferences),
    TtsCacheTableData,
    PrefetchHooks Function({bool planId})> {
  $$TtsCacheTableTableTableManager(_$AppDatabase db, $TtsCacheTableTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$TtsCacheTableTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$TtsCacheTableTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$TtsCacheTableTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<String> textHash = const Value.absent(),
            Value<String> voiceId = const Value.absent(),
            Value<String> filePath = const Value.absent(),
            Value<int> fileSizeBytes = const Value.absent(),
            Value<int?> planId = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
          }) =>
              TtsCacheTableCompanion(
            id: id,
            textHash: textHash,
            voiceId: voiceId,
            filePath: filePath,
            fileSizeBytes: fileSizeBytes,
            planId: planId,
            createdAt: createdAt,
          ),
          createCompanionCallback: ({
            Value<int> id = const Value.absent(),
            required String textHash,
            required String voiceId,
            required String filePath,
            Value<int> fileSizeBytes = const Value.absent(),
            Value<int?> planId = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
          }) =>
              TtsCacheTableCompanion.insert(
            id: id,
            textHash: textHash,
            voiceId: voiceId,
            filePath: filePath,
            fileSizeBytes: fileSizeBytes,
            planId: planId,
            createdAt: createdAt,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (
                    e.readTable(table),
                    $$TtsCacheTableTableReferences(db, table, e)
                  ))
              .toList(),
          prefetchHooksCallback: ({planId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins: <
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
                      dynamic>>(state) {
                if (planId) {
                  state = state.withJoin(
                    currentTable: table,
                    currentColumn: table.planId,
                    referencedTable:
                        $$TtsCacheTableTableReferences._planIdTable(db),
                    referencedColumn:
                        $$TtsCacheTableTableReferences._planIdTable(db).id,
                  ) as T;
                }

                return state;
              },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ));
}

typedef $$TtsCacheTableTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $TtsCacheTableTable,
    TtsCacheTableData,
    $$TtsCacheTableTableFilterComposer,
    $$TtsCacheTableTableOrderingComposer,
    $$TtsCacheTableTableAnnotationComposer,
    $$TtsCacheTableTableCreateCompanionBuilder,
    $$TtsCacheTableTableUpdateCompanionBuilder,
    (TtsCacheTableData, $$TtsCacheTableTableReferences),
    TtsCacheTableData,
    PrefetchHooks Function({bool planId})>;
typedef $$ExecutionStateTableTableCreateCompanionBuilder
    = ExecutionStateTableCompanion Function({
  Value<int> id,
  required int planId,
  Value<int> currentStepIndex,
  Value<String> repeatCounters,
  Value<int> elapsedMs,
  Value<int> ambientPositionMs,
  Value<String> status,
  Value<DateTime> savedAt,
});
typedef $$ExecutionStateTableTableUpdateCompanionBuilder
    = ExecutionStateTableCompanion Function({
  Value<int> id,
  Value<int> planId,
  Value<int> currentStepIndex,
  Value<String> repeatCounters,
  Value<int> elapsedMs,
  Value<int> ambientPositionMs,
  Value<String> status,
  Value<DateTime> savedAt,
});

final class $$ExecutionStateTableTableReferences extends BaseReferences<
    _$AppDatabase, $ExecutionStateTableTable, ExecutionStateTableData> {
  $$ExecutionStateTableTableReferences(
      super.$_db, super.$_table, super.$_typedResult);

  static $PlansTableTable _planIdTable(_$AppDatabase db) =>
      db.plansTable.createAlias($_aliasNameGenerator(
          db.executionStateTable.planId, db.plansTable.id));

  $$PlansTableTableProcessedTableManager get planId {
    final $_column = $_itemColumn<int>('plan_id')!;

    final manager = $$PlansTableTableTableManager($_db, $_db.plansTable)
        .filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_planIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: [item]));
  }
}

class $$ExecutionStateTableTableFilterComposer
    extends Composer<_$AppDatabase, $ExecutionStateTableTable> {
  $$ExecutionStateTableTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get currentStepIndex => $composableBuilder(
      column: $table.currentStepIndex,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get repeatCounters => $composableBuilder(
      column: $table.repeatCounters,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get elapsedMs => $composableBuilder(
      column: $table.elapsedMs, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get ambientPositionMs => $composableBuilder(
      column: $table.ambientPositionMs,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get status => $composableBuilder(
      column: $table.status, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get savedAt => $composableBuilder(
      column: $table.savedAt, builder: (column) => ColumnFilters(column));

  $$PlansTableTableFilterComposer get planId {
    final $$PlansTableTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.planId,
        referencedTable: $db.plansTable,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$PlansTableTableFilterComposer(
              $db: $db,
              $table: $db.plansTable,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$ExecutionStateTableTableOrderingComposer
    extends Composer<_$AppDatabase, $ExecutionStateTableTable> {
  $$ExecutionStateTableTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get currentStepIndex => $composableBuilder(
      column: $table.currentStepIndex,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get repeatCounters => $composableBuilder(
      column: $table.repeatCounters,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get elapsedMs => $composableBuilder(
      column: $table.elapsedMs, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get ambientPositionMs => $composableBuilder(
      column: $table.ambientPositionMs,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get status => $composableBuilder(
      column: $table.status, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get savedAt => $composableBuilder(
      column: $table.savedAt, builder: (column) => ColumnOrderings(column));

  $$PlansTableTableOrderingComposer get planId {
    final $$PlansTableTableOrderingComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.planId,
        referencedTable: $db.plansTable,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$PlansTableTableOrderingComposer(
              $db: $db,
              $table: $db.plansTable,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$ExecutionStateTableTableAnnotationComposer
    extends Composer<_$AppDatabase, $ExecutionStateTableTable> {
  $$ExecutionStateTableTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get currentStepIndex => $composableBuilder(
      column: $table.currentStepIndex, builder: (column) => column);

  GeneratedColumn<String> get repeatCounters => $composableBuilder(
      column: $table.repeatCounters, builder: (column) => column);

  GeneratedColumn<int> get elapsedMs =>
      $composableBuilder(column: $table.elapsedMs, builder: (column) => column);

  GeneratedColumn<int> get ambientPositionMs => $composableBuilder(
      column: $table.ambientPositionMs, builder: (column) => column);

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<DateTime> get savedAt =>
      $composableBuilder(column: $table.savedAt, builder: (column) => column);

  $$PlansTableTableAnnotationComposer get planId {
    final $$PlansTableTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.planId,
        referencedTable: $db.plansTable,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$PlansTableTableAnnotationComposer(
              $db: $db,
              $table: $db.plansTable,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$ExecutionStateTableTableTableManager extends RootTableManager<
    _$AppDatabase,
    $ExecutionStateTableTable,
    ExecutionStateTableData,
    $$ExecutionStateTableTableFilterComposer,
    $$ExecutionStateTableTableOrderingComposer,
    $$ExecutionStateTableTableAnnotationComposer,
    $$ExecutionStateTableTableCreateCompanionBuilder,
    $$ExecutionStateTableTableUpdateCompanionBuilder,
    (ExecutionStateTableData, $$ExecutionStateTableTableReferences),
    ExecutionStateTableData,
    PrefetchHooks Function({bool planId})> {
  $$ExecutionStateTableTableTableManager(
      _$AppDatabase db, $ExecutionStateTableTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ExecutionStateTableTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ExecutionStateTableTableOrderingComposer(
                  $db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ExecutionStateTableTableAnnotationComposer(
                  $db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<int> planId = const Value.absent(),
            Value<int> currentStepIndex = const Value.absent(),
            Value<String> repeatCounters = const Value.absent(),
            Value<int> elapsedMs = const Value.absent(),
            Value<int> ambientPositionMs = const Value.absent(),
            Value<String> status = const Value.absent(),
            Value<DateTime> savedAt = const Value.absent(),
          }) =>
              ExecutionStateTableCompanion(
            id: id,
            planId: planId,
            currentStepIndex: currentStepIndex,
            repeatCounters: repeatCounters,
            elapsedMs: elapsedMs,
            ambientPositionMs: ambientPositionMs,
            status: status,
            savedAt: savedAt,
          ),
          createCompanionCallback: ({
            Value<int> id = const Value.absent(),
            required int planId,
            Value<int> currentStepIndex = const Value.absent(),
            Value<String> repeatCounters = const Value.absent(),
            Value<int> elapsedMs = const Value.absent(),
            Value<int> ambientPositionMs = const Value.absent(),
            Value<String> status = const Value.absent(),
            Value<DateTime> savedAt = const Value.absent(),
          }) =>
              ExecutionStateTableCompanion.insert(
            id: id,
            planId: planId,
            currentStepIndex: currentStepIndex,
            repeatCounters: repeatCounters,
            elapsedMs: elapsedMs,
            ambientPositionMs: ambientPositionMs,
            status: status,
            savedAt: savedAt,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (
                    e.readTable(table),
                    $$ExecutionStateTableTableReferences(db, table, e)
                  ))
              .toList(),
          prefetchHooksCallback: ({planId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins: <
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
                      dynamic>>(state) {
                if (planId) {
                  state = state.withJoin(
                    currentTable: table,
                    currentColumn: table.planId,
                    referencedTable:
                        $$ExecutionStateTableTableReferences._planIdTable(db),
                    referencedColumn: $$ExecutionStateTableTableReferences
                        ._planIdTable(db)
                        .id,
                  ) as T;
                }

                return state;
              },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ));
}

typedef $$ExecutionStateTableTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $ExecutionStateTableTable,
    ExecutionStateTableData,
    $$ExecutionStateTableTableFilterComposer,
    $$ExecutionStateTableTableOrderingComposer,
    $$ExecutionStateTableTableAnnotationComposer,
    $$ExecutionStateTableTableCreateCompanionBuilder,
    $$ExecutionStateTableTableUpdateCompanionBuilder,
    (ExecutionStateTableData, $$ExecutionStateTableTableReferences),
    ExecutionStateTableData,
    PrefetchHooks Function({bool planId})>;
typedef $$AppSettingsTableTableCreateCompanionBuilder
    = AppSettingsTableCompanion Function({
  Value<int> id,
  required String key,
  required String value,
  Value<DateTime> updatedAt,
});
typedef $$AppSettingsTableTableUpdateCompanionBuilder
    = AppSettingsTableCompanion Function({
  Value<int> id,
  Value<String> key,
  Value<String> value,
  Value<DateTime> updatedAt,
});

class $$AppSettingsTableTableFilterComposer
    extends Composer<_$AppDatabase, $AppSettingsTableTable> {
  $$AppSettingsTableTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get key => $composableBuilder(
      column: $table.key, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get value => $composableBuilder(
      column: $table.value, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnFilters(column));
}

class $$AppSettingsTableTableOrderingComposer
    extends Composer<_$AppDatabase, $AppSettingsTableTable> {
  $$AppSettingsTableTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get key => $composableBuilder(
      column: $table.key, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get value => $composableBuilder(
      column: $table.value, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnOrderings(column));
}

class $$AppSettingsTableTableAnnotationComposer
    extends Composer<_$AppDatabase, $AppSettingsTableTable> {
  $$AppSettingsTableTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get key =>
      $composableBuilder(column: $table.key, builder: (column) => column);

  GeneratedColumn<String> get value =>
      $composableBuilder(column: $table.value, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$AppSettingsTableTableTableManager extends RootTableManager<
    _$AppDatabase,
    $AppSettingsTableTable,
    AppSettingsTableData,
    $$AppSettingsTableTableFilterComposer,
    $$AppSettingsTableTableOrderingComposer,
    $$AppSettingsTableTableAnnotationComposer,
    $$AppSettingsTableTableCreateCompanionBuilder,
    $$AppSettingsTableTableUpdateCompanionBuilder,
    (
      AppSettingsTableData,
      BaseReferences<_$AppDatabase, $AppSettingsTableTable,
          AppSettingsTableData>
    ),
    AppSettingsTableData,
    PrefetchHooks Function()> {
  $$AppSettingsTableTableTableManager(
      _$AppDatabase db, $AppSettingsTableTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$AppSettingsTableTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$AppSettingsTableTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$AppSettingsTableTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<String> key = const Value.absent(),
            Value<String> value = const Value.absent(),
            Value<DateTime> updatedAt = const Value.absent(),
          }) =>
              AppSettingsTableCompanion(
            id: id,
            key: key,
            value: value,
            updatedAt: updatedAt,
          ),
          createCompanionCallback: ({
            Value<int> id = const Value.absent(),
            required String key,
            required String value,
            Value<DateTime> updatedAt = const Value.absent(),
          }) =>
              AppSettingsTableCompanion.insert(
            id: id,
            key: key,
            value: value,
            updatedAt: updatedAt,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$AppSettingsTableTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $AppSettingsTableTable,
    AppSettingsTableData,
    $$AppSettingsTableTableFilterComposer,
    $$AppSettingsTableTableOrderingComposer,
    $$AppSettingsTableTableAnnotationComposer,
    $$AppSettingsTableTableCreateCompanionBuilder,
    $$AppSettingsTableTableUpdateCompanionBuilder,
    (
      AppSettingsTableData,
      BaseReferences<_$AppDatabase, $AppSettingsTableTable,
          AppSettingsTableData>
    ),
    AppSettingsTableData,
    PrefetchHooks Function()>;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$PlansTableTableTableManager get plansTable =>
      $$PlansTableTableTableManager(_db, _db.plansTable);
  $$TtsCacheTableTableTableManager get ttsCacheTable =>
      $$TtsCacheTableTableTableManager(_db, _db.ttsCacheTable);
  $$ExecutionStateTableTableTableManager get executionStateTable =>
      $$ExecutionStateTableTableTableManager(_db, _db.executionStateTable);
  $$AppSettingsTableTableTableManager get appSettingsTable =>
      $$AppSettingsTableTableTableManager(_db, _db.appSettingsTable);
}

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$appDatabaseHash() => r'8c69eb46d45206533c176c88a926608e79ca927d';

/// Riverpod provider that exposes the singleton [AppDatabase].
///
/// [keepAlive: true] ensures the database is never garbage-collected while
/// the app is running.
///
/// Copied from [appDatabase].
@ProviderFor(appDatabase)
final appDatabaseProvider = Provider<AppDatabase>.internal(
  appDatabase,
  name: r'appDatabaseProvider',
  debugGetCreateSourceHash:
      const bool.fromEnvironment('dart.vm.product') ? null : _$appDatabaseHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef AppDatabaseRef = ProviderRef<AppDatabase>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
