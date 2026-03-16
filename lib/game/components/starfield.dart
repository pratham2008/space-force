import 'dart:math';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import '../zero_vector_game.dart';

/// 3-layer parallax starfield with realistic star shapes (4-point sparkles),
/// color variety, twinkle, and faint nebula clouds.
/// Zero per-frame Paint allocation.
class Starfield extends Component with HasGameReference<ZeroVectorGame> {
  static const int _count0 = 70;  // far, dim, slow
  static const int _count1 = 55;  // mid
  static const int _count2 = 30;  // near, bright, fast

  final List<_Star> _stars = [];
  final List<_Nebula> _nebulae = [];
  final Random _rng = Random();

  // ── Cached paints ──────────────────────────────────────────────────────────
  static final Paint _starPaint  = Paint()..style = PaintingStyle.fill;
  static final Paint _glowPaint  = Paint()
    ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.5);
  static final Paint _nebulaP    = Paint()
    ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 40);

  @override
  Future<void> onLoad() async {
    await super.onLoad();

    for (int i = 0; i < _count0; i++) {
      _stars.add(_makeStar(0));
    }
    for (int i = 0; i < _count1; i++) {
      _stars.add(_makeStar(1));
    }
    for (int i = 0; i < _count2; i++) {
      _stars.add(_makeStar(2));
    }

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
        size = 0.5 + _rng.nextDouble() * 0.3;
        opacity = 0.15 + _rng.nextDouble() * 0.25;
        break;
      case 1:
        speedBase = 28 + _rng.nextDouble() * 30;
        size = 0.7 + _rng.nextDouble() * 0.5;
        opacity = 0.35 + _rng.nextDouble() * 0.35;
        break;
      default:
        speedBase = 65 + _rng.nextDouble() * 80;
        size = 1.0 + _rng.nextDouble() * 0.8;
        opacity = 0.65 + _rng.nextDouble() * 0.35;
        break;
    }

    // Color variety: ~20% cool blue, ~10% warm amber
    final roll = _rng.nextDouble();
    if (roll < 0.20) {
      tint = const Color(0xFFB8D4FF);
    } else if (roll < 0.30) {
      tint = const Color(0xFFFFD9A0);
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
      rotationAngle: _rng.nextDouble() * pi / 4, // slight random rotation
    );
  }

  @override
  void update(double dt) {
    super.update(dt);

    final speedMult = game.state == GameState.menu ? 1.5 : 1.0;

    for (final s in _stars) {
      s.y += s.speed * speedMult * dt;
      if (s.layer == 2) {
        s.twinklePhase += 3.0 * dt;
      }
      if (s.y > game.size.y + 2) {
        s.y = -2;
        s.x = _rng.nextDouble() * game.size.x;
      }
    }

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

    // Nebula clouds (behind stars)
    for (final n in _nebulae) {
      _nebulaP.color = n.color.withValues(alpha: 0.12);
      canvas.drawCircle(Offset(n.x, n.y), n.radius, _nebulaP);
    }

    // Stars — rendered as 4-point sparkles
    for (final s in _stars) {
      double alpha = s.baseOpacity;
      if (s.layer == 2) {
        alpha *= (0.7 + 0.3 * sin(s.twinklePhase));
      }

      final color = s.tint.withValues(alpha: alpha.clamp(0.0, 1.0));

      if (s.layer == 0) {
        // Far layer: tiny dot (too small to see shape)
        _starPaint.color = color;
        canvas.drawCircle(Offset(s.x, s.y), s.size * 0.6, _starPaint);
      } else {
        // Mid/Near layers: 4-point sparkle cross
        _drawSparkle(canvas, s.x, s.y, s.size, s.rotationAngle, color, s.layer == 2);
      }
    }
  }

  /// Draws a 4-point sparkle (cross shape with pointed tips).
  /// Optionally adds a soft glow behind it for bright (layer 2) stars.
  void _drawSparkle(Canvas canvas, double x, double y, double r,
      double rotation, Color color, bool addGlow) {
    // Spike lengths: vertical spikes are longer than horizontal
    final longR  = r * 2.8;  // vertical spike length
    final shortR = r * 1.4;  // horizontal spike length
    final midW   = r * 0.35; // half-width at the spike's waist

    if (addGlow) {
      _glowPaint.color = color.withValues(alpha: (color.a * 0.3).clamp(0.0, 1.0));
      canvas.drawCircle(Offset(x, y), r * 1.8, _glowPaint);
    }

    canvas.save();
    canvas.translate(x, y);
    canvas.rotate(rotation);

    final path = Path()
      // Top spike
      ..moveTo(0, -longR)
      ..lineTo(midW, 0)
      // Right spike
      ..lineTo(shortR, 0)
      ..lineTo(0, midW)
      // Bottom spike
      ..lineTo(0, longR)
      ..lineTo(-midW, 0)
      // Left spike
      ..lineTo(-shortR, 0)
      ..lineTo(0, -midW)
      ..close();

    _starPaint.color = color;
    canvas.drawPath(path, _starPaint);
    canvas.restore();
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
  final double rotationAngle;

  _Star({
    required this.x, required this.y,
    required this.speed, required this.size,
    required this.baseOpacity, required this.layer,
    required this.tint, required this.twinklePhase,
    required this.rotationAngle,
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
