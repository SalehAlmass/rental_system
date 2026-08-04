class DashboardStats {
  DashboardStats({
    required this.clients,
    required this.equipment,
    required this.openRents,
    required this.revenue,
    this.todayRevenue,
    this.yesterdayRevenue,
    this.thisWeekRevenue,
    this.lastWeekRevenue,
    this.deferredAmount,
  });

  final int clients;
  final int equipment;
  final int openRents;
  final double revenue;
  final double? todayRevenue;
  final double? yesterdayRevenue;
  final double? thisWeekRevenue;
  final double? lastWeekRevenue;
  final double? deferredAmount;

  factory DashboardStats.fromJson(Map<String, dynamic> json) {
    double? toDouble(dynamic val) {
      if (val is num) return val.toDouble();
      if (val != null) return double.tryParse(val.toString());
      return null;
    }

    return DashboardStats(
      clients: (json['clients'] ?? 0) as int,
      equipment: (json['equipment'] ?? 0) as int,
      openRents: (json['open_rents'] ?? 0) as int,
      revenue: toDouble(json['revenue']) ?? 0.0,
      todayRevenue: toDouble(json['today_revenue']),
      yesterdayRevenue: toDouble(json['yesterday_revenue']),
      thisWeekRevenue: toDouble(json['this_week_revenue']),
      lastWeekRevenue: toDouble(json['last_week_revenue']),
      deferredAmount: toDouble(json['deferred_amount'] ?? json['outstanding_amount']),
    );
  }
}
