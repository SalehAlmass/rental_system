part of 'user_management_bloc.dart';

abstract class UserManagementEvent extends Equatable {
  const UserManagementEvent();

  @override
  List<Object?> get props => [];
}

class LoadUsers extends UserManagementEvent {}

class CreateUser extends UserManagementEvent {
  final String username;
  final String password;
  final String role;

  const CreateUser({
    required this.username,
    required this.password,
    required this.role,
  });

  @override
  List<Object> get props => [username, password, role];
}

class UpdateUser extends UserManagementEvent {
  final int id;
  final String? username;
  final String? password;
  final String? role;
  final bool? isActive;

  const UpdateUser({
    required this.id,
    this.username,
    this.password,
    this.role,
    this.isActive,
  });

  @override
  List<Object?> get props => [id, username, password, role, isActive];
}

class DeleteUser extends UserManagementEvent {
  final int id;

  const DeleteUser({required this.id});

  @override
  List<Object> get props => [id];
}

class ChangeUserRole extends UserManagementEvent {
  final int id;
  final String newRole;

  const ChangeUserRole({
    required this.id,
    required this.newRole,
  });

  @override
  List<Object> get props => [id, newRole];
}
class ChangeUserPassword extends UserManagementEvent {
  final int id;
  final String newPassword;

  ChangeUserPassword({required this.id, required this.newPassword});
}
