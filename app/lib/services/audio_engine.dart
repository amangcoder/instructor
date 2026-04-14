/// AudioEngine — dual-channel audio playback with volume ducking.
///
/// ## Architecture
/// Two independent [AudioPlayer] instances handle separate concerns:
///
/// - **_ambientPlayer** — looping background audio (rain, forest, bowls…).
///   Supports volume control, looping, seeking (for crash recovery), and
///   graceful fade-out on stop.
///
/// - **_voicePlayer** — one-shot TTS audio and effect sounds (bell, chime…).
///   Triggers volume ducking on the ambient channel while active.
///
/// A third **_silencePlayer** loops a 1-second silent asset during wait steps
/// to keep the iOS AVAudioSession active and prevent OS suspension. It is
/// managed internally and never exposed through the public API.
///
/// ## Volume ducking
/// When [playVoice] is called:
///   1. The ambient volume fades from its current level to 20% over 300 ms.
///   2. The voice audio plays.
///   3. When the voice player's [ProcessingState] becomes `completed`, the
///      ambient volume fades back to its pre-duck level over 300 ms.
///
/// All fades use a [Timer]-based linear interpolation at ~60 fps (16 ms
/// ticks). Any in-progress fade is cancelled and replaced when a new fade
/// starts, ensuring clean cross-fades even if [playVoice] is called rapidly.
library audio_engine;

import 'dart:async';
import 'dart:developer';
import 'dart:io';

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:instructor/data/audio_assets.dart';

part 'audio_engine.g.dart';

// ────────────────────────────────────────────────────────────────────────────
// Exceptions
// ────────────────────────────────────────────────────────────────────────────

/// Thrown by [AudioEngine.playVoice] and [AudioEngine.playEffect] when
/// [AudioEngine.stopAll] or [AudioEngine.dispose] interrupts in-progress
/// audio playback before natural completion.
///
/// The [PlanExecutionEngine] catches this exception to distinguish a
/// deliberate user-requested stop from an unexpected audio error, so that
/// the execution engine can cleanly halt without logging a spurious error.
class StoppedByUserException implements Exception {
  const StoppedByUserException();

  @override
  String toString() =>
      'StoppedByUserException: audio playback was stopped by the user';
}

// ────────────────────────────────────────────────────────────────────────────
// Public interface
// ────────────────────────────────────────────────────────────────────────────

/// Abstract interface for the audio engine, enabling mocking in tests.
abstract class AudioEngine {
  /// Plays a TTS or effect audio file on the voice channel.
  ///
  /// Automatically ducks the ambient channel to [kDuckVolume] (20%) before
  /// playback and restores the original volume when the file finishes.
  ///
  /// If a voice file is already playing it is replaced immediately (the duck
  /// stays active until the new file completes).
  Future<void> playVoice(String filePath, {double speed = 1.0});

  /// Plays a one-shot effect sound (bell, chime, gong) on the voice channel.
  ///
  /// Ducks the ambient channel while the effect plays, then restores it.
  /// The [assetKey] is resolved via [resolveAudioAssetPath].
  Future<void> playEffect(String assetKey);

  /// Starts an ambient track identified by [assetKey].
  ///
  /// [assetKey] must be one of the keys defined in [kAudioAssetPaths]
  /// (e.g. [kAmbientRain]). Throws [ArgumentError] for unknown keys.
  ///
  /// [loop] — whether to loop the track indefinitely (default: `true`).
  /// [volume] — initial playback volume in [0.0, 1.0] (default: `1.0`).
  Future<void> startAmbient(
    String assetKey, {
    bool loop = true,
    double volume = 1.0,
  });

  /// Stops the ambient channel with an optional fade-out over [fadeOutMs]
  /// milliseconds (default: 500 ms). Pass `fadeOutMs: 0` for instant stop.
  Future<void> stopAmbient({int fadeOutMs = 500});

  /// Reduces ambient volume to [kDuckVolume] (20%) over [kDuckDurationMs]
  /// milliseconds.
  ///
  /// Called automatically by [playVoice]; exposed here so the
  /// [PlanExecutionEngine] can duck proactively (e.g. before a TTS request
  /// completes and a voice file is ready).
  Future<void> duckAmbient();

  /// Restores the ambient volume to its pre-duck target over
  /// [kDuckDurationMs] milliseconds.
  ///
  /// Called automatically when the voice player finishes. Exposed for manual
  /// control by [PlanExecutionEngine] when needed.
  Future<void> restoreAmbient();

