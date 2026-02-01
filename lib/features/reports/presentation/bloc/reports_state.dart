import 'package:equatable/equatable.dart';

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

      working: working ?? this.working,
    );
  }

  @override
  List<Object?> get props => [
        dashboardStatus,
        dashboard,
        dashboardError,
        paymentsStatus,
        payments,
        paymentsError,
        equipmentProfitStatus,
        equipmentProfit,
        equipmentProfitError,
        topEquipmentStatus,
        topEquipment,
        topEquipmentError,
        topClientsStatus,
        topClients,
        topClientsError,
        lateClientsStatus,
        lateClients,
        lateClientsError,
        revenueStatus,
        revenue,
        revenueError,
        revenueGroup,
        revenueByUserStatus,
        revenueByUser,
        revenueByUserError,
        working,
      ];
}
