import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:rental_app/features/auth/data/repositories/auth_repository_impl.dart';

part 'auth_event.dart';
part 'auth_state.dart';

class AuthBloc extends Bloc<AuthEvent, AuthState> {
  AuthBloc(this._repo) : super(const AuthState.initial()) {
    on<LoginSubmitted>(_onLoginSubmitted);
    on<LogoutRequested>(_onLogoutRequested);
    on<RegisterSubmitted>(_onRegisterSubmitted);
    on<ForgotPasswordSubmitted>(_onForgotPasswordSubmitted);
    on<ChangePasswordSubmitted>(_onChangePasswordSubmitted);
  }

  final AuthRepository _repo;

  Future<void> _onLoginSubmitted(
    LoginSubmitted event,
    Emitter<AuthState> emit,
  ) async {
    emit(state.copyWith(status: AuthStatus.loading, error: null));
    try {
      final lr = await _repo.login(
        username: event.username,
        password: event.password,
      );
      emit(state.copyWith(status: AuthStatus.authenticated, user: lr.user));
    } catch (e) {
      emit(state.copyWith(status: AuthStatus.failure, error: e.toString()));
    }
  }

  Future<void> _onLogoutRequested(
    LogoutRequested event,
    Emitter<AuthState> emit,
  ) async {
    await _repo.logout();
    emit(const AuthState.initial());
  }

  Future<void> _onRegisterSubmitted(
    RegisterSubmitted event,
    Emitter<AuthState> emit,
  ) async {
    emit(state.copyWith(status: AuthStatus.loading, error: null));
    try {
      await _repo.register(
        username: event.username,
        password: event.password,
        role: event.role,
      );
      emit(state.copyWith(status: AuthStatus.registerSuccess));
    } catch (e) {
      emit(state.copyWith(status: AuthStatus.failure, error: e.toString()));
    }
  }


Future<void> _onForgotPasswordSubmitted(
  ForgotPasswordSubmitted event,
  Emitter<AuthState> emit,
) async {
  emit(state.copyWith(status: AuthStatus.loading, error: null));
  try {
    await _repo.forgotPassword(username: event.username);
    emit(state.copyWith(status: AuthStatus.initial));
  } catch (e) {
    emit(state.copyWith(status: AuthStatus.failure, error: e.toString()));
  }
}


Future<void> _onChangePasswordSubmitted(
  ChangePasswordSubmitted event,
  Emitter<AuthState> emit,
) async {
  emit(state.copyWith(status: AuthStatus.loading, error: null));
  try {
    await _repo.changePassword(
      oldPassword: event.oldPassword,
      newPassword: event.newPassword,
    );
    emit(state.copyWith(status: AuthStatus.initial));
  } catch (e) {
    emit(state.copyWith(status: AuthStatus.failure, error: e.toString()));
  }
}

}
