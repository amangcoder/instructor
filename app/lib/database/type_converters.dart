import 'dart:convert';

import 'package:drift/drift.dart';

import 'package:instructor/models/plan_step.dart';

/// Converts a [List<PlanStep>] to/from a JSON string for storage in a Drift
/// text column.
///
/// Each [PlanStep] is serialised via [PlanStep.toJson] (freezed + json_serializable)
/// and stored as a JSON array string. This avoids complex normalised schemas
/// for deeply nested [RepeatStep] hierarchies.
class StepListConverter extends TypeConverter<List<PlanStep>, String> {
  const StepListConverter();

  @override
  List<PlanStep> fromSql(String fromDb) {
    final list = jsonDecode(fromDb) as List<dynamic>;
    return list
        .map((e) => PlanStep.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  @override
  String toSql(List<PlanStep> value) {
    return jsonEncode(value.map((s) => s.toJson()).toList());
  }
}

/// Converts a [List<String>] to/from a JSON array string.
class StringListConverter extends TypeConverter<List<String>, String> {
  const StringListConverter();

  @override
  List<String> fromSql(String fromDb) {
    final list = jsonDecode(fromDb) as List<dynamic>;
    return list.cast<String>();
  }

  @override
  String toSql(List<String> value) => jsonEncode(value);
}
