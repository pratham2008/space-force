import 'package:flutter/material.dart';
import '../zero_vector_game.dart';
import '../services/auth_service.dart';
import '../services/leaderboard_service.dart';
import 'common/overlay_anim_container.dart';

class GameOverOverlay extends StatefulWidget {
  static const String id = Overlays.gameOver;
  final ZeroVectorGame game;

  const GameOverOverlay({super.key, required this.game});

  @override
  State<GameOverOverlay> createState() => _GameOverOverlayState();
}

class _GameOverOverlayState extends State<GameOverOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _glowController;
  late final Animation<double> _glowAnimation;
  bool _isHighScore = false;
  bool _checkingHighScore = true;

  @override
  void initState() {
    super.initState();
    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _glowAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _glowController, curve: Curves.easeInOut),
    );

    _initHighScoreCheck();
  }

  Future<void> _initHighScoreCheck() async {
    if (AuthService.instance.isLoggedIn) {
      final entry = await LeaderboardService.instance.getMyEntry();
      if (entry != null && widget.game.score > entry.score) {
        setState(() => _isHighScore = true);
        // Persist immediately if logged in
        await LeaderboardService.instance.saveScore(entry.username, widget.game.score);
      } else if (entry == null && widget.game.score > 0) {
        // First ever score would be a high score
        setState(() => _isHighScore = true);
      }
    } else {
      // For non-logged in users, we can't check against global, 
      // but we treat everything > 0 as potential save-worthy.
      setState(() => _isHighScore = widget.game.score > 0);
    }
    setState(() => _checkingHighScore = false);
  }

  @override
  void dispose() {
    _glowController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isLoggedIn = AuthService.instance.isLoggedIn;

    return Container(
      color: Colors.black.withValues(alpha: 0.85),
      child: Center(
        child: OverlayAnimContainer(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ── Title ────────────────────────────────────────────────────
              ShaderMask(
                shaderCallback: (bounds) => const LinearGradient(
                  colors: [Color(0xFFFF1744), Color(0xFFFF6D00)],
                ).createShader(bounds),
                child: const Text(
                  'GAME OVER',
                  style: TextStyle(
                    fontSize: 48,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 6,
                    color: Colors.white,
                    fontFamily: 'monospace',
                  ),
                ),
              ),

              const SizedBox(height: 32),

              // ── High Score Glow ──────────────────────────────────────────
              if (!_checkingHighScore && _isHighScore)
                AnimatedBuilder(
                  animation: _glowAnimation,
                  builder: (context, child) {
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFF00E5FF).withValues(alpha: 0.1 * _glowAnimation.value),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: const Color(0xFF00E5FF).withValues(alpha: 0.5 * _glowAnimation.value),
                          width: 1.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF00E5FF).withValues(alpha: 0.2 * _glowAnimation.value),
                            blurRadius: 15,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: const Text(
                        'NEW HIGH SCORE',
                        style: TextStyle(
                          color: Color(0xFF00E5FF),
                          fontWeight: FontWeight.w900,
                          fontSize: 12,
                          letterSpacing: 4,
                        ),
                      ),
                    );
                  },
                ),

              const SizedBox(height: 16),

              // ── Final score ──────────────────────────────────────────────
              Text(
                'FINAL SCORE',
                style: TextStyle(
                  fontSize: 11,
                  letterSpacing: 4,
                  color: Colors.white.withValues(alpha: 0.4),
                  fontFamily: 'monospace',
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${widget.game.score}'.padLeft(6, '0'),
                style: const TextStyle(
                  fontSize: 56,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                  fontFamily: 'monospace',
                  letterSpacing: 4,
                ),
              ),

              const SizedBox(height: 48),

              // ── Buttons ──────────────────────────────────────────────────
              _MenuButton(
                label: 'PLAY AGAIN',
                onPressed: widget.game.restart,
                primary: true,
              ),
              const SizedBox(height: 16),

              // Save Score button (Only if not logged in and has a score)
              if (!isLoggedIn && widget.game.score > 0) ...[
                _MenuButton(
                  label: 'SAVE SCORE',
                  onPressed: () => widget.game.overlays.add(Overlays.createUsername),
                  color: const Color(0xFF00E5FF),
                ),
                const SizedBox(height: 16),
              ],

              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _SmallButton(
                    label: 'LEADERBOARD',
                    onPressed: () => widget.game.overlays.add(Overlays.leaderboard),
                  ),
                  const SizedBox(width: 12),
                  _SmallButton(
                    label: 'MAIN MENU',
                    onPressed: widget.game.mainMenuCleanup,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MenuButton extends StatelessWidget {
  final String label;
  final VoidCallback onPressed;
  final bool primary;
  final Color? color;

  const _MenuButton({
    required this.label,
    required this.onPressed,
    this.primary = false,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        width: 240,
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          gradient: primary
              ? const LinearGradient(colors: [Color(0xFF00E5FF), Color(0xFF0072FF)])
              : null,
          color: !primary ? (color?.withValues(alpha: 0.1) ?? Colors.white10) : null,
          borderRadius: BorderRadius.circular(16),
          border: !primary
              ? Border.all(color: (color ?? Colors.white).withValues(alpha: 0.2))
              : null,
          boxShadow: primary
              ? [
                  BoxShadow(
                    color: const Color(0xFF00E5FF).withValues(alpha: 0.3),
                    blurRadius: 15,
                    spreadRadius: 1,
                  )
                ]
              : null,
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w900,
              letterSpacing: 4,
              color: primary ? Colors.white : (color ?? Colors.white),
            ),
          ),
        ),
      ),
    );
  }
}

class _SmallButton extends StatelessWidget {
  final String label;
  final VoidCallback onPressed;

  const _SmallButton({required this.label, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w800,
          letterSpacing: 2,
          color: Colors.white.withValues(alpha: 0.5),
        ),
      ),
    );
  }
}
