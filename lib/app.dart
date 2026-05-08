import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bhaichara/core/theme/app_theme.dart';
import 'package:bhaichara/core/router/app_router.dart';
import 'package:bhaichara/features/auth/presentation/providers/auth_provider.dart';
import 'package:bhaichara/core/services/encryption_service.dart';
import 'package:bhaichara/core/services/fcm_service.dart';
import 'package:bhaichara/core/network/supabase_client.dart';
import 'package:bhaichara/features/messaging/presentation/providers/messaging_provider.dart';

class BhaiCharaApp extends ConsumerWidget {
  const BhaiCharaApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);

    ref.listen(authStateProvider, (previous, next) {
      final user = next.asData?.value;
      final wasLoggedOut = previous?.asData?.value == null;

      if (user != null) {
        // Init E2EE
        ref.read(encryptionServiceProvider).initialize();

        // Save FCM token to profiles table (and keep it updated on refresh)
        final supabase = ref.read(supabaseClientProvider);
        FcmService.instance.registerTokenWithProfile((token) async {
          await supabase
              .from('profiles')
              .update({'fcm_token': token})
              .eq('id', user.id);
        });

        // Retry any messages that failed to sync while offline
        if (wasLoggedOut) {
          Future.microtask(
            () => ref.read(messagingActionsProvider).retryOfflineQueue(),
          );
        }
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
