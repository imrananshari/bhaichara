import 'package:bhaichara/core/router/app_routes.dart';
import 'package:bhaichara/features/auth/domain/entities/user_entity.dart';

/// Guards routes based on the user's role.
/// Returns a redirect route if the user is not allowed to access the targetRoute,
/// or null if access is allowed.
String? roleGuard(UserRole role, String targetRoute) {
  // If the user is pending approval, they can ONLY access the pending screen.
  // Wait, if they are pending, can they log out? Usually yes, but the main app is blocked.
  if (role == UserRole.pending) {
    if (targetRoute != AppRoutes.pendingApproval) {
      return AppRoutes.pendingApproval;
    }
  }

  // If the user is a regular member or admin, they shouldn't be on the pending screen
  if (role != UserRole.pending && targetRoute == AppRoutes.pendingApproval) {
    return AppRoutes.home;
  }

  // Admin Panel is strictly for Chief and SuperAdmin
  if (targetRoute == AppRoutes.admin) {
    if (role != UserRole.chief && role != UserRole.superAdmin) {
      return AppRoutes.home; // block non-admins
    }
  }

  return null; // allow
}
