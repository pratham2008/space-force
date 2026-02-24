import 'dart:ui';
import 'package:flutter/material.dart';
import '../zero_vector_game.dart';
import 'common/overlay_anim_container.dart';

class PauseMenuOverlay extends StatelessWidget {
  static const String id = Overlays.pauseMenu;
  final ZeroVectorGame game;

  const PauseMenuOverlay({super.key, required this.game});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          // ── Background Blur ────────────────────────────────────────────────
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
              child: Container(
                color: Colors.black.withValues(alpha: 0.5), // Performance fallback
              ),
            ),
          ),

          // ── Centered Modal ─────────────────────────────────────────────────
          Center(
            child: OverlayAnimContainer(
              child: Container(
                width: 280,
                padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
                decoration: BoxDecoration(
                  color: const Color(0xFF0A0A1A).withValues(alpha: 0.9),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: const Color(0xFF00E5FF).withValues(alpha: 0.3),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF00E5FF).withValues(alpha: 0.15),
                      blurRadius: 30,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // ── Title ────────────────────────────────────────────────
                    const Text(
                      'PAUSED',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 8,
                        color: Color(0xFF00E5FF),
                      ),
                    ),
                    const SizedBox(height: 32),

                    // ── Buttons ──────────────────────────────────────────────
                    _PauseButton(
                      label: 'RESUME',
                      onPressed: game.resumeGame,
                      primary: true,
                    ),
                    const SizedBox(height: 16),
                    _PauseButton(
                      label: 'RESTART',
                      onPressed: game.restart,
                    ),
                    const SizedBox(height: 16),
                    _PauseButton(
                      label: 'LEADERBOARD',
                      onPressed: () {
                        game.overlays.remove(Overlays.pauseMenu);
                        game.overlays.add(Overlays.leaderboard);
                      },
                    ),
                    const SizedBox(height: 16),
                    _PauseButton(
                      label: 'MAIN MENU',
                      onPressed: game.mainMenuCleanup,
                      isWarning: true,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PauseButton extends StatelessWidget {
  final String label;
  final VoidCallback onPressed;
  final bool primary;
  final bool isWarning;

  const _PauseButton({
    required this.label,
    required this.onPressed,
    this.primary = false,
    this.isWarning = false,
  });

  @override
  Widget build(BuildContext context) {
    Color color = Colors.white.withValues(alpha: 0.7);
    if (primary) color = const Color(0xFF00E5FF);
    if (isWarning) color = const Color(0xFFFF1744).withValues(alpha: 0.7);

    return GestureDetector(
      onTap: onPressed,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: primary 
              ? const Color(0xFF00E5FF).withValues(alpha: 0.1) 
              : Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: color.withValues(alpha: 0.3),
            width: 1,
          ),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              letterSpacing: 3,
              color: color,
            ),
          ),
        ),
      ),
    );
  }
}
