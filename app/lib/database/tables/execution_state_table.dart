import 'package:drift/drift.dart';

import 'package:instructor/database/tables/plans_table.dart';

/// Drift table definition for persisted execution state.
///
/// Rows are written on every step transition so that the [PlanExecutionEngine]
/// can recover from app crashes or backgrounding. At most one row should exist
/// at any time; it is deleted when the session ends normally.
class ExecutionStateTable extends Table {
  @override
  String get tableName => 'execution_state';

  IntColumn get id => integer().autoIncrement()();

  IntColumn get planId =>
      integer().references(PlansTable, #id, onDelete: KeyAction.cascade)();

  /// Index into the Plan's flattened step list.
  IntColumn get currentStepIndex => integer().withDefault(const Constant(0))();

  /// JSON-encoded map of repeatStepId → current iteration count.
  TextColumn get repeatCounters =>
      text().withDefault(const Constant('{}'))();

  /// Total elapsed time in milliseconds since the Plan started.
  IntColumn get elapsedMs => integer().withDefault(const Constant(0))();

  /// Ambient audio playback position in milliseconds for resume-after-interrupt.
  IntColumn get ambientPositionMs =>
      integer().withDefault(const Constant(0))();

  /// [ExecutionStatus] name string.
  TextColumn get status => text().withDefault(const Constant('paused'))();

  DateTimeColumn get savedAt => dateTime().withDefault(currentDateAndTime)();
}
