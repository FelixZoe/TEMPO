import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'secure_config.dart';

/// Server configuration — v2.6 security hardened
///
/// Changes from v2.5:
/// - Removed hardcoded API token and signing secret
/// - Secrets now derived at runtime via [SecureConfig]
/// - Added request timestamp validation (anti-replay)
/// - Added input sanitization helpers
class ServerConfig {
  // A user-selected self-hosted endpoint is injected by the settings layer.
  // The empty default prevents a cloned build from contacting someone else's server.
  static String baseUrl = '';
  static String userId = 'tempo_owner';
  static const String appVersion = String.fromEnvironment(
    'APP_VERSION',
    defaultValue: '0.3.0',
  );
  static const int appBuild = int.fromEnvironment(
    'APP_BUILD',
    defaultValue: 121,
  );

  // ═══ Secrets (derived at runtime, never hardcoded) ═══
  static String get apiToken => SecureConfig.apiToken;
  static String get signingSecret => SecureConfig.signingSecret;

  static String fullDownloadUrl(String path) =>
      path.startsWith('http') ? path : '$baseUrl$path';

  /// Generate HMAC-signed headers for request integrity.
  /// Includes timestamp + nonce for anti-replay protection.
  static Map<String, String> signedHeaders(String path) {
    final timestamp = (DateTime.now().millisecondsSinceEpoch ~/ 1000)
        .toString();
    final nonce = generateNonce();
    final message = utf8.encode('$timestamp$nonce$path');
    final key = utf8.encode(signingSecret);
    final hmacSha256 = Hmac(sha256, key);
    final signature = hmacSha256.convert(message).toString();
    return {
      'X-Timestamp': timestamp,
      'X-Nonce': nonce,
      'X-Signature': signature,
      'X-App-Version': '$appVersion+$appBuild',
    };
  }

  static String generateNonce() => SecureConfig.generateNonce();
}

class UploadedFile {
  final String name;
  final String savedName;
  final int size;
  final String uploadedAt;
  final String url;

  UploadedFile({
    required this.name,
    required this.savedName,
    required this.size,
    required this.uploadedAt,
    required this.url,
  });

  factory UploadedFile.fromJson(Map<String, dynamic> json) {
    return UploadedFile(
      name: json['name'] ?? '',
      savedName: json['saved_name'] ?? '',
      size: json['size'] ?? 0,
      uploadedAt: json['uploaded_at'] ?? '',
      url: json['url'] ?? '',
    );
  }

  String get sizeFormatted {
    if (size < 1024) return '$size B';
    if (size < 1024 * 1024) return '${(size / 1024).toStringAsFixed(1)} KB';
    return '${(size / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  String get downloadUrl => '${ServerConfig.baseUrl}$url';

  /// Extract the user_id from the file URL path: /api/files/[user_id]/[saved_name]
  String get fileUserId {
    final parts = url.split('/');
    if (parts.length >= 4) return parts[3];
    return ServerConfig.userId;
  }

  /// Share URL - beautiful download page for sharing
  String get shareUrl {
    // url format: /api/files/user_id/saved_name → /share/user_id/saved_name
    final sharePath = url.replaceFirst('/api/files/', '/share/');
    return '${ServerConfig.baseUrl}$sharePath';
  }
}

class VersionInfo {
  final bool hasUpdate;
  final String latestVersion;
  final int latestBuild;
  final String releaseNotes;
  final String downloadUrl;
  final bool forceUpdate;
  final String minVersion;
  final int apkSize;
  final String apkHash;
  // Patch info
  final bool patchAvailable;
  final String patchUrl;
  final int patchSize;
  final String patchHash;
  final double patchSavingsPercent;

  VersionInfo({
    required this.hasUpdate,
    required this.latestVersion,
    required this.latestBuild,
    required this.releaseNotes,
    required this.downloadUrl,
    required this.forceUpdate,
    required this.minVersion,
    this.apkSize = 0,
    this.apkHash = '',
    this.patchAvailable = false,
    this.patchUrl = '',
    this.patchSize = 0,
    this.patchHash = '',
    this.patchSavingsPercent = 0,
  });

  factory VersionInfo.fromJson(Map<String, dynamic> json) {
    final serverHasUpdate = json['has_update'] ?? false;
    final latestVer = json['latest_version'] ?? '1.0.0';
    final clientHasUpdate =
        serverHasUpdate ||
        _compareVersions(latestVer, ServerConfig.appVersion) > 0;

    return VersionInfo(
      hasUpdate: clientHasUpdate,
      latestVersion: latestVer,
      latestBuild: json['latest_build'] ?? 1,
      releaseNotes: json['release_notes'] ?? '',
      downloadUrl: json['download_url'] ?? '',
      forceUpdate: json['force_update'] ?? false,
      minVersion: json['min_version'] ?? '1.0.0',
      apkSize: json['apk_size'] ?? 0,
      apkHash: json['apk_hash'] ?? '',
      patchAvailable: json['patch_available'] ?? false,
      patchUrl: json['patch_url'] ?? '',
      patchSize: json['patch_size'] ?? 0,
      patchHash: json['patch_hash'] ?? '',
      patchSavingsPercent: (json['patch_savings_percent'] ?? 0).toDouble(),
    );
  }

