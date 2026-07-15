part of 'equipment_bloc.dart';

sealed class EquipmentEvent extends Equatable {
  const EquipmentEvent();
  @override
  List<Object?> get props => [];
}

class EquipmentRequested extends EquipmentEvent {
  final String? sortBy;
  final String? sortOrder;
  final String? query;
  final String? filterStatus;

  const EquipmentRequested({this.sortBy, this.sortOrder, this.query, this.filterStatus});

  @override
  List<Object?> get props => [sortBy, sortOrder, query, filterStatus];
}

class EquipmentCreated extends EquipmentEvent {
  const EquipmentCreated({
    required this.name,
    this.model,
    this.serialNo,
    this.status = 'available',
    this.dailyRate = 0,
    this.depreciationRate = 0,
    this.lastMaintenanceDate,
    this.isActive = true,
    this.purchasePrice = 0,
    this.salvageValue = 0,
    this.usefulLifeMonths = 60,
    this.depreciationStartDate,
    this.estimatedUsageDays = 365,
    this.seriesCount = 1,
  });

  final String name;
  final String? model;
  final String? serialNo;
  final String status;
  final double dailyRate;
  final double depreciationRate;
  final String? lastMaintenanceDate;
  final bool isActive;
  final double purchasePrice;
  final double salvageValue;
  final int usefulLifeMonths;
  final String? depreciationStartDate;
  final int estimatedUsageDays;
  final int seriesCount;

  @override
  List<Object?> get props => [name, model, serialNo, status, dailyRate, depreciationRate, lastMaintenanceDate, isActive, purchasePrice, salvageValue, usefulLifeMonths, depreciationStartDate, estimatedUsageDays, seriesCount];
}

class EquipmentUpdated extends EquipmentEvent {
  const EquipmentUpdated({
    required this.id,
    required this.name,
    this.model,
    this.serialNo,
    this.status = 'available',
    this.dailyRate = 0,
    this.depreciationRate = 0,
    this.lastMaintenanceDate,
    this.isActive = true,
    this.purchasePrice = 0,
    this.salvageValue = 0,
    this.usefulLifeMonths = 60,
    this.depreciationStartDate,
    this.estimatedUsageDays = 365,
  });

  final int id;
  final String name;
  final String? model;
  final String? serialNo;
  final String status;
  final double dailyRate;
  final double depreciationRate;
  final String? lastMaintenanceDate;
  final bool isActive;
  final double purchasePrice;
  final double salvageValue;
  final int usefulLifeMonths;
  final String? depreciationStartDate;
  final int estimatedUsageDays;

  @override
  List<Object?> get props => [id, name, model, serialNo, status, dailyRate, depreciationRate, lastMaintenanceDate, isActive, purchasePrice, salvageValue, usefulLifeMonths, depreciationStartDate, estimatedUsageDays];
}

class EquipmentDeleted extends EquipmentEvent {
  const EquipmentDeleted(this.id);
  final int id;
  @override
  List<Object?> get props => [id];
}
