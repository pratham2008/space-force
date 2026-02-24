import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../services/leaderboard_service.dart';
import '../zero_vector_game.dart';
import 'common/overlay_anim_container.dart';

class CreateUsernameOverlay extends StatefulWidget {
  static const String id = Overlays.createUsername;
  final ZeroVectorGame game;

  const CreateUsernameOverlay({super.key, required this.game});

  @override
  State<CreateUsernameOverlay> createState() => _CreateUsernameOverlayState();
}

class _CreateUsernameOverlayState extends State<CreateUsernameOverlay> {
  final _controller = TextEditingController();
  bool _loading = false;
  String? _error;
  bool _isValid = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_validate);
  }

  void _validate() {
    final text = _controller.text;
    final sanitized = text.trim().toLowerCase();
    
    // Quick real-time validation feedback
    bool valid = sanitized.length >= 3 && 
                 sanitized.length <= 20 && 
                 !sanitized.contains(' ');
    
    if (valid != _isValid || _error != null) {
      setState(() {
        _isValid = valid;
        _error = null;
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_isValid) return;

    setState(() {
      _loading = true;
      _error   = null;
    });

    try {
      final username = await AuthService.instance.createUser(_controller.text);
      await LeaderboardService.instance.saveScore(username, widget.game.score);

      if (mounted) {
        widget.game.overlays.remove(Overlays.createUsername);
        // We stay on the current screen (GameOver) but show a success hint
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('SCORE SAVED TO CLOUD'),
            backgroundColor: Color(0xFF00E5FF),
          ),
        );
      }
    } on Exception catch (e) {
      if (mounted) {
        setState(() {
          _error   = e.toString().replaceFirst('Exception: ', '');
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black.withValues(alpha: 0.8),
      child: Center(
        child: OverlayAnimContainer(
          child: Container(
            width: 320,
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: const Color(0xFF0A0A1A),
              borderRadius: BorderRadius.circular(28),
              border: Border.all(
                color: const Color(0xFF00E5FF).withValues(alpha: 0.4),
                width: 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF00E5FF).withValues(alpha: 0.2),
                  blurRadius: 40,
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  '🎉 SAVE YOUR SCORE',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 2,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Enter a unique username to compete globally.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.white.withValues(alpha: 0.5),
                  ),
                ),
                const SizedBox(height: 32),

                // ── Input ───────────────────────────────────────────────────
                TextField(
                  controller:     _controller,
                  enabled:        !_loading,
                  autofocus:      true,
                  maxLength:      20,
                  textAlign:      TextAlign.center,
                  style:          const TextStyle(color: Colors.white, fontSize: 18),
                  cursorColor:    const Color(0xFF00E5FF),
                  decoration: InputDecoration(
                    hintText:       'username',
                    hintStyle:      TextStyle(color: Colors.white.withValues(alpha: 0.2)),
                    counterText:    '',
                    contentPadding: const EdgeInsets.symmetric(vertical: 16),
                    enabledBorder:  UnderlineInputBorder(
                      borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
                    ),
                    focusedBorder:  const UnderlineInputBorder(
                      borderSide: BorderSide(color: Color(0xFF00E5FF), width: 2),
                    ),
                  ),
                  onSubmitted: (_) => _submit(),
                ),

                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    _error!,
                    style: const TextStyle(color: Color(0xFFFF1744), fontSize: 13),
                    textAlign: TextAlign.center,
                  ),
                ],

                const SizedBox(height: 32),

                // ── Action Buttons ───────────────────────────────────────────
                Row(
                  children: [
                    Expanded(
                      child: _SmallActionBtn(
                        label: 'CANCEL',
                        onPressed: () => widget.game.overlays.remove(Overlays.createUsername),
                        isGhost: true,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _SmallActionBtn(
                        label: _loading ? '...' : 'SAVE',
                        onPressed: _loading ? () {} : _submit,
                        active: _isValid && !_loading,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SmallActionBtn extends StatelessWidget {
  final String label;
  final VoidCallback onPressed;
  final bool active;
  final bool isGhost;

  const _SmallActionBtn({
    required this.label,
    required this.onPressed,
    this.active = true,
    this.isGhost = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: active ? onPressed : null,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 200),
        opacity: active ? 1.0 : 0.3,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: isGhost ? Colors.transparent : const Color(0xFF00E5FF),
            borderRadius: BorderRadius.circular(12),
            border: isGhost ? Border.all(color: Colors.white.withValues(alpha: 0.1)) : null,
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w900,
                letterSpacing: 2,
                color: isGhost ? Colors.white.withValues(alpha: 0.6) : Colors.black,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
