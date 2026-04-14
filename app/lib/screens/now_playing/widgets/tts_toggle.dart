import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:instructor/providers/tts_status_providers.dart';

/// TTS voice mode selector for the Now Playing screen.
///
/// Renders a [SegmentedButton] with two segments:
///
/// | Segment     | When available                                          |
/// |-------------|--------------------------------------------------------|
/// | Device      | Always — uses the on-device platform TTS engine.       |
/// | AI Voice    | [ttsStatus] is `'completed'` or `'partial'`.           |
///
/// ## AI Voice label states
/// - **"AI Voice"** — audio is ready; segment is selectable.
/// - **"Downloading…"** (+ spinner) — [ttsStatus] is `'pending'` or
///   `'processing'`; segment is disabled while audio is being prepared.
/// - **"AI Voice"** (greyed) — [ttsStatus] is `'none'` or `'failed'`, or
///   [isActive] is `false`; segment is disabled.
///
/// ## State management
/// Reads and writes [ttsPlaybackModeProvider].  When the AI Voice segment
/// becomes unavailable while it is the active selection (e.g. the status
/// changes to `'failed'`), the widget automatically resets the provider to
/// [TtsPlaybackMode.platform] on the next frame so downstream consumers see
/// a consistent mode.
class TtsToggle extends ConsumerWidget {
  const TtsToggle({
    super.key,
    required this.ttsStatus,
    required this.isActive,
    this.isUnavailable = false,
    this.isLocked = false,
  });

  /// The plan's server-side TTS generation status.
  ///
  /// Expected values: `none | pending | processing | completed | partial | failed`.
  final String ttsStatus;

  /// Whether a GenAI TTS generation job has been activated for this plan.
  ///
  /// When `false` (plan never activated), the AI Voice segment is always
  /// disabled, regardless of [ttsStatus].
  final bool isActive;

  /// Whether AI Voice is truly unavailable — device is offline AND the audio
  /// is not locally cached.
  ///
  /// When `true` (and [_isAiVoiceReady] is false), the AI Voice segment label
  /// reads 'Unavailable' instead of 'AI Voice' so users can distinguish
  /// "not yet downloaded" from "cannot be used right now".
  final bool isUnavailable;

  /// Whether the toggle is locked for the current step.
  ///
  /// When `true` (e.g. during a `say` or `count` step), the entire
  /// [SegmentedButton] is disabled so the voice mode cannot be changed
  /// mid-step.  The mode change takes effect on the next step instead.
  final bool isLocked;

  // ── Status classification helpers ─────────────────────────────────────────

  static const _kReadyStatuses = {'completed', 'partial'};
  static const _kDownloadingStatuses = {'pending', 'processing'};

  bool get _isDownloading => _kDownloadingStatuses.contains(ttsStatus);
  bool get _isAiVoiceReady => _kReadyStatuses.contains(ttsStatus);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentMode = ref.watch(ttsPlaybackModeProvider);
    final colorScheme = Theme.of(context).colorScheme;

    final isDownloading = _isDownloading;
    final isAiVoiceReady = _isAiVoiceReady;

    // Auto-reset: if genai is selected but no longer available, fall back to
    // platform on the next frame to keep the provider state consistent with
    // what the UI is displaying.
    if (currentMode == TtsPlaybackMode.genai && !isAiVoiceReady) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(ttsPlaybackModeProvider.notifier).state =
            TtsPlaybackMode.platform;
      });
    }

    // Use platform as the visually selected segment when genai is unavailable,
    // so the widget never appears to have an unselected / inconsistent state.
    final displayedMode =
        (currentMode == TtsPlaybackMode.genai && !isAiVoiceReady)
            ? TtsPlaybackMode.platform
            : currentMode;

    return Semantics(
      label: 'Voice mode',
      hint: isLocked
          ? 'Voice mode cannot be changed while speaking'
          : 'Select between on-device TTS and AI Voice',
      // Let the child segments provide their own semantics.
      explicitChildNodes: true,
      child: SegmentedButton<TtsPlaybackMode>(
        style: SegmentedButton.styleFrom(
          backgroundColor: colorScheme.surfaceContainerLow,
          selectedBackgroundColor: colorScheme.primaryContainer,
          selectedForegroundColor: colorScheme.onPrimaryContainer,
          foregroundColor: colorScheme.onSurfaceVariant,
          disabledForegroundColor:
              colorScheme.onSurfaceVariant.withValues(alpha: 0.38),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          visualDensity: VisualDensity.compact,
        ),
        segments: [
          // ── Device segment (always enabled) ────────────────────────────────
          const ButtonSegment<TtsPlaybackMode>(
            value: TtsPlaybackMode.platform,
            icon: Icon(Icons.phone_android_outlined, size: 16),
            label: Text('Device'),
          ),

          // ── AI Voice segment ────────────────────────────────────────────────
          ButtonSegment<TtsPlaybackMode>(
            value: TtsPlaybackMode.genai,
            icon: isDownloading
                ? SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
                    ),
                  )
                : const Icon(Icons.auto_awesome_outlined, size: 16),
            label: Text(isDownloading
                ? 'Downloading…'
                : (isUnavailable && !isAiVoiceReady ? 'Unavailable' : 'AI Voice')),
            // Disabled when not yet ready — the user must wait for download to
            // complete or activate the plan first.
            enabled: isAiVoiceReady,
          ),
        ],
        selected: {displayedMode},
        onSelectionChanged: isLocked
            ? null
            : (modes) {
                final selected = modes.first;
                // Guard: ignore selection of genai when not available (shouldn't
                // reach here when the segment is disabled, but defensive check).
                if (selected == TtsPlaybackMode.genai && !isAiVoiceReady) return;
                ref.read(ttsPlaybackModeProvider.notifier).state = selected;
              },
      ),
    );
  }
}
