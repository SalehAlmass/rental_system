part of 'auth_bloc.dart';

enum AuthStatus { initial, loading, authenticated, registerSuccess, failure }

/// AuthState صار مسؤول فقط عن حالة الجلسة + التوكن.
/// بيانات المستخدم (مثل username/role) يتم جلبها من auth/profile عبر ProfileCubit.
class AuthState extends Equatable {
  const AuthState({required this.status, this.token, this.error});

  const AuthState.initial()
      : status = AuthStatus.initial,
        token = null,
        error = null;

  final AuthStatus status;
  final String? token;
  final String? error;

  AuthState copyWith({
    AuthStatus? status,
    String? token,
    String? error,
  }) {
    return AuthState(
      status: status ?? this.status,
      token: token ?? this.token,
      error: error,
    );
  }

  @override
  List<Object?> get props => [status, token, error];
}
