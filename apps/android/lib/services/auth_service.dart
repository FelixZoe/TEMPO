import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:hive_flutter/hive_flutter.dart';
import 'api_service.dart';
import 'cloud_sync_service.dart';
import 'persistence_service.dart';
import 'anti_abuse_service.dart';
import '../theme/miui_theme.dart';
import '../pages/auth_page.dart';
import '../pages/files_page.dart';
import 'integrity_service.dart';

/// User model
class UserInfo {
  final int id;
  final String email;
  final String nickname;
  final String avatarUrl;
  final String createdAt;
  final String? lastLogin;

  UserInfo({
    required this.id,
    required this.email,
    required this.nickname,
    this.avatarUrl = '',
    required this.createdAt,
    this.lastLogin,
  });

  factory UserInfo.fromJson(Map<String, dynamic> json) => UserInfo(
    id: json['id'] as int,
    email: json['email'] as String,
    nickname: (json['nickname'] as String?) ?? '',
    avatarUrl: (json['avatar_url'] as String?) ?? '',
    createdAt: (json['created_at'] as String?) ?? '',
    lastLogin: json['last_login'] as String?,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'email': email,
    'nickname': nickname,
    'avatar_url': avatarUrl,
    'created_at': createdAt,
    'last_login': lastLogin,
  };
}

/// Auth result
class AuthResult {
  final bool success;
  final String? error;
  final String? token;
  final String? refreshToken;
  final UserInfo? user;

  AuthResult({
    required this.success,
    this.error,
    this.token,
    this.refreshToken,
    this.user,
  });
}

/// Auth service — handles login, register, token management
class AuthService {
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  static const String _boxName = 'auth_data';
  static const String _tokenKey = 'jwt_token';
  static const String _refreshKey = 'refresh_token';
  static const String _userKey = 'user_info';

  /// Reuse a single HTTP client for connection pooling (BUG-9 fix)
  final http.Client _client = http.Client();

  Box? _box;
  UserInfo? _cachedUser;

  /// Initialize auth storage
  Future<void> init() async {
    _box = await Hive.openBox(_boxName);
    // Load cached user
    final raw = _box?.get(_userKey);
    if (raw != null) {
      try {
        _cachedUser = UserInfo.fromJson(Map<String, dynamic>.from(raw as Map));
      } catch (_) {
        _cachedUser = null;
      }
    }
    // Sync file storage userId with logged-in user
    _syncUserId();
  }

  /// Keep ServerConfig.userId in sync with the current user
  void _syncUserId() {
    if (_cachedUser != null) {
      ServerConfig.userId = 'user_${_cachedUser!.id}';
    } else {
      ServerConfig.userId = 'tempo_owner';
    }
  }

  /// Current user (from cache)
  UserInfo? get currentUser => _cachedUser;

  /// Whether user is logged in
  bool get isLoggedIn => token != null && _cachedUser != null;

  /// Whether current user is the blog/app admin.
  /// Admin = first registered user (id=1) or matching admin email.
  bool get isAdmin {
    final u = _cachedUser;
    if (u == null) return false;
    return u.id == 1 || u.email == 'zhuj3188@gmail.com';
  }

  /// Current JWT token
  String? get token => _box?.get(_tokenKey) as String?;

  /// Auth headers for API requests
  Map<String, String> get authHeaders => {
    if (token != null) 'Authorization': 'Bearer $token',
    'Content-Type': 'application/json',
  };