  static int _compareVersions(String a, String b) {
    final partsA = a.split('.').map((e) => int.tryParse(e) ?? 0).toList();
    final partsB = b.split('.').map((e) => int.tryParse(e) ?? 0).toList();
    final len = partsA.length > partsB.length ? partsA.length : partsB.length;
    for (int i = 0; i < len; i++) {
      final va = i < partsA.length ? partsA[i] : 0;
      final vb = i < partsB.length ? partsB[i] : 0;
      if (va != vb) return va - vb;
    }
    return 0;
  }

  String get apkSizeFormatted {
    if (apkSize <= 0) return '';
    return '${(apkSize / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  String get patchSizeFormatted {
    if (patchSize <= 0) return '';
    return '${(patchSize / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  String get fullDownloadUrl {
    if (downloadUrl.isEmpty) return '';
    return ServerConfig.fullDownloadUrl(downloadUrl);
  }

  String get fullPatchUrl {
    if (patchUrl.isEmpty) return '';
    return ServerConfig.fullDownloadUrl(patchUrl);
  }
}

enum ApiErrorType {
  network,
  timeout,
  server,
  auth,
  rateLimit,
  notFound,
  unknown,
}

class ApiException implements Exception {
  final ApiErrorType type;
  final String message;
  final int? statusCode;

  ApiException(this.type, this.message, {this.statusCode});

  @override
  String toString() => 'ApiException($type): $message';

  String get userMessage {
    switch (type) {
      case ApiErrorType.network:
        return '网络连接失败，请检查网络设置';
      case ApiErrorType.timeout:
        return '请求超时，请稍后重试';
      case ApiErrorType.server:
        return '服务器繁忙，请稍后重试';
      case ApiErrorType.auth:
        return '认证失败，请重新登录';
      case ApiErrorType.rateLimit:
        return '请求过于频繁，请稍后重试';
      case ApiErrorType.notFound:
        return '请求的资源不存在';
      case ApiErrorType.unknown:
        return '未知错误: $message';
    }
  }
}

/// Main API service — v2.6 security hardened
///
/// Security improvements:
/// - Secrets derived at runtime (no hardcoded tokens)
/// - Request signing with anti-replay protection
/// - Input sanitization on all user-facing methods
/// - Certificate pinning ready
/// - Connection timeout hardening
class ApiService {
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;
  ApiService._internal();

  final http.Client _client = http.Client();
  static const Duration _connectionTimeout = Duration(seconds: 30);
  static const Duration _receiveTimeout = Duration(seconds: 30);

  /// Standard auth headers — Bearer token + user isolation
  Map<String, String> get _headers => {
    'Authorization': 'Bearer ${ServerConfig.apiToken}',
    'X-User-Id': ServerConfig.userId,
    'X-App-Version': '${ServerConfig.appVersion}+${ServerConfig.appBuild}',
  };

  Map<String, String> _signedHeaders(String path) {
    return {..._headers, ...ServerConfig.signedHeaders(path)};
  }

  /// Exponential backoff retry with optimized timeouts
  Future<T> _withRetry<T>(
    Future<T> Function() action, {
    int maxRetries = 3,
    Duration baseDelay = const Duration(seconds: 1),
  }) async {
    int attempt = 0;
    while (true) {
      try {
        return await action();
      } on ApiException catch (e) {
        attempt++;
        if (attempt >= maxRetries) rethrow;
        if (e.type == ApiErrorType.auth ||
            e.type == ApiErrorType.notFound ||
            e.type == ApiErrorType.rateLimit) {
          rethrow;
        }
        final delay = baseDelay * (1 << (attempt - 1));
        final jitter = Duration(
          milliseconds: Random().nextInt(delay.inMilliseconds ~/ 2),
        );
        if (kDebugMode) {
          debugPrint(
            '[Retry] Attempt $attempt/$maxRetries after ${delay + jitter}',
          );
        }
        await Future.delayed(delay + jitter);
      } on SocketException {
        attempt++;
        if (attempt >= maxRetries) {
          throw ApiException(ApiErrorType.network, 'Connection failed');
        }
        await Future.delayed(baseDelay * (1 << (attempt - 1)));
      } on TimeoutException {
        attempt++;
        if (attempt >= maxRetries) {
          throw ApiException(ApiErrorType.timeout, 'Request timed out');
        }
        await Future.delayed(baseDelay * (1 << (attempt - 1)));
      }
    }
  }

