import 'package:dio/dio.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/failure.dart';

class BackupItem {
  final String file; // اسم الملف
  final int size;    // bytes
  final String createdAt;

  const BackupItem({required this.file, required this.size, required this.createdAt});

  factory BackupItem.fromJson(Map<String, dynamic> json) {
    // API عندك يرجع: name, size_bytes, modified_at (أو created_at حسب نسختك)
    final name = (json['file'] ?? json['name'] ?? '').toString();
    final sizeBytes = (json['size'] ?? json['size_bytes'] ?? 0);
    final created = (json['created_at'] ?? json['modified_at'] ?? json['createdAt'] ?? '').toString();

    return BackupItem(
      file: name,
      size: (sizeBytes is num) ? sizeBytes.toInt() : int.tryParse(sizeBytes.toString()) ?? 0,
      createdAt: created,
    );
  }
}

class BackupRepository {
  BackupRepository(this._api);
  final ApiClient _api;

  Future<List<BackupItem>> list() async {
    try {
      final res = await _api.dio.get('backup/list');
      dynamic raw = res.data;
      if (raw is Map) raw = raw['data'] ?? raw['items'] ?? raw['backups'] ?? [];
      if (raw is! List) return const [];
      return raw.map((e) => BackupItem.fromJson((e as Map).cast<String, dynamic>())).toList();
    } on DioException catch (e) {
      final data = e.response?.data;
      final msg = (data is Map && data['error'] != null)
          ? data['error'].toString()
          : (e.message ?? 'Backup list failed');
      throw ApiFailure(msg, statusCode: e.response?.statusCode);
    }
  }

  Future<void> create({String type = 'full'}) async {
    try {
      await _api.dio.post('backup/create', data: {'type': type});
    } on DioException catch (e) {
      final data = e.response?.data;
      final msg = (data is Map && data['error'] != null)
          ? data['error'].toString()
          : (e.message ?? 'Backup create failed');
      throw ApiFailure(msg, statusCode: e.response?.statusCode);
    }
  }

  Future<void> restore({required String file}) async {
    try {
      // API عندك يتوقع key اسمها "name"
      await _api.dio.post('backup/restore', data: {'name': file});
    } on DioException catch (e) {
      final data = e.response?.data;
      final msg = (data is Map && data['error'] != null)
          ? data['error'].toString()
          : (e.message ?? 'Backup restore failed');
      throw ApiFailure(msg, statusCode: e.response?.statusCode);
    }
  }

  // ✅ حذف نسخة واحدة
  Future<void> delete({required String file}) async {
    try {
      await _api.dio.delete(
        'backup/delete',
        queryParameters: {'name': file},
      );
    } on DioException catch (e) {
      final data = e.response?.data;
      final msg = (data is Map && data['error'] != null)
          ? data['error'].toString()
          : (e.message ?? 'Backup delete failed');
      throw ApiFailure(msg, statusCode: e.response?.statusCode);
    }
  }

  // ✅ حذف جميع النسخ
  Future<void> clear() async {
    try {
      await _api.dio.delete('backup/clear');
    } on DioException catch (e) {
      final data = e.response?.data;
      final msg = (data is Map && data['error'] != null)
          ? data['error'].toString()
          : (e.message ?? 'Backup clear failed');
      throw ApiFailure(msg, statusCode: e.response?.statusCode);
    }
  }
}
