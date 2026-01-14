part of 'equipment_bloc.dart';

sealed class EquipmentEvent extends Equatable {
  const EquipmentEvent();
  @override
  List<Object?> get props => [];
}

class EquipmentRequested extends EquipmentEvent {}

class EquipmentCreated extends EquipmentEvent {
  const EquipmentCreated({
    required this.name,
    this.model,
    this.serialNo,
    this.status = 'available',
    this.hourlyRate = 0,
    this.depreciationRate = 0,
    this.lastMaintenanceDate,
    this.isActive = true,
  });

  final String name;
  final String? model;
  final String? serialNo;
  final String status;
  final double hourlyRate;
  final double depreciationRate;
  final String? lastMaintenanceDate;
  final bool isActive;

  @override
  List<Object?> get props => [name, model, serialNo, status, hourlyRate, depreciationRate, lastMaintenanceDate, isActive];
}

class EquipmentUpdated extends EquipmentEvent {
  const EquipmentUpdated({
    required this.id,
    required this.name,
    this.model,
    this.serialNo,
    this.status = 'available',
    this.hourlyRate = 0,
    this.depreciationRate = 0,
    this.lastMaintenanceDate,
    this.isActive = true,
  });

  final int id;
  final String name;
  final String? model;
  final String? serialNo;
  final String status;
  final double hourlyRate;
  final double depreciationRate;
  final String? lastMaintenanceDate;
  final bool isActive;

  @override
  List<Object?> get props => [id, name, model, serialNo, status, hourlyRate, depreciationRate, lastMaintenanceDate, isActive];
}

class EquipmentDeleted extends EquipmentEvent {
  const EquipmentDeleted(this.id);
  final int id;
  @override
  List<Object?> get props => [id];
}
