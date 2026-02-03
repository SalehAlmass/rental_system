import 'package:dio/dio.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/failure.dart';

class BackupItem {
  final String name; // ✅ توحيد الاسم
  final int size;
  final String createdAt;

  const BackupItem({
    required this.name,
    required this.size,
    required this.createdAt,
  });

  factory BackupItem.fromJson(Map<String, dynamic> json) {
    final rawName = (json['name'] ?? json['file'] ?? '').toString();
    return BackupItem(
      name: rawName,
      size: (json['size'] is num)
          ? (json['size'] as num).toInt()
          : int.tryParse('${json['size']}') ?? 0,
      createdAt: (json['created_at'] ?? json['createdAt'] ?? '').toString(),
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
      return raw
          .map((e) => BackupItem.fromJson((e as Map).cast<String, dynamic>()))
          .toList();
    } on DioException catch (e) {
      final data = e.response?.data;
      final msg = (data is Map && data['error'] != null)
          ? data['error'].toString()
          : (e.message ?? 'Backup list failed');
      throw ApiFailure(msg, statusCode: e.response?.statusCode);
    }
  }

  Future<void> create() async {
    try {
      await _api.dio.post('backup/create');
    } on DioException catch (e) {
      final data = e.response?.data;
      final msg = (data is Map && data['error'] != null)
          ? data['error'].toString()
          : (e.message ?? 'Backup create failed');
      throw ApiFailure(msg, statusCode: e.response?.statusCode);
    }
  }

  Future<void> restore({required String name}) async {
    try {
      // ✅ أهم تعديل: name وليس file
      await _api.dio.post('backup/restore', data: {'name': name});
    } on DioException catch (e) {
      final data = e.response?.data;
      final msg = (data is Map && data['error'] != null)
          ? data['error'].toString()
          : (e.message ?? 'Backup restore failed');
      throw ApiFailure(msg, statusCode: e.response?.statusCode);
    }
  }
}
