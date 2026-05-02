// PlanDetailScreen — full detail view for an individual plan.
//
// Route: /plans/:id  (planId path parameter from GoRouter)
//
// Responsibilities (TASK-030):
//   • Fetch plan tree to depth 3 via planTreeProvider(planId)    (REQ-021)
//   • Render recursive sub-plan hierarchy up to depth 3          (REQ-021)
//   • Display VoicePickerWidget for available plan voices        (REQ-021)
//   • Persist voice selection via selectedVoiceProvider(planId)  (REQ-020)
//   • TTS fallback: no ready voice OR HTTP error → platform TTS  (REQ-022)

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:instructor/models/plan.dart';
import 'package:instructor/models/plan_voice.dart';
import 'package:instructor/providers/categories_providers.dart';
import 'package:instructor/providers/tts_status_providers.dart';
import 'package:instructor/screens/plan_editor/plan_editor_screen.dart';

import 'widgets/voice_picker_widget.dart';

// Pushing /editor/:planId via context.push from this screen (a top-level
// route, outside the StatefulShellRoute) triggers the go_router 14
// keyReservation regression — see flutter/flutter#140586. Pushing a
// MaterialPageRoute on the root navigator bypasses go_router's
// outer→shell push path while preserving back-stack UX.
void _openPlanEditor(BuildContext context, String planId) {
  Navigator.of(context, rootNavigator: true).push<void>(
    MaterialPageRoute<void>(
      builder: (_) => PlanEditorScreen(planId: planId),
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// PlanDetailScreen
// ─────────────────────────────────────────────────────────────────────────────

/// Full-screen detail view for a plan, including its sub-plan tree and
/// voice selection widget.
///
/// Fetches the complete plan tree (root + children up to depth 3) via
/// [planTreeProvider].  The [VoicePickerWidget] reads [selectedVoiceProvider]
/// and writes to it when the user changes their voice preference.
///
/// ### TTS fallback (AC-016, AC-017, REQ-022)
/// When the user taps the play button:
/// 1. If no `plan_voice` entry has `status='ready'` → force platform TTS.
/// 2. If a ready voice is selected → request genai TTS mode.
/// 3. If the HTTP TTS request subsequently fails, [TTSServiceImpl] falls back
///    to platform TTS automatically via [PlanVoiceChecker.hasReadyVoice].
class PlanDetailScreen extends ConsumerWidget {
  const PlanDetailScreen({super.key, required this.planId});

  /// The unique identifier of the plan to display.
  final String planId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final treeAsync = ref.watch(planTreeProvider(planId));

    return Scaffold(
      appBar: AppBar(
        title: treeAsync.whenOrNull(data: (plan) => Text(plan.name)) ??
            const Text('Plan Detail'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: 'Back',
          onPressed: () => context.pop(),
        ),
      ),
      body: treeAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => _ErrorView(
          message: e.toString(),
          onRetry: () => ref.invalidate(planTreeProvider(planId)),
        ),
        data: (plan) => _PlanDetailBody(plan: plan, planId: planId),
      ),
      bottomNavigationBar: treeAsync.whenOrNull(
        data: (plan) => _PlayBar(plan: plan, planId: planId),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _PlanDetailBody
// ─────────────────────────────────────────────────────────────────────────────

/// Scrollable body rendered once the plan tree has loaded.
class _PlanDetailBody extends StatelessWidget {
  const _PlanDetailBody({required this.plan, required this.planId});

  final Plan plan;
  final String planId;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
      children: [
        // ── Plan title ────────────────────────────────────────────────────
        Text(
          plan.name,
          style: GoogleFonts.manrope(
            fontSize: 26,
            fontWeight: FontWeight.w700,
            color: colorScheme.onSurface,
          ),
        ),

        // ── Description ───────────────────────────────────────────────────
        if (plan.description != null && plan.description!.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            plan.description!,
            style: TextStyle(
              fontSize: 15,
              color: colorScheme.onSurfaceVariant,
              height: 1.5,
            ),
          ),
        ],

        // ── Meta row (duration / step count) ──────────────────────────────
        const SizedBox(height: 12),
        _PlanMetaRow(plan: plan, colorScheme: colorScheme),

        // ── Voice picker ──────────────────────────────────────────────────
        const SizedBox(height: 24),
        VoicePickerWidget(planId: planId, planVoices: plan.voices),

        // ── Steps ─────────────────────────────────────────────────────────
        if (plan.steps.isNotEmpty) ...[
          const SizedBox(height: 24),
          _SectionLabel(label: 'STEPS', colorScheme: colorScheme),
          const SizedBox(height: 8),
          _StepsList(steps: plan.steps.length, colorScheme: colorScheme),
        ],

        // ── Sub-plan tree ─────────────────────────────────────────────────
        if (plan.children.isNotEmpty) ...[
          const SizedBox(height: 24),
          _SectionLabel(label: 'SUB-PLANS', colorScheme: colorScheme),
          const SizedBox(height: 8),
          _SubPlanTree(children: plan.children, depth: 0),
        ],
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _PlanMetaRow
// ─────────────────────────────────────────────────────────────────────────────

class _PlanMetaRow extends StatelessWidget {
  const _PlanMetaRow({required this.plan, required this.colorScheme});

  final Plan plan;
  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context) {
    final duration = plan.totalDuration;
    final totalMinutes = duration.inMinutes;

    return Wrap(
      spacing: 16,
      runSpacing: 4,
      children: [
        // Step count
        _MetaChip(
          icon: Icons.list_alt_outlined,
          label: '${plan.steps.length} step${plan.steps.length == 1 ? '' : 's'}',
          colorScheme: colorScheme,
        ),

        // Duration (only if any steps exist)
        if (totalMinutes > 0)
          _MetaChip(
            icon: Icons.timer_outlined,
            label: '$totalMinutes min',
            colorScheme: colorScheme,
          ),

        // Sub-plan count
        if (plan.children.isNotEmpty)
          _MetaChip(
            icon: Icons.account_tree_outlined,
            label:
                '${plan.children.length} sub-plan${plan.children.length == 1 ? '' : 's'}',
            colorScheme: colorScheme,
          ),
      ],
    );
  }
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({
    required this.icon,
    required this.label,
    required this.colorScheme,
  });

  final IconData icon;
  final String label;
  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: colorScheme.outline),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(fontSize: 13, color: colorScheme.outline),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _SectionLabel
// ─────────────────────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.label, required this.colorScheme});

  final String label;
  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w700,
        color: colorScheme.outline,
        letterSpacing: 0.8,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _StepsList
// ─────────────────────────────────────────────────────────────────────────────

/// Summary row showing number of steps (not individual step cards — those live
/// in the plan editor / NowPlaying screen).
class _StepsList extends StatelessWidget {
  const _StepsList({required this.steps, required this.colorScheme});

  final int steps;
  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Row(
        children: [
          Icon(Icons.list_alt_outlined,
              size: 16, color: colorScheme.onSurfaceVariant),
          const SizedBox(width: 8),
          Text(
            '$steps step${steps == 1 ? '' : 's'}',
            style: TextStyle(
              fontSize: 14,
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _SubPlanTree  (REQ-021 — recursive sub-plan tree to depth 3)
// ─────────────────────────────────────────────────────────────────────────────

/// Renders [children] sub-plans recursively up to a maximum of 3 levels deep.
///
/// [depth] is 0-indexed; the maximum rendered depth is 2 (i.e. depth 0, 1, 2
/// corresponding to "depth 1, 2, 3" in spec language).
class _SubPlanTree extends StatelessWidget {
  const _SubPlanTree({required this.children, required this.depth});

  final List<Plan> children;

  /// 0 = first level below root, 1 = second, 2 = third (max).
  final int depth;

  /// Maximum recursion depth (0-indexed; renders depths 0, 1, 2).
  static const _kMaxDepth = 2;

  @override
  Widget build(BuildContext context) {
    if (depth > _kMaxDepth || children.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final child in children)
          _SubPlanTile(plan: child, depth: depth),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _SubPlanTile
// ─────────────────────────────────────────────────────────────────────────────

/// A single sub-plan row. If the sub-plan itself has children and we have not
/// reached max depth, they are rendered indented beneath it.
class _SubPlanTile extends StatelessWidget {
  const _SubPlanTile({required this.plan, required this.depth});

  final Plan plan;
  final int depth;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final hasChildren =
        plan.children.isNotEmpty && depth < _SubPlanTree._kMaxDepth;

    // Horizontal indent increases with depth.
    final leftPad = depth * 16.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ── The plan tile ────────────────────────────────────────────────
        Padding(
          padding: EdgeInsets.only(left: leftPad, bottom: 4),
          child: Semantics(
            label: 'Sub-plan: ${plan.name}',
            child: Container(
              decoration: BoxDecoration(
                color: depth == 0
                    ? colorScheme.surfaceContainerLow
                    : colorScheme.surfaceContainerLowest,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: colorScheme.outlineVariant),
              ),
              child: ListTile(
                dense: true,
                leading: Icon(
                  hasChildren
                      ? Icons.folder_outlined
                      : Icons.article_outlined,
                  size: 18,
                  color: colorScheme.onSurfaceVariant,
                ),
                title: Text(
                  plan.name,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: colorScheme.onSurface,
                  ),
                ),
                subtitle: _buildSubtitle(plan, colorScheme),
                trailing: _ReadinessIndicator(voices: plan.voices),
              ),
            ),
          ),
        ),

        // ── Recursive children ──────────────────────────────────────────
        if (hasChildren)
          _SubPlanTree(children: plan.children, depth: depth + 1),
      ],
    );
  }

  Widget? _buildSubtitle(Plan plan, ColorScheme colorScheme) {
    final parts = <String>[];
    if (plan.steps.isNotEmpty) {
      parts.add('${plan.steps.length} step${plan.steps.length == 1 ? '' : 's'}');
    }
    final mins = plan.totalDuration.inMinutes;
    if (mins > 0) parts.add('$mins min');
    if (parts.isEmpty) return null;

    return Text(
      parts.join(' · '),
      style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _ReadinessIndicator
// ─────────────────────────────────────────────────────────────────────────────

/// Small icon indicating whether this plan has at least one ready voice
/// synthesis.  Used in the sub-plan tiles to give the user at-a-glance
/// TTS status without needing to open every child plan.
class _ReadinessIndicator extends StatelessWidget {
  const _ReadinessIndicator({required this.voices});

  final List<PlanVoice> voices;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final hasReady = voices.any((v) => v.status == 'ready');
    final hasPending = !hasReady &&
        voices.any(
          (v) => v.status == 'pending' || v.status == 'processing',
        );

    if (hasReady) {
      return Tooltip(
        message: 'AI voice ready',
        child: Icon(Icons.auto_awesome, size: 14, color: colorScheme.primary),
      );
    }
    if (hasPending) {
      return Tooltip(
        message: 'AI voice generating…',
        child: SizedBox(
          width: 14,
          height: 14,
          child: CircularProgressIndicator(
            strokeWidth: 1.5,
            color: colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
          ),
        ),
      );
    }
    return const SizedBox.shrink();
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _PlayBar  (sticky bottom CTA)
// ─────────────────────────────────────────────────────────────────────────────

/// Sticky bottom bar with a "Play" button.
///
/// ### TTS mode selection (AC-016, AC-017, REQ-022)
/// Before navigating to the plan editor / player the button resolves
/// the correct [TtsPlaybackMode]:
///
/// | Condition | Mode set |
/// |---|---|
/// | selected voice is non-null AND has a ready PlanVoice | genai |
/// | selected voice is null OR has no ready PlanVoice     | platform |
///
/// The TTSServiceImpl additionally falls back to platform TTS automatically
/// when [PlanVoiceChecker.hasReadyVoice] returns `false` at synthesis time,
/// providing a second line of defence (REQ-022).
class _PlayBar extends ConsumerWidget {
  const _PlayBar({required this.plan, required this.planId});

  final Plan plan;
  final String planId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final selectedVoice = ref.watch(selectedVoiceProvider(planId));

    // Determine whether we can use a GenAI voice for playback.
    final readyVoices = plan.voices.where((v) => v.status == 'ready').toList();
    final canUseAiVoice = selectedVoice != null &&
        readyVoices.any((v) => v.voiceId == selectedVoice.id);

    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        decoration: BoxDecoration(
          color: colorScheme.surface,
          border: Border(
            top: BorderSide(color: colorScheme.outlineVariant, width: 1),
          ),
        ),
        child: SizedBox(
          width: double.infinity,
          height: 52,
          child: FilledButton.icon(
            onPressed: () => _handlePlay(context, ref, canUseAiVoice),
            icon: const Icon(Icons.play_arrow_rounded),
            label: Text(
              canUseAiVoice ? 'Play with AI Voice' : 'Play',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ),
      ),
    );
  }

  /// Sets [ttsPlaybackModeProvider] based on voice availability and navigates
  /// to the plan editor.
  ///
  /// - [canUseAiVoice] `true`  → sets mode to [TtsPlaybackMode.genai].
  /// - [canUseAiVoice] `false` → sets mode to [TtsPlaybackMode.platform]
  ///   (REQ-022, AC-016, AC-017).
  void _handlePlay(BuildContext context, WidgetRef ref, bool canUseAiVoice) {
    // Set the session-scoped TTS playback mode before navigating.
    ref.read(ttsPlaybackModeProvider.notifier).state = canUseAiVoice
        ? TtsPlaybackMode.genai
        : TtsPlaybackMode.platform;

    // Navigate to the plan editor / now-playing screen.
    _openPlanEditor(context, planId);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _ErrorView
// ─────────────────────────────────────────────────────────────────────────────

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.error_outline,
              size: 48,
              color: colorScheme.error,
            ),
            const SizedBox(height: 16),
            Text(
              'Could not load plan',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 24),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}
