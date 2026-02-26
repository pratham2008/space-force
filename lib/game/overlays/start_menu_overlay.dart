import 'package:flutter/material.dart';
import '../audio/audio_manager.dart';
import '../services/auth_service.dart';
import '../services/leaderboard_service.dart';
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
  late AnimationController _scoreCounterController;

  late Animation<double> _pulseAnimation;
  late Animation<double> _floatAnimation;
  late Animation<double> _opacityAnimation;
  late Animation<Offset> _playButtonSlide;
  late Animation<Offset> _leaderboardButtonSlide;
  late Animation<double> _shimmerAnimation;
  late Animation<int> _scoreCounterAnimation;

  bool _isSoundOn = !AudioManager.instance.isMuted;
  bool _isLoadingScore = true;
  String _scoreLabel = 'GLOBAL BEST';

  @override
  void initState() {
    super.initState();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.04).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _floatController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3000),
    )..repeat(reverse: true);
    _floatAnimation = Tween<double>(begin: -3.0, end: 3.0).animate(
      CurvedAnimation(parent: _floatController, curve: Curves.easeInOut),
    );

    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();
    _shimmerAnimation = Tween<double>(begin: -1.0, end: 2.0).animate(
      CurvedAnimation(parent: _shimmerController, curve: Curves.linear),
    );

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

    _scoreCounterController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    _scoreCounterAnimation = IntTween(begin: 0, end: 0).animate(
      CurvedAnimation(parent: _scoreCounterController, curve: Curves.easeOutCubic),
    );

    _loadScoreData();
    _entranceController.forward();
  }

  Future<void> _loadScoreData() async {
    int targetScore = 0;
    String label = 'GLOBAL BEST';

    try {
      if (AuthService.instance.isLoggedIn) {
        final myEntry = await LeaderboardService.instance.getMyEntry();
        if (myEntry != null) {
          targetScore = myEntry.score;
          label = 'YOUR BEST';
        } else {
          // If logged in but no score, show global best
          final topTen = await LeaderboardService.instance.getTopTen();
          if (topTen.isNotEmpty) targetScore = topTen.first.score;
        }
      } else {
        final topTen = await LeaderboardService.instance.getTopTen();
        if (topTen.isNotEmpty) targetScore = topTen.first.score;
      }
    } catch (e) {
      debugPrint('Error fetching leaderboard: $e');
    }

    if (mounted) {
      setState(() {
        _scoreLabel = label;
        _isLoadingScore = false;
        
        _scoreCounterAnimation = IntTween(begin: 0, end: targetScore).animate(
          CurvedAnimation(parent: _scoreCounterController, curve: Curves.easeOutCubic),
        );
      });
      _scoreCounterController.forward();
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _floatController.dispose();
    _entranceController.dispose();
    _shimmerController.dispose();
    _scoreCounterController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          // Radial Light Bloom
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

          // Top Section: High Score
          Positioned(
            top: 60,
            left: 0,
            right: 0,
            child: FadeTransition(
              opacity: _opacityAnimation,
              child: Column(
                children: [
                  Text(
                    _scoreLabel,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                      letterSpacing: 6,
                      fontWeight: FontWeight.w300,
                    ),
                  ),
                  const SizedBox(height: 4),
                  if (_isLoadingScore)
                    const SizedBox(
                      height: 44,
                      width: 44,
                      child: Padding(
                        padding: EdgeInsets.all(12.0),
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.cyanAccent,
                        ),
                      ),
                    )
                  else
                    AnimatedBuilder(
                      animation: _scoreCounterAnimation,
                      builder: (context, child) {
                        return Text(
                          '${_scoreCounterAnimation.value}',
                          style: const TextStyle(
                            color: Colors.cyanAccent,
                            fontSize: 36,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 2,
                          ),
                        );
                      },
                    ),
                ],
              ),
            ),
          ),

          // Center Section: Title and Buttons
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(height: 40),
                
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
                          height: 100,
                          child: Stack(
                            clipBehavior: Clip.none,
                            alignment: Alignment.center,
                            children: [
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
                                      ..blendMode = BlendMode.plus,
                                  ),
                                ),
                              ),
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
                                      ..blendMode = BlendMode.plus,
                                  ),
                                ),
                              ),
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
                      widget.game.overlays.add(Overlays.leaderboard);
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
                  AudioManager.instance.playSfx('button.wav');
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
    with TickerProviderStateMixin {
  bool _isPressed = false;
  late AnimationController _glowController;
  late AnimationController _scaleController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _glowController = AnimationController(
        vsync: this, duration: const Duration(seconds: 2))
      ..repeat(reverse: true);

    _scaleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(parent: _scaleController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _glowController.dispose();
    _scaleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final baseColor = widget.primary ? Colors.cyanAccent : Colors.white;
    final opacity = widget.primary ? 0.15 : 0.05;

    return GestureDetector(
      onTapDown: (_) {
        setState(() => _isPressed = true);
        _scaleController.forward();
      },
      onTapUp: (_) {
        setState(() => _isPressed = false);
        _scaleController.reverse();
      },
      onTapCancel: () {
        setState(() => _isPressed = false);
        _scaleController.reverse();
      },
      onTap: widget.onPressed,
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: AnimatedBuilder(
          animation: _glowController,
          builder: (context, child) {
            return Container(
              width: 280,
              padding: const EdgeInsets.symmetric(vertical: 18),
              decoration: BoxDecoration(
                color: baseColor.withValues(alpha: _isPressed ? opacity + 0.1 : opacity),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: widget.primary
                      ? baseColor.withValues(alpha: 0.3 + (0.4 * _glowController.value))
                      : baseColor.withValues(alpha: 0.2),
                  width: 2,
                ),
                boxShadow: widget.primary
                    ? [
                        BoxShadow(
                          color: baseColor.withValues(alpha: 0.1 + (0.2 * _glowController.value)),
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
      ),
    );
  }
}
