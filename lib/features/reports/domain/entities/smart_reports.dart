class EquipmentProfitRow {
  final int equipmentId;
  final String name;
  final String? type;
  final String? serialNo;
  final double profit;
  final double cost;
  final double net;

  const EquipmentProfitRow({
    required this.equipmentId,
    required this.name,
    this.type,
    this.serialNo,
    required this.profit,
    required this.cost,
    required this.net,
  });

  factory EquipmentProfitRow.fromJson(Map<String, dynamic> json) {
    double toD(dynamic v) => v == null ? 0.0 : (v is num ? v.toDouble() : double.tryParse(v.toString()) ?? 0.0);
    int toI(dynamic v) => v == null ? 0 : (v is num ? v.toInt() : int.tryParse(v.toString()) ?? 0);

    return EquipmentProfitRow(
      equipmentId: toI(json['equipment_id'] ?? json['id']),
      name: (json['name'] ?? '').toString(),
      type: json['type']?.toString(),
      serialNo: json['serial_no']?.toString(),
      profit: toD(json['profit'] ?? json['revenue']),
      cost: toD(json['cost']),
      net: toD(json['net'] ?? json['net_profit']),
    );
  }
}

class TopEquipmentRow {
  final int equipmentId;
  final String name;
  final String? type;
  final String? serialNo;
  final int rentalsCount;
  final double totalIncome;

  /// Backward compatible alias (older UI code expects `timesRented`).
  int get timesRented => rentalsCount;
  const TopEquipmentRow({
    required this.equipmentId,
    required this.name,
    this.type,
    this.serialNo,
    required this.rentalsCount,
    required this.totalIncome,
  });

  factory TopEquipmentRow.fromJson(Map<String, dynamic> json) {
    double toD(dynamic v) => v == null ? 0.0 : (v is num ? v.toDouble() : double.tryParse(v.toString()) ?? 0.0);
    int toI(dynamic v) => v == null ? 0 : (v is num ? v.toInt() : int.tryParse(v.toString()) ?? 0);

    return TopEquipmentRow(
      equipmentId: toI(json['equipment_id'] ?? json['id']),
      name: (json['name'] ?? '').toString(),
      type: json['type']?.toString(),
      serialNo: json['serial_no']?.toString(),
      rentalsCount: toI(json['rentals_count']),
      totalIncome: toD(json['total_income']),
    );
  }
}

class TopClientRow {
  final int clientId;
  final String name;
  final String? phone;
  final int contractsCount;
  final double totalAmount;

  const TopClientRow({
    required this.clientId,
    required this.name,
    this.phone,
    required this.contractsCount,
    required this.totalAmount,
  });

  factory TopClientRow.fromJson(Map<String, dynamic> json) {
    double toD(dynamic v) => v == null ? 0.0 : (v is num ? v.toDouble() : double.tryParse(v.toString()) ?? 0.0);
    int toI(dynamic v) => v == null ? 0 : (v is num ? v.toInt() : int.tryParse(v.toString()) ?? 0);

    return TopClientRow(
      clientId: toI(json['client_id'] ?? json['id']),
      name: (json['name'] ?? '').toString(),
      phone: json['phone']?.toString(),
      contractsCount: toI(json['contracts_count']),
      totalAmount: toD(json['total_amount']),
    );
  }
}

class LateClientRow {
  final int clientId;
  final String name;
  final String? phone;

  // الاسم الأساسي الموجود
  final int lateContractsCount;

  /// Backward compatible alias (older UI code expects `lateCount`).
  int get lateCount => lateContractsCount;

  const LateClientRow({
    required this.clientId,
    required this.name,
    this.phone,
    required this.lateContractsCount,
  });

  factory LateClientRow.fromJson(Map<String, dynamic> json) {
    int toI(dynamic v) => v == null ? 0 : (v is num ? v.toInt() : int.tryParse(v.toString()) ?? 0);

    return LateClientRow(
      clientId: toI(json['client_id'] ?? json['id']),
      name: (json['name'] ?? '').toString(),
      phone: json['phone']?.toString(),
      lateContractsCount: toI(json['late_contracts_count'] ?? json['late_count']),
    );
  }
}


class RevenueRow {
  final String period;
  final double revenue;

  const RevenueRow({required this.period, required this.revenue});

  factory RevenueRow.fromJson(Map<String, dynamic> json) {
    double toD(dynamic v) => v == null ? 0.0 : (v is num ? v.toDouble() : double.tryParse(v.toString()) ?? 0.0);
    return RevenueRow(
      period: (json['period'] ?? '').toString(),
      revenue: toD(json['revenue']),
    );
  }
}

class RevenueByUserRow {
  final int userId;
  final String username;
  final String fullName;
  final String role;
  final int receiptsCount;
  final double revenue;

  const RevenueByUserRow({
    required this.userId,
    required this.username,
    required this.fullName,
    required this.role,
    required this.receiptsCount,
    required this.revenue,
  });

  factory RevenueByUserRow.fromJson(Map<String, dynamic> json) {
    double toD(dynamic v) => v == null ? 0.0 : (v is num ? v.toDouble() : double.tryParse(v.toString()) ?? 0.0);
    int toI(dynamic v) => v == null ? 0 : (v is num ? v.toInt() : int.tryParse(v.toString()) ?? 0);

    return RevenueByUserRow(
      userId: toI(json['user_id'] ?? json['id']),
      username: (json['username'] ?? '').toString(),
      fullName: (json['full_name'] ?? '').toString(),
      role: (json['role'] ?? '').toString(),
      receiptsCount: toI(json['receipts_count']),
      revenue: toD(json['revenue']),
    );
  }
}
