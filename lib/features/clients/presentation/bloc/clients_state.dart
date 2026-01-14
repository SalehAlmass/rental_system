part of 'clients_bloc.dart';

enum ClientsStatus { initial, loading, success, failure }
enum ClientsAction { none, created, updated, deleted }

class ClientsState extends Equatable {
  const ClientsState({
    required this.status,
    required this.items,
    this.error,
    this.creating = false,
    this.action = ClientsAction.none,
  });

  const ClientsState.initial()
      : status = ClientsStatus.initial,
        items = const [],
        error = null,
        creating = false,
        action = ClientsAction.none;

  final ClientsStatus status;
  final List<Client> items;
  final String? error;
  final bool creating;

  /// ✅ يحدد آخر عملية نجحت (علشان نقفل Dialog صح)
  final ClientsAction action;

  ClientsState copyWith({
    ClientsStatus? status,
    List<Client>? items,
    String? error,
    bool? creating,
    ClientsAction? action,
  }) {
    return ClientsState(
      status: status ?? this.status,
      items: items ?? this.items,
      error: error,
      creating: creating ?? this.creating,
      action: action ?? this.action,
    );
  }

  @override
  List<Object?> get props => [status, items, error, creating, action];
}
