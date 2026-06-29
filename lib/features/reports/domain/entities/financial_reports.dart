/// financial_reports.dart
/// Domain entities for Phase 7 Financial Intelligence reports.

// ─────────────────────────────────────────────
//  Financial Summary
// ─────────────────────────────────────────────
class FinancialSummary {
  final double rentalRevenue;
  final double otherRevenue;
  final double totalRevenue;
  final double maintenanceExpenses;
  final double payrollExpenses;
  final double depreciationExpenses;
  final double operationalExpenses;
  final double totalExpenses;
  final double grossProfit;
  final double operatingProfit;
  final double netProfit;
  final double outstandingAmount;
  final double totalAssetValue;
  final double profitMarginPct;
  final FinancialComparison? comparison;

  const FinancialSummary({
    required this.rentalRevenue,
    required this.otherRevenue,
    required this.totalRevenue,
    required this.maintenanceExpenses,
    required this.payrollExpenses,
    required this.depreciationExpenses,
    required this.operationalExpenses,
    required this.totalExpenses,
    required this.grossProfit,
    required this.operatingProfit,
    required this.netProfit,
    required this.outstandingAmount,
    required this.totalAssetValue,
    required this.profitMarginPct,
    this.comparison,
  });

  factory FinancialSummary.fromJson(Map<String, dynamic> json) {
    double toD(dynamic v) => v == null ? 0.0 : (v is num ? v.toDouble() : double.tryParse(v.toString()) ?? 0.0);

    final root = (json['data'] is Map) ? (json['data'] as Map).cast<String, dynamic>() : json;
    final rev  = (root['revenue']  is Map) ? (root['revenue']  as Map).cast<String, dynamic>() : <String, dynamic>{};
    final exp  = (root['expenses'] is Map) ? (root['expenses'] as Map).cast<String, dynamic>() : <String, dynamic>{};
    final res  = (root['results']  is Map) ? (root['results']  as Map).cast<String, dynamic>() : <String, dynamic>{};
    final kpis = (root['kpis']     is Map) ? (root['kpis']     as Map).cast<String, dynamic>() : <String, dynamic>{};
    final cmpRaw = root['comparison'];
    final cmp = (cmpRaw is Map) ? FinancialComparison.fromJson(cmpRaw.cast<String, dynamic>()) : null;

    return FinancialSummary(
      rentalRevenue:         toD(rev['rental_revenue']),
      otherRevenue:          toD(rev['other_revenue']),
      totalRevenue:          toD(rev['total_revenue']),
      maintenanceExpenses:   toD(exp['maintenance']),
      payrollExpenses:       toD(exp['payroll']),
      depreciationExpenses:  toD(exp['depreciation']),
      operationalExpenses:   toD(exp['operational']),
      totalExpenses:         toD(exp['total']),
      grossProfit:           toD(res['gross_profit']),
      operatingProfit:       toD(res['operating_profit']),
      netProfit:             toD(res['net_profit']),
      outstandingAmount:     toD(kpis['outstanding_amount']),
      totalAssetValue:       toD(kpis['total_asset_value']),
      profitMarginPct:       toD(kpis['profit_margin_pct']),
      comparison:            cmp,
    );
  }
}

class FinancialComparison {
  final String fromDate;
  final String toDate;
  final double totalRevenue;
  final double netProfit;
  final double? revenueGrowthPct;

  const FinancialComparison({
    required this.fromDate,
    required this.toDate,
    required this.totalRevenue,
    required this.netProfit,
    this.revenueGrowthPct,
  });

  factory FinancialComparison.fromJson(Map<String, dynamic> json) {
    double toD(dynamic v) => v == null ? 0.0 : (v is num ? v.toDouble() : double.tryParse(v.toString()) ?? 0.0);
    final period = (json['period'] is Map) ? (json['period'] as Map).cast<String, dynamic>() : <String, dynamic>{};
    return FinancialComparison(
      fromDate:        period['from']?.toString() ?? '',
      toDate:          period['to']?.toString() ?? '',
      totalRevenue:    toD(json['total_revenue']),
      netProfit:       toD(json['net_profit']),
      revenueGrowthPct: json['revenue_growth_pct'] == null ? null : toD(json['revenue_growth_pct']),
    );
  }
}