  // ═══ Check Email (is registered?) ═══
  Future<({bool success, bool registered, String? error})> checkEmail(
    String email,
  ) async {
    try {
      final resp = await _client
          .post(
            Uri.parse('${ServerConfig.baseUrl}/api/auth/check-email'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'email': email.trim().toLowerCase()}),
          )
          .timeout(const Duration(seconds: 10));

      final data = jsonDecode(resp.body) as Map<String, dynamic>;
      if (resp.statusCode == 200 && data['success'] == true) {
        return (
          success: true,
          registered: data['registered'] == true,
          error: null,
        );
      }
      return (
        success: false,
        registered: false,
        error: (data['error'] as String?) ?? '检查失败',
      );
    } catch (e) {
      if (kDebugMode) debugPrint('CheckEmail error: $e');
      return (success: false, registered: false, error: '网络错误，请检查网络连接');
    }
  }

  // ═══ Send Verification Code ═══
  Future<({bool success, String? error, int? cooldown})> sendCode(
    String email,
  ) async {
    // Anti-abuse: disposable email check
    if (AntiAbuseService.isDisposableEmail(email)) {
      return (
        success: false,
        error: AntiAbuseService.disposableEmailError,
        cooldown: null,
      );
    }
    // Anti-abuse: client-side rate limit (5/hour)
    if (AntiAbuseService.isSendCodeLimited()) {
      final cd = AntiAbuseService.getSendCodeCooldown();
      return (success: false, error: '发送过于频繁，请${cd ~/ 60}分钟后再试', cooldown: cd);
    }
    try {
      final path = '/api/auth/send-code';
      final body = {
        'email': email.trim().toLowerCase(),
        'device_id': AntiAbuseService.getDeviceId(),
      };
      // Use signed headers with device fingerprint
      final headers = AntiAbuseService.signedAuthHeaders(path, body: body);

      final resp = await _client
          .post(
            Uri.parse('${ServerConfig.baseUrl}$path'),
            headers: headers,
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 15));

      final data = jsonDecode(resp.body) as Map<String, dynamic>;
      if (resp.statusCode == 200 && data['success'] == true) {
        AntiAbuseService.recordSendCode();
        return (success: true, error: null, cooldown: null);
      }
      if (resp.statusCode == 429) {
        return (
          success: false,
          error: data['error'] as String?,
          cooldown: data['cooldown'] as int?,
        );
      }
      return (
        success: false,
        error: (data['error'] as String?) ?? '发送失败',
        cooldown: null,
      );
    } catch (e) {
      if (kDebugMode) debugPrint('SendCode error: $e');
      return (success: false, error: '网络错误，请检查网络连接', cooldown: null);
    }
  }

  // ═══ Register (with verification code) ═══
  Future<AuthResult> register({
    required String email,
    required String password,
    String? nickname,
    required String code,
  }) async {
    // Anti-abuse: disposable email check
    if (AntiAbuseService.isDisposableEmail(email)) {
      return AuthResult(
        success: false,
        error: AntiAbuseService.disposableEmailError,
      );
    }
    // Anti-abuse: client-side rate limit (3/24h)
    if (AntiAbuseService.isRegisterLimited()) {
      return AuthResult(success: false, error: '注册过于频繁，请24小时后再试');
    }
    try {
      final path = '/api/auth/register';
      final body = {
        'email': email.trim().toLowerCase(),
        'password': password,
        'code': code.trim(),
        'device_id': AntiAbuseService.getDeviceId(),
        if (nickname != null && nickname.trim().isNotEmpty)
          'nickname': nickname.trim(),
      };
      // Use signed headers with device fingerprint
      final headers = AntiAbuseService.signedAuthHeaders(path, body: body);

      final resp = await _client
          .post(
            Uri.parse('${ServerConfig.baseUrl}$path'),
            headers: headers,
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 10));

      final data = jsonDecode(resp.body) as Map<String, dynamic>;

      if (resp.statusCode == 200 && data['success'] == true) {
        AntiAbuseService.recordRegister();
        await _saveAuth(data);
        return AuthResult(
          success: true,
          token: data['token'] as String?,
          refreshToken: data['refresh_token'] as String?,
          user: _cachedUser,
        );
      } else {
        return AuthResult(
          success: false,
          error: (data['error'] as String?) ?? '注册失败',
        );
      }
    } catch (e) {
      if (kDebugMode) debugPrint('Register error: $e');
      return AuthResult(success: false, error: '网络错误，请检查网络连接');
    }
  }

  // ═══ Login ═══
  Future<AuthResult> login({
    required String email,
    required String password,
  }) async {
    try {
      final body = {'email': email.trim().toLowerCase(), 'password': password};

      final resp = await _client
          .post(
            Uri.parse('${ServerConfig.baseUrl}/api/auth/login'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 10));

      final data = jsonDecode(resp.body) as Map<String, dynamic>;

      if (resp.statusCode == 200 && data['success'] == true) {
        await _saveAuth(data);
        return AuthResult(
          success: true,
          token: data['token'] as String?,
          refreshToken: data['refresh_token'] as String?,
          user: _cachedUser,
        );
      } else {
        return AuthResult(
          success: false,
          error: (data['error'] as String?) ?? '登录失败',
        );
      }
    } catch (e) {
      if (kDebugMode) debugPrint('Login error: $e');
      return AuthResult(success: false, error: '网络错误，请检查网络连接');
    }
  }

  // ═══ Refresh token ═══
  Future<bool> refreshAccessToken() async {
    final rt = _box?.get(_refreshKey) as String?;
    if (rt == null) return false;
    try {
      final resp = await _client
          .post(
            Uri.parse('${ServerConfig.baseUrl}/api/auth/refresh'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'refresh_token': rt}),
          )
          .timeout(const Duration(seconds: 10));

      final data = jsonDecode(resp.body) as Map<String, dynamic>;
      if (resp.statusCode == 200 && data['success'] == true) {
        await _box?.put(_tokenKey, data['token']);
        await _box?.put(_refreshKey, data['refresh_token']);
        return true;
      }
    } catch (_) {}
    return false;
  }

  // ═══ Get profile (from server) ═══
  Future<UserInfo?> fetchProfile() async {
    if (token == null) return null;
    try {
      final resp = await _client
          .get(
            Uri.parse('${ServerConfig.baseUrl}/api/auth/profile'),
            headers: authHeaders,
          )
          .timeout(const Duration(seconds: 10));

      final data = jsonDecode(resp.body) as Map<String, dynamic>;
      if (resp.statusCode == 200 && data['success'] == true) {
        final user = UserInfo.fromJson(data['user'] as Map<String, dynamic>);
        _cachedUser = user;
        await _box?.put(_userKey, user.toJson());
        return user;
      } else if (resp.statusCode == 401) {
        // Token expired, try refresh
        if (await refreshAccessToken()) {
          return fetchProfile();
        }
        await logout();
      }
    } catch (_) {}
    return _cachedUser;
  }

  // ═══ Update profile ═══
  Future<bool> updateProfile({String? nickname, String? avatarUrl}) async {
    if (token == null) return false;
    try {
      final body = <String, dynamic>{};
      if (nickname != null) body['nickname'] = nickname;
      if (avatarUrl != null) body['avatar_url'] = avatarUrl;

      final resp = await _client
          .put(
            Uri.parse('${ServerConfig.baseUrl}/api/auth/profile'),
            headers: authHeaders,
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 10));

      final data = jsonDecode(resp.body) as Map<String, dynamic>;
      if (resp.statusCode == 200 && data['success'] == true) {
        final user = UserInfo.fromJson(data['user'] as Map<String, dynamic>);
        _cachedUser = user;
        await _box?.put(_userKey, user.toJson());
        return true;
      }
    } catch (_) {}
    return false;
  }

  // ═══ Change password ═══
  Future<AuthResult> changePassword({
    required String oldPassword,
    required String newPassword,
  }) async {
    if (token == null) return AuthResult(success: false, error: '未登录');
    try {
      final resp = await _client
          .put(
            Uri.parse('${ServerConfig.baseUrl}/api/auth/password'),
            headers: authHeaders,
            body: jsonEncode({
              'old_password': oldPassword,
              'new_password': newPassword,
            }),
          )
          .timeout(const Duration(seconds: 10));

      final data = jsonDecode(resp.body) as Map<String, dynamic>;
      if (resp.statusCode == 200 && data['success'] == true) {
        return AuthResult(success: true);
      }
      return AuthResult(
        success: false,
        error: (data['error'] as String?) ?? '修改失败',
      );
    } catch (e) {
      return AuthResult(success: false, error: '网络错误');
    }
  }

  // ═══ Reset password (forgot password) ═══
  Future<AuthResult> resetPassword({
    required String email,
    required String code,
    required String newPassword,
  }) async {
    try {
      final resp = await _client
          .post(
            Uri.parse('${ServerConfig.baseUrl}/api/auth/reset-password'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'email': email.trim().toLowerCase(),
              'code': code,
              'new_password': newPassword,
            }),
          )
          .timeout(const Duration(seconds: 10));

      final data = jsonDecode(resp.body) as Map<String, dynamic>;
      if (resp.statusCode == 200 && data['success'] == true) {
        return AuthResult(success: true);
      }
      return AuthResult(
        success: false,
        error: (data['error'] as String?) ?? '重置失败',
      );
    } catch (e) {
      if (kDebugMode) debugPrint('ResetPassword error: $e');
      return AuthResult(success: false, error: '网络错误');
    }
  }

  // ═══ Logout ═══
  Future<void> logout() async {
    // 1. Push current user's data to cloud before logout (save their latest state)
    if (isLoggedIn) {
      try {
        final syncService = CloudSyncService();
        await syncService.pushToCloud().timeout(const Duration(seconds: 10));
      } catch (_) {}
    }

    // 2. Server-side logout
    if (token != null) {
      try {
        await _client
            .post(
              Uri.parse('${ServerConfig.baseUrl}/api/auth/logout'),
              headers: authHeaders,
            )
            .timeout(const Duration(seconds: 5));
      } catch (_) {}
    }

    // 3. Clear auth tokens
    _cachedUser = null;
    await _box?.delete(_tokenKey);
    await _box?.delete(_refreshKey);
    await _box?.delete(_userKey);

    // 4. Clear all local user data to prevent leaking to next account
    await PersistenceService.clearAllUserData();

    // 5. Clear file page cache to prevent cross-account file leaking
    FilesPage.clearCache();

    // 6. Reset file storage userId back to default
    _syncUserId();
  }

  // ═══ Login Gate ═══

  /// Check login and show bottom sheet prompt if not logged in.
  /// Also checks app integrity — if tampered, shows warning and blocks.
  /// Returns true if logged in, false if not (and prompt shown).
  /// Usage: if (!AuthService().requireLogin(context)) return;
  bool requireLogin(BuildContext context, {String action = '使用此功能'}) {
    // TEMPO is a personal, local-first workspace. Local features never require
    // an account; self-hosted sync is paired separately in settings.
    final integrity = IntegrityService();
    if (!integrity.isLegitimate) {
      _showIntegrityWarning(context, integrity.blockReason);
      return false;
    }
    return true;
  }

  /// Show integrity violation warning
  void _showIntegrityWarning(BuildContext context, String reason) {
    final colors = AppColors.of(context);
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: colors.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: MiuiColors.red.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.shield_outlined,
                size: 24,
                color: MiuiColors.red,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                '安全警告',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: colors.textPrimary,
                ),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              reason.isNotEmpty ? reason : '检测到应用完整性异常，为保护您的数据安全，部分功能暂时不可用。',
              style: TextStyle(
                fontSize: 14,
                color: colors.textSecondary,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: MiuiColors.blue.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.download_rounded,
                    size: 18,
                    color: MiuiColors.blue,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      '请从 ${ServerConfig.baseUrl} 下载官方版本',
                      style: const TextStyle(
                        fontSize: 13,
                        color: MiuiColors.blue,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('知道了', style: TextStyle(color: colors.textSecondary)),
          ),
        ],
      ),
    );
  }

  /// Navigate to auth page
  void _navigateToLogin(BuildContext context) {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => AuthPage(onLoginSuccess: () {})));
  }

  // ═══ Internal ═══
  Future<void> _saveAuth(Map<String, dynamic> data) async {
    if (data.containsKey('token')) {
      await _box?.put(_tokenKey, data['token']);
    }
    if (data.containsKey('refresh_token')) {
      await _box?.put(_refreshKey, data['refresh_token']);
    }
    if (data.containsKey('user')) {
      final user = UserInfo.fromJson(data['user'] as Map<String, dynamic>);
      _cachedUser = user;
      await _box?.put(_userKey, user.toJson());
      // Sync file storage userId
      _syncUserId();
      // BUG-19: Invalidate file cache so new user's files are loaded
      FilesPage.invalidateCache();
    }
  }
}