  /// Stops all audio channels immediately (no fade).
  Future<void> stopAll();

  /// Duration of the currently loaded voice audio file.
  ///
  /// Available as soon as the voice player has decoded the file header
  /// (i.e. right after [playVoice] calls `setFilePath`). Returns `null`
  /// when no voice file is loaded or the file has not yet been decoded.
  ///
  /// Used by [PlanExecutionEngine] to display an accurate countdown timer
  /// for [SayStep]s.
  Duration? get currentVoiceDuration;

  /// The current playback position within the voice audio file (at 1× speed).
  ///
  /// Used by [PlanExecutionEngine] when the user changes playback speed
  /// mid-step to recompute how much audio content remains.
  Duration? get currentVoicePosition;

  /// Changes the playback speed of the voice channel while audio is playing.
  ///
  /// Safe to call at any time — [just_audio] applies speed changes to an
  /// in-progress playback immediately without interrupting the stream.
  ///
  /// [speed] is clamped to [0.5, 2.0] before being applied.
  Future<void> setVoiceSpeed(double speed);

  /// The current playback position of the ambient audio.
  ///
  /// Returns `null` when no ambient track is loaded.  Used by
  /// [PlanExecutionEngine] to persist the position on every step transition
  /// for crash recovery.
  Duration? get currentAmbientPosition;

  /// The asset key passed to the most recent [startAmbient] call, or `null`
  /// if no ambient track is currently loaded (i.e. [stopAll] or
  /// [stopAmbient] was called after the last [startAmbient]).
  ///
  /// Used by [PlanExecutionEngine] to re-load the correct ambient track when
  /// resuming a paused session.
  String? get currentAmbientAssetKey;

  /// Seeks the ambient player to [position].
  ///
  /// Used during crash recovery to resume ambient audio at the exact position
  /// where execution was interrupted.
  Future<void> seekAmbient(Duration position);

  /// Starts the silent keep-alive loop on the internal silence channel.
  ///
  /// Must be called at the beginning of every wait step on iOS to prevent
  /// the OS from suspending the app due to audio inactivity.
  Future<void> startSilenceKeepAlive();

  /// Stops the silence keep-alive loop.
  Future<void> stopSilenceKeepAlive();

  /// Releases all resources. Called by the Riverpod provider's [onDispose].
  Future<void> dispose();
}

// ────────────────────────────────────────────────────────────────────────────
// Constants
// ────────────────────────────────────────────────────────────────────────────

/// Target ambient volume while a voice file is playing (20%).
const double kDuckVolume = 0.2;

/// Duration of the duck-in and duck-out fade in milliseconds (300 ms).
const int kDuckDurationMs = 300;

/// Duration of the default ambient fade-out in milliseconds (500 ms).
const int kDefaultFadeOutMs = 500;

/// Fade step interval in milliseconds (~60 fps).
const int _kFadeStepMs = 16;

// ────────────────────────────────────────────────────────────────────────────
// Concrete implementation
// ────────────────────────────────────────────────────────────────────────────

/// Concrete implementation of [AudioEngine] backed by two [AudioPlayer]
/// instances from the `just_audio` package.
///
/// Constructor accepts optional [AudioPlayer] instances to enable dependency
/// injection in unit tests.
class AudioEngineImpl implements AudioEngine {
  AudioEngineImpl({
    AudioPlayer? ambientPlayer,
    AudioPlayer? voicePlayer,
    AudioPlayer? silencePlayer,
  })  : _ambientPlayer = ambientPlayer ?? AudioPlayer(),
        _voicePlayer = voicePlayer ?? AudioPlayer(),
        _silencePlayer = silencePlayer ?? AudioPlayer();

  // ── Players ──────────────────────────────────────────────────────────────

  final AudioPlayer _ambientPlayer;
  final AudioPlayer _voicePlayer;

  /// Internal player for OS keep-alive during wait steps.
  final AudioPlayer _silencePlayer;

  /// True while the silence keep-alive cycle is active.
  bool _silenceKeepAliveActive = false;

  /// Subscription to [_silencePlayer.processingStateStream] for detecting
  /// when a silence chunk finishes so we can restart with the next chunk.
  StreamSubscription<ProcessingState>? _silenceCompletionSub;

  // ── Volume state ─────────────────────────────────────────────────────────

  /// The volume that ambient audio should play at (set by [startAmbient]).
  double _targetAmbientVolume = 1.0;

