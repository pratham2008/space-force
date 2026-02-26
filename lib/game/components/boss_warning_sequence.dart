import 'dart:math';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import '../zero_vector_game.dart';

/// Full boss warning sequence:
///   0.3s silence → banner appears for 2.2s → warp in boss
///
/// Banner width: dynamically sized to text + 48px padding, capped at 90% screen.
/// Calls [game.onBossWarningComplete] when finished.
class BossWarningSequence extends PositionComponent
    with HasGameReference<ZeroVectorGame> {

  final int bossWave;

  double _timer = 0;
  bool _bannerShowing = false;
  bool _done = false;

  double _bannerOpacity = 0;
  static const double _silenceDelay   = 0.3;
  static const double _bannerDuration = 2.2;
  static const double _fadeInDuration = 0.3;
  static const double _fadeOutStart   = 1.9;

  // Animation state
  double _pulsePhase   = 0;
  double _glitchOffset = 0;
  double _glitchTimer  = 0;
  bool   _scanlineFlip = false;

  final Random _rng = Random();

  // ── Cached layout (computed once when banner first fires) ──────────────────
  double? _resolvedBannerW;
  double? _resolvedFontSize;
  static const double _bannerH       = 62.0;
  static const double _hPad          = 24.0;  // horizontal text padding
  static const double _extraBgPad    = 24.0;  // extra bg padding beyond text
  static const double _maxWidthRatio = 0.90;
  static const double _minWidthRatio = 0.50;

  BossWarningSequence({required this.bossWave});

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    size     = game.size.clone();
    position = Vector2.zero();
    debugPrint('[BossWarning] Started for wave $bossWave. GameState=${game.state}');
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (_done) return;

    _timer += dt;
    _pulsePhase += dt * 4.0;

    // Glitch jitter — ~every 300 ms
    _glitchTimer += dt;
    if (_glitchTimer > 0.28 + _rng.nextDouble() * 0.12) {
      _glitchTimer  = 0;
      _glitchOffset = (_rng.nextDouble() - 0.5) * 2.8;
      _scanlineFlip = !_scanlineFlip;
    } else if (_glitchTimer > 0.05) {
      _glitchOffset = 0;
    }

    if (_timer < _silenceDelay) return;

    final bannerTimer = _timer - _silenceDelay;

    if (!_bannerShowing) {
      _bannerShowing = true;
      game.audioManager.playSfx('warning_siren.wav');
    }

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

  // ── Measure text and resolve banner width (called once at first render) ─────
  void _resolveLayout() {
    final maxBannerW = size.x * _maxWidthRatio;
    final minBannerW = size.x * _minWidthRatio;

    // Try starting at 24px, see if text fits in maxBannerW - padding
    double fontSize = 24.0;
    TextPainter tp;

    while (true) {
      tp = TextPainter(
        text: TextSpan(
          text: '☠  BOSS APPROACHING',
          style: TextStyle(
            fontSize: fontSize,
            fontWeight: FontWeight.w900,
            letterSpacing: max(1.0, fontSize * 0.18),
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();

      final needed = tp.width + (_hPad + _extraBgPad) * 2;
      if (needed <= maxBannerW || fontSize <= 11) break;
      fontSize -= 1.0;
    }

    // Re‑measure final size
    tp = TextPainter(
      text: TextSpan(
        text: '☠  BOSS APPROACHING',
        style: TextStyle(
          fontSize: fontSize,
          fontWeight: FontWeight.w900,
          letterSpacing: max(1.0, fontSize * 0.18),
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    // Background width = text + padding on each side, clamped
    final desiredW = tp.width + (_hPad + _extraBgPad) * 2;
    _resolvedBannerW  = desiredW.clamp(minBannerW, maxBannerW);
    _resolvedFontSize = fontSize;
  }

  @override
  void render(Canvas canvas) {
    if (!_bannerShowing || _bannerOpacity <= 0) return;

    _resolveLayout();  // idempotent after first run if we guard, but cheap enough

    final a          = _bannerOpacity.clamp(0.0, 1.0);
    final bannerW    = _resolvedBannerW!;
    final fontSize   = _resolvedFontSize!;
    final glowPulse  = (sin(_pulsePhase) + 1) / 2;

    // ── Vignette layer
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.x, size.y),
      Paint()..color = Colors.black.withValues(alpha: 0.35 * a),
    );

    final bannerX    = (size.x - bannerW) / 2;
    final bannerYPos = size.y * 0.38;
    final bannerRect = Rect.fromLTWH(bannerX, bannerYPos, bannerW, _bannerH);
    final bannerRRect = RRect.fromRectAndRadius(bannerRect, const Radius.circular(10));

    // ── 1. Outer pulse glow (before clip, bleeds outward)
    canvas.drawRRect(
      bannerRRect,
      Paint()
        ..color = const Color(0xFFFF1744).withValues(alpha: (0.28 + 0.18 * glowPulse) * a)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 22),
    );

    // ── 2. Clip zone
    canvas.save();
    canvas.clipRRect(bannerRRect);

    // 2a. Gradient background: crimson → near-black
    canvas.drawPaint(Paint()
      ..shader = LinearGradient(
        colors: const [Color(0xFF2E0008), Color(0xFF0D0002)],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ).createShader(bannerRect)
      ..color = Colors.white.withValues(alpha: a),
    );

    // 2b. Scanlines
    final scanPaint = Paint()..color = Colors.black.withValues(alpha: 0.15 * a);
    for (double sy = bannerYPos; sy < bannerYPos + _bannerH; sy += 3) {
      if (_scanlineFlip ? (sy ~/ 3).isEven : (sy ~/ 3).isOdd) {
        canvas.drawRect(Rect.fromLTWH(bannerX, sy, bannerW, 1.5), scanPaint);
      }
    }

    // 2c. Hazard corner stripes
    _drawHazardCorner(canvas, bannerX,              bannerYPos,              44, 10, a);
    _drawHazardCorner(canvas, bannerX + bannerW - 44, bannerYPos,            44, 10, a);
    _drawHazardCorner(canvas, bannerX,              bannerYPos + _bannerH - 10, 44, 10, a);
    _drawHazardCorner(canvas, bannerX + bannerW - 44, bannerYPos + _bannerH - 10, 44, 10, a);

    // 2d. Pulsing inner red tint
    canvas.drawPaint(Paint()
      ..color = const Color(0xFFFF1744).withValues(alpha: (0.03 + 0.04 * glowPulse) * a)
      ..blendMode = BlendMode.plus,
    );

    // 2e. Text (with glitch jitter)
    final tp = TextPainter(
      text: TextSpan(
        text: '☠  BOSS APPROACHING',
        style: TextStyle(
          fontSize: fontSize,
          fontWeight: FontWeight.w900,
          letterSpacing: max(1.0, fontSize * 0.18),
          color: Colors.white.withValues(alpha: a),
          shadows: [
            Shadow(color: const Color(0xFFFF1744).withValues(alpha: 0.9 * a), blurRadius: 22),
            Shadow(color: const Color(0xFFFF1744).withValues(alpha: 0.35 * a), blurRadius: 8),
          ],
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    tp.paint(
      canvas,
      Offset(
        bannerX + (bannerW - tp.width) / 2 + _glitchOffset,
        bannerYPos + (_bannerH - tp.height) / 2,
      ),
    );

    canvas.restore();

    // ── 3. Border — drawn outside clip so stroke is fully visible
    canvas.drawRRect(
      bannerRRect,
      Paint()
        ..color = const Color(0xFFFF1744).withValues(alpha: (0.7 + 0.3 * glowPulse) * a)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.8,
    );

    // ── 4. Sharp vertical edge accent bars
    final edgePaint = Paint()
      ..color = const Color(0xFFFF1744).withValues(alpha: 0.55 * a);
    canvas.drawRect(Rect.fromLTWH(bannerX, bannerYPos, 3, _bannerH), edgePaint);
    canvas.drawRect(Rect.fromLTWH(bannerX + bannerW - 3, bannerYPos, 3, _bannerH), edgePaint);
  }

  void _drawHazardCorner(Canvas canvas, double x, double y, double w, double h, double alpha) {
    final red   = Paint()..color = const Color(0xFFFF1744).withValues(alpha: 0.35 * alpha);
    final black = Paint()..color = Colors.black.withValues(alpha: 0.55 * alpha);
    const sw = 8.0;
    for (double i = -h; i < w + h; i += sw * 2) {
      canvas.drawPath(Path()
        ..moveTo(x + i,      y)
        ..lineTo(x + i + sw, y)
        ..lineTo(x + i + sw + h, y + h)
        ..lineTo(x + i + h, y + h)
        ..close(), red);
      canvas.drawPath(Path()
        ..moveTo(x + i + sw,      y)
        ..lineTo(x + i + sw * 2,  y)
        ..lineTo(x + i + sw * 2 + h, y + h)
        ..lineTo(x + i + sw + h,  y + h)
        ..close(), black);
    }
  }
}
