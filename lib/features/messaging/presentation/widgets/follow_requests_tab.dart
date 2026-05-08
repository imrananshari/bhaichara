import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bhaichara/core/theme/app_colors.dart';
import 'package:bhaichara/features/profile/presentation/providers/follow_provider.dart';
import 'package:bhaichara/features/profile/domain/entities/follow_entity.dart';
import 'package:bhaichara/features/auth/domain/entities/user_entity.dart';

class FollowRequestsTab extends ConsumerWidget {
  const FollowRequestsTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final requestsAsync = ref.watch(pendingFollowRequestsProvider);

    return RefreshIndicator(
      onRefresh: () async => ref.invalidate(pendingFollowRequestsProvider),
      child: requestsAsync.when(
        data: (requests) {
          return AnimatedSwitcher(
            duration: const Duration(milliseconds: 500),
            child: requests.isEmpty
                ? _buildEmptyState()
                : ListView.builder(
                    key: const ValueKey('requests_list'),
                    padding: const EdgeInsets.all(16),
                    itemCount: requests.length,
                    itemBuilder: (context, index) {
                      return _RequestCard(request: requests[index]);
                    },
                  ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => Center(child: Text('Error: $e')),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      key: const ValueKey('empty_state'),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: 1),
            duration: const Duration(seconds: 1),
            builder: (context, value, child) {
              return Transform.scale(
                scale: value,
                child: Opacity(opacity: value, child: child),
              );
            },
            child: const Icon(Icons.person_add_outlined, size: 80, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 24),
          const Text(
            'No pending requests',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 18, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 8),
          const Text(
            'When someone follows you, they\'ll appear here.',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
          ),
        ],
      ),
    );
  }
}

class _RequestCard extends ConsumerStatefulWidget {
  final FollowEntity request;
  const _RequestCard({required this.request});

  @override
  ConsumerState<_RequestCard> createState() => _RequestCardState();
}

class _RequestCardState extends ConsumerState<_RequestCard> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 300));
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.95).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final userAsync = ref.watch(otherUserProfileProvider(widget.request.followerId));

    return userAsync.when(
      data: (user) {
        if (user == null) return const SizedBox();

        return ScaleTransition(
          scale: _scaleAnimation,
          child: Card(
            elevation: 0,
            margin: const EdgeInsets.only(bottom: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: AppColors.primary.withOpacity(0.1)),
            ),
            color: AppColors.surface,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 28,
                    backgroundImage: user.avatarUrl != null ? NetworkImage(user.avatarUrl!) : null,
                    child: user.avatarUrl == null ? Text(user.fullName?[0] ?? '?', style: const TextStyle(fontSize: 20)) : null,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(user.fullName ?? 'Unknown', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.textPrimary)),
                        Text('@${user.username ?? 'user'}', style: const TextStyle(color: AppColors.textSecondary, fontSize: 14)),
                      ],
                    ),
                  ),
                  _buildActions(),
                ],
              ),
            ),
          ),
        );
      },
      loading: () => _buildShimmer(),
      error: (e, st) => const SizedBox(),
    );
  }

  Widget _buildActions() {
    if (_isProcessing) {
      return const SizedBox(width: 40, height: 40, child: CircularProgressIndicator(strokeWidth: 2));
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _ActionButton(
          icon: Icons.check,
          color: Colors.green,
          onPressed: () async {
            setState(() => _isProcessing = true);
            await _controller.forward();
            await ref.read(followActionsProvider).acceptRequest(widget.request.id);
            ref.invalidate(pendingFollowRequestsProvider);
            ref.invalidate(acceptedFriendsProvider);
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Follow request from ${widget.request.followerId} accepted!'), backgroundColor: Colors.green),
              );
            }
          },
        ),
        const SizedBox(width: 8),
        _ActionButton(
          icon: Icons.close,
          color: Colors.red,
          onPressed: () async {
            setState(() => _isProcessing = true);
            await _controller.forward();
            await ref.read(followActionsProvider).rejectRequest(widget.request.id);
            ref.invalidate(pendingFollowRequestsProvider);
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Request declined'), backgroundColor: Colors.redAccent),
              );
            }
          },
        ),
      ],
    );
  }

  Widget _buildShimmer() {
    return Container(
      height: 80,
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.surface.withOpacity(0.5),
        borderRadius: BorderRadius.circular(16),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onPressed;

  const _ActionButton({required this.icon, required this.color, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        shape: BoxShape.circle,
      ),
      child: IconButton(
        icon: Icon(icon, color: color, size: 20),
        onPressed: onPressed,
        constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
        padding: EdgeInsets.zero,
      ),
    );
  }
}
