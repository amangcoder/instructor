/// PlanGenerationScreen — AI-assisted plan creation via natural-language prompt.
library plan_generation_screen;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:instructor/models/plan.dart';
import 'package:instructor/providers/auth_providers.dart';
import 'package:instructor/providers/tts_providers.dart';
import 'package:instructor/router.dart';
import 'package:instructor/services/plan_generation_client.dart';
import 'plan_review_screen.dart';

/// Payload passed from [PlanGenerationScreen] to [PlanReviewScreen].
class GeneratedPlanPayload {
  const GeneratedPlanPayload({required this.plan});
  final Plan plan;
}

/// Free-text input screen where the user describes the plan they want.
///
/// Calls POST /api/plans/generate with the prompt and navigates to
/// [PlanReviewScreen] on success.
class PlanGenerationScreen extends ConsumerStatefulWidget {
  const PlanGenerationScreen({super.key});

  @override
  ConsumerState<PlanGenerationScreen> createState() =>
      _PlanGenerationScreenState();
}

class _PlanGenerationScreenState extends ConsumerState<PlanGenerationScreen> {
  final _promptController = TextEditingController();
  bool _isGenerating = false;
  String? _errorMessage;
  String _selectedLanguage = 'Auto-detect';

  static const _languages = [
    'Auto-detect',
    'English',
    'Hindi',
    'Spanish',
    'French',
    'German',
    'Portuguese',
    'Japanese',
    'Korean',
    'Chinese',
    'Arabic',
    'Russian',
    'Italian',
  ];

  @override
  void dispose() {
    _promptController.dispose();
    super.dispose();
  }

  Future<void> _generate() async {
    final prompt = _promptController.text.trim();
    if (prompt.isEmpty) {
      setState(() => _errorMessage = 'Please describe the plan you want.');
      return;
    }

    setState(() {
      _isGenerating = true;
      _errorMessage = null;
    });

    HapticFeedback.lightImpact();

    try {
      final client = ref.read(planGenerationClientProvider);
      final activeProvider = await ref.read(activeProviderProvider.future);
      final lang = _selectedLanguage == 'Auto-detect'
          ? null
          : _selectedLanguage;
      final plan = await client.generatePlan(
        prompt,
        language: lang,
        fallbackVoice: activeProvider.defaultVoice.isNotEmpty
            ? activeProvider.defaultVoice
            : 'af_heart',
      );

      if (mounted) {
        context.push(
          AppRoutes.generatePlanReview,
          extra: GeneratedPlanPayload(plan: plan),
        );
      }
    } on PlanGenerationException catch (e) {
      if (mounted) {
        setState(() => _errorMessage = e.userMessage);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _errorMessage = 'Plan generation failed. Please try again.');
      }
    } finally {
      if (mounted) {
        setState(() => _isGenerating = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isAuthenticated = ref.watch(isAuthenticatedProvider);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Generate Plan'),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 600),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // ── Unauthenticated gate ──────────────────────────────
                  if (!isAuthenticated) ...[
                    _AuthGateCard(onLoginTap: () => context.push(AppRoutes.login)),
                  ] else ...[
                    // ── Header ──────────────────────────────────────────
                    Icon(
                      Icons.auto_awesome_outlined,
                      size: 56,
                      color: colorScheme.primary,
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Describe your plan',
                      style: theme.textTheme.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.w700),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'The AI will generate a structured plan with steps based on your description.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 32),

                    // ── Prompt input ─────────────────────────────────────
                    Semantics(
                      label: 'Plan description',
                      child: TextField(
                        controller: _promptController,
                        enabled: !_isGenerating,
                        maxLines: 5,
                        minLines: 3,
                        textInputAction: TextInputAction.newline,
                        decoration: InputDecoration(
                          labelText: 'What plan do you want to create?',
                          hintText:
                              'e.g. A 20-minute morning yoga routine with breathing exercises',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          errorText: _errorMessage,
                          alignLabelWithHint: true,
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // ── Language dropdown ────────────────────────────────
                    DropdownButtonFormField<String>(
                      initialValue: _selectedLanguage,
                      decoration: InputDecoration(
                        labelText: 'Language',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                      ),
                      items: _languages
                          .map(
                            (lang) => DropdownMenuItem(
                              value: lang,
                              child: Text(lang),
                            ),
                          )
                          .toList(),
                      onChanged: _isGenerating
                          ? null
                          : (value) {
                              if (value != null) {
                                setState(() => _selectedLanguage = value);
                              }
                            },
                    ),

                    const SizedBox(height: 24),

                    // ── Generate button ──────────────────────────────────
                    FilledButton.icon(
                      onPressed: _isGenerating ? null : _generate,
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(52),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      icon: _isGenerating
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.auto_awesome),
                      label: Text(
                        _isGenerating ? 'Generating…' : 'Generate Plan',
                        style: const TextStyle(fontSize: 16),
                      ),
                    ),

                    if (_isGenerating) ...[
                      const SizedBox(height: 12),
                      Text(
                        'This may take 10–30 seconds…',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Auth gate card
// ─────────────────────────────────────────────────────────────────────────────

class _AuthGateCard extends StatelessWidget {
  const _AuthGateCard({required this.onLoginTap});

  final VoidCallback onLoginTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Icon(
              Icons.lock_outlined,
              size: 48,
              color: colorScheme.primary,
            ),
            const SizedBox(height: 16),
            Text(
              'Login to use AI plan generation',
              style: theme.textTheme.titleLarge
                  ?.copyWith(fontWeight: FontWeight.w700),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Sign in with your email to unlock AI-powered plan creation.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: onLoginTap,
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text('Log in'),
            ),
          ],
        ),
      ),
    );
  }
}
