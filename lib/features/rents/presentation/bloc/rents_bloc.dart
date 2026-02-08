import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:rental_app/features/rents/data/repositories/rents_repository_impl.dart';
import 'package:rental_app/features/rents/domain/entities/models.dart';

part 'rents_event.dart';
part 'rents_state.dart';

class RentsBloc extends Bloc<RentsEvent, RentsState> {
  RentsBloc(this._repo) : super(const RentsState.initial()) {
    on<RentsRequested>(_onRequested);
    on<RentOpened>(_onOpened);
    on<RentClosed>(_onClosed);
    on<RentCancelled>(_onCancelled);
    on<RentNotesUpdated>(_onNotesUpdated);
  }

  final RentsRepository _repo;

  Future<void> _onRequested(RentsRequested event, Emitter<RentsState> emit) async {
    emit(state.copyWith(status: RentsStatus.loading, error: null, filterStatus: event.status));
    try {
      final items = await _repo.list(status: event.status);
      emit(state.copyWith(status: RentsStatus.success, items: items));
    } catch (e) {
      emit(state.copyWith(status: RentsStatus.failure, error: e.toString()));
    }
  }

  Future<void> _onOpened(RentOpened event, Emitter<RentsState> emit) async {
    emit(state.copyWith(working: true, error: null));
    try {
      await _repo.openRent(
        clientId: event.clientId,
        equipmentId: event.equipmentId,
        startDatetime: event.startDatetime,
        hourlyRate: event.hourlyRate,
        notes: event.notes,
      );
      final items = await _repo.list(status: state.filterStatus);
      emit(state.copyWith(working: false, status: RentsStatus.success, items: items));
    } catch (e) {
      emit(state.copyWith(working: false, error: e.toString()));
    }
  }

  Future<void> _onClosed(RentClosed event, Emitter<RentsState> emit) async {
    emit(state.copyWith(working: true, error: null));
    try {
      await _repo.closeRent(rentId: event.rentId, endDatetime: event.endDatetime);
      final items = await _repo.list(status: state.filterStatus);
      emit(state.copyWith(working: false, status: RentsStatus.success, items: items));
    } catch (e) {
      emit(state.copyWith(working: false, error: e.toString()));
    }
  }

  Future<void> _onCancelled(RentCancelled event, Emitter<RentsState> emit) async {
    emit(state.copyWith(working: true, error: null));
    try {
      await _repo.cancelRent(rentId: event.rentId, reason: event.reason);
      final items = await _repo.list(status: state.filterStatus);
      emit(state.copyWith(working: false, status: RentsStatus.success, items: items));
    } catch (e) {
      emit(state.copyWith(working: false, error: e.toString()));
    }
  }

  Future<void> _onNotesUpdated(RentNotesUpdated event, Emitter<RentsState> emit) async {
    emit(state.copyWith(working: true, error: null));
    try {
      await _repo.updateNotes(rentId: event.rentId, notes: event.notes);
      final items = await _repo.list(status: state.filterStatus);
      emit(state.copyWith(working: false, status: RentsStatus.success, items: items));
    } catch (e) {
      emit(state.copyWith(working: false, error: e.toString()));
    }
  }
}
