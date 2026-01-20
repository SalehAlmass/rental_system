import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:rental_app/features/auth/domain/entities/user_model.dart';
import 'package:rental_app/features/auth/data/repositories/user_repository.dart';

part 'user_management_event.dart';
part 'user_management_state.dart';

class UserManagementBloc
    extends Bloc<UserManagementEvent, UserManagementState> {
  final UserRepository userRepository;

  UserManagementBloc(this.userRepository) : super(UserManagementInitial()) {
    on<LoadUsers>(_onLoadUsers);
    on<CreateUser>(_onCreateUser);
    on<UpdateUser>(_onUpdateUser);
    on<DeleteUser>(_onDeleteUser);
    on<ChangeUserRole>(_onChangeUserRole);
    on<ChangeUserPassword>(_onChangeUserPassword);
  }

  void _onLoadUsers(LoadUsers event, Emitter<UserManagementState> emit) async {
    emit(UserManagementLoading());
    try {
      final users = await userRepository.getUsers();
      emit(UserManagementLoaded(users));
    } catch (e) {
      emit(UserManagementError(e.toString()));
    }
  }

  void _onCreateUser(
    CreateUser event,
    Emitter<UserManagementState> emit,
  ) async {
    try {
      final user = await userRepository.createUser(
        username: event.username,
        password: event.password,
        role: event.role,
      );

      if (state is UserManagementLoaded) {
        final currentState = state as UserManagementLoaded;
        emit(UserManagementLoaded([...currentState.users, user]));
      }
    } catch (e) {
      emit(UserManagementError(e.toString()));
    }
  }

  void _onUpdateUser(
    UpdateUser event,
    Emitter<UserManagementState> emit,
  ) async {
    try {
      final user = await userRepository.updateUser(
        id: event.id,
        username: event.username,
        password: event.password,
        role: event.role,
        isActive: event.isActive,
      );

      if (state is UserManagementLoaded) {
        final currentState = state as UserManagementLoaded;
        final updatedUsers = currentState.users
            .map((u) => u.id == user.id ? user : u)
            .toList();
        emit(UserManagementLoaded(updatedUsers));
      }
    } catch (e) {
      emit(UserManagementError(e.toString()));
    }
  }

  void _onDeleteUser(
    DeleteUser event,
    Emitter<UserManagementState> emit,
  ) async {
    try {
      await userRepository.deleteUser(id: event.id);

      if (state is UserManagementLoaded) {
        final currentState = state as UserManagementLoaded;
        final filteredUsers = currentState.users
            .where((u) => u.id != event.id)
            .toList();
        emit(UserManagementLoaded(filteredUsers));
      }
    } catch (e) {
      emit(UserManagementError(e.toString()));
    }
  }

  void _onChangeUserRole(
    ChangeUserRole event,
    Emitter<UserManagementState> emit,
  ) async {
    try {
      final user = await userRepository.changeUserRole(
        id: event.id,
        newRole: event.newRole,
      );

      if (state is UserManagementLoaded) {
        final currentState = state as UserManagementLoaded;
        final updatedUsers = currentState.users
            .map((u) => u.id == user.id ? user : u)
            .toList();
        emit(UserManagementLoaded(updatedUsers));
      }
    } catch (e) {
      emit(UserManagementError(e.toString()));
    }
  }

  void _onChangeUserPassword(
    ChangeUserPassword event,
    Emitter<UserManagementState> emit,
  ) async {
    try {
      // تحديث كلمة المرور فقط
      final user = await userRepository.updateUser(
        id: event.id,
        password: event.newPassword,
      );

      // بعد نجاح التحديث، قم بإعادة تحميل المستخدمين
      final users = await userRepository.getUsers();
      emit(UserManagementLoaded(users));
    } catch (e) {
      emit(UserManagementError(e.toString()));
    }
  }
}
