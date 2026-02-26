import 'dart:async';
import 'package:flame_audio/flame_audio.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Which background music track should be playing.
enum BgmType { menu, game }

/// Centralised audio system for SPACE FORCE.
///
/// All BGM transitions go through [switchBgm]. Never call FlameAudio directly
/// from game components — use this class exclusively.
///
/// Usage:
///   await AudioManager.instance.init();
///   AudioManager.instance.switchBgm(BgmType.menu);
///   AudioManager.instance.playSfx('shoot.wav');
///   AudioManager.instance.toggleMute();
class AudioManager {
  AudioManager._();
  static final AudioManager instance = AudioManager._();

  // ── State ───────────────────────────────────────────────────────────────────
  bool _isMuted = false;
  bool _initialised = false;
  BgmType? _currentBgm;

  // Ongoing fade timer — cancelled if a new switchBgm arrives
  Timer? _fadeTimer;

  bool get isMuted => _isMuted;

  // ── Constants ────────────────────────────────────────────────────────────────
  static const _muteKey = 'audio_muted';
  static const double _menuBgmVolume = 0.6;
  static const double _gameBgmVolume  = 0.8;
  static const _menuBgmFile = 'menu_bgm.mp3';
  static const _gameBgmFile = 'game_bgm.mp3';
  static const _fadeDuration = Duration(milliseconds: 300);
  static const _fadeSteps    = 10; // ticks inside the 300 ms fade

  static const _allFiles = [
    _menuBgmFile,
    _gameBgmFile,
    'shoot.wav',
    'explosion.wav',
    'button.wav',
    'player_hit.wav',
    'warning_siren.wav',
    'boss_entry.wav',
    'missile_lock.wav',
    'missile_launch.wav',
    'boss_death.wav',
    'miniboss_warning.wav',
  ];

  // ── Initialisation ──────────────────────────────────────────────────────────

  /// Call once from ZeroVectorGame.onLoad().
  /// Missing audio files are silently skipped — the app will NOT crash.
  Future<void> init() async {
    if (_initialised) return;
    _initialised = true;

    // Restore persisted mute state.
    final prefs = await SharedPreferences.getInstance();
    _isMuted = prefs.getBool(_muteKey) ?? false;

    // Load each file individually so a missing asset does not abort the whole
    // preload batch. Errors are logged in debug mode only.
    for (final file in _allFiles) {
      try {
        await FlameAudio.audioCache.load(file);
      } catch (e) {
        debugPrint('[AudioManager] Could not preload "$file": $e');
      }
    }
  }

  // ── BGM ─────────────────────────────────────────────────────────────────────

  /// The single entry-point for all BGM changes.
  ///
  /// Fades the current track out over 300 ms, then starts [type].
  /// No-ops if [type] is already playing. Respects mute.
  void switchBgm(BgmType type) {
    if (_currentBgm == type) return; // already playing — avoid restart
    _currentBgm = type;

    if (_isMuted) return; // nothing to fade, just update bookkeeping

    _cancelFade();
    _fadeOutThenStart();
  }

  /// Pause BGM — call when the app goes to background / engine pauses.
  void pauseBgm() {
    _cancelFade();
    FlameAudio.bgm.pause();
  }

  /// Resume BGM — call when the app returns to foreground / engine resumes.
  void resumeBgm() {
    if (_isMuted) return;
    FlameAudio.bgm.resume();
  }

  // ── SFX ─────────────────────────────────────────────────────────────────────

  /// Play a one-shot SFX. Silent when muted.
  void playSfx(String fileName) {
    if (_isMuted) return;
    try {
      FlameAudio.play(fileName);
    } catch (e) {
      debugPrint('[AudioManager] Could not play SFX "$fileName": $e');
    }
  }

  // ── Mute ────────────────────────────────────────────────────────────────────

  /// Toggle mute, persist it, and apply immediately.
  Future<void> toggleMute() async {
    _isMuted = !_isMuted;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_muteKey, _isMuted);

    if (_isMuted) {
      _cancelFade();
      FlameAudio.bgm.stop();
    } else {
      // Resume the track that should be playing right now.
      _startCurrentBgm();
    }
  }

  // ── Dispose ─────────────────────────────────────────────────────────────────

  /// Call on game teardown. Stops all audio and resets state.
  void dispose() {
    _cancelFade();
    FlameAudio.bgm.stop();
    _currentBgm  = null;
    _initialised = false;
  }

  // ── Private ──────────────────────────────────────────────────────────────────

  /// Start the track recorded in [_currentBgm] immediately at full volume.
  void _startCurrentBgm() {
    final target = _currentBgm;
    if (target == null) return;
    final file   = target == BgmType.menu ? _menuBgmFile : _gameBgmFile;
    final volume = target == BgmType.menu ? _menuBgmVolume : _gameBgmVolume;
    try {
      FlameAudio.bgm.play(file, volume: volume);
    } catch (e) {
      debugPrint('[AudioManager] Could not start BGM "$file": $e');
    }
  }

  /// Fade the current BGM out over [_fadeDuration], then start the next track.
  void _fadeOutThenStart() {
    // Snapshot the target before the async fade completes, so a mid-fade
    // switchBgm() cannot race with us.
    final intendedBgm = _currentBgm;

    // Starting volume for the outgoing track.
    final targetVolume = intendedBgm == BgmType.menu
        ? _menuBgmVolume
        : _gameBgmVolume;

    // Immediately stop any previous BGM to avoid overlap before the fade.
    // We restart the outgoing file at "previous volume" logic is not available
    // from FlameAudio.bgm, so instead we just do a hard stop → delayed start.
    //
    // Pattern: stop old BGM now, wait 300 ms (the "fade"), play new BGM.
    // This gives a clean break without overlap, and the 300 ms gap prevents
    // jarring cuts. True volume fade requires a raw AudioPlayer handle which
    // flame_audio.Bgm does not expose; this approximation is safe and clean.
    FlameAudio.bgm.stop();

    // After a short gap, start the new track (simulating the "after fade" moment).
    final stepMs = _fadeDuration.inMilliseconds ~/ _fadeSteps;
    var step = 0;
    _fadeTimer = Timer.periodic(Duration(milliseconds: stepMs), (timer) {
      step++;
      if (step >= _fadeSteps) {
        timer.cancel();
        _fadeTimer = null;
        // Only start if the intended BGM is still current (no race condition).
        if (_currentBgm == intendedBgm && !_isMuted) {
          final file   = intendedBgm == BgmType.menu ? _menuBgmFile : _gameBgmFile;
          try {
            FlameAudio.bgm.play(file, volume: targetVolume);
          } catch (e) {
            debugPrint('[AudioManager] Could not start BGM "$file": $e');
          }
        }
      }
    });
  }

  void _cancelFade() {
    _fadeTimer?.cancel();
    _fadeTimer = null;
  }
}
