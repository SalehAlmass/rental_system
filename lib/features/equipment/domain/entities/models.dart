class Equipment {
  const Equipment({
    required this.id,
    required this.name,
    this.model,
    this.serialNo,
    this.status,
    this.dailyRate = 0,
    this.depreciationRate = 0,
    this.lastMaintenanceDate,
    this.isActive = true,
    this.purchasePrice = 0,
    this.salvageValue = 0,
    this.usefulLifeMonths = 60,
    this.depreciationStartDate,
    this.depreciationMonthly = 0,
    this.depreciationAccumulated = 0,
    this.bookValue = 0,
    this.estimatedUsageDays = 365,
    this.operationalDepreciationPerDay = 0,
    this.operationalDepreciationAccumulated = 0,
  });

  final int id;
  final String name;
  final String? model;
  final String? serialNo;
  final String? status;
  final double dailyRate;
  final double depreciationRate;
  final String? lastMaintenanceDate;
  final bool isActive;
  final double purchasePrice;
  final double salvageValue;
  final int usefulLifeMonths;
  final String? depreciationStartDate;
  final double depreciationMonthly;
  final double depreciationAccumulated;
  final double bookValue;
  final int estimatedUsageDays;
  final double operationalDepreciationPerDay;
  final double operationalDepreciationAccumulated;

  factory Equipment.fromJson(Map<String, dynamic> json) {
    double toD(dynamic v) => v == null ? 0.0 : (v is num ? v.toDouble() : double.tryParse(v.toString()) ?? 0.0);
    int toI(dynamic v) => v == null ? 0 : (v is num ? v.toInt() : int.tryParse(v.toString()) ?? 0);
    bool toB(dynamic v) {
      if (v == null) return true;
      if (v is bool) return v;
      final s = v.toString();
      return s != '0' && s.toLowerCase() != 'false';
    }

    return Equipment(
      id: toI(json['id']),
      name: (json['name'] ?? '').toString(),
      model: json['model']?.toString(),
      serialNo: json['serial_no']?.toString(),
      status: json['status']?.toString(),
      dailyRate: toD(json['daily_rate'] ?? json['hourly_rate']),
      depreciationRate: toD(json['depreciation_rate']),
      lastMaintenanceDate: json['last_maintenance_date']?.toString(),
      isActive: toB(json['is_active']),
      purchasePrice: toD(json['purchase_price']),
      salvageValue: toD(json['salvage_value']),
      usefulLifeMonths: toI(json['useful_life_months'] ?? 60),
      depreciationStartDate: json['depreciation_start_date']?.toString(),
      depreciationMonthly: toD(json['depreciation_monthly']),
      depreciationAccumulated: toD(json['depreciation_accumulated']),
      bookValue: toD(json['book_value']),
      estimatedUsageDays: toI(json['estimated_usage_days'] ?? 365),
      operationalDepreciationPerDay: toD(json['operational_depreciation_per_day']),
      operationalDepreciationAccumulated: toD(json['operational_depreciation_accumulated']),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'model': model,
        'serial_no': serialNo,
        'status': status,
        'daily_rate': dailyRate,
        'hourly_rate': dailyRate,
        'depreciation_rate': depreciationRate,
        'last_maintenance_date': lastMaintenanceDate,
        'is_active': isActive ? 1 : 0,
        'purchase_price': purchasePrice,
        'salvage_value': salvageValue,
        'useful_life_months': usefulLifeMonths,
        'depreciation_start_date': depreciationStartDate,
        'depreciation_monthly': depreciationMonthly,
        'depreciation_accumulated': depreciationAccumulated,
        'book_value': bookValue,
        'estimated_usage_days': estimatedUsageDays,
        'operational_depreciation_per_day': operationalDepreciationPerDay,
        'operational_depreciation_accumulated': operationalDepreciationAccumulated,
      };
}
