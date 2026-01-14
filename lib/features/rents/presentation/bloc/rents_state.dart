part of 'rents_bloc.dart';

enum RentsStatus { initial, loading, success, failure }

class RentsState extends Equatable {
  const RentsState({
    required this.status,
    required this.items,
    this.error,
    this.working = false,
  });

  const RentsState.initial()
      : status = RentsStatus.initial,
        items = const [],
        error = null,
        working = false;

  final RentsStatus status;
  final List<Rent> items;
  final String? error;
  final bool working;

  RentsState copyWith({
    RentsStatus? status,
    List<Rent>? items,
    String? error,
    bool? working,
  }) {
    return RentsState(
      status: status ?? this.status,
      items: items ?? this.items,
      error: error,
      working: working ?? this.working,
    );
  }

  @override
  List<Object?> get props => [status, items, error, working];
}
