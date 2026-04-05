import 'package:drift/drift.dart';

/// Drift table for app-wide user preferences.
///
/// Uses a single-row key/value approach so new settings can be added without
/// schema migrations that touch existing Plan data.
class AppSettingsTable extends Table {
  @override
  String get tableName => 'app_settings';

  IntColumn get id => integer().autoIncrement()();

  /// The settings key identifier.
  TextColumn get key => text().unique()();

  /// The settings value serialised as a string.
  TextColumn get value => text()();

  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
}
