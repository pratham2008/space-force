import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../services/leaderboard_service.dart';
import '../zero_vector_game.dart';
import 'common/overlay_anim_container.dart';

class LeaderboardOverlay extends StatefulWidget {
  static const String id = Overlays.leaderboard;
  final ZeroVectorGame game;

  const LeaderboardOverlay({super.key, required this.game});

  @override
  State<LeaderboardOverlay> createState() => _LeaderboardOverlayState();
}

class _LeaderboardOverlayState extends State<LeaderboardOverlay> {
  bool _loading = true;
  List<LeaderboardEntry> _topTen = [];
  LeaderboardEntry? _myEntry;
  int _myRank = 0;
  bool _myInTopTen = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final results = await Future.wait([
      LeaderboardService.instance.getTopTen(),
      LeaderboardService.instance.getMyEntry(),
    ]);

    final topTen  = results[0] as List<LeaderboardEntry>;
    final myEntry = results[1] as LeaderboardEntry?;

    int rank = 0;
    bool inTop = false;

    if (myEntry != null) {
      inTop = topTen.any((e) => e.uid == myEntry.uid);
      if (!inTop) {
        rank = await LeaderboardService.instance.getMyRank(myEntry.score);
      } else {
        rank = topTen.indexWhere((e) => e.uid == myEntry.uid) + 1;
      }
    }

    if (mounted) {
      setState(() {
        _topTen     = topTen;
        _myEntry    = myEntry;
        _myRank     = rank;
        _myInTopTen = inTop;
        _loading    = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final myUid = AuthService.instance.uid;

    return Container(
      color: Colors.black.withValues(alpha: 0.95),
      child: SafeArea(
        child: OverlayAnimContainer(
          child: Column(
            children: [
              // ── Header ───────────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      onPressed: () {
                        widget.game.overlays.remove(Overlays.leaderboard);
                        if (widget.game.state == GameState.paused) {
                          widget.game.resumeEngine();
                        }
                      },
                      icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
                    ),
                    const Text(
                      'LEADERBOARD',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 4,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 48), // Spacer
                  ],
                ),
              ),

              // ── Top 3 Section (Optional/Visual) ───────────────────────
              // ... For brevity we'll stick to the animated list requirements

              // ── List or loader ──────────────────────────────────────────
              Expanded(
                child: _loading
                    ? const Center(child: CircularProgressIndicator(color: Color(0xFF00E5FF)))
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        itemCount: _topTen.length + (!_myInTopTen && _myEntry != null ? 2 : 0),
                        itemBuilder: (context, index) {
                          if (index < _topTen.length) {
                            return _buildRow(
                              rank:      index + 1,
                              entry:     _topTen[index],
                              highlight: _topTen[index].uid == myUid,
                            );
                          }
                          
                          // Handle personal rank separator and row
                          if (!_myInTopTen && _myEntry != null) {
                            if (index == _topTen.length) {
                              return const Padding(
                                padding: EdgeInsets.symmetric(vertical: 12),
                                child: Divider(color: Colors.white10),
                              );
                            }
                            return _buildRow(
                              rank:      _myRank,
                              entry:     _myEntry!,
                              highlight: true,
                            );
                          }
                          return const SizedBox.shrink();
                        },
                      ),
              ),

              // ── Footer ───────────────────────────────────────────────────
              Container(
                padding: const EdgeInsets.all(24),
                child: Row(
                  children: [
                    Expanded(
                      child: _ActionBtn(
                        label: 'MAIN MENU',
                        onPressed: widget.game.mainMenuCleanup,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _ActionBtn(
                        label: 'PLAY AGAIN',
                        onPressed: widget.game.restart,
                        primary: true,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRow({
    required int rank,
    required LeaderboardEntry entry,
    required bool highlight,
  }) {
    Color glowColor = Colors.transparent;
    if (rank == 1) glowColor = const Color(0xFFFFD700).withValues(alpha: 0.15); // Gold
    if (rank == 2) glowColor = const Color(0xFFC0C0C0).withValues(alpha: 0.1);  // Silver
    if (rank == 3) glowColor = const Color(0xFFCD7F32).withValues(alpha: 0.1);  // Bronze
    
    if (highlight) glowColor = const Color(0xFF00E5FF).withValues(alpha: 0.1);

    final textColor = highlight ? const Color(0xFF00E5FF) : Colors.white;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color:        glowColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: highlight 
              ? const Color(0xFF00E5FF).withValues(alpha: 0.3)
              : (rank <= 3 ? textColor.withValues(alpha: 0.1) : Colors.white.withValues(alpha: 0.05)),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          // Rank w/ Medal
          SizedBox(
            width: 40,
            child: Text(
              '#$rank',
              style: TextStyle(
                color:      textColor,
                fontSize:   14,
                fontWeight: rank <= 3 || highlight ? FontWeight.w900 : FontWeight.w400,
              ),
            ),
          ),
          // User
          Expanded(
            child: Text(
              entry.username,
              style: TextStyle(
                color:      textColor,
                fontSize:   15,
                fontWeight: highlight ? FontWeight.w800 : FontWeight.w500,
              ),
            ),
          ),
          // Score
          Text(
            entry.score.toString().padLeft(6, '0'),
            style: TextStyle(
              color:      textColor,
              fontSize:   16,
              fontWeight: FontWeight.w700,
              fontFamily: 'monospace',
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionBtn extends StatelessWidget {
  final String label;
  final VoidCallback onPressed;
  final bool primary;

  const _ActionBtn({required this.label, required this.onPressed, this.primary = false});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: primary ? const Color(0xFF00E5FF) : Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(12),
          border: !primary ? Border.all(color: Colors.white.withValues(alpha: 0.1)) : null,
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w900,
              letterSpacing: 2,
              color: primary ? Colors.black : Colors.white.withValues(alpha: 0.6),
            ),
          ),
        ),
      ),
    );
  }
}
