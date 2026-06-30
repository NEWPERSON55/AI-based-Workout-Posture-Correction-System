import 'package:firebase_auth/firebase_auth.dart';

/// Wrapper around [FirebaseAuth] for clean architecture separation.
class FirebaseAuthDatasource {
  final FirebaseAuth _auth;

  FirebaseAuthDatasource({FirebaseAuth? auth})
      : _auth = auth ?? FirebaseAuth.instance;

  /// Sign in with email and password.
  Future<UserCredential> signIn(String email, String password) {
    return _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
  }

  /// Create a new account and set the display name.
  Future<UserCredential> signUp(
      String name, String email, String password) async {
    final credential = await _auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    await credential.user?.updateDisplayName(name.trim());
    return credential;
  }

  /// Send a password-reset email.
  Future<void> resetPassword(String email) {
    return _auth.sendPasswordResetEmail(email: email.trim());
  }

  /// Sign out the current user.
  Future<void> signOut() => _auth.signOut();

  /// Stream that emits whenever auth state changes.
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  /// The currently signed-in user, or null.
  User? get currentUser => _auth.currentUser;
}