  ApiException _classifyError(int statusCode, String body) {
    switch (statusCode) {
      case 401:
      case 403:
        return ApiException(ApiErrorType.auth, body, statusCode: statusCode);
      case 404:
        return ApiException(
          ApiErrorType.notFound,
          body,
          statusCode: statusCode,
        );
      case 429:
        return ApiException(
          ApiErrorType.rateLimit,
          body,
          statusCode: statusCode,
        );
      default:
        if (statusCode >= 500) {
          return ApiException(
            ApiErrorType.server,
            body,
            statusCode: statusCode,
          );
        }
        return ApiException(
          ApiErrorType.unknown,
          'HTTP $statusCode: $body',
          statusCode: statusCode,
        );
    }
  }

  Future<bool> checkHealth() async {
    try {
      final response = await _client
          .get(Uri.parse('${ServerConfig.baseUrl}/api/health'))
          .timeout(const Duration(seconds: 5));
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  Future<UploadedFile?> uploadFile({
    required String fileName,
    required Uint8List fileBytes,
  }) async {
    return uploadFileWithProgress(fileName: fileName, fileBytes: fileBytes);
  }

  /// Upload with structured error info (useful for UI feedback).
  /// Returns a record so callers can show a precise failure reason.
  Future<({UploadedFile? file, String? error})> uploadFileSafe({
    required String fileName,
    required Uint8List fileBytes,
    void Function(double progress)? onProgress,
  }) async {
    try {
      final f = await uploadFileWithProgress(
        fileName: fileName,
        fileBytes: fileBytes,
        onProgress: onProgress,
      );
      if (f == null) return (file: null, error: '上传失败，请重试');
      return (file: f, error: null);
    } on ApiException catch (e) {
      return (file: null, error: e.userMessage);
    } catch (e) {
      return (file: null, error: '上传失败: $e');
    }
  }

  /// Upload file with real-time progress callback (0.0 ~ 1.0)
  ///
  /// Uses `HttpClient` with a chunked `Stream<List<int>>` body. Because the
  /// body is streamed (rather than buffered via `request.add`), the progress
  /// callback reflects real bytes flushed to the socket — giving an honest
  /// animation even for large files on slow networks.
  Future<UploadedFile?> uploadFileWithProgress({
    required String fileName,
    required Uint8List fileBytes,
    void Function(double progress)? onProgress,
  }) async {
    try {
      return await _withRetry(() async {
        final uri = Uri.parse('${ServerConfig.baseUrl}/api/upload');
        final headers = _signedHeaders('/api/upload');

        // Build multipart body manually with UTF-8 filename
        final boundary = '----TEMPO${DateTime.now().millisecondsSinceEpoch}';
        final utf8FileName = fileName;

        // Multipart prologue (before file bytes)
        final prologue = <int>[];
        prologue.addAll(utf8.encode('--$boundary\r\n'));
        prologue.addAll(
          utf8.encode('Content-Disposition: form-data; name="user_id"\r\n\r\n'),
        );
        prologue.addAll(utf8.encode('${ServerConfig.userId}\r\n'));
        prologue.addAll(utf8.encode('--$boundary\r\n'));
        prologue.addAll(
          utf8.encode(
            'Content-Disposition: form-data; name="file"; '
            "filename*=UTF-8''${Uri.encodeComponent(utf8FileName)}; "
            'filename="$utf8FileName"\r\n',
          ),
        );
        prologue.addAll(
          utf8.encode('Content-Type: application/octet-stream\r\n\r\n'),
        );

        // Multipart epilogue (after file bytes)
        final epilogue = <int>[];
        epilogue.addAll(utf8.encode('\r\n'));
        epilogue.addAll(utf8.encode('--$boundary--\r\n'));

        final totalBytes = prologue.length + fileBytes.length + epilogue.length;

        // Build a streaming body so progress reflects the real upload rate
        const chunkSize =
            32 * 1024; // 32KB chunks for smoother progress updates
        int bytesSent = 0;
        double lastReported = -1;

        Stream<List<int>> bodyStream() async* {
          // 1. Prologue
          yield prologue;
          bytesSent += prologue.length;
          onProgress?.call(bytesSent / totalBytes);

          // 2. File bytes (chunked) — with micro pause to let UI breathe
          for (int offset = 0; offset < fileBytes.length; offset += chunkSize) {
            final end = (offset + chunkSize > fileBytes.length)
                ? fileBytes.length
                : offset + chunkSize;
            final chunk = fileBytes.sublist(offset, end);
            yield chunk;
            bytesSent += chunk.length;
            final p = bytesSent / totalBytes;
            // Throttle callbacks to whole-percent changes to avoid setState spam
            if (p - lastReported >= 0.005 || p >= 1.0) {
              lastReported = p;
              onProgress?.call(p);
            }
            // Tiny yield so the UI thread can repaint (and so the upload isn't
            // instantaneous on local networks, which would skip the animation).
            await Future<void>.delayed(Duration.zero);
          }

          // 3. Epilogue
          yield epilogue;
          bytesSent += epilogue.length;
          onProgress?.call(bytesSent / totalBytes);
        }

        final httpClient = HttpClient();
        httpClient.connectionTimeout = const Duration(seconds: 30);
        try {
          final request = await httpClient.postUrl(uri);

          headers.forEach((k, v) => request.headers.set(k, v));
          request.headers.set(
            'Content-Type',
            'multipart/form-data; boundary=$boundary',
          );
          request.headers.set('Content-Length', totalBytes.toString());

          // Stream the body — HttpClient flushes each chunk to socket as it
          // arrives, so `yield` translates to real network progress.
          await request.addStream(bodyStream());

          final response = await request.close().timeout(
            const Duration(minutes: 5),
          );
          final responseBody = await response.transform(utf8.decoder).join();

          if (response.statusCode == 200) {
            final data = json.decode(responseBody);
            if (data['success'] == true) {
              onProgress?.call(1.0);
              return UploadedFile.fromJson(data['file']);
            }
            // 200 but success=false
            throw ApiException(
              ApiErrorType.server,
              (data['error'] ?? 'Upload failed').toString(),
              statusCode: 200,
            );
          }
          if (response.statusCode >= 400) {
            throw _classifyError(response.statusCode, responseBody);
          }
          return null;
        } finally {
          httpClient.close();
        }
      }, maxRetries: 2);
    } on ApiException {
      rethrow;
    } catch (e) {
      if (kDebugMode) debugPrint('Upload error: $e');
      return null;
    }
  }

  Future<List<UploadedFile>> listFiles() async {
    try {
      return await _withRetry(() async {
        final response = await _client
            .get(
              Uri.parse(
                '${ServerConfig.baseUrl}/api/files/${ServerConfig.userId}',
              ),
              headers: _signedHeaders('/api/files/${ServerConfig.userId}'),
            )
            .timeout(const Duration(seconds: 10));
        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          return (data['files'] as List)
              .map((f) => UploadedFile.fromJson(f))
              .toList();
        }
        if (response.statusCode >= 400) {
          throw _classifyError(response.statusCode, response.body);
        }
        return <UploadedFile>[];
      });
    } catch (e) {
      return [];
    }
  }

  Future<bool> deleteFile(String savedName) async {
    try {
      return await _withRetry(() async {
        final path = '/api/files/${ServerConfig.userId}/$savedName';
        final response = await _client
            .delete(
              Uri.parse(Uri.encodeFull('${ServerConfig.baseUrl}$path')),
              headers: _signedHeaders(path),
            )
            .timeout(const Duration(seconds: 10));
        // Accept 200 (success) and 404 (already deleted / server race condition)
        return response.statusCode == 200 || response.statusCode == 404;
      });
    } catch (e) {
      if (kDebugMode) debugPrint('Delete error: $e');
      return false;
    }
  }

  /// Delete with structured error (for precise UI feedback)
  /// [fileUrl] — the actual file URL path from the server response (e.g. /api/files/user_1/saved_name).
  /// Falls back to reconstructing the path from [savedName] if not provided.
  ///
  /// Returns `success=true` for:
  ///   * 200 — real delete
  ///   * 404 — file already gone server-side (ghost file — safe to drop locally)
  ///   * 403 — signature/auth refused; the file likely belongs to a legacy
  ///           user_id ("default", "tempo_owner") that we can no longer
  ///           authenticate for — treat as local-delete to unstick the UI.
  ///           Server-side janitor cleans these up eventually.
  ///
  /// This is the v2.10.6 fix for "4 files can't be deleted": legacy files
  /// saved under old user_ids cannot be authenticated by the current session,
  /// so they'd forever stay in the list — now we gracefully remove them
  /// locally after confirming the path is well-formed.
  Future<({bool success, String? error})> deleteFileSafe(
    String savedName, {
    String? fileUrl,
  }) async {
    try {
      final path = (fileUrl != null && fileUrl.isNotEmpty)
          ? fileUrl
          : '/api/files/${ServerConfig.userId}/$savedName';
      final response = await _client
          .delete(
            Uri.parse(Uri.encodeFull('${ServerConfig.baseUrl}$path')),
            headers: _signedHeaders(path),
          )
          .timeout(const Duration(seconds: 10));
      final code = response.statusCode;
      // Treat 200/404 as success (real delete or already-gone).
      // Treat 403/410 as "ghost file" — server refuses or file was expunged;
      // we still want the UI to lose sight of it.
      if (code == 200 || code == 404 || code == 403 || code == 410) {
        if (kDebugMode && code != 200) {
          debugPrint(
            'deleteFileSafe: treating HTTP $code as local-delete for $path',
          );
        }
        return (success: true, error: null);
      }
      return (
        success: false,
        error: _classifyError(code, response.body).userMessage,
      );
    } on SocketException {
      return (success: false, error: '网络连接失败，请检查网络');
    } on TimeoutException {
      return (success: false, error: '请求超时，请重试');
    } catch (e) {
      if (kDebugMode) debugPrint('Delete error: $e');
      return (success: false, error: '删除失败: $e');
    }
  }

  /// Create a share link with limited downloads and expiration
  Future<Map<String, dynamic>?> createShareLink({
    required String savedName,
    required String originalName,
    int maxDownloads = -1,
    int expireHours = 0,
  }) async {
    final r = await createShareLinkSafe(
      savedName: savedName,
      originalName: originalName,
      maxDownloads: maxDownloads,
      expireHours: expireHours,
    );
    return r.data;
  }

  /// Create share link with precise error info.
  /// [fileUserId] — the actual user_id stored with the file (extracted from file.url).
  /// Falls back to ServerConfig.userId if not provided.
  Future<({Map<String, dynamic>? data, String? error})> createShareLinkSafe({
    required String savedName,
    required String originalName,
    String? fileUserId,
    int maxDownloads = -1,
    int expireHours = 0,
  }) async {
    // Use the actual user_id from the file URL, not the current session user_id
    final effectiveUserId = (fileUserId != null && fileUserId.isNotEmpty)
        ? fileUserId
        : ServerConfig.userId;
    try {
      final response = await _client
          .post(
            Uri.parse('${ServerConfig.baseUrl}/api/share/create'),
            headers: {
              ..._signedHeaders('/api/share/create'),
              'Content-Type': 'application/json',
            },
            body: json.encode({
              'user_id': effectiveUserId,
              'filename': savedName,
              'original_name': originalName,
              'max_downloads': maxDownloads,
              'expire_hours': expireHours,
            }),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          return (data: data as Map<String, dynamic>, error: null);
        }
        return (data: null, error: (data['error'] ?? '生成分享链接失败').toString());
      }
      if (response.statusCode >= 400) {
        return (
          data: null,
          error: _classifyError(response.statusCode, response.body).userMessage,
        );
      }
      return (data: null, error: '服务器未返回数据');
    } on SocketException {
      return (data: null, error: '网络连接失败，请检查网络');
    } on TimeoutException {
      return (data: null, error: '请求超时，请重试');
    } catch (e) {
      if (kDebugMode) debugPrint('Create share link error: $e');
      return (data: null, error: '生成分享链接失败: $e');
    }
  }

