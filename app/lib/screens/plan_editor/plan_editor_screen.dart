import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

import 'package:instructor/models/enums.dart';
import 'package:instructor/models/plan.dart';
import 'package:instructor/models/plan_step.dart';
import 'package:instructor/repositories/plan_repository.dart';
import 'package:instructor/router.dart';
import 'package:instructor/services/plan_execution_engine.dart';
import 'package:instructor/services/tts_service.dart';

import 'widgets/plan_metadata_sheet.dart';
import 'widgets/repeat_block_card.dart';
import 'widgets/step_card.dart';
import 'widgets/step_insert_button.dart';

const _uuid = Uuid();

// ─────────────────────────────────────────────────────────────────────────────
// PlanEditorScreen
// ─────────────────────────────────────────────────────────────────────────────

/// Full Plan editor screen.
///
/// - When [planId] is null a new blank Plan is created.
/// - When [planId] is provided the existing Plan is loaded for editing.
///
/// ## Layout (top → bottom)
/// 1. [AppBar] — Plan name (or "New Plan") + metadata and save actions
/// 2. Sticky [_DurationHeader] — total computed duration; updates in real-time
/// 3. [ReorderableListView.builder] — step cards with inline editing and
///    [StepInsertButton]s between every pair of adjacent cards
class PlanEditorScreen extends ConsumerStatefulWidget {
  const PlanEditorScreen({super.key, this.planId});

  /// When non-null the editor loads this Plan for editing.
  final int? planId;

  @override
  ConsumerState<PlanEditorScreen> createState() => _PlanEditorScreenState();
}

class _PlanEditorScreenState extends ConsumerState<PlanEditorScreen> {
  // ── Loading / saving state ────────────────────────────────────────────────
  bool _isLoading = false;
  bool _isSaving = false;
  bool _isDownloading = false;
  String? _loadError;

  // ── Download progress state ───────────────────────────────────────────────
  int _downloadedCount = 0;
  int _downloadTotal = 0;
  bool _downloadComplete = false;
  Timer? _downloadCompleteTimer;

  // ── Plan metadata ─────────────────────────────────────────────────────────
  String _name = '';
  String _description = '';
  PlanCategory _category = PlanCategory.custom;
  List<String> _tags = [];
  String _defaultVoice = 'aoede';

  // Original timestamps (preserved when editing an existing plan)
  DateTime? _originalCreatedAt;
  DateTime? _originalLastUsedAt;

  // ── Steps ─────────────────────────────────────────────────────────────────
  List<PlanStep> _steps = [];

  /// ID of the currently expanded step card (only one at a time).
  String? _expandedStepId;

  // ── Computed property ─────────────────────────────────────────────────────
  Duration get _totalDuration => _steps.fold(
        Duration.zero,
        (acc, s) => acc + s.estimatedStepDuration,
      );

