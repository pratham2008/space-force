import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import '../zero_vector_game.dart';
import 'enemy.dart';

class Bullet extends PositionComponent
    with HasGameReference<ZeroVectorGame>, CollisionCallbacks {
  static const double _speed = 500.0;
  static const double _width = 6.0;
  static const double _height = 16.0;
  static const int _damage = DamageValues.bullet;

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

    if (position.y < -_height) {
      removeFromParent();
    }
  }

  @override
  void onCollisionStart(
    Set<Vector2> intersectionPoints,
    PositionComponent other,
  ) {
    super.onCollisionStart(intersectionPoints, other);
    if (other is Enemy) {
      other.hit(_damage);  // deals damage; enemy destroys itself when hp ≤ 0
      removeFromParent();
    }
  }

  @override
  void render(Canvas canvas) {
    final paint = Paint()..color = const Color(0xFFFFEB3B);
    canvas.drawRect(Rect.fromLTWH(0, 0, size.x, size.y), paint);
  }
}
