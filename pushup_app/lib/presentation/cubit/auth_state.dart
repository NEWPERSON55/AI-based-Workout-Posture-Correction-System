import 'package:equatable/equatable.dart';

/// Auth states for login, sign-up, and forgot-password flows.
abstract class AuthState extends Equatable {
  const AuthState();
  @override
  List<Object?> get props => [];
}

class AuthInitial extends AuthState {
  final bool isPasswordVisible;
  final bool isConfirmPasswordVisible;
  final bool termsAccepted;

  const AuthInitial({
    this.isPasswordVisible = false,
    this.isConfirmPasswordVisible = false,
    this.termsAccepted = false,
  });

  @override
  List<Object?> get props =>
      [isPasswordVisible, isConfirmPasswordVisible, termsAccepted];
}

class AuthLoading extends AuthState {
  const AuthLoading();
}

class AuthSuccess extends AuthState {
  final String message;
  final String uid;
  const AuthSuccess(this.message, {this.uid = ''});

  @override
  List<Object?> get props => [message, uid];
}

class AuthAuthenticated extends AuthState {
  final String uid;
  final String displayName;
  final String email;
  const AuthAuthenticated({
    required this.uid,
    required this.displayName,
    required this.email,
  });

  @override
  List<Object?> get props => [uid, displayName, email];
}

class AuthError extends AuthState {
  final String message;
  const AuthError(this.message);

  @override
  List<Object?> get props => [message];
}
