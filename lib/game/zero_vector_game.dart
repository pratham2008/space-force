import 'dart:math';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'audio/audio_manager.dart';
import 'camera/camera_effects.dart';
import 'components/score_popup.dart';
import 'components/player.dart';
import 'components/enemy.dart';
import 'components/starfield.dart';
import 'components/missile_ship.dart';
import 'components/mini_boss.dart';
import 'components/boss.dart';
import 'components/boss_warning_sequence.dart';
import 'components/elite_warning_banner.dart';
import 'package:flame/components.dart';
import 'components/wave_transition.dart';
import 'effects/warp_ring_component.dart';
import 'managers/enemy_spawn_manager.dart';
import 'overlays/start_menu_overlay.dart';

// ── Game state ──────────────────────────────────────────────────────────────
enum GameState { menu, waveTransition, bossWarning, bossFight, playing, paused, gameOver }

// ── Overlay keys (single source of truth) ──────────────────────────────────
class Overlays {
  static const String hud            = 'Hud';
  static const String gameOver       = 'GameOver';
  static const String startMenu      = StartMenuOverlay.id;
  static const String createUsername = 'CreateUsername';
  static const String leaderboard    = 'Leaderboard';
  static const String pauseMenu      = 'PauseMenu';
}

// ── Damage constants ────────────────────────────────────────────────────────
class DamageValues {
  static const int bullet = 15;
  static int collision(int wave) => 40 + (wave * 5);
}

class ZeroVectorGame extends FlameGame with HasCollisionDetection {
  // ── Score ───────────────────────────────────────────────────────────────────
  int _score = 0;
  int get score => _score;

  // ── Player HP ───────────────────────────────────────────────────────────────
  int playerMaxHp = 100;
  int playerHp = 100;

  // ── Lives ───────────────────────────────────────────────────────────────────
  int lives = 3;
  int maxLives = 3;

  // ── Kill tracking ────────────────────────────────────────────────────────────
  int killCount = 0;

  // ── Internal random ─────────────────────────────────────────────────────────
  final Random _random = Random();

  // ── Wave ─────────────────────────────────────────────────────────────────────
  int wave = 1;
  double waveTimer = 0;
  static const double _waveDuration = 60.0;

  bool get isWaveTransition => state == GameState.waveTransition;
  String get waveTransitionText => 'WAVE $wave COMPLETE';

  // ── Wave spawn budget (read by EnemySpawnManager) ────────────────────────────
  int get totalEnemiesThisWave => _waveBudget(wave);
  int get maxSimultaneous => (2 + (wave / 2).floor()).clamp(1, 6);

  // ── Boss state isolation ─────────────────────────────────────────────────────
  bool isBossFight = false;
  bool _bossWarningFired = false;  // Guard: onBossWarningComplete only fires once

  // ── Aggressive mode (once-per-wave flag) ─────────────────────────────────────
  bool _aggressiveModeActivated = false; // Resets each wave via _startNextWave

  // ── Invulnerability ─────────────────────────────────────────────────────────
  double _invulnTimer = 0;
  bool get isInvulnerable => _invulnTimer > 0;

  // ── State ───────────────────────────────────────────────────────────────────
  GameState state = GameState.menu;

  // ── Spawn manager ref ───────────────────────────────────────────────────────
  EnemySpawnManager? _spawnManager;

  // ── Camera shake ────────────────────────────────────────────────────────────
  final ScreenShakeController shakeController = ScreenShakeController();

  // ── Audio ───────────────────────────────────────────────────────────────────
  AudioManager get audioManager => AudioManager.instance;

