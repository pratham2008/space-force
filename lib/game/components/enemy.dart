import 'dart:math';
import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import '../zero_vector_game.dart';
import '../effects/particle_effects.dart';
import '../effects/warp_ring_component.dart';
import 'player.dart';

class Enemy extends PositionComponent
    with HasGameReference<ZeroVectorGame>, CollisionCallbacks {

  // ── Base stats ────────────────────────────────────────────────────────────
  final double baseSpeed;
  final int scoreValue;
  int hp;

  // ── Hover config ──────────────────────────────────────────────────────────
  final double hoverYFraction;
  static const double _hoverMinFraction = 0.10;

  // ── Movement state ────────────────────────────────────────────────────────
  double _currentSpeed;
  bool _aggressiveMode = false;
  bool _hovering = false;
  double _hoverTargetY = 0;
  double _oscillationPhase = 0;
  static const double _oscillationAmplitude = 30.0;
  static const double _oscillationSpeed     = 1.8;

  // ── Rotation oscillation ─────────────────────────────────────────────────
  double _rotationPhase = 0;
  static const double _rotationSpeed = 0.9;
  static const double _maxRotation   = 0.12; // ±~7°

  // ── Fire ──────────────────────────────────────────────────────────────────
  double _fireTimer = 0;
  late double _fireInterval;
  final Random _random = Random();

  final bool startAggressive;

  // ── Wave-scaled size ──────────────────────────────────────────────────────
  // Size is set in the constructor based on wave; hitbox is updated in onLoad.
  final int wave;

  Enemy({
    required Vector2 position,
    this.baseSpeed    = 120.0,
    this.scoreValue   = 10,
    required this.hp,
    required this.hoverYFraction,
    this.startAggressive = false,
    this.wave = 1,
  })  : _currentSpeed = baseSpeed,
        super(
          position: position,
          // Size grows with wave, clamped 40–70 px
          size: Vector2.all((38.0 + wave * 3.0).clamp(40.0, 70.0)),
          anchor: Anchor.center,
        );

  @override
  Future<void> onLoad() async {
    await super.onLoad();

    // Hitbox matches current (wave-scaled) size
    add(RectangleHitbox(size: size.clone()));

    _fireInterval = _calculateFireInterval();
    _fireTimer    = _random.nextDouble() * _fireInterval;
    _rotationPhase = _random.nextDouble() * 2 * pi;

    // Warp-in effect
    game.add(WarpRingComponent(
      position: position.clone(),
      color: const Color(0xFFFF1744),
    ));

    if (startAggressive) {
      _aggressiveMode  = true;
      _currentSpeed    = baseSpeed * 1.4;
    } else {
      _oscillationPhase = _random.nextDouble() * 2 * pi;
      final minY = game.size.y * _hoverMinFraction;
      final maxY = game.size.y * hoverYFraction;
      _hoverTargetY = minY + _random.nextDouble() * (maxY - minY);
    }
  }

  @override
  void update(double dt) {
    super.update(dt);

    _rotationPhase += _rotationSpeed * dt;
    angle = sin(_rotationPhase) * _maxRotation;

    if (_aggressiveMode) {
      _updateAggressive(dt);
    } else {
      _updateHover(dt);
    }

    final playerZoneCeiling = game.size.y * 0.60;
    if (position.y > playerZoneCeiling) position.y = playerZoneCeiling;

    if (position.y > game.size.y + size.y) {
      removeFromParent();
      return;
    }

    _fireTimer += dt;
    if (_fireTimer >= _fireInterval) {
      _fireTimer    = 0;
      _fireInterval = _calculateFireInterval();
      _fire();
    }
  }

  void _updateHover(double dt) {
    if (!_hovering) {
      position.y += _currentSpeed * dt;
      if (position.y >= _hoverTargetY) {
        position.y = _hoverTargetY;
        _hovering = true;
      }
    } else {
      _oscillationPhase += _oscillationSpeed * dt;
      position.x += sin(_oscillationPhase) * _oscillationAmplitude * dt;
      position.x = position.x.clamp(size.x / 2, game.size.x - size.x / 2);

      // Subtle vertical hover bob (±2.5 px)
      position.y = _hoverTargetY + sin(_oscillationPhase * 1.3) * 2.5;
    }
  }

  void _updateAggressive(double dt) {
    final px = game.player?.position.x ?? position.x;
    final dx = (px - position.x).clamp(-_currentSpeed * dt, _currentSpeed * dt);
    position.x += dx;
    position.y += _currentSpeed * dt;
  }

  void activateAggressiveMode() {
    if (_aggressiveMode) return;
    _aggressiveMode = true;
    _hovering       = false;
    _currentSpeed   = baseSpeed * 1.4;
  }

  // ── HP / Death ────────────────────────────────────────────────────────────

  void hit(int damage) {
    hp -= damage;
    if (hp <= 0) {
      // Enforce particle cap
      final pCount = game.children.whereType<ParticleSystemComponent>().length;
      if (pCount < kMaxParticleSystems) {
        game.add(explosionParticles(position.clone()));
      }
      game.audioManager.playSfx('explosion.wav');
      game.onEnemyKilled(scoreValue);
      removeFromParent();
    } else {
      final pCount = game.children.whereType<ParticleSystemComponent>().length;
      if (pCount < kMaxParticleSystems) {
        game.add(sparkParticles(position.clone()));
      }
    }
  }

  // ── Collision with Player ─────────────────────────────────────────────────

  @override
  void onCollisionStart(
    Set<Vector2> intersectionPoints,
    PositionComponent other,
  ) {
    super.onCollisionStart(intersectionPoints, other);
    if (other is Player) {
      game.applyCollisionDamage();
      other.takeDamage(isCollision: true);
      removeFromParent();
    }
  }

  // ── Fire ──────────────────────────────────────────────────────────────────

  double _calculateFireInterval() {
    final w = game.wave;
    if (w <= 2) return 2.0;
    if (w <= 5) return 1.5;
    return 0.8 + _random.nextDouble() * 0.7;
  }

  void _fire() {
    game.add(
      EnemyBullet(position: Vector2(position.x, position.y + size.y / 2)),
    );
  }

  // ── Render ────────────────────────────────────────────────────────────────

  @override
  void render(Canvas canvas) {
    final cx = size.x / 2;
    final cy = size.y / 2;

    // HP ratio (for damaged glow effect)
    final maxHp  = 2 + (game.wave * 0.6).floor();
    final hpRatio = (hp / maxHp).clamp(0.0, 1.0);

    final coreColor = Color.lerp(
      const Color(0xFFFF6D00), // orange (full hp)
      const Color(0xFFFF1744), // red (low hp)
      1.0 - hpRatio,
    )!;

    // ── Outer glow (BlendMode.plus) ───────────────────────────────────────
    canvas.drawPath(
      _buildShipPath(cx, cy),
      Paint()
        ..color = coreColor.withValues(alpha: 0.3)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 9.0
        ..blendMode = BlendMode.plus,
    );

    // ── Body fill ─────────────────────────────────────────────────────────
    canvas.drawPath(
      _buildShipPath(cx, cy),
      Paint()
        ..color = coreColor.withValues(alpha: 0.9),
    );

    // ── Inner highlight ───────────────────────────────────────────────────
    canvas.drawPath(
      _buildShipPath(cx, cy),
      Paint()
        ..color = Colors.white.withValues(alpha: 0.25)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0,
    );

    // ── HP bar (only when damaged) ────────────────────────────────────────
    if (hp < maxHp) {
      final barW  = size.x;
      final filled = hpRatio * barW;
      canvas.drawRect(
        Rect.fromLTWH(0, -8, barW, 4),
        Paint()..color = const Color(0x44FF1744),
      );
      canvas.drawRect(
        Rect.fromLTWH(0, -8, filled, 4),
        Paint()
          ..color = const Color(0xFFFF1744)
          ..blendMode = BlendMode.plus,
      );
    }
  }

  /// Alien craft: diamond with swept wings
  Path _buildShipPath(double cx, double cy) {
    return Path()
      ..moveTo(cx,          0)          // top point (nose)
      ..lineTo(cx + cx * 0.55, cy * 0.7) // right shoulder
      ..lineTo(size.x,     cy)          // right wingtip
      ..lineTo(cx + cx * 0.45, cy * 1.15) // right wing notch
      ..lineTo(cx + cx * 0.3,  size.y) // right tail tip
      ..lineTo(cx,          cy * 1.6)  // center rear notch
      ..lineTo(cx - cx * 0.3,  size.y) // left tail tip
      ..lineTo(cx - cx * 0.45, cy * 1.15) // left wing notch
      ..lineTo(0,          cy)          // left wingtip
      ..lineTo(cx - cx * 0.55, cy * 0.7) // left shoulder
      ..close();
  }
}

