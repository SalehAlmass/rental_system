class ReportDashboard {
  final int clients;
  final int equipment;
  final int openContracts;
  final double revenue;

  const ReportDashboard({
    required this.clients,
    required this.equipment,
    required this.openContracts,
    required this.revenue,
  });

  factory ReportDashboard.fromJson(Map<String, dynamic> json) {
    // API may return {data:{...}} or direct {...}
    final root = (json['data'] is Map) ? (json['data'] as Map).cast<String, dynamic>() : json;

    int toI(dynamic v) => v == null ? 0 : (v is num ? v.toInt() : int.tryParse(v.toString()) ?? 0);
    double toD(dynamic v) => v == null ? 0.0 : (v is num ? v.toDouble() : double.tryParse(v.toString()) ?? 0.0);

    final open = root.containsKey('open_contracts')
        ? toI(root['open_contracts'])
        : toI(root['open_rents']);

    return ReportDashboard(
      clients: toI(root['clients']),
      equipment: toI(root['equipment']),
      openContracts: open,
      revenue: toD(root['revenue']),
    );
  }
}
