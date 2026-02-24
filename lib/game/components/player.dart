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
  static const double _fireRate = 0.25;
  double _fireTimer = 0;
  bool _fireFromLeft = true; // For alternating cannons
  
  // 1-frame muzzle flash (visual only)
  bool _showMuzzleFlash = false;
  final Vector2 _currentMuzzlePos = Vector2.zero();

  // ── Dimensions ───────────────────────────────────────────────────────────────
  static const double _size = 56.0; // Slightly larger for detail

  // ── Inertia movement ─────────────────────────────────────────────────────────
  final Vector2 _velocity = Vector2.zero();
  static const double _acceleration = 1200.0;
  static const double _maxSpeed     = 460.0;
  static const double _friction     = 8.0;

  final Vector2 _dragDelta = Vector2.zero();

  // ── Tilt ─────────────────────────────────────────────────────────────────────
  static const double _maxTilt = 0.28; // ±16°

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
    position = Vector2(game.size.x / 2, game.size.y - 120);
    // Hitbox is slightly narrowed for better gameplay feel
    add(RectangleHitbox(
      size: Vector2(_size * 0.7, _size * 0.9),
      position: Vector2(_size * 0.15, _size * 0.05),
    ));
  }

  @override
  void onDragUpdate(DragUpdateEvent event) {
    _dragDelta.add(event.localDelta);
  }

  @override
  void update(double dt) {
    super.update(dt);

    if (_dragDelta.length > 0) {
      _velocity.add(_dragDelta * _acceleration * dt);
      _dragDelta.setZero();
    }

    _velocity.scale(1.0 / (1.0 + _friction * dt));

    if (_velocity.length > _maxSpeed) {
      _velocity.normalize();
      _velocity.scale(_maxSpeed);
    }

    position.add(_velocity * dt);

    final minY = game.size.y * 0.55;
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

    angle = (_velocity.x / _maxSpeed).clamp(-1.0, 1.0) * _maxTilt;

    _thrusterJitterTimer += dt;
    if (_thrusterJitterTimer >= _thrusterJitterRate) {
      _thrusterJitterTimer = 0;
      _thrusterJitter = (_rng.nextDouble() - 0.5) * 8.0;
    }

    if (_flashTimer > 0) {
      _flashTimer = (_flashTimer - dt).clamp(0.0, _flashDuration);
    }

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

    // Reset muzzle flash
    _showMuzzleFlash = false;

    _fireTimer += dt;
    if (_fireTimer >= _fireRate) {
      _fireTimer = 0;
      _shoot();
    }
  }

  void _shoot() {
    // Cannon positions on wings
    final double offsetX = _fireFromLeft ? -18.0 : 18.0;
    final double offsetY = -4.0;
    
    _currentMuzzlePos.setValues(size.x / 2 + offsetX, size.y / 2 + offsetY);
    _showMuzzleFlash = true;

    // Bullet spawning (global coords)
    // We adjust by angle to spawn accurately from cannon tips
    final spawnPos = position + (Vector2(offsetX, offsetY)..rotate(angle));
    game.add(Bullet(position: spawnPos));
    
    game.audioManager.playSfx('shoot.wav');
    _fireFromLeft = !_fireFromLeft;
  }

  void takeDamage({bool isCollision = false}) {
    if (game.isInvulnerable && !isCollision) return;
    _flashTimer = _flashDuration;
    final knockback = isCollision ? 32.0 : 16.0;
    add(
      MoveByEffect(
        Vector2(0, -knockback),
        EffectController(
          duration: 0.08, reverseDuration: 0.12, curve: Curves.easeOut,
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

    final cx = size.x / 2;
    final cy = size.y / 2;

    // ── Engine flames (drawn first, furthest back) ────────────────────────
    final speed = _velocity.length;
    if (speed > 10) {
      _drawTwinThrusters(canvas, cx, cy, speed);
    }

    // Colors
    final hullColor     = const Color(0xFF2B2F36); // Gunmetal
    final wingColor     = const Color(0xFF3A3F47); // Steel Gray

    Paint p = Paint();

    // ── 1. Wings (Bottom layer) ───────────────────────────────────────────
    final wingPath = Path()
      ..moveTo(cx - 2, cy - 2)
      ..lineTo(cx - 24, cy + 8)  // left wing tip back
      ..lineTo(cx - 26, cy + 4)  // left wing tip front
      ..lineTo(cx - 4, cy - 8)   // left wing root front
      ..lineTo(cx + 4, cy - 8)   // right wing root front
      ..lineTo(cx + 26, cy + 4)  // right wing tip front
      ..lineTo(cx + 24, cy + 8)  // right wing tip back
      ..lineTo(cx + 2, cy - 2);

    p.color = wingColor;
    canvas.drawPath(wingPath, p);

    // ── 2. Fuselage (Central body) ────────────────────────────────────────
    final fuselage = Path()
      ..moveTo(cx, 4)               // Nose (sharp)
      ..lineTo(cx + 6, cy - 10)     // shoulder R
      ..lineTo(cx + 6, size.y - 4)  // Rear R
      ..lineTo(cx, size.y)          // Engine exhaust indent
      ..lineTo(cx - 6, size.y - 4)  // Rear L
      ..lineTo(cx - 6, cy - 10)     // shoulder L
      ..close();

    p.color = hullColor;
    canvas.drawPath(fuselage, p);

    // ── 3. Panel Lines ───────────────────────────────────────────────────
    p.style = PaintingStyle.stroke;
    p.strokeWidth = 1.0;
    p.color = Colors.black.withValues(alpha: 0.4);
    canvas.drawPath(wingPath, p);
    canvas.drawPath(fuselage, p);
    
    // Cross panel lines
    canvas.drawLine(Offset(cx - 6, cy), Offset(cx + 6, cy), p);
    canvas.drawLine(Offset(cx - 6, cy + 12), Offset(cx + 6, cy + 12), p);

    // ── 4. Stabilizers ───────────────────────────────────────────────────
    final stabL = Path()
      ..moveTo(cx - 4, size.y - 8)
      ..lineTo(cx - 10, size.y)
      ..lineTo(cx - 10, size.y - 4)
      ..close();
    final stabR = Path()
      ..moveTo(cx + 4, size.y - 8)
      ..lineTo(cx + 10, size.y)
      ..lineTo(cx + 10, size.y - 4)
      ..close();
    
    p.style = PaintingStyle.fill;
    p.color = hullColor;
    canvas.drawPath(stabL, p);
    canvas.drawPath(stabR, p);

    // ── 5. Cockpit ────────────────────────────────────────────────────────
    final cockpit = Rect.fromCenter(center: Offset(cx, cy - 12), width: 6, height: 16);
    final cockpitRRect = RRect.fromRectAndRadius(cockpit, const Radius.circular(3));
    
    p.shader = const LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [Colors.white, Color(0xFF00E5FF)],
      stops: [0.1, 0.9],
    ).createShader(cockpit);
    canvas.drawRRect(cockpitRRect, p);
    p.shader = null;

    // ── 6. Cannons (Weapon Mounts) ────────────────────────────────────────
    final cannonL = Rect.fromLTWH(cx - 20, cy - 2, 2, 8);
    final cannonR = Rect.fromLTWH(cx + 18, cy - 2, 2, 8);
    p.color = const Color(0xFF1A1A1A);
    canvas.drawRect(cannonL, p);
    canvas.drawRect(cannonR, p);
    
    // Muzzle tips (Red)
    p.color = const Color(0xFFFF1744);
    canvas.drawCircle(Offset(cx - 19, cy - 2), 1.2, p);
    canvas.drawCircle(Offset(cx + 19, cy - 2), 1.2, p);

    // ── 7. Muzzle Flash (1-frame) ─────────────────────────────────────────
    if (_showMuzzleFlash) {
      _drawMuzzleFlash(canvas);
    }

    // ── 8. Glow overlays (BlendMode.plus) ─────────────────────────────────
    if (_flashTimer > 0) {
      _drawDamageFlash(canvas, wingPath, fuselage);
    }
  }

  void _drawTwinThrusters(Canvas canvas, double cx, double cy, double speed) {
    final intensity = (speed / _maxSpeed).clamp(0.0, 1.0);
    final h = 12 + 20 * intensity + _thrusterJitter.abs();
    final w = 4 + 2 * intensity;

    _drawExhaust(canvas, Offset(cx - 4, size.y - 2), w, h, intensity);
    _drawExhaust(canvas, Offset(cx + 4, size.y - 2), w, h, intensity);
  }

  void _drawExhaust(Canvas canvas, Offset top, double w, double h, double intensity) {
    // Outer glow
    final glow = Path()
      ..moveTo(top.dx - w, top.dy)
      ..lineTo(top.dx, top.dy + h)
      ..lineTo(top.dx + w, top.dy)
      ..close();

    canvas.drawPath(
      glow,
      Paint()
        ..color = const Color(0xFF00E5FF).withValues(alpha: 0.4 * intensity)
        ..blendMode = BlendMode.plus,
    );

    // Core
    final core = Path()
      ..moveTo(top.dx - w * 0.4, top.dy)
      ..lineTo(top.dx, top.dy + h * 0.6)
      ..lineTo(top.dx + w * 0.4, top.dy)
      ..close();

    canvas.drawPath(
      core,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.8 * intensity)
        ..blendMode = BlendMode.plus,
    );
  }

  void _drawMuzzleFlash(Canvas canvas) {
    canvas.drawCircle(
      Offset(_currentMuzzlePos.x, _currentMuzzlePos.y),
      8,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.8)
        ..blendMode = BlendMode.plus,
    );
    canvas.drawCircle(
      Offset(_currentMuzzlePos.x, _currentMuzzlePos.y),
      14,
      Paint()
        ..color = const Color(0xFF00E5FF).withValues(alpha: 0.3)
        ..blendMode = BlendMode.plus,
    );
  }

  void _drawDamageFlash(Canvas canvas, Path wings, Path fuselage) {
    final a = (_flashTimer / _flashDuration).clamp(0.0, 1.0);
    final p = Paint()
      ..color = const Color(0xFFFF1744).withValues(alpha: 0.6 * a)
      ..blendMode = BlendMode.plus;
    
    canvas.drawPath(wings, p);
    canvas.drawPath(fuselage, p);
  }
}
