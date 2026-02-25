import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import '../zero_vector_game.dart';

/// Full boss warning sequence:
///   0.3s silence → dark crimson banner "☠ BOSS APPROACHING" (2.2s) → warp in boss
///
/// Total duration ≈ 2.5s before boss appears.
/// Calls [game.onBossWarningComplete] when finished.
class BossWarningSequence extends PositionComponent
    with HasGameReference<ZeroVectorGame> {

  final int bossWave;

  // Internal timer state
  double _timer = 0;
  bool _bannerShowing = false;
  bool _done = false;

  // Banner visual state
  double _bannerOpacity = 0;
  static const double _silenceDelay = 0.3;   // Before banner appears
  static const double _bannerDuration = 2.2;  // Banner display time
  static const double _fadeInDuration = 0.3;
  static const double _fadeOutStart   = 1.9;  // Within banner window

  BossWarningSequence({required this.bossWave});

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    // Fullscreen — covers everything
    size    = game.size.clone();
    position = Vector2.zero();
    debugPrint('[BossWarning] Started for wave $bossWave. GameState=${game.state}');
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (_done) return;

    _timer += dt;

    if (_timer < _silenceDelay) {
      // Silent pre-roll
      return;
    }

    final bannerTimer = _timer - _silenceDelay;

    if (!_bannerShowing) {
      _bannerShowing = true;
    }

    // Fade in
    if (bannerTimer < _fadeInDuration) {
      _bannerOpacity = bannerTimer / _fadeInDuration;
    } else if (bannerTimer < _fadeOutStart) {
      _bannerOpacity = 1.0;
    } else if (bannerTimer < _bannerDuration) {
      _bannerOpacity = 1.0 - (bannerTimer - _fadeOutStart) / (_bannerDuration - _fadeOutStart);
    } else if (!_done) {
      _done = true;
      debugPrint('[BossWarning] Animation done — removing self');
      removeFromParent();
    }
  }

  @override
  void onRemove() {
    super.onRemove();
    debugPrint('[BossWarning] onRemove fired. Calling onBossWarningComplete($bossWave)');
    game.onBossWarningComplete(bossWave);
  }

  @override
  void render(Canvas canvas) {
    if (!_bannerShowing || _bannerOpacity <= 0) return;

    final a = _bannerOpacity.clamp(0.0, 1.0);

    // Screen dim
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.x, size.y),
      Paint()..color = Colors.black.withValues(alpha: 0.20 * a),
    );

    // Banner background
    final bannerH = 72.0;
    final bannerY = size.y * 0.38;
    final bannerRect = Rect.fromLTWH(0, bannerY, size.x, bannerH);

    canvas.drawRect(
      bannerRect,
      Paint()..color = const Color(0xFF1A0006).withValues(alpha: a),
    );

    // Crimson glow border (top + bottom lines)
    final borderPaint = Paint()
      ..color = const Color(0xFFFF1744).withValues(alpha: a * 0.8)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawLine(Offset(0, bannerY), Offset(size.x, bannerY), borderPaint);
    canvas.drawLine(Offset(0, bannerY + bannerH), Offset(size.x, bannerY + bannerH), borderPaint);

    // Glow blur behind text
    canvas.drawRect(
      bannerRect,
      Paint()
        ..color = const Color(0xFFFF1744).withValues(alpha: 0.08 * a)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 24),
    );

    // Warning text
    final tp = TextPainter(
      text: TextSpan(
        text: '☠  BOSS APPROACHING',
        style: TextStyle(
          fontSize: 26,
          fontWeight: FontWeight.w900,
          letterSpacing: 5,
          color: Colors.white.withValues(alpha: a),
          shadows: [
            Shadow(color: const Color(0xFFFF1744).withValues(alpha: a), blurRadius: 18),
          ],
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    tp.layout();
    tp.paint(
      canvas,
      Offset((size.x - tp.width) / 2, bannerY + (bannerH - tp.height) / 2),
    );
  }
}