  /// The actual current ambient volume (may differ from [_targetAmbientVolume]
  /// while ducking/restoring).
  double _currentAmbientVolume = 1.0;

  // ── Fade / duck state ────────────────────────────────────────────────────

  Timer? _fadeTimer;
  Completer<void>? _fadeCompleter;
  StreamSubscription<ProcessingState>? _voiceCompletionSubscription;

  /// Completer resolved when voice playback finishes (or is interrupted).
  ///
  /// Allows [playVoice] to await playback completion. Completed by [stopAll]
  /// or [dispose] to unblock any in-progress [playVoice] call.
  Completer<void>? _voiceCompleter;

  // ── Ambient track identity ────────────────────────────────────────────────

  /// The asset key of the most recently loaded ambient track, or `null`.
  String? _currentAmbientAssetKey;

  // ── Lifecycle guard ──────────────────────────────────────────────────────

  bool _disposed = false;

  // ────────────────────────────────────────────────────────────────────────
  // Public API — Voice channel
  // ────────────────────────────────────────────────────────────────────────

  @override
  Future<void> playVoice(String filePath, {double speed = 1.0}) async {
    _assertNotDisposed();

    debugPrint('AudioEngine: playVoice called — file=$filePath, speed=$speed');

    // Verify the file exists and has content before attempting playback.
    final file = File(filePath);
    if (!await file.exists()) {
      throw StateError('AudioEngine: file does not exist: $filePath');
    }
    final fileSize = await file.length();
    debugPrint('AudioEngine: file verified — $fileSize bytes');
    // debugger(message: 'playVoice entry — file=$filePath, size=$fileSize bytes, speed=$speed');
    if (fileSize == 0) {
      throw StateError('AudioEngine: file is empty: $filePath');
    }

    // Cancel any in-progress restore fade from a previous voice playback.
    _cancelFade();
    _voiceCompletionSubscription?.cancel();
    _voiceCompletionSubscription = null;

    // Unblock any previous pending playVoice call (rapid succession guard).
    // Complete with StoppedByUserException so the previous caller (e.g.
    // _executeSayStep) treats the interruption as a deliberate stop rather than
    // a successful completion — preventing voicePlayedSuccessfully=true and the
    // consequent ambient duck staying active after rapid step transitions.
    if (_voiceCompleter != null && !_voiceCompleter!.isCompleted) {
      _voiceCompleter!.completeError(const StoppedByUserException());
    }
    _voiceCompleter = Completer<void>();

    // Duck ambient channel before starting voice.
    await _animateAmbientVolume(
      from: _currentAmbientVolume,
      to: kDuckVolume,
      durationMs: kDuckDurationMs,
    );

    // Load and play the voice file at the requested speed.
    debugPrint('AudioEngine: loading file into player…');
    await _voicePlayer.setFilePath(filePath);
    final duration = _voicePlayer.duration;
    debugPrint('AudioEngine: file loaded — duration=$duration');
    await _voicePlayer.setSpeed(speed.clamp(0.5, 2.0));
    await _voicePlayer.seek(Duration.zero);

    // Listen for completion OR unexpected idle (error recovery).
    _voiceCompletionSubscription = _voicePlayer.processingStateStream
        .listen((state) {
      debugPrint('AudioEngine: processingState=$state');
      if (state == ProcessingState.completed) {
        _voiceCompletionSubscription?.cancel();
        _voiceCompletionSubscription = null;
        unawaited(restoreAmbient());
        if (!(_voiceCompleter?.isCompleted ?? true)) {
          _voiceCompleter!.complete();
        }
        _voiceCompleter = null;
      } else if (state == ProcessingState.idle) {
        // Player transitioned to idle without completing — likely a decoding
        // or audio-focus error that didn't surface through play().
        _voiceCompletionSubscription?.cancel();
        _voiceCompletionSubscription = null;
        unawaited(restoreAmbient());
        if (!(_voiceCompleter?.isCompleted ?? true)) {
          _voiceCompleter!.completeError(
            StateError('AudioEngine: player went idle without completing '
                '(possible decoding error for $filePath)'),
          );
        }
        _voiceCompleter = null;
      }
    });

    // Guard against playback errors. just_audio surfaces errors through the
    // play() Future. Without catching them, a failed play() would leave
    // _voiceCompleter pending forever and hang the execution engine.
    debugPrint('AudioEngine: calling play()…');
    _voicePlayer.play().catchError((Object e) {
      debugPrint('AudioEngine: play() error — $e');
      _voiceCompletionSubscription?.cancel();
      _voiceCompletionSubscription = null;
      unawaited(restoreAmbient());
      if (!(_voiceCompleter?.isCompleted ?? true)) {
        _voiceCompleter!.completeError(e);
      }
      _voiceCompleter = null;
    });

    // Await completion so that the caller (PlanExecutionEngine) can sequence
    // steps correctly — the next step only starts after voice is done.
    await _voiceCompleter!.future;
    debugPrint('AudioEngine: playVoice completed');
  }

