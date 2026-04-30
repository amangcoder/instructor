import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:uuid/uuid.dart';

import 'package:instructor/models/enums.dart';
import 'package:instructor/models/plan_step.dart';
import 'package:instructor/theme/step_colors.dart';

import 'step_card.dart';
import 'step_editors/step_editors.dart';
import 'step_insert_button.dart';
import 'step_type_picker.dart';

const _uuid = Uuid();

// ─────────────────────────────────────────────────────────────────────────────
// RepeatBlockCard
// ─────────────────────────────────────────────────────────────────────────────

/// A Scratch-style visual block card for a [RepeatStep].
///
/// Renders as a card with a left accent border (indented container) holding a
/// vertical list of nested [_NestedStepCard]s. Expanding the card reveals:
/// - A count input (1–999)
/// - The nested steps with [StepInsertButton]s between them
///
/// Nested-step expansion state is managed internally so the parent only tracks
/// top-level expansion.
class RepeatBlockCard extends StatefulWidget {
  const RepeatBlockCard({
    super.key,
    required this.step,
    required this.isExpanded,
    required this.dragIndex,
    required this.onToggle,
    required this.onUpdate,
    required this.onLongPress,
  });

  final RepeatStep step;
  final bool isExpanded;
  final int dragIndex;
  final VoidCallback onToggle;
  final void Function(PlanStep updated) onUpdate;
  final VoidCallback onLongPress;

  @override
  State<RepeatBlockCard> createState() => _RepeatBlockCardState();
}

class _RepeatBlockCardState extends State<RepeatBlockCard> {
  String? _expandedNestedId;
  late final TextEditingController _countController;

  @override
  void initState() {
    super.initState();
    _countController =
        TextEditingController(text: widget.step.count.toString());
  }

  @override
  void didUpdateWidget(RepeatBlockCard old) {
    super.didUpdateWidget(old);
    if (old.step.count != widget.step.count) {
      final text = widget.step.count.toString();
      if (_countController.text != text) {
        _countController.text = text;
      }
    }
  }

  @override
  void dispose() {
    _countController.dispose();
    super.dispose();
  }

  // ── Nested step operations ────────────────────────────────────────────────

  void _addNestedStep(StepType type, int afterIndex) {
    final id = _uuid.v4();
    final newStep = defaultStepForType(type, id);
    final updated = List<PlanStep>.from(widget.step.children)
      ..insert(afterIndex, newStep);
    widget.onUpdate(widget.step.copyWith(children: updated));
    setState(() => _expandedNestedId = id);
  }

  void _updateNestedStep(int index, PlanStep updated) {
    final children = List<PlanStep>.from(widget.step.children);
    children[index] = updated;
    widget.onUpdate(widget.step.copyWith(children: children));
  }

  void _deleteNestedStep(int index) {
    final id = widget.step.children[index].id;
    final updated = List<PlanStep>.from(widget.step.children)..removeAt(index);
    widget.onUpdate(widget.step.copyWith(children: updated));
    if (_expandedNestedId == id) setState(() => _expandedNestedId = null);
  }

  void _duplicateNestedStep(int index) {
    final original = widget.step.children[index];
    final copy = _copyWithNewId(original);
    final updated = List<PlanStep>.from(widget.step.children)
      ..insert(index + 1, copy);
    widget.onUpdate(widget.step.copyWith(children: updated));
  }

  void _toggleNested(String id) {
    setState(
      () => _expandedNestedId = _expandedNestedId == id ? null : id,
    );
  }

  // ── Count ────────────────────────────────────────────────────────────────

