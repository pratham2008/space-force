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

  @override
  void render(Canvas canvas) {
    final cx = size.x / 2;
    final cy = size.y / 2;

    // Engine exhaust
    canvas.drawPath(
      Path()
        ..moveTo(cx - 7, size.y)
        ..lineTo(cx, size.y + 14)
        ..lineTo(cx + 7, size.y)
        ..close(),
      Paint()
        ..color = const Color(0xFFFF6D00)
            .withValues(alpha: _shipState == _MissileShipState.aggressive ? 0.9 : 0.6)
        ..blendMode = BlendMode.plus,
    );

    // Main fuselage
    canvas.drawPath(
      Path()
        ..moveTo(cx, 0)             // Sharp nose
        ..lineTo(cx + 8, cy + 6)
        ..lineTo(cx + 6, size.y)
        ..lineTo(cx - 6, size.y)
        ..lineTo(cx - 8, cy + 6)
        ..close(),
      Paint()..color = const Color(0xFF3D1A00),
    );

    // Swept wings
    final wingPaint = Paint()..color = const Color(0xFF4A2209);
    // Left
    canvas.drawPath(
      Path()
        ..moveTo(cx - 6, cy)
        ..lineTo(0, cy + 6)
        ..lineTo(cx - 6, cy + 16)
        ..close(),
      wingPaint,
    );
    // Right
    canvas.drawPath(
      Path()
        ..moveTo(cx + 6, cy)
        ..lineTo(size.x, cy + 6)
        ..lineTo(cx + 6, cy + 16)
        ..close(),
      wingPaint,
    );

    // Missile pods under wings
    final podPaint = Paint()..color = const Color(0xFF1A0A00);
    canvas.drawRect(Rect.fromLTWH(6, cy + 4, 10, 6), podPaint);
    canvas.drawRect(Rect.fromLTWH(size.x - 16, cy + 4, 10, 6), podPaint);

    // Orange/red tip lights
    final tipPaint = Paint()
      ..color = const Color(0xFFFF6D00)
      ..blendMode = BlendMode.plus;
    canvas.drawCircle(Offset(8, cy + 7), 2, tipPaint);
    canvas.drawCircle(Offset(size.x - 8, cy + 7), 2, tipPaint);

    // Core glow (pulses brighter in aggressive mode)
    canvas.drawCircle(
      Offset(cx, cy), 8,
      Paint()
        ..color = const Color(0xFFFF6D00)
            .withValues(alpha: _shipState == _MissileShipState.aggressive ? 0.8 : 0.5)
        ..blendMode = BlendMode.plus,
    );

    // Rim light
    canvas.drawPath(
      Path()
        ..moveTo(cx - 8, cy - 2)
        ..lineTo(cx, 4),
      Paint()
        ..color = Colors.white.withValues(alpha: 0.3)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0
        ..blendMode = BlendMode.plus,
    );

    // HP bar
    final maxHp = 3 + (wave * 0.5).floor();
    if (hp < maxHp) {
      final ratio  = (hp / maxHp).clamp(0.0, 1.0);
      final barW   = size.x * 0.8;
      final startX = (size.x - barW) / 2;
      canvas.drawRect(Rect.fromLTWH(startX, -10, barW, 3), Paint()..color = Colors.black26);
      canvas.drawRect(Rect.fromLTWH(startX, -10, barW * ratio, 3),
          Paint()..color = const Color(0xFFFF6D00));
    }
  }
}
