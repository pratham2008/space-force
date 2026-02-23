import 'package:flutter/material.dart';
import '../zero_vector_game.dart';

class GameOverOverlay extends StatelessWidget {
  static const String id = Overlays.gameOver;

  final ZeroVectorGame game;
  const GameOverOverlay({super.key, required this.game});

  @override
  Widget build(BuildContext context) {
    return Container(
      // Dark translucent backdrop
      color: Colors.black.withValues(alpha: 0.75),
      child: Center(
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
                  color: Colors.white, // masked by shader
                  fontFamily: 'monospace',
                ),
              ),
            ),

            const SizedBox(height: 24),

            // ── Final score ──────────────────────────────────────────────
            Text(
              'SCORE',
              style: TextStyle(
                fontSize: 11,
                letterSpacing: 4,
                color: Colors.white.withValues(alpha: 0.5),
                fontFamily: 'monospace',
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '${game.score}'.padLeft(6, '0'),
              style: const TextStyle(
                fontSize: 40,
                fontWeight: FontWeight.w700,
                color: Color(0xFF00E5FF),
                fontFamily: 'monospace',
                letterSpacing: 4,
              ),
            ),

            const SizedBox(height: 48),

            // ── Restart button ───────────────────────────────────────────
            GestureDetector(
              onTap: game.restart,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 40,
                  vertical: 14,
                ),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF00E5FF), Color(0xFF0072FF)],
                  ),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF00E5FF).withValues(alpha: 0.35),
                      blurRadius: 18,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: const Text(
                  'PLAY AGAIN',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 3,
                    color: Colors.white,
                    fontFamily: 'monospace',
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
