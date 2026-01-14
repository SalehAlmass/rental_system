part of 'auth_bloc.dart';

sealed class AuthEvent extends Equatable {
  const AuthEvent();
  @override
  List<Object?> get props => [];
}

final class LoginSubmitted extends AuthEvent {
  const LoginSubmitted({required this.username, required this.password});
  final String username;
  final String password;

  @override
  List<Object?> get props => [username, password];
}

final class LogoutRequested extends AuthEvent {}

final class RegisterSubmitted extends AuthEvent {
  const RegisterSubmitted({
    required this.username,
    required this.password,
    required this.role,
  });

  final String username;
  final String password;
  final String role;

  @override
  List<Object?> get props => [username, password, role];
}
final class ForgotPasswordSubmitted extends AuthEvent {
  const ForgotPasswordSubmitted({required this.username});
  final String username;

  @override
  List<Object?> get props => [username];
}
final class ChangePasswordSubmitted extends AuthEvent {
  const ChangePasswordSubmitted({
    required this.oldPassword,
    required this.newPassword,
  });

  final String oldPassword;
  final String newPassword;

  @override
  List<Object?> get props => [oldPassword, newPassword];
}
