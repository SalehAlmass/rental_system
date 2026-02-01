import 'package:equatable/equatable.dart';

sealed class ReportsEvent extends Equatable {
  const ReportsEvent();
  @override
  List<Object?> get props => [];
}

class ReportsDashboardRequested extends ReportsEvent {
  final String? from;
  final String? to;
  const ReportsDashboardRequested({this.from, this.to});
  @override
  List<Object?> get props => [from, to];
}

class ReportsPaymentsRequested extends ReportsEvent {
  final String? from;
  final String? to;
  final String type; // all|in|out
  const ReportsPaymentsRequested({this.from, this.to, this.type = 'all'});
  @override
  List<Object?> get props => [from, to, type];
}

class ReportsEquipmentProfitRequested extends ReportsEvent {
  final String? from;
  final String? to;
  const ReportsEquipmentProfitRequested({this.from, this.to});
  @override
  List<Object?> get props => [from, to];
}

class ReportsTopEquipmentRequested extends ReportsEvent {
  final String? from;
  final String? to;
  final int limit;
  const ReportsTopEquipmentRequested({this.from, this.to, this.limit = 10});
  @override
  List<Object?> get props => [from, to, limit];
}

class ReportsTopClientsRequested extends ReportsEvent {
  final String? from;
  final String? to;
  final int limit;
  const ReportsTopClientsRequested({this.from, this.to, this.limit = 10});
  @override
  List<Object?> get props => [from, to, limit];
}

class ReportsLateClientsRequested extends ReportsEvent {
  final String? from;
  final String? to;
  final int limit;
  const ReportsLateClientsRequested({this.from, this.to, this.limit = 10});
  @override
  List<Object?> get props => [from, to, limit];
}

class ReportsRevenueRequested extends ReportsEvent {
  final String group; // day|month|year
  final String? from;
  final String? to;
  const ReportsRevenueRequested({required this.group, this.from, this.to});
  @override
  List<Object?> get props => [group, from, to];
}

class ReportsRevenueByUserRequested extends ReportsEvent {
  final String? from;
  final String? to;
  const ReportsRevenueByUserRequested({this.from, this.to});
  @override
  List<Object?> get props => [from, to];
}

class ReportsRefreshAllRequested extends ReportsEvent {
  final String? from;
  final String? to;
  final String revenueGroup;
  const ReportsRefreshAllRequested({this.from, this.to, this.revenueGroup = 'day'});
  @override
  List<Object?> get props => [from, to, revenueGroup];
}
