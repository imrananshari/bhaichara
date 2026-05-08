import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bhaichara/core/theme/app_colors.dart';
import 'package:bhaichara/features/auth/domain/entities/user_entity.dart';
import 'package:bhaichara/features/auth/presentation/providers/auth_provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:go_router/go_router.dart';
import 'package:bhaichara/features/profile/presentation/providers/follow_provider.dart';
import 'package:bhaichara/core/router/app_routes.dart';
import 'package:bhaichara/core/network/supabase_client.dart';
import 'package:bhaichara/features/profile/domain/entities/follow_entity.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  final String? userId;
  const ProfileScreen({super.key, this.userId});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _usernameController;
  bool _isEditing = false;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _usernameController = TextEditingController();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _usernameController.dispose();
    super.dispose();
  }

  void _startEditing(UserEntity user) {
    _nameController.text = user.fullName ?? '';
    _usernameController.text = user.username ?? '';
    setState(() => _isEditing = true);
  }

  Future<void> _saveProfile(UserEntity user) async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);
    try {
      final supabase = ref.read(authRepositoryProvider);
      await supabase.updateProfile(
        userId: user.id,
        fullName: _nameController.text.trim(),
        username: _usernameController.text.trim(),
      );
      if (mounted) {
        setState(() { _isEditing = false; _isSaving = false; });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile updated!'),
            backgroundColor: AppColors.primary,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  String _roleLabel(UserRole role) {
    switch (role) {
      case UserRole.chief: return 'Chief';
      case UserRole.superAdmin: return 'Super Admin';
      case UserRole.member: return 'Member';
      case UserRole.pending: return 'Pending Approval';
    }
  }

  Color _roleColor(UserRole role) {
    switch (role) {
      case UserRole.chief: return const Color(0xFFFFD700);
      case UserRole.superAdmin: return AppColors.accent;
      case UserRole.member: return Colors.green;
      case UserRole.pending: return AppColors.textSecondary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId = ref.watch(supabaseClientProvider).auth.currentUser?.id;
    final targetUserId = widget.userId ?? currentUserId;
    if (targetUserId == null) return const Scaffold(body: Center(child: Text('User not found')));
    final isMe = targetUserId == currentUserId;

    final userAsync = isMe 
      ? ref.watch(authStateProvider)
      : ref.watch(otherUserProfileProvider(targetUserId));

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: !isMe ? AppBar(backgroundColor: Colors.transparent, elevation: 0) : null,
      body: userAsync.when(
        loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
        error: (e, _) => Center(child: Text('Error: $e', style: const TextStyle(color: Colors.red))),
        data: (user) {
          if (user == null) return const SizedBox();
          return CustomScrollView(
            slivers: [
              // Header with avatar
              SliverAppBar(
                expandedHeight: 240,
                backgroundColor: AppColors.surface,
                pinned: true,
                automaticallyImplyLeading: false,
                actions: [
                  if (isMe) ...[
                    if (!_isEditing)
                      IconButton(
                        icon: const Icon(Icons.edit, color: AppColors.accent),
                        onPressed: () => _startEditing(user),
                      )
                    else
                      TextButton(
                        onPressed: () => setState(() => _isEditing = false),
                        child: const Text('Cancel', style: TextStyle(color: AppColors.textSecondary)),
                      ),
                  ],
                ],
                flexibleSpace: FlexibleSpaceBar(
                  background: Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Color(0xFF2A1050), AppColors.surface],
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const SizedBox(height: 40),
                        Stack(
                          alignment: Alignment.center,
                          children: [
                            Container(
                              width: 96,
                              height: 96,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(color: AppColors.primary, width: 3),
                                gradient: const LinearGradient(
                                  colors: [AppColors.primary, AppColors.accent],
                                ),
                              ),
                              child: ClipOval(
                                child: user.avatarUrl != null
                                    ? CachedNetworkImage(
                                        imageUrl: user.avatarUrl!,
                                        fit: BoxFit.cover,
                                        placeholder: (context, state) => const CircularProgressIndicator(),
                                        errorWidget: (e, st, stack) => _avatarFallback(user),
                                      )
                                    : _avatarFallback(user),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          user.fullName ?? 'No Name',
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                          decoration: BoxDecoration(
                            color: _roleColor(user.role).withOpacity(0.15),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: _roleColor(user.role).withOpacity(0.5)),
                          ),
                          child: Text(
                            _roleLabel(user.role),
                            style: TextStyle(
                              color: _roleColor(user.role),
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // Profile form / info
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 8),
                        _sectionTitle('Account Info'),
                        const SizedBox(height: 16),

                        // Full Name
                        _ProfileField(
                          label: 'Full Name',
                          icon: Icons.person_outline,
                          controller: _nameController,
                          staticValue: user.fullName,
                          isEditing: _isEditing,
                          validator: (v) => (v == null || v.trim().isEmpty) ? 'Name is required' : null,
                        ),
                        const SizedBox(height: 14),

                        // Username
                        _ProfileField(
                          label: 'Username',
                          icon: Icons.alternate_email,
                          controller: _usernameController,
                          staticValue: user.username != null ? '@${user.username}' : 'Not set',
                          isEditing: _isEditing,
                          prefix: _isEditing ? '@' : null,
                        ),
                        const SizedBox(height: 14),

                        // Email (read-only always)
                        _ReadOnlyField(
                          label: 'Email',
                          icon: Icons.email_outlined,
                          value: user.email ?? 'Not available',
                        ),
                        const SizedBox(height: 14),

                        // Role (read-only)
                        _ReadOnlyField(
                          label: 'Role',
                          icon: Icons.shield_outlined,
                          value: _roleLabel(user.role),
                          valueColor: _roleColor(user.role),
                        ),

                        if (!isMe) ...[
                          const SizedBox(height: 28),
                          _FollowButton(userId: user.id),
                        ],

                        if (isMe && _isEditing) ...[
                          const SizedBox(height: 28),
                          SizedBox(
                            width: double.infinity,
                            height: 52,
                            child: ElevatedButton(
                              onPressed: _isSaving ? null : () => _saveProfile(user),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                              child: _isSaving
                                  ? const SizedBox(
                                      width: 20, height: 20,
                                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                                    )
                                  : const Text('Save Changes', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                            ),
                          ),
                        ],

                        if (isMe) ...[
                          const SizedBox(height: 40),
                          const Divider(color: AppColors.surface),
                          const SizedBox(height: 16),

                          // Logout
                          SizedBox(
                            width: double.infinity,
                            height: 52,
                            child: OutlinedButton.icon(
                              onPressed: () => ref.read(authActionsProvider).signOut(),
                              icon: const Icon(Icons.logout, color: Colors.redAccent),
                              label: const Text('Log Out', style: TextStyle(color: Colors.redAccent, fontSize: 16)),
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(color: Colors.redAccent),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                              ),
                            ),
                          ),
                        ],
                        const SizedBox(height: 40),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _avatarFallback(UserEntity user) {
    final letter = (user.fullName?.isNotEmpty == true) ? user.fullName![0].toUpperCase() : '?';
    return Center(
      child: Text(letter, style: const TextStyle(color: Colors.white, fontSize: 36, fontWeight: FontWeight.bold)),
    );
  }

  Widget _sectionTitle(String title) => Text(
    title,
    style: const TextStyle(color: AppColors.textSecondary, fontSize: 13, fontWeight: FontWeight.w600, letterSpacing: 1.2),
  );
}

class _ProfileField extends StatelessWidget {
  const _ProfileField({
    required this.label,
    required this.icon,
    required this.controller,
    required this.staticValue,
    required this.isEditing,
    this.validator,
    this.prefix,
  });

  final String label;
  final IconData icon;
  final TextEditingController controller;
  final String? staticValue;
  final bool isEditing;
  final String? Function(String?)? validator;
  final String? prefix;

  @override
  Widget build(BuildContext context) {
    if (!isEditing) {
      return _ReadOnlyField(label: label, icon: icon, value: staticValue ?? 'Not set');
    }
    return TextFormField(
      controller: controller,
      style: const TextStyle(color: AppColors.textPrimary),
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: AppColors.textSecondary),
        prefixIcon: Icon(icon, color: AppColors.textSecondary, size: 20),
        prefixText: prefix,
        prefixStyle: const TextStyle(color: AppColors.accent),
        filled: true,
        fillColor: AppColors.surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.primary),
        ),
      ),
    );
  }
}

class _ReadOnlyField extends StatelessWidget {
  const _ReadOnlyField({required this.label, required this.icon, required this.value, this.valueColor});
  final String label;
  final IconData icon;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(icon, color: AppColors.textSecondary, size: 20),
          const SizedBox(width: 14),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
              const SizedBox(height: 2),
              Text(value, style: TextStyle(color: valueColor ?? AppColors.textPrimary, fontSize: 15, fontWeight: FontWeight.w500)),
            ],
          ),
        ],
      ),
    );
  }
}

class _FollowButton extends ConsumerStatefulWidget {
  final String userId;
  const _FollowButton({required this.userId});

  @override
  ConsumerState<_FollowButton> createState() => _FollowButtonState();
}

class _FollowButtonState extends ConsumerState<_FollowButton> {
  bool _isProcessing = false;

  @override
  Widget build(BuildContext context) {
    final status = ref.watch(followStatusProvider(widget.userId));

    return status.when(
      data: (followStatus) {
        return AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          child: _buildButtonContent(followStatus),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, st) => const Text('Error loading status'),
    );
  }

  Widget _buildButtonContent(FollowStatus? followStatus) {
    if (_isProcessing) {
      return const Center(
        key: ValueKey('processing'),
        child: SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }

    if (followStatus == null) {
      return SizedBox(
        key: const ValueKey('follow'),
        width: double.infinity,
        height: 52,
        child: ElevatedButton(
          onPressed: () async {
            setState(() => _isProcessing = true);
            try {
              await ref.read(followActionsProvider).followUser(widget.userId);
              ref.invalidate(followStatusProvider(widget.userId));
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Follow request sent!'), backgroundColor: AppColors.primary),
                );
              }
            } finally {
              if (mounted) setState(() => _isProcessing = false);
            }
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
          child: const Text('Send Follow Request', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
        ),
      );
    }

    if (followStatus == FollowStatus.accepted) {
      return Row(
        key: const ValueKey('accepted'),
        children: [
          Expanded(
            child: Container(
              height: 52,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.1),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.green),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.check, color: Colors.green, size: 20),
                  SizedBox(width: 8),
                  Text('Following', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: ElevatedButton.icon(
              onPressed: () {
                context.push(AppRoutes.individualChat.replaceAll(':id', widget.userId));
              },
              icon: const Icon(Icons.chat),
              label: const Text('Message'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                minimumSize: const Size(0, 52),
              ),
            ),
          ),
        ],
      );
    }

    return Row(
      key: const ValueKey('pending'),
      children: [
        Expanded(
          flex: 2,
          child: Container(
            height: 52,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Colors.orange.withOpacity(0.1),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.orange.withOpacity(0.5)),
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.timer_outlined, color: Colors.orange, size: 18),
                SizedBox(width: 8),
                Text('Pending', style: TextStyle(color: Colors.orange, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          flex: 1,
          child: OutlinedButton(
            onPressed: () async {
              setState(() => _isProcessing = true);
              try {
                await ref.read(followActionsProvider).cancelRequest(widget.userId);
                // Status will update automatically via stream
              } finally {
                if (mounted) setState(() => _isProcessing = false);
              }
            },
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: Colors.redAccent),
              foregroundColor: Colors.redAccent,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              minimumSize: const Size(0, 52),
            ),
            child: const Text('Cancel', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ),
      ],
    );
  }
}
