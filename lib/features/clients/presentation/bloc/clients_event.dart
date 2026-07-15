part of 'clients_bloc.dart';

sealed class ClientsEvent extends Equatable {
  const ClientsEvent();
  @override
  List<Object?> get props => [];
}

class ClientsRequested extends ClientsEvent {
  final String? sortBy;
  final String? sortOrder;
  final String? query;

  const ClientsRequested({this.sortBy, this.sortOrder, this.query});

  @override
  List<Object?> get props => [sortBy, sortOrder, query];
}

class ClientCreated extends ClientsEvent {
  const ClientCreated({
    required this.name,
    this.nationalId,
    this.phone,
    this.address,
    this.creditLimit = 0,
    this.isFrozen = 0,
  });

  final String name;
  final String? nationalId;
  final String? phone;
  final String? address;
  final double creditLimit;
  final int isFrozen;

  @override
  List<Object?> get props => [name, nationalId, phone, address, creditLimit, isFrozen];
}
class ClientUpdated extends ClientsEvent {
  const ClientUpdated({
    required this.id,
    required this.name,
    this.nationalId,
    this.phone,
    this.address,
    this.creditLimit = 0,
    this.isFrozen = 0,
  });

  final int id;
  final String name;
  final String? nationalId;
  final String? phone;
  final String? address;
  final double creditLimit;
  final int isFrozen;

  @override
  List<Object?> get props => [id, name, nationalId, phone, address, creditLimit, isFrozen];
}

class ClientDeleted extends ClientsEvent {
  const ClientDeleted({required this.id});

  final int id;

  @override
  List<Object?> get props => [id];
}
