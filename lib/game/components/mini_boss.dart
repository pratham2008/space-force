import 'dart:math';
import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import '../zero_vector_game.dart';
import '../effects/particle_effects.dart';
import '../effects/warp_ring_component.dart';
import 'hittable.dart';
import 'player.dart';
import 'missile_projectile.dart';
import 'missile_lock_reticle.dart';



class MiniBoss extends PositionComponent
    with HasGameReference<ZeroVectorGame>, CollisionCallbacks, Hittable {

  final int wave;
  int hp;

  // ── Movement ────────────────────────────────────────────────────────────────
  static const double _entrySpeed  = 80.0;
  static const double _oscillationAmplitude = 40.0;
  double _hoverTargetY = 0;
  bool _hovering = false;
  double _oscillationPhase = 0;

  // ── Fire ────────────────────────────────────────────────────────────────────
  double _gunTimer   = 0;
  double _missileTimer = 0;
  bool _missileReticleActive = false;
  final Random _random = Random();

  double get _gunInterval   => (1.8 - wave * 0.04).clamp(0.4, 1.8);
  double get _missileInterval => (6.0 - wave * 0.1).clamp(2.5, 6.0);

  MiniBoss({required this.wave, required this.hp, required Vector2 position})
      : super(
          position: position,
          size: Vector2.zero(), // sized in onLoad based on screen
          anchor: Anchor.center,
        );

  @override
  Future<void> onLoad() async {
    await super.onLoad();

    // Size: 22% of screen height, proportional width
    size = Vector2(game.size.y * 0.22 * 1.4, game.size.y * 0.22);

    add(RectangleHitbox(
      size: Vector2(size.x * 0.85, size.y * 0.8),
      position: Vector2(size.x * 0.075, size.y * 0.1),
    ));

    _hoverTargetY = game.size.y * 0.25;
    _oscillationPhase = _random.nextDouble() * 2 * pi;

    game.add(WarpRingComponent(
      position: position.clone(),
      color: const Color(0xFFFF1744),
    ));
  }

  // ── Update ──────────────────────────────────────────────────────────────────

  @override
  void update(double dt) {
    super.update(dt);
    _oscillationPhase += 1.0 * dt;

    if (!_hovering) {
      position.y += _entrySpeed * dt;
      if (position.y >= _hoverTargetY) {
        position.y = _hoverTargetY;
        _hovering = true;
      }
    } else {
      position.x += sin(_oscillationPhase) * _oscillationAmplitude * dt;
      position.x = position.x.clamp(size.x / 2, game.size.x - size.x / 2);
    }

    if (!_hovering) return;

    // ── Machine gun (2 ports) ──────────────────────────────────────────────
    _gunTimer += dt;
    if (_gunTimer >= _gunInterval) {
      _gunTimer = 0;
      _fireGuns();
    }

    // ── Missile (1 launcher) ──────────────────────────────────────────────
    _missileTimer += dt;
    if (_missileTimer >= _missileInterval && !_missileReticleActive) {
      _missileTimer = 0;
      _missileReticleActive = true;
      game.add(MissileLockReticle(onLockComplete: _onMissileLockComplete));
    }
  }

  void _fireGuns() {
    final cx = position.x;
    final cy = position.y + size.y / 2;
    final offset = size.x * 0.35;

    // Two gun ports
    for (final x in [cx - offset, cx + offset]) {
      game.add(EnemyBulletMiniBoss(position: Vector2(x, cy)));
    }
    game.audioManager.playSfx('enemy_shoot.wav');
  }

  void _onMissileLockComplete() {
    _missileReticleActive = false;
    final player = game.player;
    if (player == null) return;
    final spawnPos  = Vector2(position.x, position.y + size.y / 2);
    final rawDir    = player.position - spawnPos; // Capture at fire time
    final direction = rawDir.length > 0.001
        ? (rawDir..normalize())
        : Vector2(0, 1);
    game.add(MissileProjectile(
      position: spawnPos,
      damage: missileWaveDamage(wave),
      direction: direction,
    ));
    game.audioManager.playSfx('enemy_shoot.wav');
  }

  // ── Collision/Damage ────────────────────────────────────────────────────────

  @override
  void hit(int damage) {
    hp -= damage;
    if (hp <= 0) {
      final pCount = game.children.whereType<ParticleSystemComponent>().length;
      if (pCount < kMaxParticleSystems) {
        game.add(explosionParticles(position.clone()));
      }
      game.audioManager.playSfx('explosion.wav');
      game.onMiniBossKilled(position.clone(), wave);
      removeFromParent();
    } else {
      final pCount = game.children.whereType<ParticleSystemComponent>().length;
      if (pCount < kMaxParticleSystems) {
        game.add(sparkParticles(position.clone()));
      }
    }
  }

  @override
  void onCollisionStart(Set<Vector2> intersectionPoints, PositionComponent other) {
    super.onCollisionStart(intersectionPoints, other);
    if (other is Player) {
      game.applyCollisionDamage();
      other.takeDamage(isCollision: true);
    }
  }

  // ── Render ──────────────────────────────────────────────────────────────────

  // ── Render ──────────────────────────────────────────────────────────────────

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

    // ── 1. Brutalist Angular Hull (Base Layer) ──────────────────────────
    final hull = Path()
      ..moveTo(cx, 0)                         // Nose
      ..lineTo(cx + cx * 0.75, cy * 0.5)      // Top shoulder R
      ..lineTo(size.x, cy)                    // Wing tip R
      ..lineTo(cx + cx, size.y)               // Rear flare R
      ..lineTo(cx + cx * 0.3, size.y - 10)    // Rear inner R
      ..lineTo(cx, size.y - 20)               // Engine bay
      ..lineTo(cx - cx * 0.3, size.y - 10)    // Rear inner L
      ..lineTo(cx - cx, size.y)               // Rear flare L
      ..lineTo(0, cy)                         // Wing tip L
      ..lineTo(cx - cx * 0.75, cy * 0.5)      // Top shoulder L
      ..close();
    
    canvas.drawPath(hull, _hullPaint);

    // ── 2. Multi-Layer Armor Plating ─────────────────────────────────────
    final armor1 = Path()
      ..moveTo(cx, 15)
      ..lineTo(cx + 40, cy)
      ..lineTo(cx, cy + 15)
      ..lineTo(cx - 40, cy)
      ..close();
    canvas.drawPath(armor1, _armorPaint);

    final armor2 = Path()
      ..moveTo(cx - 30, cy + 20)
      ..lineTo(cx + 30, cy + 20)
      ..lineTo(cx + 20, size.y - 15)
      ..lineTo(cx - 20, size.y - 15)
      ..close();
    canvas.drawPath(armor2, _armorPaint);

    // ── 3. HP bar (Moved up for clarity) ─────────────────────────────────
    _drawHpBar(canvas);

    // ── 4. Cyan Energy Veins (Branching) ─────────────────────────────────
    final vPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..color = const Color(0xFF00E5FF).withValues(alpha: 0.4)
      ..blendMode = BlendMode.plus;
    
    // Main veins
    canvas.drawLine(Offset(cx, 10), Offset(cx - 25, cy - 10), vPaint);
    canvas.drawLine(Offset(cx, 10), Offset(cx + 25, cy - 10), vPaint);
    canvas.drawLine(Offset(cx - 25, cy - 10), Offset(cx - 50, cy + 10), vPaint);
    canvas.drawLine(Offset(cx + 25, cy - 10), Offset(cx + 50, cy + 10), vPaint);

    // Animated pulse along veins
    final pulseT = (sin(_oscillationPhase * 2.5) + 1) / 2;
    final pulsePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..color = const Color(0xFF00E5FF).withValues(alpha: 0.6 * pulseT)
      ..blendMode = BlendMode.plus;
    
    canvas.drawCircle(Offset(cx - 25 + 25 * pulseT, cy - 10 - 20 * pulseT), 2, pulsePaint);
    canvas.drawCircle(Offset(cx + 25 - 25 * pulseT, cy - 10 - 20 * pulseT), 2, pulsePaint);

    // ── 5. Magenta Power Core (Pulsing) ──────────────────────────────────
    final coreAlpha = 0.5 + 0.3 * sin(_oscillationPhase * 2.0);
    final coreSize = 24.0 + 4.0 * sin(_oscillationPhase * 2.0);
    final coreRect = Rect.fromCenter(center: Offset(cx, cy), width: coreSize, height: coreSize);
    
    canvas.drawOval(coreRect, Paint()..color = const Color(0xFF0D0204));
    canvas.drawOval(coreRect, _magentaGlowPaint..color = const Color(0xFFFF2D95).withValues(alpha: coreAlpha));
    canvas.drawCircle(Offset(cx, cy), coreSize * 0.4, Paint()..color = Colors.white.withValues(alpha: 0.6)..blendMode = BlendMode.plus);

    // ── 6. Weapon Mount Glow ─────────────────────────────────────────────
    final gunX = size.x * 0.35;
    canvas.drawRect(Rect.fromLTWH(cx - gunX - 4, cy - 5, 8, 2), _cyanGlowPaint);
    canvas.drawRect(Rect.fromLTWH(cx + gunX - 4, cy - 5, 8, 2), _cyanGlowPaint);

    // ── 7. Engine Exhausts ──────────────────────────────────────────────
    _drawCyberExhaustSingle(canvas, Offset(cx - 20, size.y - 12), 12, 18, const Color(0xFFFF2D95));
    _drawCyberExhaustSingle(canvas, Offset(cx + 20, size.y - 12), 12, 18, const Color(0xFFFF2D95));

    // ── 8. Detail Paneling ──────────────────────────────────────────────
    canvas.drawPath(hull, _linePaint);
    canvas.drawPath(armor1, _linePaint);
    canvas.drawPath(armor2, _linePaint);
  }

  void _drawCyberExhaustSingle(Canvas canvas, Offset top, double w, double h, Color baseColor) {
    final glow = Path()
      ..moveTo(top.dx - w / 2, top.dy)
      ..lineTo(top.dx, top.dy + h)
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
      ..lineTo(top.dx, top.dy + h * 0.5)
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
    final maxHp = _maxHp();
    final ratio  = (hp / maxHp).clamp(0.0, 1.0);
    final barW   = size.x * 0.85;
    final startX = (size.x - barW) / 2;
    canvas.drawRect(Rect.fromLTWH(startX, -12, barW, 4), Paint()..color = Colors.black45);
    canvas.drawRect(Rect.fromLTWH(startX, -12, barW * ratio, 4),
        Paint()..color = const Color(0xFFFF2D95));
  }

  int _maxHp() {
    if (wave <= 12) return 600;
    if (wave <= 18) return 900;
    return 1200;
  }
}

