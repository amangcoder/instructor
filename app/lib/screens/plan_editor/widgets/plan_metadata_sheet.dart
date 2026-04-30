import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:instructor/models/enums.dart';
import 'package:instructor/models/tts_provider_config.dart';
import 'package:instructor/providers/tts_providers.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Data class
// ─────────────────────────────────────────────────────────────────────────────

/// Immutable snapshot of the values the user filled in [_PlanMetadataSheet].
class PlanMetadata {
  const PlanMetadata({
    required this.name,
    this.description,
    required this.category,
    required this.tags,
    required this.defaultVoice,
  });

  final String name;
  final String? description;
  final PlanCategory category;
  final List<String> tags;
  final String defaultVoice;
}

// ─────────────────────────────────────────────────────────────────────────────
// Entry point
// ─────────────────────────────────────────────────────────────────────────────

/// Opens a modal bottom sheet for editing Plan metadata.
///
/// Returns the edited [PlanMetadata] on save, or null when dismissed.
Future<PlanMetadata?> showPlanMetadataSheet(
  BuildContext context, {
  required String initialName,
  String? initialDescription,
  required PlanCategory initialCategory,
  required List<String> initialTags,
  required String initialVoice,
  bool voiceLocked = false,
}) {
  return showModalBottomSheet<PlanMetadata>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (ctx) => _PlanMetadataSheet(
      initialName: initialName,
      initialDescription: initialDescription,
      initialCategory: initialCategory,
      initialTags: initialTags,
      initialVoice: initialVoice,
      voiceLocked: voiceLocked,
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// Sheet widget
// ─────────────────────────────────────────────────────────────────────────────

class _PlanMetadataSheet extends ConsumerStatefulWidget {
  const _PlanMetadataSheet({
    required this.initialName,
    this.initialDescription,
    required this.initialCategory,
    required this.initialTags,
    required this.initialVoice,
    this.voiceLocked = false,
  });

  final String initialName;
  final String? initialDescription;
  final PlanCategory initialCategory;
  final List<String> initialTags;
  final String initialVoice;

  /// When true, the voice picker is disabled because TTS has already been
  /// pre-generated for this plan. Changing the voice would invalidate the cache.
  final bool voiceLocked;

  @override
  ConsumerState<_PlanMetadataSheet> createState() => _PlanMetadataSheetState();
}

class _PlanMetadataSheetState extends ConsumerState<_PlanMetadataSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _descController;
  final TextEditingController _tagInputController = TextEditingController();

  late PlanCategory _category;
  late List<String> _tags;
  late String _voice;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.initialName);
    _descController =
        TextEditingController(text: widget.initialDescription ?? '');
    _category = widget.initialCategory;
    _tags = List<String>.from(widget.initialTags);
    _voice = widget.initialVoice;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descController.dispose();
    _tagInputController.dispose();
    super.dispose();
  }

  // ── Tag management ────────────────────────────────────────────────────────

  void _addTag() {
    final tag = _tagInputController.text.trim();
    if (tag.isEmpty || _tags.contains(tag)) return;
    setState(() {
      _tags.add(tag);
      _tagInputController.clear();
    });
  }

  void _removeTag(String tag) => setState(() => _tags.remove(tag));

  // ── Save ─────────────────────────────────────────────────────────────────

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    final desc = _descController.text.trim();
    Navigator.of(context).pop(
      PlanMetadata(
        name: _nameController.text.trim(),
        description: desc.isEmpty ? null : desc,
        category: _category,
        tags: List<String>.unmodifiable(_tags),
        defaultVoice: _voice,
      ),
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              // ── Header row ───────────────────────────────────────────────
              Row(
                children: [
                  Text(
                    'Plan Details',
                    style: theme.textTheme.titleLarge,
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: _save,
                    child: const Text('Save'),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // ── Name ─────────────────────────────────────────────────────
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Name *',
                  hintText: 'e.g. Morning Yoga Flow',
                  // counterText suppresses the default character counter while
                  // still enforcing the maxLength validator.
                  counterText: '',
                ),
                maxLength: 100,
                textInputAction: TextInputAction.next,
                autofocus: true,
                validator: (v) {
                  final s = v?.trim() ?? '';
                  if (s.isEmpty) return 'Name is required';
                  if (s.length > 100) return 'Name must be 100 characters or fewer';
                  return null;
                },
              ),
              const SizedBox(height: 12),

              // ── Description ───────────────────────────────────────────────
              TextFormField(
                controller: _descController,
                decoration: const InputDecoration(
                  labelText: 'Description (optional)',
                  hintText: 'What is this plan for?',
                ),
                maxLines: 3,
                minLines: 2,
                textInputAction: TextInputAction.newline,
              ),
              const SizedBox(height: 12),

              // ── Category ──────────────────────────────────────────────────
              DropdownButtonFormField<PlanCategory>(
                value: _category,
                decoration: const InputDecoration(labelText: 'Category'),
                items: PlanCategory.values
                    .map(
                      (c) => DropdownMenuItem(
                        value: c,
                        child: Text(_categoryLabel(c)),
                      ),
                    )
                    .toList(),
                onChanged: (c) =>
                    setState(() => _category = c ?? PlanCategory.custom),
              ),
              const SizedBox(height: 12),

              // ── Default Voice ─────────────────────────────────────────────
              _buildVoiceDropdown(),
              const SizedBox(height: 16),

              // ── Tags ──────────────────────────────────────────────────────
              Text(
                'Tags',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 6),

              if (_tags.isNotEmpty) ...[
                Semantics(
                  label: 'Current tags: ${_tags.join(', ')}',
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: _tags
                        .map(
                          (tag) => InputChip(
                            label: Text(tag),
                            deleteIconColor: colorScheme.onSurfaceVariant,
                            onDeleted: () => _removeTag(tag),
                          ),
                        )
                        .toList(),
                  ),
                ),
                const SizedBox(height: 8),
              ],

              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _tagInputController,
                      decoration: const InputDecoration(
                        hintText: 'Add a tag…',
                        isDense: true,
                      ),
                      textInputAction: TextInputAction.done,
                      onFieldSubmitted: (_) => _addTag(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Semantics(
                    button: true,
                    label: 'Add tag',
                    child: IconButton.outlined(
                      onPressed: _addTag,
                      icon: const Icon(Icons.add),
                      tooltip: 'Add tag',
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  /// Resolves [voiceId] to its human-readable label in [provider]'s namespace.
  ///
  /// When the plan stores a foreign voice ID (e.g. seed library plans store
  /// Kokoro IDs like `af_bella` but the active provider is Gemini), the audio
  /// was actually generated using the cross-provider mapping. Display the
  /// label of the mapped voice so the locked picker reflects what was used.
  String _resolveDisplayLabel(TtsProviderConfig provider, String voiceId) {
    final native = provider.voices.firstWhere(
      (v) => v.id == voiceId,
      orElse: () => const TtsVoiceOption(id: '', label: ''),
    );
    if (native.id.isNotEmpty) return native.label;

    final mappedId = provider.voiceMap[voiceId];
    if (mappedId == null) return voiceId;
    final mapped = provider.voices.firstWhere(
      (v) => v.id == mappedId,
      orElse: () => const TtsVoiceOption(id: '', label: ''),
    );
    return mapped.id.isNotEmpty ? mapped.label : mappedId;
  }

  String _categoryLabel(PlanCategory c) => switch (c) {
        PlanCategory.yoga => 'Yoga',
        PlanCategory.meditation => 'Meditation',
        PlanCategory.workout => 'Workout',
        PlanCategory.cooking => 'Cooking',
        PlanCategory.routine => 'Routine',
        PlanCategory.focus => 'Focus',
        PlanCategory.custom => 'Custom',
      };

  Widget _buildVoiceDropdown() {
    final voicesAsync = ref.watch(availableVoicesProvider);

    // When TTS has been pre-generated, lock the voice to avoid cache mismatches.
    if (widget.voiceLocked) {
      final providerAsync = ref.watch(activeProviderProvider);
      final displayLabel = providerAsync.maybeWhen(
        data: (p) => _resolveDisplayLabel(p, _voice),
        orElse: () => _voice,
      );
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DropdownButtonFormField<String>(
            value: _voice,
            decoration: const InputDecoration(
              labelText: 'Default Voice',
              suffixIcon: Icon(Icons.lock_outline, size: 18),
            ),
            items: [DropdownMenuItem(value: _voice, child: Text(displayLabel))],
            onChanged: null,
          ),
          const SizedBox(height: 4),
          Text(
            'Voice is locked because AI audio has already been generated for this plan.',
            style: TextStyle(
              fontSize: 12,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      );
    }

    return voicesAsync.when(
      data: (voices) {
        if (voices.isEmpty) {
          return DropdownButtonFormField<String>(
            value: _voice,
            decoration: const InputDecoration(labelText: 'Default Voice'),
            items: [DropdownMenuItem(value: _voice, child: Text(_voice))],
            onChanged: null,
          );
        }

        // Auto-correct voice if it doesn't match the current provider.
        final validVoice = voices.any((v) => v.id == _voice)
            ? _voice
            : voices.first.id;
        if (validVoice != _voice) {
          _voice = validVoice;
        }

        return DropdownButtonFormField<String>(
          key: ValueKey(validVoice),
          value: validVoice,
          decoration: const InputDecoration(labelText: 'Default Voice'),
          items: voices
              .map((v) => DropdownMenuItem(value: v.id, child: Text(v.label)))
              .toList(),
          onChanged: (v) {
            if (v != null) setState(() => _voice = v);
          },
        );
      },
      loading: () => DropdownButtonFormField<String>(
        value: _voice,
        decoration: const InputDecoration(labelText: 'Default Voice'),
        items: [DropdownMenuItem(value: _voice, child: Text(_voice))],
        onChanged: null,
      ),
      error: (_, __) => DropdownButtonFormField<String>(
        value: _voice,
        decoration: const InputDecoration(labelText: 'Default Voice'),
        items: [DropdownMenuItem(value: _voice, child: Text(_voice))],
        onChanged: null,
      ),
    );
  }
}
