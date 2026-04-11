import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:instructor/models/tts_provider_config.dart';
import 'package:instructor/providers/tts_providers.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Public API
// ─────────────────────────────────────────────────────────────────────────────

/// Shows a modal bottom sheet that displays voices for [providerId] and
/// returns the selected [TtsVoiceOption], or `null` if dismissed.
///
/// Only voices for [providerId] are shown (filtered from the cached catalog).
/// ElevenLabs opaque voice IDs are shown using their human-readable labels.
Future<TtsVoiceOption?> showVoicePickerSheet(
  BuildContext context, {
  required String providerId,
  String? currentVoiceId,
}) {
  return showModalBottomSheet<TtsVoiceOption>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => ProviderScope(
      parent: ProviderScope.containerOf(context),
      child: _VoicePickerSheet(
        providerId: providerId,
        currentVoiceId: currentVoiceId,
      ),
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// Sheet widget
// ─────────────────────────────────────────────────────────────────────────────

class _VoicePickerSheet extends ConsumerStatefulWidget {
  const _VoicePickerSheet({
    required this.providerId,
    this.currentVoiceId,
  });

  final String providerId;
  final String? currentVoiceId;

  @override
  ConsumerState<_VoicePickerSheet> createState() => _VoicePickerSheetState();
}

class _VoicePickerSheetState extends ConsumerState<_VoicePickerSheet> {
  String? _selectedVoiceId;
  final TextEditingController _searchController = TextEditingController();

  // Local search query — kept in state so the search field is stateful.
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _selectedVoiceId = widget.currentVoiceId;
    _searchController.addListener(_onSearch);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onSearch() {
    final query = _searchController.text.toLowerCase().trim();
    if (query != _searchQuery) {
      setState(() => _searchQuery = query);
    }
  }

  /// Filters [voices] by the current [_searchQuery].
  List<TtsVoiceOption> _applyFilter(List<TtsVoiceOption> voices) {
    if (_searchQuery.isEmpty) return voices;
    return voices
        .where(
          (v) =>
              v.label.toLowerCase().contains(_searchQuery) ||
              v.id.toLowerCase().contains(_searchQuery),
        )
        .toList();
  }

  void _onConfirm(List<TtsVoiceOption> allVoices) {
    if (_selectedVoiceId == null) return;
    final selected = allVoices.firstWhere(
      (v) => v.id == _selectedVoiceId,
      orElse: () => allVoices.first,
    );
    Navigator.of(context).pop(selected);
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final mediaQuery = MediaQuery.of(context);

    // Watch the Riverpod provider — rebuilds instantly when catalog refreshes.
    final voicesAsync = ref.watch(voicesForProviderProvider(widget.providerId));

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          constraints: BoxConstraints(
            maxHeight: mediaQuery.size.height * 0.85,
          ),
          decoration: BoxDecoration(
            color: colorScheme.surface.withValues(alpha: 0.92),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            boxShadow: [
              BoxShadow(
                color: colorScheme.shadow.withValues(alpha: 0.1),
                blurRadius: 32,
                offset: const Offset(0, -8),
              ),
            ],
          ),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // ── Handle ─────────────────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.only(top: 12, bottom: 8),
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),

                // ── Title ──────────────────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    children: [
                      Text(
                        'Select Voice',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                      const Spacer(),
                      // Show provider label from loaded catalog if available;
                      // fall back to a simple string map for loading state.
                      voicesAsync.when(
                        data: (_) => Text(
                          const {
                            'kokoro': 'Kokoro',
                            'gemini': 'Gemini',
                            'elevenlabs': 'ElevenLabs',
                          }[widget.providerId] ??
                              widget.providerId,
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: colorScheme.onSurfaceVariant,
                                  ),
                        ),
                        loading: () => const SizedBox.shrink(),
                        error: (_, __) => const SizedBox.shrink(),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 12),

                // ── Search field ────────────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Search voices…',
                      prefixIcon: const Icon(Icons.search, size: 20),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, size: 18),
                              onPressed: () => _searchController.clear(),
                            )
                          : null,
                      filled: true,
                      fillColor: colorScheme.surfaceContainer,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 10),
                    ),
                  ),
                ),

                const SizedBox(height: 8),

                // ── Voice list ──────────────────────────────────────────────
                Flexible(
                  child: voicesAsync.when(
                    loading: () => const Center(
                      child: Padding(
                        padding: EdgeInsets.all(32),
                        child: CircularProgressIndicator(),
                      ),
                    ),
                    error: (error, _) => Padding(
                      padding: const EdgeInsets.all(32),
                      child: Text(
                        'Could not load voices.',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: colorScheme.error,
                            ),
                      ),
                    ),
                    data: (allVoices) {
                      final filtered = _applyFilter(allVoices);
                      if (filtered.isEmpty) {
                        return Padding(
                          padding: const EdgeInsets.all(32),
                          child: Text(
                            _searchQuery.isEmpty
                                ? 'No voices available.'
                                : 'No voices found.',
                            style:
                                Theme.of(context).textTheme.bodyMedium?.copyWith(
                                      color: colorScheme.onSurfaceVariant,
                                    ),
                          ),
                        );
                      }
                      return ListView.builder(
                        shrinkWrap: true,
                        padding: const EdgeInsets.only(
                            left: 8, right: 8, bottom: 8),
                        itemCount: filtered.length,
                        itemBuilder: (context, index) {
                          final voice = filtered[index];
                          final isSelected = _selectedVoiceId == voice.id;
                          return RadioListTile<String>(
                            value: voice.id,
                            groupValue: _selectedVoiceId,
                            onChanged: (v) =>
                                setState(() => _selectedVoiceId = v),
                            title: Text(
                              voice.label,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w500),
                            ),
                            subtitle: voice.gender != null
                                ? Text(
                                    voice.gender!,
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodySmall,
                                  )
                                : null,
                            activeColor: colorScheme.primary,
                            selected: isSelected,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),

                // ── Action buttons ──────────────────────────────────────────
                voicesAsync.when(
                  data: (allVoices) => Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                    child: Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.of(context).pop(null),
                            style: OutlinedButton.styleFrom(
                              padding:
                                  const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: const Text('Cancel'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: FilledButton(
                            onPressed: _selectedVoiceId != null
                                ? () => _onConfirm(allVoices)
                                : null,
                            style: FilledButton.styleFrom(
                              padding:
                                  const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: const Text('Confirm'),
                          ),
                        ),
                      ],
                    ),
                  ),
                  loading: () => Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(null),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text('Cancel'),
                    ),
                  ),
                  error: (_, __) => Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(null),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text('Close'),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
