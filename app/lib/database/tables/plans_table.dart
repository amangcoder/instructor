import 'package:drift/drift.dart';

import 'package:instructor/database/type_converters.dart';

/// Drift table definition for Plans.
///
/// Steps are stored as a JSON text column via [StepListConverter] to avoid
/// complex recursive SQL schemas for nested [RepeatStep] blocks.
/// Tags are stored as a JSON array string via [StringListConverter].
class PlansTable extends Table {
  @override
  String get tableName => 'plans';

  @override
  Set<Column> get primaryKey => {id};

  /// Server-assigned UUID primary key.
  TextColumn get id => text()();

  TextColumn get name => text().withLength(min: 1, max: 100)();

  TextColumn get description => text().nullable()();

  /// [PlanCategory] stored as its string name.
  TextColumn get category => text().withDefault(const Constant('custom'))();

  /// JSON array of tag strings.
  TextColumn get tags =>
      text().map(const StringListConverter()).withDefault(const Constant('[]'))();

  /// Voice identifier string (OpenAI voice name or 'platform').
  TextColumn get defaultVoice => text().withDefault(const Constant('aoede'))();

  /// JSON-encoded list of [PlanStep] objects.
  TextColumn get steps =>
      text().map(const StepListConverter()).withDefault(const Constant('[]'))();

  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  DateTimeColumn get lastUsedAt => dateTime().nullable()();

  /// Whether this plan has been activated for GenAI TTS generation.
  BoolColumn get isActive => boolean().withDefault(const Constant(false))();

  /// TTS generation status: 'none', 'pending', 'processing', 'completed', 'failed'.
  TextColumn get ttsStatus => text().withDefault(const Constant('none'))();

  /// Total number of TTS audio files to generate for this plan.
  IntColumn get ttsTotal => integer().withDefault(const Constant(0))();

  /// Number of TTS audio files successfully generated so far.
  IntColumn get ttsCompleted => integer().withDefault(const Constant(0))();
}
