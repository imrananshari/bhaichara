import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:bhaichara/core/router/app_routes.dart';
import 'package:bhaichara/core/theme/app_colors.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:typed_data';
import 'package:bhaichara/core/services/image_upload_service.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bhaichara/features/auth/domain/entities/user_entity.dart';
import 'package:bhaichara/features/auth/presentation/providers/auth_provider.dart';

class ProfileSetupScreen extends ConsumerStatefulWidget {
  const ProfileSetupScreen({super.key});

  @override
  ConsumerState<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends ConsumerState<ProfileSetupScreen> {
  final _fullNameController = TextEditingController();
  final _usernameController = TextEditingController();
  final _bioController = TextEditingController();
  String? _avatarUrl;
  Uint8List? _pickedImageBytes;

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery, imageQuality: 70);
    if (pickedFile != null) {
      final bytes = await pickedFile.readAsBytes();
      setState(() {
        _pickedImageBytes = bytes;
      });
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final user = await ref.read(authActionsProvider).getCurrentUser();
      if (user != null && mounted) {
        setState(() {
          _fullNameController.text = user.fullName ?? '';
          _usernameController.text = user.username ?? '';
          _avatarUrl = user.avatarUrl;
        });
      }
    });
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _usernameController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  bool _isLoading = false;

  void _finishSetup() async {
    setState(() => _isLoading = true);
    try {
      final signupData = ref.read(signupDataProvider);
      final inviteCode = signupData['invite_code'] ?? '';
      
      final currentUser = await ref.read(authActionsProvider).getCurrentUser();
      
      if (currentUser != null) {
        String? finalAvatarUrl = _avatarUrl;
        
        // Upload image if a new one was picked
        if (_pickedImageBytes != null) {
          final fileName = 'profile_${currentUser.id}_${DateTime.now().millisecondsSinceEpoch}.jpg';
          try {
            final uploadedUrl = await ImageUploadService.uploadProfileImageWeb(
              _pickedImageBytes!,
              fileName,
            );
            
            if (uploadedUrl != null) {
              finalAvatarUrl = uploadedUrl;
            }
          } catch (e) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Failed to upload image: $e')),
              );
            }
          }
        }

        final usernameToSave = _usernameController.text.trim().isEmpty 
           ? "" 
           : _usernameController.text.trim();
           
        await ref.read(authActionsProvider).updateProfile(
          userId: currentUser.id,
          fullName: _fullNameController.text.trim(),
          username: usernameToSave,
          avatarUrl: finalAvatarUrl,
        );
        
        if (inviteCode.isNotEmpty) {
          await ref.read(authActionsProvider).consumeInviteCode(inviteCode, currentUser.id);
        }
      }
      
      if (mounted) {
        if (currentUser?.role == UserRole.pending) {
          context.go(AppRoutes.pendingApproval);
        } else {
          context.go(AppRoutes.home);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to complete setup: ${e.toString()}')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 40.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Complete Your Profile',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              const Text(
                'Add a photo and some details so your circle knows it\'s you.',
                style: TextStyle(
                  fontSize: 14,
                  color: AppColors.textSecondary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 40),
              Center(
                child: GestureDetector(
                  onTap: _pickImage,
                  child: Stack(
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: AppColors.primary, width: 3),
                        ),
                        child: CircleAvatar(
                          radius: 65,
                          backgroundColor: AppColors.surface,
                          backgroundImage: _pickedImageBytes != null
                              ? MemoryImage(_pickedImageBytes!) as ImageProvider
                              : (_avatarUrl != null ? CachedNetworkImageProvider(_avatarUrl!) : null),
                          child: (_pickedImageBytes == null && _avatarUrl == null)
                              ? const Icon(Icons.person, size: 65, color: AppColors.textSecondary)
                              : null,
                        ),
                      ),
                      Positioned(
                        bottom: 0,
                        right: 4,
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            shape: BoxShape.circle,
                            border: Border.all(color: AppColors.background, width: 2),
                          ),
                          child: const Icon(Icons.camera_alt, color: Colors.black, size: 20),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 40),
              _buildTextField(
                controller: _fullNameController,
                label: 'Full Name',
                hint: 'John Doe',
                icon: Icons.badge_outlined,
              ),
              const SizedBox(height: 20),
              _buildTextField(
                controller: _usernameController,
                label: 'Username',
                hint: '@username',
                icon: Icons.alternate_email,
              ),
              const SizedBox(height: 20),
              _buildTextField(
                controller: _bioController,
                label: 'Bio (optional)',
                hint: 'Tell your circle about yourself...',
                icon: Icons.info_outline,
                maxLines: 3,
              ),
              const SizedBox(height: 40),
              _isLoading 
                ? const Center(child: CircularProgressIndicator())
                : ElevatedButton(
                    onPressed: _finishSetup,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.black,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                    child: const Text('Complete Profile', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    int maxLines = 1,
  }) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        filled: true,
        fillColor: AppColors.surface,
        prefixIcon: maxLines == 1 ? Icon(icon, color: AppColors.textSecondary) : null,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.primary, width: 1),
        ),
      ),
    );
  }
}
