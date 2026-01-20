part of 'user_management_bloc.dart';

abstract class UserManagementState extends Equatable {
  const UserManagementState();

  @override
  List<Object?> get props => [];
}

class UserManagementInitial extends UserManagementState {}

class UserManagementPasswordChanged extends UserManagementState {}


class UserManagementLoading extends UserManagementState {}

class UserManagementLoaded extends UserManagementState {
  final List<User> users;

  const UserManagementLoaded(this.users);

  @override
  List<Object> get props => [users];
}

class UserManagementError extends UserManagementState {
  final String message;

  const UserManagementError(this.message);

  @override
  List<Object> get props => [message];
}