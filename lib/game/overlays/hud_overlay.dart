import 'package:flutter/material.dart';
import '../zero_vector_game.dart';

class HudOverlay extends StatefulWidget {
  final ZeroVectorGame game;

  const HudOverlay({super.key, required this.game});

  @override
  State<HudOverlay> createState() => _HudOverlayState();
}

class _HudOverlayState extends State<HudOverlay> with TickerProviderStateMixin {
  late AnimationController _hpGradientController;
  late AnimationController _lifePulseController;
  int _prevLives = 0;

  @override
  void initState() {
    super.initState();
    _hpGradientController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();

    _lifePulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    _prevLives = widget.game.lives;
  }

  @override
  void didUpdateWidget(HudOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.game.lives != _prevLives) {
      _lifePulseController.forward(from: 0.0);
      _prevLives = widget.game.lives;
    }
  }

  @override
  void dispose() {
    _hpGradientController.dispose();
    _lifePulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
      child: Column(
        children: [
          // Top row: Score and Wave
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _StatItem(label: 'SCORE', value: '${widget.game.score}'),
              _StatItem(label: 'WAVE', value: '${widget.game.wave}'),
            ],
          ),

          const SizedBox(height: 16),

          // HP Bar with Animated Gradient
          AnimatedBuilder(
            animation: _hpGradientController,
            builder: (context, child) {
              final progress = (widget.game.playerHp / widget.game.playerMaxHp).clamp(0.0, 1.0);
              return Container(
                height: 12,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.white10,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: Colors.white24),
                ),
                child: FractionallySizedBox(
                  alignment: Alignment.centerLeft,
                  widthFactor: progress,
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(6),
                      gradient: LinearGradient(
                        colors: const [
                          Color(0xFF00E5FF),
                          Colors.cyanAccent,
                          Color(0xFF00E5FF),
                        ],
                        stops: [
                          0.0,
                          _hpGradientController.value,
                          1.0,
                        ],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.cyanAccent.withValues(alpha: 0.4),
                          blurRadius: 8,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),

          const SizedBox(height: 12),

          // Bottom Row: Lives
          Row(
            children: List.generate(widget.game.maxLives, (index) {
              final isLit = index < widget.game.lives;
              return ScaleTransition(
                scale: index == widget.game.lives - 1 || (index == widget.game.lives && _lifePulseController.isAnimating)
                    ? Tween<double>(begin: 1.0, end: 1.25).animate(
                        CurvedAnimation(parent: _lifePulseController, curve: Curves.elasticOut))
                    : const AlwaysStoppedAnimation(1.0),
                child: Icon(
                  Icons.favorite,
                  size: 20,
                  color: isLit ? Colors.redAccent : Colors.white10,
                  shadows: isLit
                      ? [const Shadow(color: Colors.redAccent, blurRadius: 10)]
                      : null,
                ),
              );
            }),
          ),
        ],
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final String label;
  final String value;

  const _StatItem({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Colors.white60,
            fontSize: 10,
            letterSpacing: 3,
            fontWeight: FontWeight.w600,
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w900,
            letterSpacing: 1,
          ),
        ),
      ],
    );
  }
}
