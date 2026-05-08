import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bhaichara/core/theme/app_colors.dart';
import 'package:bhaichara/features/auth/presentation/providers/auth_provider.dart';

class HomeFeedScreen extends ConsumerWidget {
  const HomeFeedScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(authStateProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            backgroundColor: AppColors.background,
            pinned: true,
            automaticallyImplyLeading: false,
            title: const Text(
              'Bhai Chara',
              style: TextStyle(
                color: AppColors.primary,
                fontWeight: FontWeight.bold,
                fontSize: 24,
              ),
            ),
            actions: [
              // Notification bell
              IconButton(
                icon: const Icon(Icons.notifications_outlined, color: AppColors.textSecondary),
                onPressed: () {},
              ),
            ],
          ),

          // Stories row
          SliverToBoxAdapter(
            child: SizedBox(
              height: 100,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                itemCount: 10,
                itemBuilder: (context, index) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    child: Column(
                      children: [
                        Container(
                          width: 60,
                          height: 60,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: AppColors.primary, width: 2.5),
                            gradient: index == 0
                                ? const LinearGradient(
                                    colors: [AppColors.primary, AppColors.accent],
                                  )
                                : null,
                          ),
                          child: const Icon(Icons.person, color: AppColors.textSecondary, size: 30),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          index == 0 ? 'Your Story' : 'User $index',
                          style: const TextStyle(color: AppColors.textSecondary, fontSize: 11),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),

          // Feed posts
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 0, vertical: 6),
                  color: AppColors.surface,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ListTile(
                        leading: const CircleAvatar(
                          backgroundColor: AppColors.primary,
                          child: Icon(Icons.person, color: Colors.white),
                        ),
                        title: Text(
                          userAsync.value?.fullName ?? 'Bhai',
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        subtitle: const Text('2 hours ago', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                        trailing: const Icon(Icons.more_horiz, color: AppColors.textSecondary),
                      ),
                      Container(
                        height: 300,
                        width: double.infinity,
                        color: const Color(0xFF1A1025),
                        child: const Center(
                          child: Icon(Icons.image_outlined, size: 60, color: AppColors.textSecondary),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        child: Row(
                          children: [
                            const Icon(Icons.favorite_border, color: AppColors.textPrimary),
                            const SizedBox(width: 6),
                            const Text('24', style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                            const SizedBox(width: 16),
                            const Icon(Icons.comment_outlined, color: AppColors.textPrimary),
                            const SizedBox(width: 6),
                            const Text('8', style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                            const Spacer(),
                            const Icon(Icons.send_outlined, color: AppColors.textPrimary),
                          ],
                        ),
                      ),
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                        child: Text(
                          'This is a caption for the post! 🔥',
                          style: TextStyle(color: AppColors.textPrimary),
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                  ),
                );
              },
              childCount: 5,
            ),
          ),
        ],
      ),
    );
  }
}
