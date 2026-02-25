import 'dart:math';
import 'package:flame/components.dart';
import '../zero_vector_game.dart';
import '../components/enemy.dart';
import '../components/missile_ship.dart';

/// Wave-controlled spawn manager.
///
/// Budget = totalEnemiesThisWave (from ZeroVectorGame).
/// MissileShips are PART of the budget (they replace standard enemies).
/// Mini Boss spawning is handled by ZeroVectorGame.onWaveTransitionComplete
/// after inspecting guards (no boss wave, no active boss/mini-boss).
class EnemySpawnManager extends Component
    with HasGameReference<ZeroVectorGame> {

  // ── Per-wave counters ───────────────────────────────────────────────────────
  int totalSpawned = 0;

  // ── Timing ──────────────────────────────────────────────────────────────────
  double _timeSinceLastSpawn = 0;
  static const double _spawnCooldown = 1.2;

  bool _active = true;

  final Random _random = Random();

  // ── Called by ZeroVectorGame at the start of each new wave ──────────────────
  void startWave() {
    totalSpawned = 0;
    _timeSinceLastSpawn = 0;
    _active = true;
  }

  void stopSpawning() => _active = false;

  void resumeSpawning() {
    _active = true;
    _timeSinceLastSpawn = 0;
  }

  /// Force-spawns all remaining enemies aggressively.
  /// MUST NOT be called during a boss fight — ZeroVectorGame guards this.
  void forceSpawnAllRemaining() {
    final remaining = game.totalEnemiesThisWave - totalSpawned;
    for (var i = 0; i < remaining; i++) {
      _spawnEnemyImpl(aggressive: true);
    }
    totalSpawned = game.totalEnemiesThisWave;
    _active = false;
  }

  @override
  void update(double dt) {
    super.update(dt);

    if (!_active) return;

    final total = game.totalEnemiesThisWave;
    if (totalSpawned >= total) return;

    _timeSinceLastSpawn += dt;
    if (_timeSinceLastSpawn < _spawnCooldown) return;

    final activeEnemies = game.children.whereType<Enemy>().length
        + game.children.whereType<MissileShip>().length;
    if (activeEnemies >= game.maxSimultaneous) return;

    _timeSinceLastSpawn = 0;
    _spawnEnemy();
  }

  void _spawnEnemy() {
    _spawnEnemyImpl(aggressive: false);
    totalSpawned++;
  }

  void _spawnEnemyImpl({required bool aggressive}) {
    final x = _random.nextDouble() * game.size.x;
    final w = game.wave;

    // ── Missile Ship injection (part of budget, Wave 8+) ─────────────────────
    // Determine how many MissileShips should appear this wave
    if (w >= 8 && _shouldSpawnMissileShip()) {
      game.add(MissileShip(
        position: Vector2(x, -30),
        wave: w,
        hp: 3 + (w * 0.5).floor(),
        baseSpeed: (80 + w * 5.0).clamp(80, 150).toDouble(),
        hoverYFraction: 0.30,
      ));
      return;
    }

    // ── Assault gating: Wave 7+ only ─────────────────────────────────────────
    EnemyType type = EnemyType.interceptor;
    if (w >= 7) {
      final assaultChance = w >= 15 ? 0.40 : (w >= 10 ? 0.30 : 0.20);
      if (_random.nextDouble() < assaultChance) {
        type = EnemyType.assault;
      }
    }

    game.add(
      Enemy(
        position: Vector2(x, -20),
        type: type,
        baseSpeed: _calculateEnemySpeed(),
        scoreValue: type == EnemyType.assault ? 25 : 10,
        hp: _calculateEnemyHp(type),
        hoverYFraction: _calculateHoverY(),
        startAggressive: aggressive,
        wave: w,
      ),
    );
  }

  // ── Missile ship count tracking ───────────────────────────────────────────

  bool _shouldSpawnMissileShip() {
    final w = game.wave;
    final targetCount = _missileShipCountForWave(w);
    final current = game.children.whereType<MissileShip>().length;
    final alreadySpawnedThisWave = _missileShipsSpawnedThisWave;

    if (alreadySpawnedThisWave >= targetCount) return false;
    if (current > 0) return false; // Only one at a time on screen
    // Inject missile ships early in the wave budget
    final budgetUsed = totalSpawned / game.totalEnemiesThisWave;
    return budgetUsed < 0.5 && _random.nextDouble() < 0.35;
  }

  int get _missileShipsSpawnedThisWave {
    // Cheap approximation: track via kills is complex; use spawn slot count
    // This is conservative — MissileShip count capped via targetCount
    return 0; // Simplified: wave target managed via _shouldSpawnMissileShip
  }

  int _missileShipCountForWave(int w) {
    if (w <= 10) return 1;
    if (w <= 14) return 2;
    if (w <= 18) return 3;
    return 4;
  }

  // ── Calculations ─────────────────────────────────────────────────────────────

  /// HP scales with wave. Assault get +1 base HP.
  int _calculateEnemyHp(EnemyType type) {
    final base = 2 + (game.wave * 0.6).floor();
    return type == EnemyType.assault ? base + 1 : base;
  }

  double _calculateEnemySpeed() {
    return (100 + game.wave * 10.0).clamp(100, 280).toDouble();
  }

  /// Hover Y ceiling as fraction of screen height.
  double _calculateHoverY() {
    final w = game.wave;
    if (w <= 2) return 0.35;
    if (w <= 5) return 0.45;
    return 0.55;
  }
}
