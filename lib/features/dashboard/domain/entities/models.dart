class DashboardStats {
  DashboardStats({required this.clients, required this.equipment, required this.openRents, required this.revenue});

  final int clients;
  final int equipment;
  final int openRents;
  final double revenue;

  factory DashboardStats.fromJson(Map<String, dynamic> json) {
    return DashboardStats(
      clients: (json['clients'] ?? 0) as int,
      equipment: (json['equipment'] ?? 0) as int,
      openRents: (json['open_rents'] ?? 0) as int,
      revenue: (json['revenue'] is num) ? (json['revenue'] as num).toDouble() : 0.0,
    );
  }
}