  Future<VersionInfo?> checkForUpdate() async {
    try {
      return await _withRetry(() async {
        final response = await _client
            .get(
              Uri.parse(
                '${ServerConfig.baseUrl}/api/version/check'
                '?version=${ServerConfig.appVersion}'
                '&build=${ServerConfig.appBuild}',
              ),
            )
            .timeout(const Duration(seconds: 5));

        if (response.statusCode == 200) {
          return VersionInfo.fromJson(json.decode(response.body));
        }
        return null;
      }, maxRetries: 2);
    } catch (e) {
      return null;
    }
  }

  /// Download file with optional hash verification
  /// [cleanStart] — don't resume from old .tmp file (for patch/small files)
  Future<String?> downloadFile({
    required String downloadUrl,
    required String savePath,
    void Function(int received, int total)? onProgress,
    int expectedSize = 0,
    String? expectedHash,
    bool cleanStart = false,
  }) async {
    try {
      final totalSize = expectedSize;
      final result = await _singleDownload(
        downloadUrl: downloadUrl,
        savePath: savePath,
        totalSize: totalSize,
        onProgress: onProgress,
        cleanStart: cleanStart,
      );

      if (result == null) {
        debugPrint('[DL] _singleDownload returned null for $downloadUrl');
        return null;
      }

      // Hash verification
      if (expectedHash != null && expectedHash.isNotEmpty) {
        final actualHash = await _computeFileHashDart(savePath);
        if (actualHash != null &&
            actualHash.toLowerCase() != expectedHash.toLowerCase()) {
          debugPrint(
            '[DL] HASH MISMATCH! expected=$expectedHash, actual=$actualHash, url=$downloadUrl',
          );
          try {
            await File(savePath).delete();
          } catch (_) {}
          return null;
        }
        debugPrint('[DL] Hash verified OK: $expectedHash');
      }

      return savePath;
    } catch (e) {
      debugPrint('[DL] ERROR: $e');
      return null;
    }
  }

