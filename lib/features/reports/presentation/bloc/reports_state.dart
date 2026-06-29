import 'package:equatable/equatable.dart';

import '../../domain/entities/financial_reports.dart';
import '../../domain/entities/payment_report.dart';
import '../../domain/entities/report_dashboard.dart';
import '../../domain/entities/smart_reports.dart';

enum ReportsStatus { initial, loading, success, failure }
class ReportsState extends Equatable {
  const ReportsState({
    required this.dashboardStatus,
    this.dashboard,
    this.dashboardError,

    required this.paymentsStatus,
    this.payments,
    this.paymentsError,

    required this.equipmentProfitStatus,
    this.equipmentProfit = const [],
    this.equipmentProfitError,

    required this.topEquipmentStatus,
    this.topEquipment = const [],
    this.topEquipmentError,

    required this.topClientsStatus,
    this.topClients = const [],
    this.topClientsError,

    required this.lateClientsStatus,
    this.lateClients = const [],
    this.lateClientsError,

    required this.revenueStatus,
    this.revenue = const [],
    this.revenueError,
    this.revenueGroup = 'day',

    required this.revenueByUserStatus,
    this.revenueByUser = const [],
    this.revenueByUserError,

    required this.financialSummaryStatus,
    this.financialSummary,
    this.financialSummaryError,

    required this.profitLossStatus,
    this.profitLoss,
    this.profitLossError,

    required this.cashFlowStatus,
    this.cashFlow,
    this.cashFlowError,

    required this.employeePerformanceStatus,
    this.employeePerformance = const [],
    this.employeePerformanceError,

    required this.revenueByUserSummaryStatus,
    this.revenueByUserSummary = const [],
    this.revenueByUserSummaryError,

    required this.equipmentProfitV2Status,
    this.equipmentProfitV2 = const [],
    this.equipmentProfitV2Error,

    this.working = false,
  });

  const ReportsState.initial()
      : dashboardStatus = ReportsStatus.initial,
        dashboard = null,
        dashboardError = null,
        paymentsStatus = ReportsStatus.initial,
        payments = null,
        paymentsError = null,
        equipmentProfitStatus = ReportsStatus.initial,
        equipmentProfit = const [],
        equipmentProfitError = null,
        topEquipmentStatus = ReportsStatus.initial,
        topEquipment = const [],
        topEquipmentError = null,
        topClientsStatus = ReportsStatus.initial,
        topClients = const [],
        topClientsError = null,
        lateClientsStatus = ReportsStatus.initial,
        lateClients = const [],
        lateClientsError = null,
        revenueStatus = ReportsStatus.initial,
        revenue = const [],
        revenueError = null,
        revenueGroup = 'day',
        revenueByUserStatus = ReportsStatus.initial,
        revenueByUser = const [],
        revenueByUserError = null,
        financialSummaryStatus = ReportsStatus.initial,
        financialSummary = null,
        financialSummaryError = null,
        profitLossStatus = ReportsStatus.initial,
        profitLoss = null,
        profitLossError = null,
        cashFlowStatus = ReportsStatus.initial,
        cashFlow = null,
        cashFlowError = null,
        employeePerformanceStatus = ReportsStatus.initial,
        employeePerformance = const [],
        employeePerformanceError = null,
        revenueByUserSummaryStatus = ReportsStatus.initial,
        revenueByUserSummary = const [],
        revenueByUserSummaryError = null,
        equipmentProfitV2Status = ReportsStatus.initial,
        equipmentProfitV2 = const [],
        equipmentProfitV2Error = null,
        working = false;

  final ReportsStatus dashboardStatus;
  final ReportDashboard? dashboard;
  final String? dashboardError;

  final ReportsStatus paymentsStatus;
  final PaymentsReport? payments;
  final String? paymentsError;

  final ReportsStatus equipmentProfitStatus;
  final List<EquipmentProfitRow> equipmentProfit;
  final String? equipmentProfitError;

  final ReportsStatus topEquipmentStatus;
  final List<TopEquipmentRow> topEquipment;
  final String? topEquipmentError;

  final ReportsStatus topClientsStatus;
  final List<TopClientRow> topClients;
  final String? topClientsError;

  final ReportsStatus lateClientsStatus;
  final List<LateClientRow> lateClients;
  final String? lateClientsError;

  final ReportsStatus revenueStatus;
  final List<RevenueRow> revenue;
  final String? revenueError;
  final String revenueGroup;

  final ReportsStatus revenueByUserStatus;
  final List<RevenueByUserRow> revenueByUser;
  final String? revenueByUserError;

  // Phase 7 Financial Reports
  final ReportsStatus financialSummaryStatus;
  final FinancialSummary? financialSummary;
  final String? financialSummaryError;

  final ReportsStatus profitLossStatus;
  final ProfitLoss? profitLoss;
  final String? profitLossError;

  final ReportsStatus cashFlowStatus;
  final CashFlow? cashFlow;
  final String? cashFlowError;

  final ReportsStatus employeePerformanceStatus;
  final List<EmployeePerformanceRow> employeePerformance;
  final String? employeePerformanceError;

  final ReportsStatus revenueByUserSummaryStatus;
  final List<RevenueByUserSummaryRow> revenueByUserSummary;
  final String? revenueByUserSummaryError;

  final ReportsStatus equipmentProfitV2Status;
  final List<EquipmentProfitRowV2> equipmentProfitV2;
  final String? equipmentProfitV2Error;

  final bool working;

