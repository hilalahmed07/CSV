import 'package:google_secret_manager/google_secret_manager.dart';
import 'dart:convert';

class SecretsManager {
  static final SecretsManager _instance = SecretsManager._internal();
  late final GoogleSecretManager _secretManager;

  // Cache for secrets
  final Map<String, String> _secretCache = {};

  factory SecretsManager() {
    return _instance;
  }

  SecretsManager._internal();

  /// Get a secret value. First checks cache, then fetches from Google Secret Manager
  Future<String> getSecret(String secretId) async {
    // Check cache first
    if (_secretCache.containsKey(secretId)) {
      return _secretCache[secretId]!;
    }

    // Fetch from Google Secret Manager
    try {
      final response = await GoogleSecretManager.instance.get(secretId);

      if (response?.payload?.data != null) {
        // Cache the secret
        final decodedData = base64Decode(response?.payload?.data ?? '');
        final decodedDataString = String.fromCharCodes(decodedData);

        _secretCache[secretId] = decodedDataString;
        return decodedDataString;
      }
    } catch (e) {
      print('Error fetching secret $secretId: $e');
      rethrow;
    }

    throw Exception('Secret $secretId not found');
  }

  /// Clear all cached secrets
  void clearCache() {
    _secretCache.clear();
  }
}
