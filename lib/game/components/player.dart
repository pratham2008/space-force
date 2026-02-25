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

  // Shared Paint objects to avoid per-frame allocations
  static final Paint _hullPaint = Paint()..color = const Color(0xFF141821);
  static final Paint _armorPaint = Paint()..color = const Color(0xFF1F2430);
  static final Paint _cyanGlowPaint = Paint()
    ..color = const Color(0xFF00E5FF).withValues(alpha: 0.5)
    ..blendMode = BlendMode.plus;
  static final Paint _magentaGlowPaint = Paint()
    ..color = const Color(0xFFFF2D95).withValues(alpha: 0.6)
    ..blendMode = BlendMode.plus;
  static final Paint _linePaint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.0
    ..color = Colors.white.withValues(alpha: 0.15);

  @override
  void render(Canvas canvas) {
    if (!_invulnBlinkVisible) return;

    final cx = size.x / 2;
    final cy = size.y / 2;

    final speed = _velocity.length;
    if (speed > 10) {
      _drawCyberThrusters(canvas, cx, cy, speed);
    }

    // ── 1. Base Delta Hull (Lower Layer) ──────────────────────────────────
    final deltaHull = Path()
      ..moveTo(cx, 6)                         // Sharp nose
      ..lineTo(cx + 28, cy + 18)              // Right wing tip (swept)
      ..lineTo(cx + 10, size.y - 2)           // Right rear
      ..lineTo(cx, size.y - 6)                // Engine bay indent
      ..lineTo(cx - 10, size.y - 2)           // Left rear
      ..lineTo(cx - 28, cy + 18)              // Left wing tip (swept)
      ..close();
    
    canvas.drawPath(deltaHull, _hullPaint);

    // ── 2. Secondary Armor Plating (Middle Layer) ─────────────────────────
    final armorPlating = Path()
      ..moveTo(cx, 16)
      ..lineTo(cx + 14, cy + 8)
      ..lineTo(cx + 6, size.y - 10)
      ..lineTo(cx - 6, size.y - 10)
      ..lineTo(cx - 14, cy + 8)
      ..close();
    
    canvas.drawPath(armorPlating, _armorPaint);

    // ── 3. Detail Lines (Paneling) ───────────────────────────────────────
    canvas.drawPath(deltaHull, _linePaint);
    canvas.drawPath(armorPlating, _linePaint);
    // Micro-accents on wings
    canvas.drawLine(Offset(cx - 14, cy + 8), Offset(cx - 24, cy + 15), _linePaint);
    canvas.drawLine(Offset(cx + 14, cy + 8), Offset(cx + 24, cy + 15), _linePaint);

    // ── 4. Neon Edge Strips (Cyan) ────────────────────────────────────────
    final cyanEdge = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..color = const Color(0xFF00E5FF).withValues(alpha: 0.7)
      ..blendMode = BlendMode.plus;
    
    // Front edges of wings
    canvas.drawLine(Offset(cx, 8), Offset(cx + 26, cy + 16), cyanEdge);
    canvas.drawLine(Offset(cx, 8), Offset(cx - 26, cy + 16), cyanEdge);

    // ── 5. Magenta Accent Strips ──────────────────────────────────────────
    final magentaStrip = Paint()..color = const Color(0xFFFF2D95);
    canvas.drawRect(Rect.fromLTWH(cx - 18, cy + 12, 6, 2), magentaStrip);
    canvas.drawRect(Rect.fromLTWH(cx + 12, cy + 12, 6, 2), magentaStrip);

    // ── 6. Cockpit Canopy (Cyan Glow) ─────────────────────────────────────
    final canopyRect = Rect.fromCenter(center: Offset(cx, cy - 4), width: 10, height: 18);
    final canopyRRect = RRect.fromRectAndRadius(canopyRect, const Radius.circular(5));
    
    canvas.drawRRect(canopyRRect, Paint()..color = const Color(0xFF08121A));
    canvas.drawRRect(canopyRRect, _cyanGlowPaint);
    
    // Internal canopy detail
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromCenter(center: Offset(cx, cy - 8), width: 4, height: 6), const Radius.circular(2)),
      Paint()..color = Colors.white.withValues(alpha: 0.3)
    );

    // ── 7. Rear Stabilizers ───────────────────────────────────────────────
    final stabL = Path()
      ..moveTo(cx - 6, size.y - 8)
      ..lineTo(cx - 14, size.y)
      ..lineTo(cx - 14, size.y - 4)
      ..close();
    final stabR = Path()
      ..moveTo(cx + 6, size.y - 8)
      ..lineTo(cx + 14, size.y)
      ..lineTo(cx + 14, size.y - 4)
      ..close();
    
    canvas.drawPath(stabL, _hullPaint);
    canvas.drawPath(stabR, _hullPaint);
    canvas.drawPath(stabL, _linePaint);
    canvas.drawPath(stabR, _linePaint);

    // ── 8. Muzzle Flash (Existing logic) ──────────────────────────────────
    if (_showMuzzleFlash) {
      _drawCyberMuzzleFlash(canvas);
    }

    // ── 9. Damage Flash ──────────────────────────────────────────────────
    if (_flashTimer > 0) {
      _drawDamageFlash(canvas, deltaHull);
    }
  }

  void _drawCyberThrusters(Canvas canvas, double cx, double cy, double speed) {
    final intensity = (speed / _maxSpeed).clamp(0.0, 1.0);
    final h = 14 + 18 * intensity + _thrusterJitter.abs();
    final w = 6 + 2 * intensity;

    _drawExhaustCyber(canvas, Offset(cx - 7, size.y - 4), w, h, intensity);
    _drawExhaustCyber(canvas, Offset(cx + 7, size.y - 4), w, h, intensity);
  }

  void _drawExhaustCyber(Canvas canvas, Offset top, double w, double h, double intensity) {
    // 1. Magenta outer shimmer
    final magentaShimmer = Path()
      ..moveTo(top.dx - w, top.dy)
      ..lineTo(top.dx, top.dy + h * 1.1)
      ..lineTo(top.dx + w, top.dy)
      ..close();
    canvas.drawPath(magentaShimmer, _magentaGlowPaint..color = const Color(0xFFFF2D95).withValues(alpha: 0.2 * intensity));

    // 2. Cyan outer glow
    final glow = Path()
      ..moveTo(top.dx - w * 0.8, top.dy)
      ..lineTo(top.dx, top.dy + h)
      ..lineTo(top.dx + w * 0.8, top.dy)
      ..close();
    canvas.drawPath(glow, _cyanGlowPaint..color = const Color(0xFF00E5FF).withValues(alpha: 0.4 * intensity));

    // 3. Central bright core
    final core = Path()
      ..moveTo(top.dx - w * 0.3, top.dy)
      ..lineTo(top.dx, top.dy + h * 0.5)
      ..lineTo(top.dx + w * 0.3, top.dy)
      ..close();
    canvas.drawPath(core, Paint()..color = Colors.white.withValues(alpha: 0.8 * intensity)..blendMode = BlendMode.plus);
  }

  void _drawCyberMuzzleFlash(Canvas canvas) {
    final pX = _currentMuzzlePos.x;
    final pY = _currentMuzzlePos.y;
    
    canvas.drawCircle(Offset(pX, pY), 10, _cyanGlowPaint);
    canvas.drawCircle(Offset(pX, pY), 5, Paint()..color = Colors.white..blendMode = BlendMode.plus);
    
    // Magenta spark
    canvas.drawRect(Rect.fromCenter(center: Offset(pX, pY), width: 14, height: 1.5), _magentaGlowPaint);
  }

  void _drawDamageFlash(Canvas canvas, Path hull) {
    final a = (_flashTimer / _flashDuration).clamp(0.0, 1.0);
    canvas.drawPath(
      hull,
      Paint()
        ..color = const Color(0xFFFF1744).withValues(alpha: 0.6 * a)
        ..blendMode = BlendMode.plus,
    );
  }
}
