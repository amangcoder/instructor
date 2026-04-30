import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:instructor/models/plan_step.dart';

/// A StatefulWidget for editing a [WaitStep].
class WaitStepEditor extends StatefulWidget {
  const WaitStepEditor({required this.step, required this.onUpdate});

  final WaitStep step;
  final void Function(PlanStep) onUpdate;

  @override
  State<WaitStepEditor> createState() => WaitStepEditorState();
}

/// State for [WaitStepEditor].
class WaitStepEditorState extends State<WaitStepEditor> {
  late final TextEditingController _minutesCtrl;
  late final TextEditingController _secondsCtrl;

  @override
  void initState() {
    super.initState();
    final d = widget.step.duration;
    _minutesCtrl =
        TextEditingController(text: d.inMinutes.remainder(60).toString());
    _secondsCtrl =
        TextEditingController(text: d.inSeconds.remainder(60).toString());
  }

  @override
  void dispose() {
    _minutesCtrl.dispose();
    _secondsCtrl.dispose();
    super.dispose();
  }

  void _push() {
    final minutes = int.tryParse(_minutesCtrl.text) ?? 0;
    final seconds = int.tryParse(_secondsCtrl.text) ?? 0;
    final clamped = seconds.clamp(0, 59);
    if (clamped != seconds) {
      _secondsCtrl.text = clamped.toString();
    }
    widget.onUpdate(
      widget.step.copyWith(
        duration: Duration(
          minutes: minutes.clamp(0, 9999),
          seconds: clamped,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Divider(),
        const SizedBox(height: 8),
        Row(
          children: [
            // Minutes
            Expanded(
              child: Semantics(
                label: 'Minutes',
                textField: true,
                child: TextField(
                  controller: _minutesCtrl,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: const InputDecoration(
                    labelText: 'Minutes',
                    suffixText: 'm',
                  ),
                  textInputAction: TextInputAction.next,
                  onChanged: (_) => _push(),
                ),
              ),
            ),
            const SizedBox(width: 12),
            // Seconds
            Expanded(
              child: Semantics(
                label: 'Seconds',
                textField: true,
                child: TextField(
                  controller: _secondsCtrl,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: const InputDecoration(
                    labelText: 'Seconds',
                    suffixText: 's',
                  ),
                  textInputAction: TextInputAction.done,
                  onChanged: (_) => _push(),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
