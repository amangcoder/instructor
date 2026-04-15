/// Shared Plan Preview Screen — shown when a user opens a shared plan deep link.
///
/// Fetches the shared plan via [PlanSharingService.fetchSharedPlan] on init,
/// then displays plan name, description, step list, step count, and estimated
/// duration. A prominent 'Save to My Plans' button allows the viewer to copy
/// the plan to their own library.
///
/// ## Deep link entry
/// GoRouter route: `/shared/:token`
/// The [shareToken] path parameter is extracted by the router and passed here.
///
/// ## Auth handling
/// Tapping 'Save to My Plans' calls [PlanSharingService.saveSharedPlanToLibrary].
/// If the service throws a 401 error (not authenticated), the screen redirects
/// the user to the login flow and returns to complete the save after sign-in.
library shared_plan_preview_screen;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:instructor/models/shared_plan_preview.dart';
import 'package:instructor/models/shared_plan_step.dart';
import 'package:instructor/router.dart';
import 'package:instructor/services/plan_sharing_service.dart';
import 'package:instructor/theme/app_branding.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Screen
// ─────────────────────────────────────────────────────────────────────────────

/// Screen that displays a shared plan preview loaded via a deep link token.
///
/// Implements [ConsumerStatefulWidget] to manage the async fetch lifecycle
/// (loading → loaded / error) and the save-in-progress state.
class SharedPlanPreviewScreen extends ConsumerStatefulWidget {
  const SharedPlanPreviewScreen({
    super.key,
    required this.shareToken,
  });

  /// Token extracted from the deep link path `/shared/:token`.
  final String shareToken;

  @override
  ConsumerState<SharedPlanPreviewScreen> createState() =>
      _SharedPlanPreviewScreenState();
}

class _SharedPlanPreviewScreenState
    extends ConsumerState<SharedPlanPreviewScreen> {
  // ── State ─────────────────────────────────────────────────────────────────

  SharedPlanPreview? _plan;
  String? _errorMessage;
  bool _isLoading = true;
  bool _isSaving = false;

  // ── Lifecycle ─────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _fetchSharedPlan();
  }

  // ── Data fetching ─────────────────────────────────────────────────────────

  Future<void> _fetchSharedPlan() async {
    final service = ref.read(planSharingServiceProvider);
    try {
      final plan = await service.fetchSharedPlan(widget.shareToken);
      if (mounted) {
        setState(() {
          _plan = plan;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = _extractMessage(e);
          _isLoading = false;
        });
      }
    }
  }

  // ── Save action ───────────────────────────────────────────────────────────

  Future<void> _savePlan() async {
    final plan = _plan;
    if (plan == null || _isSaving) return;

    setState(() => _isSaving = true);

    final service = ref.read(planSharingServiceProvider);
    try {
      await service.saveSharedPlanToLibrary(plan);
      if (mounted) {
        setState(() => _isSaving = false);
        _showSuccessSnackBar();
      }
    } on PlanSharingException catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        if (e.statusCode == 401) {
          // User is not authenticated — redirect to login.
          context.push(AppRoutes.login);
        } else {
          _showErrorSnackBar(e.userMessage);
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        _showErrorSnackBar('Failed to save plan. Please try again.');
      }
    }
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  /// Extracts a user-visible message from any thrown exception.
  String _extractMessage(Object error) {
    if (error is PlanSharingException) return error.userMessage;
    debugPrint('SharedPlanPreviewScreen: unexpected error: $error');
    return 'This plan is no longer available. The link may have expired or been revoked.';
  }

  void _showSuccessSnackBar() {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Plan saved to your library!'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        backgroundColor: Theme.of(context).colorScheme.error,
      ),
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBranding.brandedAppBar(
        title: const Text('Shared Plan'),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) return _buildLoadingState();
    if (_errorMessage != null) return _buildErrorState(_errorMessage!);
    if (_plan != null) return _buildPlanContent(_plan!);
    return const SizedBox.shrink();
  }

  // ── Loading state ─────────────────────────────────────────────────────────

  Widget _buildLoadingState() {
    return const Center(
      child: Semantics(
        label: 'Loading shared plan',
        child: CircularProgressIndicator(),
      ),
    );
  }

  // ── Error state ───────────────────────────────────────────────────────────

  Widget _buildErrorState(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.link_off_rounded,
              size: 64,
              color: Theme.of(context).colorScheme.error,
            ),
            const SizedBox(height: 16),
            Text(
              'Plan Unavailable',
              style: Theme.of(context).textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              message,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            OutlinedButton.icon(
              onPressed: () {
                setState(() {
                  _isLoading = true;
                  _errorMessage = null;
                });
                _fetchSharedPlan();
              },
              icon: const Icon(Icons.refresh),
              label: const Text('Try Again'),
            ),
          ],
        ),
      ),
    );
  }

  // ── Plan content ──────────────────────────────────────────────────────────

  Widget _buildPlanContent(SharedPlanPreview plan) {
    final steps = _parseSteps(plan.steps);
    final durationLabel = _formatDuration(plan.estimatedDurationMs);

    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Plan name (large title) ──────────────────────────────
                Semantics(
                  header: true,
                  child: Text(
                    plan.name,
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ),

                // ── Stats row ─────────────────────────────────────────────
                const SizedBox(height: 12),
                _PlanStatsRow(
                  stepCount: plan.stepCount,
                  durationLabel: durationLabel,
                ),

                // ── Description ───────────────────────────────────────────
                if (plan.description != null &&
                    plan.description!.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Text(
                    plan.description!,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color:
                              Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                  ),
                ],

                // ── Divider ───────────────────────────────────────────────
                const SizedBox(height: 24),
                const Divider(),
                const SizedBox(height: 8),

                // ── Step list ─────────────────────────────────────────────
                Text(
                  'Steps',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
                const SizedBox(height: 12),

                if (steps.isEmpty)
                  Text(
                    'No steps available.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context)
                              .colorScheme
                              .onSurfaceVariant,
                        ),
                  )
                else
                  ListView.separated(
                    physics: const NeverScrollableScrollPhysics(),
                    shrinkWrap: true,
                    itemCount: steps.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, index) =>
                        _StepTile(step: steps[index], index: index),
                  ),

                // Bottom padding so content is not obscured by the CTA
                const SizedBox(height: 96),
              ],
            ),
          ),
        ),

        // ── Sticky Save CTA ───────────────────────────────────────────────
        _SavePlanBar(
          onSave: _savePlan,
          isSaving: _isSaving,
        ),
      ],
    );
  }

  /// Converts the raw [SharedPlanPreview.steps] list (may contain
  /// [SharedPlanStep] objects from tests or [Map] from JSON parsing)
  /// to a typed [List<SharedPlanStep>].
  List<SharedPlanStep> _parseSteps(List<dynamic> rawSteps) {
    return rawSteps.map((step) {
      if (step is SharedPlanStep) return step;
      if (step is Map<String, dynamic>) {
        return SharedPlanStep.fromMap(step);
      }
      return const SharedPlanStep(type: 'say');
    }).toList();
  }

  /// Formats [durationMs] as a human-readable string (e.g. "30 min", "1 hr 15 min").
  String _formatDuration(int durationMs) {
    final total = Duration(milliseconds: durationMs);
    final hours = total.inHours;
    final minutes = total.inMinutes.remainder(60);

    if (hours == 0) return '$minutes min';
    if (minutes == 0) return '$hours hr';
    return '$hours hr $minutes min';
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Sub-widgets
// ─────────────────────────────────────────────────────────────────────────────

/// Row showing step count and estimated duration badges.
class _PlanStatsRow extends StatelessWidget {
  const _PlanStatsRow({
    required this.stepCount,
    required this.durationLabel,
  });

  final int stepCount;
  final String durationLabel;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 12,
      runSpacing: 8,
      children: [
        _StatChip(
          icon: Icons.format_list_numbered_rounded,
          label: '$stepCount ${stepCount == 1 ? 'step' : 'steps'}',
        ),
        _StatChip(
          icon: Icons.timer_outlined,
          label: durationLabel,
        ),
      ],
    );
  }
}

