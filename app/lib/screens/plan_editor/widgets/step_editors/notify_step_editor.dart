import 'package:flutter/material.dart';

import 'package:instructor/models/plan_step.dart';

/// A StatefulWidget for editing a [NotifyStep].
class NotifyStepEditor extends StatefulWidget {
  const NotifyStepEditor({required this.step, required this.onUpdate});

  final NotifyStep step;
  final void Function(PlanStep) onUpdate;

  @override
  State<NotifyStepEditor> createState() => NotifyStepEditorState();
}

/// State for [NotifyStepEditor].
class NotifyStepEditorState extends State<NotifyStepEditor> {
  late final TextEditingController _titleController;
  late final TextEditingController _bodyController;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.step.title);
    _bodyController = TextEditingController(text: widget.step.body);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _bodyController.dispose();
    super.dispose();
  }

  void _onChanged() {
    widget.onUpdate(
      widget.step.copyWith(
        title: _titleController.text,
        body: _bodyController.text,
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
        Semantics(
          label: 'Notification title',
          textField: true,
          child: TextField(
            controller: _titleController,
            decoration: const InputDecoration(
              labelText: 'Title',
              hintText: 'e.g. Time check',
            ),
            textInputAction: TextInputAction.next,
            onChanged: (_) => _onChanged(),
          ),
        ),
        const SizedBox(height: 8),
        Semantics(
          label: 'Notification body',
          textField: true,
          child: TextField(
            controller: _bodyController,
            decoration: const InputDecoration(
              labelText: 'Body',
              hintText: 'e.g. You are halfway there!',
            ),
            maxLines: null,
            minLines: 2,
            textInputAction: TextInputAction.newline,
            onChanged: (_) => _onChanged(),
          ),
        ),
      ],
    );
  }
}