  @override
  Future<void> playEffect(String assetKey) async {
    _assertNotDisposed();
    final assetPath = resolveAudioAssetPath(assetKey);

    // Reuse the voice channel: duck ambient, play the effect, restore.
    _cancelFade();
    _voiceCompletionSubscription?.cancel();
    _voiceCompletionSubscription = null;

    if (_voiceCompleter != null && !_voiceCompleter!.isCompleted) {
      _voiceCompleter!.completeError(const StoppedByUserException());
    }
    _voiceCompleter = Completer<void>();

    await _animateAmbientVolume(
      from: _currentAmbientVolume,
      to: kDuckVolume,
      durationMs: kDuckDurationMs,
    );

    await _voicePlayer.setSpeed(1.0);
    await _voicePlayer.setAsset(assetPath);
    await _voicePlayer.seek(Duration.zero);

    // Listen for completion OR unexpected idle (error recovery) — same pattern
    // as playVoice so that effects that fail to decode don't hang the engine.
    _voiceCompletionSubscription = _voicePlayer.processingStateStream
        .listen((state) {
      if (state == ProcessingState.completed) {
        _voiceCompletionSubscription?.cancel();
        _voiceCompletionSubscription = null;
        unawaited(restoreAmbient());
        if (!(_voiceCompleter?.isCompleted ?? true)) {
          _voiceCompleter!.complete();
        }
        _voiceCompleter = null;
      } else if (state == ProcessingState.idle) {
        // Player transitioned to idle without completing — likely a decoding
        // or audio-focus error that didn't surface through play().
        _voiceCompletionSubscription?.cancel();
        _voiceCompletionSubscription = null;
        unawaited(restoreAmbient());
        if (!(_voiceCompleter?.isCompleted ?? true)) {
          _voiceCompleter!.completeError(
            StateError('AudioEngine: effect player went idle without completing '
                '(possible decoding error for $assetKey)'),
          );
        }
        _voiceCompleter = null;
      }
    });

    _voicePlayer.play().catchError((Object e) {
      _voiceCompletionSubscription?.cancel();
      _voiceCompletionSubscription = null;
      unawaited(restoreAmbient());
      if (!(_voiceCompleter?.isCompleted ?? true)) {
        _voiceCompleter!.completeError(e);
      }
      _voiceCompleter = null;
    });

    await _voiceCompleter!.future;
  }

  // ────────────────────────────────────────────────────────────────────────
  // Public API — Ambient channel
  // ────────────────────────────────────────────────────────────────────────

  @override
  Future<void> startAmbient(
    String assetKey, {
    bool loop = true,
    double volume = 1.0,
  }) async {
    _assertNotDisposed();

    final newVolume = volume.clamp(0.0, 1.0);

    // Cancel any in-progress duck/restore fade before touching volume state.
    _cancelFade();

    // If the same track is already playing, just update the volume — do NOT
    // call setAsset() again. setAsset() stops and reloads the player, which
    // causes an audible gap every time a PlayStep is encountered inside a
    // repeat block.
    if (assetKey == _currentAmbientAssetKey && _ambientPlayer.playing) {
      _targetAmbientVolume = newVolume;
      _currentAmbientVolume = newVolume;
      await _ambientPlayer.setVolume(newVolume);
      return;
    }

    _targetAmbientVolume = newVolume;
    _currentAmbientVolume = _targetAmbientVolume;
    _currentAmbientAssetKey = assetKey;

    final assetPath = resolveAudioAssetPath(assetKey);

    await _ambientPlayer.setLoopMode(loop ? LoopMode.one : LoopMode.off);
    await _ambientPlayer.setVolume(_targetAmbientVolume);
    await _ambientPlayer.setAsset(assetPath);
    unawaited(_ambientPlayer.play());
  }

