import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import '../zero_vector_game.dart';

/// Warning banner shown after wave transition, before a Mini Boss spawns.
/// Timeline:
///   0.3s silence → banner appears for 1.8s → mini boss warp entry
class EliteWarningBanner extends PositionComponent
    with HasGameReference<ZeroVectorGame> {

  final void Function() onComplete;

  double _timer = 0;
  bool _bannerVisible = false;
  double _bannerOpacity = 0;

  static const double _silenceDuration = 0.3;
  static const double _displayDuration = 1.8;

  EliteWarningBanner({required this.onComplete});

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    position = Vector2(game.size.x / 2, game.size.y * 0.18);
    anchor = Anchor.center;
    size = Vector2(game.size.x * 0.9, 56);
  }

  @override
  void update(double dt) {
    super.update(dt);
    _timer += dt;

    if (_timer >= _silenceDuration && !_bannerVisible) {
      _bannerVisible = true;
    }

    if (_bannerVisible) {
      final visElapsed = _timer - _silenceDuration;
      // Fade in over 0.25s, hold, fade out at end
      if (visElapsed < 0.25) {
        _bannerOpacity = (visElapsed / 0.25).clamp(0.0, 1.0);
      } else if (visElapsed > _displayDuration - 0.25) {
        _bannerOpacity = (((_displayDuration - visElapsed) / 0.25)).clamp(0.0, 1.0);
      } else {
        _bannerOpacity = 1.0;
      }
    }

    if (_timer >= _silenceDuration + _displayDuration) {
      removeFromParent();
      onComplete();
    }
  }

  @override
  void render(Canvas canvas) {
    if (!_bannerVisible || _bannerOpacity <= 0) return;

    final rect = Rect.fromLTWH(0, 0, size.x, size.y);
    final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(8));

    // Dark crimson background
    canvas.drawRRect(
      rrect,
      Paint()..color = const Color(0xFF5A0E1A).withValues(alpha: _bannerOpacity * 0.9),
    );

    // Outer glow
    canvas.drawRRect(
      rrect,
      Paint()
        ..color = const Color(0xFFFF1744).withValues(alpha: _bannerOpacity * 0.4)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..blendMode = BlendMode.plus,
    );

    // Text
    final tp = TextPainter(
      text: TextSpan(
        text: '⚠  ELITE TARGET INBOUND',
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w900,
          letterSpacing: 3,
          color: Colors.white.withValues(alpha: _bannerOpacity),
          shadows: [
            Shadow(
              color: const Color(0xFFFF1744).withValues(alpha: _bannerOpacity),
              blurRadius: 12,
            ),
          ],
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset((size.x - tp.width) / 2, (size.y - tp.height) / 2));
  }
}
