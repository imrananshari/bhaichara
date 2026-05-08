import 'dart:convert';
import 'package:cryptography/cryptography.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:bhaichara/core/network/supabase_client.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final encryptionServiceProvider = Provider((ref) {
  final supabase = ref.watch(supabaseClientProvider);
  return EncryptionService(supabase);
});

class EncryptionService {
  final SupabaseClient _supabase;
  final _storage = const FlutterSecureStorage();
  final _algorithm = X25519();
  final _cipher = AesGcm.with256bits();

  EncryptionService(this._supabase);

  String _getPrivateKeyKey(String userId) => 'e2ee_private_key_$userId';
  String _getPublicKeyKey(String userId) => 'e2ee_public_key_$userId';

  /// Initializes the E2EE setup for the current user
  Future<void> initialize() async {
    final myId = _supabase.auth.currentUser?.id;
    if (myId == null) return;

    final privateKeyKey = _getPrivateKeyKey(myId);
    final publicKeyKey = _getPublicKeyKey(myId);

    // Check if we already have a private key
    String? privateKeyString = await _storage.read(key: privateKeyKey);

    if (privateKeyString == null) {
      // Generate new key pair
      final keyPair = await _algorithm.newKeyPair();
      final privateKey = await keyPair.extractPrivateKeyBytes();
      final publicKey = await keyPair.extractPublicKey();

      // Store keys locally
      await _storage.write(
        key: privateKeyKey,
        value: base64Encode(privateKey),
      );
      await _storage.write(
        key: publicKeyKey,
        value: base64Encode(publicKey.bytes),
      );

      // Upload public key to Supabase
      await _supabase.from('user_public_keys').upsert({
        'user_id': myId,
        'public_key': base64Encode(publicKey.bytes),
      });
    }
  }

  /// Encrypts a message for a specific recipient
  Future<Map<String, String>> encryptMessage({
    required String recipientId,
    required String plaintext,
  }) async {
    final myId = _supabase.auth.currentUser?.id;
    if (myId == null) throw Exception('User not logged in');

    // 1. Get my keys
    final privateKeyStr = await _storage.read(key: _getPrivateKeyKey(myId));
    final publicKeyStr = await _storage.read(key: _getPublicKeyKey(myId));
    
    if (privateKeyStr == null || publicKeyStr == null) {
      // Try to initialize if missing
      await initialize();
      return encryptMessage(recipientId: recipientId, plaintext: plaintext);
    }
    
    final myKeyPair = SimpleKeyPairData(
      base64Decode(privateKeyStr),
      publicKey: SimplePublicKey(base64Decode(publicKeyStr), type: KeyPairType.x25519),
      type: KeyPairType.x25519,
    );

    // 2. Get recipient's public key from Supabase
    final response = await _supabase
        .from('user_public_keys')
        .select('public_key')
        .eq('user_id', recipientId)
        .single();
    
    final recipientPublicKeyStr = response['public_key'] as String;
    final recipientPublicKey = SimplePublicKey(
      base64Decode(recipientPublicKeyStr),
      type: KeyPairType.x25519,
    );

    // 3. Generate Shared Secret (ECDH)
    final sharedSecret = await _algorithm.sharedSecretKey(
      keyPair: myKeyPair,
      remotePublicKey: recipientPublicKey,
    );

    // 4. Encrypt with AES-GCM
    final secretBox = await _cipher.encrypt(
      utf8.encode(plaintext),
      secretKey: sharedSecret,
    );

    return {
      'ciphertext': base64Encode(secretBox.concatenation()),
      'iv': base64Encode(secretBox.nonce),
    };
  }

  /// Decrypts a message using a specific other party's public key
  Future<String> decryptMessage({
    required String otherPartyId,
    required String ciphertext,
    required String iv,
  }) async {
    try {
      final myId = _supabase.auth.currentUser?.id;
      if (myId == null) throw Exception('User not logged in');

      // 1. Get my keys
      final privateKeyStr = await _storage.read(key: _getPrivateKeyKey(myId));
      final publicKeyStr = await _storage.read(key: _getPublicKeyKey(myId));
      if (privateKeyStr == null || publicKeyStr == null) throw Exception('E2EE not initialized locally');
      
      final myKeyPair = SimpleKeyPairData(
        base64Decode(privateKeyStr),
        publicKey: SimplePublicKey(base64Decode(publicKeyStr), type: KeyPairType.x25519),
        type: KeyPairType.x25519,
      );

      // 2. Get other party's public key from Supabase
      final response = await _supabase
          .from('user_public_keys')
          .select('public_key')
          .eq('user_id', otherPartyId)
          .single();
      
      final otherPublicKeyStr = response['public_key'] as String;
      final otherPublicKey = SimplePublicKey(
        base64Decode(otherPublicKeyStr),
        type: KeyPairType.x25519,
      );

      // 3. Generate Shared Secret (ECDH)
      final sharedSecret = await _algorithm.sharedSecretKey(
        keyPair: myKeyPair,
        remotePublicKey: otherPublicKey,
      );

      // 4. Decrypt
      final secretBox = SecretBox.fromConcatenation(
        base64Decode(ciphertext),
        nonceLength: 12,
        macLength: 16,
      );

      final clearText = await _cipher.decrypt(
        secretBox,
        secretKey: sharedSecret,
      );

      return utf8.decode(clearText);
    } catch (e) {
      return '[Decryption Error]';
    }
  }
}
