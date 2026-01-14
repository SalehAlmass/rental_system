part of 'auth_bloc.dart';

enum AuthStatus { initial, loading, authenticated, registerSuccess, failure }

class AuthState extends Equatable {
  const AuthState({required this.status, this.user, this.error});

  const AuthState.initial()
    : status = AuthStatus.initial,
      user = null,
      error = null;

  final AuthStatus status;
  final Map<String, dynamic>? user;
  final String? error;
  
  AuthState copyWith({
    AuthStatus? status,
    Map<String, dynamic>? user,
    String? error,
  }) {
    return AuthState(
      status: status ?? this.status,
      user: user ?? this.user,
      error: error,
    );
  }

  @override
  List<Object?> get props => [status, user, error];
}
