import 'package:equatable/equatable.dart';

abstract class ReportsEvent extends Equatable {
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