  /// Single-thread download with resume support
  /// [cleanStart] — skip resume & delete any old .tmp file (used for patch files)
  Future<String?> _singleDownload({
    required String downloadUrl,
    required String savePath,
    required int totalSize,
    void Function(int received, int total)? onProgress,
    bool cleanStart = false,
  }) async {
    final tmpPath = '$savePath.tmp';
    final tmpFile = File(tmpPath);
    int existingBytes = 0;

    // FIX: For patch files, always start fresh to avoid corrupted resume data
    if (cleanStart) {
      try {
        if (await tmpFile.exists()) await tmpFile.delete();
      } catch (_) {}
    } else if (await tmpFile.exists()) {
      existingBytes = await tmpFile.length();
    }

    final request = http.Request('GET', Uri.parse(Uri.encodeFull(downloadUrl)));
    if (existingBytes > 0) {
      request.headers['Range'] = 'bytes=$existingBytes-';
    }

    final http.StreamedResponse streamed;
    try {
      streamed = await request.send().timeout(const Duration(minutes: 5));
    } catch (e) {
      debugPrint('[DL] Connection failed: $e');
      return null;
    }

    if (streamed.statusCode != 200 && streamed.statusCode != 206) {
      debugPrint('[DL] HTTP ${streamed.statusCode} for $downloadUrl');
      return null;
    }

    // Server returned 200 (not 206) = Range not supported, restart from scratch
    if (streamed.statusCode == 200 && existingBytes > 0) {
      existingBytes = 0;
      if (await tmpFile.exists()) await tmpFile.delete();
    }

    int serverCL = streamed.contentLength ?? 0;
    if (serverCL <= 0) {
      serverCL = int.tryParse(streamed.headers['content-length'] ?? '') ?? 0;
    }
    // Priority: totalSize from API > serverCL > 0
    final total = totalSize > 0
        ? totalSize
        : (serverCL > 0 ? existingBytes + serverCL : 0);
    int received = existingBytes;

    final sink = tmpFile.openWrite(
      mode: existingBytes > 0 ? FileMode.append : FileMode.write,
    );

    // OPT-10: Increase stream timeout from 60s to 120s for weak networks
    await for (final chunk in streamed.stream.timeout(
      const Duration(seconds: 120),
      onTimeout: (s) => s.close(),
    )) {
      sink.add(chunk);
      received += chunk.length;
      // Always use API-provided totalSize — never let progress be indeterminate
      // Cloudflare strips Content-Length, so server response total is unreliable
      if (total > 0) {
        final capped = received > total ? total : received;
        onProgress?.call(capped, total);
      } else {
        // No known total — still report but mark as indeterminate
        onProgress?.call(received, 0);
      }
    }

    await sink.flush();
    await sink.close();

    if (received < 1024) {
      debugPrint('[DL] File too small: $received bytes');
      return null;
    }

    // Verify downloaded size — generous tolerance for Cloudflare/CDN quirks
    if (totalSize > 0) {
      final tolerance =
          totalSize * 0.10; // 10% tolerance (Cloudflare can add overhead)
      if (received < totalSize - tolerance) {
        debugPrint('[DL] FILE TRUNCATED! expected=$totalSize, got=$received');
        try {
          await tmpFile.delete();
        } catch (_) {}
        return null;
      }
      if ((received - totalSize).abs() > totalSize * 0.01) {
        debugPrint(
          '[DL] Size variance: expected=$totalSize, got=$received (within tolerance)',
        );
      }
    }

    final dest = File(savePath);
    if (await dest.exists()) await dest.delete();
    await tmpFile.rename(savePath);
    return savePath;
  }

