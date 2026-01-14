import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:rental_app/features/equipment/data/repositories/equipment_repository_impl.dart';
import 'package:rental_app/features/equipment/domain/entities/models.dart';

part 'equipment_event.dart';
part 'equipment_state.dart';

class EquipmentBloc extends Bloc<EquipmentEvent, EquipmentState> {
  EquipmentBloc(this._repo) : super(const EquipmentState.initial()) {
    on<EquipmentRequested>(_onRequested);
    on<EquipmentCreated>(_onCreated);
    on<EquipmentUpdated>(_onUpdated);
    on<EquipmentDeleted>(_onDeleted);
  }

  final EquipmentRepository _repo;

  Future<void> _onRequested(EquipmentRequested event, Emitter<EquipmentState> emit) async {
    emit(state.copyWith(status: EquipmentStatus.loading, error: null));
    try {
      final items = await _repo.list();
      emit(state.copyWith(status: EquipmentStatus.success, items: items));
    } catch (e) {
      emit(state.copyWith(status: EquipmentStatus.failure, error: e.toString()));
    }
  }

  Future<void> _onCreated(EquipmentCreated event, Emitter<EquipmentState> emit) async {
    emit(state.copyWith(working: true, error: null));
    try {
      await _repo.create(
        name: event.name,
        model: event.model,
        serialNo: event.serialNo,
        status: event.status,
        hourlyRate: event.hourlyRate,
        depreciationRate: event.depreciationRate,
        lastMaintenanceDate: event.lastMaintenanceDate,
        isActive: event.isActive,
      );
      final items = await _repo.list();
      emit(state.copyWith(working: false, status: EquipmentStatus.success, items: items));
    } catch (e) {
      emit(state.copyWith(working: false, error: e.toString()));
    }
  }

  Future<void> _onUpdated(EquipmentUpdated event, Emitter<EquipmentState> emit) async {
    emit(state.copyWith(working: true, error: null));
    try {
      await _repo.update(
        id: event.id,
        name: event.name,
        model: event.model,
        serialNo: event.serialNo,
        status: event.status,
        hourlyRate: event.hourlyRate,
        depreciationRate: event.depreciationRate,
        lastMaintenanceDate: event.lastMaintenanceDate,
        isActive: event.isActive,
      );
      final items = await _repo.list();
      emit(state.copyWith(working: false, status: EquipmentStatus.success, items: items));
    } catch (e) {
      emit(state.copyWith(working: false, error: e.toString()));
    }
  }

  Future<void> _onDeleted(EquipmentDeleted event, Emitter<EquipmentState> emit) async {
    emit(state.copyWith(working: true, error: null));
    try {
      await _repo.delete(event.id);
      final items = await _repo.list();
      emit(state.copyWith(working: false, status: EquipmentStatus.success, items: items));
    } catch (e) {
      emit(state.copyWith(working: false, error: e.toString()));
    }
  }
}
