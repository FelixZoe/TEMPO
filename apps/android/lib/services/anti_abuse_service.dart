import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'api_service.dart';
import 'secure_config.dart';

/// Anti-abuse service v2.6: enhanced security
///
/// Improvements:
/// - Uses SecureConfig derived keys (no hardcoded secrets)
/// - Stronger HMAC signing with body hash
/// - Enhanced disposable email detection
/// - IP-based rate limiting hints
class AntiAbuseService {
  static final AntiAbuseService _instance = AntiAbuseService._();
  factory AntiAbuseService() => _instance;
  AntiAbuseService._();

  static late Box _box;

  static Future<void> init() async {
    _box = await Hive.openBox('anti_abuse');
  }

  // ═══════════════════════════════════════════
  // 1. Device Fingerprint (persistent UUID)
  // ═══════════════════════════════════════════

  /// Get or generate a persistent device ID
  static String getDeviceId() {
    String? id = _box.get('device_id') as String?;
    if (id == null || id.isEmpty) {
      id = _generateUUID();
      _box.put('device_id', id);
    }
    return id;
  }

  static String _generateUUID() {
    final rng = Random.secure();
    final bytes = List<int>.generate(16, (_) => rng.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40; // version 4
    bytes[8] = (bytes[8] & 0x3f) | 0x80; // variant
    final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-'
        '${hex.substring(12, 16)}-${hex.substring(16, 20)}-'
        '${hex.substring(20, 32)}';
  }

  // ═══════════════════════════════════════════
  // 2. HMAC Signing for Auth Requests
  // ═══════════════════════════════════════════

  /// Generate signed headers for auth API calls (register, send-code)
  /// Server should verify these to reject direct API calls without the app
  static Map<String, String> signedAuthHeaders(
    String path, {
    Map<String, dynamic>? body,
  }) {
    final timestamp = (DateTime.now().millisecondsSinceEpoch ~/ 1000)
        .toString();
    final nonce = ServerConfig.generateNonce();
    final deviceId = getDeviceId();

    // Sign: timestamp + nonce + path + deviceId + bodyHash
    final bodyStr = body != null ? jsonEncode(body) : '';
    final bodyHash = md5.convert(utf8.encode(bodyStr)).toString();
    final message = '$timestamp$nonce$path$deviceId$bodyHash';

    // SEC: Use derived signing key instead of hardcoded
    final key = utf8.encode(SecureConfig.signingSecret);
    final hmacSha256 = Hmac(sha256, key);
    final signature = hmacSha256.convert(utf8.encode(message)).toString();

    return {
      'Content-Type': 'application/json',
      'X-Timestamp': timestamp,
      'X-Nonce': nonce,
      'X-Signature': signature,
      'X-Device-Id': deviceId,
    };
  }

  // ═══════════════════════════════════════════
  // 3. Disposable Email Blocking
  // ═══════════════════════════════════════════

  /// Known disposable/temporary email domains
  static const _disposableDomains = <String>{
    // Popular disposable email services
    'guerrillamail.com', 'guerrillamail.net', 'guerrillamail.org',
    'guerrillamailblock.com', 'grr.la', 'sharklasers.com',
    'tempmail.com', 'temp-mail.org', 'temp-mail.io',
    'throwaway.email', 'throwaway.com',
    'mailinator.com', 'mailinator.net', 'mailinator2.com',
    'maildrop.cc', 'maildrop.gq',
    'yopmail.com', 'yopmail.fr', 'yopmail.net',
    'dispostable.com', 'trashmail.com', 'trashmail.net',
    'trashmail.me', 'trashmail.org',
    'fakeinbox.com', 'fakeemail.org',
    'tempinbox.com', 'tempr.email',
    'discard.email', 'discardmail.com', 'discardmail.de',
    'mohmal.com', 'mohmal.im', 'mohmal.in',
    'getnada.com', 'nada.email',
    'emailondeck.com', 'emailfake.com',
    'crazymailing.com', 'mailnesia.com',
    'mintemail.com', 'binkmail.com',
    'spamgourmet.com', 'spamfree24.org',
    'mytemp.email', 'tempail.com',
    'harakirimail.com', 'mailnator.com',
    '10minutemail.com', '10minutemail.net',
    '20minutemail.com', '20minutemail.it',
    'mailcatch.com', 'mailexpire.com',
    'mailzilla.com', 'inboxbear.com',
    'guerrillamail.de', 'getairmail.com',
    'wegwerfmail.de', 'wegwerfmail.net',
    'byom.de', 'trash-mail.at',
    'jetable.org', 'mailscrap.com',
    'mx0.wwwnew.eu', 'disposableemailaddresses.emailmiser.com',
    // Chinese temp email
    'linshiyouxiang.net', 'bccto.me', 'chacuo.net',
    'moakt.cc', 'moakt.co', 'moakt.ws',
    '24mail.chacuo.net', 'guerrillamail.info',
  };

  /// Check if an email uses a known disposable domain
  static bool isDisposableEmail(String email) {
    final domain = email.split('@').last.toLowerCase().trim();
    if (_disposableDomains.contains(domain)) return true;

    // Heuristic: domains with many dots or very short TLDs often suspicious
    // But don't block legitimate ones — keep it conservative
    for (final d in _disposableDomains) {
      if (domain.endsWith('.$d')) return true;
    }
    return false;
  }

  /// Get user-friendly error for disposable email
  static String get disposableEmailError => '不支持临时邮箱注册，请使用常用邮箱';

  // ═══════════════════════════════════════════
  // 4. Client-side Rate Limiting
  // ═══════════════════════════════════════════

  /// Record a send-code attempt
  static void recordSendCode() {
    final now = DateTime.now().millisecondsSinceEpoch;
    final attempts = _getAttemptList('send_code_attempts');
    attempts.add(now);
    // Keep last 1 hour only
    final cutoff = now - 3600000;
    attempts.removeWhere((t) => t < cutoff);
    _box.put('send_code_attempts', attempts);
  }

  /// Check if send-code is rate-limited (max 5 per hour on client side)
  static bool isSendCodeLimited() {
    final now = DateTime.now().millisecondsSinceEpoch;
    final cutoff = now - 3600000; // 1 hour
    final attempts = _getAttemptList('send_code_attempts');
    final recentAttempts = attempts.where((t) => t >= cutoff).length;
    return recentAttempts >= 5;
  }

  /// Record a registration attempt
  static void recordRegister() {
    final now = DateTime.now().millisecondsSinceEpoch;
    final attempts = _getAttemptList('register_attempts');
    attempts.add(now);
    // Keep last 24 hours only
    final cutoff = now - 86400000;
    attempts.removeWhere((t) => t < cutoff);
    _box.put('register_attempts', attempts);
  }

  /// Check if registration is rate-limited (max 3 per 24h on client side)
  static bool isRegisterLimited() {
    final now = DateTime.now().millisecondsSinceEpoch;
    final cutoff = now - 86400000; // 24 hours
    final attempts = _getAttemptList('register_attempts');
    final recentAttempts = attempts.where((t) => t >= cutoff).length;
    return recentAttempts >= 3;
  }

  /// Get remaining cooldown for send-code (seconds), 0 if not limited
  static int getSendCodeCooldown() {
    if (!isSendCodeLimited()) return 0;
    final attempts = _getAttemptList('send_code_attempts');
    if (attempts.isEmpty) return 0;
    final oldest = attempts.reduce((a, b) => a < b ? a : b);
    final remaining =
        (oldest + 3600000 - DateTime.now().millisecondsSinceEpoch) ~/ 1000;
    return remaining > 0 ? remaining : 0;
  }

  static List<int> _getAttemptList(String key) {
    final raw = _box.get(key, defaultValue: <dynamic>[]);
    return (raw as List).map((e) => e as int).toList();
  }

  // ═══════════════════════════════════════════
  // 5. Debug info
  // ═══════════════════════════════════════════

  static Map<String, dynamic> debugInfo() {
    return {
      'device_id': getDeviceId(),
      'send_code_attempts_1h': _getAttemptList('send_code_attempts')
          .where((t) => t >= DateTime.now().millisecondsSinceEpoch - 3600000)
          .length,
      'register_attempts_24h': _getAttemptList('register_attempts')
          .where((t) => t >= DateTime.now().millisecondsSinceEpoch - 86400000)
          .length,
    };
  }
}
