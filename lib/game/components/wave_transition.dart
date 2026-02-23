import 'package:flame/components.dart';
import 'package:flame/effects.dart';
import 'package:flutter/material.dart';
import '../zero_vector_game.dart';

/// Animated cinematic "WAVE X COMPLETE" component.
class WaveTransitionComponent extends PositionComponent
    with HasGameReference<ZeroVectorGame> {
  final int completedWave;

  WaveTransitionComponent({required this.completedWave});

  @override
  Future<void> onLoad() async {
    await super.onLoad();

    position = Vector2(game.size.x / 2, game.size.y * 0.45);
    anchor = Anchor.center;
    size = Vector2(350, 80);
    scale = Vector2.all(0.8);

    // Initial Appearance Phase
    // Trigger effects on game side
    game.shake(intensity: 10, duration: 0.3);
    game.add(BrightnessFlash());

    // Scale pop: 0.8 -> 1.15 -> 1.0
    add(
      SequenceEffect([
        ScaleEffect.to(
          Vector2.all(1.15),
          EffectController(duration: 0.2, curve: Curves.easeOutBack),
        ),
        ScaleEffect.to(
          Vector2.all(1.0),
          EffectController(duration: 0.15, curve: Curves.easeInOut),
        ),
      ]),
    );

    // cinematic movement: hold -> slide up -> shrink
    add(
      SequenceEffect([
        MoveByEffect(Vector2.zero(), EffectController(duration: 1.5)),
        MoveToEffect(
          Vector2(game.size.x / 2, 60),
          EffectController(duration: 0.6, curve: Curves.easeInOutCubic),
        ),
        ScaleEffect.to(Vector2.zero(), EffectController(duration: 0.2)),
        RemoveEffect(),
      ]),
    );
  }

  @override
  void onRemove() {
    super.onRemove();
    game.onWaveTransitionComplete();
  }

  @override
  void render(Canvas canvas) {
    final rect = Rect.fromLTWH(0, 0, size.x, size.y);
    final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(16));

    // Option B: Cyan + white hot center glow
    final glowPaint = Paint()
      ..color = const Color(0x6600E5FF)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 20);
    canvas.drawRRect(rrect, glowPaint);

    // White hot core
    final corePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.4)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10);
    canvas.drawRRect(rrect.inflate(-10), corePaint);

    // Border
    final borderPaint = Paint()
      ..color = Colors.cyanAccent
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawRRect(rrect, borderPaint);

    final tp = TextPainter(
      text: TextSpan(
        text: 'WAVE $completedWave COMPLETE',
        style: const TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.w900,
          letterSpacing: 4,
          color: Colors.white,
          shadows: [
            Shadow(color: Colors.cyanAccent, blurRadius: 15),
          ],
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    tp.layout();
    tp.paint(canvas, Offset((size.x - tp.width) / 2, (size.y - tp.height) / 2));
  }
}

/// Quick brightness flash that covers the entire screen
class BrightnessFlash extends Component with HasGameReference<ZeroVectorGame> {
  double _opacity = 0.8;
  final double _duration = 0.15;
  double _timer = 0;

  @override
  void update(double dt) {
    super.update(dt);
    _timer += dt;
    if (_timer >= _duration) {
      removeFromParent();
    }
    _opacity = 0.8 * (1.0 - (_timer / _duration));
  }

  @override
  void render(Canvas canvas) {
    canvas.drawRect(
      Rect.fromLTWH(0, 0, game.size.x, game.size.y),
      Paint()..color = Colors.white.withValues(alpha: _opacity),
    );
  }
}
