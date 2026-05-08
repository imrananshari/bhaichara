import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bhaichara/core/theme/app_theme.dart';
import 'package:bhaichara/core/router/app_router.dart';
import 'package:bhaichara/features/auth/presentation/providers/auth_provider.dart';
import 'package:bhaichara/core/services/encryption_service.dart';

class BhaiCharaApp extends ConsumerWidget {
  const BhaiCharaApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    
    // Listen for auth changes to initialize E2EE
    ref.listen(authStateProvider, (previous, next) {
      if (next.hasValue && next.value != null) {
        ref.read(encryptionServiceProvider).initialize();
      }
    });

    return MaterialApp.router(
      title: 'Bhaichara',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      routerConfig: router,
    );
  }
}
