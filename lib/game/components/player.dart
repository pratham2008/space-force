import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:flame/effects.dart';
import 'package:flame/events.dart';
import 'package:flutter/material.dart';
import '../zero_vector_game.dart';
import 'bullet.dart';

class Player extends PositionComponent
    with HasGameReference<ZeroVectorGame>, DragCallbacks, CollisionCallbacks {
  static const double _fireRate = 0.3;
  double _fireTimer = 0;

  static const double _size = 48.0;

  // ── Flash state ─────────────────────────────────────────────────────────────
  // Normal damage flash: 0.2s. Invuln flash: blink pattern handled in render.
  static const double _flashDuration = 0.2;
  double _flashTimer = 0;

  // ── Invuln blink ─────────────────────────────────────────────────────────────
  bool _invulnBlinkVisible = true;
  double _blinkTimer = 0;
  static const double _blinkRate = 0.1; // toggle every 0.1s

  Player()
      : super(
          size: Vector2.all(_size),
          anchor: Anchor.center,
        );

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    position = Vector2(
      game.size.x / 2,
      game.size.y - 100,
    );
    add(RectangleHitbox());
  }

  @override
  void update(double dt) {
    super.update(dt);

    // Flash timer
    if (_flashTimer > 0) {
      _flashTimer = (_flashTimer - dt).clamp(0, _flashDuration);
    }

    // Invuln blink
    if (game.isInvulnerable) {
      _blinkTimer += dt;
      if (_blinkTimer >= _blinkRate) {
        _blinkTimer = 0;
        _invulnBlinkVisible = !_invulnBlinkVisible;
      }
    } else {
      _invulnBlinkVisible = true;
      _blinkTimer = 0;
    }

    // Auto-fire
    _fireTimer += dt;
    if (_fireTimer >= _fireRate) {
      _fireTimer = 0;
      _shoot();
    }

    // ── Movement restriction: bottom 40% of screen ────────────────────────────
    final minY = game.size.y * 0.6;
    position.x = position.x.clamp(_size / 2, game.size.x - _size / 2);
    position.y = position.y.clamp(minY, game.size.y - _size / 2);
  }

  void _shoot() {
    game.add(
      Bullet(position: Vector2(position.x, position.y - _size / 2)),
    );
    game.audioManager.playSfx('shoot.wav');
  }

  // ── Drag — unchanged ────────────────────────────────────────────────────────
  @override
  void onDragUpdate(DragUpdateEvent event) {
    position += event.localDelta;
  }

  // ── Damage feedback ─────────────────────────────────────────────────────────

  /// Visual-only feedback called alongside game-level damage methods.
  /// [isCollision] = true → stronger knockback; false = bullet hit.
  void takeDamage({bool isCollision = false}) {
    if (game.isInvulnerable && !isCollision) return;

    _flashTimer = _flashDuration;

    final knockback = isCollision ? 32.0 : 16.0;
    add(
      MoveByEffect(
        Vector2(0, -knockback),
        EffectController(
          duration: 0.08,
          reverseDuration: 0.12,
          curve: Curves.easeOut,
        ),
      ),
    );
  }

  /// Called by the game when a life is lost — starts the 1s invuln blink.
  void startInvulnFlash() {
    _flashTimer = 0;
    _invulnBlinkVisible = true;
    _blinkTimer = 0;
  }

  @override
  void render(Canvas canvas) {
    // Hide during blink-off frames
    if (!_invulnBlinkVisible) return;

    final Color shipColor = _flashTimer > 0
        ? Color.lerp(
            const Color(0xFF00E5FF),
            const Color(0xFFFF1744),
            (_flashTimer / _flashDuration).clamp(0.0, 1.0),
          )!
        : const Color(0xFF00E5FF);

    final paint = Paint()..color = shipColor;
    final path = Path()
      ..moveTo(size.x / 2, 0)
      ..lineTo(size.x, size.y)
      ..lineTo(0, size.y)
      ..close();
    canvas.drawPath(path, paint);
  }
}