  // ── Lifecycle ───────────────────────────────────────────────────────────────
  @override
  Color backgroundColor() => const Color(0xFF0A0A1A);

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    await audioManager.init();
    add(shakeController);
    add(Starfield());
    if (state == GameState.menu) {
      overlays.add(Overlays.startMenu);
      audioManager.switchBgm(BgmType.menu);
    } else {
      _initGame();
    }
  }

  void _initGame() {
    add(Player());
    _spawnManager = EnemySpawnManager();
    add(_spawnManager!);
    overlays.add(Overlays.hud);
  }

  @override
  void update(double dt) {
    super.update(dt);
    camera.viewfinder.position = shakeController.offset;

    if (state == GameState.playing || state == GameState.bossFight) {
      if (_invulnTimer > 0) {
        _invulnTimer = (_invulnTimer - dt).clamp(0, 1.0);
      }

      if (state == GameState.playing) {
        // Wave timer — only in playing state, never during boss fight
        if (!isBossFight && !_aggressiveModeActivated) {
          waveTimer += dt;

          if (waveTimer >= _waveDuration) {
            // Set flag FIRST to prevent repeated calls every remaining frame
            _aggressiveModeActivated = true;
            _activateAggressiveMode();
          }
        }

        // Wave ends when budget exhausted AND no standard enemies + missile ships remain
        final spawner    = _spawnManager;
        final enemyCount = children.whereType<Enemy>().length
                         + children.whereType<MissileShip>().length;

        if (!isBossFight &&
            spawner != null &&
            spawner.totalSpawned >= totalEnemiesThisWave &&
            enemyCount == 0) {
          _startWaveTransition();
        }
      }
    }
  }

  // ── Wave budget ─────────────────────────────────────────────────────────────
  int _waveBudget(int w) {
    // Phase 17 difficulty curve is implemented in Phase 17.
    // For now: base budget scales, uncapped for large waves.
    if (w <= 5)  return w * 2;
    if (w <= 10) return 8 + (w - 5) * 2;
    if (w <= 20) return 18 + (w - 10) * 3;
    return 48 + (w - 20) * 4;
  }

  // ── Shake ────────────────────────────────────────────────────────────────────
  void shake({required double intensity, required double duration}) {
    shakeController.shake(intensity: intensity, duration: duration);
  }

  // ── Damage ──────────────────────────────────────────────────────────────────
  void applyBulletDamageToPlayer() => _applyDamageToPlayer(DamageValues.bullet);

  void applyCollisionDamage() => _applyDamageToPlayer(DamageValues.collision(wave));

  /// Missile damage is given as a pre-computed value (fixed at projectile creation).
  void applyMissileDamageToPlayer(int damage) => _applyDamageToPlayer(damage);

  void _applyDamageToPlayer(int amount) {
    if (state == GameState.gameOver) return;
    if (isInvulnerable) return;

    playerHp -= amount;
    if (playerHp <= 0) {
      lives--;
      if (lives <= 0) {
        lives = 0;
        playerHp = 0;
        _triggerGameOver();
        return;
      }
      playerHp = playerMaxHp;
      _invulnTimer = 1.0;
      player?.startInvulnFlash();
    }
    audioManager.playSfx('player_hit.wav');
    shake(intensity: 5, duration: 0.25);
    _refreshHud();
  }

  // ── Kill handlers ────────────────────────────────────────────────────────────

  /// Called by regular Enemy and MissileShip on kill.
  void onEnemyKilled(int scoreValue, Vector2 pos, bool isAssault) {
    _score += scoreValue;
    killCount++;

    add(ScorePopup(
      position: pos + Vector2(0, -20),
      score: scoreValue,
      color: isAssault ? const Color(0xFFFFC857) : const Color(0xFF00E5FF),
    ));

    if (killCount % 15 == 0 && lives < maxLives) {
      lives++;
    }
    shake(intensity: 2, duration: 0.12);
    _refreshHud();
  }

  /// Called by MiniBoss on kill — higher score, gold popup.
  void onMiniBossKilled(Vector2 pos, int w) {
    const scoreValue = 150;
    _score += scoreValue;
    killCount++;
    add(ScorePopup(
      position: pos + Vector2(0, -28),
      score: scoreValue,
      color: const Color(0xFFFFC857),
    ));
    shake(intensity: 8, duration: 0.5);
    _refreshHud();
  }

  // ── Wave transitions ─────────────────────────────────────────────────────────

  void _activateAggressiveMode() {
    // Double-guard: never during boss fight
    if (isBossFight) return;

    // All standard enemies → aggressive dive
    for (final e in children.whereType<Enemy>()) {
      e.activateAggressiveMode();
    }
    // MissileShips — cancel lock/hover cleanly and switch to dive
    for (final ms in children.whereType<MissileShip>()) {
      ms.activateAggressiveMode();
    }
    // Force-spawn remaining budget (safe: isBossFight already guarded above)
    _spawnManager?.forceSpawnAllRemaining();
  }

  void _startWaveTransition() {
    state = GameState.waveTransition;
    _spawnManager?.stopSpawning();
    shake(intensity: 8, duration: 0.4);
    add(WaveTransitionComponent(completedWave: wave));
    _refreshHud();
  }

  /// Called by WaveTransitionComponent when its animation finishes.
  void onWaveTransitionComplete() {
    if (state != GameState.waveTransition) return;

    // ── Fixed boss wave detection (EXPLICIT — no modulo) ─────────────────────
    final nextWave = wave + 1;
    if (nextWave == 10 || nextWave == 20 || nextWave == 30) {
      wave++;
      waveTimer = 0;
      isBossFight = true;
      state = GameState.bossWarning;
      _spawnManager?.stopSpawning();
      clearEnemies();
      _refreshHud();
      debugPrint('[Wave] Boss wave detected: wave=$wave. SpawnManager active=${_spawnManager != null}. children=${children.length}');
      add(BossWarningSequence(bossWave: wave));
      return;
    }

    // ── Mini Boss roll (Wave 8+, with guards) ───────────────────────────────
    // Skip if: boss fight, boss wave, boss or mini-boss already active
    final hasActiveBoss = children.whereType<MiniBoss>().isNotEmpty ||
                          children.whereType<Boss>().isNotEmpty;

    if (!isBossFight && !hasActiveBoss && wave >= 8) {
      const miniBossChance = 0.15;
      if (_random.nextDouble() < miniBossChance) {
        add(EliteWarningBanner(
          onComplete: () {
            _spawnMiniBoss();
            _startNextWave();
          },
        ));
        wave++;
        waveTimer = 0;
        _refreshHud();
        return;
      }
    }

    _startNextWave();
  }

  /// Called by BossWarningSequence when its animation + fade finishes.
  /// Guarded by _bossWarningFired to prevent double-fire if onRemove
  /// is triggered during resetGame/clearEnemies.
  void onBossWarningComplete(int bossWave) {
    if (_bossWarningFired) return; // Idempotent — safe during cleanup
    _bossWarningFired = true;
    if (state != GameState.bossWarning) return; // Safety: must still be in warning

    debugPrint('[Boss] BossWarning completed — spawning wave $bossWave boss');
    state = GameState.bossFight;
    add(Boss(
      bossWave: bossWave,
      position: Vector2(size.x / 2, -80),
    ));
    debugPrint('[Boss] Boss added. children.length = ${children.length}');
    _refreshHud();
  }

  /// Called by Boss when HP reaches 0 — awards score and starts next wave.
  void onBossKilled(Vector2 pos, int bossWave) {
    const scoreValue = 1000;
    _score += scoreValue;
    killCount++;
    add(ScorePopup(
      position: pos + Vector2(0, -40),
      score: scoreValue,
      color: const Color(0xFFFFC857),
    ));
    shake(intensity: 15, duration: 1.0);
    _refreshHud();

    isBossFight = false;
    _startNextWave();
  }

  void _spawnMiniBoss() {
    final w = wave;
    int hp;
    if (w <= 12) {
      hp = 600;
    } else if (w <= 18) {
      hp = 900;
    } else {
      hp = 1200;
    }

    add(MiniBoss(
      wave: w,
      hp: hp,
      position: Vector2(size.x / 2, -60),
    ));
  }

  void _startNextWave() {
    wave++;
    waveTimer = 0;
    isBossFight = false;
    _aggressiveModeActivated = false; // Reset per-wave flag
    _bossWarningFired        = false; // Reset boss warning guard
    state = GameState.playing;
    _spawnManager?.startWave();
    _refreshHud();
  }

  void _triggerGameOver() {
    state = GameState.gameOver;
    _spawnManager?.removeFromParent();
    _spawnManager = null;
    clearEnemies();
    pauseEngine();
    audioManager.switchBgm(BgmType.menu);
    overlays.remove(Overlays.hud);
    overlays.add(Overlays.gameOver);
  }

  // ── Reset / Cleanup ─────────────────────────────────────────────────────────

  void resetGame() {
    _score = 0;
    lives = 3;
    wave = 1;
    waveTimer = 0;
    killCount = 0;
    isBossFight = false;
    _aggressiveModeActivated = false;
    _bossWarningFired        = false;
    playerHp = playerMaxHp;
    _invulnTimer = 0;
    state = GameState.playing;

    clearEnemies();
    children.whereType<WaveTransitionComponent>().forEach((c) => c.removeFromParent());
    children.whereType<ParticleSystemComponent>().forEach((c) => c.removeFromParent());
    children.whereType<WarpRingComponent>().forEach((c) => c.removeFromParent());
    children.whereType<MiniBoss>().forEach((c) => c.removeFromParent());
    children.whereType<EliteWarningBanner>().forEach((c) => c.removeFromParent());
    player?.removeFromParent();
    _spawnManager?.removeFromParent();

    _initGame();
  }

  void mainMenuCleanup() {
    audioManager.switchBgm(BgmType.menu);
    clearEnemies();
    _spawnManager?.removeFromParent();
    _spawnManager = null;
    player?.removeFromParent();
    children.whereType<WaveTransitionComponent>().forEach((c) => c.removeFromParent());
    children.whereType<ParticleSystemComponent>().forEach((c) => c.removeFromParent());
    children.whereType<WarpRingComponent>().forEach((c) => c.removeFromParent());
    children.whereType<MiniBoss>().forEach((c) => c.removeFromParent());
    children.whereType<Boss>().forEach((c) => c.removeFromParent());
    children.whereType<BossWarningSequence>().forEach((c) => c.removeFromParent());
    children.whereType<EliteWarningBanner>().forEach((c) => c.removeFromParent());

    _score = 0;
    isBossFight = false;
    state = GameState.menu;

    resumeEngine();

    overlays.clear();
    overlays.add(Overlays.startMenu);
  }

  // ── Restart ─────────────────────────────────────────────────────────────────
  void restart() {
    resetGame();
    resumeEngine();
    audioManager.switchBgm(BgmType.game);
    overlays.clear();
    overlays.add(Overlays.hud);
  }

  // ── Pause/Resume ────────────────────────────────────────────────────────────
  void pauseGame() {
    if (state != GameState.playing) return;
    state = GameState.paused;
    pauseEngine();
    audioManager.pauseBgm();
    overlays.add(Overlays.pauseMenu);
  }

  void resumeGame() {
    if (state != GameState.paused) return;
    state = GameState.playing;
    resumeEngine();
    audioManager.resumeBgm();
    overlays.remove(Overlays.pauseMenu);
  }

  // ── Helpers ─────────────────────────────────────────────────────────────────
  void clearEnemies() {
    children.whereType<Enemy>().forEach((e) => e.removeFromParent());
    children.whereType<MissileShip>().forEach((e) => e.removeFromParent());
    children.whereType<MiniBoss>().forEach((e) => e.removeFromParent());
    children.whereType<Boss>().forEach((e) => e.removeFromParent());
  }

  Player? get player => children.whereType<Player>().firstOrNull;

  void _refreshHud() {
    overlays.remove(Overlays.hud);
    overlays.add(Overlays.hud);
  }

  // ── Engine lifecycle ────────────────────────────────────────────────────────
  @override
  void lifecycleStateChange(AppLifecycleState state) {
    super.lifecycleStateChange(state);
    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.inactive:
      case AppLifecycleState.hidden:
        audioManager.pauseBgm();
        break;
      case AppLifecycleState.resumed:
        audioManager.resumeBgm();
        break;
      default:
        break;
    }
  }

  // ── Legacy compat ─────────────────────────────────────────────────────────────
  void damagePlayer(int amount) => applyCollisionDamage();
}
