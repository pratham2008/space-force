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

// ── Boss loadout by wave ──────────────────────────────────────────────────────

class _BossSpec {
  final int hp;
  final int gunCount;
  final int missilePodCount;
  final double gunInterval;
  final double missileInterval;
  const _BossSpec({
    required this.hp,
    required this.gunCount,
    required this.missilePodCount,
    required this.gunInterval,
    required this.missileInterval,
  });
}

const _bossSpecs = {
  10: _BossSpec(hp: 2500, gunCount: 4, missilePodCount: 2, gunInterval: 0.8, missileInterval: 5.0),
  20: _BossSpec(hp: 4500, gunCount: 4, missilePodCount: 3, gunInterval: 0.55, missileInterval: 3.5),
  30: _BossSpec(hp: 8000, gunCount: 4, missilePodCount: 4, gunInterval: 0.4,  missileInterval: 2.0),
};

// ── Boss component ────────────────────────────────────────────────────────────

class Boss extends PositionComponent
    with HasGameReference<ZeroVectorGame>, CollisionCallbacks, Hittable {

  final int bossWave;
  late int hp;
  late int _maxHp;
  late _BossSpec _spec;

  // ── Movement ─────────────────────────────────────────────────────────────────
  static const double _entrySpeed = 60.0;
  double _hoverTargetY = 0;
  bool _hovering = false;
  double _oscillationPhase = 0;
  static const double _oscillationAmplitude = 30.0;

  // ── Fire state ───────────────────────────────────────────────────────────────
  double _gunTimer    = 0;
  double _missileTimer = 0;
  int    _gunIndex    = 0; // cycles through gun ports in order

  final Random _random = Random();

  // Boss covers 30% of screen height
  static const double _heightFraction = 0.30;

  Boss({required this.bossWave, required Vector2 position})
      : super(position: position, anchor: Anchor.center);

  @override
  Future<void> onLoad() async {
    await super.onLoad();

    _spec   = _bossSpecs[bossWave] ?? _bossSpecs[10]!;
    _maxHp  = _spec.hp;
    hp      = _maxHp;

    size = Vector2(game.size.y * _heightFraction * 1.5, game.size.y * _heightFraction);

    add(RectangleHitbox(
      size: Vector2(size.x * 0.88, size.y * 0.75),
      position: Vector2(size.x * 0.06, size.y * 0.13),
      collisionType: CollisionType.active,
    ));

    _hoverTargetY = game.size.y * 0.22;
    _oscillationPhase = _random.nextDouble() * 2 * pi;

    game.add(WarpRingComponent(
      position: position.clone(),
      color: const Color(0xFFFF1744),
    ));
  }

  // ── Update ───────────────────────────────────────────────────────────────────

  @override
  void update(double dt) {
    super.update(dt);
    _oscillationPhase += 0.7 * dt;

    if (!_hovering) {
      position.y += _entrySpeed * dt;
      if (position.y >= _hoverTargetY) {
        position.y = _hoverTargetY;
        _hovering   = true;
      }
      return; // Don't fire while entering
    }

    // Slow side-to-side oscillation
    position.x += sin(_oscillationPhase) * _oscillationAmplitude * dt;
    position.x  = position.x.clamp(size.x / 2, game.size.x - size.x / 2);

    _updateGuns(dt);
    _updateMissiles(dt);
  }

  // ── Fire ─────────────────────────────────────────────────────────────────────

  void _updateGuns(double dt) {
    _gunTimer += dt;
    if (_gunTimer < _spec.gunInterval) return;
    _gunTimer = 0;

    // Cycle through guns in order for a rhythmic feel
    final cx = position.x;
    final cy = position.y + size.y / 2;
    final ports = _gunPorts(cx);
    final portX  = ports[_gunIndex % ports.length];
    _gunIndex = (_gunIndex + 1) % ports.length;

    // Auto-aim: predict player X at travel time
    final playerX = game.player?.position.x ?? cx;
    final dx = (playerX - portX).clamp(-80.0, 80.0);
    final vx = dx / (game.size.y / 300.0);

    game.add(EnemyBullet(position: Vector2(portX, cy), velocityX: vx));
    game.audioManager.playSfx('enemy_shoot.wav');
  }

  List<double> _gunPorts(double cx) {
    const offsets = [-0.38, -0.18, 0.18, 0.38];
    return offsets.take(_spec.gunCount).map((o) => cx + size.x * o).toList();
  }

  void _updateMissiles(double dt) {
    _missileTimer += dt;
    if (_missileTimer < _spec.missileInterval) return;
    _missileTimer = 0;

    final player = game.player;
    if (player == null) return;

    // Fire from each missile pod
    final podOffsets = _missilePodOffsets();
    final cy = position.y + size.y / 2;

    for (final ox in podOffsets) {
      final spawnPos = Vector2(position.x + ox, cy);
      final rawDir   = player.position - spawnPos;
      final direction = rawDir.length > 0.001 ? (rawDir..normalize()) : Vector2(0, 1);

      game.add(MissileProjectile(
        position: spawnPos,
        damage: 100, // Boss missiles always 100
        direction: direction,
      ));
    }
    game.audioManager.playSfx('enemy_shoot.wav');
  }

  List<double> _missilePodOffsets() {
    // Distribute pods symmetrically
    switch (_spec.missilePodCount) {
      case 2: return [size.x * -0.3, size.x * 0.3];
      case 3: return [size.x * -0.35, 0, size.x * 0.35];
      case 4: return [size.x * -0.38, size.x * -0.15, size.x * 0.15, size.x * 0.38];
      default: return [0];
    }
  }

  // ── Hittable ─────────────────────────────────────────────────────────────────

  @override
  void hit(int damage) {
    hp -= damage;
    if (hp <= 0) {
      // Boss death — big explosion sequence
      final pCount = game.children.whereType<ParticleSystemComponent>().length;
      if (pCount < kMaxParticleSystems) {
        game.add(explosionParticles(position.clone()));
      }
      game.audioManager.playSfx('explosion.wav');
      game.shake(intensity: 15, duration: 0.8);
      game.onBossKilled(position.clone(), bossWave);
      removeFromParent();
    } else {
      final pCount = game.children.whereType<ParticleSystemComponent>().length;
      if (pCount < kMaxParticleSystems) {
        game.add(sparkParticles(position.clone()));
      }
    }
  }

  // ── Collision ────────────────────────────────────────────────────────────────

  @override
  void onCollisionStart(Set<Vector2> intersectionPoints, PositionComponent other) {
    super.onCollisionStart(intersectionPoints, other);
    if (other is Player) {
      game.applyCollisionDamage();
      other.takeDamage(isCollision: true);
      // Boss does NOT die from collision
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

    // ── 1. Brutalist Broad Hull (Base Layer) ────────────────────────────
    final hull = Path()
      ..moveTo(cx, 10)                         // Nose
      ..lineTo(size.x - 20, cy * 0.4)          // Outward shoulder R
      ..lineTo(size.x, cy)                     // Far right tip
      ..lineTo(size.x * 0.85, size.y)          // Rear R
      ..lineTo(cx + 40, size.y - 15)           // Engine bay indent R
      ..lineTo(cx, size.y - 5)                 // Central rear bay
      ..lineTo(cx - 40, size.y - 15)           // Engine bay indent L
      ..lineTo(size.x * 0.15, size.y)          // Rear L
      ..lineTo(0, cy)                          // Far left tip
      ..lineTo(20, cy * 0.4)                   // Outward shoulder L
      ..close();
    
    canvas.drawPath(hull, _hullPaint);

    // ── 2. Massive Armor Plating Layers ──────────────────────────────────
    final centerPlate = Path()
      ..moveTo(cx - 60, cy - 20)
      ..lineTo(cx + 60, cy - 20)
      ..lineTo(cx + 40, cy + 20)
      ..lineTo(cx - 40, cy + 20)
      ..close();
    canvas.drawPath(centerPlate, _armorPaint);

    final wingPlateR = Path()
      ..moveTo(cx + 70, cy - 10)
      ..lineTo(size.x - 20, cy + 5)
      ..lineTo(size.x - 40, cy + 25)
      ..lineTo(cx + 60, cy + 15)
      ..close();
    canvas.drawPath(wingPlateR, _armorPaint);

    final wingPlateL = Path()
      ..moveTo(cx - 70, cy - 10)
      ..lineTo(20, cy + 5)
      ..lineTo(40, cy + 25)
      ..lineTo(cx - 60, cy + 15)
      ..close();
    canvas.drawPath(wingPlateL, _armorPaint);

    // ── 3. Cyan Energy Veins & Pulse ─────────────────────────────────────
    final vPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..color = const Color(0xFF00E5FF).withValues(alpha: 0.45)
      ..blendMode = BlendMode.plus;
    
    canvas.drawPath(
      Path()
        ..moveTo(cx, 20)
        ..lineTo(cx - 80, cy - 5)
        ..moveTo(cx, 20)
        ..lineTo(cx + 80, cy - 5),
      vPaint,
    );

    final pulseT = (sin(_oscillationPhase * 2.0) + 1) / 2;
    canvas.drawCircle(Offset(cx - 80 * pulseT, 20 + (cy - 25) * pulseT), 3, _cyanGlowPaint..color = const Color(0xFF00E5FF).withValues(alpha: 0.7 * pulseT));
    canvas.drawCircle(Offset(cx + 80 * pulseT, 20 + (cy - 25) * pulseT), 3, _cyanGlowPaint);

    // ── 4. Pulsing Magenta Power Reactor ──────────────────────────────────
    final coreAlpha = 0.6 + 0.3 * sin(_oscillationPhase * 3.0);
    final coreSize = 36.0 + 6.0 * sin(_oscillationPhase * 3.0);
    final coreRect = Rect.fromCenter(center: Offset(cx, cy), width: coreSize, height: coreSize);
    
    canvas.drawOval(coreRect, Paint()..color = const Color(0xFF0D0204));
    canvas.drawOval(coreRect, _magentaGlowPaint..color = const Color(0xFFFF2D95).withValues(alpha: coreAlpha));
    canvas.drawCircle(Offset(cx, cy), coreSize * 0.45, Paint()..color = Colors.white.withValues(alpha: 0.75)..blendMode = BlendMode.plus);

    // ── 5. Weapon Port Glow (Cyan) ────────────────────────────────────────
    for (final ox in _gunPorts(cx)) {
      final lx = ox - position.x + cx;
      canvas.drawRect(Rect.fromLTWH(lx - 5, cy - 15, 10, 3), _cyanGlowPaint);
    }

    // ── 6. Engine Exhausts (Heavy Multi-Vent) ─────────────────────────────
    for (final xOff in [-80.0, -40.0, 40.0, 80.0]) {
      _drawCyberExhaustSingle(canvas, Offset(cx + xOff, size.y - 15), 16, 24, const Color(0xFFFF2D95));
    }

    // ── 7. Detail Lines ──────────────────────────────────────────────────
    canvas.drawPath(hull, _linePaint);
    canvas.drawPath(centerPlate, _linePaint);
    canvas.drawPath(wingPlateR, _linePaint);
    canvas.drawPath(wingPlateL, _linePaint);

    // ── 8. HP Bar ────────────────────────────────────────────────────────
    _drawHpBar(canvas);
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
    final ratio  = (hp / _maxHp).clamp(0.0, 1.0);
    final barW   = size.x * 0.9;
    final startX = (size.x - barW) / 2;
    canvas.drawRect(Rect.fromLTWH(startX, -16, barW, 6), Paint()..color = Colors.black54);
    
    // HP transitions from cyan/green to red-magenta
    final hpColor = Color.lerp(const Color(0xFFFF2D95), const Color(0xFF00E5FF), ratio)!;
    
    canvas.drawRect(
      Rect.fromLTWH(startX, -16, barW * ratio, 6),
      Paint()..color = hpColor,
    );

    // HP bar border
    canvas.drawRect(
      Rect.fromLTWH(startX, -16, barW, 6),
      _linePaint,
    );
  }
}

/// Lightweight auto-aim bullet used by Boss machine guns.
class EnemyBullet extends PositionComponent
    with HasGameReference<ZeroVectorGame>, CollisionCallbacks {

  static const double _speedY = 320.0;
  static const double _width  = 5.0;
  static const double _height = 16.0;

  final double velocityX;

  EnemyBullet({required Vector2 position, this.velocityX = 0})
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
    position.x += velocityX * dt;
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
