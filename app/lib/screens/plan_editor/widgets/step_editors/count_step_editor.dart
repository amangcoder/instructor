import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:instructor/models/plan_step.dart';

/// A StatefulWidget for editing a [CountStep].
class CountStepEditor extends StatefulWidget {
  const CountStepEditor({required this.step, required this.onUpdate});

  final CountStep step;
  final void Function(PlanStep) onUpdate;

  @override
  State<CountStepEditor> createState() => _CountStepEditorState();
}

/// State for [CountStepEditor].
class _CountStepEditorState extends State<CountStepEditor> {
  late final TextEditingController _fromCtrl;
  late final TextEditingController _toCtrl;
  late final TextEditingController _intervalCtrl;

  @override
  void initState() {
    super.initState();
    _fromCtrl = TextEditingController(text: widget.step.from.toString());
    _toCtrl = TextEditingController(text: widget.step.to.toString());
    _intervalCtrl =
        TextEditingController(text: widget.step.intervalSeconds.toString());
  }

  @override
  void dispose() {
    _fromCtrl.dispose();
    _toCtrl.dispose();
    _intervalCtrl.dispose();
    super.dispose();
  }

  void _push() {
    final from = (int.tryParse(_fromCtrl.text) ?? 1).clamp(1, 999);
    final to = (int.tryParse(_toCtrl.text) ?? 10).clamp(1, 999);
    final interval = (int.tryParse(_intervalCtrl.text) ?? 1).clamp(1, 20);
    widget.onUpdate(
      widget.step.copyWith(
        from: from,
        to: to,
        intervalSeconds: interval,
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
            Expanded(
              child: TextField(
                controller: _fromCtrl,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: const InputDecoration(
                  labelText: 'From',
                ),
                textInputAction: TextInputAction.next,
                onChanged: (_) => _push(),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextField(
                controller: _toCtrl,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: const InputDecoration(
                  labelText: 'To',
                ),
                textInputAction: TextInputAction.next,
                onChanged: (_) => _push(),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextField(
                controller: _intervalCtrl,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: const InputDecoration(
                  labelText: 'Interval',
                  suffixText: 's',
                ),
                textInputAction: TextInputAction.done,
                onChanged: (_) => _push(),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
