import 'package:dio/dio.dart';
import 'package:rental_app/core/network/api_client.dart';
import 'package:rental_app/core/storage/token_storage.dart';
import 'package:rental_app/core/network/failure.dart';
import 'package:rental_app/features/auth/domain/entities/models.dart';

class AuthRepository {
  AuthRepository(this._api, this._tokenStorage);

  final ApiClient _api;
  final TokenStorage _tokenStorage;

  Future<LoginResponse> login({required String username, required String password}) async {
    try {
      final res = await _api.dio.post('auth/login', data: {
        'username': username,
        'password': password,
      });

      final data = (res.data as Map).cast<String, dynamic>();
      final lr = LoginResponse.fromJson(data);
      if (lr.token.isEmpty) throw ApiFailure("Token not returned");
      await _tokenStorage.saveToken(lr.token);
      return lr;
    } on DioException catch (e) {
      final msg = (e.response?.data is Map && (e.response?.data['error'] != null))
          ? e.response?.data['error'].toString()
          : (e.message ?? 'Login failed');
      throw ApiFailure(msg ?? 'Failed', statusCode: e.response?.statusCode);
    }
  }
Future<void> forgotPassword({required String username}) async {
  try {
    await _api.dio.post('auth/forgot-password', data: {
      'username': username,
    });
  } on DioException catch (e) {
    final msg = (e.response?.data is Map && e.response?.data['error'] != null)
        ? e.response?.data['error'].toString()
        : (e.message ?? 'Request failed');
    throw ApiFailure(msg ?? 'Failed', statusCode: e.response?.statusCode);
  }
}

  Future<void> logout() => _tokenStorage.clear();
  Future<void> register({
  required String username,
  required String password,
  String role = 'user',
}) async {
  try {
    await _api.dio.post('auth/register', data: {
      'username': username,
      'password': password,
      'role': role,
    });
  } on DioException catch (e) {
    final msg = (e.response?.data is Map && e.response?.data['error'] != null)
        ? e.response?.data['error'].toString()
        : (e.message ?? 'Register failed');
    throw ApiFailure(msg ?? 'Failed', statusCode: e.response?.statusCode);
  }
}
Future<void> changePassword({
  required String oldPassword,
  required String newPassword,
}) async {
  try {
    await _api.dio.post('auth/change-password', data: {
      'old_password': oldPassword,
      'new_password': newPassword,
    });
  } on DioException catch (e) {
    final msg = (e.response?.data is Map && e.response?.data['error'] != null)
        ? e.response?.data['error'].toString()
        : (e.message ?? 'Change password failed');
    throw ApiFailure(msg ?? 'Failed', statusCode: e.response?.statusCode);
  }
}

}