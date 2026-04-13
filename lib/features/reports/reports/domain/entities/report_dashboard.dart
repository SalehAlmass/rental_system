class ReportDashboard {
  final int clients;
  final int equipment;
  final int openRents;
  final double revenue;

  const ReportDashboard({
    required this.clients,
    required this.equipment,
    required this.openRents,
    required this.revenue,
  });

  factory ReportDashboard.fromJson(Map<String, dynamic> json) {
    return ReportDashboard(
      clients: (json['clients'] as num?)?.toInt() ?? 0,
      equipment: (json['equipment'] as num?)?.toInt() ?? 0,
      openRents: (json['open_rents'] as num?)?.toInt() ?? 0,
      revenue: (json['revenue'] as num?)?.toDouble() ?? 0.0,
    );
  }
}
