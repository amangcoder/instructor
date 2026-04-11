import 'package:drift/drift.dart';

/// Stores the full TTS provider catalog JSON response from GET /api/tts/providers,
/// along with a [fetchedAt] timestamp used to enforce the 24-hour local TTL.
///
/// Only a single row is kept (id = 1). On every refresh the row is replaced
/// via INSERT OR REPLACE.
class ProviderCatalogTable extends Table {
  @override
  String get tableName => 'provider_catalog';

  /// Primary key — always 1 (single-row table).
  IntColumn get id => integer().withDefault(const Constant(1))();

  /// Full JSON-encoded catalog from GET /api/tts/providers.
  ///
  /// Structure:
  /// ```json
  /// { "providers": [ { "id": "gemini", "label": "...", "voices": [...], ... } ] }
  /// ```
  TextColumn get catalogJson => text()();

  /// UTC timestamp of the last successful catalog fetch from the server.
  DateTimeColumn get fetchedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}