  @override
  Future<void> stopAmbient({int fadeOutMs = kDefaultFadeOutMs}) async {
    _assertNotDisposed();
    _cancelFade();
    _currentAmbientAssetKey = null;

    if (fadeOutMs > 0 && _ambientPlayer.playing) {
      await _animateAmbientVolume(
        from: _currentAmbientVolume,
        to: 0.0,
        durationMs: fadeOutMs,
      );
    }

    await _ambientPlayer.stop();
    // Reset volume state so the next startAmbient begins at full volume.
    _currentAmbientVolume = _targetAmbientVolume;
  }

  @override
  Future<void> duckAmbient() async {
    _assertNotDisposed();
    await _animateAmbientVolume(
      from: _currentAmbientVolume,
      to: kDuckVolume,
      durationMs: kDuckDurationMs,
    );
  }

  @override
  Future<void> restoreAmbient() async {
    if (_disposed) return;
    await _animateAmbientVolume(
      from: _currentAmbientVolume,
      to: _targetAmbientVolume,
      durationMs: kDuckDurationMs,
    );
  }

  // ────────────────────────────────────────────────────────────────────────
  // Public API — Stop all
  // ────────────────────────────────────────────────────────────────────────

  @override
  Future<void> stopAll() async {
    if (_disposed) return;
    _cancelFade();
    _silenceKeepAliveActive = false;
    _silenceCompletionSub?.cancel();
    _silenceCompletionSub = null;
    _voiceCompletionSubscription?.cancel();
    _voiceCompletionSubscription = null;
    _currentAmbientAssetKey = null;

    // Signal any pending playVoice()/playEffect() awaiter that the stop was
    // deliberate (not an audio error) so the execution engine can cleanly
    // halt rather than logging a spurious error.
    if (_voiceCompleter != null && !_voiceCompleter!.isCompleted) {
      _voiceCompleter!.completeError(const StoppedByUserException());
    }
    _voiceCompleter = null;

    await Future.wait([
      _ambientPlayer.stop(),
      _voicePlayer.stop(),
      _silencePlayer.stop(),
    ]);

    _currentAmbientVolume = _targetAmbientVolume;
  }

  // ────────────────────────────────────────────────────────────────────────
  // Public API — Position tracking
  // ────────────────────────────────────────────────────────────────────────

  @override
  Duration? get currentVoiceDuration {
    // just_audio returns null for duration when no file is loaded.
    final d = _voicePlayer.duration;
    if (d == null || d == Duration.zero) return null;
    return d;
  }

  @override
  Duration? get currentVoicePosition => _voicePlayer.playing ? _voicePlayer.position : null;

  @override
  Future<void> setVoiceSpeed(double speed) async {
    await _voicePlayer.setSpeed(speed.clamp(0.5, 2.0));
  }

  @override
  Duration? get currentAmbientPosition {
    // just_audio returns a zero Duration when not loaded; we return null so
    // callers can distinguish "no ambient" from "ambient at 0:00".
    if (!_ambientPlayer.playing && _ambientPlayer.duration == null) {
      return null;
    }
    return _ambientPlayer.position;
  }

  @override
  String? get currentAmbientAssetKey => _currentAmbientAssetKey;

  @override
  Future<void> seekAmbient(Duration position) async {
    _assertNotDisposed();
    await _ambientPlayer.seek(position);
  }

  // ────────────────────────────────────────────────────────────────────────
  // Public API — iOS silence keep-alive
  // ────────────────────────────────────────────────────────────────────────

  @override
  Future<void> startSilenceKeepAlive() async {
    if (_disposed) return;
    _silenceKeepAliveActive = true;
    await _playSilenceChunk();
  }

  @override
  Future<void> stopSilenceKeepAlive() async {
    _silenceKeepAliveActive = false;
    _silenceCompletionSub?.cancel();
    _silenceCompletionSub = null;
    if (_disposed) return;
    await _silencePlayer.stop();
  }

