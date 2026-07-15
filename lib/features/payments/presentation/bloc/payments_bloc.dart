import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:rental_app/features/payments/data/repositories/payments_repository_impl.dart';
import 'package:rental_app/features/payments/domain/entities/models.dart';

part 'payments_event.dart';
part 'payments_state.dart';

class PaymentsBloc extends Bloc<PaymentsEvent, PaymentsState> {
  PaymentsBloc(this._repo) : super(const PaymentsState.initial()) {
    on<PaymentsRequested>(_onRequested);
    on<PaymentCreated>(_onCreated);
    on<PaymentUpdated>(_onUpdated);
    on<PaymentVoided>(_onVoided);
  }

  final PaymentsRepository _repo;

  Future<void> _onRequested(
    PaymentsRequested event,
    Emitter<PaymentsState> emit,
  ) async {
    emit(state.copyWith(status: PaymentsStatus.loading, error: null));
    try {
      final result = await _repo.list(
        showVoided: event.showVoided,
        query: event.query,
        page: event.page,
        perPage: event.perPage,
      );
      emit(
        state.copyWith(
          status: PaymentsStatus.success,
          items: result.items,
          summary: result.summary,
          total: result.total,
          showVoided: event.showVoided,
          query: event.query,
          page: event.page,
          perPage: event.perPage,
        ),
      );
    } catch (e) {
      emit(state.copyWith(status: PaymentsStatus.failure, error: e.toString()));
    }
  }

  Future<void> _onCreated(
    PaymentCreated event,
    Emitter<PaymentsState> emit,
  ) async {
    emit(state.copyWith(working: true, error: null));
    try {
      await _repo.create(
        type: event.type,
        amount: event.amount,
        clientId: event.clientId,
        rentId: event.rentId,
        equipmentId: event.equipmentId,
        method: event.method,
        referenceNo: event.referenceNo,
        notes: event.notes,
      );
      final result = await _repo.list(
        showVoided: state.showVoided,
        query: state.query,
        page: state.page,
        perPage: state.perPage,
      );
      emit(
        state.copyWith(
          working: false,
          status: PaymentsStatus.success,
          items: result.items,
          summary: result.summary,
          total: result.total,
        ),
      );
    } catch (e) {
      emit(state.copyWith(working: false, error: e.toString()));
    }
  }

  Future<void> _onUpdated(
    PaymentUpdated event,
    Emitter<PaymentsState> emit,
  ) async {
    emit(state.copyWith(working: true, error: null));
    try {
      await _repo.update(
        id: event.id,
        amount: event.amount,
        clientId: event.clientId,
        rentId: event.rentId,
        equipmentId: event.equipmentId,
        method: event.method,
        referenceNo: event.referenceNo,
        notes: event.notes,
      );
      final result = await _repo.list(
        showVoided: state.showVoided,
        query: state.query,
        page: state.page,
        perPage: state.perPage,
      );
      emit(
        state.copyWith(
          working: false,
          status: PaymentsStatus.success,
          items: result.items,
          summary: result.summary,
          total: result.total,
        ),
      );
    } catch (e) {
      emit(state.copyWith(working: false, error: e.toString()));
    }
  }

  Future<void> _onVoided(
    PaymentVoided event,
    Emitter<PaymentsState> emit,
  ) async {
    emit(state.copyWith(working: true, error: null));
    try {
      await _repo.voidPayment(id: event.id, reason: event.reason);
      final result = await _repo.list(
        showVoided: state.showVoided,
        query: state.query,
        page: state.page,
        perPage: state.perPage,
      );
      emit(
        state.copyWith(
          working: false,
          status: PaymentsStatus.success,
          items: result.items,
          summary: result.summary,
          total: result.total,
        ),
      );
    } catch (e) {
      emit(state.copyWith(working: false, error: e.toString()));
    }
  }
}