  ReportsState copyWith({
    ReportsStatus? dashboardStatus,
    ReportDashboard? dashboard,
    String? dashboardError,

    ReportsStatus? paymentsStatus,
    PaymentsReport? payments,
    String? paymentsError,

    ReportsStatus? equipmentProfitStatus,
    List<EquipmentProfitRow>? equipmentProfit,
    String? equipmentProfitError,

    ReportsStatus? topEquipmentStatus,
    List<TopEquipmentRow>? topEquipment,
    String? topEquipmentError,

    ReportsStatus? topClientsStatus,
    List<TopClientRow>? topClients,
    String? topClientsError,

    ReportsStatus? lateClientsStatus,
    List<LateClientRow>? lateClients,
    String? lateClientsError,

    ReportsStatus? revenueStatus,
    List<RevenueRow>? revenue,
    String? revenueError,
    String? revenueGroup,

    ReportsStatus? revenueByUserStatus,
    List<RevenueByUserRow>? revenueByUser,
    String? revenueByUserError,

    ReportsStatus? financialSummaryStatus,
    FinancialSummary? financialSummary,
    String? financialSummaryError,

    ReportsStatus? profitLossStatus,
    ProfitLoss? profitLoss,
    String? profitLossError,

    ReportsStatus? cashFlowStatus,
    CashFlow? cashFlow,
    String? cashFlowError,

    ReportsStatus? employeePerformanceStatus,
    List<EmployeePerformanceRow>? employeePerformance,
    String? employeePerformanceError,

    ReportsStatus? revenueByUserSummaryStatus,
    List<RevenueByUserSummaryRow>? revenueByUserSummary,
    String? revenueByUserSummaryError,

    ReportsStatus? equipmentProfitV2Status,
    List<EquipmentProfitRowV2>? equipmentProfitV2,
    String? equipmentProfitV2Error,

    bool? working,
  }) {
    return ReportsState(
      dashboardStatus: dashboardStatus ?? this.dashboardStatus,
      dashboard: dashboard ?? this.dashboard,
      dashboardError: dashboardError,

      paymentsStatus: paymentsStatus ?? this.paymentsStatus,
      payments: payments ?? this.payments,
      paymentsError: paymentsError,

      equipmentProfitStatus: equipmentProfitStatus ?? this.equipmentProfitStatus,
      equipmentProfit: equipmentProfit ?? this.equipmentProfit,
      equipmentProfitError: equipmentProfitError,

      topEquipmentStatus: topEquipmentStatus ?? this.topEquipmentStatus,
      topEquipment: topEquipment ?? this.topEquipment,
      topEquipmentError: topEquipmentError,

      topClientsStatus: topClientsStatus ?? this.topClientsStatus,
      topClients: topClients ?? this.topClients,
      topClientsError: topClientsError,

      lateClientsStatus: lateClientsStatus ?? this.lateClientsStatus,
      lateClients: lateClients ?? this.lateClients,
      lateClientsError: lateClientsError,

      revenueStatus: revenueStatus ?? this.revenueStatus,
      revenue: revenue ?? this.revenue,
      revenueError: revenueError,
      revenueGroup: revenueGroup ?? this.revenueGroup,

      revenueByUserStatus: revenueByUserStatus ?? this.revenueByUserStatus,
      revenueByUser: revenueByUser ?? this.revenueByUser,
      revenueByUserError: revenueByUserError,

      financialSummaryStatus: financialSummaryStatus ?? this.financialSummaryStatus,
      financialSummary: financialSummary ?? this.financialSummary,
      financialSummaryError: financialSummaryError,

      profitLossStatus: profitLossStatus ?? this.profitLossStatus,
      profitLoss: profitLoss ?? this.profitLoss,
      profitLossError: profitLossError,

      cashFlowStatus: cashFlowStatus ?? this.cashFlowStatus,
      cashFlow: cashFlow ?? this.cashFlow,
      cashFlowError: cashFlowError,

      employeePerformanceStatus: employeePerformanceStatus ?? this.employeePerformanceStatus,
      employeePerformance: employeePerformance ?? this.employeePerformance,
      employeePerformanceError: employeePerformanceError,

      revenueByUserSummaryStatus: revenueByUserSummaryStatus ?? this.revenueByUserSummaryStatus,
      revenueByUserSummary: revenueByUserSummary ?? this.revenueByUserSummary,
      revenueByUserSummaryError: revenueByUserSummaryError,

      equipmentProfitV2Status: equipmentProfitV2Status ?? this.equipmentProfitV2Status,
      equipmentProfitV2: equipmentProfitV2 ?? this.equipmentProfitV2,
      equipmentProfitV2Error: equipmentProfitV2Error,

      working: working ?? this.working,
    );
  }

  @override
  List<Object?> get props => [
        dashboardStatus, dashboard, dashboardError,
        paymentsStatus, payments, paymentsError,
        equipmentProfitStatus, equipmentProfit, equipmentProfitError,
        topEquipmentStatus, topEquipment, topEquipmentError,
        topClientsStatus, topClients, topClientsError,
        lateClientsStatus, lateClients, lateClientsError,
        revenueStatus, revenue, revenueError, revenueGroup,
        revenueByUserStatus, revenueByUser, revenueByUserError,
        financialSummaryStatus, financialSummary, financialSummaryError,
        profitLossStatus, profitLoss, profitLossError,
        cashFlowStatus, cashFlow, cashFlowError,
        employeePerformanceStatus, employeePerformance, employeePerformanceError,
        revenueByUserSummaryStatus, revenueByUserSummary, revenueByUserSummaryError,
        equipmentProfitV2Status, equipmentProfitV2, equipmentProfitV2Error,
        working,
      ];
}
