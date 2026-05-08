import 'package:flutter_dotenv/flutter_dotenv.dart';

class SupabaseConstants {
  /// Core Supabase configuration loaded from .env
  static String get supabaseUrl => dotenv.env['SUPABASE_URL'] ?? '';
  static String get supabaseAnonKey => dotenv.env['SUPABASE_ANON_KEY'] ?? '';

  // Table Names
  static const String profilesTable = 'profiles';
  static const String invitesTable = 'invites';
  static const String postsTable = 'posts';
  static const String commentsTable = 'comments';
  static const String messagesTable = 'messages';
  static const String liveSessionsTable = 'live_sessions';
  static const String circlesTable = 'circles';
  static const String followsTable = 'follows';

  // Bucket Names
  // If using ImageKit, this might not be needed for images, but keeping for reference
  static const String avatarsBucket = 'avatars';

  // ImageKit Configuration
  static String get imageKitUrlEndpoint => dotenv.env['IMAGEKIT_URL_ENDPOINT'] ?? '';
  static String get imageKitPublicKey => dotenv.env['IMAGEKIT_PUBLIC_KEY'] ?? '';
  static String get imageKitPrivateKey => dotenv.env['IMAGEKIT_PRIVATE_KEY'] ?? '';
  
  static String get googleClientId => dotenv.env['GOOGLE_CLIENT_ID'] ?? '';
}
