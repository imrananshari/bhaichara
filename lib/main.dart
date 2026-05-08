import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:bhaichara/app.dart';
import 'package:bhaichara/core/constants/supabase_constants.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    // Load environment variables from .env file
    // On web, if this fails, we catch it
    await dotenv.load(fileName: ".env");
    debugPrint("Environment variables loaded successfully");
  } catch (e) {
    debugPrint("Error loading .env file: $e. Using environment defaults.");
  }

  try {
    // Initialize Supabase Client
    await Supabase.initialize(
      url: SupabaseConstants.supabaseUrl,
      anonKey: SupabaseConstants.supabaseAnonKey,
    );
    debugPrint("Supabase initialized successfully");
  } catch (e) {
    debugPrint("Supabase initialization error: $e");
  }

  runApp(
    const ProviderScope(
      child: BhaiCharaApp(),
    ),
  );
}
