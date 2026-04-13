import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:rental_app/features/reports/data/repositories/reports_repository_impl.dart';

import 'reports_event.dart';
import 'reports_state.dart';

class ReportsBloc extends Bloc<ReportsEvent, ReportsState> {
  ReportsBloc(this._repo) : super(const ReportsState.initial()) {
    on<ReportsDashboardRequested>(_onDashboard);
    on<ReportsPaymentsRequested>(_onPayments);
  }

  final ReportsRepository _repo;

  Future<void> _onDashboard(
    ReportsDashboardRequested event,
    Emitter<ReportsState> emit,
  ) async {
    emit(state.copyWith(
      dashboardStatus: ReportsStatus.loading,
      resetDashboard: true,
      dashboardError: null,
    ));

    try {
      final result = await _repo.dashboard(from: event.from, to: event.to);
      emit(state.copyWith(
        dashboardStatus: ReportsStatus.success,
        dashboard: result,
        dashboardError: null,
      ));
    } catch (e) {
      emit(state.copyWith(
        dashboardStatus: ReportsStatus.failure,
        resetDashboard: true,
        dashboardError: e.toString(),
      ));
    }
  }

  Future<void> _onPayments(
    ReportsPaymentsRequested event,
    Emitter<ReportsState> emit,
  ) async {
    emit(state.copyWith(
      paymentsStatus: ReportsStatus.loading,
      resetPayments: true,
      paymentsError: null,
    ));

    try {
      final result = await _repo.paymentsReport(from: event.from, to: event.to, type: event.type);
      emit(state.copyWith(
        paymentsStatus: ReportsStatus.success,
        payments: result,
        paymentsError: null,
      ));
    } catch (e) {
      emit(state.copyWith(
        paymentsStatus: ReportsStatus.failure,
        resetPayments: true,
        paymentsError: e.toString(),
      ));
    }
  }
}
