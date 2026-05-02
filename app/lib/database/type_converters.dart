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

/// Validates that a TTS status string column contains only known values.
///
/// Known values: 'none', 'pending', 'processing', 'completed', 'failed'.
///
/// Throws [StateError] for any unrecognised value, preventing silent data
/// corruption caused by out-of-range strings entering the Dart layer.
class TtsStatusConverter extends TypeConverter<String, String> {
  const TtsStatusConverter();

  static const _validValues = {
    'none',
    'pending',
    'processing',
    'completed',
    'failed',
  };

  @override
  String fromSql(String fromDb) {
    if (!_validValues.contains(fromDb)) {
      throw StateError(
        'Unknown TTS status value: "$fromDb". '
        'Expected one of: ${_validValues.join(', ')}',
      );
    }
    return fromDb;
  }

  @override
  String toSql(String value) {
    if (!_validValues.contains(value)) {
      throw StateError(
        'Unknown TTS status value: "$value". '
        'Expected one of: ${_validValues.join(', ')}',
      );
    }
    return value;
  }
}

/// Pass-through converter — category is stored and retrieved as a plain slug string.
class PlanCategoryConverter extends TypeConverter<String, String> {
  const PlanCategoryConverter();

  @override
  String fromSql(String fromDb) => fromDb;

  @override
  String toSql(String value) => value;
}
