// Plan-trigger sync service — pushes dirty local rows to the backend and
// pulls the authoritative server view, reconciling with the local Drift
// store and re-arming the native scheduler as needed.
//
// ## Contract
//
//   * `push()` — uploads every local row whose updatedAt > syncedAt (or
//     whose syncedAt is null) via POST /api/sync/triggers, then stamps the
//     returned server id + updatedAt onto each local row to clear dirty.
//   * `pull({since})` — fetches GET /api/sync/triggers?since=…, upserts each
//     row locally, and either arms the native alarm (new rows) or cancels it
//     (tombstones). Returns the largest server updatedAt so the caller can
//     stamp it as the next "since" cursor.
//
// Both directions are idempotent and safe to retry on failure — the server
// upsert is keyed on (userId, clientId) and the local store is keyed on
// clientId.

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:instructor/database/app_database.dart';
import 'package:instructor/repositories/plan_trigger_repository.dart';
import 'package:instructor/services/api_client.dart';
import 'package:instructor/services/calendar_service.dart' show CalendarRecurrence;
import 'package:instructor/services/plan_trigger_service.dart';

part 'plan_trigger_sync_service.g.dart';

class PlanTriggerSyncService {
  PlanTriggerSyncService({
    required ApiClient api,
    required PlanTriggerRepository repo,
    required PlanTriggerService triggers,
  })  : _api = api,
        _repo = repo,
        _triggers = triggers;

  final ApiClient _api;
  final PlanTriggerRepository _repo;
  final PlanTriggerService _triggers;

  /// Pushes every dirty (never-synced or locally-updated) row for [userId].
  /// Returns the number of rows successfully pushed.
  Future<int> push(String userId) async {
    final dirty = await _repo.getDirty(userId);
    if (dirty.isEmpty) return 0;

    final body = {
      'triggers': dirty.map(_rowToJson).toList(),
    };

    final uri = Uri.parse('${_api.backendBaseUrl}/sync/triggers');
    final response = await _api.postJson(uri, body);

    final rows = (response['triggers'] as List?) ?? const [];
    for (final raw in rows) {
      if (raw is! Map<String, dynamic>) continue;
      final clientId = raw['clientId'] as String?;
      final serverId = raw['id'] as String?;
      final updatedAt = _parseIso(raw['updatedAt']);
      if (clientId == null || serverId == null || updatedAt == null) continue;
      await _repo.markSynced(
        clientId: clientId,
        serverId: serverId,
        serverUpdatedAt: updatedAt,
      );
    }

    await _repo.purgeSyncedTombstones();
    return rows.length;
  }

  /// Pulls server-authoritative triggers updated since [since], writes them
  /// into Drift, and arms / cancels the native scheduler accordingly.
  ///
  /// Returns the newest server `updatedAt` so the caller can stamp it as the
  /// next cursor, or null if no rows were returned.
  Future<DateTime?> pull(String userId, {DateTime? since}) async {
    final uri = Uri.parse(
      '${_api.backendBaseUrl}/sync/triggers'
      '${since != null ? '?since=${Uri.encodeQueryComponent(since.toUtc().toIso8601String())}' : ''}',
    );
    final response = await _api.getJson(uri);
    final rows = (response['triggers'] as List?) ?? const [];
    if (rows.isEmpty) return null;

    DateTime? newestUpdated;
    for (final raw in rows) {
      if (raw is! Map<String, dynamic>) continue;
      final server = _parseServerRow(raw);
      if (server == null) continue;

      await _applyServerRow(userId, server);

      if (newestUpdated == null || server.updatedAt.isAfter(newestUpdated)) {
        newestUpdated = server.updatedAt;
      }
    }
    return newestUpdated;
  }

  // ── Helpers ──────────────────────────────────────────────────────────────

