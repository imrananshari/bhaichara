import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:bhaichara/core/network/supabase_client.dart';
import 'package:bhaichara/core/router/app_routes.dart';
import 'package:bhaichara/core/services/image_upload_service.dart';
import 'package:bhaichara/core/theme/app_colors.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bhaichara/features/auth/presentation/providers/auth_provider.dart';

class SignupScreen extends ConsumerStatefulWidget {
  const SignupScreen({super.key});

  @override
  ConsumerState<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends ConsumerState<SignupScreen> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  XFile? _profileImage;
  bool _isLoading = false;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 70,
      maxWidth: 500,
    );
    
    if (image != null) {
      setState(() {
        _profileImage = image;
      });
    }
  }

  Future<void> _signUp() async {
    if (_nameController.text.isEmpty || _emailController.text.isEmpty || _passwordController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill all fields')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      String? avatarUrl;

      // 1. Upload image to ImageKit if selected
      if (_profileImage != null) {
        if (kIsWeb) {
          final bytes = await _profileImage!.readAsBytes();
          avatarUrl = await ImageUploadService.uploadProfileImageWeb(bytes, _profileImage!.name);
        } else {
          avatarUrl = await ImageUploadService.uploadProfileImage(File(_profileImage!.path));
        }
      }

      // 2. Call Supabase Auth Signup with avatarUrl
      await ref.read(authActionsProvider).signUpWithEmail(
        _emailController.text.trim(),
        _passwordController.text,
        _nameController.text.trim(),
        avatarUrl: avatarUrl,
      );

      // 3. Save data to provider to use in profile setup
      ref.read(signupDataProvider.notifier).updateData({
        'email': _emailController.text.trim(),
        'password': _passwordController.text,
        'full_name': _nameController.text.trim(),
        'avatar_url': avatarUrl,
      });

      // 4. Check if we are already logged in (Option 1: Confirm Email is OFF)
      final session = ref.read(supabaseClientProvider).auth.currentSession;
      if (session != null) {
        // Already logged in, no OTP needed
        if (mounted) context.go(AppRoutes.home);
      } else {
        // Session is null, means OTP was sent
        if (mounted) context.push(AppRoutes.otp);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _signUpWithGoogle() async {
    setState(() => _isLoading = true);
    try {
      // 1. Sign in with Google
      await ref.read(authActionsProvider).signInWithGoogle();
      
      // 2. Check if we have an invite code in state to consume
      final signupData = ref.read(signupDataProvider);
      final inviteCode = signupData['invite_code'];
      final user = ref.read(supabaseClientProvider).auth.currentUser;
      
      if (inviteCode != null && user != null) {
        await ref.read(authActionsProvider).consumeInviteCode(inviteCode, user.id);
      }

      // 3. Redirection will be handled by AppRouter based on user role
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Google Sign-In failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Account'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Profile Image Picker
              Center(
                child: GestureDetector(
                  onTap: _pickImage,
                  child: Stack(
                    children: [
                      CircleAvatar(
                        radius: 50,
                        backgroundColor: AppColors.surface,
                        backgroundImage: _profileImage != null 
                          ? (kIsWeb ? NetworkImage(_profileImage!.path) : FileImage(File(_profileImage!.path)) as ImageProvider)
                          : null,
                        child: _profileImage == null 
                          ? const Icon(Icons.add_a_photo, size: 40, color: AppColors.primary)
                          : null,
                      ),
                      if (_profileImage != null)
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: const BoxDecoration(
                              color: AppColors.primary,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.edit, size: 20, color: Colors.white),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Upload Profile Photo',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textSecondary),
              ),
              const SizedBox(height: 32),
              const Text(
                'Account Details',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 24),
              TextField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Full Name',
                  hintText: 'Enter full name',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.person),
                ),
                textCapitalization: TextCapitalization.words,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  labelText: 'Email',
                  hintText: 'Enter your email',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.email),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _passwordController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Password',
                  hintText: 'Create a strong password',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.lock),
                ),
              ),
              const SizedBox(height: 32),
              _isLoading 
                ? const Center(child: CircularProgressIndicator())
                : Column(
                    children: [
                      ElevatedButton(
                        onPressed: _signUp,
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          minimumSize: const Size(double.infinity, 50),
                        ),
                        child: const Text('Create Account'),
                      ),
                      const SizedBox(height: 16),
                      const Text('OR', textAlign: TextAlign.center, style: TextStyle(color: AppColors.textSecondary)),
                      const SizedBox(height: 16),
                      OutlinedButton.icon(
                        onPressed: _signUpWithGoogle,
                        icon: const Icon(Icons.email),
                        label: const Text('Continue with Google'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          minimumSize: const Size(double.infinity, 50),
                        ),
                      ),
                    ],
                  ),
            ],
          ),
        ),
      ),
    );
  }
}
