part of 'shifts_bloc.dart';

enum ShiftsStatus { initial, loading, success, failure }

class ShiftsState extends Equatable {
  const ShiftsState({
    required this.status,
    required this.items,
    this.error,
    this.working = false,
    this.filterFrom,
    this.filterTo,
  });

  const ShiftsState.initial()
      : status = ShiftsStatus.initial,
        items = const [],
        error = null,
        working = false,
        filterFrom = null,
        filterTo = null;

  final ShiftsStatus status;
  final List<ShiftClosing> items;
  final String? error;
  final bool working;
  final String? filterFrom;
  final String? filterTo;

  ShiftsState copyWith({
    ShiftsStatus? status,
    List<ShiftClosing>? items,
    String? error,
    bool? working,
    String? filterFrom,
    String? filterTo,
  }) {
    return ShiftsState(
      status: status ?? this.status,
      items: items ?? this.items,
      error: error,
      working: working ?? this.working,
      filterFrom: filterFrom ?? this.filterFrom,
      filterTo: filterTo ?? this.filterTo,
    );
  }

  @override
  List<Object?> get props => [status, items, error, working, filterFrom, filterTo];
}
