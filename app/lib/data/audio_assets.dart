/// Mapping from logical audio asset keys to bundled asset paths.
///
/// Used by [AudioEngine.startAmbient] to resolve asset keys from [PlayStep]
/// and [StopAudioStep] into actual Flutter asset paths.
///
/// ## Ambient tracks (5 total — compressed AAC/OGG, ≤5 MB each)
/// Looping background audio designed for meditation, yoga, workouts, etc.
///
/// ## Effect sounds (3 total — short, percussive)
/// One-shot sounds used for step transitions, timers, and notifications.
///
/// ## Silence (1 — 1-second silent loop)
/// Played on the ambient channel during wait steps to keep the iOS
/// AVAudioSession active and prevent OS suspension.
library audio_assets;

// ────────────────────────────────────────────────────────────────────────────
// Ambient track asset keys
// ────────────────────────────────────────────────────────────────────────────

/// Soft rain on leaves — calming, good for meditation / focus.
const String kAmbientRain = 'rain';

/// Forest ambience (birds, wind) — refreshing, good for yoga / morning
/// routines.
const String kAmbientForest = 'forest';

/// Ocean waves — rhythmic, good for breathwork / sleep wind-downs.
const String kAmbientOcean = 'ocean';

/// White noise (broadband) — neutral, good for focus / study sessions.
const String kAmbientWhiteNoise = 'white_noise';

/// Tibetan singing bowls drone — meditative, good for deep meditation /
/// body scans.
const String kAmbientTibetanBowls = 'tibetan_bowls';

// ────────────────────────────────────────────────────────────────────────────
// Effect sound asset keys
// ────────────────────────────────────────────────────────────────────────────

/// Soft bell — step start / transition marker.
const String kEffectBell = 'bell';

/// Wind chime — light transition, end of section.
const String kEffectChime = 'chime';

/// Deep gong strike — session end, major section boundary.
const String kEffectGong = 'gong';

// ────────────────────────────────────────────────────────────────────────────
// Silence key (internal — used by AudioEngine for iOS keep-alive)
// ────────────────────────────────────────────────────────────────────────────

/// 1-second silent audio loop for iOS AVAudioSession keep-alive during wait
/// steps. Not intended to be used directly in Plan steps.
const String kSilenceTrack = 'silence';

// ────────────────────────────────────────────────────────────────────────────
// Asset path map
// ────────────────────────────────────────────────────────────────────────────

/// Full mapping of logical asset keys → Flutter asset bundle paths.
///
/// Keys must match the values bundled under the asset directories declared in
/// `pubspec.yaml`. The exact filenames below must exist in the repository.
const Map<String, String> kAudioAssetPaths = {
  // Ambient
  kAmbientRain: 'assets/audio/ambient/rain.mp3',
  kAmbientForest: 'assets/audio/ambient/forest.mp3',
  kAmbientOcean: 'assets/audio/ambient/ocean.mp3',
  kAmbientWhiteNoise: 'assets/audio/ambient/white_noise.mp3',
  kAmbientTibetanBowls: 'assets/audio/ambient/tibetan_bowls.mp3',

  // Effects
  kEffectBell: 'assets/audio/effects/bell.mp3',
  kEffectChime: 'assets/audio/effects/chime.mp3',
  kEffectGong: 'assets/audio/effects/gong.mp3',

  // Silence (iOS keep-alive)
  kSilenceTrack: 'assets/audio/silence/silence.mp3',
};

/// Returns `true` if [key] is a known ambient track key.
bool isAmbientKey(String key) => const {
      kAmbientRain,
      kAmbientForest,
      kAmbientOcean,
      kAmbientWhiteNoise,
      kAmbientTibetanBowls,
    }.contains(key);

/// Returns `true` if [key] is a known effect sound key.
bool isEffectKey(String key) => const {
      kEffectBell,
      kEffectChime,
      kEffectGong,
    }.contains(key);

/// Resolves [assetKey] to its Flutter asset path.
///
/// Throws [ArgumentError] if the key is not found in [kAudioAssetPaths].
String resolveAudioAssetPath(String assetKey) {
  final path = kAudioAssetPaths[assetKey];
  if (path == null) {
    throw ArgumentError.value(
      assetKey,
      'assetKey',
      'Unknown audio asset key. Valid keys: ${kAudioAssetPaths.keys.join(', ')}',
    );
  }
  return path;
}
