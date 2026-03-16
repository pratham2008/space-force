import 'dart:math';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import '../zero_vector_game.dart';

/// 3-layer parallax starfield with color variety, twinkle, and faint nebula
/// clouds. All Paint objects are cached — zero per-frame allocations.
class Starfield extends Component with HasGameReference<ZeroVectorGame> {
  static const int _count0 = 70;  // far, dim, slow
  static const int _count1 = 55;  // mid
  static const int _count2 = 30;  // near, bright, fast

  final List<_Star> _stars = [];
  final List<_Nebula> _nebulae = [];
  final Random _rng = Random();

  // ── Cached paints (reused every frame) ──────────────────────────────────
  static final Paint _white   = Paint()..color = Colors.white;
  static final Paint _nebulaP = Paint()..maskFilter = const MaskFilter.blur(BlurStyle.normal, 40);

  @override
  Future<void> onLoad() async {
    await super.onLoad();

    // Stars
    for (int i = 0; i < _count0; i++) {
      _stars.add(_makeStar(0));
    }
    for (int i = 0; i < _count1; i++) {
      _stars.add(_makeStar(1));
    }
    for (int i = 0; i < _count2; i++) {
      _stars.add(_makeStar(2));
    }

    // Nebula clouds (3-4 large soft circles)
    for (int i = 0; i < 4; i++) {
      _nebulae.add(_Nebula(
        x: _rng.nextDouble() * game.size.x,
        y: _rng.nextDouble() * game.size.y,
        radius: 80 + _rng.nextDouble() * 60,
        speed: 3 + _rng.nextDouble() * 4,
        color: _nebulaColor(i),
      ));
    }
  }

  Color _nebulaColor(int i) {
    const colors = [
      Color(0xFF0D1B3A), // deep navy
      Color(0xFF1A0C2A), // dark violet-black
      Color(0xFF0A1A20), // dark teal
      Color(0xFF1A1008), // warm dark amber
    ];
    return colors[i % colors.length];
  }

  _Star _makeStar(int layer) {
    double speedBase, size, opacity;
    Color tint = Colors.white;

    switch (layer) {
      case 0:
        speedBase = 10 + _rng.nextDouble() * 15;
        size = 0.4 + _rng.nextDouble() * 0.4;
        opacity = 0.15 + _rng.nextDouble() * 0.25;
        break;
      case 1:
        speedBase = 28 + _rng.nextDouble() * 30;
        size = 0.7 + _rng.nextDouble() * 0.6;
        opacity = 0.35 + _rng.nextDouble() * 0.35;
        break;
      default:
        speedBase = 65 + _rng.nextDouble() * 80;
        size = 1.2 + _rng.nextDouble() * 1.0;
        opacity = 0.65 + _rng.nextDouble() * 0.35;
        break;
    }

    // Color variety: ~20% faint blue, ~10% warm amber, rest white
    final roll = _rng.nextDouble();
    if (roll < 0.20) {
      tint = const Color(0xFFB8D4FF); // cool starlight blue
    } else if (roll < 0.30) {
      tint = const Color(0xFFFFD9A0); // warm amber
    }

    return _Star(
      x: _rng.nextDouble() * game.size.x,
      y: _rng.nextDouble() * game.size.y,
      speed: speedBase,
      size: size,
      baseOpacity: opacity,
      layer: layer,
      tint: tint,
      twinklePhase: _rng.nextDouble() * 2 * pi,
    );
  }

  @override
  void update(double dt) {
    super.update(dt);

    final speedMult = game.state == GameState.menu ? 1.5 : 1.0;

    // Stars
    for (final s in _stars) {
      s.y += s.speed * speedMult * dt;
      if (s.layer == 2) s.twinklePhase += 3.0 * dt; // only bright stars twinkle
      if (s.y > game.size.y + 2) {
        s.y = -2;
        s.x = _rng.nextDouble() * game.size.x;
      }
    }

    // Nebulae (very slow parallax)
    for (final n in _nebulae) {
      n.y += n.speed * speedMult * dt;
      if (n.y > game.size.y + n.radius) {
        n.y = -n.radius;
        n.x = _rng.nextDouble() * game.size.x;
      }
    }
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);

    // Nebula clouds first (behind stars)
    for (final n in _nebulae) {
      _nebulaP.color = n.color.withValues(alpha: 0.12);
      canvas.drawCircle(Offset(n.x, n.y), n.radius, _nebulaP);
    }

    // Stars
    for (final s in _stars) {
      double alpha = s.baseOpacity;
      if (s.layer == 2) {
        // Twinkle: subtle brightness oscillation
        alpha *= (0.7 + 0.3 * sin(s.twinklePhase));
      }
      _white.color = s.tint.withValues(alpha: alpha.clamp(0.0, 1.0));
      canvas.drawCircle(Offset(s.x, s.y), s.size, _white);
    }
  }
}

// ── Data classes ──────────────────────────────────────────────────────────────

class _Star {
  double x, y;
  final double speed;
  final double size;
  final double baseOpacity;
  final int layer;
  final Color tint;
  double twinklePhase;

  _Star({
    required this.x, required this.y,
    required this.speed, required this.size,
    required this.baseOpacity, required this.layer,
    required this.tint, required this.twinklePhase,
  });
}

class _Nebula {
  double x, y;
  final double radius;
  final double speed;
  final Color color;

  _Nebula({
    required this.x, required this.y,
    required this.radius, required this.speed,
    required this.color,
  });
}
