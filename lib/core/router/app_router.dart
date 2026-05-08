import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:bhaichara/core/router/app_routes.dart';
import 'package:bhaichara/core/theme/app_colors.dart';
import 'package:bhaichara/features/auth/domain/entities/user_entity.dart';
import 'package:bhaichara/features/auth/presentation/providers/auth_provider.dart';
import 'package:bhaichara/features/auth/presentation/screens/splash_screen.dart';
import 'package:bhaichara/features/auth/presentation/screens/welcome_screen.dart';
import 'package:bhaichara/features/auth/presentation/screens/invite_code_screen.dart';
import 'package:bhaichara/features/auth/presentation/screens/signup_screen.dart';
import 'package:bhaichara/features/auth/presentation/screens/otp_screen.dart';
import 'package:bhaichara/features/auth/presentation/screens/profile_setup_screen.dart';
import 'package:bhaichara/features/auth/presentation/screens/pending_approval_screen.dart';
import 'package:bhaichara/features/feed/presentation/screens/home_feed_screen.dart';
import 'package:bhaichara/features/members/presentation/screens/members_screen.dart';
import 'package:bhaichara/features/admin/presentation/screens/admin_panel_screen.dart';
import 'package:bhaichara/features/profile/presentation/screens/profile_screen.dart';
import 'package:bhaichara/features/messaging/presentation/screens/chat_main_screen.dart';
import 'package:bhaichara/features/live/presentation/screens/live_main_screen.dart';
import 'package:bhaichara/features/messaging/presentation/screens/individual_chat_screen.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authStateProvider);

  return GoRouter(
    initialLocation: AppRoutes.splash,
    redirect: (context, state) {
      if (authState.isLoading) return null;

      final user = authState.asData?.value;
      final isAuthPath = state.matchedLocation == AppRoutes.welcome ||
          state.matchedLocation == AppRoutes.inviteCode ||
          state.matchedLocation == AppRoutes.signup ||
          state.matchedLocation == AppRoutes.otp;

      // Not logged in → send to welcome
      if (user == null) {
        return isAuthPath ? null : AppRoutes.welcome;
      }

      // If user hasn't completed profile setup (username is null)
      // Note: If they skip username, it's saved as an empty string (""), not null!
      final hasCompletedSetup = user.username != null;
      if (!hasCompletedSetup) {
        return state.matchedLocation == AppRoutes.profileSetup
            ? null
            : AppRoutes.profileSetup;
      }

      // If still pending approval → go to pending screen
      if (user.role == UserRole.pending) {
        return state.matchedLocation == AppRoutes.pendingApproval
            ? null
            : AppRoutes.pendingApproval;
      }

      // Authenticated + approved → redirect away from auth/pending/splash to home
      if (isAuthPath ||
          state.matchedLocation == AppRoutes.profileSetup ||
          state.matchedLocation == AppRoutes.pendingApproval ||
          state.matchedLocation == AppRoutes.splash) {
        return AppRoutes.home;
      }

      return null;
    },
    routes: [
      // Auth routes (no bottom nav)
      GoRoute(path: AppRoutes.splash, builder: (context, state) => const SplashScreen()),
      GoRoute(path: AppRoutes.welcome, builder: (context, state) => const WelcomeScreen()),
      GoRoute(path: AppRoutes.inviteCode, builder: (context, state) => const InviteCodeScreen()),
      GoRoute(path: AppRoutes.signup, builder: (context, state) => const SignupScreen()),
      GoRoute(path: AppRoutes.otp, builder: (context, state) => const OtpScreen()),
      GoRoute(path: AppRoutes.profileSetup, builder: (context, state) => const ProfileSetupScreen()),
      GoRoute(path: AppRoutes.pendingApproval, builder: (context, state) => const PendingApprovalScreen()),

      // Main shell with bottom nav
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return _MainShell(navigationShell: navigationShell);
        },
        branches: [
          StatefulShellBranch(
            routes: [GoRoute(path: AppRoutes.home, builder: (context, state) => const HomeFeedScreen())],
          ),
          StatefulShellBranch(
            routes: [GoRoute(path: AppRoutes.members, builder: (context, state) => const MembersScreen())],
          ),
          StatefulShellBranch(
            routes: [GoRoute(path: AppRoutes.chat, builder: (context, state) => const ChatMainScreen())],
          ),
          StatefulShellBranch(
            routes: [GoRoute(path: AppRoutes.live, builder: (context, state) => const LiveMainScreen())],
          ),
          StatefulShellBranch(
            routes: [GoRoute(path: AppRoutes.admin, builder: (context, state) => const AdminPanelScreen())],
          ),
          StatefulShellBranch(
            routes: [GoRoute(path: AppRoutes.profile, builder: (context, state) => const ProfileScreen())],
          ),
        ],
      ),
      GoRoute(
        path: AppRoutes.individualChat,
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          return IndividualChatScreen(userId: id);
        },
      ),
      GoRoute(
        path: AppRoutes.userProfile,
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          return ProfileScreen(userId: id);
        },
      ),
    ],
  );
});

