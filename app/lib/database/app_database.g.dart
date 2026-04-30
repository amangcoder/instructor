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
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
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
  @override
  late final GeneratedColumnWithTypeConverter<PlanCategory, String> category =
      GeneratedColumn<String>('category', aliasedName, false,
              type: DriftSqlType.string,
              requiredDuringInsert: false,
              defaultValue: const Constant('custom'))
          .withConverter<PlanCategory>($PlansTableTable.$convertercategory);
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
      defaultValue: const Constant('aoede'));
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
  static const VerificationMeta _isActiveMeta =
      const VerificationMeta('isActive');
  @override
  late final GeneratedColumn<bool> isActive = GeneratedColumn<bool>(
      'is_active', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('CHECK ("is_active" IN (0, 1))'),
      defaultValue: const Constant(false));
  @override
  late final GeneratedColumnWithTypeConverter<String, String> ttsStatus =
      GeneratedColumn<String>('tts_status', aliasedName, false,
              type: DriftSqlType.string,
              requiredDuringInsert: false,
              defaultValue: const Constant('none'))
          .withConverter<String>($PlansTableTable.$converterttsStatus);
  static const VerificationMeta _ttsTotalMeta =
      const VerificationMeta('ttsTotal');
  @override
  late final GeneratedColumn<int> ttsTotal = GeneratedColumn<int>(
      'tts_total', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
  static const VerificationMeta _ttsCompletedMeta =
      const VerificationMeta('ttsCompleted');
  @override
  late final GeneratedColumn<int> ttsCompleted = GeneratedColumn<int>(
      'tts_completed', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
  static const VerificationMeta _libraryIdMeta =
      const VerificationMeta('libraryId');
  @override
  late final GeneratedColumn<String> libraryId = GeneratedColumn<String>(
      'library_id', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
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
        lastUsedAt,
        isActive,
        ttsStatus,
        ttsTotal,
        ttsCompleted,
        libraryId
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
    } else if (isInserting) {
      context.missing(_idMeta);
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
    if (data.containsKey('is_active')) {
      context.handle(_isActiveMeta,
          isActive.isAcceptableOrUnknown(data['is_active']!, _isActiveMeta));
    }
    if (data.containsKey('tts_total')) {
      context.handle(_ttsTotalMeta,
          ttsTotal.isAcceptableOrUnknown(data['tts_total']!, _ttsTotalMeta));
    }
    if (data.containsKey('tts_completed')) {
      context.handle(
          _ttsCompletedMeta,
          ttsCompleted.isAcceptableOrUnknown(
              data['tts_completed']!, _ttsCompletedMeta));
    }
    if (data.containsKey('library_id')) {
      context.handle(_libraryIdMeta,
          libraryId.isAcceptableOrUnknown(data['library_id']!, _libraryIdMeta));
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
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      name: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}name'])!,
      description: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}description']),
      category: $PlansTableTable.$convertercategory.fromSql(attachedDatabase
          .typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}category'])!),
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
      isActive: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}is_active'])!,
      ttsStatus: $PlansTableTable.$converterttsStatus.fromSql(attachedDatabase
          .typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}tts_status'])!),
      ttsTotal: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}tts_total'])!,
      ttsCompleted: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}tts_completed'])!,
      libraryId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}library_id']),
    );
  }

  @override
  $PlansTableTable createAlias(String alias) {
    return $PlansTableTable(attachedDatabase, alias);
  }

  static TypeConverter<PlanCategory, String> $convertercategory =
      const PlanCategoryConverter();
  static TypeConverter<List<String>, String> $convertertags =
      const StringListConverter();
  static TypeConverter<List<PlanStep>, String> $convertersteps =
      const StepListConverter();
  static TypeConverter<String, String> $converterttsStatus =
      const TtsStatusConverter();
}

class PlansTableData extends DataClass implements Insertable<PlansTableData> {
  /// Server-assigned UUID primary key.
  final String id;
  final String name;
  final String? description;

  /// [PlanCategory] stored as its string name, validated by [PlanCategoryConverter].
  final PlanCategory category;

  /// JSON array of tag strings.
  final List<String> tags;

  /// Voice identifier string (OpenAI voice name or 'platform').
  final String defaultVoice;

  /// JSON-encoded list of [PlanStep] objects.
  final List<PlanStep> steps;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? lastUsedAt;

  /// Whether this plan has been activated for GenAI TTS generation.
  final bool isActive;

  /// TTS generation status: 'none', 'pending', 'processing', 'completed', 'failed'.
  /// Validated by [TtsStatusConverter] — throws [StateError] for unknown values.
  final String ttsStatus;

  /// Total number of TTS audio files to generate for this plan.
  final int ttsTotal;

  /// Number of TTS audio files successfully generated so far.
  final int ttsCompleted;

  /// The library plan ID this plan was cloned from, if any.
  ///
  /// Set when the user adds a plan from the Discover tab. Used to prevent
  /// duplicate additions: a library plan can only be added once.
  final String? libraryId;
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
      this.lastUsedAt,
      required this.isActive,
      required this.ttsStatus,
      required this.ttsTotal,
      required this.ttsCompleted,
      this.libraryId});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['name'] = Variable<String>(name);
    if (!nullToAbsent || description != null) {
      map['description'] = Variable<String>(description);
    }
    {
      map['category'] =
          Variable<String>($PlansTableTable.$convertercategory.toSql(category));
    }
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
    map['is_active'] = Variable<bool>(isActive);
    {
      map['tts_status'] = Variable<String>(
          $PlansTableTable.$converterttsStatus.toSql(ttsStatus));
    }
    map['tts_total'] = Variable<int>(ttsTotal);
    map['tts_completed'] = Variable<int>(ttsCompleted);
    if (!nullToAbsent || libraryId != null) {
      map['library_id'] = Variable<String>(libraryId);
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
      isActive: Value(isActive),
      ttsStatus: Value(ttsStatus),
      ttsTotal: Value(ttsTotal),
      ttsCompleted: Value(ttsCompleted),
      libraryId: libraryId == null && nullToAbsent
          ? const Value.absent()
          : Value(libraryId),
    );
  }

  factory PlansTableData.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PlansTableData(
      id: serializer.fromJson<String>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      description: serializer.fromJson<String?>(json['description']),
      category: serializer.fromJson<PlanCategory>(json['category']),
      tags: serializer.fromJson<List<String>>(json['tags']),
      defaultVoice: serializer.fromJson<String>(json['defaultVoice']),
      steps: serializer.fromJson<List<PlanStep>>(json['steps']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
      lastUsedAt: serializer.fromJson<DateTime?>(json['lastUsedAt']),
      isActive: serializer.fromJson<bool>(json['isActive']),
      ttsStatus: serializer.fromJson<String>(json['ttsStatus']),
      ttsTotal: serializer.fromJson<int>(json['ttsTotal']),
      ttsCompleted: serializer.fromJson<int>(json['ttsCompleted']),
      libraryId: serializer.fromJson<String?>(json['libraryId']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'name': serializer.toJson<String>(name),
      'description': serializer.toJson<String?>(description),
      'category': serializer.toJson<PlanCategory>(category),
      'tags': serializer.toJson<List<String>>(tags),
      'defaultVoice': serializer.toJson<String>(defaultVoice),
      'steps': serializer.toJson<List<PlanStep>>(steps),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
      'lastUsedAt': serializer.toJson<DateTime?>(lastUsedAt),
      'isActive': serializer.toJson<bool>(isActive),
      'ttsStatus': serializer.toJson<String>(ttsStatus),
      'ttsTotal': serializer.toJson<int>(ttsTotal),
      'ttsCompleted': serializer.toJson<int>(ttsCompleted),
      'libraryId': serializer.toJson<String?>(libraryId),
    };
  }

  PlansTableData copyWith(
          {String? id,
          String? name,
          Value<String?> description = const Value.absent(),
          PlanCategory? category,
          List<String>? tags,
          String? defaultVoice,
          List<PlanStep>? steps,
          DateTime? createdAt,
          DateTime? updatedAt,
          Value<DateTime?> lastUsedAt = const Value.absent(),
          bool? isActive,
          String? ttsStatus,
          int? ttsTotal,
          int? ttsCompleted,
          Value<String?> libraryId = const Value.absent()}) =>
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
        isActive: isActive ?? this.isActive,
        ttsStatus: ttsStatus ?? this.ttsStatus,
        ttsTotal: ttsTotal ?? this.ttsTotal,
        ttsCompleted: ttsCompleted ?? this.ttsCompleted,
        libraryId: libraryId.present ? libraryId.value : this.libraryId,
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
      isActive: data.isActive.present ? data.isActive.value : this.isActive,
      ttsStatus: data.ttsStatus.present ? data.ttsStatus.value : this.ttsStatus,
      ttsTotal: data.ttsTotal.present ? data.ttsTotal.value : this.ttsTotal,
      ttsCompleted: data.ttsCompleted.present
          ? data.ttsCompleted.value
          : this.ttsCompleted,
      libraryId: data.libraryId.present ? data.libraryId.value : this.libraryId,
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
          ..write('lastUsedAt: $lastUsedAt, ')
          ..write('isActive: $isActive, ')
          ..write('ttsStatus: $ttsStatus, ')
          ..write('ttsTotal: $ttsTotal, ')
          ..write('ttsCompleted: $ttsCompleted, ')
          ..write('libraryId: $libraryId')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
      id,
      name,
      description,
      category,
      tags,
      defaultVoice,
      steps,
      createdAt,
      updatedAt,
      lastUsedAt,
      isActive,
      ttsStatus,
      ttsTotal,
      ttsCompleted,
      libraryId);
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
          other.lastUsedAt == this.lastUsedAt &&
          other.isActive == this.isActive &&
          other.ttsStatus == this.ttsStatus &&
          other.ttsTotal == this.ttsTotal &&
          other.ttsCompleted == this.ttsCompleted &&
          other.libraryId == this.libraryId);
}