/// Lightweight bullet fired by MiniBoss machine guns (faster, slightly different visual)
class EnemyBulletMiniBoss extends PositionComponent
    with HasGameReference<ZeroVectorGame>, CollisionCallbacks {

  static const double _speedY = 300.0;
  static const double _width  = 5.0;
  static const double _height = 16.0;

  EnemyBulletMiniBoss({required Vector2 position})
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
    position.y += _speedY * dt;
    if (position.y > game.size.y + _height) removeFromParent();
  }

  @override
  void onCollisionStart(Set<Vector2> intersectionPoints, PositionComponent other) {
    super.onCollisionStart(intersectionPoints, other);
    if (other is Player) {
      game.applyBulletDamageToPlayer();
      other.takeDamage(isCollision: false);
      removeFromParent();
    }
  }

  @override
  void render(Canvas canvas) {
    canvas.drawOval(
      Rect.fromLTWH(-2, -2, _width + 4, _height + 4),
      Paint()
        ..color = const Color(0xFFFF1744).withValues(alpha: 0.35)
        ..blendMode = BlendMode.plus,
    );
    canvas.drawOval(
      Rect.fromLTWH(0, 0, _width, _height),
      Paint()..color = const Color(0xFFFF4444),
    );
    canvas.drawOval(
      Rect.fromLTWH(1, 1, _width - 2, _height - 4),
      Paint()..color = Colors.white.withValues(alpha: 0.5),
    );
  }
}