// ─────────────────────────────────────────────
//  Profit & Loss
// ─────────────────────────────────────────────
class ProfitLoss {
  final double rentalRevenue;
  final double otherRevenue;
  final double totalRevenue;
  final double maintenanceCost;
  final double depreciationCost;
  final double totalCost;
  final double grossProfit;
  final double payrollExpense;
  final double otherExpenses;
  final double totalOperating;
  final double netProfit;

  const ProfitLoss({
    required this.rentalRevenue,
    required this.otherRevenue,
    required this.totalRevenue,
    required this.maintenanceCost,
    required this.depreciationCost,
    required this.totalCost,
    required this.grossProfit,
    required this.payrollExpense,
    required this.otherExpenses,
    required this.totalOperating,
    required this.netProfit,
  });

  factory ProfitLoss.fromJson(Map<String, dynamic> json) {
    double toD(dynamic v) => v == null ? 0.0 : (v is num ? v.toDouble() : double.tryParse(v.toString()) ?? 0.0);
    final root = (json['data'] is Map) ? (json['data'] as Map).cast<String, dynamic>() : json;
    final inc  = (root['income']              is Map) ? (root['income']              as Map).cast<String, dynamic>() : <String, dynamic>{};
    final cor  = (root['cost_of_revenue']     is Map) ? (root['cost_of_revenue']     as Map).cast<String, dynamic>() : <String, dynamic>{};
    final opex = (root['operating_expenses']  is Map) ? (root['operating_expenses']  as Map).cast<String, dynamic>() : <String, dynamic>{};

    return ProfitLoss(
      rentalRevenue:   toD(inc['rental_revenue']),
      otherRevenue:    toD(inc['other_revenue']),
      totalRevenue:    toD(inc['total_revenue']),
      maintenanceCost: toD(cor['maintenance']),
      depreciationCost:toD(cor['depreciation']),
      totalCost:       toD(cor['total_cost']),
      grossProfit:     toD(root['gross_profit']),
      payrollExpense:  toD(opex['payroll']),
      otherExpenses:   toD(opex['other_expenses']),
      totalOperating:  toD(opex['total_operating']),
      netProfit:       toD(root['net_profit']),
    );
  }
}

// ─────────────────────────────────────────────
//  Cash Flow
// ─────────────────────────────────────────────
class CashFlow {
  final double openingBalance;
  final double cashIn;
  final double transferIn;
  final double totalCashIn;
  final double cashOut;
  final double transferOut;
  final double maintenanceCashOut;
  final double totalCashOut;
  final double netMovement;
  final double closingBalance;

  const CashFlow({
    required this.openingBalance,
    required this.cashIn,
    required this.transferIn,
    required this.totalCashIn,
    required this.cashOut,
    required this.transferOut,
    required this.maintenanceCashOut,
    required this.totalCashOut,
    required this.netMovement,
    required this.closingBalance,
  });

  factory CashFlow.fromJson(Map<String, dynamic> json) {
    double toD(dynamic v) => v == null ? 0.0 : (v is num ? v.toDouble() : double.tryParse(v.toString()) ?? 0.0);
    final root = (json['data'] is Map) ? (json['data'] as Map).cast<String, dynamic>() : json;
    final inm  = (root['cash_in']  is Map) ? (root['cash_in']  as Map).cast<String, dynamic>() : <String, dynamic>{};
    final out  = (root['cash_out'] is Map) ? (root['cash_out'] as Map).cast<String, dynamic>() : <String, dynamic>{};

    return CashFlow(
      openingBalance:     toD(root['opening_balance']),
      cashIn:             toD(inm['cash']),
      transferIn:         toD(inm['transfer']),
      totalCashIn:        toD(inm['total']),
      cashOut:            toD(out['cash']),
      transferOut:        toD(out['transfer']),
      maintenanceCashOut: toD(out['maintenance']),
      totalCashOut:       toD(out['total']),
      netMovement:        toD(root['net_movement']),
      closingBalance:     toD(root['closing_balance']),
    );
  }
}

// ─────────────────────────────────────────────
//  Employee Performance
// ─────────────────────────────────────────────
class EmployeePerformanceRow {
  final int userId;
  final String username;
  final String role;
  final int receiptsCount;
  final double totalCollected;
  final int contractsCreated;
  final double totalContractValue;
  final double avgTransactionValue;

  const EmployeePerformanceRow({
    required this.userId,
    required this.username,
    required this.role,
    required this.receiptsCount,
    required this.totalCollected,
    required this.contractsCreated,
    required this.totalContractValue,
    required this.avgTransactionValue,
  });

