import 'dart:math';
import 'package:flame/components.dart';
import 'package:flutter/animation.dart';

/// Reusable screen shake controller.
/// Does NOT affect Flutter overlays — only Flame world components.
///
/// Usage:
///   1. Add as a child of the game.
///   2. Call `shake(intensity: 6, duration: 0.3)` to trigger.
///   3. The controller offsets all sibling components via the
///      game's camera viewport.
class ScreenShakeController extends Component {
  final Random _random = Random();

  double _elapsed = 0;
  double _duration = 0;
  double _intensity = 0;
  bool _active = false;

  /// Current shake offset — applied by the game's update loop to the camera.
  Vector2 offset = Vector2.zero();

  /// Trigger a new shake.  If a shake is already playing the stronger one wins.
  void shake({required double intensity, required double duration}) {
    if (_active && intensity <= _intensity) return; // ignore weaker shakes
    _intensity = intensity;
    _duration = duration;
    _elapsed = 0;
    _active = true;
  }

  @override
  void update(double dt) {
    super.update(dt);

    if (!_active) return;

    _elapsed += dt;
    if (_elapsed >= _duration) {
      _active = false;
      offset = Vector2.zero();
      return;
    }

    // Progress 0→1, apply easeOut decay so shake diminishes smoothly.
    final progress = (_elapsed / _duration).clamp(0.0, 1.0);
    final decay = 1.0 - Curves.easeOut.transform(progress);
    final currentIntensity = _intensity * decay;

    offset = Vector2(
      (_random.nextDouble() * 2 - 1) * currentIntensity,
      (_random.nextDouble() * 2 - 1) * currentIntensity,
    );
  }
}
