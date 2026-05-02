// CreatePlanScreen — form for users to author new private plans.
//
// Route: /create-plan  (auth-gated — requires authenticated user)
//
// Workflow:
//   1. User fills in title, steps (ordered list of text instructions),
//      and an optional description, then taps "Create Plan".
//   2. The screen calls POST /api/plans, which creates the plan with
//      visibility=private and owner_user_id from the auth JWT.
//   3. On success the form is replaced with a confirmation view that shows
//      a "Request Publish" button.
//   4. Tapping "Request Publish" calls POST /api/plans/:id/request-publish,
//      which transitions the plan to pending_review so admins can review it.

import 'dart:async' show unawaited;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:instructor/providers/auth_providers.dart';
import 'package:instructor/router.dart';
import 'package:instructor/services/create_plan_client.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Screen widget
// ─────────────────────────────────────────────────────────────────────────────

/// Screen for creating a new user-authored private plan.
///
/// Requires authentication — the router redirect sends unauthenticated users
/// to /login.
class CreatePlanScreen extends ConsumerStatefulWidget {
  const CreatePlanScreen({super.key});

  @override
  ConsumerState<CreatePlanScreen> createState() => _CreatePlanScreenState();
}

class _CreatePlanScreenState extends ConsumerState<CreatePlanScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();

  /// Ordered list of step text controllers (one per step row).
  final List<TextEditingController> _stepControllers = [
    TextEditingController(),
  ];

  bool _isSubmitting = false;
  bool _isRequestingPublish = false;
  String? _errorMessage;

  /// Non-null after the plan has been successfully created on the server.
  String? _createdPlanId;

  // ── Lifecycle ──────────────────────────────────────────────────────────────

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    for (final c in _stepControllers) {
      c.dispose();
    }
    super.dispose();
  }

  // ── Step list helpers ──────────────────────────────────────────────────────

  void _addStep() {
    setState(() => _stepControllers.add(TextEditingController()));
    // Auto-scroll / focus handled by the list itself.
  }

  void _removeStep(int index) {
    if (_stepControllers.length <= 1) return; // keep at least one step row
    final controller = _stepControllers.removeAt(index);
    controller.dispose();
    setState(() {});
  }

  void _moveStepUp(int index) {
    if (index <= 0) return;
    setState(() {
      final c = _stepControllers.removeAt(index);
      _stepControllers.insert(index - 1, c);
    });
  }

  void _moveStepDown(int index) {
    if (index >= _stepControllers.length - 1) return;
    setState(() {
      final c = _stepControllers.removeAt(index);
      _stepControllers.insert(index + 1, c);
    });
  }

  // ── Form submission ────────────────────────────────────────────────────────

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final user = ref.read(currentUserProvider);
    if (user == null) {
      context.go(AppRoutes.login);
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });
    unawaited(HapticFeedback.lightImpact());

    try {
      final client = ref.read(createPlanClientProvider);
      final steps = _stepControllers
          .map((c) => c.text.trim())
          .where((s) => s.isNotEmpty)
          .toList();

      final planId = await client.createPlan(
        title: _titleController.text.trim(),
        steps: steps,
        description: _descriptionController.text.trim(),
      );

      if (!mounted) return;
      setState(() => _createdPlanId = planId);
      unawaited(HapticFeedback.mediumImpact());
    } on CreatePlanException catch (e) {
      if (!mounted) return;
      setState(() => _errorMessage = e.userMessage);
    } catch (_) {
      if (!mounted) return;
      setState(() => _errorMessage = 'Could not create your plan. Please try again.');
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  // ── Request Publish ────────────────────────────────────────────────────────

  Future<void> _requestPublish() async {
    final planId = _createdPlanId;
    if (planId == null) return;

    setState(() {
      _isRequestingPublish = true;
      _errorMessage = null;
    });
    unawaited(HapticFeedback.lightImpact());

    try {
      final client = ref.read(createPlanClientProvider);
      await client.requestPublish(planId);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Publish request submitted! Our team will review your plan.',
          ),
          behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: 4),
        ),
      );
      context.pop();
    } on CreatePlanException catch (e) {
      if (!mounted) return;
      setState(() => _errorMessage = e.userMessage);
    } catch (_) {
      if (!mounted) return;
      setState(() => _errorMessage = 'Could not submit your publish request. Please try again.');
    } finally {
      if (mounted) setState(() => _isRequestingPublish = false);
    }
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Plan'),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.close),
          tooltip: 'Cancel',
          onPressed: () => context.pop(),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: _createdPlanId != null
                ? _SuccessView(
                    planId: _createdPlanId!,
                    planTitle: _titleController.text.trim(),
                    isRequestingPublish: _isRequestingPublish,
                    errorMessage: _errorMessage,
                    onRequestPublish: _requestPublish,
                    onDone: () => context.pop(),
                  )
                : _PlanForm(
                    formKey: _formKey,
                    titleController: _titleController,
                    descriptionController: _descriptionController,
                    stepControllers: _stepControllers,
                    isSubmitting: _isSubmitting,
                    errorMessage: _errorMessage,
                    onAddStep: _addStep,
                    onRemoveStep: _removeStep,
                    onMoveStepUp: _moveStepUp,
                    onMoveStepDown: _moveStepDown,
                    onSubmit: _submit,
                  ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Plan creation form
// ─────────────────────────────────────────────────────────────────────────────

class _PlanForm extends StatelessWidget {
  const _PlanForm({
    required this.formKey,
    required this.titleController,
    required this.descriptionController,
    required this.stepControllers,
    required this.isSubmitting,
    required this.errorMessage,
    required this.onAddStep,
    required this.onRemoveStep,
    required this.onMoveStepUp,
    required this.onMoveStepDown,
    required this.onSubmit,
  });

  final GlobalKey<FormState> formKey;
  final TextEditingController titleController;
  final TextEditingController descriptionController;
  final List<TextEditingController> stepControllers;
  final bool isSubmitting;
  final String? errorMessage;
  final VoidCallback onAddStep;
  final void Function(int index) onRemoveStep;
  final void Function(int index) onMoveStepUp;
  final void Function(int index) onMoveStepDown;
  final Future<void> Function() onSubmit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Form(
      key: formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Header ─────────────────────────────────────────────────────
          Icon(
            Icons.edit_note_rounded,
            size: 48,
            color: colorScheme.primary,
          ),
          const SizedBox(height: 16),
          Text(
            'Author a private plan',
            style: theme.textTheme.headlineSmall
                ?.copyWith(fontWeight: FontWeight.w700),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'Your plan is saved privately. You can request it to be '
            'reviewed and published to the library later.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 28),

          // ── Title ─────────────────────────────────────────────────────
          TextFormField(
            controller: titleController,
            enabled: !isSubmitting,
            maxLength: 200,
            textInputAction: TextInputAction.next,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(
              labelText: 'Title *',
              hintText: 'e.g. Morning mindfulness routine',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            validator: (value) {
              final v = value?.trim() ?? '';
              if (v.length < 3) {
                return 'Please enter a title (3+ characters).';
              }
              return null;
            },
          ),
          const SizedBox(height: 12),

          // ── Description ───────────────────────────────────────────────
          TextFormField(
            controller: descriptionController,
            enabled: !isSubmitting,
            maxLines: 4,
            minLines: 2,
            maxLength: 2000,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(
              labelText: 'Description (optional)',
              hintText: 'Briefly describe what this plan is for…',
              alignLabelWithHint: true,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          const SizedBox(height: 20),

          // ── Steps section ─────────────────────────────────────────────
          Row(
            children: [
              Text(
                'Steps *',
                style: theme.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w600),
              ),
              const Spacer(),
              TextButton.icon(
                onPressed: isSubmitting ? null : onAddStep,
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Add step'),
                style: TextButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Add the spoken instructions for each step in order.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 12),

          // Step rows — rendered inline (no Reorderable overhead for simplicity)
          for (int i = 0; i < stepControllers.length; i++)
            _StepRow(
              index: i,
              total: stepControllers.length,
              controller: stepControllers[i],
              enabled: !isSubmitting,
              onRemove: () => onRemoveStep(i),
              onMoveUp: () => onMoveStepUp(i),
              onMoveDown: () => onMoveStepDown(i),
            ),

          const SizedBox(height: 20),

          // ── Error message ─────────────────────────────────────────────
          if (errorMessage != null) ...[
            _ErrorBanner(message: errorMessage!),
            const SizedBox(height: 16),
          ],

          // ── Submit ─────────────────────────────────────────────────────
          Semantics(
            button: true,
            label: 'Create plan',
            child: FilledButton.icon(
              onPressed: isSubmitting ? null : onSubmit,
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(52),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              icon: isSubmitting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.check_circle_outline),
              label: Text(
                isSubmitting ? 'Creating…' : 'Create plan',
                style: const TextStyle(fontSize: 16),
              ),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Individual step row
// ─────────────────────────────────────────────────────────────────────────────

class _StepRow extends StatelessWidget {
  const _StepRow({
    required this.index,
    required this.total,
    required this.controller,
    required this.enabled,
    required this.onRemove,
    required this.onMoveUp,
    required this.onMoveDown,
  });

  final int index;
  final int total;
  final TextEditingController controller;
  final bool enabled;
  final VoidCallback onRemove;
  final VoidCallback onMoveUp;
  final VoidCallback onMoveDown;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final stepNumber = index + 1;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Step number badge
          Container(
            width: 28,
            height: 28,
            margin: const EdgeInsets.only(top: 14),
            decoration: BoxDecoration(
              color: colorScheme.primaryContainer,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Text(
              '$stepNumber',
              style: theme.textTheme.labelSmall?.copyWith(
                color: colorScheme.onPrimaryContainer,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 8),

          // Text input
          Expanded(
            child: TextFormField(
              controller: controller,
              enabled: enabled,
              maxLines: 3,
              minLines: 1,
              maxLength: 500,
              textCapitalization: TextCapitalization.sentences,
              textInputAction: TextInputAction.next,
              decoration: InputDecoration(
                hintText: 'Step $stepNumber instruction…',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                counterText: '',
              ),
              validator: (value) {
                final v = value?.trim() ?? '';
                if (v.isEmpty) return 'Step $stepNumber cannot be empty.';
                return null;
              },
              // Accessibility: describe the field by its position
              // (provided via hint text above)
            ),
          ),
          const SizedBox(width: 4),

          // Reorder / remove controls
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (index > 0)
                IconButton(
                  icon: const Icon(Icons.arrow_upward, size: 18),
                  tooltip: 'Move step up',
                  onPressed: enabled ? onMoveUp : null,
                  visualDensity: VisualDensity.compact,
                )
              else
                const SizedBox(width: 40, height: 40),
              if (index < total - 1)
                IconButton(
                  icon: const Icon(Icons.arrow_downward, size: 18),
                  tooltip: 'Move step down',
                  onPressed: enabled ? onMoveDown : null,
                  visualDensity: VisualDensity.compact,
                )
              else
                const SizedBox(width: 40, height: 40),
              if (total > 1)
                IconButton(
                  icon: Icon(
                    Icons.close,
                    size: 18,
                    color: colorScheme.error,
                  ),
                  tooltip: 'Remove step',
                  onPressed: enabled ? onRemove : null,
                  visualDensity: VisualDensity.compact,
                ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Success / post-creation view
// ─────────────────────────────────────────────────────────────────────────────

class _SuccessView extends StatelessWidget {
  const _SuccessView({
    required this.planId,
    required this.planTitle,
    required this.isRequestingPublish,
    required this.errorMessage,
    required this.onRequestPublish,
    required this.onDone,
  });

  final String planId;
  final String planTitle;
  final bool isRequestingPublish;
  final String? errorMessage;
  final Future<void> Function() onRequestPublish;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 24),

        // ── Success icon ─────────────────────────────────────────────────
        Icon(
          Icons.check_circle_outline_rounded,
          size: 64,
          color: colorScheme.primary,
        ),
        const SizedBox(height: 20),

        Text(
          'Plan created!',
          style: theme.textTheme.headlineSmall
              ?.copyWith(fontWeight: FontWeight.w700),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),

        // Plan name chip
        Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              planTitle,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onPrimaryContainer,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ),
        const SizedBox(height: 16),

        Text(
          'Your plan has been saved to your private library. '
          'It is only visible to you.\n\n'
          "If you'd like it to be reviewed for inclusion in the "
          'public Discover library, tap "Request Publish" below.',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 32),

        // ── Error banner ─────────────────────────────────────────────────
        if (errorMessage != null) ...[
          _ErrorBanner(message: errorMessage!),
          const SizedBox(height: 16),
        ],

        // ── Request Publish ──────────────────────────────────────────────
        Semantics(
          button: true,
          label: 'Request plan to be published to library',
          child: FilledButton.icon(
            onPressed: isRequestingPublish ? null : onRequestPublish,
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(52),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            icon: isRequestingPublish
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.upload_outlined),
            label: Text(
              isRequestingPublish ? 'Requesting…' : 'Request Publish',
              style: const TextStyle(fontSize: 16),
            ),
          ),
        ),
        const SizedBox(height: 12),

        // ── Done (keep private) ──────────────────────────────────────────
        OutlinedButton(
          onPressed: isRequestingPublish ? null : onDone,
          style: OutlinedButton.styleFrom(
            minimumSize: const Size.fromHeight(48),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: const Text(
            'Keep private — done',
            style: TextStyle(fontSize: 15),
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Shared error banner
// ─────────────────────────────────────────────────────────────────────────────

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Semantics(
      liveRegion: true,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: colorScheme.errorContainer,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            Icon(
              Icons.error_outline,
              size: 18,
              color: colorScheme.onErrorContainer,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                message,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: colorScheme.onErrorContainer,
                    ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