/// A small chip displaying an icon + label for a plan statistic.
class _StatChip extends StatelessWidget {
  const _StatChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon,
              size: 16,
              color: Theme.of(context).colorScheme.onSurfaceVariant),
          const SizedBox(width: 4),
          Text(
            label,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
        ],
      ),
    );
  }
}

/// A card displaying a single step's type label and optional duration.
class _StepTile extends StatelessWidget {
  const _StepTile({required this.step, required this.index});

  final SharedPlanStep step;
  final int index;

  @override
  Widget build(BuildContext context) {
    final durationText = step.estimatedDurationMs != null
        ? _formatStepDuration(step.estimatedDurationMs!)
        : null;

    return Semantics(
      label: 'Step ${index + 1}: ${step.typeLabel}'
          '${step.text != null ? ', ${step.text}' : ''}'
          '${durationText != null ? ', $durationText' : ''}',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            // Step index
            Container(
              width: 28,
              height: 28,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer,
                shape: BoxShape.circle,
              ),
              child: Text(
                '${index + 1}',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color:
                          Theme.of(context).colorScheme.onPrimaryContainer,
                      fontWeight: FontWeight.bold,
                    ),
              ),
            ),
            const SizedBox(width: 12),
            // Step content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Type badge
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Theme.of(context)
                          .colorScheme
                          .secondaryContainer,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      step.typeLabel,
                      style:
                          Theme.of(context).textTheme.labelSmall?.copyWith(
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSecondaryContainer,
                              ),
                    ),
                  ),
                  if (step.text != null && step.text!.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      step.text!,
                      style: Theme.of(context).textTheme.bodySmall,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
            // Duration
            if (durationText != null) ...[
              const SizedBox(width: 8),
              Text(
                durationText,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color:
                          Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// Formats a step duration in milliseconds to a short human-readable string.
  String _formatStepDuration(int durationMs) {
    final secs = (durationMs / 1000).round();
    if (secs < 60) return '${secs}s';
    final mins = (secs / 60).round();
    if (mins < 60) return '${mins}m';
    return '${(mins / 60).floor()}h ${mins % 60}m';
  }
}

/// Sticky bottom bar containing the 'Save to My Plans' CTA.
class _SavePlanBar extends StatelessWidget {
  const _SavePlanBar({
    required this.onSave,
    required this.isSaving,
  });

  final VoidCallback onSave;
  final bool isSaving;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 16),
        child: SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton(
            onPressed: isSaving ? null : onSave,
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.primary,
              foregroundColor: Theme.of(context).colorScheme.onPrimary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: isSaving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Text(
                    'Save to My Plans',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}
