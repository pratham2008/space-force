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
    game.audioManager.playSfx('boss_entry.wav');
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

  // Explicit weapon mount relative offsets (relative to own size.x / size.y).
  // These MUST match the render geometry in _buildPaths.
  static const List<double> _mountRelX = [-0.38, -0.18, 0.18, 0.38];

  /// Returns world-space X positions of the active gun mounts.
  List<double> _weaponMountWorldX() {
    return _mountRelX
        .take(_spec.gunCount)
        .map((r) => position.x + size.x * r)
        .toList();
  }

  /// Returns world-space Y of the barrel muzzle tip.
  /// Barrel bottom (muzzle) = local cy + 9 + 10 = cy + 19, but we use +14 as a
  /// mid-barrel compromise to avoid clipping into the player hitbox too early.
  double _barrelMuzzleWorldY() => position.y + size.y / 2 + 14.0;

  void _updateGuns(double dt) {
    _gunTimer += dt;
    if (_gunTimer < _spec.gunInterval) return;
    _gunTimer = 0;

    final mounts  = _weaponMountWorldX();
    final muzzleY = _barrelMuzzleWorldY();
    final portX   = mounts[_gunIndex % mounts.length];
    _gunIndex = (_gunIndex + 1) % mounts.length;

    // Auto-aim: slight tracking toward player X
    final playerX = game.player?.position.x ?? position.x;
    final dx = (playerX - portX).clamp(-80.0, 80.0);
    final vx = dx / (game.size.y / 300.0);

    game.add(EnemyBullet(position: Vector2(portX, muzzleY), velocityX: vx));
    game.audioManager.playSfx('enemy_shoot.wav');
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
    game.audioManager.playSfx('missile_launch.wav');
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
      game.audioManager.playSfx('boss_death.wav');
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

  // ── Static cached paints ─────────────────────────────────────────────────────
  static final Paint _shadowPaint      = Paint()..color = const Color(0xFF05080E);
  static final Paint _hullPaint        = Paint()..color = const Color(0xFF141821);
  static final Paint _armorMidPaint    = Paint()..color = const Color(0xFF1F2A38);
  static final Paint _armorLightPaint  = Paint()..color = const Color(0xFF2A3648);
  static final Paint _armorAccentPaint = Paint()..color = const Color(0xFF243040);
  static final Paint _rimPaint         = Paint()
    ..color = const Color(0xFF00E5FF).withValues(alpha: 0.12)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.0;
  static final Paint _seamPaint        = Paint()
    ..color = Colors.black.withValues(alpha: 0.55)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.2;
  static final Paint _edgePaint        = Paint()
    ..color = Colors.white.withValues(alpha: 0.08)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 0.8;
  static final Paint _cyanVeinPaint    = Paint()
    ..color = const Color(0xFF00E5FF).withValues(alpha: 0.0)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.2
    ..blendMode = BlendMode.plus;
  static final Paint _magentaCorePaint = Paint()
    ..color = const Color(0xFFFF2D95).withValues(alpha: 0.0)
    ..blendMode = BlendMode.plus;
  static final Paint _blackFillPaint   = Paint()..color = Colors.black;
  static final Paint _exhaustPaint     = Paint()
    ..color = const Color(0xFFFF2D95).withValues(alpha: 0.0)
    ..blendMode = BlendMode.plus;

  // ── Per-instance path cache ───────────────────────────────────────────────────
  Path? _cachedHull;
  Path? _cachedUpperArmor;
  Path? _cachedLowerArmor;
  Path? _cachedJaw;
  Path? _cachedCenterPlate;
  Path? _cachedAsymPlate; // asymmetric detail plate (slight offset for realism)
  final List<Rect>  _cachedWeaponBays    = [];
  final List<Rect>  _cachedCannonBarrels = [];
  final List<Path>  _cachedSeams         = [];
  Size? _cachedSize;

  void _buildPaths() {
    final w  = size.x;
    final h  = size.y;
    final cx = w / 2;
    final cy = h / 2;

    _cachedWeaponBays.clear();
    _cachedCannonBarrels.clear();
    _cachedSeams.clear();

    // ── Layer 1: Main hull — perspective trapezoid (narrower top → wider base)
    _cachedHull = Path()
      ..moveTo(cx - w * 0.12, 0)
      ..lineTo(cx + w * 0.12, 0)
      ..lineTo(w * 0.92, h * 0.72)
      ..lineTo(w * 0.75, h)
      ..lineTo(w * 0.25, h)
      ..lineTo(w * 0.08, h * 0.72)
      ..close();

    // ── Layer 2: Upper heavy armor plate
    _cachedUpperArmor = Path()
      ..moveTo(cx - w * 0.10, h * 0.02)
      ..lineTo(cx + w * 0.10, h * 0.02)
      ..lineTo(w * 0.72, h * 0.40)
      ..lineTo(w * 0.28, h * 0.40)
      ..close();

    // ── Layer 3: Lower armor plate (weapon tier)
    _cachedLowerArmor = Path()
      ..moveTo(w * 0.20, h * 0.42)
      ..lineTo(w * 0.80, h * 0.42)
      ..lineTo(w * 0.80, h * 0.62)
      ..lineTo(w * 0.20, h * 0.62)
      ..close();

    // ── Layer 4: Central raised command bridge
    _cachedCenterPlate = Path()
      ..moveTo(cx - w * 0.085, h * 0.08)
      ..lineTo(cx + w * 0.085, h * 0.08)
      ..lineTo(cx + w * 0.06, h * 0.38)
      ..lineTo(cx - w * 0.06, h * 0.38)
      ..close();

    // ── Layer 5: Asymmetric accent plate (starboard side — provides realism)
    _cachedAsymPlate = Path()
      ..moveTo(cx + w * 0.10, h * 0.44)
      ..lineTo(cx + w * 0.32, h * 0.44)
      ..lineTo(cx + w * 0.36, h * 0.60)
      ..lineTo(cx + w * 0.10, h * 0.60)
      ..close();

    // ── Layer 6: Angular lower jaw
    _cachedJaw = Path()
      ..moveTo(cx - w * 0.14, h * 0.62)
      ..lineTo(cx + w * 0.14, h * 0.62)
      ..lineTo(cx + w * 0.09, h * 0.96)
      ..lineTo(cx - w * 0.09, h * 0.96)
      ..close();

    // ── Weapon bays — positions MUST match _mountRelX used in _weaponMountWorldX()
    // Bay center Y = cy - 5, height 18 → top at cy-14, bottom at cy+4
    // Barrel: top cy+9, height 10 → muzzle tip at cy+19
    // _barrelMuzzleWorldY() returns position.y + cy + 14 (midway — conservative)
    for (final relOff in _mountRelX) {
      final bx = cx + w * relOff;
      _cachedWeaponBays.add(Rect.fromCenter(center: Offset(bx, cy - 5), width: 22, height: 18));
      _cachedCannonBarrels.add(Rect.fromLTWH(bx - 3.5, cy + 9, 7, 10));
    }

    // ── Panel seams
    _cachedSeams.add(Path()..moveTo(cx, 0)..lineTo(cx, h * 0.62));
    _cachedSeams.add(Path()..moveTo(w * 0.20, h * 0.40)..lineTo(w * 0.80, h * 0.40));
    _cachedSeams.add(Path()..moveTo(cx - w * 0.10, h * 0.02)..lineTo(w * 0.08, h * 0.72));
    _cachedSeams.add(Path()..moveTo(cx + w * 0.10, h * 0.02)..lineTo(w * 0.92, h * 0.72));
    // Asymmetric panel line (matches asymmetric plate)
    _cachedSeams.add(Path()..moveTo(cx + w * 0.04, h * 0.10)..lineTo(cx + w * 0.22, h * 0.38));

    _cachedSize = Size(w, h);
  }

  @override
  void render(Canvas canvas) {
    if (_cachedSize == null ||
        _cachedSize!.width != size.x ||
        _cachedSize!.height != size.y) {
      _buildPaths();
    }

    final cx  = size.x / 2;
    final cy  = size.y / 2;
    final osc = _oscillationPhase;

    // 0. Drop shadow
    canvas.save();
    canvas.translate(0, 5);
    canvas.drawPath(_cachedHull!, _shadowPaint);
    canvas.restore();

    // 1. Hull — gradient darker top / lighter base
    canvas.drawPath(_cachedHull!,
      Paint()..shader = LinearGradient(
        colors: const [Color(0xFF080B11), Color(0xFF1C2638)],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ).createShader(Rect.fromLTWH(0, 0, size.x, size.y)),
    );

    // 2. Upper armor
    canvas.drawPath(_cachedUpperArmor!, _armorMidPaint);
    canvas.drawPath(_cachedUpperArmor!, _edgePaint);
    canvas.drawPath(_cachedUpperArmor!, _rimPaint);

    // 3. Lower armor
    canvas.drawPath(_cachedLowerArmor!, _armorMidPaint);
    canvas.drawPath(_cachedLowerArmor!, _edgePaint);

    // 4. Command bridge faceplate
    canvas.drawPath(_cachedCenterPlate!, _armorLightPaint);
    canvas.drawPath(_cachedCenterPlate!, _rimPaint);

    // 5. Asymmetric accent plate — subtle offset detail
    canvas.drawPath(_cachedAsymPlate!, _armorAccentPaint);
    canvas.drawPath(_cachedAsymPlate!, _edgePaint);

    // 6. Lower jaw
    canvas.drawPath(_cachedJaw!, _hullPaint);
    canvas.drawPath(_cachedJaw!, _seamPaint);

    // 7. Panel seams
    for (final s in _cachedSeams) {
      canvas.drawPath(s, _seamPaint);
    }

    // 8. Mechanical vents (two clusters on lower armor)
    for (final vx in [cx - size.x * 0.28, cx + size.x * 0.28]) {
      final vy = cy + size.y * 0.06;
      for (int vi = 0; vi < 3; vi++) {
        canvas.drawRect(
          Rect.fromLTWH(vx - 8, vy + vi * 5, 16, 2.5),
          Paint()..color = Colors.black.withValues(alpha: 0.7),
        );
        canvas.drawRect(
          Rect.fromLTWH(vx - 8, vy + vi * 5 + 2, 16, 0.8),
          Paint()..color = const Color(0xFF00E5FF).withValues(alpha: 0.18)..blendMode = BlendMode.plus,
        );
      }
    }

    // 9. Weapon bays + cannon barrels
    for (int i = 0; i < _cachedWeaponBays.length; i++) {
      final bay    = _cachedWeaponBays[i];
      final barrel = _cachedCannonBarrels[i];

      canvas.drawRect(bay, _blackFillPaint);
      canvas.drawRect(
        bay.deflate(3),
        Paint()..color = const Color(0xFF00E5FF).withValues(alpha: 0.48)..blendMode = BlendMode.plus,
      );
      canvas.drawRect(barrel, Paint()..color = const Color(0xFF1A2030));
      canvas.drawRect(barrel, Paint()
        ..color = const Color(0xFF2A3648)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.6);
      // Muzzle tip glow
      canvas.drawRect(
        Rect.fromLTWH(barrel.left + 1.5, barrel.bottom - 2, barrel.width - 3, 2),
        Paint()..color = const Color(0xFF00E5FF).withValues(alpha: 0.6)..blendMode = BlendMode.plus,
      );
    }

    // 10. Cyan energy veins (pulsing)
    final pulseA = 0.30 + 0.20 * sin(osc * 2.5);
    _cyanVeinPaint.color = const Color(0xFF00E5FF).withValues(alpha: pulseA);
    canvas.drawPath(
      Path()
        ..moveTo(cx, size.y * 0.06)
        ..lineTo(cx - size.x * 0.08, size.y * 0.38)
        ..moveTo(cx, size.y * 0.06)
        ..lineTo(cx + size.x * 0.08, size.y * 0.38),
      _cyanVeinPaint,
    );

    // 11. Reactor core — embedded inside command bridge
    final coreAlpha = 0.65 + 0.25 * sin(osc * 3.0);
    final coreR     = 14.0 + 3.0 * sin(osc * 3.0);
    final coreCtr   = Offset(cx, cy * 0.72);
    canvas.drawCircle(coreCtr, coreR + 5, _blackFillPaint);
    canvas.drawCircle(coreCtr, coreR + 3, _hullPaint);
    _magentaCorePaint.color = const Color(0xFFFF2D95).withValues(alpha: coreAlpha);
    canvas.drawCircle(coreCtr, coreR, _magentaCorePaint);
    canvas.drawCircle(coreCtr, coreR * 0.45,
      Paint()..color = Colors.white.withValues(alpha: 0.85)..blendMode = BlendMode.plus);

    // 12. Engine exhaust bays (integrated into hull rear)
    final exhA = 0.5 + 0.25 * sin(osc * 5.0);
    for (final xOff in [-size.x * 0.18, size.x * 0.18]) {
      final ex = Offset(cx + xOff, size.y);
      canvas.drawRect(Rect.fromCenter(center: ex, width: 22, height: 6), _blackFillPaint);
      _exhaustPaint.color = const Color(0xFFFF2D95).withValues(alpha: 0.55 * exhA);
      canvas.drawPath(
        Path()
          ..moveTo(ex.dx - 11, ex.dy)
          ..lineTo(ex.dx, ex.dy + 16)
          ..lineTo(ex.dx + 11, ex.dy)
          ..close(),
        _exhaustPaint..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
      );
      canvas.drawPath(
        Path()
          ..moveTo(ex.dx - 5, ex.dy)
          ..lineTo(ex.dx, ex.dy + 8)
          ..lineTo(ex.dx + 5, ex.dy)
          ..close(),
        Paint()..color = Colors.white.withValues(alpha: 0.6 * exhA)..blendMode = BlendMode.plus,
      );
    }

    // 13. Bottom rim highlight (light-from-below illusion)
    canvas.drawPath(
      _cachedHull!,
      Paint()
        ..color = const Color(0xFF00E5FF).withValues(alpha: 0.06)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );

    _drawHpBar(canvas);
  }

  void _drawHpBar(Canvas canvas) {
    final ratio  = (hp / _maxHp).clamp(0.0, 1.0);
    final barW   = size.x * 0.9;
    final startX = (size.x - barW) / 2;
    canvas.drawRect(Rect.fromLTWH(startX, -16, barW, 6), Paint()..color = Colors.black54);
    final hpColor = Color.lerp(const Color(0xFFFF2D95), const Color(0xFF00E5FF), ratio)!;
    canvas.drawRect(Rect.fromLTWH(startX, -16, barW * ratio, 6), Paint()..color = hpColor);
    canvas.drawRect(
      Rect.fromLTWH(startX, -16, barW, 6),
      Paint()..color = Colors.white.withValues(alpha: 0.25)..style = PaintingStyle.stroke..strokeWidth = 0.8,
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
