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

  IntColumn get id => integer().autoIncrement()();

  TextColumn get name => text().withLength(min: 1, max: 100)();

  TextColumn get description => text().nullable()();

  /// [PlanCategory] stored as its string name.
  TextColumn get category => text().withDefault(const Constant('custom'))();

  /// JSON array of tag strings.
  TextColumn get tags =>
      text().map(const StringListConverter()).withDefault(const Constant('[]'))();

  /// Voice identifier string (OpenAI voice name or 'platform').
  TextColumn get defaultVoice => text().withDefault(const Constant('nova'))();

  /// JSON-encoded list of [PlanStep] objects.
  TextColumn get steps =>
      text().map(const StepListConverter()).withDefault(const Constant('[]'))();

  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  DateTimeColumn get lastUsedAt => dateTime().nullable()();
}
