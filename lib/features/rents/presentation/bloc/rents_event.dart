part of 'rents_bloc.dart';

abstract class RentsEvent extends Equatable {
  const RentsEvent();

  @override
  List<Object?> get props => [];
}

class RentsRequested extends RentsEvent {
  const RentsRequested({this.status});
  final String? status;

  @override
  List<Object?> get props => [status];
}

class RentOpened extends RentsEvent {
  const RentOpened({
    required this.clientId,
    required this.startDatetime,
    this.items,
    this.notes,
  });

  final int clientId;
  final String startDatetime;
  final List<Map<String, dynamic>>? items;
  final String? notes;

  @override
  List<Object?> get props => [
        clientId,
        startDatetime,
        items,
        notes,
      ];
}

class RentEquipmentReplaced extends RentsEvent {
  const RentEquipmentReplaced({
    required this.rentId,
    required this.oldEquipmentId,
    required this.newEquipmentId,
    this.notes,
  });

  final int rentId;
  final int oldEquipmentId;
  final int newEquipmentId;
  final String? notes;

  @override
  List<Object?> get props => [rentId, oldEquipmentId, newEquipmentId, notes];
}

class RentClosed extends RentsEvent {
  const RentClosed({
    required this.rentId,
    required this.endDatetime,
  });

  final int rentId;
  final String endDatetime;

  @override
  List<Object?> get props => [rentId, endDatetime];
}

class RentCancelled extends RentsEvent {
  const RentCancelled({
    required this.rentId,
    this.reason,
  });

  final int rentId;
  final String? reason;

  @override
  List<Object?> get props => [rentId, reason];
}

class RentNotesUpdated extends RentsEvent {
  const RentNotesUpdated({
    required this.rentId,
    required this.notes,
  });

  final int rentId;
  final String notes;

  @override
  List<Object?> get props => [rentId, notes];
}