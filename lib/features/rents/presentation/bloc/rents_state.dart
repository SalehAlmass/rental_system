part of 'rents_bloc.dart';

enum RentsStatus { initial, loading, success, failure }

class RentsState extends Equatable {
  const RentsState({
    required this.status,
    required this.items,
    this.filterStatus,
    this.error,
    this.working = false,
  });

  const RentsState.initial()
      : status = RentsStatus.initial,
        items = const [],
        filterStatus = null,
        error = null,
        working = false;

  final RentsStatus status;
  final List<Rent> items;
  /// open|closed|cancelled|null(all)
  final String? filterStatus;
  final String? error;
  final bool working;

  RentsState copyWith({
    RentsStatus? status,
    List<Rent>? items,
    String? filterStatus,
    String? error,
    bool? working,
  }) {
    return RentsState(
      status: status ?? this.status,
      items: items ?? this.items,
      filterStatus: filterStatus ?? this.filterStatus,
      error: error,
      working: working ?? this.working,
    );
  }

  @override
  List<Object?> get props => [status, items, filterStatus, error, working];
}