// ── Enemy Bullet ─────────────────────────────────────────────────────────────

class EnemyBullet extends PositionComponent
    with HasGameReference<ZeroVectorGame>, CollisionCallbacks {
  static const double _speed  = 260.0;
  static const double _width  = 5.0;
  static const double _height = 14.0;

  EnemyBullet({required Vector2 position})
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
    position.y += _speed * dt;
    if (position.y > game.size.y + _height) removeFromParent();
  }

  @override
  void onCollisionStart(
    Set<Vector2> intersectionPoints,
    PositionComponent other,
  ) {
    super.onCollisionStart(intersectionPoints, other);
    if (other is Player) {
      game.applyBulletDamageToPlayer();
      other.takeDamage(isCollision: false);
      removeFromParent();
    }
  }

  @override
  void render(Canvas canvas) {
    // Glow pass
    canvas.drawOval(
      Rect.fromLTWH(-2, -2, size.x + 4, size.y + 4),
      Paint()
        ..color = const Color(0xFFFF6D00).withValues(alpha: 0.3)
        ..blendMode = BlendMode.plus,
    );
    // Core pill
    canvas.drawOval(
      Rect.fromLTWH(0, 0, size.x, size.y),
      Paint()..color = const Color(0xFFFF6D00),
    );
    // Hot centre
    canvas.drawOval(
      Rect.fromLTWH(1, 1, size.x - 2, size.y - 4),
      Paint()..color = Colors.white.withValues(alpha: 0.6),
    );
  }
}
