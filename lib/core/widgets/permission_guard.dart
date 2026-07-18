import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:rental_app/features/profile/profile_cubit.dart';

class PermissionGuard extends StatelessWidget {
  final String permissionKey;
  final Widget child;
  final Widget? fallback;

  const PermissionGuard({
    super.key,
    required this.permissionKey,
    required this.child,
    this.fallback,
  });

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ProfileCubit, ProfileState>(
      builder: (context, state) {
        final hasPermission = () {
          if (state is ProfileLoaded) {
            final role = state.user['role']?.toString();
            if (role == 'admin') return true;

            final perms = state.user['screen_permissions'];
            if (perms is Map) {
              return perms[permissionKey] == true;
            }
          }
          return false;
        }();
        if (hasPermission) return child;
        return fallback ?? const SizedBox.shrink();
      },
    );
  }
}

/// Extension on ProfileState for convenient permission checking.
extension ProfileStateX on ProfileState {
  bool hasScreenPermission(String key) {
    if (this is ProfileLoaded) {
      final role = (this as ProfileLoaded).user['role']?.toString();
      if (role == 'admin') return true;

      final perms = (this as ProfileLoaded).user['screen_permissions'];
      if (perms is Map) {
        return perms[key] == true;
      }
    }
    return false;
  }

  /// Checks action-level permission (`{baseKey}_{action}`).
  /// Falls back to [defaultVal] if the key does not exist in [screen_permissions].
  bool hasActionPermission(String baseKey, String action, {bool defaultVal = true}) {
    if (this is ProfileLoaded) {
      final role = (this as ProfileLoaded).user['role']?.toString();
      if (role == 'admin') return true;

      final perms = (this as ProfileLoaded).user['screen_permissions'];
      if (perms is Map) {
        final val = perms['${baseKey}_$action'];
        if (val != null) return val == true;
      }
      return defaultVal;
    }
    return defaultVal;
  }
}