  /// Plays a single 60-second silence chunk and listens for completion to
  /// restart the next chunk. This creates natural play-complete-restart
  /// cycles that iOS and Android treat as legitimate audio activity, unlike
  /// an infinite loop of a tiny silence file which the OS can detect and
  /// kill after 10-15 minutes.
  Future<void> _playSilenceChunk() async {
    if (_disposed || !_silenceKeepAliveActive) return;

    _silenceCompletionSub?.cancel();
    final silencePath = resolveAudioAssetPath(kSilenceTrack);
    await _silencePlayer.setLoopMode(LoopMode.off);
    await _silencePlayer.setVolume(0.0);
    await _silencePlayer.setAsset(silencePath);

    _silenceCompletionSub = _silencePlayer.processingStateStream.listen(
      (state) {
        if (state == ProcessingState.completed && _silenceKeepAliveActive) {
          debugPrint('AudioEngine: silence chunk completed — restarting');
          unawaited(_playSilenceChunk());
        }
      },
    );

    unawaited(_silencePlayer.play());
  }

  // ────────────────────────────────────────────────────────────────────────
  // Lifecycle
  // ────────────────────────────────────────────────────────────────────────

  @override
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;

    _cancelFade();
    _silenceKeepAliveActive = false;
    _silenceCompletionSub?.cancel();
    _silenceCompletionSub = null;
    _voiceCompletionSubscription?.cancel();
    _voiceCompletionSubscription = null;

    // Unblock any pending playVoice() awaiter before tearing down players.
    // Use StoppedByUserException so the caller can distinguish dispose from
    // an audio error.
    if (_voiceCompleter != null && !_voiceCompleter!.isCompleted) {
      _voiceCompleter!.completeError(const StoppedByUserException());
    }
    _voiceCompleter = null;

    await Future.wait([
      _ambientPlayer.dispose(),
      _voicePlayer.dispose(),
      _silencePlayer.dispose(),
    ]);
  }

  // ────────────────────────────────────────────────────────────────────────
  // Private helpers — volume fade
  // ────────────────────────────────────────────────────────────────────────

  /// Smoothly animates the ambient player's volume from [from] to [to] over
  /// [durationMs] milliseconds using [_kFadeStepMs]-tick intervals (~60 fps).
  ///
  /// Cancels any in-progress fade before starting. Resolves when the
  /// animation completes or when the target volume is reached instantly
  /// (for zero-duration or trivially-small durations).
  Future<void> _animateAmbientVolume({
    required double from,
    required double to,
    required int durationMs,
  }) {
    // Cancel any existing fade and complete its completer (if still pending)
    // so that any awaiting caller is unblocked.
    _cancelFade();

    if ((from - to).abs() < 0.001) {
      // Already at target — no animation needed.
      return Future.value();
    }

    final steps = (durationMs / _kFadeStepMs).ceil().clamp(1, 10000);
    final completer = Completer<void>();
    _fadeCompleter = completer;

    int step = 0;
    _fadeTimer = Timer.periodic(
      const Duration(milliseconds: _kFadeStepMs),
      (timer) {
        step++;
        final progress = step / steps;
        // Linear interpolation between from and to.
        final volume = (from + (to - from) * progress).clamp(0.0, 1.0);
        _currentAmbientVolume = volume;

        // setVolume is async but we intentionally don't await — the call is
        // effectively instant (a platform channel call that buffers quickly)
        // and awaiting inside a Timer callback is unsupported.
        _ambientPlayer.setVolume(volume);

        if (step >= steps) {
          timer.cancel();
          _fadeTimer = null;
          _currentAmbientVolume = to;
          _ambientPlayer.setVolume(to);
          if (!completer.isCompleted) completer.complete();
          _fadeCompleter = null;
        }
      },
    );

    return completer.future;
  }

  /// Cancels any in-progress volume fade, completing its [Completer] if one
  /// is pending (so awaiting callers are unblocked immediately).
  void _cancelFade() {
    _fadeTimer?.cancel();
    _fadeTimer = null;
    if (_fadeCompleter != null && !_fadeCompleter!.isCompleted) {
      _fadeCompleter!.complete();
    }
    _fadeCompleter = null;
  }

  void _assertNotDisposed() {
    if (_disposed) {
      throw StateError('AudioEngine has been disposed and cannot be used.');
    }
  }
}

// ────────────────────────────────────────────────────────────────────────────
// Riverpod provider
// ────────────────────────────────────────────────────────────────────────────

/// Singleton [AudioEngine] provider.
///
/// Kept alive for the lifetime of the [ProviderScope] (typically the entire
/// app session). Disposing the [ProviderScope] (e.g. in tests) will call
/// [AudioEngine.dispose], releasing all [AudioPlayer] resources.
@Riverpod(keepAlive: true)
AudioEngine audioEngine(Ref ref) {
  final engine = AudioEngineImpl();
  ref.onDispose(engine.dispose);
  return engine;
}
