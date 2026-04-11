/// StepEditor — inline editor for a single plan step in PlanReviewScreen.
library step_editor;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:instructor/models/plan_step.dart';

/// Callback type for when a step is modified.
typedef StepChangedCallback = void Function(PlanStep updated);

/// Displays and allows editing of a single [PlanStep].
///
/// Shows the step type icon, description, and (for [SayStep]) an editable
/// text field. For [WaitStep] shows an editable duration in seconds.
/// The [onChanged] callback is invoked whenever the user modifies the step.
class StepEditor extends StatefulWidget {
  const StepEditor({
    super.key,
    required this.step,
    required this.index,
    this.onChanged,
  });

  final PlanStep step;
  final int index;
  final StepChangedCallback? onChanged;

  @override
  State<StepEditor> createState() => _StepEditorState();
}

class _StepEditorState extends State<StepEditor> {
  late TextEditingController _textController;
  late TextEditingController _durationController;
  bool _isExpanded = false;

  @override
  void initState() {
    super.initState();
    _textController = TextEditingController(text: _initialText);
    _durationController = TextEditingController(
      text: _initialDurationSeconds?.toString() ?? '',
    );
  }

  @override
  void dispose() {
    _textController.dispose();
    _durationController.dispose();
    super.dispose();
  }

  String get _initialText => switch (widget.step) {
        SayStep(:final text) => text,
        NotifyStep(:final title) => title,
        _ => '',
      };

  int? get _initialDurationSeconds => switch (widget.step) {
        WaitStep(:final duration) => duration.inSeconds,
        _ => null,
      };

  IconData get _stepIcon => switch (widget.step) {
        SayStep() => Icons.record_voice_over_outlined,
        NotifyStep() => Icons.notifications_outlined,
        PlayStep() => Icons.music_note_outlined,
        WaitStep() => Icons.hourglass_empty_outlined,
        CountStep() => Icons.tag,
        RepeatStep() => Icons.repeat_outlined,
        StopAudioStep() => Icons.stop_circle_outlined,
      };

  Color _stepColor(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return switch (widget.step) {
      SayStep() => colorScheme.primary,
      NotifyStep() => colorScheme.tertiary,
      PlayStep() => colorScheme.tertiary,
      WaitStep() => colorScheme.secondary,
      CountStep() => const Color(0xFF00838F),
      RepeatStep() => colorScheme.secondaryContainer,
      StopAudioStep() => colorScheme.error,
    };
  }

  String get _stepTypeLabel => switch (widget.step) {
        SayStep() => 'Say',
        NotifyStep() => 'Notify',
        PlayStep() => 'Play',
        WaitStep() => 'Wait',
        CountStep() => 'Count',
        RepeatStep() => 'Repeat',
        StopAudioStep() => 'Stop Audio',
      };

  String get _stepSummary => switch (widget.step) {
        SayStep(:final text) =>
          text.length > 60 ? '${text.substring(0, 60)}…' : text,
        NotifyStep(:final title, :final body) => '$title — $body',
        PlayStep(:final audioAssetKey) => audioAssetKey,
        WaitStep(:final duration) =>
          '${duration.inSeconds}s',
        CountStep(:final from, :final to, :final intervalSeconds) =>
          '${from <= to ? '' : '(countdown) '}$from \u2192 $to'
          '${intervalSeconds > 1 ? ' every ${intervalSeconds}s' : ''}',
        RepeatStep(:final count, :final children) =>
          '× $count (${children.length} steps)',
        StopAudioStep() => 'Stop all audio',
      };

  void _onTextChanged(String value) {
    if (widget.onChanged == null) return;
    final updated = switch (widget.step) {
      SayStep(:final id, :final voiceId, :final estimatedDuration) =>
        PlanStep.say(
          id: id,
          text: value,
          voiceId: voiceId,
          estimatedDuration: estimatedDuration,
        ),
      NotifyStep(:final id, :final body) =>
        PlanStep.notify(id: id, title: value, body: body),
      _ => widget.step,
    };
    widget.onChanged!(updated);
  }

  void _onDurationChanged(String value) {
    if (widget.onChanged == null) return;
    final seconds = int.tryParse(value) ?? 0;
    if (widget.step case WaitStep(:final id)) {
      widget.onChanged!(
        PlanStep.wait(id: id, duration: Duration(seconds: seconds)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = _stepColor(context);

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: color.withOpacity(0.3)),
      ),
      child: Theme(
        data: theme.copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          onExpansionChanged: (v) => setState(() => _isExpanded = v),
          leading: CircleAvatar(
            radius: 18,
            backgroundColor: color.withOpacity(0.15),
            child: Icon(_stepIcon, color: color, size: 18),
          ),
          title: Text(
            '${widget.index + 1}. $_stepTypeLabel',
            style: theme.textTheme.labelLarge
                ?.copyWith(fontWeight: FontWeight.w600),
          ),
          subtitle: Text(
            _stepSummary,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: _buildEditor(context),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEditor(BuildContext context) {
    return switch (widget.step) {
      SayStep() => _textField(
          label: 'Speech text',
          controller: _textController,
          onChanged: _onTextChanged,
          maxLines: 3,
        ),
      NotifyStep() => _textField(
          label: 'Notification title',
          controller: _textController,
          onChanged: _onTextChanged,
        ),
      WaitStep() => _numberField(
          label: 'Duration (seconds)',
          controller: _durationController,
          onChanged: _onDurationChanged,
        ),
      _ => Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Text(
            'This step type is not editable here.',
            style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant),
          ),
        ),
    };
  }

  Widget _textField({
    required String label,
    required TextEditingController controller,
    required void Function(String) onChanged,
    int maxLines = 1,
  }) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: label,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
      ),
      onChanged: onChanged,
    );
  }

  Widget _numberField({
    required String label,
    required TextEditingController controller,
    required void Function(String) onChanged,
  }) {
    return TextField(
      controller: controller,
      keyboardType: TextInputType.number,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      decoration: InputDecoration(
        labelText: label,
        suffixText: 's',
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
      ),
      onChanged: onChanged,
    );
  }
}
