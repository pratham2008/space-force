import 'dart:math';
import 'package:flame/components.dart';
import '../zero_vector_game.dart';
import '../components/enemy.dart';

/// Wave-controlled spawn manager.
/// Each wave has a fixed enemy budget and a simultaneous cap.
///   totalEnemies    = wave * 2
///   maxSimultaneous = min(2 + floor(wave / 2), 5)
class EnemySpawnManager extends Component
    with HasGameReference<ZeroVectorGame> {
  // ── Per-wave counters ───────────────────────────────────────────────────────
  int totalSpawned = 0;

  // ── Timing ──────────────────────────────────────────────────────────────────
  double _timeSinceLastSpawn = 0;
  static const double _spawnCooldown = 1.2; // min seconds between any spawn

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

  /// Spawns all enemies that haven't been spawned yet this wave,
  /// ignoring maxSimultaneous and cooldown. Each spawns in aggressive mode.
  void forceSpawnAllRemaining() {
    final remaining = game.totalEnemiesThisWave - totalSpawned;
    for (var i = 0; i < remaining; i++) {
      _spawnEnemyImpl(aggressive: true);
    }
    // Mark budget exhausted so normal spawning doesn't fire again.
    totalSpawned = game.totalEnemiesThisWave;
    _active = false;
  }

  @override
  void update(double dt) {
    super.update(dt);

    if (!_active) return;

    final total = game.totalEnemiesThisWave;
    if (totalSpawned >= total) return; // budget exhausted

    _timeSinceLastSpawn += dt;
    if (_timeSinceLastSpawn < _spawnCooldown) return;

    // Count active enemies (exclude EnemyBullets)
    final activeEnemies = game.children.whereType<Enemy>().length;
    if (activeEnemies >= game.maxSimultaneous) return; // at cap

    _timeSinceLastSpawn = 0;
    _spawnEnemy();
  }

  void _spawnEnemy() {
    _spawnEnemyImpl(aggressive: false);
    totalSpawned++;
  }

  void _spawnEnemyImpl({required bool aggressive}) {
    final x = _random.nextDouble() * game.size.x;
    game.add(
      Enemy(
        position: Vector2(x, -20),
        baseSpeed: _calculateEnemySpeed(),
        scoreValue: 10,
        hp: _calculateEnemyHp(),
        hoverYFraction: _calculateHoverY(),
        startAggressive: aggressive,
      ),
    );
  }

  /// enemyHp = 2 + floor(wave * 0.6)
  int _calculateEnemyHp() => 2 + (game.wave * 0.6).floor();

  /// Speed scales gently with wave number.
  double _calculateEnemySpeed() {
    return (100 + game.wave * 10.0).clamp(100, 280).toDouble();
  }

  /// Hover Y ceiling as a fraction of screen height.
  /// Wave 1–2: 35%  |  Wave 3–5: 45%  |  Wave 6+: 55%
  /// Minimum is always 10% from the top.
  double _calculateHoverY() {
    final w = game.wave;
    if (w <= 2) return 0.35;
    if (w <= 5) return 0.45;
    return 0.55;
  }
}
