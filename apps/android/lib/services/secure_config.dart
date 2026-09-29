import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';

/// Secure configuration service — eliminates hardcoded secrets.
///
/// Secrets are derived at runtime using multi-layer obfuscation:
/// 1. Base key fragments are split across the binary
/// 2. Device-specific salt ensures keys differ per device
/// 3. HMAC chain produces final secrets
///
/// This prevents trivial `strings` extraction from the APK.
class SecureConfig {
  static final SecureConfig _instance = SecureConfig._();
  factory SecureConfig() => _instance;
  SecureConfig._();

  static bool _ready = false;
  static late String _derivedToken;
  static late String _derivedSigningKey;

  // ═══ Obfuscated key fragments ═══
  // These are NOT the actual secrets — they are seeds that get combined
  // with device-specific entropy to produce the real secrets.
  // Splitting them makes `strings <apk>` extraction useless.

  // Token seed fragments (combined at runtime)
  static const List<String> _tokenFragments = [
    'cHBfc2Vj', // base64 fragments
    'dXJlXzIw',
    'MjRfdG9r',
    'ZW4=',
  ];

  // Signing key seed fragments
  static const List<String> _signingFragments = [
    'ZnRfc2ln',
    'bl9zM2Ny',
    'ZXRfMjAy',
    'NF9obWFj',
  ];

  /// Initialize — must be called after Hive is ready
  static Future<void> init() async {
    if (_ready) return;

    // Reconstruct seed from fragments
    final tokenSeed = _reassemble(_tokenFragments);
    final signingSeed = _reassemble(_signingFragments);

    // Get or create device-specific salt
    final salt = await _getDeviceSalt();

    // Derive actual secrets via HMAC chain
    _derivedToken = _deriveKey(tokenSeed, salt, 'token');
    _derivedSigningKey = _deriveKey(signingSeed, salt, 'signing');

    _ready = true;
    if (kDebugMode) {
      debugPrint('[SecureConfig] Initialized with device-specific keys');
    }
  }

  /// Reassemble base64 fragments into the original seed string
  static String _reassemble(List<String> fragments) {
    try {
      final combined = fragments.join();
      return utf8.decode(base64.decode(combined));
    } catch (_) {
      // Fallback for malformed fragments
      return fragments.join();
    }
  }

  /// Get or create a persistent device-specific salt
  static Future<String> _getDeviceSalt() async {
    try {
      final box = await Hive.openBox('_sc');
      String? salt = box.get('ds') as String?;
      if (salt == null || salt.length < 16) {
        final rng = Random.secure();
        salt = List.generate(
          32,
          (_) => rng.nextInt(256),
        ).map((b) => b.toRadixString(16).padLeft(2, '0')).join();
        await box.put('ds', salt);
      }
      return salt;
    } catch (_) {
      return 'fallback_salt_${DateTime.now().year}';
    }
  }

  /// Derive a key using HMAC-SHA256 chain
  static String _deriveKey(String seed, String salt, String context) {
    // Round 1: HMAC(seed, salt)
    final key1 = Hmac(sha256, utf8.encode(seed));
    final round1 = key1.convert(utf8.encode(salt)).toString();

    // Round 2: HMAC(round1, context)
    final key2 = Hmac(sha256, utf8.encode(round1));
    final round2 = key2.convert(utf8.encode(context)).toString();

    // No project-owned server secret is embedded in the client. A self-hosted
    // deployment can replace this device-local key through its own pairing flow.
    return round2;
  }

  // ═══ Public Accessors ═══

  /// API bearer token (server-validated)
  static String get apiToken {
    _ensureReady();
    return _derivedToken;
  }

  /// HMAC signing secret for request integrity
  static String get signingSecret {
    _ensureReady();
    return _derivedSigningKey;
  }

  static void _ensureReady() {
    if (!_ready) {
      // Fallback: use compile-time constants (same as before, but
      // this path should never be hit in normal execution)
      _derivedToken = '';
      _derivedSigningKey = '';
      if (kDebugMode) {
        debugPrint(
          '[SecureConfig] WARNING: Using fallback keys (init not called)',
        );
      }
    }
  }

  // ═══ Input Sanitization ═══

  /// Sanitize user input to prevent injection attacks
  static String sanitizeInput(String input, {int maxLength = 1000}) {
    // Trim whitespace
    var sanitized = input.trim();

    // Enforce length limit
    if (sanitized.length > maxLength) {
      sanitized = sanitized.substring(0, maxLength);
    }

    // Remove null bytes (prevents null byte injection)
    sanitized = sanitized.replaceAll('\x00', '');

    // Remove control characters except newlines and tabs
    sanitized = sanitized.replaceAll(
      RegExp(r'[\x01-\x08\x0B\x0C\x0E-\x1F\x7F]'),
      '',
    );

    return sanitized;
  }

  /// Sanitize URL input — validate scheme and remove dangerous chars
  static String? sanitizeUrl(String url) {
    final trimmed = url.trim();
    if (trimmed.isEmpty) return null;

    // Only allow http/https
    if (!trimmed.startsWith('http://') && !trimmed.startsWith('https://')) {
      return null;
    }

    // Block javascript: and data: schemes that could appear after redirect
    final lower = trimmed.toLowerCase();
    if (lower.contains('javascript:') || lower.contains('data:text')) {
      return null;
    }

    // Remove null bytes and control chars
    return trimmed.replaceAll(RegExp(r'[\x00-\x1F\x7F]'), '');
  }

  /// Sanitize file path to prevent path traversal
  static String sanitizeFilePath(String path) {
    // Remove path traversal sequences
    var safe = path.replaceAll('..', '').replaceAll('//', '/');
    // Remove leading slashes
    while (safe.startsWith('/')) {
      safe = safe.substring(1);
    }
    // Only allow alphanumeric, dots, hyphens, underscores, slashes
    safe = safe.replaceAll(RegExp(r'[^\w.\-/]'), '_');
    return safe;
  }

  // ═══ Certificate Pinning Helpers ═══

  /// Optional SHA-256 fingerprints for a user-selected self-hosted endpoint.
  static const List<String> pinnedCertHashes = [
    // Current certificate fingerprint (from `openssl s_client`)
    // This should be updated when certificates are renewed
  ];

  // ═══ Secure Random ═══

  /// Generate a cryptographically secure nonce
  static String generateNonce({int length = 16}) {
    const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
    final rng = Random.secure();
    return List.generate(
      length,
      (_) => chars[rng.nextInt(chars.length)],
    ).join();
  }

  /// Generate a cryptographically secure token
  static String generateSecureToken({int byteLength = 32}) {
    final rng = Random.secure();
    return List.generate(
      byteLength,
      (_) => rng.nextInt(256),
    ).map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }
}
