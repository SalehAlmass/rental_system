import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:rental_app/core/storage/token_storage.dart';
import 'profile_repository.dart';

sealed class ProfileState {}

class ProfileInitial extends ProfileState {}

class ProfileLoading extends ProfileState {}

class ProfileLoaded extends ProfileState {
  final Map<String, dynamic> user;
  final bool fromCache;
  ProfileLoaded(this.user, {this.fromCache = false});
}

class ProfileError extends ProfileState {
  final String message;
  ProfileError(this.message);
}

/// يجلب profile من السيرفر (auth/profile) + يعرض cache أولاً من TokenStorage.
class ProfileCubit extends Cubit<ProfileState> {
  final ProfileRepository repo;
  final TokenStorage storage;

  ProfileCubit({
    required this.repo,
    required this.storage,
  }) : super(ProfileInitial());

  Future<void> load() async {
    // 1) اعرض الكاش بسرعة (إن وجد)
    final cached = await storage.getProfileCache();
    if (cached != null) {
      emit(ProfileLoaded({
        'username': cached['username'],
        'role': cached['role'],
      }, fromCache: true));
    } else {
      emit(ProfileLoading());
    }

    // 2) هات البيانات الحقيقية من السيرفر
    try {
      final u = await repo.fetchProfile();

      final username = (u['username'] ?? '').toString();
      final role = (u['role'] ?? '').toString();

      // خزّن الكاش (اختياري)
      if (username.isNotEmpty && role.isNotEmpty) {
        await storage.saveProfileCache(username: username, role: role);
      }

      emit(ProfileLoaded(u, fromCache: false));
    } catch (e) {
      // لو عندنا كاش معروض بالفعل لا نخرب الصفحة
      if (state is ProfileLoaded) return;
      emit(ProfileError(e.toString()));
    }
  }

  Future<void> refresh() async {
    try {
      final u = await repo.fetchProfile();

      final username = (u['username'] ?? '').toString();
      final role = (u['role'] ?? '').toString();

      if (username.isNotEmpty && role.isNotEmpty) {
        await storage.saveProfileCache(username: username, role: role);
      }

      emit(ProfileLoaded(u, fromCache: false));
    } catch (e) {
      emit(ProfileError(e.toString()));
    }
  }
}
