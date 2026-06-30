import 'package:flutter_bloc/flutter_bloc.dart';
import '../../domain/repositories/auth_repository.dart';
import 'auth_state.dart';

/// Cubit managing auth UI state with Firebase Auth.
class AuthCubit extends Cubit<AuthState> {
  final AuthRepository _authRepo;

  AuthCubit(this._authRepo) : super(const AuthInitial());

  void togglePasswordVisibility() {
    if (state is AuthInitial) {
      final s = state as AuthInitial;
      emit(AuthInitial(
        isPasswordVisible: !s.isPasswordVisible,
        isConfirmPasswordVisible: s.isConfirmPasswordVisible,
        termsAccepted: s.termsAccepted,
      ));
    }
  }

  void toggleConfirmPasswordVisibility() {
    if (state is AuthInitial) {
      final s = state as AuthInitial;
      emit(AuthInitial(
        isPasswordVisible: s.isPasswordVisible,
        isConfirmPasswordVisible: !s.isConfirmPasswordVisible,
        termsAccepted: s.termsAccepted,
      ));
    }
  }

  void toggleTerms() {
    if (state is AuthInitial) {
      final s = state as AuthInitial;
      emit(AuthInitial(
        isPasswordVisible: s.isPasswordVisible,
        isConfirmPasswordVisible: s.isConfirmPasswordVisible,
        termsAccepted: !s.termsAccepted,
      ));
    }
  }

  Future<void> login(String email, String password) async {
    if (email.trim().isEmpty || password.isEmpty) {
      emit(const AuthError('Please fill in all fields'));
      emit(const AuthInitial());
      return;
    }
    emit(const AuthLoading());
    try {
      final user = await _authRepo.signIn(email, password);
      emit(AuthSuccess('Login successful', uid: user.uid));
    } catch (e) {
      emit(AuthError(_parseFirebaseError(e.toString())));
      emit(const AuthInitial());
    }
  }

  Future<void> signUp(String name, String email, String password) async {
    if (name.trim().isEmpty || email.trim().isEmpty || password.isEmpty) {
      emit(const AuthError('Please fill in all fields'));
      emit(const AuthInitial());
      return;
    }
    emit(const AuthLoading());
    try {
      final user = await _authRepo.signUp(name, email, password);
      emit(AuthSuccess('Account created', uid: user.uid));
    } catch (e) {
      emit(AuthError(_parseFirebaseError(e.toString())));
      emit(const AuthInitial());
    }
  }

  Future<void> forgotPassword(String email) async {
    if (email.trim().isEmpty) {
      emit(const AuthError('Please enter your email'));
      emit(const AuthInitial());
      return;
    }
    emit(const AuthLoading());
    try {
      await _authRepo.resetPassword(email);
      emit(const AuthSuccess('Reset link sent'));
    } catch (e) {
      emit(AuthError(_parseFirebaseError(e.toString())));
      emit(const AuthInitial());
    }
  }

  Future<void> logout() async {
    await _authRepo.signOut();
    emit(const AuthInitial());
  }

  void reset() => emit(const AuthInitial());

  /// Make Firebase error messages more user-friendly.
  String _parseFirebaseError(String error) {
    if (error.contains('user-not-found')) {
      return 'No account found with this email';
    }
    if (error.contains('wrong-password') ||
        error.contains('invalid-credential')) {
      return 'Incorrect email or password';
    }
    if (error.contains('email-already-in-use')) {
      return 'An account already exists with this email';
    }
    if (error.contains('weak-password')) {
      return 'Password must be at least 6 characters';
    }
    if (error.contains('invalid-email')) {
      return 'Please enter a valid email address';
    }
    if (error.contains('network-request-failed')) {
      return 'Network error — check your connection';
    }
    return 'Authentication failed. Please try again.';
  }
}
