import 'package:flutter/material.dart';
import '../zero_vector_game.dart';
import 'common/overlay_anim_container.dart';

class HudOverlay extends StatefulWidget {
  final ZeroVectorGame game;
  const HudOverlay({super.key, required this.game});

  @override
  State<HudOverlay> createState() => _HudOverlayState();
}

class _HudOverlayState extends State<HudOverlay> with SingleTickerProviderStateMixin {
  late final AnimationController _heartPulseController;
  late final Animation<double> _heartPulseAnimation;
  int _prevLives = 0;

  @override
  void initState() {
    super.initState();

    _heartPulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _heartPulseAnimation = Tween<double>(begin: 1.0, end: 1.25).animate(
      CurvedAnimation(parent: _heartPulseController, curve: Curves.elasticOut),
    );

    _prevLives = widget.game.lives;
  }

  @override
  void didUpdateWidget(HudOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.game.lives != _prevLives) {
      _heartPulseController.forward(from: 0.0);
      _prevLives = widget.game.lives;
    }
  }

  @override
  void dispose() {
    _heartPulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return OverlayAnimContainer(
      child: Stack(
        children: [
          // ── Top Row: Score, Wave, Pause ──────────────────────────────────
          Positioned(
            top: 40,
            left: 20,
            right: 20,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Score (Left)
                _StatItem(
                  label: 'SCORE',
                  value: widget.game.score.toString().padLeft(6, '0'),
                  color: const Color(0xFF00E5FF),
                ),

                // Wave (Center)
                _StatItem(
                  label: 'WAVE',
                  value: widget.game.wave.toString(),
                  color: Colors.white,
                  isCenter: true,
                ),

                // Pause Button (Right)
                IconButton(
                  onPressed: widget.game.pauseGame,
                  icon: const Icon(
                    Icons.pause_rounded,
                    color: Colors.white,
                    size: 28,
                  ),
                ),
              ],
            ),
          ),

          // ── Bottom Left: Hearts (Lives) ──────────────────────────────────
          Positioned(
            bottom: 40,
            left: 20,
            child: Row(
              children: List.generate(
                widget.game.maxLives,
                (index) => Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ScaleTransition(
                    scale: index == widget.game.lives - 1 || (index == widget.game.lives && _heartPulseController.isAnimating)
                        ? _heartPulseAnimation
                        : const AlwaysStoppedAnimation(1.0),
                    child: Icon(
                      index < widget.game.lives
                          ? Icons.favorite_rounded
                          : Icons.favorite_border_rounded,
                      color: index < widget.game.lives
                          ? const Color(0xFFFF1744)
                          : Colors.white.withValues(alpha: 0.2),
                      size: 24,
                      shadows: index < widget.game.lives
                          ? [
                              const Shadow(
                                color: Color(0xFFFF1744),
                                blurRadius: 10,
                              )
                            ]
                          : null,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final bool isCenter;

  const _StatItem({
    required this.label,
    required this.value,
    this.color = Colors.white,
    this.isCenter = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment:
          isCenter ? CrossAxisAlignment.center : CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            letterSpacing: 3,
            color: Colors.white.withValues(alpha: 0.5),
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: color,
            letterSpacing: 2,
            fontFamily: 'monospace',
          ),
        ),
      ],
    );
  }
}