  // ─────────────────────────────────────────────────────────────────────────
  // Lifecycle
  // ─────────────────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    if (widget.planId != null) _loadPlan();
  }

  @override
  void dispose() {
    _downloadCompleteTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadPlan() async {
    setState(() {
      _isLoading = true;
      _loadError = null;
    });
    try {
      final repo = ref.read(planRepositoryProvider);
      final plan = await repo.getPlanById(widget.planId!);
      if (plan != null && mounted) {
        setState(() {
          _name = plan.name;
          _description = plan.description ?? '';
          _category = plan.category;
          _tags = List<String>.from(plan.tags);
          _defaultVoice = PlanVoice.values.map((v) => v.name).contains(plan.defaultVoice)
              ? plan.defaultVoice
              : 'aoede';
          _steps = List<PlanStep>.from(plan.steps);
          _originalCreatedAt = plan.createdAt;
          _originalLastUsedAt = plan.lastUsedAt;
        });
      } else if (mounted) {
        setState(() => _loadError = 'Plan not found.');
      }
    } catch (e) {
      if (mounted) setState(() => _loadError = e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Step operations
  // ─────────────────────────────────────────────────────────────────────────

  void _addStep(StepType type, {required int afterIndex}) {
    final id = _uuid.v4();
    final step = defaultStepForType(type, id);
    setState(() {
      _steps = List<PlanStep>.from(_steps)
        ..insert(afterIndex + 1, step);
      _expandedStepId = id;
    });
  }

  void _updateStep(int index, PlanStep updated) {
    setState(() {
      final list = List<PlanStep>.from(_steps);
      list[index] = updated;
      _steps = list;
    });
  }

  void _deleteStep(int index) {
    final id = _steps[index].id;
    setState(() {
      _steps = List<PlanStep>.from(_steps)..removeAt(index);
      if (_expandedStepId == id) _expandedStepId = null;
    });
  }

  void _duplicateStep(int index) {
    final copy = _deepCopy(_steps[index]);
    setState(() {
      _steps = List<PlanStep>.from(_steps)..insert(index + 1, copy);
    });
  }

  void _toggleExpand(String id) {
    setState(() => _expandedStepId = _expandedStepId == id ? null : id);
  }

  void _onReorder(int oldIndex, int newIndex) {
    if (newIndex > oldIndex) newIndex--;
    HapticFeedback.mediumImpact();
    setState(() {
      final list = List<PlanStep>.from(_steps);
      final step = list.removeAt(oldIndex);
      list.insert(newIndex, step);
      _steps = list;
    });
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Context menu (long-press on a step card)
  // ─────────────────────────────────────────────────────────────────────────

  Future<void> _showStepContextMenu(
    BuildContext context,
    int index,
    Offset tapPosition,
  ) async {
    final result = await showMenu<_StepAction>(
      context: context,
      position: RelativeRect.fromLTRB(
        tapPosition.dx,
        tapPosition.dy,
        tapPosition.dx + 1,
        tapPosition.dy + 1,
      ),
      items: const [
        PopupMenuItem(
          value: _StepAction.duplicate,
          child: ListTile(
            leading: Icon(Icons.copy_outlined),
            title: Text('Duplicate'),
            contentPadding: EdgeInsets.zero,
            visualDensity: VisualDensity.compact,
          ),
        ),
        PopupMenuItem(
          value: _StepAction.delete,
          child: ListTile(
            leading: Icon(Icons.delete_outline),
            title: Text('Delete'),
            contentPadding: EdgeInsets.zero,
            visualDensity: VisualDensity.compact,
          ),
        ),
      ],
    );

    if (result == _StepAction.duplicate) _duplicateStep(index);
    if (result == _StepAction.delete) _deleteStep(index);
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Metadata sheet
  // ─────────────────────────────────────────────────────────────────────────

  Future<void> _openMetadataSheet() async {
    final result = await showPlanMetadataSheet(
      context,
      initialName: _name,
      initialDescription: _description.isEmpty ? null : _description,
      initialCategory: _category,
      initialTags: _tags,
      initialVoice: _defaultVoice,
    );
    if (result == null) return;
    setState(() {
      _name = result.name;
      _description = result.description ?? '';
      _category = result.category;
      _tags = List<String>.from(result.tags);
      _defaultVoice = result.defaultVoice;
    });
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Preview
  // ─────────────────────────────────────────────────────────────────────────

  /// Starts a 4× speed preview of the current plan and navigates to the
  /// Now Playing screen.
  ///
  /// Does nothing if the plan has no steps (button is also disabled in that
  /// case via [_steps.isEmpty]).
  Future<void> _startPreview() async {
    if (_steps.isEmpty) return;

    final now = DateTime.now();
    final plan = Plan(
      id: widget.planId ?? 0,
      name: _name.trim().isEmpty ? 'Preview' : _name.trim(),
      description: _description.trim().isEmpty ? null : _description.trim(),
      category: _category,
      tags: List<String>.unmodifiable(_tags),
      defaultVoice: _defaultVoice,
      steps: List<PlanStep>.unmodifiable(_steps),
      createdAt: _originalCreatedAt ?? now,
      updatedAt: now,
      lastUsedAt: _originalLastUsedAt,
    );

    final engine = ref.read(planExecutionEngineProvider);
    await engine.startPreview(plan);

    if (mounted) {
      context.go(AppRoutes.nowPlaying);
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Download voices
  // ─────────────────────────────────────────────────────────────────────────

  /// Pre-renders and caches all TTS voice audio for the current plan.
  ///
  /// Shows a determinate circular progress indicator (with N / M counter)
  /// while downloading.  On completion a checkmark is shown for 2 seconds
  /// before reverting to the download icon.
  Future<void> _downloadVoices() async {
    if (_steps.isEmpty) return;
    setState(() {
      _isDownloading = true;
      _downloadedCount = 0;
      _downloadTotal = 0;
      _downloadComplete = false;
    });
    try {
      final tts = ref.read(ttsServiceProvider);
      final now = DateTime.now();
      final plan = Plan(
        id: widget.planId ?? 0,
        name: _name.trim().isEmpty ? 'Download' : _name.trim(),
        description:
            _description.trim().isEmpty ? null : _description.trim(),
        category: _category,
        tags: List<String>.unmodifiable(_tags),
        defaultVoice: _defaultVoice,
        steps: List<PlanStep>.unmodifiable(_steps),
        createdAt: _originalCreatedAt ?? now,
        updatedAt: now,
        lastUsedAt: _originalLastUsedAt,
      );
      await tts.preRenderPlan(
        plan,
        onProgress: (completed, total) {
          if (mounted) {
            setState(() {
              _downloadedCount = completed;
              _downloadTotal = total;
            });
          }
        },
      );
      if (mounted) {
        // Transition to checkmark state.
        _downloadCompleteTimer?.cancel();
        setState(() {
          _isDownloading = false;
          _downloadComplete = true;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('All voices downloaded ✓')),
        );
        // Revert to download icon after 2 seconds.
        _downloadCompleteTimer = Timer(const Duration(seconds: 2), () {
          if (mounted) setState(() => _downloadComplete = false);
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isDownloading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Voice download failed: $e')),
        );
      }
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Save
  // ─────────────────────────────────────────────────────────────────────────

  Future<void> _save() async {
    // Require a name before saving.
    if (_name.trim().isEmpty) {
      final shouldOpen = await _promptForName();
      if (!shouldOpen) return;
      return; // metadata sheet was opened; user must tap save again
    }

    setState(() => _isSaving = true);
    try {
      final repo = ref.read(planRepositoryProvider);
      final tts = ref.read(ttsServiceProvider);
      final now = DateTime.now();

      final plan = Plan(
        id: widget.planId ?? 0,
        name: _name.trim(),
        description:
            _description.trim().isEmpty ? null : _description.trim(),
        category: _category,
        tags: List<String>.unmodifiable(_tags),
        defaultVoice: _defaultVoice,
        steps: List<PlanStep>.unmodifiable(_steps),
        createdAt: _originalCreatedAt ?? now,
        updatedAt: now,
        lastUsedAt: _originalLastUsedAt,
      );

      int savedId;
      if (widget.planId == null) {
        savedId = await repo.createPlan(plan);
      } else {
        await repo.updatePlan(widget.planId!, plan);
        savedId = widget.planId!;
      }

      // Fire-and-forget: pre-render TTS for all say steps.
      // preRenderPlan already skips cached steps and deduplicates in-flight
      // requests, so this is safe even if _downloadVoices() just ran.
      if (!_isDownloading) {
        unawaited(
          tts.preRenderPlan(plan.copyWith(id: savedId)).catchError((_) {
            // Pre-render is best-effort; do not surface errors to the user.
          }),
        );
      }

      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Save failed: $e')),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  /// Opens the metadata sheet and returns false so the save flow is interrupted
  /// (the user must fill in the name and tap Save again).
  Future<bool> _promptForName() async {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Please add a plan name before saving.')),
    );
    await _openMetadataSheet();
    return false;
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Build
  // ─────────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return _buildLoadingScaffold();
    if (_loadError != null) return _buildErrorScaffold();
    return _buildEditor();
  }

  Widget _buildLoadingScaffold() {
    return Scaffold(
      appBar: AppBar(title: const Text('Loading…')),
      body: const Center(child: CircularProgressIndicator()),
    );
  }

  Widget _buildErrorScaffold() {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.planId == null ? 'New Plan' : 'Edit Plan'),
      ),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48),
            const SizedBox(height: 12),
            Text(_loadError!),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _loadPlan,
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEditor() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final title =
        _name.trim().isEmpty ? (widget.planId == null ? 'New Plan' : 'Edit Plan') : _name;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          // Preview at 4x speed
          if (_steps.isNotEmpty)
            Semantics(
              button: true,
              label: 'Preview plan at 4x speed',
              child: IconButton(
                icon: const Icon(Icons.play_circle_outline),
                tooltip: 'Preview at 4x speed',
                onPressed: _startPreview,
              ),
            ),
          // Download all voices
          if (_steps.isNotEmpty)
            Semantics(
              button: true,
              label: _isDownloading
                  ? 'Downloading voices: $_downloadedCount of $_downloadTotal'
                  : _downloadComplete
                      ? 'Voices downloaded'
                      : 'Download all voices',
              child: _isDownloading
                  ? Padding(
                      padding: const EdgeInsets.all(12),
                      child: SizedBox(
                        width: 24,
                        height: 24,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            CircularProgressIndicator(
                              strokeWidth: 2.5,
                              value: _downloadTotal > 0
                                  ? _downloadedCount / _downloadTotal
                                  : null,
                            ),
                            if (_downloadTotal > 0)
                              Text(
                                '$_downloadedCount\n$_downloadTotal',
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  fontSize: 6,
                                  height: 1.1,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                          ],
                        ),
                      ),
                    )
                  : IconButton(
                      icon: Icon(
                        _downloadComplete
                            ? Icons.check_circle
                            : Icons.download_outlined,
                      ),
                      tooltip: _downloadComplete
                          ? 'Voices downloaded'
                          : 'Download all voices',
                      onPressed: _downloadComplete ? null : _downloadVoices,
                    ),
            ),
          // Edit metadata
          Semantics(
            button: true,
            label: 'Edit plan details',
            child: IconButton(
              icon: const Icon(Icons.tune_outlined),
              tooltip: 'Plan details',
              onPressed: _openMetadataSheet,
            ),
          ),
          // Save
          Semantics(
            button: true,
            label: 'Save plan',
            child: _isSaving
                ? const Padding(
                    padding: EdgeInsets.all(16),
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                : IconButton(
                    icon: const Icon(Icons.save_outlined),
                    tooltip: 'Save',
                    onPressed: _save,
                  ),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Sticky duration header ───────────────────────────────────────
          _DurationHeader(
            duration: _totalDuration,
            stepCount: _steps.length,
            colorScheme: colorScheme,
            theme: theme,
          ),
          const Divider(height: 1),

          // ── Step list ────────────────────────────────────────────────────
          Expanded(
            child: _steps.isEmpty
                ? _buildEmptyState(theme, colorScheme)
                : _buildStepList(),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(ThemeData theme, ColorScheme colorScheme) {
    return Column(
      children: [
        // Top insert button always visible even when empty
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: StepInsertButton(
            onInsert: (type) => _addStep(type, afterIndex: -1),
            afterStepIndex: -1,
          ),
        ),
        Expanded(
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.add_circle_outline,
                  size: 56,
                  color: colorScheme.primary.withValues(alpha: 0.4),
                ),
                const SizedBox(height: 12),
                Text('No steps yet', style: theme.textTheme.titleMedium),
                const SizedBox(height: 6),
                Text(
                  'Tap + to add your first step',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStepList() {
    return ReorderableListView.builder(
      buildDefaultDragHandles: false,
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 96),
      header: Padding(
        padding: const EdgeInsets.only(bottom: 2),
        child: StepInsertButton(
          onInsert: (type) => _addStep(type, afterIndex: -1),
          afterStepIndex: -1,
        ),
      ),
      itemCount: _steps.length,
      itemBuilder: (context, index) {
        final step = _steps[index];
        final isExpanded = _expandedStepId == step.id;

        return _EditorListItem(
          key: ValueKey('item_${step.id}'),
          step: step,
          index: index,
          isExpanded: isExpanded,
          onToggle: () => _toggleExpand(step.id),
          onUpdate: (updated) => _updateStep(index, updated),
          onLongPress: (tapPos) => _showStepContextMenu(context, index, tapPos),
          onInsertAfter: (type) => _addStep(type, afterIndex: index),
        );
      },
      onReorder: _onReorder,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _EditorListItem
// ─────────────────────────────────────────────────────────────────────────────

/// A list item containing a [StepCard] (or [RepeatBlockCard]) followed by a
/// [StepInsertButton].
///
/// Wrapping both inside a single [Column] lets the parent
/// [ReorderableListView] treat card + insert button as one draggable unit,
/// while the drag handle inside the card controls where the drag starts.
class _EditorListItem extends StatelessWidget {
  const _EditorListItem({
    super.key,
    required this.step,
    required this.index,
    required this.isExpanded,
    required this.onToggle,
    required this.onUpdate,
    required this.onLongPress,
    required this.onInsertAfter,
  });

  final PlanStep step;
  final int index;
  final bool isExpanded;
  final VoidCallback onToggle;
  final void Function(PlanStep) onUpdate;
  final void Function(Offset tapPosition) onLongPress;
  final void Function(StepType) onInsertAfter;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        GestureDetector(
          onLongPressStart: (details) => onLongPress(details.globalPosition),
          child: _buildCard(),
        ),
        StepInsertButton(onInsert: onInsertAfter, afterStepIndex: index),
      ],
    );
  }

  Widget _buildCard() {
    if (step is RepeatStep) {
      return RepeatBlockCard(
        step: step as RepeatStep,
        isExpanded: isExpanded,
        dragIndex: index,
        onToggle: onToggle,
        onUpdate: onUpdate,
        onLongPress: () {}, // long-press is handled by parent GestureDetector
      );
    }
    return StepCard(
      step: step,
      isExpanded: isExpanded,
      dragIndex: index,
      onToggle: onToggle,
      onUpdate: onUpdate,
      onLongPress: () {}, // long-press is handled by parent GestureDetector
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _DurationHeader
// ─────────────────────────────────────────────────────────────────────────────

/// Sticky header that shows the total computed duration of all steps.
class _DurationHeader extends StatelessWidget {
  const _DurationHeader({
    required this.duration,
    required this.stepCount,
    required this.colorScheme,
    required this.theme,
  });

  final Duration duration;
  final int stepCount;
  final ColorScheme colorScheme;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    final durationText = _formatDuration(duration);

    return Semantics(
      label:
          'Total duration: $durationText, $stepCount step${stepCount == 1 ? '' : 's'}',
      child: Container(
        color: colorScheme.surfaceContainerLowest,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            Icon(
              Icons.timer_outlined,
              size: 18,
              color: colorScheme.primary,
            ),
            const SizedBox(width: 6),
            Text(
              'Total: $durationText',
              style: theme.textTheme.titleSmall?.copyWith(
                color: colorScheme.onSurface,
              ),
            ),
            const Spacer(),
            Text(
              '$stepCount step${stepCount == 1 ? '' : 's'}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDuration(Duration d) {
    if (d == Duration.zero) return '0s';
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    final s = d.inSeconds.remainder(60);
    if (h > 0) return m > 0 ? '${h}h ${m}m' : '${h}h';
    if (m > 0) return s > 0 ? '${m}m ${s}s' : '${m}m';
    return '${s}s';
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Helpers
// ─────────────────────────────────────────────────────────────────────────────

enum _StepAction { duplicate, delete }

/// Returns a deep copy of [step] with a freshly generated ID (and new IDs for
/// any nested children of a [RepeatStep]).
PlanStep _deepCopy(PlanStep step) {
  final newId = _uuid.v4();
  return switch (step) {
    SayStep s => s.copyWith(id: newId),
    NotifyStep n => n.copyWith(id: newId),
    PlayStep p => p.copyWith(id: newId),
    WaitStep w => w.copyWith(id: newId),
    RepeatStep r => r.copyWith(
        id: newId,
        children: r.children.map(_deepCopy).toList(),
      ),
    StopAudioStep _ => PlanStep.stopAudio(id: newId),
  };
}

/// Fire-and-forget helper that suppresses the unused-result lint.
void unawaited(Future<void> future) {}
