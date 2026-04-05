import 'package:drift/drift.dart';

import 'package:instructor/database/tables/plans_table.dart';

/// Drift table definition for the TTS audio file cache.
///
/// Cache keys are SHA-256 hashes of (voiceId + text) so that identical text
/// across multiple Plans shares a single audio file.
class TtsCacheTable extends Table {
  @override
  String get tableName => 'tts_cache';

  IntColumn get id => integer().autoIncrement()();

  /// SHA-256 hash of (voiceId + ":" + text) — used as the deduplication key.
  TextColumn get textHash => text().unique()();

  TextColumn get voiceId => text()();

  /// Absolute path to the cached audio file on local storage.
  TextColumn get filePath => text()();

  /// Size of the audio file in bytes.
  IntColumn get fileSizeBytes => integer().withDefault(const Constant(0))();

  /// Optional reference back to the owning Plan for bulk cache eviction.
  IntColumn get planId => integer()
      .nullable()
      .references(PlansTable, #id, onDelete: KeyAction.setNull)();

  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}
