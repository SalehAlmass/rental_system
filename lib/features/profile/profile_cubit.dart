import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:rental_app/core/storage/token_storage.dart';
import 'profile_repository.dart';

sealed class ProfileState {}

class ProfileInitial extends ProfileState {}

class ProfileLoading extends ProfileState {}

class ProfileLoaded extends ProfileState {
  final Map<String, dynamic> user;
  ProfileLoaded(this.user);
}

class ProfileError extends ProfileState {
  final String message;
  ProfileError(this.message);
}

/// يجلب profile من السيرفر (auth/profile) ويخزن البيانات في الstate.
class ProfileCubit extends Cubit<ProfileState> {
  final ProfileRepository repo;
  final TokenStorage storage;

  ProfileCubit({required this.repo, required this.storage}) : super(ProfileInitial());

  Future<void> load() async {
    try {
      emit(ProfileLoading());
      final u = await repo.fetchProfile();
      emit(ProfileLoaded(u));
    } catch (e) {
      emit(ProfileError(e.toString()));
    }
  }

  Future<void> refresh() => load();
}
