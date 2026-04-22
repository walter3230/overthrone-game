import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AuthService {
  AuthService._();
  static final AuthService I = AuthService._();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final ValueNotifier<User?> currentUser = ValueNotifier(null);

  bool get isLoggedIn => _auth.currentUser != null;
  String get uid => _auth.currentUser?.uid ?? '';
  String get displayName =>
      _auth.currentUser?.displayName ?? 'Player_${uid.substring(0, 6)}';

  Future<void> init() async {
    _auth.authStateChanges().listen((u) => currentUser.value = u);
    if (_auth.currentUser == null) {
      await signInAnonymously();
    }
  }

  Future<void> signInAnonymously() async {
    try {
      await _auth.signInAnonymously();
    } catch (e) {
      debugPrint('Anonymous sign-in failed: $e');
    }
  }

  Future<void> linkWithGoogle() async {
    try {
      final provider = GoogleAuthProvider();
      await _auth.currentUser?.linkWithProvider(provider);
    } catch (e) {
      debugPrint('Google link failed: $e');
    }
  }

  Future<void> signOut() async {
    await _auth.signOut();
  }
}
