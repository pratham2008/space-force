import 'dart:math';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import '../zero_vector_game.dart';

class Starfield extends Component with HasGameReference<ZeroVectorGame> {
  final int starCount = 180; // Increased density
  final List<_Star> _stars = [];
  final Random _random = Random();

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    for (int i = 0; i < starCount; i++) {
      _stars.add(_createStar());
    }
  }

  _Star _createStar() {
    // 3 layers of parallax
    // Layer 0: small, slow (background)
    // Layer 1: medium, medium (middle)
    // Layer 2: large, fast (foreground)
    final layer = _random.nextInt(3);
    
    double speedBase;
    double size;
    double opacity;

    switch (layer) {
      case 0:
        speedBase = 10 + _random.nextDouble() * 15;
        size = 0.4 + _random.nextDouble() * 0.4;
        opacity = 0.2 + _random.nextDouble() * 0.3;
        break;
      case 1:
        speedBase = 25 + _random.nextDouble() * 30;
        size = 0.8 + _random.nextDouble() * 0.6;
        opacity = 0.4 + _random.nextDouble() * 0.4;
        break;
      default: // layer 2
        speedBase = 60 + _random.nextDouble() * 80;
        size = 1.4 + _random.nextDouble() * 1.0;
        opacity = 0.7 + _random.nextDouble() * 0.3;
        break;
    }

    return _Star(
      position: Vector2(
        _random.nextDouble() * game.size.x,
        _random.nextDouble() * game.size.y,
      ),
      speed: speedBase,
      size: size,
      opacity: opacity,
    );
  }

  @override
  void update(double dt) {
    super.update(dt);
    
    // Slightly faster speed in menu for dynamic feel
    final speedMult = game.state == GameState.menu ? 1.5 : 1.0;

    for (final star in _stars) {
      star.position.y += star.speed * speedMult * dt;
      if (star.position.y > game.size.y) {
        star.position.y = -5;
        star.position.x = _random.nextDouble() * game.size.x;
      }
    }
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    for (final star in _stars) {
      final paint = Paint()
        ..color = Colors.white.withValues(alpha: star.opacity)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(star.position.toOffset(), star.size, paint);
    }
  }
}

class _Star {
  final Vector2 position;
  final double speed;
  final double size;
  final double opacity;

  _Star({
    required this.position,
    required this.speed,
    required this.size,
    required this.opacity,
  });
}
