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
  });

  final int id;
  final String name;
  final String? model;
  final String? serialNo;
  final String? status;
  final double dailyRate;
  final double depreciationRate;
  final String? lastMaintenanceDate; // YYYY-MM-DD or null
  final bool isActive;

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
      };
}