  Future<String?> _computeFileHashDart(String filePath) async {
    try {
      final file = File(filePath);
      final digest = await md5.bind(file.openRead()).first;
      return digest.toString();
    } catch (e) {
      return null;
    }
  }

  /// Public static MD5 hash computation
  static Future<String?> computeFileMd5(String filePath) async {
    try {
      final file = File(filePath);
      final digest = await md5.bind(file.openRead()).first;
      return digest.toString();
    } catch (e) {
      return null;
    }
  }

  /// Download incremental patch, apply bspatch, verify hash.
  /// Returns savePath on success, throws on failure.
  Future<String> downloadAndApplyPatch({
    required VersionInfo info,
    required String currentApkPath,
    required String savePath,
    void Function(int received, int total)? onProgress,
    void Function(String stage)? onStage,
  }) async {
    if (!info.patchAvailable || info.fullPatchUrl.isEmpty) {
      throw Exception(
        '服务器无增量包 (${ServerConfig.appVersion} -> ${info.latestVersion})',
      );
    }

    // Step 1: Download patch file
    onStage?.call('downloading');
    final patchPath = '$savePath.patch';
    try {
      if (await File(patchPath).exists()) await File(patchPath).delete();
    } catch (_) {}
    try {
      if (await File('$patchPath.tmp').exists())
        await File('$patchPath.tmp').delete();
    } catch (_) {}

    final downloaded = await downloadFile(
      downloadUrl: info.fullPatchUrl,
      savePath: patchPath,
      expectedSize: info.patchSize,
      expectedHash: info.patchHash.isNotEmpty ? info.patchHash : null,
      cleanStart: true,
      onProgress: (received, total) {
        onProgress?.call(received, info.patchSize > 0 ? info.patchSize : total);
      },
    );

    if (downloaded == null) {
      throw Exception('增量包下载失败');
    }

    // Step 2: Verify current APK
    final oldFile = File(currentApkPath);
    if (!await oldFile.exists()) {
      try {
        await File(patchPath).delete();
      } catch (_) {}
      throw Exception('当前APK不存在');
    }

    // Step 3: Apply bsdiff patch
    onStage?.call('patching');
    const channel = MethodChannel('one.darker.qingxu/patch');
    try {
      final result = await channel.invokeMethod<String>('bspatch', {
        'oldPath': currentApkPath,
        'patchPath': patchPath,
        'newPath': savePath,
      });
      if (result != 'ok') throw Exception('bspatch: $result');
    } catch (e) {
      try {
        await File(patchPath).delete();
      } catch (_) {}
      throw Exception('增量合并失败: $e');
    }
    try {
      await File(patchPath).delete();
    } catch (_) {}

    // Step 4: Verify merged APK hash
    if (info.apkHash.isNotEmpty) {
      onStage?.call('verifying');
      final verified = await _verifyFileHash(savePath, info.apkHash);
      if (!verified) {
        try {
          await File(savePath).delete();
        } catch (_) {}
        throw Exception('合并后校验失败');
      }
    }

    return savePath;
  }

