import 'package:flutter/material.dart';
import '../audio/audio_manager.dart';
import '../zero_vector_game.dart';

class StartMenuOverlay extends StatefulWidget {
  static const String id = 'StartMenu';
  final ZeroVectorGame game;

  const StartMenuOverlay({super.key, required this.game});

  @override
  State<StartMenuOverlay> createState() => _StartMenuOverlayState();
}

class _StartMenuOverlayState extends State<StartMenuOverlay>
    with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late AnimationController _floatController;
  late AnimationController _entranceController;
  late AnimationController _shimmerController;

  late Animation<double> _pulseAnimation;
  late Animation<double> _floatAnimation;
  late Animation<double> _opacityAnimation;
  late Animation<Offset> _playButtonSlide;
  late Animation<Offset> _leaderboardButtonSlide;
  late Animation<double> _shimmerAnimation;

  // Initialise from persisted mute state
  bool _isSoundOn = !AudioManager.instance.isMuted;

  @override
  void initState() {
    super.initState();

    // Pulse: 1.0 -> 1.04 over 1.8s
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.04).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    // Floating: 0.0 -> 5.0 drift
    _floatController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3000),
    )..repeat(reverse: true);
    _floatAnimation = Tween<double>(begin: -3.0, end: 3.0).animate(
      CurvedAnimation(parent: _floatController, curve: Curves.easeInOut),
    );

    // Shimmer: 0.0 -> 1.0
    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();
    _shimmerAnimation = Tween<double>(begin: -1.0, end: 2.0).animate(
      CurvedAnimation(parent: _shimmerController, curve: Curves.linear),
    );

    // Entrance: 1.2s for buttons and high score
    _entranceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    _opacityAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _entranceController,
        curve: const Interval(0.0, 0.5, curve: Curves.easeIn),
      ),
    );

    _playButtonSlide = Tween<Offset>(
      begin: const Offset(0, 5),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _entranceController,
        curve: const Interval(0.3, 0.8, curve: Curves.elasticOut),
      ),
    );

    _leaderboardButtonSlide = Tween<Offset>(
      begin: const Offset(0, 5),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _entranceController,
        curve: const Interval(0.4, 0.9, curve: Curves.elasticOut),
      ),
    );

    _entranceController.forward();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _floatController.dispose();
    _entranceController.dispose();
    _shimmerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          // Radial Light Bloom behind title
          Center(
            child: Container(
              width: 400,
              height: 400,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    Colors.cyanAccent.withValues(alpha: 0.15),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),

          // Top Section: High Score (Fade In)
          Positioned(
            top: 60,
            left: 0,
            right: 0,
            child: FadeTransition(
              opacity: _opacityAnimation,
              child: Column(
                children: [
                  const Text(
                    'HIGH SCORE',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                      letterSpacing: 6,
                      fontWeight: FontWeight.w300,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${widget.game.highScore}',
                    style: const TextStyle(
                      color: Colors.cyanAccent,
                      fontSize: 36,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 2,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Center Section: Title and Buttons
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center, // Centered properly
              children: [
                const SizedBox(height: 40), // Offset slightly for top balance
                
                // Floating & Pulsing Title
                AnimatedBuilder(
                  animation: Listenable.merge([_pulseAnimation, _floatAnimation, _shimmerAnimation]),
                  builder: (context, child) {
                    final screenWidth = MediaQuery.of(context).size.width;
                    return Transform.translate(
                      offset: Offset(0, _floatAnimation.value),
                      child: Transform.scale(
                        scale: _pulseAnimation.value,
                        child: SizedBox(
                          width: screenWidth,
                          height: 100, // Fixed height to prevent layout shifts
                          child: Stack(
                            clipBehavior: Clip.none,
                            alignment: Alignment.center,
                            children: [
                              // 3 Layers for neon glow
                              // Outer Glow
                              Positioned(
                                left: 0,
                                right: 0,
                                child: Text(
                                  'SPACE FORCE',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 62,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 10,
                                    foreground: Paint()
                                      ..style = PaintingStyle.stroke
                                      ..strokeWidth = 8
                                      ..color = Colors.cyanAccent.withValues(alpha: 0.2)
                                      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 20),
                                  ),
                                ),
                              ),
                              // Inner Glow
                              Positioned(
                                left: 0,
                                right: 0,
                                child: Text(
                                  'SPACE FORCE',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 62,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 10,
                                    foreground: Paint()
                                      ..style = PaintingStyle.stroke
                                      ..strokeWidth = 3
                                      ..color = Colors.cyanAccent.withValues(alpha: 0.5)
                                      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
                                  ),
                                ),
                              ),
                              // Main Text with Shimmer
                              Positioned(
                                left: 0,
                                right: 0,
                                child: ShaderMask(
                                  shaderCallback: (bounds) {
                                    return LinearGradient(
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                      colors: const [
                                        Colors.white,
                                        Colors.cyanAccent,
                                        Colors.white,
                                      ],
                                      stops: [
                                        _shimmerAnimation.value - 0.2,
                                        _shimmerAnimation.value,
                                        _shimmerAnimation.value + 0.2,
                                      ],
                                    ).createShader(bounds);
                                  },
                                  child: const Text(
                                    'SPACE FORCE',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 62,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: 10,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
                
                const SizedBox(height: 80),

                // Buttons Section
                SlideTransition(
                  position: _playButtonSlide,
                  child: _MenuButton(
                    label: 'PLAY',
                    onPressed: () {
                      AudioManager.instance.playSfx('button.wav');
                      widget.game.restart();
                    },
                    primary: true,
                  ),
                ),
                const SizedBox(height: 20),
                SlideTransition(
                  position: _leaderboardButtonSlide,
                  child: _MenuButton(
                    label: 'LEADERBOARD',
                    onPressed: () {
                      AudioManager.instance.playSfx('button.wav');
                    },
                    primary: false,
                  ),
                ),
              ],
            ),
          ),

          // Bottom Right: Sound Toggle
          Positioned(
            bottom: 40,
            right: 40,
            child: FadeTransition(
              opacity: _opacityAnimation,
              child: IconButton(
                icon: Icon(
                  _isSoundOn ? Icons.volume_up : Icons.volume_off,
                  color: Colors.white.withValues(alpha: 0.6),
                  size: 32,
                ),
                onPressed: () async {
                  await AudioManager.instance.toggleMute();
                  setState(() {
                    _isSoundOn = !AudioManager.instance.isMuted;
                  });
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}



class _MenuButton extends StatefulWidget {
  final String label;
  final VoidCallback onPressed;
  final bool primary;

  const _MenuButton({
    required this.label,
    required this.onPressed,
    required this.primary,
  });

  @override
  State<_MenuButton> createState() => _MenuButtonState();
}

class _MenuButtonState extends State<_MenuButton>
    with SingleTickerProviderStateMixin {
  bool _isHovered = false;
  late AnimationController _glowController;

  @override
  void initState() {
    super.initState();
    _glowController = AnimationController(
        vsync: this, duration: const Duration(seconds: 2))
      ..repeat(reverse: true);
  }

  @override
  void dispose() {
    _glowController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final baseColor = widget.primary ? Colors.cyanAccent : Colors.white;
    final opacity = widget.primary ? 0.15 : 0.05;

    return GestureDetector(
      onTapDown: (_) => setState(() => _isHovered = true),
      onTapUp: (_) => setState(() => _isHovered = false),
      onTapCancel: () => setState(() => _isHovered = false),
      onTap: widget.onPressed,
      child: AnimatedBuilder(
        animation: _glowController,
        builder: (context, child) {
          return AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 280,
            padding: const EdgeInsets.symmetric(vertical: 18),
            decoration: BoxDecoration(
              color: baseColor.withValues(alpha: _isHovered ? opacity + 0.1 : opacity),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: widget.primary
                    ? baseColor.withValues(
                        alpha: 0.3 + (0.4 * _glowController.value))
                    : baseColor.withValues(alpha: 0.2),
                width: 2,
              ),
              boxShadow: widget.primary
                  ? [
                      BoxShadow(
                        color: baseColor.withValues(
                            alpha: 0.1 + (0.2 * _glowController.value)),
                        blurRadius: 10 + (8 * _glowController.value),
                        spreadRadius: 1,
                      )
                    ]
                  : null,
            ),
            child: Center(
              child: Text(
                widget.label,
                style: TextStyle(
                  color: baseColor.withValues(alpha: 0.95),
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 6,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
