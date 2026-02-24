import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'audio/audio_manager.dart';
import 'camera/camera_effects.dart';
import 'components/player.dart';
import 'components/enemy.dart';
import 'components/starfield.dart';
import 'package:flame/components.dart';
import 'components/wave_transition.dart';
import 'effects/warp_ring_component.dart';
import 'managers/enemy_spawn_manager.dart';
import 'overlays/start_menu_overlay.dart';

// ── Game state ──────────────────────────────────────────────────────────────
enum GameState { menu, waveTransition, playing, paused, gameOver }

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

  // ── Kill tracking (for life rewards) ────────────────────────────────────────
  int killCount = 0;

  // ── Wave ─────────────────────────────────────────────────────────────────────
  int wave = 1;
  double waveTimer = 0;
  static const double _waveDuration = 60.0;

  // Wave transition driven by WaveTransitionComponent (no timer needed)
  bool get isWaveTransition => state == GameState.waveTransition;
  String get waveTransitionText => 'WAVE $wave COMPLETE';

  // ── Wave spawn budget (read by EnemySpawnManager) ────────────────────────────
  int get totalEnemiesThisWave => wave * 2;
  int get maxSimultaneous => (2 + (wave / 2).floor()).clamp(1, 5);

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

    // Initialise audio system (loads files, restores mute state)
    await audioManager.init();

    // Shake controller (always active)
    add(shakeController);

    // Background first
    add(Starfield());

    // If in menu, show menu and start menu BGM
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

    // Apply camera shake offset
    camera.viewfinder.position = shakeController.offset;

    if (state == GameState.playing) {
      // Tick invulnerability
      if (_invulnTimer > 0) {
        _invulnTimer = (_invulnTimer - dt).clamp(0, 1.0);
      }

      // Tick wave timer
      waveTimer += dt;

      // After wave duration: activate aggressive mode on remaining enemies
      if (waveTimer >= _waveDuration) {
        _activateAggressiveMode();
      }

      // Wave ends when budget exhausted AND no enemies remain on screen
      final spawner = _spawnManager;
      final enemyCount = children.whereType<Enemy>().length;
      if (spawner != null &&
          spawner.totalSpawned >= totalEnemiesThisWave &&
          enemyCount == 0) {
        _startWaveTransition();
      }
    }
  }

  // ── Public shake API ──────────────────────────────────────────────────────────

  /// Trigger a screen shake effect.
  void shake({required double intensity, required double duration}) {
    shakeController.shake(intensity: intensity, duration: duration);
  }

  // ── Damage ──────────────────────────────────────────────────────────────────

  void applyBulletDamageToPlayer() {
    _applyDamageToPlayer(DamageValues.bullet);
  }

  void applyCollisionDamage() {
    _applyDamageToPlayer(DamageValues.collision(wave));
  }

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
    // Player damage SFX
    audioManager.playSfx('player_hit.wav');
    // Player damage → small shake
    shake(intensity: 5, duration: 0.25);
    _refreshHud();
  }

  /// Called by Enemy on kill — handles score, life rewards, and shake.
  void onEnemyKilled(int scoreValue) {
    _score += scoreValue;
    killCount++;
    // Life reward every 15 kills — only if below maxLives
    if (killCount % 15 == 0 && lives < maxLives) {
      lives++;
    }
    // Enemy death → tiny shake
    shake(intensity: 2, duration: 0.12);
    _refreshHud();
  }

  // ── Wave transitions ─────────────────────────────────────────────────────────

  void _activateAggressiveMode() {
    for (final e in children.whereType<Enemy>()) {
      e.activateAggressiveMode();
    }
    // Flush any enemies not yet spawned this wave — they skip hover
    // and start directly in aggressive mode, ensuring wave can complete.
    _spawnManager?.forceSpawnAllRemaining();
  }

  void _startWaveTransition() {
    state = GameState.waveTransition;
    _spawnManager?.stopSpawning();
    // Wave complete → medium shake
    shake(intensity: 8, duration: 0.4);
    // Add animated component (it calls onWaveTransitionComplete on removal)
    add(WaveTransitionComponent(completedWave: wave));
    _refreshHud();
  }

  /// Called by WaveTransitionComponent when its animation finishes.
  void onWaveTransitionComplete() {
    if (state != GameState.waveTransition) return; // guard against cleanup
    _startNextWave();
  }

  void _startNextWave() {
    wave++;
    waveTimer = 0;
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
    // Switch back to menu BGM on game over
    audioManager.switchBgm(BgmType.menu);
    overlays.remove(Overlays.hud);
    overlays.add(Overlays.gameOver);
  }

  // ── Reset/Cleanup Logic ───────────────────────────────────────────────────

  /// Centralized internal state reset. 
  /// Does NOT modify overlays; strictly updates internal properties and entities.
  void resetGame() {
    _score = 0;
    lives = 3;
    wave = 1;
    waveTimer = 0;
    killCount = 0;
    playerHp = playerMaxHp;
    _invulnTimer = 0;
    state = GameState.playing;

    clearEnemies();
    children.whereType<WaveTransitionComponent>().forEach((c) => c.removeFromParent());
    children.whereType<ParticleSystemComponent>().forEach((c) => c.removeFromParent());
    children.whereType<WarpRingComponent>().forEach((c) => c.removeFromParent());
    player?.removeFromParent();
    _spawnManager?.removeFromParent();

    _initGame();
  }

  /// Full engine cleanup before returning to the start menu.
  void mainMenuCleanup() {
    audioManager.switchBgm(BgmType.menu);
    clearEnemies();
    _spawnManager?.removeFromParent();
    _spawnManager = null;
    player?.removeFromParent();
    children.whereType<WaveTransitionComponent>().forEach((c) => c.removeFromParent());
    children.whereType<ParticleSystemComponent>().forEach((c) => c.removeFromParent());
    children.whereType<WarpRingComponent>().forEach((c) => c.removeFromParent());
    
    _score = 0;
    state = GameState.menu;
    
    resumeEngine(); // Ensure engine isn't stuck if we were paused
    
    // UI clean up happens in the overlay itself or callers, 
    // but we ensure the core state is ready for Start Screen.
    overlays.clear();
    overlays.add(Overlays.startMenu);
  }

  // ── Restart ─────────────────────────────────────────────────────────────────
  void restart() {
    resetGame();
    resumeEngine();
    
    // Switch to game BGM (same as startGame behaviour)
    audioManager.switchBgm(BgmType.game);
    
    overlays.clear();
    overlays.add(Overlays.hud);
  }

  // ── Pause/Resume Helpers ────────────────────────────────────────────────────

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
  }

  Player? get player => children.whereType<Player>().firstOrNull;

  void _refreshHud() {
    overlays.remove(Overlays.hud);
    overlays.add(Overlays.hud);
  }

  // ── Engine pause/resume ──────────────────────────────────────────────────────

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
