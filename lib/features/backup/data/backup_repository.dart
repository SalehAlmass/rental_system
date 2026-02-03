import 'package:dio/dio.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/failure.dart';

class BackupItem {
  final String name; // backup_*.sql
  /// Size in bytes
  final int size;
  final String createdAt;
  /// full | def | log
  final String type;

  const BackupItem({
    required this.name,
    required this.size,
    required this.createdAt,
    required this.type,
  });

  factory BackupItem.fromJson(Map<String, dynamic> json) {
    final rawName = (json['name'] ?? json['file'] ?? '').toString();
    return BackupItem(
      name: rawName,
      // API returns size in bytes (int)
      size: (json['size'] is num)
          ? (json['size'] as num).toInt()
          : int.tryParse('${json['size']}') ?? 0,
      createdAt: (json['created_at'] ?? json['createdAt'] ?? '').toString(),
      type: (json['type'] ?? 'full').toString(),
    );
  }

  double get sizeKb => size / 1024.0;
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

  /// type: full | def | log
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
