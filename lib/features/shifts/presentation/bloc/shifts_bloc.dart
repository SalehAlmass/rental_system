import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:rental_app/features/shifts/data/repositories/shifts_repository.dart';
import 'package:rental_app/features/shifts/domain/entities/shift_closing.dart';

part 'shifts_event.dart';
part 'shifts_state.dart';

class ShiftsBloc extends Bloc<ShiftsEvent, ShiftsState> {
  ShiftsBloc(this._repo) : super(const ShiftsState.initial()) {
    on<ShiftsRequested>(_onRequested);
    on<ShiftClosed>(_onClosed);
  }

  final ShiftsRepository _repo;

  Future<void> _onRequested(ShiftsRequested event, Emitter<ShiftsState> emit) async {
    emit(state.copyWith(status: ShiftsStatus.loading, error: null));
    try {
      final items = await _repo.list(from: event.from, to: event.to);
      emit(state.copyWith(status: ShiftsStatus.success, items: items));
    } catch (e) {
      emit(state.copyWith(status: ShiftsStatus.failure, error: e.toString()));
    }
  }

  Future<void> _onClosed(ShiftClosed event, Emitter<ShiftsState> emit) async {
    emit(state.copyWith(working: true, error: null));
    try {
      await _repo.close(
        shiftDate: event.shiftDate,
        cashTotal: event.cashTotal,
        transferTotal: event.transferTotal,
        cashInDrawer: event.cashInDrawer,
        note: event.note,
      );
      final items = await _repo.list(from: state.filterFrom, to: state.filterTo);
      emit(state.copyWith(working: false, status: ShiftsStatus.success, items: items));
    } catch (e) {
      emit(state.copyWith(working: false, error: e.toString()));
    }
  }
}