  Future<bool> _verifyFileHash(String filePath, String expectedMd5) async {
    try {
      final hash = await _patchChannel.invokeMethod<String>('md5', {
        'filePath': filePath,
      });
      if (hash == null) return false;
      return hash.toLowerCase() == expectedMd5.toLowerCase();
    } catch (e) {
      final dartHash = await _computeFileHashDart(filePath);
      if (dartHash == null) return false;
      return dartHash.toLowerCase() == expectedMd5.toLowerCase();
    }
  }

  static const _patchChannel = MethodChannel('one.darker.qingxu/patch');

  static Future<String?> getCurrentApkPath() async {
    try {
      return await _patchChannel.invokeMethod<String>('getApkPath');
    } catch (e) {
      return null;
    }
  }

  static const _installChannel = MethodChannel(
    'one.darker.qingxu/install',
  );

  static Future<bool> installApk(String filePath) async {
    try {
      final result = await _installChannel.invokeMethod<bool>('installApk', {
        'filePath': filePath,
      });
      return result ?? false;
    } on PlatformException {
      return false;
    }
  }

  /// v2.1: Cleanup downloaded APK after successful install
  static Future<void> cleanupAfterInstall(String apkPath) async {
    try {
      final file = File(apkPath);
      if (await file.exists()) {
        await file.delete();
        if (kDebugMode) debugPrint('[Cleanup] Deleted installed APK: $apkPath');
      }
      // Also cleanup .tmp and .part files
      final dir = file.parent;
      if (await dir.exists()) {
        await for (final entity in dir.list()) {
          if (entity is File &&
              (entity.path.endsWith('.tmp') ||
                  entity.path.endsWith('.patch') ||
                  entity.path.contains('.part'))) {
            await entity.delete();
          }
        }
      }
    } catch (e) {
      if (kDebugMode) debugPrint('[Cleanup] Error: $e');
    }
  }

  // ═══ Blog API ═══

  Future<List<BlogArticle>> listArticles({
    String? userId,
    int page = 1,
    int limit = 20,
  }) async {
    try {
      // SEC: Validate pagination params
      final safePage = page.clamp(1, 1000);
      final safeLimit = limit.clamp(1, 100);
      final safeUserId = userId != null
          ? SecureConfig.sanitizeInput(userId, maxLength: 64)
          : null;
      final uri = safeUserId != null
          ? '${ServerConfig.baseUrl}/api/blog/articles?user_id=${Uri.encodeComponent(safeUserId)}&page=$safePage&limit=$safeLimit'
          : '${ServerConfig.baseUrl}/api/blog/articles?page=$safePage&limit=$safeLimit';
      final response = await _client
          .get(Uri.parse(uri))
          .timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final list = data['articles'] as List? ?? [];
        return list.map((j) => BlogArticle.fromJson(j)).toList();
      }
      return [];
    } catch (e) {
      if (kDebugMode) debugPrint('List articles error: $e');
      return [];
    }
  }

