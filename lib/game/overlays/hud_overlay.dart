import 'package:flutter/material.dart';
import '../audio/audio_manager.dart';
import '../zero_vector_game.dart';
import 'common/overlay_anim_container.dart';

class HudOverlay extends StatefulWidget {
  final ZeroVectorGame game;
  const HudOverlay({super.key, required this.game});

  @override
  State<HudOverlay> createState() => _HudOverlayState();
}

class _HudOverlayState extends State<HudOverlay> with TickerProviderStateMixin {
  late final AnimationController _heartPulseController;
  late final Animation<double> _heartPulseAnimation;
  
  // Smooth HP animation
  late final AnimationController _hpAnimController;
  late Animation<double> _hpAnimation;
  double _displayedHp = 100;
  
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

    _hpAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );
    _hpAnimation = AlwaysStoppedAnimation(widget.game.playerHp.toDouble());
    _displayedHp = widget.game.playerHp.toDouble();

    _prevLives = widget.game.lives;
  }

  @override
  void didUpdateWidget(HudOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    // Smooth HP transition
    if (widget.game.playerHp.toDouble() != _hpAnimation.value) {
      _hpAnimation = Tween<double>(
        begin: _displayedHp,
        end: widget.game.playerHp.toDouble(),
      ).animate(CurvedAnimation(
        parent: _hpAnimController,
        curve: Curves.easeOut,
      ));
      _hpAnimController.forward(from: 0.0);
    }

    if (widget.game.lives != _prevLives) {
      _heartPulseController.forward(from: 0.0);
      _prevLives = widget.game.lives;
    }
  }

  @override
  void dispose() {
    _heartPulseController.dispose();
    _hpAnimController.dispose();
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
                _StatItem(
                  label: 'SCORE',
                  value: widget.game.score.toString().padLeft(6, '0'),
                  color: const Color(0xFF00E5FF),
                ),
                _StatItem(
                  label: 'WAVE',
                  value: widget.game.wave.toString(),
                  color: Colors.white,
                  isCenter: true,
                ),
                IconButton(
                  onPressed: () {
                    AudioManager.instance.playSfx('button.wav');
                    widget.game.pauseGame();
                  },
                  icon: const Icon(Icons.pause_rounded, color: Colors.white, size: 28),
                ),
              ],
            ),
          ),

          // ── Bottom Left: Hearts (Lives + HP) ─────────────────────────────
          Positioned(
            bottom: 40,
            left: 20,
            child: AnimatedBuilder(
              animation: Listenable.merge([_heartPulseAnimation, _hpAnimController]),
              builder: (context, child) {
                _displayedHp = _hpAnimation.value;
                final hpRatio = (_displayedHp / widget.game.playerMaxHp).clamp(0.0, 1.0);
                
                return Row(
                  children: List.generate(
                    widget.game.maxLives,
                    (index) {
                      // Determines how much of THIS heart is filled
                      double heartFill = 0.0;
                      if (index < widget.game.lives - 1) {
                        heartFill = 1.0; // Fully filled
                      } else if (index == widget.game.lives - 1) {
                        heartFill = hpRatio; // Partially filled
                      }

                      final isPulsing = index == widget.game.lives - 1 || 
                                      (index == widget.game.lives && _heartPulseController.isAnimating);

                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: Transform.scale(
                          scale: isPulsing ? _heartPulseAnimation.value : 1.0,
                          child: CustomPaint(
                            size: const Size(24, 22),
                            painter: HeartPainter(
                              fillLevel: heartFill,
                              color: const Color(0xFFFF1744),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class HeartPainter extends CustomPainter {
  final double fillLevel;
  final Color color;

  HeartPainter({required this.fillLevel, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final backgroundPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.15)
      ..style = PaintingStyle.fill;

    final heartPath = Path();
    final width = size.width;
    final height = size.height;

    heartPath.moveTo(width / 2, height * 0.25);
    heartPath.cubicTo(width * 0.2, 0, 0, height * 0.3, 0, height * 0.6);
    heartPath.cubicTo(0, height * 0.8, width * 0.4, height, width / 2, height);
    heartPath.cubicTo(width * 0.6, height, width, height * 0.8, width, height * 0.6);
    heartPath.cubicTo(width, height * 0.3, width * 0.8, 0, width / 2, height * 0.25);

    // Draw background (empty heart)
    canvas.drawPath(heartPath, backgroundPaint);

    if (fillLevel > 0) {
      canvas.save();
      // Clip according to fill level (bottom to top)
      final clipRect = Rect.fromLTWH(0, height * (1.0 - fillLevel), width, height * fillLevel);
      canvas.clipRect(clipRect);
      canvas.drawPath(heartPath, paint);
      
      // Inner brightness
      canvas.drawPath(
        heartPath,
        Paint()
          ..color = Colors.white.withValues(alpha: 0.2)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.0,
      );
      canvas.restore();
    }

    // Border
    canvas.drawPath(
      heartPath,
      Paint()
        ..color = (fillLevel > 0 ? color : Colors.white).withValues(alpha: 0.3)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2,
    );
  }

  @override
  bool shouldRepaint(HeartPainter oldDelegate) => 
      oldDelegate.fillLevel != fillLevel || oldDelegate.color != color;
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
