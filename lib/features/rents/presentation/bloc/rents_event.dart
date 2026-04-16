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
    required this.equipmentId,
    required this.startDatetime,
    this.dailyRate = 0,
    this.notes,
  });

  final int clientId;
  final int equipmentId;
  final String startDatetime;
  final double dailyRate;
  final String? notes;

  @override
  List<Object?> get props => [
        clientId,
        equipmentId,
        startDatetime,
        dailyRate,
        notes,
      ];
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