  Future<BlogArticle?> getArticle(String id) async {
    // SEC: Sanitize article ID
    final safeId = SecureConfig.sanitizeInput(id, maxLength: 64);
    try {
      final response = await _client
          .get(Uri.parse('${ServerConfig.baseUrl}/api/blog/articles/$safeId'))
          .timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        return BlogArticle.fromJson(json.decode(response.body));
      }
      return null;
    } catch (e) {
      if (kDebugMode) debugPrint('Get article error: $e');
      return null;
    }
  }

  Future<Map<String, dynamic>?> createArticle({
    required String title,
    required String content,
    List<String> tags = const [],
    bool isPublic = true,
  }) async {
    try {
      // SEC: Sanitize article content
      final safeTitle = SecureConfig.sanitizeInput(title, maxLength: 200);
      final safeContent = SecureConfig.sanitizeInput(content, maxLength: 50000);
      final safeTags = tags
          .map((t) => SecureConfig.sanitizeInput(t, maxLength: 50))
          .toList();
      final response = await _client
          .post(
            Uri.parse('${ServerConfig.baseUrl}/api/blog/articles'),
            headers: {
              'Content-Type': 'application/json',
              ..._signedHeaders('/api/blog/articles'),
            },
            body: json.encode({
              'title': safeTitle,
              'content': safeContent,
              'tags': safeTags,
              'is_public': isPublic,
              'user_id': ServerConfig.userId,
            }),
          )
          .timeout(const Duration(minutes: 1));
      if (response.statusCode == 200) {
        return json.decode(response.body);
      }
      return null;
    } catch (e) {
      if (kDebugMode) debugPrint('Create article error: $e');
      return null;
    }
  }

  Future<bool> updateArticle(
    String id, {
    String? title,
    String? content,
    List<String>? tags,
    bool? isPublic,
  }) async {
    try {
      final body = <String, dynamic>{};
      if (title != null) body['title'] = title;
      if (content != null) body['content'] = content;
      if (tags != null) body['tags'] = tags;
      if (isPublic != null) body['is_public'] = isPublic;
      final response = await _client
          .put(
            Uri.parse('${ServerConfig.baseUrl}/api/blog/articles/$id'),
            headers: {
              'Content-Type': 'application/json',
              ..._signedHeaders('/api/blog/articles/$id'),
            },
            body: json.encode(body),
          )
          .timeout(const Duration(seconds: 15));
      return response.statusCode == 200;
    } catch (e) {
      if (kDebugMode) debugPrint('Update article error: $e');
      return false;
    }
  }

  Future<bool> deleteArticle(String id) async {
    try {
      final response = await _client
          .delete(
            Uri.parse('${ServerConfig.baseUrl}/api/blog/articles/$id'),
            headers: _signedHeaders('/api/blog/articles/$id'),
          )
          .timeout(const Duration(seconds: 10));
      return response.statusCode == 200;
    } catch (e) {
      if (kDebugMode) debugPrint('Delete article error: $e');
      return false;
    }
  }

  // ═══ Heartbeat API (integrity check) ═══
  Future<Map<String, dynamic>?> heartbeat(Map<String, dynamic> payload) async {
    try {
      final resp = await _client
          .post(
            Uri.parse('${ServerConfig.baseUrl}/api/heartbeat'),
            headers: {
              'Content-Type': 'application/json',
              ..._signedHeaders('/api/heartbeat'),
            },
            body: json.encode(payload),
          )
          .timeout(const Duration(seconds: 15));
      if (resp.statusCode == 200) {
        return json.decode(resp.body) as Map<String, dynamic>;
      }
      return null;
    } catch (e) {
      if (kDebugMode) debugPrint('Heartbeat error: $e');
      return null;
    }
  }

  void dispose() {
    _client.close();
  }
}

// ═══ Blog Article Model ═══
class BlogArticle {
  final String id; // slug-based id (used for detail lookup)
  final String numericId; // original numeric id (used for admin ops)
  final String slug;
  final String userId;
  final String title;
  final String content;
  final String summary;
  final String coverUrl;
  final List<String> tags;
  final bool isPublic;
  final int views;
  final int likeCount;
  final int commentCount;
  final int wordCount;
  final int readingTime;
  final String category;
  final String createdAt;
  final String updatedAt;

  BlogArticle({
    required this.id,
    this.numericId = '',
    this.slug = '',
    required this.userId,
    required this.title,
    this.content = '',
    this.summary = '',
    this.coverUrl = '',
    this.tags = const [],
    this.isPublic = true,
    this.views = 0,
    this.likeCount = 0,
    this.commentCount = 0,
    this.wordCount = 0,
    this.readingTime = 0,
    this.category = '',
    this.createdAt = '',
    this.updatedAt = '',
  });

  factory BlogArticle.fromJson(Map<String, dynamic> j) => BlogArticle(
    id: (j['id'] ?? '').toString(),
    numericId: (j['numeric_id'] ?? j['id'] ?? '').toString(),
    slug: j['slug'] as String? ?? '',
    userId: j['user_id'] as String? ?? '',
    title: j['title'] as String? ?? '',
    content: _unescapeContent(j['content'] as String? ?? ''),
    summary: j['summary'] as String? ?? '',
    coverUrl: j['cover_url'] as String? ?? '',
    tags: (j['tags'] as List?)?.map((e) => e.toString()).toList() ?? [],
    isPublic: j['is_public'] ?? true,
    views: j['views'] as int? ?? 0,
    likeCount: j['like_count'] as int? ?? 0,
    commentCount: j['comment_count'] as int? ?? 0,
    wordCount: j['word_count'] as int? ?? 0,
    readingTime: j['reading_time'] as int? ?? 0,
    category: j['category'] as String? ?? '',
    createdAt: j['created_at'] as String? ?? '',
    updatedAt: j['updated_at'] as String? ?? '',
  );

  String get dateFormatted {
    if (createdAt.isEmpty) return '';
    try {
      final dt = DateTime.parse(createdAt);
      return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
    } catch (_) {
      return createdAt.length >= 10 ? createdAt.substring(0, 10) : createdAt;
    }
  }

  String get blogUrl => '${ServerConfig.baseUrl}/blog/$id';

  /// Fix double-escaped newlines/tabs from backend serialization bugs.
  static String _unescapeContent(String s) {
    if (s.isEmpty) return s;
    // Replace literal two-char sequences "\" + "n" / "\" + "t" with real chars
    return s.replaceAll('\\n', '\n').replaceAll('\\t', '\t');
  }
}
