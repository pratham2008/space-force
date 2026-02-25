import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import '../zero_vector_game.dart';
import 'hittable.dart';

class Bullet extends PositionComponent
    with HasGameReference<ZeroVectorGame>, CollisionCallbacks {
  static const double _speed  = 520.0;
  static const double _width  = 5.0;
  static const double _height = 22.0;
  static const int _damage    = DamageValues.bullet;

  Bullet({required Vector2 position})
      : super(
          position: position,
          size: Vector2(_width, _height),
          anchor: Anchor.center,
        );

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    add(RectangleHitbox());
  }

  @override
  void update(double dt) {
    super.update(dt);
    position.y -= _speed * dt;
    if (position.y < -_height) removeFromParent();
  }

  @override
  void onCollisionStart(
    Set<Vector2> intersectionPoints,
    PositionComponent other,
  ) {
    super.onCollisionStart(intersectionPoints, other);
    if (other is Hittable) {
      (other as Hittable).hit(_damage);
      removeFromParent();
    }
  }

  @override
  void render(Canvas canvas) {
    // ── Motion trail (faded duplicate behind bullet) ───────────────────────
    final trailRect = Rect.fromLTWH(0, _height * 0.4, size.x, size.y * 0.7);
    canvas.drawRect(
      trailRect,
      Paint()
        ..color = const Color(0xFF00E5FF).withValues(alpha: 0.12)
        ..blendMode = BlendMode.plus,
    );

    // ── Outer glow pass ────────────────────────────────────────────────────
    canvas.drawRect(
      Rect.fromLTWH(-2, -2, size.x + 4, size.y + 4),
      Paint()
        ..color = const Color(0xFF00E5FF).withValues(alpha: 0.25)
        ..blendMode = BlendMode.plus,
    );

    // ── Laser core gradient (white-hot centre → cyan edges) ───────────────
    final gradientPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Color(0xFFFFFFFF), // muzzle flash: white hot
          Color(0xFF80F4FF), // mid
          Color(0xFF00E5FF), // tail: cyan
        ],
        stops: [0.0, 0.35, 1.0],
      ).createShader(Rect.fromLTWH(0, 0, size.x, size.y));

    canvas.drawRect(Rect.fromLTWH(0, 0, size.x, size.y), gradientPaint);
  }
}
