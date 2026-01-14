part of 'rents_bloc.dart';

sealed class RentsEvent extends Equatable {
  const RentsEvent();
  @override
  List<Object?> get props => [];
}

class RentsRequested extends RentsEvent {}

class RentOpened extends RentsEvent {
  const RentOpened({
    required this.clientId,
    required this.equipmentId,
    required this.startDatetime,
    this.hourlyRate = 0,
    this.notes,
  });

  final int clientId;
  final int equipmentId;
  final String startDatetime;
  final double hourlyRate;
  final String? notes;

  @override
  List<Object?> get props => [clientId, equipmentId, startDatetime, hourlyRate, notes];
}

class RentClosed extends RentsEvent {
  const RentClosed({required this.rentId, required this.endDatetime});
  final int rentId;
  final String endDatetime;
  @override
  List<Object?> get props => [rentId, endDatetime];
}

class RentCancelled extends RentsEvent {
  const RentCancelled({required this.rentId, this.reason});
  final int rentId;
  final String? reason;
  @override
  List<Object?> get props => [rentId, reason];
}

class RentNotesUpdated extends RentsEvent {
  const RentNotesUpdated({required this.rentId, required this.notes});
  final int rentId;
  final String notes;
  @override
  List<Object?> get props => [rentId, notes];
}