class _MainShell extends ConsumerWidget {
  const _MainShell({required this.navigationShell});
  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(authStateProvider);
    final user = userAsync.asData?.value;
    final isAdmin = user?.role == UserRole.chief || user?.role == UserRole.superAdmin;

    // Tab indices: 0=Home, 1=Members, 2=Chat, 3=Live, 4=Admin(admin only), 5=Profile
    final tabs = <_NavTab>[
      const _NavTab(icon: Icons.home_outlined, activeIcon: Icons.home, label: 'Home'),
      const _NavTab(icon: Icons.group_outlined, activeIcon: Icons.group, label: 'Members'),
      const _NavTab(icon: Icons.chat_bubble_outline, activeIcon: Icons.chat_bubble, label: 'Chat'),
      const _NavTab(icon: Icons.live_tv_outlined, activeIcon: Icons.live_tv, label: 'Live'),
      if (isAdmin)
        const _NavTab(icon: Icons.admin_panel_settings_outlined, activeIcon: Icons.admin_panel_settings, label: 'Admin'),
      const _NavTab(icon: Icons.person_outline, activeIcon: Icons.person, label: 'Profile'),
    ];

    // Map shell index to visible tab index
    int currentIndex = navigationShell.currentIndex;
    
    // Safety check for non-admins on admin tab
    if (!isAdmin && currentIndex == 4) currentIndex = 0;

    // Calculate visible index
    int visibleIndex;
    if (isAdmin) {
      visibleIndex = currentIndex;
    } else {
      // Non-admin mapping: 0->0, 1->1, 2->2, 3->3, 5->4
      if (currentIndex == 5) {
        visibleIndex = 4;
      } else {
        visibleIndex = currentIndex;
      }
    }

    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          border: Border(top: BorderSide(color: AppColors.primary.withValues(alpha: 0.2), width: 0.5)),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.1),
              blurRadius: 20,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: List.generate(tabs.length, (index) {
                final tab = tabs[index];
                final isSelected = visibleIndex == index;
                // Map visible tab index back to shell index
                final shellIndex = _visibleToShellIndex(index, isAdmin);
                return _NavItem(
                  tab: tab,
                  isSelected: isSelected,
                  onTap: () => navigationShell.goBranch(shellIndex,
                    initialLocation: shellIndex == navigationShell.currentIndex,
                  ),
                );
              }),
            ),
          ),
        ),
      ),
    );
  }

  int _visibleToShellIndex(int visibleIndex, bool isAdmin) {
    // Shell branches: 0=Home, 1=Members, 2=Chat, 3=Live, 4=Admin, 5=Profile
    if (isAdmin) return visibleIndex;
    // Non-admin visible indices: 0, 1, 2, 3, 4
    // Map to shell indices: 0, 1, 2, 3, 5
    if (visibleIndex == 4) return 5;
    return visibleIndex;
  }
}

class _NavTab {
  const _NavTab({required this.icon, required this.activeIcon, required this.label});
  final IconData icon;
  final IconData activeIcon;
  final String label;
}

class _NavItem extends StatelessWidget {
  const _NavItem({required this.tab, required this.isSelected, required this.onTap});
  final _NavTab tab;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary.withValues(alpha: 0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isSelected ? tab.activeIcon : tab.icon,
              color: isSelected ? AppColors.primary : AppColors.textSecondary,
              size: 24,
            ),
            const SizedBox(height: 4),
            Text(
              tab.label,
              style: TextStyle(
                color: isSelected ? AppColors.primary : AppColors.textSecondary,
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
