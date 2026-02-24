import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Data model for a leaderboard entry.
class LeaderboardEntry {
  final String uid;
  final String username;
  final int score;

  const LeaderboardEntry({
    required this.uid,
    required this.username,
    required this.score,
  });

  factory LeaderboardEntry.fromDoc(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return LeaderboardEntry(
      uid:      data['uid']      as String? ?? '',
      username: data['username'] as String? ?? '???',
      score:    data['score']    as int?    ?? 0,
    );
  }
}

/// Handles all Firestore leaderboard reads and writes.
class LeaderboardService {
  LeaderboardService._();
  static final LeaderboardService instance = LeaderboardService._();

  final _db   = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  CollectionReference<Map<String, dynamic>> get _col =>
      _db.collection('leaderboard');

  // ── Write ───────────────────────────────────────────────────────────────────

  /// Creates or updates the current user's document.
  /// Only updates if [score] is strictly greater than the stored score.
  /// This also creates the document on the very first call (no prior saveScore(0)).
  Future<void> saveScore(String username, int score) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;

    final ref = _col.doc(uid);
    await _db.runTransaction((tx) async {
      final snap = await tx.get(ref);
      final existing = snap.exists ? (snap.data()!['score'] as int? ?? 0) : -1;
      if (score > existing) {
        tx.set(ref, {
          'uid':       uid,
          'username':  username,
          'score':     score,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
    });
  }

  // ── Read ────────────────────────────────────────────────────────────────────

  /// Fetches top 10 entries ordered by score descending.
  Future<List<LeaderboardEntry>> getTopTen() async {
    final snap = await _col
        .orderBy('score', descending: true)
        .limit(10)
        .get();
    return snap.docs.map(LeaderboardEntry.fromDoc).toList();
  }

  /// Returns this user's leaderboard document, or null if not yet saved.
  Future<LeaderboardEntry?> getMyEntry() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return null;
    final snap = await _col.doc(uid).get();
    if (!snap.exists) return null;
    return LeaderboardEntry.fromDoc(snap);
  }

  /// Rank = number of users with a score strictly greater than [myScore] + 1.
  Future<int> getMyRank(int myScore) async {
    final snap = await _col
        .where('score', isGreaterThan: myScore)
        .count()
        .get();
    return (snap.count ?? 0) + 1;
  }

  /// Returns the stored username for the current user, or null.
  Future<String?> getMyUsername() async {
    final entry = await getMyEntry();
    return entry?.username;
  }
}
