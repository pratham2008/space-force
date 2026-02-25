import 'dart:math';
import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import '../zero_vector_game.dart';
import '../effects/particle_effects.dart';
import '../effects/warp_ring_component.dart';
import 'hittable.dart';
import 'player.dart';

// ── Enemy classification ──────────────────────────────────────────────────────
// Keep as an enum for extensibility (future: Boss, Drone, etc.)
enum EnemyType { interceptor, assault }

// ── Fire-state machine ────────────────────────────────────────────────────────
// Prevents burst cooldown and burst gap timers from ever overlapping.
enum _FireState { idle, bursting }

class Enemy extends PositionComponent
    with HasGameReference<ZeroVectorGame>, CollisionCallbacks, Hittable {

  // ── Classification ──────────────────────────────────────────────────────────
  final EnemyType type;
  bool get isAssault => type == EnemyType.assault;

  // ── Base stats ──────────────────────────────────────────────────────────────
  final double baseSpeed;
  final int scoreValue;
  int hp;
  final int wave;

  // ── Hover config ────────────────────────────────────────────────────────────
  final double hoverYFraction;
  static const double _hoverMinFraction = 0.10;

  // ── Movement state ──────────────────────────────────────────────────────────
  double _currentSpeed;
  bool _aggressiveMode = false;
  bool _hovering = false;
  double _hoverTargetY = 0;
  double _oscillationPhase = 0;
  static const double _oscillationAmplitude = 30.0;
  static const double _oscillationSpeed     = 1.8;

  // ── Rotation oscillation ────────────────────────────────────────────────────
  double _rotationPhase = 0;
  static const double _rotationSpeed = 1.0;
  static const double _maxRotation   = 0.14;

  // ── Fire state machine ──────────────────────────────────────────────────────
  //
  // Interceptor: stays in _FireState.idle, fires _idleTimer countdown, then
  //              calls _fireSingle() and resets countdown. Never enters bursting.
  //
  // Assault:     stays _FireState.idle, counts down _cooldownTimer, then enters
  //              _FireState.bursting. While bursting: fires one shot, decrements
  //              _burstShotsLeft, waits _burstGapTimer between each shot. When
  //              _burstShotsLeft reaches 0, returns to _FireState.idle and resets
  //              _cooldownTimer.  The two timers NEVER run simultaneously.
  //
  _FireState _fireState = _FireState.idle;

  // -- Shared: cooldown timer (Interceptor: between shots; Assault: between bursts)
  double _cooldownTimer = 0;

  // -- Assault-only: intra-burst state
  static const int    _burstSize = 3;
  static const double _burstGapSeconds = 0.12;
  int    _burstShotsLeft = 0;
  double _burstGapTimer  = 0;

  final Random _random = Random();

  final bool startAggressive;

  Enemy({
    required Vector2 position,
    required this.type,
    this.baseSpeed    = 120.0,
    this.scoreValue   = 10,
    required this.hp,
    required this.hoverYFraction,
    this.startAggressive = false,
    this.wave = 1,
  })  : _currentSpeed = baseSpeed,
        super(
          position: position,
          size: type == EnemyType.assault
              ? Vector2(68, 62)
              : Vector2(58, 52),
          anchor: Anchor.center,
        );

  @override
  Future<void> onLoad() async {
    await super.onLoad();

    add(RectangleHitbox(
      size: Vector2(size.x * 0.9, size.y * 0.8),
      position: Vector2(size.x * 0.05, size.y * 0.1),
    ));

    // Randomise initial cooldown so enemies in the same wave don't volley together
    _cooldownTimer = _random.nextDouble() * _calculateBurstCooldown();
    _rotationPhase = _random.nextDouble() * 2 * pi;

    game.add(WarpRingComponent(
      position: position.clone(),
      color: const Color(0xFFFF1744),
    ));

    if (startAggressive) {
      _aggressiveMode = true;
      _currentSpeed   = baseSpeed * 1.4;
    } else {
      _oscillationPhase = _random.nextDouble() * 2 * pi;
      final minY = game.size.y * _hoverMinFraction;
      final maxY = game.size.y * hoverYFraction;
      _hoverTargetY = minY + _random.nextDouble() * (maxY - minY);
    }
  }

  // ── Update ──────────────────────────────────────────────────────────────────

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

    // Prevent enemies drifting into player zone
    final ceiling = game.size.y * 0.60;
    if (position.y > ceiling) position.y = ceiling;

    if (position.y > game.size.y + size.y) {
      removeFromParent();
      return;
    }

    _updateFire(dt);
  }

  // ── Fire state machine ──────────────────────────────────────────────────────

  void _updateFire(double dt) {
    if (isAssault) {
      _updateFireAssault(dt);
    } else {
      _updateFireInterceptor(dt);
    }
  }

  /// Simple single-shot fire for interceptors.
  void _updateFireInterceptor(double dt) {
    _cooldownTimer -= dt;
    if (_cooldownTimer <= 0) {
      _cooldownTimer = _calculateInterceptorInterval();
      _fireSingle(velocityX: 0);
    }
  }

  /// Burst-fire state machine for assault class.
  /// Two timers (_cooldownTimer, _burstGapTimer) NEVER tick simultaneously.
  void _updateFireAssault(double dt) {
    switch (_fireState) {
      case _FireState.idle:
        _cooldownTimer -= dt;
        if (_cooldownTimer <= 0) {
          // Transition → bursting
          _fireState      = _FireState.bursting;
          _burstShotsLeft = _burstSize;
          _burstGapTimer  = 0; // fire immediately on first tick in bursting state
        }

      case _FireState.bursting:
        _burstGapTimer -= dt;
        if (_burstGapTimer <= 0 && _burstShotsLeft > 0) {
          // Snapshot player X once at fire moment — no continuous lerping
          final playerX  = game.player?.position.x ?? position.x;
          final dx       = (playerX - position.x).clamp(-60.0, 60.0);
          // Convert horizontal offset to a velocity component at spawn time
          final vx       = dx / (game.size.y / 260.0); // scales with screen height

          _fireSingle(velocityX: vx);
          _burstShotsLeft--;
          _burstGapTimer = _burstGapSeconds;

          if (_burstShotsLeft <= 0) {
            // Burst complete → back to idle, start full cooldown
            _fireState    = _FireState.idle;
            _cooldownTimer = _calculateBurstCooldown();
          }
        }
    }
  }

  // ── Helpers ─────────────────────────────────────────────────────────────────

  double _calculateInterceptorInterval() {
    final w = game.wave;
    double base = 1.8;
    if (w > 2) base = 1.4;
    if (w > 5) base = 1.0;
    if (w > 10) base = 0.7;
    return base + _random.nextDouble() * 0.5;
  }

  /// Burst cooldown scales by wave tier as per spec.
  double _calculateBurstCooldown() {
    final w = game.wave;
    if (w >= 15) return 0.5 + _random.nextDouble() * 0.15;
    if (w >= 10) return 0.8 + _random.nextDouble() * 0.2;
    return 1.2 + _random.nextDouble() * 0.3; // Wave 7–9
  }

  void _fireSingle({required double velocityX}) {
    game.add(EnemyBullet(
      position: Vector2(position.x, position.y + size.y / 2),
      velocityX: velocityX,
    ));
  }

  // ── Movement ────────────────────────────────────────────────────────────────

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
      position.y = _hoverTargetY + sin(_oscillationPhase * 1.3) * 3.0;
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

  // ── HP / Collision ──────────────────────────────────────────────────────────

  @override
  void hit(int damage) {
    hp -= damage;
    if (hp <= 0) {
      final pCount = game.children.whereType<ParticleSystemComponent>().length;
      if (pCount < kMaxParticleSystems) {
        game.add(explosionParticles(position.clone()));
      }
      game.audioManager.playSfx('explosion.wav');
      game.onEnemyKilled(scoreValue, position.clone(), isAssault);
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
      removeFromParent();
    }
  }

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

    if (isAssault) {
      _renderAssault(canvas, cx, cy);
    } else {
      _renderInterceptor(canvas, cx, cy);
    }

    _drawHpBar(canvas);
  }

  void _renderInterceptor(Canvas canvas, double cx, double cy) {
    // ── 1. Slim V-Hull (Base Layer) ──────────────────────────────────────
    final vHull = Path()
      ..moveTo(cx, size.y - 4)                // Rear point
      ..lineTo(cx + 26, 8)                    // Right tip (forward leaning)
      ..lineTo(cx + 10, 0)                    // Right inner nose
      ..lineTo(cx, 12)                        // Center indent
      ..lineTo(cx - 10, 0)                    // Left inner nose
      ..lineTo(cx - 26, 8)                    // Left tip (forward leaning)
      ..close();
    
    canvas.drawPath(vHull, _hullPaint);

    // ── 2. Armor Plating ─────────────────────────────────────────────────
    final armor = Path()
      ..moveTo(cx, size.y - 12)
      ..lineTo(cx + 14, cy)
      ..lineTo(cx, cy + 4)
      ..lineTo(cx - 14, cy)
      ..close();
    canvas.drawPath(armor, _armorPaint);

    // ── 3. Detail Lines ──────────────────────────────────────────────────
    canvas.drawPath(vHull, _linePaint);
    canvas.drawPath(armor, _linePaint);

    // ── 4. Magenta Edge Highlights ───────────────────────────────────────
    final edgePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..color = const Color(0xFFFF2D95).withValues(alpha: 0.7)
      ..blendMode = BlendMode.plus;
    canvas.drawLine(Offset(cx + 24, 10), Offset(cx + 10, 2), edgePaint);
    canvas.drawLine(Offset(cx - 24, 10), Offset(cx - 10, 2), edgePaint);

    // ── 5. Cyan Targeting Eye (Center) ──────────────────────────────────
    canvas.drawCircle(Offset(cx, cy - 6), 4, Paint()..color = const Color(0xFF08121A));
    canvas.drawCircle(Offset(cx, cy - 6), 3, _cyanGlowPaint);
    canvas.drawCircle(Offset(cx, cy - 6), 1, Paint()..color = Colors.white..blendMode = BlendMode.plus);

    // ── 6. Small Glowing Vents (Cyan) ─────────────────────────────────────
    canvas.drawRect(Rect.fromLTWH(cx - 16, cy + 4, 3, 1.5), _cyanGlowPaint);
    canvas.drawRect(Rect.fromLTWH(cx + 13, cy + 4, 3, 1.5), _cyanGlowPaint);

    // ── 7. Engine Exhaust ────────────────────────────────────────────────
    _drawCyberExhaustSingle(canvas, Offset(cx, size.y - 4), 8, 14, const Color(0xFFFF2D95));
  }

  void _renderAssault(Canvas canvas, double cx, double cy) {
    // ── 1. Brutalist Wide Hull (Base Layer) ──────────────────────────────
    final wideHull = Path()
      ..moveTo(cx, 0)                         // Sharp nose
      ..lineTo(cx + 32, cy - 4)               // Right shoulder
      ..lineTo(cx + 28, size.y)               // Right rear
      ..lineTo(cx - 28, size.y)               // Left rear
      ..lineTo(cx - 32, cy - 4)               // Left shoulder
      ..close();
    
    canvas.drawPath(wideHull, _hullPaint);

    // ── 2. Top Secondary Armor ───────────────────────────────────────────
    final armor = Path()
      ..moveTo(cx, 10)
      ..lineTo(cx + 20, cy)
      ..lineTo(cx + 16, size.y - 8)
      ..lineTo(cx - 16, size.y - 8)
      ..lineTo(cx - 20, cy)
      ..close();
    canvas.drawPath(armor, _armorPaint);

    // ── 3. Visible Dual Cannon Pods ──────────────────────────────────────
    final podPaint = Paint()..color = const Color(0xFF0D1016);
    canvas.drawRect(Rect.fromLTWH(cx - 30, cy - 8, 8, 16), podPaint);
    canvas.drawRect(Rect.fromLTWH(cx + 22, cy - 8, 8, 16), podPaint);
    
    // Magenta cannon glow
    canvas.drawRect(Rect.fromLTWH(cx - 28, cy - 10, 4, 2), _magentaGlowPaint);
    canvas.drawRect(Rect.fromLTWH(cx + 24, cy - 10, 4, 2), _magentaGlowPaint);

    // ── 4. Cyan Reactor Vents (Rear) ──────────────────────────────────────
    canvas.drawRect(Rect.fromLTWH(cx - 12, size.y - 6, 8, 2), _cyanGlowPaint);
    canvas.drawRect(Rect.fromLTWH(cx + 4, size.y - 6, 8, 2), _cyanGlowPaint);

    // ── 5. Detail Paneling & Neon Accents ────────────────────────────────
    canvas.drawPath(wideHull, _linePaint);
    // Neon accent lines at wing roots
    final neonCyan = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0
      ..color = const Color(0xFF00E5FF).withValues(alpha: 0.6)
      ..blendMode = BlendMode.plus;
    canvas.drawLine(Offset(cx - 18, cy + 4), Offset(cx - 26, cy + 18), neonCyan);
    canvas.drawLine(Offset(cx + 18, cy + 4), Offset(cx + 26, cy + 18), neonCyan);

    // ── 6. Engine Exhaust ────────────────────────────────────────────────
    _drawCyberExhaustSingle(canvas, Offset(cx, size.y - 2), 12, 18, const Color(0xFF00E5FF));
  }

  void _drawCyberExhaustSingle(Canvas canvas, Offset top, double w, double h, Color baseColor) {
    final speedFactor = _aggressiveMode ? 1.4 : 1.0;
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
    final maxHp = _maxHp;
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
      Paint()..color = const Color(0xFFFF2D95), // Magenta HP bar for enemies
    );
  }

  int get _maxHp => 2 + (wave * 0.6).floor();
}

