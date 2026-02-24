import 'dart:math';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// Handles Firebase Auth for SPACE FORCE.
/// Users authenticate anonymously via a derived email + random password,
/// exposing only a username to the rest of the app.
class AuthService {
  AuthService._();
  static final AuthService instance = AuthService._();

  final _auth = FirebaseAuth.instance;
  final _db   = FirebaseFirestore.instance;

  // ── State ───────────────────────────────────────────────────────────────────

  bool get isLoggedIn => _auth.currentUser != null;
  String? get uid     => _auth.currentUser?.uid;

  // ── Username uniqueness ─────────────────────────────────────────────────────

  /// Returns true if [username] is already taken.
  /// Uses .where().limit(1) to avoid full collection scans.
  Future<bool> isUsernameTaken(String username) async {
    final snap = await _db
        .collection('leaderboard')
        .where('username', isEqualTo: username)
        .limit(1)
        .get();
    return snap.docs.isNotEmpty;
  }

  // ── Account creation ────────────────────────────────────────────────────────

  /// Sanitizes [rawUsername], checks availability, and creates a Firebase
  /// account. Returns the sanitized username on success, throws on failure.
  ///
  /// Does NOT write to Firestore — the first [LeaderboardService.saveScore]
  /// call creates the document.
  Future<String> createUser(String rawUsername) async {
    final username = _sanitize(rawUsername);

    if (username.length < 3 || username.length > 20) {
      throw Exception('Username must be 3–20 characters.');
    }

    if (await isUsernameTaken(username)) {
      throw Exception('Username "$username" is already taken.');
    }

    final email    = '$username@spaceforce.game';
    final password = _generatePassword();

    await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );

    return username;
  }

  // ── Helpers ─────────────────────────────────────────────────────────────────

  /// Lowercase, trim, collapse spaces to underscores.
  String _sanitize(String input) =>
      input.trim().toLowerCase().replaceAll(RegExp(r'\s+'), '_');

  /// Generates a cryptographically random 16-character alphanumeric password.
  String _generatePassword() {
    const chars =
        'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final rng = Random.secure();
    return List.generate(16, (_) => chars[rng.nextInt(chars.length)]).join();
  }
}
