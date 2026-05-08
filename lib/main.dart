import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:bhaichara/app.dart';
import 'package:bhaichara/core/constants/supabase_constants.dart';
import 'package:bhaichara/core/services/fcm_service.dart';
import 'package:bhaichara/firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load .env
  try {
    await dotenv.load(fileName: '.env');
    debugPrint('[App] .env loaded');
  } catch (e) {
    debugPrint('[App] .env not found, using defaults: $e');
  }

  // Initialise Firebase (must come before Supabase so FCM background handler
  // is registered as early as possible)
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    debugPrint('[App] Firebase initialised');
  } catch (e) {
    debugPrint('[App] Firebase init error: $e');
  }

  // Initialise Supabase
  try {
    await Supabase.initialize(
      url: SupabaseConstants.supabaseUrl,
      anonKey: SupabaseConstants.supabaseAnonKey,
    );
    debugPrint('[App] Supabase initialised');
  } catch (e) {
    debugPrint('[App] Supabase init error: $e');
  }

  // Initialise FCM (request permission, set up channels, foreground handler)
  try {
    await FcmService.instance.init();
    debugPrint('[App] FCM initialised — token: ${FcmService.instance.fcmToken}');
  } catch (e) {
    debugPrint('[App] FCM init error: $e');
  }

  runApp(
    const ProviderScope(
      child: BhaiCharaApp(),
    ),
  );
}
