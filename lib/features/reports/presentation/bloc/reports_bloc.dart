import 'package:flutter_bloc/flutter_bloc.dart';
import '../../data/repositories/reports_repository_impl.dart';
import 'reports_event.dart';
import 'reports_state.dart';

class ReportsBloc extends Bloc<ReportsEvent, ReportsState> {
  ReportsBloc(this._repo) : super(const ReportsState.initial()) {
    on<ReportsDashboardRequested>(_loadDashboard);
  }

  final ReportsRepository _repo;

  Future<void> _loadDashboard(
    ReportsDashboardRequested event,
    Emitter<ReportsState> emit,
  ) async {
    emit(state.copyWith(status: ReportsStatus.loading));
    try {
      final data = await _repo.getDashboard();
      emit(state.copyWith(status: ReportsStatus.success, data: data));
    } catch (e) {
      emit(state.copyWith(
        status: ReportsStatus.failure,
        error: e.toString(),
      ));
    }
  }
}
