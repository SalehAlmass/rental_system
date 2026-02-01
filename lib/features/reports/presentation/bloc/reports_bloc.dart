import 'package:flutter_bloc/flutter_bloc.dart';

import '../../data/repositories/reports_repository_impl.dart';
import 'reports_event.dart';
import 'reports_state.dart';

class ReportsBloc extends Bloc<ReportsEvent, ReportsState> {
  ReportsBloc(this._repo) : super(const ReportsState.initial()) {
    on<ReportsDashboardRequested>(_onDashboard);
    on<ReportsPaymentsRequested>(_onPayments);
    on<ReportsEquipmentProfitRequested>(_onEqProfit);
    on<ReportsTopEquipmentRequested>(_onTopEquipment);
    on<ReportsTopClientsRequested>(_onTopClients);
    on<ReportsLateClientsRequested>(_onLateClients);
    on<ReportsRevenueRequested>(_onRevenue);
    on<ReportsRevenueByUserRequested>(_onRevenueByUser);
    on<ReportsRefreshAllRequested>(_onRefreshAll);
  }

  final ReportsRepository _repo;

  Future<void> _onDashboard(ReportsDashboardRequested event, Emitter<ReportsState> emit) async {
    emit(state.copyWith(dashboardStatus: ReportsStatus.loading, dashboardError: null));
    try {
      final d = await _repo.dashboard(from: event.from, to: event.to);
      emit(state.copyWith(dashboardStatus: ReportsStatus.success, dashboard: d));
    } catch (e) {
      emit(state.copyWith(dashboardStatus: ReportsStatus.failure, dashboardError: e.toString()));
    }
  }

  Future<void> _onPayments(ReportsPaymentsRequested event, Emitter<ReportsState> emit) async {
    emit(state.copyWith(paymentsStatus: ReportsStatus.loading, paymentsError: null));
    try {
      final r = await _repo.paymentsReport(from: event.from, to: event.to, type: event.type);
      emit(state.copyWith(paymentsStatus: ReportsStatus.success, payments: r));
    } catch (e) {
      emit(state.copyWith(paymentsStatus: ReportsStatus.failure, paymentsError: e.toString()));
    }
  }

  Future<void> _onEqProfit(ReportsEquipmentProfitRequested event, Emitter<ReportsState> emit) async {
    emit(state.copyWith(equipmentProfitStatus: ReportsStatus.loading, equipmentProfitError: null));
    try {
      final rows = await _repo.equipmentProfit(from: event.from, to: event.to);
      emit(state.copyWith(equipmentProfitStatus: ReportsStatus.success, equipmentProfit: rows));
    } catch (e) {
      emit(state.copyWith(equipmentProfitStatus: ReportsStatus.failure, equipmentProfitError: e.toString()));
    }
  }

  Future<void> _onTopEquipment(ReportsTopEquipmentRequested event, Emitter<ReportsState> emit) async {
    emit(state.copyWith(topEquipmentStatus: ReportsStatus.loading, topEquipmentError: null));
    try {
      final rows = await _repo.topEquipment(from: event.from, to: event.to, limit: event.limit);
      emit(state.copyWith(topEquipmentStatus: ReportsStatus.success, topEquipment: rows));
    } catch (e) {
      emit(state.copyWith(topEquipmentStatus: ReportsStatus.failure, topEquipmentError: e.toString()));
    }
  }

  Future<void> _onTopClients(ReportsTopClientsRequested event, Emitter<ReportsState> emit) async {
    emit(state.copyWith(topClientsStatus: ReportsStatus.loading, topClientsError: null));
    try {
      final rows = await _repo.topClients(from: event.from, to: event.to, limit: event.limit);
      emit(state.copyWith(topClientsStatus: ReportsStatus.success, topClients: rows));
    } catch (e) {
      emit(state.copyWith(topClientsStatus: ReportsStatus.failure, topClientsError: e.toString()));
    }
  }

  Future<void> _onLateClients(ReportsLateClientsRequested event, Emitter<ReportsState> emit) async {
    emit(state.copyWith(lateClientsStatus: ReportsStatus.loading, lateClientsError: null));
    try {
      final rows = await _repo.lateClients(from: event.from, to: event.to, limit: event.limit);
      emit(state.copyWith(lateClientsStatus: ReportsStatus.success, lateClients: rows));
    } catch (e) {
      emit(state.copyWith(lateClientsStatus: ReportsStatus.failure, lateClientsError: e.toString()));
    }
  }

  Future<void> _onRevenue(ReportsRevenueRequested event, Emitter<ReportsState> emit) async {
    emit(state.copyWith(revenueStatus: ReportsStatus.loading, revenueError: null, revenueGroup: event.group));
    try {
      final rows = await _repo.revenue(group: event.group, from: event.from, to: event.to);
      emit(state.copyWith(revenueStatus: ReportsStatus.success, revenue: rows));
    } catch (e) {
      emit(state.copyWith(revenueStatus: ReportsStatus.failure, revenueError: e.toString()));
    }
  }

  Future<void> _onRevenueByUser(ReportsRevenueByUserRequested event, Emitter<ReportsState> emit) async {
    emit(state.copyWith(revenueByUserStatus: ReportsStatus.loading, revenueByUserError: null));
    try {
      final rows = await _repo.revenueByUser(from: event.from, to: event.to);
      emit(state.copyWith(revenueByUserStatus: ReportsStatus.success, revenueByUser: rows));
    } catch (e) {
      emit(state.copyWith(revenueByUserStatus: ReportsStatus.failure, revenueByUserError: e.toString()));
    }
  }

  Future<void> _onRefreshAll(ReportsRefreshAllRequested event, Emitter<ReportsState> emit) async {
    add(ReportsDashboardRequested(from: event.from, to: event.to));
    add(ReportsPaymentsRequested(from: event.from, to: event.to));
    add(ReportsEquipmentProfitRequested(from: event.from, to: event.to));
    add(ReportsTopEquipmentRequested(from: event.from, to: event.to));
    add(ReportsTopClientsRequested(from: event.from, to: event.to));
    add(ReportsLateClientsRequested(from: event.from, to: event.to));
    add(ReportsRevenueRequested(group: event.revenueGroup, from: event.from, to: event.to));
    add(ReportsRevenueByUserRequested(from: event.from, to: event.to));
  }
}
