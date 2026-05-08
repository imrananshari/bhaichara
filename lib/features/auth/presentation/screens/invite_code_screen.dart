import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:bhaichara/core/router/app_routes.dart';
import 'package:bhaichara/features/auth/presentation/providers/auth_provider.dart';
import 'package:bhaichara/core/theme/app_colors.dart';

class InviteCodeScreen extends ConsumerStatefulWidget {
  const InviteCodeScreen({super.key});

  @override
  ConsumerState<InviteCodeScreen> createState() => _InviteCodeScreenState();
}

class _InviteCodeScreenState extends ConsumerState<InviteCodeScreen> {
  final _codeController = TextEditingController();

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  void _validateCode() async {
    final code = _codeController.text.trim();
    if (code.isEmpty) return;

    final isValid = await ref.read(inviteCodeValidationProvider.notifier).validateCode(code);

    if (!mounted) return;

    if (isValid) {
      // Proceed to Signup
      context.push(AppRoutes.signup); // Note: signup route isn't built yet
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invite code accepted!')),
      );
    } else {
      // Show error
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invalid or expired invite code.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final validationState = ref.watch(inviteCodeValidationProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Enter Invite Code'),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(),
              const Icon(Icons.lock_person, size: 80, color: AppColors.primary),
              const SizedBox(height: 24),
              const Text(
                'This app is private.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                'Enter the 6-digit invite code you received from a member.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 48),
              TextField(
                controller: _codeController,
                decoration: const InputDecoration(
                  labelText: 'Invite Code',
                  hintText: 'XXXX-XXXX-XXXX',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.key),
                ),
                textCapitalization: TextCapitalization.characters,
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: validationState.isLoading ? null : _validateCode,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: validationState.isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Continue'),
              ),
              const Spacer(),
              const Text(
                'Don\'t have an invite code? Ask a member to invite you.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