  factory EmployeePerformanceRow.fromJson(Map<String, dynamic> json) {
    double toD(dynamic v) => v == null ? 0.0 : (v is num ? v.toDouble() : double.tryParse(v.toString()) ?? 0.0);
    int toI(dynamic v) => v == null ? 0 : (v is num ? v.toInt() : int.tryParse(v.toString()) ?? 0);

    return EmployeePerformanceRow(
      userId:              toI(json['user_id']),
      username:            (json['username'] ?? '').toString(),
      role:                (json['role'] ?? '').toString(),
      receiptsCount:       toI(json['receipts_count']),
      totalCollected:      toD(json['total_collected']),
      contractsCreated:    toI(json['contracts_created']),
      totalContractValue:  toD(json['total_contract_value']),
      avgTransactionValue: toD(json['avg_transaction_value']),
    );
  }
}

// ─────────────────────────────────────────────
//  Revenue by User Summary
// ─────────────────────────────────────────────
class RevenueByUserSummaryRow {
  final int userId;
  final String username;
  final String role;
  final double cashCollected;
  final double transferCollected;
  final double totalReceipts;
  final int transactionsCount;

  const RevenueByUserSummaryRow({
    required this.userId,
    required this.username,
    required this.role,
    required this.cashCollected,
    required this.transferCollected,
    required this.totalReceipts,
    required this.transactionsCount,
  });

  factory RevenueByUserSummaryRow.fromJson(Map<String, dynamic> json) {
    double toD(dynamic v) => v == null ? 0.0 : (v is num ? v.toDouble() : double.tryParse(v.toString()) ?? 0.0);
    int toI(dynamic v) => v == null ? 0 : (v is num ? v.toInt() : int.tryParse(v.toString()) ?? 0);

    return RevenueByUserSummaryRow(
      userId:              toI(json['user_id']),
      username:            (json['username'] ?? '').toString(),
      role:                (json['role'] ?? '').toString(),
      cashCollected:       toD(json['cash_collected']),
      transferCollected:   toD(json['transfer_collected']),
      totalReceipts:       toD(json['total_receipts']),
      transactionsCount:   toI(json['transactions_count']),
    );
  }
}

// ─────────────────────────────────────────────
//  Enhanced Equipment Profit (with ROI)
// ─────────────────────────────────────────────
class EquipmentProfitRowV2 {
  final int equipmentId;
  final String name;
  final String? type;
  final String? serialNo;
  final double purchasePrice;
  final double rentalDays;
  final double rentalRevenue;
  final double maintenanceCost;
  final double accountingDepreciation;
  final double operationalDepreciation;
  final double netProfit;
  final double operationalNet;
  final double? roiPct;

  const EquipmentProfitRowV2({
    required this.equipmentId,
    required this.name,
    this.type,
    this.serialNo,
    required this.purchasePrice,
    required this.rentalDays,
    required this.rentalRevenue,
    required this.maintenanceCost,
    required this.accountingDepreciation,
    required this.operationalDepreciation,
    required this.netProfit,
    required this.operationalNet,
    this.roiPct,
  });

  factory EquipmentProfitRowV2.fromJson(Map<String, dynamic> json) {
    double toD(dynamic v) => v == null ? 0.0 : (v is num ? v.toDouble() : double.tryParse(v.toString()) ?? 0.0);
    int toI(dynamic v) => v == null ? 0 : (v is num ? v.toInt() : int.tryParse(v.toString()) ?? 0);

    return EquipmentProfitRowV2(
      equipmentId:              toI(json['equipment_id'] ?? json['id']),
      name:                     (json['name'] ?? '').toString(),
      type:                     json['type']?.toString(),
      serialNo:                 json['serial_no']?.toString(),
      purchasePrice:            toD(json['purchase_price']),
      rentalDays:               toD(json['rental_days']),
      rentalRevenue:            toD(json['rental_revenue'] ?? json['profit']),
      maintenanceCost:          toD(json['maintenance_cost'] ?? json['cost']),
      accountingDepreciation:   toD(json['accounting_depreciation']),
      operationalDepreciation:  toD(json['operational_depreciation']),
      netProfit:                toD(json['net_profit'] ?? json['net']),
      operationalNet:           toD(json['operational_net']),
      roiPct:                   json['roi_pct'] == null ? null : toD(json['roi_pct']),
    );
  }
}
