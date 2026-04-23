import 'package:equatable/equatable.dart';
import '../../models/profile_model.dart';

abstract class AuthState extends Equatable {
  const AuthState();

  @override
  List<Object?> get props => [];
}

class AuthInitial extends AuthState {}

class AuthLoading extends AuthState {}

class AuthAuthenticated extends AuthState {
  final ProfileModel profile;

  const AuthAuthenticated(this.profile);

  @override
  List<Object?> get props => [profile];
}

class AuthUnauthenticated extends AuthState {}

class AuthOfflineGuest extends AuthState {}

class AuthBlocked extends AuthState {
  final ProfileModel profile;
  final String message;

  const AuthBlocked(this.profile, this.message);

  @override
  List<Object?> get props => [profile, message];
}

class AuthError extends AuthState {
  final String message;

  const AuthError(this.message);

  @override
  List<Object?> get props => [message];
}
