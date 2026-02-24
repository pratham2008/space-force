import 'dart:math';
import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:flame/effects.dart';
import 'package:flame/events.dart';
import 'package:flutter/material.dart';
import '../zero_vector_game.dart';
import 'bullet.dart';

class Player extends PositionComponent
    with HasGameReference<ZeroVectorGame>, DragCallbacks, CollisionCallbacks {
  // ── Fire ────────────────────────────────────────────────────────────────────
  static const double _fireRate = 0.3;
  double _fireTimer = 0;

  // ── Dimensions ───────────────────────────────────────────────────────────────
  static const double _size = 52.0;

  // ── Inertia movement ─────────────────────────────────────────────────────────
  final Vector2 _velocity = Vector2.zero();
  static const double _acceleration = 1200.0; // px/s² per drag-delta
  static const double _maxSpeed     = 460.0;  // px/s
  static const double _friction     = 8.0;    // exponential drag multiplier

  // Pending drag delta applied on next update()
  final Vector2 _dragDelta = Vector2.zero();

  // ── Tilt ─────────────────────────────────────────────────────────────────────
  // Max tilt ±14°
  static const double _maxTilt = 0.24; // radians

  // ── Flash / invuln ──────────────────────────────────────────────────────────
  static const double _flashDuration = 0.2;
  double _flashTimer = 0;
  bool _invulnBlinkVisible = true;
  double _blinkTimer = 0;
  static const double _blinkRate = 0.1;

  // ── Thruster flicker ─────────────────────────────────────────────────────────
  final Random _rng = Random();
  double _thrusterJitter = 0;
  static const double _thrusterJitterRate = 0.04;
  double _thrusterJitterTimer = 0;

  Player()
      : super(
          size: Vector2.all(_size),
          anchor: Anchor.center,
        );

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    position = Vector2(game.size.x / 2, game.size.y - 100);
    add(RectangleHitbox());
  }

  // ── Drag ─────────────────────────────────────────────────────────────────────
  // Accumulate delta only. Position is moved exclusively in update().
  @override
  void onDragUpdate(DragUpdateEvent event) {
    _dragDelta.add(event.localDelta);
  }

  // ── Update ───────────────────────────────────────────────────────────────────
  @override
  void update(double dt) {
    super.update(dt);

    // ── Apply drag delta as acceleration ─────────────────────────────────
    if (_dragDelta.length > 0) {
      _velocity.add(_dragDelta * _acceleration * dt);
      _dragDelta.setZero();
    }

    // ── Friction / drag ──────────────────────────────────────────────────
    _velocity.scale(1.0 / (1.0 + _friction * dt));

    // ── Clamp speed ──────────────────────────────────────────────────────
    if (_velocity.length > _maxSpeed) {
      _velocity.normalize();
      _velocity.scale(_maxSpeed);
    }

    // ── Move ─────────────────────────────────────────────────────────────
    position.add(_velocity * dt);

    // ── Boundary clamp + velocity zeroing ────────────────────────────────
    final minY = game.size.y * 0.6;
    final hw   = _size / 2;
    if (position.x < hw) {
      position.x = hw;
      if (_velocity.x < 0) _velocity.x = 0;
    }
    if (position.x > game.size.x - hw) {
      position.x = game.size.x - hw;
      if (_velocity.x > 0) _velocity.x = 0;
    }
    if (position.y < minY) {
      position.y = minY;
      if (_velocity.y < 0) _velocity.y = 0;
    }
    if (position.y > game.size.y - hw) {
      position.y = game.size.y - hw;
      if (_velocity.y > 0) _velocity.y = 0;
    }

    // ── Tilt ─────────────────────────────────────────────────────────────
    angle = (_velocity.x / _maxSpeed).clamp(-1.0, 1.0) * _maxTilt;

    // ── Thruster jitter ──────────────────────────────────────────────────
    _thrusterJitterTimer += dt;
    if (_thrusterJitterTimer >= _thrusterJitterRate) {
      _thrusterJitterTimer = 0;
      _thrusterJitter = (_rng.nextDouble() - 0.5) * 6.0;
    }

    // ── Flash timer ──────────────────────────────────────────────────────
    if (_flashTimer > 0) {
      _flashTimer = (_flashTimer - dt).clamp(0.0, _flashDuration);
    }

    // ── Invuln blink ─────────────────────────────────────────────────────
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

    // ── Auto-fire ────────────────────────────────────────────────────────
    _fireTimer += dt;
    if (_fireTimer >= _fireRate) {
      _fireTimer = 0;
      _shoot();
    }
  }

  void _shoot() {
    game.add(Bullet(position: Vector2(position.x, position.y - _size / 2)));
    game.audioManager.playSfx('shoot.wav');
  }

  // ── Damage feedback ──────────────────────────────────────────────────────────
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

  void startInvulnFlash() {
    _flashTimer = 0;
    _invulnBlinkVisible = true;
    _blinkTimer = 0;
  }

  // ── Render ───────────────────────────────────────────────────────────────────
  @override
  void render(Canvas canvas) {
    if (!_invulnBlinkVisible) return;

    final shipColor = _flashTimer > 0
        ? Color.lerp(
            const Color(0xFF00E5FF),
            const Color(0xFFFF1744),
            (_flashTimer / _flashDuration).clamp(0.0, 1.0),
          )!
        : const Color(0xFF00E5FF);

    final cx = size.x / 2;
    final cy = size.y / 2;

    // ── Thruster flame (drawn behind ship) ────────────────────────────────
    final speed = _velocity.length;
    if (speed > 20) {
      _drawThruster(canvas, cx, cy, speed);
    }

    // ── Outer glow pass (BlendMode.plus, wider stroke) ────────────────────
    final glowPaint = Paint()
      ..color = shipColor.withValues(alpha: 0.35)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8.0
      ..blendMode = BlendMode.plus;

    canvas.drawPath(_buildShipPath(cx, cy), glowPaint);

    // ── Ship body fill ────────────────────────────────────────────────────
    final bodyPaint = Paint()
      ..color = shipColor.withValues(alpha: 0.9)
      ..style = PaintingStyle.fill;
    canvas.drawPath(_buildShipPath(cx, cy), bodyPaint);

    // ── Inner highlight stroke ────────────────────────────────────────────
    final strokePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;
    canvas.drawPath(_buildShipPath(cx, cy), strokePaint);
  }

  Path _buildShipPath(double cx, double cy) {
    // Symmetrical fuselage:  nose → right-fin → right-rear → centre-rear →
    //                         left-rear → left-fin → close
    return Path()
      ..moveTo(cx, 0)                         // nose
      ..lineTo(cx + 20, cy + 4)               // right shoulder
      ..lineTo(cx + 24, cy + 14)              // right wingtip flare
      ..lineTo(cx + 16, cy + 20)              // right wing inner
      ..lineTo(cx + 8,  cy + 18)              // right fuselage
      ..lineTo(cx + 5,  size.y - 4)           // right tail
      ..lineTo(cx,      size.y)               // tail centre
      ..lineTo(cx - 5,  size.y - 4)           // left tail
      ..lineTo(cx - 8,  cy + 18)              // left fuselage
      ..lineTo(cx - 16, cy + 20)              // left wing inner
      ..lineTo(cx - 24, cy + 14)              // left wingtip flare
      ..lineTo(cx - 20, cy + 4)               // left shoulder
      ..close();
  }

  void _drawThruster(Canvas canvas, double cx, double cy, double speed) {
    final intensity = (speed / _maxSpeed).clamp(0.0, 1.0);
    final flameH = 10 + 16 * intensity + _thrusterJitter.abs();
    final flameW = 6 + 4 * intensity;

    // Two overlapping cones:  outer (blue) + inner (white)
    final outerPath = Path()
      ..moveTo(cx - flameW, size.y - 2)
      ..lineTo(cx, size.y + flameH)
      ..lineTo(cx + flameW, size.y - 2)
      ..close();

    canvas.drawPath(
      outerPath,
      Paint()
        ..color = const Color(0xFF00E5FF).withValues(alpha: 0.5 * intensity)
        ..blendMode = BlendMode.plus,
    );

    final innerPath = Path()
      ..moveTo(cx - flameW * 0.4, size.y - 2)
      ..lineTo(cx, size.y + flameH * 0.6 + _thrusterJitter)
      ..lineTo(cx + flameW * 0.4, size.y - 2)
      ..close();

    canvas.drawPath(
      innerPath,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.7 * intensity)
        ..blendMode = BlendMode.plus,
    );
  }
}
