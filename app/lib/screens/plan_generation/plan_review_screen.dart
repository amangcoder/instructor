/// PlanReviewScreen — review, edit, and save or discard a generated plan.
library plan_review_screen;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:instructor/models/plan.dart';
import 'package:instructor/models/plan_step.dart';
import 'package:instructor/providers/plan_providers.dart';
import 'package:instructor/router.dart';
import 'plan_generation_screen.dart';
import 'widgets/step_editor.dart';

/// Displays a generated [Plan] for the user to review and optionally modify
/// before saving to the local SQLite database.
class PlanReviewScreen extends ConsumerStatefulWidget {
  const PlanReviewScreen({super.key, this.payload});

  /// The generated plan payload received from [PlanGenerationScreen].
  final GeneratedPlanPayload? payload;

  @override
  ConsumerState<PlanReviewScreen> createState() => _PlanReviewScreenState();
}

class _PlanReviewScreenState extends ConsumerState<PlanReviewScreen> {
  late Plan _plan;
  bool _isSaving = false;
  String? _saveError;

  @override
  void initState() {
    super.initState();
    _plan = widget.payload?.plan ??
        Plan(
          id: '',
          name: 'Untitled Plan',
          steps: const [],
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );
  }

  Future<void> _save() async {
    setState(() {
      _isSaving = true;
      _saveError = null;
    });

    HapticFeedback.lightImpact();

    try {
      final repo = ref.read(planRepositoryProvider);
      await repo.createPlan(_plan);

      if (mounted) {
        // Navigate back to the library and clear the generation stack.
        context.go(AppRoutes.library);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('"${_plan.name}" saved to your library.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _saveError = 'Failed to save plan. Please try again.');
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  void _discard() {
    HapticFeedback.lightImpact();
    context.pop();
  }

  void _onStepChanged(int index, PlanStep updated) {
    setState(() {
      final steps = List<PlanStep>.from(_plan.steps);
      steps[index] = updated;
      _plan = _plan.copyWith(steps: steps);
    });
  }

  void _onNameChanged(String name) {
    setState(() => _plan = _plan.copyWith(name: name));
  }

  @override
  Widget build(BuildContext context) {
    if (widget.payload == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Review Plan')),
        body: const Center(child: Text('No plan data available.')),
      );
    }

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Review Plan'),
        centerTitle: true,
        actions: [
          TextButton(
            onPressed: _isSaving ? null : _discard,
            child: const Text('Discard'),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // ── Plan name editor ─────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: _PlanNameField(
                initialName: _plan.name,
                onChanged: _onNameChanged,
              ),
            ),

            if (_plan.description != null && _plan.description!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: Text(
                  _plan.description!,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ),

            // ── Steps list ───────────────────────────────────────────────
            Expanded(
              child: _plan.steps.isEmpty
                  ? const Center(child: Text('No steps in this plan.'))
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
                      itemCount: _plan.steps.length,
                      itemBuilder: (context, index) {
                        return StepEditor(
                          key: ValueKey(_plan.steps[index].hashCode),
                          step: _plan.steps[index],
                          index: index,
                          onChanged: (updated) =>
                              _onStepChanged(index, updated),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),

      // ── Bottom action bar ─────────────────────────────────────────────
      bottomNavigationBar: _BottomActionBar(
        isSaving: _isSaving,
        errorMessage: _saveError,
        onSave: _save,
        onDiscard: _discard,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Plan name field
// ─────────────────────────────────────────────────────────────────────────────

class _PlanNameField extends StatefulWidget {
  const _PlanNameField({
    required this.initialName,
    required this.onChanged,
  });

  final String initialName;
  final ValueChanged<String> onChanged;

  @override
  State<_PlanNameField> createState() => _PlanNameFieldState();
}

class _PlanNameFieldState extends State<_PlanNameField> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialName);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _controller,
      style: Theme.of(context).textTheme.titleLarge,
      decoration: const InputDecoration(
        labelText: 'Plan name',
        border: OutlineInputBorder(),
      ),
      onChanged: widget.onChanged,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Bottom action bar
// ─────────────────────────────────────────────────────────────────────────────

class _BottomActionBar extends StatelessWidget {
  const _BottomActionBar({
    required this.isSaving,
    required this.errorMessage,
    required this.onSave,
    required this.onDiscard,
  });

  final bool isSaving;
  final String? errorMessage;
  final VoidCallback onSave;
  final VoidCallback onDiscard;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (errorMessage != null) ...[
              Text(
                errorMessage!,
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: colorScheme.error),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
            ],
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: isSaving ? null : onDiscard,
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(52),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Discard'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: FilledButton.icon(
                    onPressed: isSaving ? null : onSave,
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(52),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    icon: isSaving
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.save_outlined),
                    label: const Text('Save Plan',
                        style: TextStyle(fontSize: 16)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
