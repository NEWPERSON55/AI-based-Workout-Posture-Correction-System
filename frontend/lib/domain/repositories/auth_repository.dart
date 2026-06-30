import 'package:firebase_auth/firebase_auth.dart';

/// Abstract auth repository.
abstract class AuthRepository {
  /// Sign in with email/password. Returns the Firebase User.
  Future<User> signIn(String email, String password);

  /// Create a new account and Firestore profile.
  Future<User> signUp(String name, String email, String password);

  /// Send a password-reset email.
  Future<void> resetPassword(String email);

  /// Sign out.
  Future<void> signOut();

  /// Stream of auth state changes.
  Stream<User?> get authStateChanges;

  /// The currently signed-in user, or null.
  User? get currentUser;
}
