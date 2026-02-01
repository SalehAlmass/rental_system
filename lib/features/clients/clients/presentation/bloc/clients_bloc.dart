import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:rental_app/features/clients/data/repositories/clients_repository_impl.dart';
import 'package:rental_app/features/clients/domain/entities/models.dart';

part 'clients_event.dart';
part 'clients_state.dart';

class ClientsBloc extends Bloc<ClientsEvent, ClientsState> {
  ClientsBloc(this._repo) : super(const ClientsState.initial()) {
    on<ClientsRequested>(_onRequested);
    on<ClientCreated>(_onCreated);
    on<ClientUpdated>(_onUpdated);
    on<ClientDeleted>(_onDeleted);
  }

  final ClientsRepository _repo;

  Future<void> _onRequested(
      ClientsRequested event, Emitter<ClientsState> emit) async {
    emit(state.copyWith(status: ClientsStatus.loading, error: null));
    try {
      final items = await _repo.list();
      emit(state.copyWith(status: ClientsStatus.success, items: items, action: ClientsAction.none));
    } catch (e) {
      emit(state.copyWith(status: ClientsStatus.failure, error: e.toString(), action: ClientsAction.none));
    }
  }

  Future<void> _onCreated(
      ClientCreated event, Emitter<ClientsState> emit) async {
    emit(state.copyWith(
      creating: true,
      error: null,
      action: ClientsAction.none,
    ));

    try {
      await _repo.create(
        name: event.name,
        nationalId: event.nationalId,
        phone: event.phone,
        address: event.address,
        creditLimit: event.creditLimit,
        isFrozen: event.isFrozen,
      );

      final items = await _repo.list();
      emit(state.copyWith(
        creating: false,
        status: ClientsStatus.success,
        items: items,
        action: ClientsAction.created,
      ));
      emit(state.copyWith(action: ClientsAction.none));
    } catch (e) {
      emit(state.copyWith(
        creating: false,
        error: e.toString(),
        action: ClientsAction.none,
      ));
    }
  }

  Future<void> _onUpdated(
      ClientUpdated event, Emitter<ClientsState> emit) async {
    emit(state.copyWith(
      creating: true,
      error: null,
      action: ClientsAction.none,
    ));

    try {
      await _repo.update(
        id: event.id,
        name: event.name,
        nationalId: event.nationalId,
        phone: event.phone,
        address: event.address,
        creditLimit: event.creditLimit,
        isFrozen: event.isFrozen,
      );

      final items = await _repo.list();
      emit(state.copyWith(
        creating: false,
        status: ClientsStatus.success,
        items: items,
        action: ClientsAction.updated,
      ));
      emit(state.copyWith(action: ClientsAction.none));
    } catch (e) {
      emit(state.copyWith(
        creating: false,
        error: e.toString(),
        action: ClientsAction.none,
      ));
    }
  }

  Future<void> _onDeleted(
      ClientDeleted event, Emitter<ClientsState> emit) async {
    emit(state.copyWith(
      creating: true,
      error: null,
      action: ClientsAction.none,
    ));

    try {
      await _repo.delete(event.id);

      final items = await _repo.list();
      emit(state.copyWith(
        creating: false,
        status: ClientsStatus.success,
        items: items,
        action: ClientsAction.deleted,
      ));
      emit(state.copyWith(action: ClientsAction.none));
    } catch (e) {
      emit(state.copyWith(
        creating: false,
        error: e.toString(),
        action: ClientsAction.none,
      ));
    }
  }
}
