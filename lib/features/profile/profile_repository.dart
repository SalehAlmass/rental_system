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
    return (res.data as Map).cast<String, dynamic>();
  } on DioException catch (e) {
      throw ApiFailure.fromDio(e);
    }
}

}
