import 'package:dio/dio.dart';
import 'package:rental_app/core/network/failure.dart';

/// Repository لجلب بيانات المستخدم الحالي من السيرفر.
/// Endpoint: GET auth/profile (يتطلب Authorization: Bearer <token>)
class ProfileRepository {
  final Dio dio;
  ProfileRepository(this.dio);

  Future<Map<String, dynamic>> fetchProfile() async {
    try {
      final res = await dio.get('auth/profile');
      final map = (res.data as Map).cast<String, dynamic>();

      // إذا السيرفر يرجع: { success: true, data: {...} }
      if (map['data'] is Map) {
        return (map['data'] as Map).cast<String, dynamic>();
      }

      // fallback: إذا رجّع البيانات مباشرة
      return map;
    } on DioException catch (e) {
      final msg = (e.response?.data is Map && (e.response?.data['error'] != null))
          ? e.response?.data['error'].toString()
          : (e.message ?? 'Failed to load profile');

      throw ApiFailure(
        msg ?? 'Failed to load profile',
        statusCode: e.response?.statusCode,
      );
    }
  }
}
