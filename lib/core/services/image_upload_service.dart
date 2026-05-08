import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:bhaichara/core/constants/supabase_constants.dart';

class ImageUploadService {
  static Future<String?> uploadProfileImage(File imageFile) async {
    try {
      final String urlEndpoint = SupabaseConstants.imageKitUrlEndpoint;
      final String publicKey = SupabaseConstants.imageKitPublicKey;
      final String privateKey = SupabaseConstants.imageKitPrivateKey;

      if (urlEndpoint.isEmpty || publicKey.isEmpty || privateKey.isEmpty) {
        debugPrint("ImageKit configuration is missing in .env");
        return null;
      }

      // Convert image to base64
      final bytes = await imageFile.readAsBytes();
      final base64Image = base64Encode(bytes);

      // Prepare the request
      final uri = Uri.parse('https://upload.imagekit.io/api/v1/files/upload');
      
      // Basic Auth Header: base64(private_key:)
      final String auth = base64Encode(utf8.encode('$privateKey:'));

      final request = http.MultipartRequest('POST', uri)
        ..headers['Authorization'] = 'Basic $auth'
        ..fields['file'] = base64Image
        ..fields['fileName'] = 'profile_${DateTime.now().millisecondsSinceEpoch}.jpg'
        ..fields['useUniqueFileName'] = 'true'
        ..fields['folder'] = '/avatars';

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(response.body);
        return jsonResponse['url'] as String;
      } else {
        final error = 'ImageKit Error (${response.statusCode}): ${response.body}';
        debugPrint(error);
        throw Exception(error);
      }
    } catch (e) {
      debugPrint('Error uploading to ImageKit: $e');
      rethrow;
    }
  }

  /// For Web support (XFile uses bytes instead of File path)
  static Future<String?> uploadProfileImageWeb(Uint8List bytes, String fileName) async {
    try {
      final String urlEndpoint = SupabaseConstants.imageKitUrlEndpoint;
      final String privateKey = SupabaseConstants.imageKitPrivateKey;

      if (urlEndpoint.isEmpty || privateKey.isEmpty) {
        throw Exception("ImageKit endpoint or private key is missing in .env");
      }

      final base64Image = base64Encode(bytes);
      final uri = Uri.parse('https://upload.imagekit.io/api/v1/files/upload');
      final String auth = base64Encode(utf8.encode('$privateKey:'));

      final request = http.MultipartRequest('POST', uri)
        ..headers['Authorization'] = 'Basic $auth'
        ..fields['file'] = base64Image
        ..fields['fileName'] = fileName
        ..fields['useUniqueFileName'] = 'true'
        ..fields['folder'] = '/avatars';

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(response.body);
        return jsonResponse['url'] as String;
      } else {
        final error = 'ImageKit Error (${response.statusCode}): ${response.body}';
        debugPrint(error);
        throw Exception(error);
      }
    } catch (e) {
      debugPrint('Error uploading to ImageKit: $e');
      rethrow;
    }
  }
}
