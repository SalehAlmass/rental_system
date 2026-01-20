import 'package:equatable/equatable.dart';
import '../../domain/entities/report_dashboard.dart';
import '../../domain/entities/payment_report.dart';

enum ReportsStatus { initial, loading, success, failure }

class ReportsState extends Equatable {
  const ReportsState({
    required this.dashboardStatus,
    required this.paymentsStatus,
    this.dashboard,
    this.payments,
    this.dashboardError,
    this.paymentsError,
  });

  const ReportsState.initial()
      : dashboardStatus = ReportsStatus.initial,
        paymentsStatus = ReportsStatus.initial,
        dashboard = null,
        payments = null,
        dashboardError = null,
        paymentsError = null;

  final ReportsStatus dashboardStatus;
  final ReportsStatus paymentsStatus;
  final ReportDashboard? dashboard;
  final PaymentsReport? payments;
  final String? dashboardError;
  final String? paymentsError;

  ReportsState copyWith({
    ReportsStatus? dashboardStatus,
    ReportsStatus? paymentsStatus,
    ReportDashboard? dashboard,
    PaymentsReport? payments,
    bool resetDashboard = false,
    bool resetPayments = false,
    String? dashboardError,
    String? paymentsError,
  }) {
    return ReportsState(
      dashboardStatus: dashboardStatus ?? this.dashboardStatus,
      paymentsStatus: paymentsStatus ?? this.paymentsStatus,
      dashboard: resetDashboard ? null : (dashboard ?? this.dashboard),
      payments: resetPayments ? null : (payments ?? this.payments),
      dashboardError: dashboardError ?? this.dashboardError,
      paymentsError: paymentsError ?? this.paymentsError,
    );
  }

  @override
  List<Object?> get props => [
        dashboardStatus,
        paymentsStatus,
        dashboard,
        payments,
        dashboardError,
        paymentsError,
      ];
}
