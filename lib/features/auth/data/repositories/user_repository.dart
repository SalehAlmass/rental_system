import 'package:dio/dio.dart';
import 'package:rental_app/core/network/api_client.dart';
import 'package:rental_app/features/auth/domain/entities/user_model.dart';

abstract class UserRepository {
  Future<List<User>> getUsers();
  Future<User> createUser({required String username, required String password, required String role});
  Future<User> updateUser({required int id, String? username, String? password, String? role, bool? isActive});
  Future<void> deleteUser({required int id});
  Future<User> changeUserRole({required int id, required String newRole});
}

class UserRepositoryImpl implements UserRepository {
  final ApiClient _apiClient;

  UserRepositoryImpl(this._apiClient);

  @override
  Future<List<User>> getUsers() async {
    try {
      final response = await _apiClient.dio.get('/users');
      if (response.data is List) {
        return (response.data as List).map((json) => User.fromJson(json)).toList();
      }
      return [];
    } on DioException catch (e) {
      throw Exception('Failed to load users: ${e.message}');
    }
  }

  @override
  Future<User> createUser({required String username, required String password, required String role}) async {
    try {
      final response = await _apiClient.dio.post('/users', data: {
        'username': username,
        'password': password,
        'role': role,
      });
      return User.fromJson(response.data);
    } on DioException catch (e) {
      throw Exception('Failed to create user: ${e.message}');
    }
  }

  @override
  Future<User> updateUser({required int id, String? username, String? password, String? role, bool? isActive}) async {
    try {
      final data = <String, dynamic>{};
      if (username != null) data['username'] = username;
      if (password != null) data['password'] = password;
      if (role != null) data['role'] = role;
      if (isActive != null) data['is_active'] = isActive ? 1 : 0;

      final response = await _apiClient.dio.put('/users/$id', data: data);
      return User.fromJson(response.data);
    } on DioException catch (e) {
      throw Exception('Failed to update user: ${e.message}');
    }
  }

  @override
  Future<void> deleteUser({required int id}) async {
    try {
      await _apiClient.dio.delete('/users/$id');
    } on DioException catch (e) {
      throw Exception('Failed to delete user: ${e.message}');
    }
  }

  @override
  Future<User> changeUserRole({required int id, required String newRole}) async {
    try {
      final response = await _apiClient.dio.put('/users/$id/role', data: {
        'role': newRole,
      });
      return User.fromJson(response.data);
    } on DioException catch (e) {
      throw Exception('Failed to change user role: ${e.message}');
    }
  }
}