import 'dart:async';

import 'package:flutter/material.dart';

/// Wraps [child] with complex multi-gesture recognition for the Now Playing
/// screen.
///
/// ## Gesture map
/// | Gesture                                 | Action         |
/// |-----------------------------------------|----------------|
/// | Single tap                              | [onTogglePause] |
/// | Double-tap                              | [onSkipForward] |
/// | Triple-tap                              | [onSkipBackward] |
/// | Swipe right (positive dx velocity)      | [onSkipForward] |
/// | Swipe left  (negative dx velocity)      | [onSkipBackward] |
/// | Swipe down  (positive dy velocity)      | [onEnd] |
/// | Long-press  (≥ 2 seconds)              | [onEnd] |
///
/// Triple-tap is detected manually: three taps within [_multiTapWindow]
/// (400 ms) are collapsed into a single callback. Single/double taps are
/// dispatched after the window elapses so that all three can be distinguished.
class SessionGestureDetector extends StatefulWidget {
  const SessionGestureDetector({
    super.key,
    required this.child,
    required this.onTogglePause,
    required this.onSkipForward,
    required this.onSkipBackward,
    required this.onEnd,
    required this.onTouchDetected,
  });

  final Widget child;

  /// Called when the user single-taps — toggles pause/resume.
  final VoidCallback onTogglePause;

  /// Called on double-tap or swipe-right — skip to next step.
  final VoidCallback onSkipForward;

  /// Called on triple-tap or swipe-left — go to previous step.
  final VoidCallback onSkipBackward;

  /// Called on swipe-down or long-press (≥ 2 s) — end session flow.
  final VoidCallback onEnd;

  /// Called on every touch event — used by the auto-dim timer parent.
  final VoidCallback onTouchDetected;

  @override
  State<SessionGestureDetector> createState() => _SessionGestureDetectorState();
}

class _SessionGestureDetectorState extends State<SessionGestureDetector> {
  /// Time window within which consecutive taps are grouped.
  static const _multiTapWindow = Duration(milliseconds: 400);

  /// Minimum px/s velocity to register a swipe (horizontal or vertical).
  static const _swipeVelocityThreshold = 300.0;

  /// Duration finger must be held to trigger long-press end.
  static const _longPressDuration = Duration(seconds: 2);

  int _tapCount = 0;
  Timer? _multiTapTimer;

  // Long-press tracking
  Timer? _longPressTimer;

  void _onTap() {
    widget.onTouchDetected();
    _tapCount++;
    // Cancel any pending timer and restart it so the window always extends
    // from the most-recent tap. Dispatch is deferred to the timer callback so
    // that ALL taps within the 400 ms window are counted before any action is
    // taken. This prevents a premature double-tap dispatch when the user's
    // third tap arrives just after the previous timer would have fired.
    // Note: the 400 ms window means three taps must all fall within 400 ms of
    // the last tap to register as a triple-tap.
    _multiTapTimer?.cancel();
    _multiTapTimer = Timer(_multiTapWindow, () {
      final count = _tapCount;
      _tapCount = 0;
      if (count == 1) {
        widget.onTogglePause();
      } else if (count == 2) {
        widget.onSkipForward();
      } else {
        widget.onSkipBackward();
      }
    });
  }

  /// Called when the pan gesture is recognised by the arena — cancels the
  /// long-press timer so a swipe does not accidentally trigger end-session.
  void _onPanStart(DragStartDetails _) {
    _longPressTimer?.cancel();
    _longPressTimer = null;
  }

  /// Unified pan-end handler that decomposes velocity into horizontal vs
  /// vertical components and dispatches the appropriate callback based on
  /// which axis dominates. Using a single [onPanEnd] instead of separate
  /// [onHorizontalDragEnd] / [onVerticalDragEnd] avoids the Flutter gesture
  /// arena conflict where both drag recognisers compete and one (usually
  /// vertical) becomes unreliable.
  void _onPanEnd(DragEndDetails details) {
    widget.onTouchDetected();
    final velocity = details.velocity.pixelsPerSecond;
    final absDx = velocity.dx.abs();
    final absDy = velocity.dy.abs();

    if (absDx >= absDy) {
      // Horizontal swipe dominates.
      if (velocity.dx > _swipeVelocityThreshold) {
        widget.onSkipForward();
      } else if (velocity.dx < -_swipeVelocityThreshold) {
        widget.onSkipBackward();
      }
    } else {
      // Vertical swipe dominates.
      if (velocity.dy > _swipeVelocityThreshold) {
        widget.onEnd();
      }
    }
  }

  void _onTapDown(TapDownDetails _) {
    widget.onTouchDetected();
    _longPressTimer?.cancel();
    _longPressTimer = Timer(_longPressDuration, () {
      widget.onEnd();
    });
  }

  void _onTapUp(TapUpDetails _) {
    _longPressTimer?.cancel();
    _longPressTimer = null;
  }

  void _onTapCancel() {
    _longPressTimer?.cancel();
    _longPressTimer = null;
  }

  @override
  void dispose() {
    _multiTapTimer?.cancel();
    _longPressTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _onTap,
      onTapDown: _onTapDown,
      onTapUp: _onTapUp,
      onTapCancel: _onTapCancel,
      onPanStart: _onPanStart,
      onPanEnd: _onPanEnd,
      child: widget.child,
    );
  }
}
