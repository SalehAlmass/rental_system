import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:rental_app/features/dashboard/data/repositories/dashboard_repository_impl.dart';
import 'package:rental_app/features/dashboard/domain/entities/models.dart';

part 'dashboard_event.dart';
part 'dashboard_state.dart';

class DashboardBloc extends Bloc<DashboardEvent, DashboardState> {
  DashboardBloc(this._repo) : super(const DashboardState.initial()) {
    on<DashboardRequested>(_onRequested);
  }

  final DashboardRepository _repo;

  Future<void> _onRequested(DashboardRequested event, Emitter<DashboardState> emit) async {
    emit(state.copyWith(status: DashboardStatus.loading));
    try {
      final stats = await _repo.fetchStats();
      emit(state.copyWith(status: DashboardStatus.success, stats: stats));
    } catch (e) {
      emit(state.copyWith(status: DashboardStatus.failure, error: e.toString()));
    }
  }
}