// ── Enemy Bullet ──────────────────────────────────────────────────────────────
// velocityX: horizontal drift calculated ONCE at fire moment (predictive aim).
// No continuous trajectory updates — the value is constant for the bullet's life.

class EnemyBullet extends PositionComponent
    with HasGameReference<ZeroVectorGame>, CollisionCallbacks {

  static const double _speedY = 260.0;
  static const double _width  = 5.0;
  static const double _height = 14.0;

  final double velocityX;

  EnemyBullet({
    required Vector2 position,
    this.velocityX = 0,
  }) : super(
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
    position.x += velocityX * dt;   // constant horizontal component set at birth
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
    // Outer glow
    canvas.drawOval(
      Rect.fromLTWH(-2, -2, size.x + 4, size.y + 4),
      Paint()
        ..color = const Color(0xFFFF1744).withValues(alpha: 0.3)
        ..blendMode = BlendMode.plus,
    );
    // Core pill
    canvas.drawOval(
      Rect.fromLTWH(0, 0, size.x, size.y),
      Paint()..color = const Color(0xFFFF1744),
    );
    // Hot centre
    canvas.drawOval(
      Rect.fromLTWH(1, 1, size.x - 2, size.y - 4),
      Paint()..color = Colors.white.withValues(alpha: 0.6),
    );
  }
}
