/// Mapping from logical audio asset keys to bundled asset paths.
///
/// Used by [AudioEngine.startAmbient] to resolve asset keys from [PlayStep]
/// and [StopAudioStep] into actual Flutter asset paths.
///
/// ## Ambient tracks (15 total — compressed MP3, ≤7 MB each)
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

/// Crackling campfire — warm, cozy; good for journaling / evening wind-downs.
const String kAmbientCampfire = 'campfire';

/// Night crickets — gentle, rhythmic; good for evening meditation / sleep.
const String kAmbientCrickets = 'crickets';

/// Babbling brook — serene, flowing; good for mindfulness / walking meditation.
const String kAmbientBabblingBrook = 'babbling_brook';

/// Waterfall — immersive, steady; good for deep focus / stress relief.
const String kAmbientWaterfall = 'waterfall';

/// Tropical rainforest ambience (birds + insects) — lush; good for energising yoga.
const String kAmbientRainforest = 'rainforest';

/// Thunderstorm (rain + thunder) — dramatic; good for intense breathwork /
/// power workouts.
const String kAmbientThunderstorm = 'thunderstorm';

/// Steady wind — airy, open; good for grounding exercises / visualisation.
const String kAmbientWind = 'wind';

/// Bird song in forest — uplifting; good for morning routines / nature meditation.
const String kAmbientBirdSong = 'bird_song';

/// Beach soundscape (waves + shore ambience) — relaxing; good for coastal
/// visualisations / breathwork.
const String kAmbientBeach = 'beach';

/// Frogs at dusk — earthy, alive; good for sleep wind-downs / restorative yoga.
const String kAmbientFrogs = 'frogs';

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

/// 60-second silent audio file for OS keep-alive during wait steps.
///
/// Played in discrete chunks (not infinite loop) so that iOS / Android see
/// natural play-complete-restart cycles instead of a suspicious infinite loop.
/// Not intended to be used directly in Plan steps.
const String kSilenceTrack = 'silence_60s';

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
  kAmbientCampfire: 'assets/audio/ambient/campfire.mp3',
  kAmbientCrickets: 'assets/audio/ambient/crickets.mp3',
  kAmbientBabblingBrook: 'assets/audio/ambient/babbling_brook.mp3',
  kAmbientWaterfall: 'assets/audio/ambient/waterfall.mp3',
  kAmbientRainforest: 'assets/audio/ambient/rainforest.mp3',
  kAmbientThunderstorm: 'assets/audio/ambient/thunderstorm.mp3',
  kAmbientWind: 'assets/audio/ambient/wind.mp3',
  kAmbientBirdSong: 'assets/audio/ambient/bird_song.mp3',
  kAmbientBeach: 'assets/audio/ambient/beach.mp3',
  kAmbientFrogs: 'assets/audio/ambient/frogs.mp3',

  // Effects
  kEffectBell: 'assets/audio/effects/bell.mp3',
  kEffectChime: 'assets/audio/effects/chime.mp3',
  kEffectGong: 'assets/audio/effects/gong.mp3',

  // Silence (OS keep-alive — 60-second chunks)
  kSilenceTrack: 'assets/audio/silence/silence_60s.mp3',
};

/// Returns `true` if [key] is a known ambient track key.
bool isAmbientKey(String key) => const {
      kAmbientRain,
      kAmbientForest,
      kAmbientOcean,
      kAmbientWhiteNoise,
      kAmbientTibetanBowls,
      kAmbientCampfire,
      kAmbientCrickets,
      kAmbientBabblingBrook,
      kAmbientWaterfall,
      kAmbientRainforest,
      kAmbientThunderstorm,
      kAmbientWind,
      kAmbientBirdSong,
      kAmbientBeach,
      kAmbientFrogs,
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
