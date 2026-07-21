import 'package:dio/dio.dart';
import 'package:rental_app/core/network/api_client.dart';
import 'package:rental_app/core/network/failure.dart';

class ContractClosingSettings {
  const ContractClosingSettings({
    required this.hourPricingMode,
    required this.paymentReceiptMode,
  });

  final String hourPricingMode; // auto | ask
  final String paymentReceiptMode; // auto | ask

  bool get shouldAskForSpecialPricing => hourPricingMode == 'ask';
  bool get shouldAutoCreateReceipt => paymentReceiptMode == 'auto';
  bool get shouldAskForReceipt => paymentReceiptMode == 'ask';

  factory ContractClosingSettings.fromJson(Map<String, dynamic> json) {
    return ContractClosingSettings(
      hourPricingMode: (json['hour_pricing_mode'] ?? 'ask').toString(),
      paymentReceiptMode: (json['payment_receipt_mode'] ?? 'auto').toString(),
    );
  }
}

class ContractClosingSettingsRepository {
  ContractClosingSettingsRepository(this._api);
  final ApiClient _api;

  Future<ContractClosingSettings> fetch() async {
    try {
      final res = await _api.dio.get('settings/contract-closing');
      final data = (res.data is Map ? res.data as Map : <String, dynamic>{}).cast<String, dynamic>();
      return ContractClosingSettings.fromJson(data);
    } on DioException catch (e) {
      throw ApiFailure.fromDio(e);
    }
  }

  Future<ContractClosingSettings> save({
    required String hourPricingMode,
    required String paymentReceiptMode,
  }) async {
    try {
      final res = await _api.dio.put('settings/contract-closing', data: {
        'hour_pricing_mode': hourPricingMode,
        'payment_receipt_mode': paymentReceiptMode,
      });
      final raw = (res.data is Map ? res.data as Map : <String, dynamic>{}).cast<String, dynamic>();
      final data = (raw['data'] is Map ? raw['data'] as Map : raw).cast<String, dynamic>();
      return ContractClosingSettings.fromJson(data);
    } on DioException catch (e) {
      throw ApiFailure.fromDio(e);
    }
  }
}
