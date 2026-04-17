import 'package:equatable/equatable.dart';

abstract class AuthEvent extends Equatable {
  const AuthEvent();

  @override
  List<Object?> get props => [];
}

class AuthCheckStatus extends AuthEvent {}

class AuthSignUpRequested extends AuthEvent {
  final String email;
  final String password;
  final String fullName;
  final String role;
  final String? phone;
  // Helper-specific fields
  final String? occupation;
  final String? state;

  const AuthSignUpRequested({
    required this.email,
    required this.password,
    required this.fullName,
    required this.role,
    this.phone,
    this.occupation,
    this.state,
  });

  @override
  List<Object?> get props =>
      [email, password, fullName, role, phone, occupation, state];
}

class AuthSignInRequested extends AuthEvent {
  final String email;
  final String password;

  const AuthSignInRequested({
    required this.email,
    required this.password,
  });

  @override
  List<Object?> get props => [email, password];
}

class AuthSignOutRequested extends AuthEvent {}
