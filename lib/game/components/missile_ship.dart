import 'dart:math';
import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import '../zero_vector_game.dart';
import '../effects/particle_effects.dart';
import '../effects/warp_ring_component.dart';
import 'player.dart';
import 'hittable.dart';
import 'missile_projectile.dart';
import 'missile_lock_reticle.dart';

/// State machine for MissileShip.
enum _MissileShipState {
  entering,   // Flying down to hover Y
  hovering,   // Oscillating at hover Y, counting down to lock
  locking,    // MissileLockReticle is active on player
  cooldown,   // Post-fire pause before hovering again
  aggressive, // Aggressive dive — hover/lock cancelled, track player & descend
}

class MissileShip extends PositionComponent
    with HasGameReference<ZeroVectorGame>, CollisionCallbacks, Hittable {

  // ── Config ──────────────────────────────────────────────────────────────────
  final double baseSpeed;
  final double hoverYFraction;
  final int wave;
  int hp;

  // ── State machine ───────────────────────────────────────────────────────────
  _MissileShipState _shipState = _MissileShipState.entering;
  double _hoverTargetY = 0;
  double _stateTimer   = 0;
  double _oscillationPhase = 0;

  static const double _preLockHoverDuration = 1.5;
  static const double _launchCooldown       = 4.0;

  bool _reticleActive = false;

  final Random _random = Random();

  static const double _shipWidth  = 64.0;
  static const double _shipHeight = 48.0;

  MissileShip({
    required Vector2 position,
    required this.wave,
    required this.hp,
    this.baseSpeed = 100.0,
    this.hoverYFraction = 0.30,
  }) : super(
          position: position,
          size: Vector2(_shipWidth, _shipHeight),
          anchor: Anchor.center,
        );

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    add(RectangleHitbox(
      size: Vector2(size.x * 0.85, size.y * 0.8),
      position: Vector2(size.x * 0.075, size.y * 0.1),
      collisionType: CollisionType.active,
    ));

    game.add(WarpRingComponent(
      position: position.clone(),
      color: const Color(0xFFFF6D00),
    ));

    final minY  = game.size.y * 0.10;
    final maxY  = game.size.y * hoverYFraction;
    _hoverTargetY = minY + _random.nextDouble() * (maxY - minY);
    _oscillationPhase = _random.nextDouble() * 2 * pi;
  }

  // ── Update ──────────────────────────────────────────────────────────────────

  @override
  void update(double dt) {
    super.update(dt);
    if (position.y > game.size.y + size.y) {
      removeFromParent();
      return;
    }

    _stateTimer += dt;
    _oscillationPhase += 1.5 * dt;

    switch (_shipState) {
      case _MissileShipState.entering:
        position.y += baseSpeed * dt;
        if (position.y >= _hoverTargetY) {
          position.y = _hoverTargetY;
          _shipState  = _MissileShipState.hovering;
          _stateTimer = 0;
        }

      case _MissileShipState.hovering:
        _oscillateXY(dt);
        if (_stateTimer >= _preLockHoverDuration) {
          _beginLock();
        }

      case _MissileShipState.locking:
        _oscillateXY(dt);
        // MissileLockReticle calls _onLockComplete when finished

      case _MissileShipState.cooldown:
        _oscillateXY(dt);
        if (_stateTimer >= _launchCooldown) {
          _shipState  = _MissileShipState.hovering;
          _stateTimer = 0;
        }

      case _MissileShipState.aggressive:
        // Dive toward player X while descending
        final px = game.player?.position.x ?? position.x;
        final dx = (px - position.x).clamp(-baseSpeed * dt * 1.4, baseSpeed * dt * 1.4);
        position.x += dx;
        position.y += baseSpeed * 1.4 * dt;
    }
  }

  void _oscillateXY(double dt) {
    position.x += sin(_oscillationPhase) * 25.0 * dt;
    position.x  = position.x.clamp(size.x / 2, game.size.x - size.x / 2);
    position.y  = _hoverTargetY + sin(_oscillationPhase * 1.2) * 4.0;
  }

  // ── Lock sequence ────────────────────────────────────────────────────────────

  void _beginLock() {
    if (_reticleActive) return;
    _reticleActive = true;
    _shipState  = _MissileShipState.locking;
    _stateTimer = 0;
    game.add(MissileLockReticle(onLockComplete: _onLockComplete));
  }

  void _onLockComplete() {
    _reticleActive = false;
    _fireMissile();
    _shipState  = _MissileShipState.cooldown;
    _stateTimer = 0;
  }

  void _fireMissile() {
    final player = game.player;
    if (player == null) return;

    // Capture player position AT fire time — missile does NOT live-track
    final targetPos  = player.position.clone();
    final spawnPos   = Vector2(position.x, position.y + size.y / 2);
    final rawDir     = targetPos - spawnPos;

    // Guard against zero-length (shouldn't happen, but prevents NaN)
    final direction = rawDir.length > 0.001
        ? (rawDir..normalize())
        : Vector2(0, 1);

    game.add(MissileProjectile(
      position: spawnPos,
      damage: missileWaveDamage(wave), // Fixed at creation
      direction: direction,
    ));
    game.audioManager.playSfx('enemy_shoot.wav');
  }

  // ── Aggressive mode (called after 60s wave timer) ────────────────────────────

  /// Activates aggressive dive mode.
  /// Cleanly cancels active lock phase and hover oscillation before switching.
  void activateAggressiveMode() {
    if (_shipState == _MissileShipState.aggressive) return;

    // ── Cancel active lock reticle cleanly ───────────────────────────────────
    // The reticle has already been added to the game — find and remove it.
    if (_reticleActive) {
      for (final r in game.children.whereType<MissileLockReticle>()) {
        r.removeFromParent();
      }
      _reticleActive = false;
    }

    // ── Cancel hover oscillation — reset Y to current position ───────────────
    // (avoids a sudden jump when Y was being set to _hoverTargetY + sin(…))
    _hoverTargetY = position.y;

    // ── Switch to aggressive dive ─────────────────────────────────────────────
    _shipState  = _MissileShipState.aggressive;
    _stateTimer = 0;
  }

  // ── Hittable (player bullets) ────────────────────────────────────────────────

  @override
  void hit(int damage) {
    hp -= damage;
    if (hp <= 0) {
      final pCount = game.children.whereType<ParticleSystemComponent>().length;
      if (pCount < kMaxParticleSystems) {
        game.add(explosionParticles(position.clone()));
      }
      game.audioManager.playSfx('explosion.wav');
      game.onEnemyKilled(35, position.clone(), false);
      removeFromParent();
    } else {
      final pCount = game.children.whereType<ParticleSystemComponent>().length;
      if (pCount < kMaxParticleSystems) {
        game.add(sparkParticles(position.clone()));
      }
    }
  }

  // ── Collision (physical contact with player) ─────────────────────────────────

  @override
  void onCollisionStart(Set<Vector2> intersectionPoints, PositionComponent other) {
    super.onCollisionStart(intersectionPoints, other);
    if (other is Player) {
      game.applyCollisionDamage();
      other.takeDamage(isCollision: true);
      removeFromParent();
    }
  }

  // ── Render ───────────────────────────────────────────────────────────────────

  // ── Render ───────────────────────────────────────────────────────────────────

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
    final cx = size.x / 2;
    final cy = size.y / 2;

    // ── 1. Sharp Triangular Hull (Base Layer) ───────────────────────────
    final noseHull = Path()
      ..moveTo(cx, 0)                         // Forward extended nose
      ..lineTo(cx + 28, size.y - 10)           // Right wing tip
      ..lineTo(cx + 12, size.y)                // Right rear
      ..lineTo(cx - 12, size.y)                // Left rear
      ..lineTo(cx - 28, size.y - 10)           // Left wing tip
      ..close();
    
    canvas.drawPath(noseHull, _hullPaint);

    // ── 2. Top Armor Layer ──────────────────────────────────────────────
    final armor = Path()
      ..moveTo(cx, 12)
      ..lineTo(cx + 12, cy)
      ..lineTo(cx, cy + 8)
      ..lineTo(cx - 12, cy)
      ..close();
    canvas.drawPath(armor, _armorPaint);

    // ── 3. Underslung Missile Rails (Magenta) ────────────────────────────
    final railPaint = Paint()..color = const Color(0xFF0D0508);
    canvas.drawRect(Rect.fromLTWH(cx - 22, cy + 4, 12, 4), railPaint);
    canvas.drawRect(Rect.fromLTWH(cx + 10, cy + 4, 12, 4), railPaint);
    
    // Magenta pod glow
    canvas.drawRect(Rect.fromLTWH(cx - 20, cy + 5, 8, 2), _magentaGlowPaint);
    canvas.drawRect(Rect.fromLTWH(cx + 12, cy + 5, 8, 2), _magentaGlowPaint);

    // ── 4. Cyan Engine Glow ──────────────────────────────────────────────
    _drawCyberExhaustSingle(canvas, Offset(cx, size.y - 4), 10, 16, const Color(0xFF00E5FF));

    // ── 5. Blinking Magenta Tip Light ────────────────────────────────────
    // Use _oscillationPhase for consistent per-ship blinking
    final blink = (sin(_oscillationPhase * 4.0) > 0);
    if (blink) {
      canvas.drawCircle(Offset(cx, 4), 2, _magentaGlowPaint);
    }

    // ── 6. Subtle Animated Light Strip ───────────────────────────────────
    final stripT = (sin(_oscillationPhase * 0.8) + 1) / 2; // 0..1
    final stripX = cx - 10 + 20 * stripT;
    canvas.drawRect(Rect.fromLTWH(stripX - 2, cy - 2, 4, 1), _cyanGlowPaint);

    // ── 7. Detail lines ──────────────────────────────────────────────────
    canvas.drawPath(noseHull, _linePaint);
    canvas.drawPath(armor, _linePaint);

    _drawHpBar(canvas);
  }

  void _drawCyberExhaustSingle(Canvas canvas, Offset top, double w, double h, Color baseColor) {
    final speedFactor = _shipState == _MissileShipState.aggressive ? 1.5 : 1.0;
    final finalH = h * speedFactor;
    
    final glow = Path()
      ..moveTo(top.dx - w / 2, top.dy)
      ..lineTo(top.dx, top.dy + finalH)
      ..lineTo(top.dx + w / 2, top.dy)
      ..close();

    canvas.drawPath(
      glow,
      Paint()
        ..color = baseColor.withValues(alpha: 0.4)
        ..blendMode = BlendMode.plus,
    );

    final core = Path()
      ..moveTo(top.dx - w * 0.2, top.dy)
      ..lineTo(top.dx, top.dy + finalH * 0.5)
      ..lineTo(top.dx + w * 0.2, top.dy)
      ..close();

    canvas.drawPath(
      core,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.7)
        ..blendMode = BlendMode.plus,
    );
  }

  void _drawHpBar(Canvas canvas) {
    final maxHp = 3 + (wave * 0.5).floor();
    if (hp >= maxHp) return;

    final ratio  = (hp / maxHp).clamp(0.0, 1.0);
    final barW   = size.x * 0.8;
    final startX = (size.x - barW) / 2;

    canvas.drawRect(
      Rect.fromLTWH(startX, -10, barW, 3),
      Paint()..color = Colors.black26,
    );
    canvas.drawRect(
      Rect.fromLTWH(startX, -10, barW * ratio, 3),
      Paint()..color = const Color(0xFFFF2D95),
    );
  }
}
