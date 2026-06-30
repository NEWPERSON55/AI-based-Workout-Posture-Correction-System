import 'package:firebase_auth/firebase_auth.dart';
import '../../domain/entities/user_profile.dart';
import '../../domain/repositories/auth_repository.dart';
import '../datasources/firebase_auth_datasource.dart';
import '../datasources/firestore_datasource.dart';

class AuthRepositoryImpl implements AuthRepository {
  final FirebaseAuthDatasource _authDatasource;
  final FirestoreDatasource _firestoreDatasource;

  AuthRepositoryImpl(this._authDatasource, this._firestoreDatasource);

  @override
  Future<User> signIn(String email, String password) async {
    final credential = await _authDatasource.signIn(email, password);
    return credential.user!;
  }

  @override
  Future<User> signUp(String name, String email, String password) async {
    final credential = await _authDatasource.signUp(name, email, password);
    final user = credential.user!;

    // Create initial Firestore profile
    final profile = UserProfile(
      uid: user.uid,
      name: name.trim(),
      email: email.trim(),
      createdAt: DateTime.now(),
    );
    await _firestoreDatasource.saveUserProfile(user.uid, profile);

    return user;
  }

  @override
  Future<void> resetPassword(String email) {
    return _authDatasource.resetPassword(email);
  }

  @override
  Future<void> signOut() => _authDatasource.signOut();

  @override
  Stream<User?> get authStateChanges => _authDatasource.authStateChanges;

  @override
  User? get currentUser => _authDatasource.currentUser;
}
