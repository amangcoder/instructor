import 'package:flutter/material.dart';

import 'package:instructor/data/audio_assets.dart';
import 'package:instructor/models/plan_step.dart';

/// Formats the audio asset key as a human-readable display name.
String _formatAudioAssetKey(String key) => switch (key) {
      kAmbientRain => 'Rain',
      kAmbientForest => 'Forest',
      kAmbientOcean => 'Ocean Waves',
      kAmbientWhiteNoise => 'White Noise',
      kAmbientTibetanBowls => 'Tibetan Bowls',
      kEffectBell => 'Bell',
      kEffectChime => 'Wind Chime',
      kEffectGong => 'Gong',
      _ => key,
    };

/// All playable asset keys (excludes internal silence track).
const _kPlayableAssets = [
  kAmbientRain,
  kAmbientForest,
  kAmbientOcean,
  kAmbientWhiteNoise,
  kAmbientTibetanBowls,
  kEffectBell,
  kEffectChime,
  kEffectGong,
];

/// A StatefulWidget for editing a [PlayStep].
class PlayStepEditor extends StatefulWidget {
  const PlayStepEditor({required this.step, required this.onUpdate});

  final PlayStep step;
  final void Function(PlanStep) onUpdate;

  @override
  State<PlayStepEditor> createState() => PlayStepEditorState();
}

/// State for [PlayStepEditor].
class PlayStepEditorState extends State<PlayStepEditor> {
  late String _audioKey;
  late bool _loop;
  late double _volume;

  @override
  void initState() {
    super.initState();
    // Ensure the asset key is a valid playable key.
    _audioKey = _kPlayableAssets.contains(widget.step.audioAssetKey)
        ? widget.step.audioAssetKey
        : kAmbientRain;
    _loop = widget.step.loop;
    _volume = widget.step.volume.clamp(0.0, 1.0);
  }

  void _push() {
    widget.onUpdate(
      widget.step.copyWith(
        audioAssetKey: _audioKey,
        loop: _loop,
        volume: _volume,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Divider(),
        const SizedBox(height: 8),

        // Audio asset dropdown
        DropdownButtonFormField<String>(
          value: _audioKey,
          decoration: const InputDecoration(labelText: 'Audio Track'),
          items: _kPlayableAssets
              .map(
                (k) => DropdownMenuItem(
                  value: k,
                  child: Text(_formatAudioAssetKey(k)),
                ),
              )
              .toList(),
          onChanged: (k) {
            if (k == null) return;
            setState(() => _audioKey = k);
            _push();
          },
        ),
        const SizedBox(height: 8),

        // Loop toggle
        SwitchListTile.adaptive(
          contentPadding: EdgeInsets.zero,
          title: const Text('Loop'),
          subtitle: const Text('Repeat continuously'),
          value: _loop,
          onChanged: (v) {
            setState(() => _loop = v);
            _push();
          },
        ),

        // Volume slider
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Volume: ${(_volume * 100).round()}%',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
            ),
            Semantics(
              label: 'Volume',
              slider: true,
              child: Slider.adaptive(
                value: _volume,
                min: 0,
                max: 1,
                divisions: 20,
                label: '${(_volume * 100).round()}%',
                onChanged: (v) => setState(() => _volume = v),
                onChangeEnd: (v) {
                  setState(() => _volume = v);
                  _push();
                },
              ),
            ),
          ],
        ),
      ],
    );
  }
}
