// PlanRequestScreen — lets the user request a plan/schedule that isn't in
// the Discover library yet. The submission is persisted on the backend, the
// admin team is notified by email, and the user sees a confirmation snackbar.

import 'dart:async' show unawaited;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:instructor/providers/auth_providers.dart';
import 'package:instructor/providers/categories_providers.dart';
import 'package:instructor/router.dart';
import 'package:instructor/screens/plan_library/widgets/plan_card.dart'
    show planCategoryLabel;
import 'package:instructor/services/plan_request_client.dart';

class PlanRequestScreen extends ConsumerStatefulWidget {
  const PlanRequestScreen({super.key});

  @override
  ConsumerState<PlanRequestScreen> createState() => _PlanRequestScreenState();
}

class _PlanRequestScreenState extends ConsumerState<PlanRequestScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  String? _selectedCategory;
  bool _isSubmitting = false;
  String? _errorMessage;

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

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
      final client = ref.read(planRequestClientProvider);
      await client.submit(
        email: user.email,
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim(),
        category: _selectedCategory,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Thanks! We received your request and will follow up by email.',
          ),
          behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: 4),
        ),
      );
      context.pop();
    } on PlanRequestException catch (e) {
      if (!mounted) return;
      setState(() => _errorMessage = e.userMessage);
    } catch (_) {
      if (!mounted) return;
      setState(() => _errorMessage = 'Could not submit your request. Please try again.');
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final user = ref.watch(currentUserProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Request a Plan'),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Icon(
                    Icons.lightbulb_outline,
                    size: 48,
                    color: colorScheme.primary,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Can’t find what you need?',
                    style: theme.textTheme.headlineSmall
                        ?.copyWith(fontWeight: FontWeight.w700),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Tell us about the plan or schedule you want. Our team will review it and email you when it’s ready in Discover.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),

                  if (user != null)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: colorScheme.surfaceContainerLow,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.email_outlined,
                            size: 18,
                            color: colorScheme.onSurfaceVariant,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'We’ll reply to ${user.email}',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),

                  TextFormField(
                    controller: _titleController,
                    enabled: !_isSubmitting,
                    maxLength: 200,
                    textInputAction: TextInputAction.next,
                    decoration: InputDecoration(
                      labelText: 'Title',
                      hintText: 'e.g. 30-day intermediate yoga',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    validator: (value) {
                      final v = value?.trim() ?? '';
                      if (v.length < 3) return 'Please add a short title (3+ chars).';
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),

                  Builder(builder: (context) {
                    final slugs = ref.watch(categoriesProvider).valueOrNull?.map((c) => c.slug).toList() ?? [];
                    return DropdownButtonFormField<String?>(
                      value: _selectedCategory,
                      decoration: InputDecoration(
                        labelText: 'Category (optional)',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                      ),
                      items: [
                        const DropdownMenuItem(value: null, child: Text('Not sure')),
                        ...slugs.map((slug) => DropdownMenuItem(
                              value: slug,
                              child: Text(planCategoryLabel(slug)),
                            )),
                      ],
                      onChanged: _isSubmitting
                          ? null
                          : (value) => setState(() => _selectedCategory = value),
                    );
                  }),
                  const SizedBox(height: 12),

                  TextFormField(
                    controller: _descriptionController,
                    enabled: !_isSubmitting,
                    maxLines: 6,
                    minLines: 4,
                    maxLength: 2000,
                    decoration: InputDecoration(
                      labelText: 'What plan or schedule do you want?',
                      hintText:
                          'Describe goals, length, frequency, level, anything specific…',
                      alignLabelWithHint: true,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      errorText: _errorMessage,
                    ),
                    validator: (value) {
                      final v = value?.trim() ?? '';
                      if (v.length < 10) {
                        return 'Please add a few more details (10+ chars).';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  FilledButton.icon(
                    onPressed: _isSubmitting ? null : _submit,
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(52),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    icon: _isSubmitting
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.send_outlined),
                    label: Text(
                      _isSubmitting ? 'Sending…' : 'Send request',
                      style: const TextStyle(fontSize: 16),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
