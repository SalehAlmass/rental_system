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
    on<RentEquipmentReplaced>(_onEquipmentReplaced);
  }

  final RentsRepository _repo;

  Future<void> _onRequested(
    RentsRequested event,
    Emitter<RentsState> emit,
  ) async {
    final sortBy = event.sortBy ?? state.sortBy;
    final sortOrder = event.sortOrder ?? state.sortOrder;

    emit(
      state.copyWith(
        status: RentsStatus.loading,
        error: null,
        filterStatus: event.status,
        currentPage: event.page,
        perPage: event.perPage,
        searchQuery: event.searchQuery,
        sortBy: sortBy,
        sortOrder: sortOrder,
      ),
    );

    try {
      final res = await _repo.listPaginated(
        status: event.status,
        page: event.page,
        perPage: event.perPage,
        searchQuery: event.searchQuery,
        sortBy: sortBy,
        sortOrder: sortOrder,
      );
      emit(
        state.copyWith(
          status: RentsStatus.success,
          items: res.items,
          totalCount: res.total,
          currentPage: event.page,
          perPage: event.perPage,
          searchQuery: event.searchQuery,
          sortBy: sortBy,
          sortOrder: sortOrder,
          error: null,
        ),
      );
    } catch (e) {
      emit(
        state.copyWith(
          status: RentsStatus.failure,
          error: e.toString(),
        ),
      );
    }
  }

  Future<void> _onEquipmentReplaced(
    RentEquipmentReplaced event,
    Emitter<RentsState> emit,
  ) async {
    emit(state.copyWith(working: true, error: null));

    try {
      await _repo.replaceEquipment(
        rentId: event.rentId,
        oldEquipmentId: event.oldEquipmentId,
        newEquipmentId: event.newEquipmentId,
        notes: event.notes,
      );

      final res = await _repo.listPaginated(
        status: state.filterStatus,
        page: state.currentPage,
        perPage: state.perPage,
        searchQuery: state.searchQuery,
      );

      emit(
        state.copyWith(
          working: false,
          status: RentsStatus.success,
          items: res.items,
          totalCount: res.total,
          error: null,
        ),
      );
    } catch (e) {
      emit(
        state.copyWith(
          working: false,
          error: e.toString(),
        ),
      );
    }
  }

  Future<void> _onOpened(
    RentOpened event,
    Emitter<RentsState> emit,
  ) async {
    emit(state.copyWith(working: true, error: null));

    try {
      await _repo.openRent(
        clientId: event.clientId,
        items: event.items,
        startDatetime: event.startDatetime,
        notes: event.notes,
      );

      final res = await _repo.listPaginated(
        status: state.filterStatus,
        page: 1,
        perPage: state.perPage,
        searchQuery: '',
      );

      emit(
        state.copyWith(
          working: false,
          status: RentsStatus.success,
          items: res.items,
          totalCount: res.total,
          currentPage: 1,
          searchQuery: '',
          error: null,
        ),
      );
    } catch (e) {
      emit(
        state.copyWith(
          working: false,
          error: e.toString(),
        ),
      );
    }
  }

  Future<void> _onClosed(
    RentClosed event,
    Emitter<RentsState> emit,
  ) async {
    emit(state.copyWith(working: true, error: null));

    try {
      await _repo.closeRent(
        rentId: event.rentId,
        endDatetime: event.endDatetime,
      );

      final res = await _repo.listPaginated(
        status: state.filterStatus,
        page: state.currentPage,
        perPage: state.perPage,
        searchQuery: state.searchQuery,
      );

      emit(
        state.copyWith(
          working: false,
          status: RentsStatus.success,
          items: res.items,
          totalCount: res.total,
          error: null,
        ),
      );
    } catch (e) {
      emit(
        state.copyWith(
          working: false,
          error: e.toString(),
        ),
      );
    }
  }

  Future<void> _onCancelled(
    RentCancelled event,
    Emitter<RentsState> emit,
  ) async {
    emit(state.copyWith(working: true, error: null));

    try {
      await _repo.cancelRent(
        rentId: event.rentId,
        reason: event.reason,
      );

      final res = await _repo.listPaginated(
        status: state.filterStatus,
        page: state.currentPage,
        perPage: state.perPage,
        searchQuery: state.searchQuery,
      );

      emit(
        state.copyWith(
          working: false,
          status: RentsStatus.success,
          items: res.items,
          totalCount: res.total,
          error: null,
        ),
      );
    } catch (e) {
      emit(
        state.copyWith(
          working: false,
          error: e.toString(),
        ),
      );
    }
  }

  Future<void> _onNotesUpdated(
    RentNotesUpdated event,
    Emitter<RentsState> emit,
  ) async {
    emit(state.copyWith(working: true, error: null));

    try {
      await _repo.updateNotes(
        rentId: event.rentId,
        notes: event.notes,
      );

      final res = await _repo.listPaginated(
        status: state.filterStatus,
        page: state.currentPage,
        perPage: state.perPage,
        searchQuery: state.searchQuery,
      );

      emit(
        state.copyWith(
          working: false,
          status: RentsStatus.success,
          items: res.items,
          totalCount: res.total,
          error: null,
        ),
      );
    } catch (e) {
      emit(
        state.copyWith(
          working: false,
          error: e.toString(),
        ),
      );
    }
  }
}