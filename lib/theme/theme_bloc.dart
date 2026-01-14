import 'package:bloc/bloc.dart';
import 'package:flutter/material.dart';
import 'package:equatable/equatable.dart';

/* -------------------- EVENTS -------------------- */
abstract class ThemeEvent extends Equatable {
  const ThemeEvent();

  @override
  List<Object?> get props => [];
}

class ThemeToggled extends ThemeEvent {}

/* -------------------- STATE -------------------- */
class ThemeState extends Equatable {
  final ThemeMode mode;

  const ThemeState(this.mode);

  @override
  List<Object?> get props => [mode];

  ThemeState copyWith({ThemeMode? mode}) => ThemeState(mode ?? this.mode);
}

/* -------------------- BLOC -------------------- */
class ThemeBloc extends Bloc<ThemeEvent, ThemeState> {
  ThemeBloc() : super(const ThemeState(ThemeMode.light)) {
    on<ThemeToggled>((event, emit) {
      emit(ThemeState(
        state.mode == ThemeMode.light ? ThemeMode.dark : ThemeMode.light,
      ));
    });
  }
}
