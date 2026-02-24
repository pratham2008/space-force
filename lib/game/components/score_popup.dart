import 'package:flame/components.dart';
import 'package:flutter/material.dart';

class ScorePopup extends PositionComponent {
  final int score;
  final Color color;
  
  double _timer = 0;
  static const double _duration = 0.6;
  
  final Vector2 _velocity = Vector2(0, -45); // Float upward speed
  
  ScorePopup({
    required Vector2 position,
    required this.score,
    required this.color,
  }) : super(position: position, anchor: Anchor.center);

  @override
  void update(double dt) {
    super.update(dt);
    _timer += dt;
    
    // Ease-out progress (0.0 -> 1.0)
    final progress = (_timer / _duration).clamp(0.0, 1.0);
    final easeOut = 1.0 - (1.0 - progress) * (1.0 - progress);
    
    // Move up with easing
    position.add(_velocity * dt * (1.0 - easeOut * 0.5));
    
    // Scale up slightly (1.0 -> 1.1)
    scale = Vector2.all(1.0 + (progress * 0.1));
    
    if (_timer >= _duration) {
      removeFromParent();
    }
  }

  @override
  void render(Canvas canvas) {
    final opacity = (1.0 - (_timer / _duration)).clamp(0.0, 1.0);
    
    final textPainter = TextPainter(
      text: TextSpan(
        text: '+$score',
        style: TextStyle(
          color: color.withValues(alpha: opacity),
          fontSize: 16,
          fontWeight: FontWeight.bold,
          fontFamily: 'monospace',
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    // Double-draw technique for glow
    final glowPainter = TextPainter(
      text: TextSpan(
        text: '+$score',
        style: TextStyle(
          color: color.withValues(alpha: opacity * 0.3),
          fontSize: 16,
          fontWeight: FontWeight.bold,
          fontFamily: 'monospace',
          shadows: [
            Shadow(
              color: color.withValues(alpha: opacity * 0.5),
              blurRadius: 8,
            ),
          ],
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    // Draw glow first
    glowPainter.paint(canvas, Offset(-glowPainter.width / 2, -glowPainter.height / 2));
    
    // Draw main text
    textPainter.paint(canvas, Offset(-textPainter.width / 2, -textPainter.height / 2));
  }
}