  void _onCountChanged(String value) {
    final n = int.tryParse(value);
    if (n == null) return;
    final clamped = n.clamp(1, 999);
    widget.onUpdate(widget.step.copyWith(count: clamped));
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final repeatColor = StepColors.colorForType(StepType.repeat);

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Top accent bar ────────────────────────────────────────────────
          Container(height: 3, color: repeatColor),

          // ── Header row ───────────────────────────────────────────────────
          GestureDetector(
            onLongPress: widget.onLongPress,
            child: InkWell(
              onTap: widget.onToggle,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 4, 10),
                child: Row(
                  children: [
                    StepColors.iconForType(StepType.repeat, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '×${widget.step.count} · '
                            '${widget.step.children.length} '
                            'step${widget.step.children.length == 1 ? '' : 's'}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          if (widget.step.estimatedStepDuration !=
                              Duration.zero)
                            Text(
                              formatStepDuration(
                                widget.step.estimatedStepDuration,
                              ),
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                        ],
                      ),
                    ),
                    Icon(
                      widget.isExpanded
                          ? Icons.expand_less
                          : Icons.expand_more,
                      color: colorScheme.onSurfaceVariant,
                      size: 20,
                    ),
                    ReorderableDragStartListener(
                      index: widget.dragIndex,
                      child: MouseRegion(
                        cursor: SystemMouseCursors.grab,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          child: Icon(
                            Icons.drag_handle,
                            size: 20,
                            color: colorScheme.onSurfaceVariant,
                            semanticLabel: 'Drag repeat block to reorder',
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // ── Expanded body ────────────────────────────────────────────────
          AnimatedSize(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeInOut,
            child: widget.isExpanded
                ? _buildBody(context, theme, colorScheme, repeatColor)
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }

  Widget _buildBody(
    BuildContext context,
    ThemeData theme,
    ColorScheme colorScheme,
    Color accentColor,
  ) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Divider(),
          const SizedBox(height: 8),

          // ── Count input ──────────────────────────────────────────────────
          Semantics(
            label: 'Repeat count',
            textField: true,
            child: TextField(
              controller: _countController,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(
                labelText: 'Repeat count (1–999)',
                prefixIcon: Icon(Icons.repeat),
              ),
              textInputAction: TextInputAction.done,
              onChanged: _onCountChanged,
            ),
          ),
          const SizedBox(height: 12),

          // ── Nested steps container ───────────────────────────────────────
          Text(
            'Steps inside this block',
            style: theme.textTheme.labelMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 6),

          // Scratch-style indented container: left border + padding
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Left accent border
                Container(
                  width: 4,
                  decoration: BoxDecoration(
                    color: accentColor.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 8),

                // Nested step list
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Top insert button
                      StepInsertButton(
                        onInsert: (type) => _addNestedStep(type, 0),
                      ),
                      // Step cards
                      for (var i = 0;
                          i < widget.step.children.length;
                          i++) ...[
                        _NestedStepCard(
                          step: widget.step.children[i],
                          isExpanded: _expandedNestedId ==
                              widget.step.children[i].id,
                          onToggle: () =>
                              _toggleNested(widget.step.children[i].id),
                          onUpdate: (updated) => _updateNestedStep(i, updated),
                          onDelete: () => _deleteNestedStep(i),
                          onDuplicate: () => _duplicateNestedStep(i),
                          onLongPress: () =>
                              _showNestedContextMenu(context, i),
                        ),
                        StepInsertButton(
                          onInsert: (type) => _addNestedStep(type, i + 1),
                        ),
                      ],
                      // When no children, show a hint
                      if (widget.step.children.isEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Text(
                            'No steps yet — tap + to add',
                            textAlign: TextAlign.center,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Context menu for nested steps ─────────────────────────────────────────

  Future<void> _showNestedContextMenu(BuildContext context, int index) async {
    final box = context.findRenderObject() as RenderBox?;
    if (box == null) return;
    final offset = box.localToGlobal(Offset.zero);
    final result = await showMenu<_NestedAction>(
      context: context,
      position: RelativeRect.fromLTRB(
        offset.dx + 50,
        offset.dy + 50,
        offset.dx + box.size.width - 50,
        offset.dy + box.size.height - 50,
      ),
      items: const [
        PopupMenuItem(
          value: _NestedAction.duplicate,
          child: ListTile(
            leading: Icon(Icons.copy_outlined),
            title: Text('Duplicate'),
            contentPadding: EdgeInsets.zero,
            visualDensity: VisualDensity.compact,
          ),
        ),
        PopupMenuItem(
          value: _NestedAction.delete,
          child: ListTile(
            leading: Icon(Icons.delete_outline),
            title: Text('Delete'),
            contentPadding: EdgeInsets.zero,
            visualDensity: VisualDensity.compact,
          ),
        ),
      ],
    );
    if (result == _NestedAction.duplicate) _duplicateNestedStep(index);
    if (result == _NestedAction.delete) _deleteNestedStep(index);
  }
}

enum _NestedAction { duplicate, delete }

// ─────────────────────────────────────────────────────────────────────────────
// _NestedStepCard
// ─────────────────────────────────────────────────────────────────────────────

/// A simplified step card for nested children inside a [RepeatBlockCard].
///
/// Unlike [StepCard] it has no drag handle (nested steps are not
/// independently reorderable via [ReorderableListView]).  Instead it
/// exposes [onDelete] and [onDuplicate] via long-press.
class _NestedStepCard extends StatelessWidget {
  const _NestedStepCard({
    required this.step,
    required this.isExpanded,
    required this.onToggle,
    required this.onUpdate,
    required this.onDelete,
    required this.onDuplicate,
    required this.onLongPress,
  });

  final PlanStep step;
  final bool isExpanded;
  final VoidCallback onToggle;
  final void Function(PlanStep) onUpdate;
  final VoidCallback onDelete;
  final VoidCallback onDuplicate;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final stepColor = StepColors.colorForType(step.type);

    return Card(
      margin: const EdgeInsets.only(bottom: 4),
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(height: 2, color: stepColor),
          GestureDetector(
            onLongPress: onLongPress,
            child: InkWell(
              onTap: onToggle,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
                child: Row(
                  children: [
                    StepColors.iconForType(step.type, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _summaryText,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    Icon(
                      isExpanded ? Icons.expand_less : Icons.expand_more,
                      size: 18,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ],
                ),
              ),
            ),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeInOut,
            child: isExpanded
                ? Padding(
                    padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
                    child: _buildEditor(),
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }

  Widget _buildEditor() => switch (step) {
        SayStep s => SayStepEditor(step: s, onUpdate: onUpdate),
        NotifyStep n => NotifyStepEditor(step: n, onUpdate: onUpdate),
        PlayStep p => PlayStepEditor(step: p, onUpdate: onUpdate),
        WaitStep w => WaitStepEditor(step: w, onUpdate: onUpdate),
        CountStep c => CountStepEditor(step: c, onUpdate: onUpdate),
        // Nested RepeatStep: show a simple read-only hint — deep nesting UI
        // is not supported in the current editor.
        RepeatStep _ => const _NestedRepeatHint(),
        StopAudioStep _ => const StopAudioEditorHint(),
      };

  String get _summaryText => switch (step) {
        SayStep s => s.text.isEmpty ? '(empty)' : s.text,
        NotifyStep n => n.title.isEmpty ? '(untitled)' : n.title,
        PlayStep p => formatAudioAssetKey(p.audioAssetKey),
        WaitStep w => formatStepDuration(w.duration),
        CountStep c => '${c.from <= c.to ? 'Count' : 'Countdown'} '
            '${c.from} \u2192 ${c.to}'
            '${c.intervalSeconds > 1 ? ' (every ${c.intervalSeconds}s)' : ''}',
        RepeatStep r => '×${r.count} · ${r.children.length} steps',
        StopAudioStep _ => 'Stop all audio',
      };
}

// ─────────────────────────────────────────────────────────────────────────────
// Hint widgets
// ─────────────────────────────────────────────────────────────────────────────

class _NestedRepeatHint extends StatelessWidget {
  const _NestedRepeatHint();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Text(
        'Nested repeat blocks are not editable here. '
        'Edit from the top-level list.',
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Helper functions
// ─────────────────────────────────────────────────────────────────────────────

/// Returns a deep copy of [step] with a freshly generated ID (and new IDs for
/// any nested children).
PlanStep _copyWithNewId(PlanStep step) {
  final newId = _uuid.v4();
  return switch (step) {
    SayStep s => s.copyWith(id: newId),
    NotifyStep n => n.copyWith(id: newId),
    PlayStep p => p.copyWith(id: newId),
    WaitStep w => w.copyWith(id: newId),
    CountStep c => c.copyWith(id: newId),
    RepeatStep r => r.copyWith(
        id: newId,
        children: r.children.map(_copyWithNewId).toList(),
      ),
    StopAudioStep _ => PlanStep.stopAudio(id: newId),
  };
}
