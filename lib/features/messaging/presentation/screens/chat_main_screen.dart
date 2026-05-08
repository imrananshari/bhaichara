import 'package:flutter/material.dart';
import 'package:bhaichara/core/theme/app_colors.dart';
import 'package:bhaichara/features/messaging/presentation/widgets/group_chat_tab.dart';
import 'package:bhaichara/features/messaging/presentation/widgets/friends_list_tab.dart';
import 'package:bhaichara/features/messaging/presentation/widgets/follow_requests_tab.dart';

class ChatMainScreen extends StatelessWidget {
  const ChatMainScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text(
            'Bhaichara Chat',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 22),
          ),
          bottom: const TabBar(
            indicatorColor: AppColors.primary,
            labelColor: AppColors.primary,
            unselectedLabelColor: AppColors.textSecondary,
            tabs: [
              Tab(text: 'GROUP'),
              Tab(text: 'FRIENDS'),
              Tab(text: 'REQUESTS'),
            ],
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.camera_alt_outlined),
              onPressed: () {},
            ),
            IconButton(
              icon: const Icon(Icons.more_vert),
              onPressed: () {},
            ),
          ],
        ),
        body: const TabBarView(
          children: [
            GroupChatTab(),
            FriendsListTab(),
            FollowRequestsTab(),
          ],
        ),
      ),
    );
  }
}
