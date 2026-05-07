import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:rental_app/core/network/api_client.dart';

class AdminAlertReceiptGuard extends StatelessWidget {
  const AdminAlertReceiptGuard({
    super.key,
    required this.data,
    required this.child,
  });

  final Map<String, dynamic> data;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final rentId = _receiptAlertRentId(data);
    if (rentId == null) return child;

    return FutureBuilder<bool>(
      future: _ReceiptAlertVerifier.shouldShowAlert(context, rentId),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const SizedBox.shrink();
        }
        if (snapshot.data ?? true) {
          return child;
        }
        return const SizedBox.shrink();
      },
    );
  }
}

int? _receiptAlertRentId(Map<String, dynamic> data) {
  final action = (data['action'] ?? '').toString().toLowerCase();
  final entity = (data['entity'] ?? '').toString().toLowerCase();
  if (action != 'receipt_skipped_on_close' || entity != 'rent') {
    return null;
  }

  final entityId = data['entity_id'];
  if (entityId is num && entityId.toInt() > 0) {
    return entityId.toInt();
  }
  return int.tryParse(entityId?.toString() ?? '');
}

class _ReceiptAlertVerifier {
  static final Map<int, Future<bool>> _cache = {};

  static Future<bool> shouldShowAlert(BuildContext context, int rentId) {
    return _cache.putIfAbsent(
      rentId,
      () async {
        try {
          final dio = context.read<ApiClient>().dio;
          final res = await dio.get(
            '/payments',
            queryParameters: {
              'rent_id': rentId,
              'show_void': 0,
            },
          );

          final raw = res.data;
          final payload = raw is Map<String, dynamic>
              ? (raw['data'] ?? raw['items'] ?? raw['payments'] ?? raw)
              : raw;
          final payments = payload is List
              ? payload.whereType<Map>().map((e) => e.cast<String, dynamic>())
              : const Iterable<Map<String, dynamic>>.empty();

          final hasActiveReceipt = payments.any((payment) {
            final type = (payment['type'] ?? '').toString().toLowerCase();
            final isVoidRaw = payment['is_void'];
            final isVoid = isVoidRaw == true ||
                isVoidRaw == 1 ||
                isVoidRaw?.toString() == '1';
            return type == 'in' && !isVoid;
          });

          return !hasActiveReceipt;
        } catch (_) {
          return true;
        }
      },
    );
  }
}
