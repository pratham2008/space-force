import 'dart:math';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import '../zero_vector_game.dart';

/// Warning banner shown before a Mini Boss spawns.
/// Width dynamically sized to text. Higher contrast than previous version.
class EliteWarningBanner extends PositionComponent
    with HasGameReference<ZeroVectorGame> {

  final void Function() onComplete;

  double _timer = 0;
  bool _bannerVisible = false;
  double _bannerOpacity = 0;
  double _pulsePhase = 0;

  static const double _silenceDuration = 0.3;
  static const double _displayDuration = 1.8;
  static const double _bannerH = 46.0;
  static const double _hPad = 20.0;
  static const double _maxWidthRatio = 0.85;
  static const double _minWidthRatio = 0.45;

  double? _resolvedW;
  double? _resolvedFontSize;

  EliteWarningBanner({required this.onComplete});

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    // Position anchor at center; size calculated in _resolveLayout
    anchor = Anchor.center;
    position = Vector2(game.size.x / 2, game.size.y * 0.18);
    size = Vector2(game.size.x * 0.75, _bannerH); // will refine on first render
    _resolveLayout();
    size = Vector2(_resolvedW!, _bannerH);
  }

  void _resolveLayout() {
    final maxW = game.size.x * _maxWidthRatio;
    final minW = game.size.x * _minWidthRatio;

    double fontSize = 19.0;
    TextPainter tp;

    while (true) {
      tp = TextPainter(
        text: TextSpan(
          text: '⚠  ELITE TARGET INBOUND',
          style: TextStyle(fontSize: fontSize, fontWeight: FontWeight.w900, letterSpacing: 3),
        ),
        textDirection: TextDirection.ltr,
      )..layout();

      final needed = tp.width + _hPad * 2 + 20;
      if (needed <= maxW || fontSize <= 11) break;
      fontSize -= 1.0;
    }

    tp = TextPainter(
      text: TextSpan(
        text: '⚠  ELITE TARGET INBOUND',
        style: TextStyle(fontSize: fontSize, fontWeight: FontWeight.w900, letterSpacing: 3),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    _resolvedW        = (tp.width + _hPad * 2 + 20).clamp(minW, maxW);
    _resolvedFontSize = fontSize;
  }

  @override
  void update(double dt) {
    super.update(dt);
    _timer += dt;
    _pulsePhase += dt * 5.0;

    if (_timer >= _silenceDuration && !_bannerVisible) {
      _bannerVisible = true;
      game.audioManager.playSfx('miniboss_warning.wav');
    }

    if (_bannerVisible) {
      final vis = _timer - _silenceDuration;
      if (vis < 0.25) {
        _bannerOpacity = (vis / 0.25).clamp(0.0, 1.0);
      } else if (vis > _displayDuration - 0.25) {
        _bannerOpacity = ((_displayDuration - vis) / 0.25).clamp(0.0, 1.0);
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

    final a  = _bannerOpacity.clamp(0.0, 1.0);
    final w  = size.x;
    final h  = size.y;
    final gp = (sin(_pulsePhase) + 1) / 2;

    final rect  = Rect.fromLTWH(0, 0, w, h);
    final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(10));

    // Outer glow
    canvas.drawRRect(rrect, Paint()
      ..color = const Color(0xFFFF6600).withValues(alpha: (0.3 + 0.2 * gp) * a)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 16),
    );

    // Save + clip
    canvas.save();
    canvas.clipRRect(rrect);

    // Background — orange-amber gradient for distinct look from boss banner
    canvas.drawPaint(Paint()
      ..shader = LinearGradient(
        colors: const [Color(0xFF2A0E00), Color(0xFF0A0400)],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ).createShader(rect)
      ..color = Colors.white.withValues(alpha: a),
    );

    // Subtle inner pulse
    canvas.drawPaint(Paint()
      ..color = const Color(0xFFFF6600).withValues(alpha: (0.04 + 0.04 * gp) * a)
      ..blendMode = BlendMode.plus,
    );

    // Text
    final fontSize = _resolvedFontSize ?? 19.0;
    final tp = TextPainter(
      text: TextSpan(
        text: '⚠  ELITE TARGET INBOUND',
        style: TextStyle(
          fontSize: fontSize,
          fontWeight: FontWeight.w900,
          letterSpacing: 3,
          color: const Color(0xFFFFCC44).withValues(alpha: a), // amber — high contrast
          shadows: [
            Shadow(color: const Color(0xFFFF6600).withValues(alpha: 0.95 * a), blurRadius: 18),
            Shadow(color: const Color(0xFFFF6600).withValues(alpha: 0.4 * a), blurRadius: 6),
          ],
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    tp.paint(canvas, Offset((w - tp.width) / 2, (h - tp.height) / 2));

    canvas.restore();

    // Border — drawn outside clip
    canvas.drawRRect(rrect, Paint()
      ..color = const Color(0xFFFF6600).withValues(alpha: (0.75 + 0.25 * gp) * a)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6,
    );

    // Vertical accent bars
    final barPaint = Paint()..color = const Color(0xFFFF6600).withValues(alpha: 0.6 * a);
    canvas.drawRect(Rect.fromLTWH(0, 0, 3, h), barPaint);
    canvas.drawRect(Rect.fromLTWH(w - 3, 0, 3, h), barPaint);
  }
}
