part of 'shifts_bloc.dart';

sealed class ShiftsEvent extends Equatable {
  const ShiftsEvent();
  @override
  List<Object?> get props => [];
}

final class ShiftsRequested extends ShiftsEvent {
  const ShiftsRequested({this.from, this.to});
  final String? from;
  final String? to;

  @override
  List<Object?> get props => [from, to];
}

final class ShiftClosed extends ShiftsEvent {
  const ShiftClosed({
    this.shiftDate,
    required this.cashTotal,
    required this.transferTotal,
    required this.cashInDrawer,
    this.note,
  });

  final String? shiftDate;
  final double cashTotal;
  final double transferTotal;
  final double cashInDrawer;
  final String? note;

  @override
  List<Object?> get props => [shiftDate, cashTotal, transferTotal, cashInDrawer, note];
}
