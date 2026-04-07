import 'package:drift/drift.dart';

import 'package:instructor/database/tables/plans_table.dart';

/// Drift table definition for the TTS audio file cache.
///
/// Cache keys are SHA-256 hashes of all synthesis parameters (text, voice,
/// locale, provider, speechRate) so that any parameter change produces fresh
/// audio.
///
/// ## Schema version 2
/// Added [provider] and [speechRate] columns (defaulting to 'gemini' and '1.0'
/// respectively) to support multi-provider caching. The [textHash] column now
/// stores the full-parameter hash produced by [fullParamCacheKey].
class TtsCacheTable extends Table {
  @override
  String get tableName => 'tts_cache';

  IntColumn get id => integer().autoIncrement()();

  /// SHA-256 hash of all synthesis parameters — the deduplication key.
  ///
  /// From schema v2 onwards this is computed by [fullParamCacheKey]
  /// (JSON-serialised, alphabetical keys). Older rows stored the legacy
  /// `provider:voiceId:text` hash; they remain valid but will be superseded.
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

  /// TTS provider that generated this audio (e.g. 'gemini', 'kokoro').
  ///
  /// Added in schema v2. Defaults to 'gemini' for rows migrated from v1.
  TextColumn get provider =>
      text().withDefault(const Constant('gemini'))();

  /// Speech rate at which the audio was generated (e.g. '1.0').
  ///
  /// Added in schema v2. Defaults to '1.0' (normal speed) for v1 rows.
  TextColumn get speechRate =>
      text().withDefault(const Constant('1.0'))();

  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}