class PlansTableCompanion extends UpdateCompanion<PlansTableData> {
  final Value<String> id;
  final Value<String> name;
  final Value<String?> description;
  final Value<PlanCategory> category;
  final Value<List<String>> tags;
  final Value<String> defaultVoice;
  final Value<List<PlanStep>> steps;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<DateTime?> lastUsedAt;
  final Value<bool> isActive;
  final Value<String> ttsStatus;
  final Value<int> ttsTotal;
  final Value<int> ttsCompleted;
  final Value<String?> libraryId;
  final Value<int> rowid;
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
    this.isActive = const Value.absent(),
    this.ttsStatus = const Value.absent(),
    this.ttsTotal = const Value.absent(),
    this.ttsCompleted = const Value.absent(),
    this.libraryId = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  PlansTableCompanion.insert({
    required String id,
    required String name,
    this.description = const Value.absent(),
    this.category = const Value.absent(),
    this.tags = const Value.absent(),
    this.defaultVoice = const Value.absent(),
    this.steps = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.lastUsedAt = const Value.absent(),
    this.isActive = const Value.absent(),
    this.ttsStatus = const Value.absent(),
    this.ttsTotal = const Value.absent(),
    this.ttsCompleted = const Value.absent(),
    this.libraryId = const Value.absent(),
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        name = Value(name);
  static Insertable<PlansTableData> custom({
    Expression<String>? id,
    Expression<String>? name,
    Expression<String>? description,
    Expression<String>? category,
    Expression<String>? tags,
    Expression<String>? defaultVoice,
    Expression<String>? steps,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<DateTime>? lastUsedAt,
    Expression<bool>? isActive,
    Expression<String>? ttsStatus,
    Expression<int>? ttsTotal,
    Expression<int>? ttsCompleted,
    Expression<String>? libraryId,
    Expression<int>? rowid,
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
      if (isActive != null) 'is_active': isActive,
      if (ttsStatus != null) 'tts_status': ttsStatus,
      if (ttsTotal != null) 'tts_total': ttsTotal,
      if (ttsCompleted != null) 'tts_completed': ttsCompleted,
      if (libraryId != null) 'library_id': libraryId,
      if (rowid != null) 'rowid': rowid,
    });
  }

  PlansTableCompanion copyWith(
      {Value<String>? id,
      Value<String>? name,
      Value<String?>? description,
      Value<PlanCategory>? category,
      Value<List<String>>? tags,
      Value<String>? defaultVoice,
      Value<List<PlanStep>>? steps,
      Value<DateTime>? createdAt,
      Value<DateTime>? updatedAt,
      Value<DateTime?>? lastUsedAt,
      Value<bool>? isActive,
      Value<String>? ttsStatus,
      Value<int>? ttsTotal,
      Value<int>? ttsCompleted,
      Value<String?>? libraryId,
      Value<int>? rowid}) {
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
      isActive: isActive ?? this.isActive,
      ttsStatus: ttsStatus ?? this.ttsStatus,
      ttsTotal: ttsTotal ?? this.ttsTotal,
      ttsCompleted: ttsCompleted ?? this.ttsCompleted,
      libraryId: libraryId ?? this.libraryId,
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
    if (description.present) {
      map['description'] = Variable<String>(description.value);
    }
    if (category.present) {
      map['category'] = Variable<String>(
          $PlansTableTable.$convertercategory.toSql(category.value));
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
    if (isActive.present) {
      map['is_active'] = Variable<bool>(isActive.value);
    }
    if (ttsStatus.present) {
      map['tts_status'] = Variable<String>(
          $PlansTableTable.$converterttsStatus.toSql(ttsStatus.value));
    }
    if (ttsTotal.present) {
      map['tts_total'] = Variable<int>(ttsTotal.value);
    }
    if (ttsCompleted.present) {
      map['tts_completed'] = Variable<int>(ttsCompleted.value);
    }
    if (libraryId.present) {
      map['library_id'] = Variable<String>(libraryId.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
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
          ..write('lastUsedAt: $lastUsedAt, ')
          ..write('isActive: $isActive, ')
          ..write('ttsStatus: $ttsStatus, ')
          ..write('ttsTotal: $ttsTotal, ')
          ..write('ttsCompleted: $ttsCompleted, ')
          ..write('libraryId: $libraryId, ')
          ..write('rowid: $rowid')
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
  late final GeneratedColumn<String> planId = GeneratedColumn<String>(
      'plan_id', aliasedName, true,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultConstraints: GeneratedColumn.constraintIsAlways(
          'REFERENCES plans (id) ON DELETE SET NULL'));
  static const VerificationMeta _providerMeta =
      const VerificationMeta('provider');
  @override
  late final GeneratedColumn<String> provider = GeneratedColumn<String>(
      'provider', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant('gemini'));
  static const VerificationMeta _speechRateMeta =
      const VerificationMeta('speechRate');
  @override
  late final GeneratedColumn<String> speechRate = GeneratedColumn<String>(
      'speech_rate', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant('1.0'));
  static const VerificationMeta _createdAtMeta =
      const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
      'created_at', aliasedName, false,
      type: DriftSqlType.dateTime,
      requiredDuringInsert: false,
      defaultValue: currentDateAndTime);
  @override
  List<GeneratedColumn> get $columns => [
        id,
        textHash,
        voiceId,
        filePath,
        fileSizeBytes,
        planId,
        provider,
        speechRate,
        createdAt
      ];
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
    if (data.containsKey('provider')) {
      context.handle(_providerMeta,
          provider.isAcceptableOrUnknown(data['provider']!, _providerMeta));
    }
    if (data.containsKey('speech_rate')) {
      context.handle(
          _speechRateMeta,
          speechRate.isAcceptableOrUnknown(
              data['speech_rate']!, _speechRateMeta));
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
          .read(DriftSqlType.string, data['${effectivePrefix}plan_id']),
      provider: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}provider'])!,
      speechRate: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}speech_rate'])!,
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

  /// SHA-256 hash of all synthesis parameters — the deduplication key.
  ///
  /// From schema v2 onwards this is computed by [fullParamCacheKey]
  /// (JSON-serialised, alphabetical keys). Older rows stored the legacy
  /// `provider:voiceId:text` hash; they remain valid but will be superseded.
  final String textHash;
  final String voiceId;

  /// Absolute path to the cached audio file on local storage.
  final String filePath;

  /// Size of the audio file in bytes.
  final int fileSizeBytes;

  /// Optional reference back to the owning Plan for bulk cache eviction.
  final String? planId;

  /// TTS provider that generated this audio (e.g. 'gemini', 'kokoro').
  ///
  /// Added in schema v2. Defaults to 'gemini' for rows migrated from v1.
  final String provider;

  /// Speech rate at which the audio was generated (e.g. '1.0').
  ///
  /// Added in schema v2. Defaults to '1.0' (normal speed) for v1 rows.
  final String speechRate;
  final DateTime createdAt;
  const TtsCacheTableData(
      {required this.id,
      required this.textHash,
      required this.voiceId,
      required this.filePath,
      required this.fileSizeBytes,
      this.planId,
      required this.provider,
      required this.speechRate,
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
      map['plan_id'] = Variable<String>(planId);
    }
    map['provider'] = Variable<String>(provider);
    map['speech_rate'] = Variable<String>(speechRate);
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
      provider: Value(provider),
      speechRate: Value(speechRate),
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
      planId: serializer.fromJson<String?>(json['planId']),
      provider: serializer.fromJson<String>(json['provider']),
      speechRate: serializer.fromJson<String>(json['speechRate']),
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
      'planId': serializer.toJson<String?>(planId),
      'provider': serializer.toJson<String>(provider),
      'speechRate': serializer.toJson<String>(speechRate),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  TtsCacheTableData copyWith(
          {int? id,
          String? textHash,
          String? voiceId,
          String? filePath,
          int? fileSizeBytes,
          Value<String?> planId = const Value.absent(),
          String? provider,
          String? speechRate,
          DateTime? createdAt}) =>
      TtsCacheTableData(
        id: id ?? this.id,
        textHash: textHash ?? this.textHash,
        voiceId: voiceId ?? this.voiceId,
        filePath: filePath ?? this.filePath,
        fileSizeBytes: fileSizeBytes ?? this.fileSizeBytes,
        planId: planId.present ? planId.value : this.planId,
        provider: provider ?? this.provider,
        speechRate: speechRate ?? this.speechRate,
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
      provider: data.provider.present ? data.provider.value : this.provider,
      speechRate:
          data.speechRate.present ? data.speechRate.value : this.speechRate,
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
          ..write('provider: $provider, ')
          ..write('speechRate: $speechRate, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, textHash, voiceId, filePath,
      fileSizeBytes, planId, provider, speechRate, createdAt);
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
          other.provider == this.provider &&
          other.speechRate == this.speechRate &&
          other.createdAt == this.createdAt);
}

class TtsCacheTableCompanion extends UpdateCompanion<TtsCacheTableData> {
  final Value<int> id;
  final Value<String> textHash;
  final Value<String> voiceId;
  final Value<String> filePath;
  final Value<int> fileSizeBytes;
  final Value<String?> planId;
  final Value<String> provider;
  final Value<String> speechRate;
  final Value<DateTime> createdAt;
  const TtsCacheTableCompanion({
    this.id = const Value.absent(),
    this.textHash = const Value.absent(),
    this.voiceId = const Value.absent(),
    this.filePath = const Value.absent(),
    this.fileSizeBytes = const Value.absent(),
    this.planId = const Value.absent(),
    this.provider = const Value.absent(),
    this.speechRate = const Value.absent(),
    this.createdAt = const Value.absent(),
  });
  TtsCacheTableCompanion.insert({
    this.id = const Value.absent(),
    required String textHash,
    required String voiceId,
    required String filePath,
    this.fileSizeBytes = const Value.absent(),
    this.planId = const Value.absent(),
    this.provider = const Value.absent(),
    this.speechRate = const Value.absent(),
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
    Expression<String>? planId,
    Expression<String>? provider,
    Expression<String>? speechRate,
    Expression<DateTime>? createdAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (textHash != null) 'text_hash': textHash,
      if (voiceId != null) 'voice_id': voiceId,
      if (filePath != null) 'file_path': filePath,
      if (fileSizeBytes != null) 'file_size_bytes': fileSizeBytes,
      if (planId != null) 'plan_id': planId,
      if (provider != null) 'provider': provider,
      if (speechRate != null) 'speech_rate': speechRate,
      if (createdAt != null) 'created_at': createdAt,
    });
  }

  TtsCacheTableCompanion copyWith(
      {Value<int>? id,
      Value<String>? textHash,
      Value<String>? voiceId,
      Value<String>? filePath,
      Value<int>? fileSizeBytes,
      Value<String?>? planId,
      Value<String>? provider,
      Value<String>? speechRate,
      Value<DateTime>? createdAt}) {
    return TtsCacheTableCompanion(
      id: id ?? this.id,
      textHash: textHash ?? this.textHash,
      voiceId: voiceId ?? this.voiceId,
      filePath: filePath ?? this.filePath,
      fileSizeBytes: fileSizeBytes ?? this.fileSizeBytes,
      planId: planId ?? this.planId,
      provider: provider ?? this.provider,
      speechRate: speechRate ?? this.speechRate,
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
      map['plan_id'] = Variable<String>(planId.value);
    }
    if (provider.present) {
      map['provider'] = Variable<String>(provider.value);
    }
    if (speechRate.present) {
      map['speech_rate'] = Variable<String>(speechRate.value);
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
          ..write('provider: $provider, ')
          ..write('speechRate: $speechRate, ')
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
  late final GeneratedColumn<String> planId = GeneratedColumn<String>(
      'plan_id', aliasedName, false,
      type: DriftSqlType.string,
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
  static const VerificationMeta _ambientAssetKeyMeta =
      const VerificationMeta('ambientAssetKey');
  @override
  late final GeneratedColumn<String> ambientAssetKey = GeneratedColumn<String>(
      'ambient_asset_key', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
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
        ambientAssetKey,
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
    if (data.containsKey('ambient_asset_key')) {
      context.handle(
          _ambientAssetKeyMeta,
          ambientAssetKey.isAcceptableOrUnknown(
              data['ambient_asset_key']!, _ambientAssetKeyMeta));
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
          .read(DriftSqlType.string, data['${effectivePrefix}plan_id'])!,
      currentStepIndex: attachedDatabase.typeMapping.read(
          DriftSqlType.int, data['${effectivePrefix}current_step_index'])!,
      repeatCounters: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}repeat_counters'])!,
      elapsedMs: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}elapsed_ms'])!,
      ambientPositionMs: attachedDatabase.typeMapping.read(
          DriftSqlType.int, data['${effectivePrefix}ambient_position_ms'])!,
      ambientAssetKey: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}ambient_asset_key']),
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
  final String planId;

  /// Index into the Plan's flattened step list.
  final int currentStepIndex;

  /// JSON-encoded map of repeatStepId → current iteration count.
  final String repeatCounters;

  /// Total elapsed time in milliseconds since the Plan started.
  final int elapsedMs;

  /// Ambient audio playback position in milliseconds for resume-after-interrupt.
  final int ambientPositionMs;

  /// Asset key of the ambient track that was playing when the session was
  /// paused (e.g. 'ambient_rain'). Null when no ambient track was active.
  ///
  /// Persisted alongside [ambientPositionMs] so that crash recovery can
  /// restart the correct track before seeking to the saved position.
  final String? ambientAssetKey;

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
      this.ambientAssetKey,
      required this.status,
      required this.savedAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['plan_id'] = Variable<String>(planId);
    map['current_step_index'] = Variable<int>(currentStepIndex);
    map['repeat_counters'] = Variable<String>(repeatCounters);
    map['elapsed_ms'] = Variable<int>(elapsedMs);
    map['ambient_position_ms'] = Variable<int>(ambientPositionMs);
    if (!nullToAbsent || ambientAssetKey != null) {
      map['ambient_asset_key'] = Variable<String>(ambientAssetKey);
    }
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
      ambientAssetKey: ambientAssetKey == null && nullToAbsent
          ? const Value.absent()
          : Value(ambientAssetKey),
      status: Value(status),
      savedAt: Value(savedAt),
    );
  }

  factory ExecutionStateTableData.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ExecutionStateTableData(
      id: serializer.fromJson<int>(json['id']),
      planId: serializer.fromJson<String>(json['planId']),
      currentStepIndex: serializer.fromJson<int>(json['currentStepIndex']),
      repeatCounters: serializer.fromJson<String>(json['repeatCounters']),
      elapsedMs: serializer.fromJson<int>(json['elapsedMs']),
      ambientPositionMs: serializer.fromJson<int>(json['ambientPositionMs']),
      ambientAssetKey: serializer.fromJson<String?>(json['ambientAssetKey']),
      status: serializer.fromJson<String>(json['status']),
      savedAt: serializer.fromJson<DateTime>(json['savedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'planId': serializer.toJson<String>(planId),
      'currentStepIndex': serializer.toJson<int>(currentStepIndex),
      'repeatCounters': serializer.toJson<String>(repeatCounters),
      'elapsedMs': serializer.toJson<int>(elapsedMs),
      'ambientPositionMs': serializer.toJson<int>(ambientPositionMs),
      'ambientAssetKey': serializer.toJson<String?>(ambientAssetKey),
      'status': serializer.toJson<String>(status),
      'savedAt': serializer.toJson<DateTime>(savedAt),
    };
  }

  ExecutionStateTableData copyWith(
          {int? id,
          String? planId,
          int? currentStepIndex,
          String? repeatCounters,
          int? elapsedMs,
          int? ambientPositionMs,
          Value<String?> ambientAssetKey = const Value.absent(),
          String? status,
          DateTime? savedAt}) =>
      ExecutionStateTableData(
        id: id ?? this.id,
        planId: planId ?? this.planId,
        currentStepIndex: currentStepIndex ?? this.currentStepIndex,
        repeatCounters: repeatCounters ?? this.repeatCounters,
        elapsedMs: elapsedMs ?? this.elapsedMs,
        ambientPositionMs: ambientPositionMs ?? this.ambientPositionMs,
        ambientAssetKey: ambientAssetKey.present
            ? ambientAssetKey.value
            : this.ambientAssetKey,
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
      ambientAssetKey: data.ambientAssetKey.present
          ? data.ambientAssetKey.value
          : this.ambientAssetKey,
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
          ..write('ambientAssetKey: $ambientAssetKey, ')
          ..write('status: $status, ')
          ..write('savedAt: $savedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, planId, currentStepIndex, repeatCounters,
      elapsedMs, ambientPositionMs, ambientAssetKey, status, savedAt);
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
          other.ambientAssetKey == this.ambientAssetKey &&
          other.status == this.status &&
          other.savedAt == this.savedAt);
}

class ExecutionStateTableCompanion
    extends UpdateCompanion<ExecutionStateTableData> {
  final Value<int> id;
  final Value<String> planId;
  final Value<int> currentStepIndex;
  final Value<String> repeatCounters;
  final Value<int> elapsedMs;
  final Value<int> ambientPositionMs;
  final Value<String?> ambientAssetKey;
  final Value<String> status;
  final Value<DateTime> savedAt;
  const ExecutionStateTableCompanion({
    this.id = const Value.absent(),
    this.planId = const Value.absent(),
    this.currentStepIndex = const Value.absent(),
    this.repeatCounters = const Value.absent(),
    this.elapsedMs = const Value.absent(),
    this.ambientPositionMs = const Value.absent(),
    this.ambientAssetKey = const Value.absent(),
    this.status = const Value.absent(),
    this.savedAt = const Value.absent(),
  });
  ExecutionStateTableCompanion.insert({
    this.id = const Value.absent(),
    required String planId,
    this.currentStepIndex = const Value.absent(),
    this.repeatCounters = const Value.absent(),
    this.elapsedMs = const Value.absent(),
    this.ambientPositionMs = const Value.absent(),
    this.ambientAssetKey = const Value.absent(),
    this.status = const Value.absent(),
    this.savedAt = const Value.absent(),
  }) : planId = Value(planId);
  static Insertable<ExecutionStateTableData> custom({
    Expression<int>? id,
    Expression<String>? planId,
    Expression<int>? currentStepIndex,
    Expression<String>? repeatCounters,
    Expression<int>? elapsedMs,
    Expression<int>? ambientPositionMs,
    Expression<String>? ambientAssetKey,
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
      if (ambientAssetKey != null) 'ambient_asset_key': ambientAssetKey,
      if (status != null) 'status': status,
      if (savedAt != null) 'saved_at': savedAt,
    });
  }

  ExecutionStateTableCompanion copyWith(
      {Value<int>? id,
      Value<String>? planId,
      Value<int>? currentStepIndex,
      Value<String>? repeatCounters,
      Value<int>? elapsedMs,
      Value<int>? ambientPositionMs,
      Value<String?>? ambientAssetKey,
      Value<String>? status,
      Value<DateTime>? savedAt}) {
    return ExecutionStateTableCompanion(
      id: id ?? this.id,
      planId: planId ?? this.planId,
      currentStepIndex: currentStepIndex ?? this.currentStepIndex,
      repeatCounters: repeatCounters ?? this.repeatCounters,
      elapsedMs: elapsedMs ?? this.elapsedMs,
      ambientPositionMs: ambientPositionMs ?? this.ambientPositionMs,
      ambientAssetKey: ambientAssetKey ?? this.ambientAssetKey,
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
      map['plan_id'] = Variable<String>(planId.value);
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
    if (ambientAssetKey.present) {
      map['ambient_asset_key'] = Variable<String>(ambientAssetKey.value);
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
          ..write('ambientAssetKey: $ambientAssetKey, ')
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

class $SessionCompletionsTableTable extends SessionCompletionsTable
    with TableInfo<$SessionCompletionsTableTable, SessionCompletionsTableData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SessionCompletionsTableTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
      'id', aliasedName, false,
      hasAutoIncrement: true,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('PRIMARY KEY AUTOINCREMENT'));
  static const VerificationMeta _userIdMeta = const VerificationMeta('userId');
  @override
  late final GeneratedColumn<String> userId = GeneratedColumn<String>(
      'user_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _planIdMeta = const VerificationMeta('planId');
  @override
  late final GeneratedColumn<String> planId = GeneratedColumn<String>(
      'plan_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _completedAtMeta =
      const VerificationMeta('completedAt');
  @override
  late final GeneratedColumn<DateTime> completedAt = GeneratedColumn<DateTime>(
      'completed_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  static const VerificationMeta _durationMsMeta =
      const VerificationMeta('durationMs');
  @override
  late final GeneratedColumn<int> durationMs = GeneratedColumn<int>(
      'duration_ms', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _clientIdMeta =
      const VerificationMeta('clientId');
  @override
  late final GeneratedColumn<String> clientId = GeneratedColumn<String>(
      'client_id', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: true,
      defaultConstraints: GeneratedColumn.constraintIsAlways('UNIQUE'));
  static const VerificationMeta _syncedAtMeta =
      const VerificationMeta('syncedAt');
  @override
  late final GeneratedColumn<DateTime> syncedAt = GeneratedColumn<DateTime>(
      'synced_at', aliasedName, true,
      type: DriftSqlType.dateTime, requiredDuringInsert: false);
  static const VerificationMeta _createdAtMeta =
      const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
      'created_at', aliasedName, false,
      type: DriftSqlType.dateTime,
      requiredDuringInsert: false,
      defaultValue: currentDateAndTime);
  @override
  List<GeneratedColumn> get $columns => [
        id,
        userId,
        planId,
        completedAt,
        durationMs,
        clientId,
        syncedAt,
        createdAt
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'session_completions';
  @override
  VerificationContext validateIntegrity(
      Insertable<SessionCompletionsTableData> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('user_id')) {
      context.handle(_userIdMeta,
          userId.isAcceptableOrUnknown(data['user_id']!, _userIdMeta));
    } else if (isInserting) {
      context.missing(_userIdMeta);
    }
    if (data.containsKey('plan_id')) {
      context.handle(_planIdMeta,
          planId.isAcceptableOrUnknown(data['plan_id']!, _planIdMeta));
    } else if (isInserting) {
      context.missing(_planIdMeta);
    }
    if (data.containsKey('completed_at')) {
      context.handle(
          _completedAtMeta,
          completedAt.isAcceptableOrUnknown(
              data['completed_at']!, _completedAtMeta));
    } else if (isInserting) {
      context.missing(_completedAtMeta);
    }
    if (data.containsKey('duration_ms')) {
      context.handle(
          _durationMsMeta,
          durationMs.isAcceptableOrUnknown(
              data['duration_ms']!, _durationMsMeta));
    } else if (isInserting) {
      context.missing(_durationMsMeta);
    }
    if (data.containsKey('client_id')) {
      context.handle(_clientIdMeta,
          clientId.isAcceptableOrUnknown(data['client_id']!, _clientIdMeta));
    } else if (isInserting) {
      context.missing(_clientIdMeta);
    }
    if (data.containsKey('synced_at')) {
      context.handle(_syncedAtMeta,
          syncedAt.isAcceptableOrUnknown(data['synced_at']!, _syncedAtMeta));
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
  SessionCompletionsTableData map(Map<String, dynamic> data,
      {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SessionCompletionsTableData(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      userId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}user_id'])!,
      planId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}plan_id'])!,
      completedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}completed_at'])!,
      durationMs: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}duration_ms'])!,
      clientId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}client_id'])!,
      syncedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}synced_at']),
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}created_at'])!,
    );
  }

  @override
  $SessionCompletionsTableTable createAlias(String alias) {
    return $SessionCompletionsTableTable(attachedDatabase, alias);
  }
}

class SessionCompletionsTableData extends DataClass
    implements Insertable<SessionCompletionsTableData> {
  /// Auto-increment primary key.
  final int id;

  /// User ID (string UUID from server) — identifies the user who completed the session.
  /// Allows querying completions per user for streak calculation and sync.
  final String userId;

  /// Associated plan ID (UUID string from server).
  /// Not a FK — plan may be deleted but completion persists for streak history.
  final String planId;

  /// UTC timestamp when the user finished the session.
  final DateTime completedAt;

  /// Session duration in milliseconds.
  final int durationMs;

  /// Client-generated UUID for idempotent server sync.
  final String clientId;

  /// Sync timestamp — null if not yet synced to server.
  final DateTime? syncedAt;

  /// Record creation timestamp.
  final DateTime createdAt;
  const SessionCompletionsTableData(
      {required this.id,
      required this.userId,
      required this.planId,
      required this.completedAt,
      required this.durationMs,
      required this.clientId,
      this.syncedAt,
      required this.createdAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['user_id'] = Variable<String>(userId);
    map['plan_id'] = Variable<String>(planId);
    map['completed_at'] = Variable<DateTime>(completedAt);
    map['duration_ms'] = Variable<int>(durationMs);
    map['client_id'] = Variable<String>(clientId);
    if (!nullToAbsent || syncedAt != null) {
      map['synced_at'] = Variable<DateTime>(syncedAt);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  SessionCompletionsTableCompanion toCompanion(bool nullToAbsent) {
    return SessionCompletionsTableCompanion(
      id: Value(id),
      userId: Value(userId),
      planId: Value(planId),
      completedAt: Value(completedAt),
      durationMs: Value(durationMs),
      clientId: Value(clientId),
      syncedAt: syncedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(syncedAt),
      createdAt: Value(createdAt),
    );
  }

  factory SessionCompletionsTableData.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SessionCompletionsTableData(
      id: serializer.fromJson<int>(json['id']),
      userId: serializer.fromJson<String>(json['userId']),
      planId: serializer.fromJson<String>(json['planId']),
      completedAt: serializer.fromJson<DateTime>(json['completedAt']),
      durationMs: serializer.fromJson<int>(json['durationMs']),
      clientId: serializer.fromJson<String>(json['clientId']),
      syncedAt: serializer.fromJson<DateTime?>(json['syncedAt']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'userId': serializer.toJson<String>(userId),
      'planId': serializer.toJson<String>(planId),
      'completedAt': serializer.toJson<DateTime>(completedAt),
      'durationMs': serializer.toJson<int>(durationMs),
      'clientId': serializer.toJson<String>(clientId),
      'syncedAt': serializer.toJson<DateTime?>(syncedAt),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  SessionCompletionsTableData copyWith(
          {int? id,
          String? userId,
          String? planId,
          DateTime? completedAt,
          int? durationMs,
          String? clientId,
          Value<DateTime?> syncedAt = const Value.absent(),
          DateTime? createdAt}) =>
      SessionCompletionsTableData(
        id: id ?? this.id,
        userId: userId ?? this.userId,
        planId: planId ?? this.planId,
        completedAt: completedAt ?? this.completedAt,
        durationMs: durationMs ?? this.durationMs,
        clientId: clientId ?? this.clientId,
        syncedAt: syncedAt.present ? syncedAt.value : this.syncedAt,
        createdAt: createdAt ?? this.createdAt,
      );
  SessionCompletionsTableData copyWithCompanion(
      SessionCompletionsTableCompanion data) {
    return SessionCompletionsTableData(
      id: data.id.present ? data.id.value : this.id,
      userId: data.userId.present ? data.userId.value : this.userId,
      planId: data.planId.present ? data.planId.value : this.planId,
      completedAt:
          data.completedAt.present ? data.completedAt.value : this.completedAt,
      durationMs:
          data.durationMs.present ? data.durationMs.value : this.durationMs,
      clientId: data.clientId.present ? data.clientId.value : this.clientId,
      syncedAt: data.syncedAt.present ? data.syncedAt.value : this.syncedAt,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SessionCompletionsTableData(')
          ..write('id: $id, ')
          ..write('userId: $userId, ')
          ..write('planId: $planId, ')
          ..write('completedAt: $completedAt, ')
          ..write('durationMs: $durationMs, ')
          ..write('clientId: $clientId, ')
          ..write('syncedAt: $syncedAt, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, userId, planId, completedAt, durationMs,
      clientId, syncedAt, createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SessionCompletionsTableData &&
          other.id == this.id &&
          other.userId == this.userId &&
          other.planId == this.planId &&
          other.completedAt == this.completedAt &&
          other.durationMs == this.durationMs &&
          other.clientId == this.clientId &&
          other.syncedAt == this.syncedAt &&
          other.createdAt == this.createdAt);
}

class SessionCompletionsTableCompanion
    extends UpdateCompanion<SessionCompletionsTableData> {
  final Value<int> id;
  final Value<String> userId;
  final Value<String> planId;
  final Value<DateTime> completedAt;
  final Value<int> durationMs;
  final Value<String> clientId;
  final Value<DateTime?> syncedAt;
  final Value<DateTime> createdAt;
  const SessionCompletionsTableCompanion({
    this.id = const Value.absent(),
    this.userId = const Value.absent(),
    this.planId = const Value.absent(),
    this.completedAt = const Value.absent(),
    this.durationMs = const Value.absent(),
    this.clientId = const Value.absent(),
    this.syncedAt = const Value.absent(),
    this.createdAt = const Value.absent(),
  });
  SessionCompletionsTableCompanion.insert({
    this.id = const Value.absent(),
    required String userId,
    required String planId,
    required DateTime completedAt,
    required int durationMs,
    required String clientId,
    this.syncedAt = const Value.absent(),
    this.createdAt = const Value.absent(),
  })  : userId = Value(userId),
        planId = Value(planId),
        completedAt = Value(completedAt),
        durationMs = Value(durationMs),
        clientId = Value(clientId);
  static Insertable<SessionCompletionsTableData> custom({
    Expression<int>? id,
    Expression<String>? userId,
    Expression<String>? planId,
    Expression<DateTime>? completedAt,
    Expression<int>? durationMs,
    Expression<String>? clientId,
    Expression<DateTime>? syncedAt,
    Expression<DateTime>? createdAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (userId != null) 'user_id': userId,
      if (planId != null) 'plan_id': planId,
      if (completedAt != null) 'completed_at': completedAt,
      if (durationMs != null) 'duration_ms': durationMs,
      if (clientId != null) 'client_id': clientId,
      if (syncedAt != null) 'synced_at': syncedAt,
      if (createdAt != null) 'created_at': createdAt,
    });
  }

  SessionCompletionsTableCompanion copyWith(
      {Value<int>? id,
      Value<String>? userId,
      Value<String>? planId,
      Value<DateTime>? completedAt,
      Value<int>? durationMs,
      Value<String>? clientId,
      Value<DateTime?>? syncedAt,
      Value<DateTime>? createdAt}) {
    return SessionCompletionsTableCompanion(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      planId: planId ?? this.planId,
      completedAt: completedAt ?? this.completedAt,
      durationMs: durationMs ?? this.durationMs,
      clientId: clientId ?? this.clientId,
      syncedAt: syncedAt ?? this.syncedAt,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (userId.present) {
      map['user_id'] = Variable<String>(userId.value);
    }
    if (planId.present) {
      map['plan_id'] = Variable<String>(planId.value);
    }
    if (completedAt.present) {
      map['completed_at'] = Variable<DateTime>(completedAt.value);
    }
    if (durationMs.present) {
      map['duration_ms'] = Variable<int>(durationMs.value);
    }
    if (clientId.present) {
      map['client_id'] = Variable<String>(clientId.value);
    }
    if (syncedAt.present) {
      map['synced_at'] = Variable<DateTime>(syncedAt.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SessionCompletionsTableCompanion(')
          ..write('id: $id, ')
          ..write('userId: $userId, ')
          ..write('planId: $planId, ')
          ..write('completedAt: $completedAt, ')
          ..write('durationMs: $durationMs, ')
          ..write('clientId: $clientId, ')
          ..write('syncedAt: $syncedAt, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }
}

class $StreakFreezesTableTable extends StreakFreezesTable
    with TableInfo<$StreakFreezesTableTable, StreakFreezesTableData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $StreakFreezesTableTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
      'id', aliasedName, false,
      hasAutoIncrement: true,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('PRIMARY KEY AUTOINCREMENT'));
  static const VerificationMeta _userIdMeta = const VerificationMeta('userId');
  @override
  late final GeneratedColumn<String> userId = GeneratedColumn<String>(
      'user_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _frozenAtMeta =
      const VerificationMeta('frozenAt');
  @override
  late final GeneratedColumn<DateTime> frozenAt = GeneratedColumn<DateTime>(
      'frozen_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  static const VerificationMeta _expiresAtMeta =
      const VerificationMeta('expiresAt');
  @override
  late final GeneratedColumn<DateTime> expiresAt = GeneratedColumn<DateTime>(
      'expires_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  static const VerificationMeta _consumedAtMeta =
      const VerificationMeta('consumedAt');
  @override
  late final GeneratedColumn<DateTime> consumedAt = GeneratedColumn<DateTime>(
      'consumed_at', aliasedName, true,
      type: DriftSqlType.dateTime, requiredDuringInsert: false);
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
      [id, userId, frozenAt, expiresAt, consumedAt, createdAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'streak_freezes';
  @override
  VerificationContext validateIntegrity(
      Insertable<StreakFreezesTableData> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('user_id')) {
      context.handle(_userIdMeta,
          userId.isAcceptableOrUnknown(data['user_id']!, _userIdMeta));
    } else if (isInserting) {
      context.missing(_userIdMeta);
    }
    if (data.containsKey('frozen_at')) {
      context.handle(_frozenAtMeta,
          frozenAt.isAcceptableOrUnknown(data['frozen_at']!, _frozenAtMeta));
    } else if (isInserting) {
      context.missing(_frozenAtMeta);
    }
    if (data.containsKey('expires_at')) {
      context.handle(_expiresAtMeta,
          expiresAt.isAcceptableOrUnknown(data['expires_at']!, _expiresAtMeta));
    } else if (isInserting) {
      context.missing(_expiresAtMeta);
    }
    if (data.containsKey('consumed_at')) {
      context.handle(
          _consumedAtMeta,
          consumedAt.isAcceptableOrUnknown(
              data['consumed_at']!, _consumedAtMeta));
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
  StreakFreezesTableData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return StreakFreezesTableData(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      userId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}user_id'])!,
      frozenAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}frozen_at'])!,
      expiresAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}expires_at'])!,
      consumedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}consumed_at']),
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}created_at'])!,
    );
  }

  @override
  $StreakFreezesTableTable createAlias(String alias) {
    return $StreakFreezesTableTable(attachedDatabase, alias);
  }
}

class StreakFreezesTableData extends DataClass
    implements Insertable<StreakFreezesTableData> {
  /// Auto-increment primary key.
  final int id;

  /// User ID (string UUID from server) — identifies the user who owns this freeze.
  /// Allows querying active freezes per user for the freeze availability check.
  final String userId;

  /// The date when this freeze was earned (UTC).
  final DateTime frozenAt;

  /// The date when this freeze expires if unused.
  final DateTime expiresAt;

  /// The date when this freeze was consumed (null if still available).
  final DateTime? consumedAt;

  /// Record creation timestamp.
  final DateTime createdAt;
  const StreakFreezesTableData(
      {required this.id,
      required this.userId,
      required this.frozenAt,
      required this.expiresAt,
      this.consumedAt,
      required this.createdAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['user_id'] = Variable<String>(userId);
    map['frozen_at'] = Variable<DateTime>(frozenAt);
    map['expires_at'] = Variable<DateTime>(expiresAt);
    if (!nullToAbsent || consumedAt != null) {
      map['consumed_at'] = Variable<DateTime>(consumedAt);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  StreakFreezesTableCompanion toCompanion(bool nullToAbsent) {
    return StreakFreezesTableCompanion(
      id: Value(id),
      userId: Value(userId),
      frozenAt: Value(frozenAt),
      expiresAt: Value(expiresAt),
      consumedAt: consumedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(consumedAt),
      createdAt: Value(createdAt),
    );
  }

  factory StreakFreezesTableData.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return StreakFreezesTableData(
      id: serializer.fromJson<int>(json['id']),
      userId: serializer.fromJson<String>(json['userId']),
      frozenAt: serializer.fromJson<DateTime>(json['frozenAt']),
      expiresAt: serializer.fromJson<DateTime>(json['expiresAt']),
      consumedAt: serializer.fromJson<DateTime?>(json['consumedAt']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'userId': serializer.toJson<String>(userId),
      'frozenAt': serializer.toJson<DateTime>(frozenAt),
      'expiresAt': serializer.toJson<DateTime>(expiresAt),
      'consumedAt': serializer.toJson<DateTime?>(consumedAt),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  StreakFreezesTableData copyWith(
          {int? id,
          String? userId,
          DateTime? frozenAt,
          DateTime? expiresAt,
          Value<DateTime?> consumedAt = const Value.absent(),
          DateTime? createdAt}) =>
      StreakFreezesTableData(
        id: id ?? this.id,
        userId: userId ?? this.userId,
        frozenAt: frozenAt ?? this.frozenAt,
        expiresAt: expiresAt ?? this.expiresAt,
        consumedAt: consumedAt.present ? consumedAt.value : this.consumedAt,
        createdAt: createdAt ?? this.createdAt,
      );
  StreakFreezesTableData copyWithCompanion(StreakFreezesTableCompanion data) {
    return StreakFreezesTableData(
      id: data.id.present ? data.id.value : this.id,
      userId: data.userId.present ? data.userId.value : this.userId,
      frozenAt: data.frozenAt.present ? data.frozenAt.value : this.frozenAt,
      expiresAt: data.expiresAt.present ? data.expiresAt.value : this.expiresAt,
      consumedAt:
          data.consumedAt.present ? data.consumedAt.value : this.consumedAt,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('StreakFreezesTableData(')
          ..write('id: $id, ')
          ..write('userId: $userId, ')
          ..write('frozenAt: $frozenAt, ')
          ..write('expiresAt: $expiresAt, ')
          ..write('consumedAt: $consumedAt, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, userId, frozenAt, expiresAt, consumedAt, createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is StreakFreezesTableData &&
          other.id == this.id &&
          other.userId == this.userId &&
          other.frozenAt == this.frozenAt &&
          other.expiresAt == this.expiresAt &&
          other.consumedAt == this.consumedAt &&
          other.createdAt == this.createdAt);
}

class StreakFreezesTableCompanion
    extends UpdateCompanion<StreakFreezesTableData> {
  final Value<int> id;
  final Value<String> userId;
  final Value<DateTime> frozenAt;
  final Value<DateTime> expiresAt;
  final Value<DateTime?> consumedAt;
  final Value<DateTime> createdAt;
  const StreakFreezesTableCompanion({
    this.id = const Value.absent(),
    this.userId = const Value.absent(),
    this.frozenAt = const Value.absent(),
    this.expiresAt = const Value.absent(),
    this.consumedAt = const Value.absent(),
    this.createdAt = const Value.absent(),
  });
  StreakFreezesTableCompanion.insert({
    this.id = const Value.absent(),
    required String userId,
    required DateTime frozenAt,
    required DateTime expiresAt,
    this.consumedAt = const Value.absent(),
    this.createdAt = const Value.absent(),
  })  : userId = Value(userId),
        frozenAt = Value(frozenAt),
        expiresAt = Value(expiresAt);
  static Insertable<StreakFreezesTableData> custom({
    Expression<int>? id,
    Expression<String>? userId,
    Expression<DateTime>? frozenAt,
    Expression<DateTime>? expiresAt,
    Expression<DateTime>? consumedAt,
    Expression<DateTime>? createdAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (userId != null) 'user_id': userId,
      if (frozenAt != null) 'frozen_at': frozenAt,
      if (expiresAt != null) 'expires_at': expiresAt,
      if (consumedAt != null) 'consumed_at': consumedAt,
      if (createdAt != null) 'created_at': createdAt,
    });
  }

  StreakFreezesTableCompanion copyWith(
      {Value<int>? id,
      Value<String>? userId,
      Value<DateTime>? frozenAt,
      Value<DateTime>? expiresAt,
      Value<DateTime?>? consumedAt,
      Value<DateTime>? createdAt}) {
    return StreakFreezesTableCompanion(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      frozenAt: frozenAt ?? this.frozenAt,
      expiresAt: expiresAt ?? this.expiresAt,
      consumedAt: consumedAt ?? this.consumedAt,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (userId.present) {
      map['user_id'] = Variable<String>(userId.value);
    }
    if (frozenAt.present) {
      map['frozen_at'] = Variable<DateTime>(frozenAt.value);
    }
    if (expiresAt.present) {
      map['expires_at'] = Variable<DateTime>(expiresAt.value);
    }
    if (consumedAt.present) {
      map['consumed_at'] = Variable<DateTime>(consumedAt.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('StreakFreezesTableCompanion(')
          ..write('id: $id, ')
          ..write('userId: $userId, ')
          ..write('frozenAt: $frozenAt, ')
          ..write('expiresAt: $expiresAt, ')
          ..write('consumedAt: $consumedAt, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }
}

class $PlanTriggersTableTable extends PlanTriggersTable
    with TableInfo<$PlanTriggersTableTable, PlanTriggersTableData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PlanTriggersTableTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
      'id', aliasedName, false,
      hasAutoIncrement: true,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('PRIMARY KEY AUTOINCREMENT'));
  static const VerificationMeta _clientIdMeta =
      const VerificationMeta('clientId');
  @override
  late final GeneratedColumn<String> clientId = GeneratedColumn<String>(
      'client_id', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: true,
      defaultConstraints: GeneratedColumn.constraintIsAlways('UNIQUE'));
  static const VerificationMeta _serverIdMeta =
      const VerificationMeta('serverId');
  @override
  late final GeneratedColumn<String> serverId = GeneratedColumn<String>(
      'server_id', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _userIdMeta = const VerificationMeta('userId');
  @override
  late final GeneratedColumn<String> userId = GeneratedColumn<String>(
      'user_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _planIdMeta = const VerificationMeta('planId');
  @override
  late final GeneratedColumn<String> planId = GeneratedColumn<String>(
      'plan_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
      'title', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _startUtcMeta =
      const VerificationMeta('startUtc');
  @override
  late final GeneratedColumn<DateTime> startUtc = GeneratedColumn<DateTime>(
      'start_utc', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  static const VerificationMeta _durationMinutesMeta =
      const VerificationMeta('durationMinutes');
  @override
  late final GeneratedColumn<int> durationMinutes = GeneratedColumn<int>(
      'duration_minutes', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _recurrenceMeta =
      const VerificationMeta('recurrence');
  @override
  late final GeneratedColumn<String> recurrence = GeneratedColumn<String>(
      'recurrence', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant('none'));
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
  static const VerificationMeta _syncedAtMeta =
      const VerificationMeta('syncedAt');
  @override
  late final GeneratedColumn<DateTime> syncedAt = GeneratedColumn<DateTime>(
      'synced_at', aliasedName, true,
      type: DriftSqlType.dateTime, requiredDuringInsert: false);
  static const VerificationMeta _deletedAtMeta =
      const VerificationMeta('deletedAt');
  @override
  late final GeneratedColumn<DateTime> deletedAt = GeneratedColumn<DateTime>(
      'deleted_at', aliasedName, true,
      type: DriftSqlType.dateTime, requiredDuringInsert: false);
  @override
  List<GeneratedColumn> get $columns => [
        id,
        clientId,
        serverId,
        userId,
        planId,
        title,
        startUtc,
        durationMinutes,
        recurrence,
        createdAt,
        updatedAt,
        syncedAt,
        deletedAt
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'plan_triggers';
  @override
  VerificationContext validateIntegrity(
      Insertable<PlanTriggersTableData> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('client_id')) {
      context.handle(_clientIdMeta,
          clientId.isAcceptableOrUnknown(data['client_id']!, _clientIdMeta));
    } else if (isInserting) {
      context.missing(_clientIdMeta);
    }
    if (data.containsKey('server_id')) {
      context.handle(_serverIdMeta,
          serverId.isAcceptableOrUnknown(data['server_id']!, _serverIdMeta));
    }
    if (data.containsKey('user_id')) {
      context.handle(_userIdMeta,
          userId.isAcceptableOrUnknown(data['user_id']!, _userIdMeta));
    } else if (isInserting) {
      context.missing(_userIdMeta);
    }
    if (data.containsKey('plan_id')) {
      context.handle(_planIdMeta,
          planId.isAcceptableOrUnknown(data['plan_id']!, _planIdMeta));
    } else if (isInserting) {
      context.missing(_planIdMeta);
    }
    if (data.containsKey('title')) {
      context.handle(
          _titleMeta, title.isAcceptableOrUnknown(data['title']!, _titleMeta));
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('start_utc')) {
      context.handle(_startUtcMeta,
          startUtc.isAcceptableOrUnknown(data['start_utc']!, _startUtcMeta));
    } else if (isInserting) {
      context.missing(_startUtcMeta);
    }
    if (data.containsKey('duration_minutes')) {
      context.handle(
          _durationMinutesMeta,
          durationMinutes.isAcceptableOrUnknown(
              data['duration_minutes']!, _durationMinutesMeta));
    } else if (isInserting) {
      context.missing(_durationMinutesMeta);
    }
    if (data.containsKey('recurrence')) {
      context.handle(
          _recurrenceMeta,
          recurrence.isAcceptableOrUnknown(
              data['recurrence']!, _recurrenceMeta));
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta,
          createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    }
    if (data.containsKey('updated_at')) {
      context.handle(_updatedAtMeta,
          updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta));
    }
    if (data.containsKey('synced_at')) {
      context.handle(_syncedAtMeta,
          syncedAt.isAcceptableOrUnknown(data['synced_at']!, _syncedAtMeta));
    }
    if (data.containsKey('deleted_at')) {
      context.handle(_deletedAtMeta,
          deletedAt.isAcceptableOrUnknown(data['deleted_at']!, _deletedAtMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  PlanTriggersTableData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PlanTriggersTableData(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      clientId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}client_id'])!,
      serverId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}server_id']),
      userId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}user_id'])!,
      planId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}plan_id'])!,
      title: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}title'])!,
      startUtc: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}start_utc'])!,
      durationMinutes: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}duration_minutes'])!,
      recurrence: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}recurrence'])!,
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}created_at'])!,
      updatedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}updated_at'])!,
      syncedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}synced_at']),
      deletedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}deleted_at']),
    );
  }

  @override
  $PlanTriggersTableTable createAlias(String alias) {
    return $PlanTriggersTableTable(attachedDatabase, alias);
  }
}

class PlanTriggersTableData extends DataClass
    implements Insertable<PlanTriggersTableData> {
  /// Local auto-increment primary key. Separate from [clientId] so joins
  /// and watches stay integer-keyed.
  final int id;

  /// Client-generated UUID — cross-device identity + idempotency key.
  final String clientId;

  /// Server-assigned UUID, null until first successful push.
  final String? serverId;

  /// User who owns the trigger (server UUID).
  final String userId;

  /// Plan to start when the trigger fires.
  final String planId;

  /// Display title captured at schedule time (plan name may change later).
  final String title;

  /// First-occurrence start time (UTC).
  final DateTime startUtc;

  /// Session duration for the scheduled plan.
  final int durationMinutes;

  /// Recurrence rule — one of 'none' | 'daily' | 'weekdays' | 'weekly'.
  final String recurrence;

  /// Record creation timestamp.
  final DateTime createdAt;

  /// Last local mutation timestamp — bumped on every edit so the server can
  /// resolve concurrent updates via last-write-wins.
  final DateTime updatedAt;

  /// Last successful sync timestamp. Null or stale → row is dirty.
  final DateTime? syncedAt;

  /// Soft-delete tombstone. Non-null rows are hidden from UI but remain in
  /// the table so their delete can be synced to other devices.
  final DateTime? deletedAt;
  const PlanTriggersTableData(
      {required this.id,
      required this.clientId,
      this.serverId,
      required this.userId,
      required this.planId,
      required this.title,
      required this.startUtc,
      required this.durationMinutes,
      required this.recurrence,
      required this.createdAt,
      required this.updatedAt,
      this.syncedAt,
      this.deletedAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['client_id'] = Variable<String>(clientId);
    if (!nullToAbsent || serverId != null) {
      map['server_id'] = Variable<String>(serverId);
    }
    map['user_id'] = Variable<String>(userId);
    map['plan_id'] = Variable<String>(planId);
    map['title'] = Variable<String>(title);
    map['start_utc'] = Variable<DateTime>(startUtc);
    map['duration_minutes'] = Variable<int>(durationMinutes);
    map['recurrence'] = Variable<String>(recurrence);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    if (!nullToAbsent || syncedAt != null) {
      map['synced_at'] = Variable<DateTime>(syncedAt);
    }
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<DateTime>(deletedAt);
    }
    return map;
  }

  PlanTriggersTableCompanion toCompanion(bool nullToAbsent) {
    return PlanTriggersTableCompanion(
      id: Value(id),
      clientId: Value(clientId),
      serverId: serverId == null && nullToAbsent
          ? const Value.absent()
          : Value(serverId),
      userId: Value(userId),
      planId: Value(planId),
      title: Value(title),
      startUtc: Value(startUtc),
      durationMinutes: Value(durationMinutes),
      recurrence: Value(recurrence),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      syncedAt: syncedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(syncedAt),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
    );
  }

  factory PlanTriggersTableData.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PlanTriggersTableData(
      id: serializer.fromJson<int>(json['id']),
      clientId: serializer.fromJson<String>(json['clientId']),
      serverId: serializer.fromJson<String?>(json['serverId']),
      userId: serializer.fromJson<String>(json['userId']),
      planId: serializer.fromJson<String>(json['planId']),
      title: serializer.fromJson<String>(json['title']),
      startUtc: serializer.fromJson<DateTime>(json['startUtc']),
      durationMinutes: serializer.fromJson<int>(json['durationMinutes']),
      recurrence: serializer.fromJson<String>(json['recurrence']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
      syncedAt: serializer.fromJson<DateTime?>(json['syncedAt']),
      deletedAt: serializer.fromJson<DateTime?>(json['deletedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'clientId': serializer.toJson<String>(clientId),
      'serverId': serializer.toJson<String?>(serverId),
      'userId': serializer.toJson<String>(userId),
      'planId': serializer.toJson<String>(planId),
      'title': serializer.toJson<String>(title),
      'startUtc': serializer.toJson<DateTime>(startUtc),
      'durationMinutes': serializer.toJson<int>(durationMinutes),
      'recurrence': serializer.toJson<String>(recurrence),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
      'syncedAt': serializer.toJson<DateTime?>(syncedAt),
      'deletedAt': serializer.toJson<DateTime?>(deletedAt),
    };
  }

  PlanTriggersTableData copyWith(
          {int? id,
          String? clientId,
          Value<String?> serverId = const Value.absent(),
          String? userId,
          String? planId,
          String? title,
          DateTime? startUtc,
          int? durationMinutes,
          String? recurrence,
          DateTime? createdAt,
          DateTime? updatedAt,
          Value<DateTime?> syncedAt = const Value.absent(),
          Value<DateTime?> deletedAt = const Value.absent()}) =>
      PlanTriggersTableData(
        id: id ?? this.id,
        clientId: clientId ?? this.clientId,
        serverId: serverId.present ? serverId.value : this.serverId,
        userId: userId ?? this.userId,
        planId: planId ?? this.planId,
        title: title ?? this.title,
        startUtc: startUtc ?? this.startUtc,
        durationMinutes: durationMinutes ?? this.durationMinutes,
        recurrence: recurrence ?? this.recurrence,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
        syncedAt: syncedAt.present ? syncedAt.value : this.syncedAt,
        deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
      );
  PlanTriggersTableData copyWithCompanion(PlanTriggersTableCompanion data) {
    return PlanTriggersTableData(
      id: data.id.present ? data.id.value : this.id,
      clientId: data.clientId.present ? data.clientId.value : this.clientId,
      serverId: data.serverId.present ? data.serverId.value : this.serverId,
      userId: data.userId.present ? data.userId.value : this.userId,
      planId: data.planId.present ? data.planId.value : this.planId,
      title: data.title.present ? data.title.value : this.title,
      startUtc: data.startUtc.present ? data.startUtc.value : this.startUtc,
      durationMinutes: data.durationMinutes.present
          ? data.durationMinutes.value
          : this.durationMinutes,
      recurrence:
          data.recurrence.present ? data.recurrence.value : this.recurrence,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      syncedAt: data.syncedAt.present ? data.syncedAt.value : this.syncedAt,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('PlanTriggersTableData(')
          ..write('id: $id, ')
          ..write('clientId: $clientId, ')
          ..write('serverId: $serverId, ')
          ..write('userId: $userId, ')
          ..write('planId: $planId, ')
          ..write('title: $title, ')
          ..write('startUtc: $startUtc, ')
          ..write('durationMinutes: $durationMinutes, ')
          ..write('recurrence: $recurrence, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('syncedAt: $syncedAt, ')
          ..write('deletedAt: $deletedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
      id,
      clientId,
      serverId,
      userId,
      planId,
      title,
      startUtc,
      durationMinutes,
      recurrence,
      createdAt,
      updatedAt,
      syncedAt,
      deletedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PlanTriggersTableData &&
          other.id == this.id &&
          other.clientId == this.clientId &&
          other.serverId == this.serverId &&
          other.userId == this.userId &&
          other.planId == this.planId &&
          other.title == this.title &&
          other.startUtc == this.startUtc &&
          other.durationMinutes == this.durationMinutes &&
          other.recurrence == this.recurrence &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.syncedAt == this.syncedAt &&
          other.deletedAt == this.deletedAt);
}

class PlanTriggersTableCompanion
    extends UpdateCompanion<PlanTriggersTableData> {
  final Value<int> id;
  final Value<String> clientId;
  final Value<String?> serverId;
  final Value<String> userId;
  final Value<String> planId;
  final Value<String> title;
  final Value<DateTime> startUtc;
  final Value<int> durationMinutes;
  final Value<String> recurrence;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<DateTime?> syncedAt;
  final Value<DateTime?> deletedAt;
  const PlanTriggersTableCompanion({
    this.id = const Value.absent(),
    this.clientId = const Value.absent(),
    this.serverId = const Value.absent(),
    this.userId = const Value.absent(),
    this.planId = const Value.absent(),
    this.title = const Value.absent(),
    this.startUtc = const Value.absent(),
    this.durationMinutes = const Value.absent(),
    this.recurrence = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.syncedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
  });
  PlanTriggersTableCompanion.insert({
    this.id = const Value.absent(),
    required String clientId,
    this.serverId = const Value.absent(),
    required String userId,
    required String planId,
    required String title,
    required DateTime startUtc,
    required int durationMinutes,
    this.recurrence = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.syncedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
  })  : clientId = Value(clientId),
        userId = Value(userId),
        planId = Value(planId),
        title = Value(title),
        startUtc = Value(startUtc),
        durationMinutes = Value(durationMinutes);
  static Insertable<PlanTriggersTableData> custom({
    Expression<int>? id,
    Expression<String>? clientId,
    Expression<String>? serverId,
    Expression<String>? userId,
    Expression<String>? planId,
    Expression<String>? title,
    Expression<DateTime>? startUtc,
    Expression<int>? durationMinutes,
    Expression<String>? recurrence,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<DateTime>? syncedAt,
    Expression<DateTime>? deletedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (clientId != null) 'client_id': clientId,
      if (serverId != null) 'server_id': serverId,
      if (userId != null) 'user_id': userId,
      if (planId != null) 'plan_id': planId,
      if (title != null) 'title': title,
      if (startUtc != null) 'start_utc': startUtc,
      if (durationMinutes != null) 'duration_minutes': durationMinutes,
      if (recurrence != null) 'recurrence': recurrence,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (syncedAt != null) 'synced_at': syncedAt,
      if (deletedAt != null) 'deleted_at': deletedAt,
    });
  }

  PlanTriggersTableCompanion copyWith(
      {Value<int>? id,
      Value<String>? clientId,
      Value<String?>? serverId,
      Value<String>? userId,
      Value<String>? planId,
      Value<String>? title,
      Value<DateTime>? startUtc,
      Value<int>? durationMinutes,
      Value<String>? recurrence,
      Value<DateTime>? createdAt,
      Value<DateTime>? updatedAt,
      Value<DateTime?>? syncedAt,
      Value<DateTime?>? deletedAt}) {
    return PlanTriggersTableCompanion(
      id: id ?? this.id,
      clientId: clientId ?? this.clientId,
      serverId: serverId ?? this.serverId,
      userId: userId ?? this.userId,
      planId: planId ?? this.planId,
      title: title ?? this.title,
      startUtc: startUtc ?? this.startUtc,
      durationMinutes: durationMinutes ?? this.durationMinutes,
      recurrence: recurrence ?? this.recurrence,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      syncedAt: syncedAt ?? this.syncedAt,
      deletedAt: deletedAt ?? this.deletedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (clientId.present) {
      map['client_id'] = Variable<String>(clientId.value);
    }
    if (serverId.present) {
      map['server_id'] = Variable<String>(serverId.value);
    }
    if (userId.present) {
      map['user_id'] = Variable<String>(userId.value);
    }
    if (planId.present) {
      map['plan_id'] = Variable<String>(planId.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (startUtc.present) {
      map['start_utc'] = Variable<DateTime>(startUtc.value);
    }
    if (durationMinutes.present) {
      map['duration_minutes'] = Variable<int>(durationMinutes.value);
    }
    if (recurrence.present) {
      map['recurrence'] = Variable<String>(recurrence.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (syncedAt.present) {
      map['synced_at'] = Variable<DateTime>(syncedAt.value);
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<DateTime>(deletedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PlanTriggersTableCompanion(')
          ..write('id: $id, ')
          ..write('clientId: $clientId, ')
          ..write('serverId: $serverId, ')
          ..write('userId: $userId, ')
          ..write('planId: $planId, ')
          ..write('title: $title, ')
          ..write('startUtc: $startUtc, ')
          ..write('durationMinutes: $durationMinutes, ')
          ..write('recurrence: $recurrence, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('syncedAt: $syncedAt, ')
          ..write('deletedAt: $deletedAt')
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
  late final $SessionCompletionsTableTable sessionCompletionsTable =
      $SessionCompletionsTableTable(this);
  late final $StreakFreezesTableTable streakFreezesTable =
      $StreakFreezesTableTable(this);
  late final $PlanTriggersTableTable planTriggersTable =
      $PlanTriggersTableTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
        plansTable,
        ttsCacheTable,
        executionStateTable,
        appSettingsTable,
        sessionCompletionsTable,
        streakFreezesTable,
        planTriggersTable
      ];
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
  required String id,
  required String name,
  Value<String?> description,
  Value<PlanCategory> category,
  Value<List<String>> tags,
  Value<String> defaultVoice,
  Value<List<PlanStep>> steps,
  Value<DateTime> createdAt,
  Value<DateTime> updatedAt,
  Value<DateTime?> lastUsedAt,
  Value<bool> isActive,
  Value<String> ttsStatus,
  Value<int> ttsTotal,
  Value<int> ttsCompleted,
  Value<String?> libraryId,
  Value<int> rowid,
});
typedef $$PlansTableTableUpdateCompanionBuilder = PlansTableCompanion Function({
  Value<String> id,
  Value<String> name,
  Value<String?> description,
  Value<PlanCategory> category,
  Value<List<String>> tags,
  Value<String> defaultVoice,
  Value<List<PlanStep>> steps,
  Value<DateTime> createdAt,
  Value<DateTime> updatedAt,
  Value<DateTime?> lastUsedAt,
  Value<bool> isActive,
  Value<String> ttsStatus,
  Value<int> ttsTotal,
  Value<int> ttsCompleted,
  Value<String?> libraryId,
  Value<int> rowid,
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
        .filter((f) => f.planId.id.sqlEquals($_itemColumn<String>('id')!));

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
            .filter((f) => f.planId.id.sqlEquals($_itemColumn<String>('id')!));

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
  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get name => $composableBuilder(
      column: $table.name, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get description => $composableBuilder(
      column: $table.description, builder: (column) => ColumnFilters(column));

  ColumnWithTypeConverterFilters<PlanCategory, PlanCategory, String>
      get category => $composableBuilder(
          column: $table.category,
          builder: (column) => ColumnWithTypeConverterFilters(column));

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

  ColumnFilters<bool> get isActive => $composableBuilder(
      column: $table.isActive, builder: (column) => ColumnFilters(column));

  ColumnWithTypeConverterFilters<String, String, String> get ttsStatus =>
      $composableBuilder(
          column: $table.ttsStatus,
          builder: (column) => ColumnWithTypeConverterFilters(column));

  ColumnFilters<int> get ttsTotal => $composableBuilder(
      column: $table.ttsTotal, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get ttsCompleted => $composableBuilder(
      column: $table.ttsCompleted, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get libraryId => $composableBuilder(
      column: $table.libraryId, builder: (column) => ColumnFilters(column));

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
  ColumnOrderings<String> get id => $composableBuilder(
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

  ColumnOrderings<bool> get isActive => $composableBuilder(
      column: $table.isActive, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get ttsStatus => $composableBuilder(
      column: $table.ttsStatus, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get ttsTotal => $composableBuilder(
      column: $table.ttsTotal, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get ttsCompleted => $composableBuilder(
      column: $table.ttsCompleted,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get libraryId => $composableBuilder(
      column: $table.libraryId, builder: (column) => ColumnOrderings(column));
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
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get description => $composableBuilder(
      column: $table.description, builder: (column) => column);

  GeneratedColumnWithTypeConverter<PlanCategory, String> get category =>
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

  GeneratedColumn<bool> get isActive =>
      $composableBuilder(column: $table.isActive, builder: (column) => column);

  GeneratedColumnWithTypeConverter<String, String> get ttsStatus =>
      $composableBuilder(column: $table.ttsStatus, builder: (column) => column);

  GeneratedColumn<int> get ttsTotal =>
      $composableBuilder(column: $table.ttsTotal, builder: (column) => column);

  GeneratedColumn<int> get ttsCompleted => $composableBuilder(
      column: $table.ttsCompleted, builder: (column) => column);

  GeneratedColumn<String> get libraryId =>
      $composableBuilder(column: $table.libraryId, builder: (column) => column);

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
            Value<String> id = const Value.absent(),
            Value<String> name = const Value.absent(),
            Value<String?> description = const Value.absent(),
            Value<PlanCategory> category = const Value.absent(),
            Value<List<String>> tags = const Value.absent(),
            Value<String> defaultVoice = const Value.absent(),
            Value<List<PlanStep>> steps = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
            Value<DateTime> updatedAt = const Value.absent(),
            Value<DateTime?> lastUsedAt = const Value.absent(),
            Value<bool> isActive = const Value.absent(),
            Value<String> ttsStatus = const Value.absent(),
            Value<int> ttsTotal = const Value.absent(),
            Value<int> ttsCompleted = const Value.absent(),
            Value<String?> libraryId = const Value.absent(),
            Value<int> rowid = const Value.absent(),
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
            isActive: isActive,
            ttsStatus: ttsStatus,
            ttsTotal: ttsTotal,
            ttsCompleted: ttsCompleted,
            libraryId: libraryId,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            required String name,
            Value<String?> description = const Value.absent(),
            Value<PlanCategory> category = const Value.absent(),
            Value<List<String>> tags = const Value.absent(),
            Value<String> defaultVoice = const Value.absent(),
            Value<List<PlanStep>> steps = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
            Value<DateTime> updatedAt = const Value.absent(),
            Value<DateTime?> lastUsedAt = const Value.absent(),
            Value<bool> isActive = const Value.absent(),
            Value<String> ttsStatus = const Value.absent(),
            Value<int> ttsTotal = const Value.absent(),
            Value<int> ttsCompleted = const Value.absent(),
            Value<String?> libraryId = const Value.absent(),
            Value<int> rowid = const Value.absent(),
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
            isActive: isActive,
            ttsStatus: ttsStatus,
            ttsTotal: ttsTotal,
            ttsCompleted: ttsCompleted,
            libraryId: libraryId,
            rowid: rowid,
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
  Value<String?> planId,
  Value<String> provider,
  Value<String> speechRate,
  Value<DateTime> createdAt,
});
typedef $$TtsCacheTableTableUpdateCompanionBuilder = TtsCacheTableCompanion
    Function({
  Value<int> id,
  Value<String> textHash,
  Value<String> voiceId,
  Value<String> filePath,
  Value<int> fileSizeBytes,
  Value<String?> planId,
  Value<String> provider,
  Value<String> speechRate,
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
    final $_column = $_itemColumn<String>('plan_id');
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

  ColumnFilters<String> get provider => $composableBuilder(
      column: $table.provider, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get speechRate => $composableBuilder(
      column: $table.speechRate, builder: (column) => ColumnFilters(column));

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

  ColumnOrderings<String> get provider => $composableBuilder(
      column: $table.provider, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get speechRate => $composableBuilder(
      column: $table.speechRate, builder: (column) => ColumnOrderings(column));

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

  GeneratedColumn<String> get provider =>
      $composableBuilder(column: $table.provider, builder: (column) => column);

  GeneratedColumn<String> get speechRate => $composableBuilder(
      column: $table.speechRate, builder: (column) => column);

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
            Value<String?> planId = const Value.absent(),
            Value<String> provider = const Value.absent(),
            Value<String> speechRate = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
          }) =>
              TtsCacheTableCompanion(
            id: id,
            textHash: textHash,
            voiceId: voiceId,
            filePath: filePath,
            fileSizeBytes: fileSizeBytes,
            planId: planId,
            provider: provider,
            speechRate: speechRate,
            createdAt: createdAt,
          ),
          createCompanionCallback: ({
            Value<int> id = const Value.absent(),
            required String textHash,
            required String voiceId,
            required String filePath,
            Value<int> fileSizeBytes = const Value.absent(),
            Value<String?> planId = const Value.absent(),
            Value<String> provider = const Value.absent(),
            Value<String> speechRate = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
          }) =>
              TtsCacheTableCompanion.insert(
            id: id,
            textHash: textHash,
            voiceId: voiceId,
            filePath: filePath,
            fileSizeBytes: fileSizeBytes,
            planId: planId,
            provider: provider,
            speechRate: speechRate,
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
  required String planId,
  Value<int> currentStepIndex,
  Value<String> repeatCounters,
  Value<int> elapsedMs,
  Value<int> ambientPositionMs,
  Value<String?> ambientAssetKey,
  Value<String> status,
  Value<DateTime> savedAt,
});
typedef $$ExecutionStateTableTableUpdateCompanionBuilder
    = ExecutionStateTableCompanion Function({
  Value<int> id,
  Value<String> planId,
  Value<int> currentStepIndex,
  Value<String> repeatCounters,
  Value<int> elapsedMs,
  Value<int> ambientPositionMs,
  Value<String?> ambientAssetKey,
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
    final $_column = $_itemColumn<String>('plan_id')!;

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

  ColumnFilters<String> get ambientAssetKey => $composableBuilder(
      column: $table.ambientAssetKey,
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

  ColumnOrderings<String> get ambientAssetKey => $composableBuilder(
      column: $table.ambientAssetKey,
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

  GeneratedColumn<String> get ambientAssetKey => $composableBuilder(
      column: $table.ambientAssetKey, builder: (column) => column);

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
            Value<String> planId = const Value.absent(),
            Value<int> currentStepIndex = const Value.absent(),
            Value<String> repeatCounters = const Value.absent(),
            Value<int> elapsedMs = const Value.absent(),
            Value<int> ambientPositionMs = const Value.absent(),
            Value<String?> ambientAssetKey = const Value.absent(),
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
            ambientAssetKey: ambientAssetKey,
            status: status,
            savedAt: savedAt,
          ),
          createCompanionCallback: ({
            Value<int> id = const Value.absent(),
            required String planId,
            Value<int> currentStepIndex = const Value.absent(),
            Value<String> repeatCounters = const Value.absent(),
            Value<int> elapsedMs = const Value.absent(),
            Value<int> ambientPositionMs = const Value.absent(),
            Value<String?> ambientAssetKey = const Value.absent(),
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
            ambientAssetKey: ambientAssetKey,
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
typedef $$SessionCompletionsTableTableCreateCompanionBuilder
    = SessionCompletionsTableCompanion Function({
  Value<int> id,
  required String userId,
  required String planId,
  required DateTime completedAt,
  required int durationMs,
  required String clientId,
  Value<DateTime?> syncedAt,
  Value<DateTime> createdAt,
});
typedef $$SessionCompletionsTableTableUpdateCompanionBuilder
    = SessionCompletionsTableCompanion Function({
  Value<int> id,
  Value<String> userId,
  Value<String> planId,
  Value<DateTime> completedAt,
  Value<int> durationMs,
  Value<String> clientId,
  Value<DateTime?> syncedAt,
  Value<DateTime> createdAt,
});

class $$SessionCompletionsTableTableFilterComposer
    extends Composer<_$AppDatabase, $SessionCompletionsTableTable> {
  $$SessionCompletionsTableTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get userId => $composableBuilder(
      column: $table.userId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get planId => $composableBuilder(
      column: $table.planId, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get completedAt => $composableBuilder(
      column: $table.completedAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get durationMs => $composableBuilder(
      column: $table.durationMs, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get clientId => $composableBuilder(
      column: $table.clientId, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get syncedAt => $composableBuilder(
      column: $table.syncedAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnFilters(column));
}

class $$SessionCompletionsTableTableOrderingComposer
    extends Composer<_$AppDatabase, $SessionCompletionsTableTable> {
  $$SessionCompletionsTableTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get userId => $composableBuilder(
      column: $table.userId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get planId => $composableBuilder(
      column: $table.planId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get completedAt => $composableBuilder(
      column: $table.completedAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get durationMs => $composableBuilder(
      column: $table.durationMs, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get clientId => $composableBuilder(
      column: $table.clientId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get syncedAt => $composableBuilder(
      column: $table.syncedAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnOrderings(column));
}

class $$SessionCompletionsTableTableAnnotationComposer
    extends Composer<_$AppDatabase, $SessionCompletionsTableTable> {
  $$SessionCompletionsTableTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get userId =>
      $composableBuilder(column: $table.userId, builder: (column) => column);

  GeneratedColumn<String> get planId =>
      $composableBuilder(column: $table.planId, builder: (column) => column);

  GeneratedColumn<DateTime> get completedAt => $composableBuilder(
      column: $table.completedAt, builder: (column) => column);

  GeneratedColumn<int> get durationMs => $composableBuilder(
      column: $table.durationMs, builder: (column) => column);

  GeneratedColumn<String> get clientId =>
      $composableBuilder(column: $table.clientId, builder: (column) => column);

  GeneratedColumn<DateTime> get syncedAt =>
      $composableBuilder(column: $table.syncedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$SessionCompletionsTableTableTableManager extends RootTableManager<
    _$AppDatabase,
    $SessionCompletionsTableTable,
    SessionCompletionsTableData,
    $$SessionCompletionsTableTableFilterComposer,
    $$SessionCompletionsTableTableOrderingComposer,
    $$SessionCompletionsTableTableAnnotationComposer,
    $$SessionCompletionsTableTableCreateCompanionBuilder,
    $$SessionCompletionsTableTableUpdateCompanionBuilder,
    (
      SessionCompletionsTableData,
      BaseReferences<_$AppDatabase, $SessionCompletionsTableTable,
          SessionCompletionsTableData>
    ),
    SessionCompletionsTableData,
    PrefetchHooks Function()> {
  $$SessionCompletionsTableTableTableManager(
      _$AppDatabase db, $SessionCompletionsTableTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SessionCompletionsTableTableFilterComposer(
                  $db: db, $table: table),
          createOrderingComposer: () =>
              $$SessionCompletionsTableTableOrderingComposer(
                  $db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SessionCompletionsTableTableAnnotationComposer(
                  $db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<String> userId = const Value.absent(),
            Value<String> planId = const Value.absent(),
            Value<DateTime> completedAt = const Value.absent(),
            Value<int> durationMs = const Value.absent(),
            Value<String> clientId = const Value.absent(),
            Value<DateTime?> syncedAt = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
          }) =>
              SessionCompletionsTableCompanion(
            id: id,
            userId: userId,
            planId: planId,
            completedAt: completedAt,
            durationMs: durationMs,
            clientId: clientId,
            syncedAt: syncedAt,
            createdAt: createdAt,
          ),
          createCompanionCallback: ({
            Value<int> id = const Value.absent(),
            required String userId,
            required String planId,
            required DateTime completedAt,
            required int durationMs,
            required String clientId,
            Value<DateTime?> syncedAt = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
          }) =>
              SessionCompletionsTableCompanion.insert(
            id: id,
            userId: userId,
            planId: planId,
            completedAt: completedAt,
            durationMs: durationMs,
            clientId: clientId,
            syncedAt: syncedAt,
            createdAt: createdAt,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$SessionCompletionsTableTableProcessedTableManager
    = ProcessedTableManager<
        _$AppDatabase,
        $SessionCompletionsTableTable,
        SessionCompletionsTableData,
        $$SessionCompletionsTableTableFilterComposer,
        $$SessionCompletionsTableTableOrderingComposer,
        $$SessionCompletionsTableTableAnnotationComposer,
        $$SessionCompletionsTableTableCreateCompanionBuilder,
        $$SessionCompletionsTableTableUpdateCompanionBuilder,
        (
          SessionCompletionsTableData,
          BaseReferences<_$AppDatabase, $SessionCompletionsTableTable,
              SessionCompletionsTableData>
        ),
        SessionCompletionsTableData,
        PrefetchHooks Function()>;
typedef $$StreakFreezesTableTableCreateCompanionBuilder
    = StreakFreezesTableCompanion Function({
  Value<int> id,
  required String userId,
  required DateTime frozenAt,
  required DateTime expiresAt,
  Value<DateTime?> consumedAt,
  Value<DateTime> createdAt,
});
typedef $$StreakFreezesTableTableUpdateCompanionBuilder
    = StreakFreezesTableCompanion Function({
  Value<int> id,
  Value<String> userId,
  Value<DateTime> frozenAt,
  Value<DateTime> expiresAt,
  Value<DateTime?> consumedAt,
  Value<DateTime> createdAt,
});

class $$StreakFreezesTableTableFilterComposer
    extends Composer<_$AppDatabase, $StreakFreezesTableTable> {
  $$StreakFreezesTableTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get userId => $composableBuilder(
      column: $table.userId, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get frozenAt => $composableBuilder(
      column: $table.frozenAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get expiresAt => $composableBuilder(
      column: $table.expiresAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get consumedAt => $composableBuilder(
      column: $table.consumedAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnFilters(column));
}

class $$StreakFreezesTableTableOrderingComposer
    extends Composer<_$AppDatabase, $StreakFreezesTableTable> {
  $$StreakFreezesTableTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get userId => $composableBuilder(
      column: $table.userId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get frozenAt => $composableBuilder(
      column: $table.frozenAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get expiresAt => $composableBuilder(
      column: $table.expiresAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get consumedAt => $composableBuilder(
      column: $table.consumedAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnOrderings(column));
}

class $$StreakFreezesTableTableAnnotationComposer
    extends Composer<_$AppDatabase, $StreakFreezesTableTable> {
  $$StreakFreezesTableTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get userId =>
      $composableBuilder(column: $table.userId, builder: (column) => column);

  GeneratedColumn<DateTime> get frozenAt =>
      $composableBuilder(column: $table.frozenAt, builder: (column) => column);

  GeneratedColumn<DateTime> get expiresAt =>
      $composableBuilder(column: $table.expiresAt, builder: (column) => column);

  GeneratedColumn<DateTime> get consumedAt => $composableBuilder(
      column: $table.consumedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$StreakFreezesTableTableTableManager extends RootTableManager<
    _$AppDatabase,
    $StreakFreezesTableTable,
    StreakFreezesTableData,
    $$StreakFreezesTableTableFilterComposer,
    $$StreakFreezesTableTableOrderingComposer,
    $$StreakFreezesTableTableAnnotationComposer,
    $$StreakFreezesTableTableCreateCompanionBuilder,
    $$StreakFreezesTableTableUpdateCompanionBuilder,
    (
      StreakFreezesTableData,
      BaseReferences<_$AppDatabase, $StreakFreezesTableTable,
          StreakFreezesTableData>
    ),
    StreakFreezesTableData,
    PrefetchHooks Function()> {
  $$StreakFreezesTableTableTableManager(
      _$AppDatabase db, $StreakFreezesTableTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$StreakFreezesTableTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$StreakFreezesTableTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$StreakFreezesTableTableAnnotationComposer(
                  $db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<String> userId = const Value.absent(),
            Value<DateTime> frozenAt = const Value.absent(),
            Value<DateTime> expiresAt = const Value.absent(),
            Value<DateTime?> consumedAt = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
          }) =>
              StreakFreezesTableCompanion(
            id: id,
            userId: userId,
            frozenAt: frozenAt,
            expiresAt: expiresAt,
            consumedAt: consumedAt,
            createdAt: createdAt,
          ),
          createCompanionCallback: ({
            Value<int> id = const Value.absent(),
            required String userId,
            required DateTime frozenAt,
            required DateTime expiresAt,
            Value<DateTime?> consumedAt = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
          }) =>
              StreakFreezesTableCompanion.insert(
            id: id,
            userId: userId,
            frozenAt: frozenAt,
            expiresAt: expiresAt,
            consumedAt: consumedAt,
            createdAt: createdAt,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$StreakFreezesTableTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $StreakFreezesTableTable,
    StreakFreezesTableData,
    $$StreakFreezesTableTableFilterComposer,
    $$StreakFreezesTableTableOrderingComposer,
    $$StreakFreezesTableTableAnnotationComposer,
    $$StreakFreezesTableTableCreateCompanionBuilder,
    $$StreakFreezesTableTableUpdateCompanionBuilder,
    (
      StreakFreezesTableData,
      BaseReferences<_$AppDatabase, $StreakFreezesTableTable,
          StreakFreezesTableData>
    ),
    StreakFreezesTableData,
    PrefetchHooks Function()>;
typedef $$PlanTriggersTableTableCreateCompanionBuilder
    = PlanTriggersTableCompanion Function({
  Value<int> id,
  required String clientId,
  Value<String?> serverId,
  required String userId,
  required String planId,
  required String title,
  required DateTime startUtc,
  required int durationMinutes,
  Value<String> recurrence,
  Value<DateTime> createdAt,
  Value<DateTime> updatedAt,
  Value<DateTime?> syncedAt,
  Value<DateTime?> deletedAt,
});
typedef $$PlanTriggersTableTableUpdateCompanionBuilder
    = PlanTriggersTableCompanion Function({
  Value<int> id,
  Value<String> clientId,
  Value<String?> serverId,
  Value<String> userId,
  Value<String> planId,
  Value<String> title,
  Value<DateTime> startUtc,
  Value<int> durationMinutes,
  Value<String> recurrence,
  Value<DateTime> createdAt,
  Value<DateTime> updatedAt,
  Value<DateTime?> syncedAt,
  Value<DateTime?> deletedAt,
});

class $$PlanTriggersTableTableFilterComposer
    extends Composer<_$AppDatabase, $PlanTriggersTableTable> {
  $$PlanTriggersTableTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get clientId => $composableBuilder(
      column: $table.clientId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get serverId => $composableBuilder(
      column: $table.serverId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get userId => $composableBuilder(
      column: $table.userId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get planId => $composableBuilder(
      column: $table.planId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get title => $composableBuilder(
      column: $table.title, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get startUtc => $composableBuilder(
      column: $table.startUtc, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get durationMinutes => $composableBuilder(
      column: $table.durationMinutes,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get recurrence => $composableBuilder(
      column: $table.recurrence, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get syncedAt => $composableBuilder(
      column: $table.syncedAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get deletedAt => $composableBuilder(
      column: $table.deletedAt, builder: (column) => ColumnFilters(column));
}

class $$PlanTriggersTableTableOrderingComposer
    extends Composer<_$AppDatabase, $PlanTriggersTableTable> {
  $$PlanTriggersTableTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get clientId => $composableBuilder(
      column: $table.clientId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get serverId => $composableBuilder(
      column: $table.serverId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get userId => $composableBuilder(
      column: $table.userId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get planId => $composableBuilder(
      column: $table.planId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get title => $composableBuilder(
      column: $table.title, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get startUtc => $composableBuilder(
      column: $table.startUtc, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get durationMinutes => $composableBuilder(
      column: $table.durationMinutes,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get recurrence => $composableBuilder(
      column: $table.recurrence, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get syncedAt => $composableBuilder(
      column: $table.syncedAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get deletedAt => $composableBuilder(
      column: $table.deletedAt, builder: (column) => ColumnOrderings(column));
}

class $$PlanTriggersTableTableAnnotationComposer
    extends Composer<_$AppDatabase, $PlanTriggersTableTable> {
  $$PlanTriggersTableTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get clientId =>
      $composableBuilder(column: $table.clientId, builder: (column) => column);

  GeneratedColumn<String> get serverId =>
      $composableBuilder(column: $table.serverId, builder: (column) => column);

  GeneratedColumn<String> get userId =>
      $composableBuilder(column: $table.userId, builder: (column) => column);

  GeneratedColumn<String> get planId =>
      $composableBuilder(column: $table.planId, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<DateTime> get startUtc =>
      $composableBuilder(column: $table.startUtc, builder: (column) => column);

  GeneratedColumn<int> get durationMinutes => $composableBuilder(
      column: $table.durationMinutes, builder: (column) => column);

  GeneratedColumn<String> get recurrence => $composableBuilder(
      column: $table.recurrence, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get syncedAt =>
      $composableBuilder(column: $table.syncedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);
}

class $$PlanTriggersTableTableTableManager extends RootTableManager<
    _$AppDatabase,
    $PlanTriggersTableTable,
    PlanTriggersTableData,
    $$PlanTriggersTableTableFilterComposer,
    $$PlanTriggersTableTableOrderingComposer,
    $$PlanTriggersTableTableAnnotationComposer,
    $$PlanTriggersTableTableCreateCompanionBuilder,
    $$PlanTriggersTableTableUpdateCompanionBuilder,
    (
      PlanTriggersTableData,
      BaseReferences<_$AppDatabase, $PlanTriggersTableTable,
          PlanTriggersTableData>
    ),
    PlanTriggersTableData,
    PrefetchHooks Function()> {
  $$PlanTriggersTableTableTableManager(
      _$AppDatabase db, $PlanTriggersTableTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PlanTriggersTableTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PlanTriggersTableTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PlanTriggersTableTableAnnotationComposer(
                  $db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<String> clientId = const Value.absent(),
            Value<String?> serverId = const Value.absent(),
            Value<String> userId = const Value.absent(),
            Value<String> planId = const Value.absent(),
            Value<String> title = const Value.absent(),
            Value<DateTime> startUtc = const Value.absent(),
            Value<int> durationMinutes = const Value.absent(),
            Value<String> recurrence = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
            Value<DateTime> updatedAt = const Value.absent(),
            Value<DateTime?> syncedAt = const Value.absent(),
            Value<DateTime?> deletedAt = const Value.absent(),
          }) =>
              PlanTriggersTableCompanion(
            id: id,
            clientId: clientId,
            serverId: serverId,
            userId: userId,
            planId: planId,
            title: title,
            startUtc: startUtc,
            durationMinutes: durationMinutes,
            recurrence: recurrence,
            createdAt: createdAt,
            updatedAt: updatedAt,
            syncedAt: syncedAt,
            deletedAt: deletedAt,
          ),
          createCompanionCallback: ({
            Value<int> id = const Value.absent(),
            required String clientId,
            Value<String?> serverId = const Value.absent(),
            required String userId,
            required String planId,
            required String title,
            required DateTime startUtc,
            required int durationMinutes,
            Value<String> recurrence = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
            Value<DateTime> updatedAt = const Value.absent(),
            Value<DateTime?> syncedAt = const Value.absent(),
            Value<DateTime?> deletedAt = const Value.absent(),
          }) =>
              PlanTriggersTableCompanion.insert(
            id: id,
            clientId: clientId,
            serverId: serverId,
            userId: userId,
            planId: planId,
            title: title,
            startUtc: startUtc,
            durationMinutes: durationMinutes,
            recurrence: recurrence,
            createdAt: createdAt,
            updatedAt: updatedAt,
            syncedAt: syncedAt,
            deletedAt: deletedAt,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$PlanTriggersTableTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $PlanTriggersTableTable,
    PlanTriggersTableData,
    $$PlanTriggersTableTableFilterComposer,
    $$PlanTriggersTableTableOrderingComposer,
    $$PlanTriggersTableTableAnnotationComposer,
    $$PlanTriggersTableTableCreateCompanionBuilder,
    $$PlanTriggersTableTableUpdateCompanionBuilder,
    (
      PlanTriggersTableData,
      BaseReferences<_$AppDatabase, $PlanTriggersTableTable,
          PlanTriggersTableData>
    ),
    PlanTriggersTableData,
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
  $$SessionCompletionsTableTableTableManager get sessionCompletionsTable =>
      $$SessionCompletionsTableTableTableManager(
          _db, _db.sessionCompletionsTable);
  $$StreakFreezesTableTableTableManager get streakFreezesTable =>
      $$StreakFreezesTableTableTableManager(_db, _db.streakFreezesTable);
  $$PlanTriggersTableTableTableManager get planTriggersTable =>
      $$PlanTriggersTableTableTableManager(_db, _db.planTriggersTable);
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