  Future<void> _applyServerRow(String userId, _ServerTrigger s) async {
    // Tombstone from the server — cancel the native alarm and soft-delete the
    // local row (tracked as already synced, since the delete originated upstream).
    if (s.deletedAt != null) {
      await _triggers.cancel(s.clientId);
      await _repo.markSynced(
        clientId: s.clientId,
        serverId: s.id,
        serverUpdatedAt: s.updatedAt,
      );
      return;
    }

    // Live row from the server — upsert locally and arm the native alarm.
    // Skip arming if the scheduled start is already in the past (non-recurring);
    // PlanTriggerService.rescheduleAll() will also skip these.
    await _repo.upsert(
      clientId: s.clientId,
      userId: userId,
      planId: s.planId,
      title: s.title,
      startUtc: s.startUtc,
      durationMinutes: s.durationMinutes,
      recurrence: s.recurrence.channelValue,
      serverId: s.id,
    );
    await _repo.markSynced(
      clientId: s.clientId,
      serverId: s.id,
      serverUpdatedAt: s.updatedAt,
    );

    // Re-arm via rescheduleAll so platform-specific logic (Android alarm vs
    // iOS notification) lives in one place.
    await _triggers
        .schedule(
          id: s.clientId,
          userId: userId,
          planId: s.planId,
          title: s.title,
          start: s.startUtc,
          durationMinutes: s.durationMinutes,
          recurrence: s.recurrence,
        )
        .catchError((Object e, StackTrace st) {
      debugPrint('[PlanTriggerSync] arm failed for ${s.clientId}: $e');
      return PlanTriggerScheduleResult.failed;
    });
  }

  Map<String, dynamic> _rowToJson(PlanTriggersTableData r) => {
        'clientId': r.clientId,
        'planId': r.planId,
        'title': r.title,
        'startUtc': r.startUtc.toUtc().toIso8601String(),
        'durationMinutes': r.durationMinutes,
        'recurrence': r.recurrence,
        'deletedAt': r.deletedAt?.toUtc().toIso8601String(),
        'updatedAt': r.updatedAt.toUtc().toIso8601String(),
      };

  _ServerTrigger? _parseServerRow(Map<String, dynamic> raw) {
    final id = raw['id'] as String?;
    final clientId = raw['clientId'] as String?;
    final planId = raw['planId'] as String?;
    final title = raw['title'] as String?;
    final startUtc = _parseIso(raw['startUtc']);
    final durationMinutes = raw['durationMinutes'];
    final recurrenceStr = raw['recurrence'] as String?;
    final updatedAt = _parseIso(raw['updatedAt']);
    if (id == null ||
        clientId == null ||
        planId == null ||
        title == null ||
        startUtc == null ||
        durationMinutes is! int ||
        recurrenceStr == null ||
        updatedAt == null) {
      return null;
    }
    return _ServerTrigger(
      id: id,
      clientId: clientId,
      planId: planId,
      title: title,
      startUtc: startUtc,
      durationMinutes: durationMinutes,
      recurrence: CalendarRecurrence.values.firstWhere(
        (r) => r.channelValue == recurrenceStr,
        orElse: () => CalendarRecurrence.none,
      ),
      deletedAt: _parseIso(raw['deletedAt']),
      updatedAt: updatedAt,
    );
  }

  DateTime? _parseIso(Object? v) {
    if (v is! String || v.isEmpty) return null;
    return DateTime.tryParse(v);
  }
}

class _ServerTrigger {
  const _ServerTrigger({
    required this.id,
    required this.clientId,
    required this.planId,
    required this.title,
    required this.startUtc,
    required this.durationMinutes,
    required this.recurrence,
    required this.deletedAt,
    required this.updatedAt,
  });

  final String id;
  final String clientId;
  final String planId;
  final String title;
  final DateTime startUtc;
  final int durationMinutes;
  final CalendarRecurrence recurrence;
  final DateTime? deletedAt;
  final DateTime updatedAt;
}

@Riverpod(keepAlive: true)
PlanTriggerSyncService planTriggerSyncService(Ref ref) {
  return PlanTriggerSyncService(
    api: ref.watch(apiClientProvider),
    repo: ref.watch(planTriggerRepositoryProvider),
    triggers: ref.watch(planTriggerServiceProvider),
  );
}
