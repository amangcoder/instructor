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
    _multiTapTimer?.cancel();

    if (_tapCount >= 3) {
      _tapCount = 0;
      widget.onSkipBackward();
      return;
    }

    _multiTapTimer = Timer(_multiTapWindow, () {
      final count = _tapCount;
      _tapCount = 0;
      if (count == 1) {
        widget.onTogglePause();
      } else if (count == 2) {
        widget.onSkipForward();
      }
      // count >= 3 already handled above
    });
  }

  void _onHorizontalDragEnd(DragEndDetails details) {
    widget.onTouchDetected();
    final vx = details.primaryVelocity ?? 0;
    if (vx > _swipeVelocityThreshold) {
      widget.onSkipForward();
    } else if (vx < -_swipeVelocityThreshold) {
      widget.onSkipBackward();
    }
  }

  void _onVerticalDragEnd(DragEndDetails details) {
    widget.onTouchDetected();
    final vy = details.primaryVelocity ?? 0;
    if (vy > _swipeVelocityThreshold) {
      widget.onEnd();
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
      onHorizontalDragEnd: _onHorizontalDragEnd,
      onVerticalDragEnd: _onVerticalDragEnd,
      child: widget.child,
    );
  }
}
