import 'dart:async';
import 'dart:io';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'api_service.dart';

/// Background update checker v5 — Incremental + Full Fallback
///
/// - Wi-Fi: try incremental patch first, fallback to full APK download
/// - Cellular: notify only
/// - Retry with backoff on failure
class UpdateChecker {
  static final UpdateChecker _instance = UpdateChecker._internal();
  factory UpdateChecker() => _instance;
  UpdateChecker._internal();

  Timer? _timer;
  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();
  bool _initialized = false;
  VersionInfo? _lastVersionInfo;
  bool _isWifi = false;

  UpdateState _state = UpdateState.idle;
  String? _downloadingVersion;
  double _downloadProgress = 0;
  bool _cancelRequested = false;
  double _downloadSpeed = 0;
  int _downloadedBytes = 0;
  int _totalBytes = 0;
  int _estimatedSecondsLeft = 0;

  UpdateState get state => _state;
  double get downloadProgress => _downloadProgress;
  String? get downloadingVersion => _downloadingVersion;
  double get downloadSpeed => _downloadSpeed;
  int get downloadedBytes => _downloadedBytes;
  int get totalBytes => _totalBytes;
  int get estimatedSecondsLeft => _estimatedSecondsLeft;

  // Callbacks
  static void Function(String version)? onUpdateTapped;
  static void Function(
    UpdateState state, {
    String? version,
    double? progress,
    double? speed,
    int? eta,
  })?
  onStateChanged;

  // Keys
  static const String _lastCheckKey = 'last_update_check';
  static const String _dismissedVersionKey = 'dismissed_version';
  static const String _pendingApkKey = 'pending_apk_path';
  static const String _pendingVersionKey = 'pending_apk_version';

  // Intervals
  static const Duration _wifiCheckInterval = Duration(hours: 2);
  static const Duration _cellularCheckInterval = Duration(hours: 6);
  static const Duration _initialDelay = Duration(seconds: 10);
  static const Duration _throttleInterval = Duration(minutes: 30);

  static const int _maxRetries = 3;

  // Notification IDs
  static const int _updateNotifyId = 1001;
  static const int _progressNotifyId = 1002;
  static const int _readyNotifyId = 1003;

  bool get isWifi => _isWifi;
  VersionInfo? get cachedVersionInfo => _lastVersionInfo;

  int _speedTrackStart = 0;
  int _speedTrackBytes = 0;

  Future<void> init() async {
    if (_initialized) return;

    await _updateNetworkType();

    Connectivity().onConnectivityChanged.listen((results) {
      final wasWifi = _isWifi;
      _isWifi = results.any((r) => r == ConnectivityResult.wifi);
      if (_isWifi && !wasWifi) {
        _startPeriodicCheck();
        if (_state == UpdateState.idle &&
            _lastVersionInfo != null &&
            _lastVersionInfo!.hasUpdate) {
          checkNow();
        }
      } else if (!_isWifi && wasWifi) {
        _startPeriodicCheck();
      }
    });

    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );
    const initSettings = InitializationSettings(android: androidSettings);
    await _notifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );

    if (Platform.isAndroid) {
      final android = _notifications
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      await android?.requestNotificationsPermission();
    }

    _initialized = true;

    await _checkPendingInstall();

    Future.delayed(_initialDelay, () => checkNow());
    _startPeriodicCheck();
    _cleanupOldFiles();
  }

  Future<void> _checkPendingInstall() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final pendingPath = prefs.getString(_pendingApkKey);
      final pendingVersion = prefs.getString(_pendingVersionKey);
      if (pendingPath != null && pendingVersion != null) {
        final file = File(pendingPath);
        if (await file.exists() && await file.length() > 1024) {
          _setState(UpdateState.ready, version: pendingVersion);
          _showReadyNotification(pendingVersion);
          return;
        }
        await prefs.remove(_pendingApkKey);
        await prefs.remove(_pendingVersionKey);
      }
    } catch (_) {}
  }

  Future<void> _updateNetworkType() async {
    try {
      final results = await Connectivity().checkConnectivity();
      _isWifi = results.any((r) => r == ConnectivityResult.wifi);
    } catch (_) {
      _isWifi = false;
    }
  }

  void _startPeriodicCheck() {
    _timer?.cancel();
    final interval = _isWifi ? _wifiCheckInterval : _cellularCheckInterval;
    _timer = Timer.periodic(interval, (_) => checkNow());
  }

  void _setState(
    UpdateState newState, {
    String? version,
    double? progress,
    double? speed,
    int? eta,
  }) {
    _state = newState;
    if (version != null) _downloadingVersion = version;
    if (progress != null) _downloadProgress = progress;
    if (speed != null) _downloadSpeed = speed;
    if (eta != null) _estimatedSecondsLeft = eta;
    onStateChanged?.call(
      newState,
      version: _downloadingVersion,
      progress: _downloadProgress,
      speed: _downloadSpeed,
      eta: _estimatedSecondsLeft,
    );
  }

  void _updateSpeedAndEta(int receivedBytes, int totalBytes) {
    final now = DateTime.now().millisecondsSinceEpoch;
    if (_speedTrackStart == 0) {
      _speedTrackStart = now;
      _speedTrackBytes = receivedBytes;
      return;
    }
    final elapsed = (now - _speedTrackStart) / 1000.0;
    if (elapsed < 0.5) return;
    final bytesInPeriod = receivedBytes - _speedTrackBytes;
    _downloadSpeed = bytesInPeriod / elapsed;
    _downloadedBytes = receivedBytes;
    _totalBytes = totalBytes;
    if (_downloadSpeed > 0 && totalBytes > 0) {
      final remaining = totalBytes - receivedBytes;
      _estimatedSecondsLeft = (remaining / _downloadSpeed).ceil();
    }
    _speedTrackStart = now;
    _speedTrackBytes = receivedBytes;
  }

  String get speedFormatted {
    if (_downloadSpeed <= 0) return '';
    if (_downloadSpeed > 1024 * 1024) {
      return '${(_downloadSpeed / (1024 * 1024)).toStringAsFixed(1)} MB/s';
    }
    return '${(_downloadSpeed / 1024).toStringAsFixed(0)} KB/s';
  }

  String get etaFormatted {
    if (_estimatedSecondsLeft <= 0) return '';
    if (_estimatedSecondsLeft > 3600) {
      return '${_estimatedSecondsLeft ~/ 3600}h ${(_estimatedSecondsLeft % 3600) ~/ 60}m';
    }
    if (_estimatedSecondsLeft > 60) {
      return '${_estimatedSecondsLeft ~/ 60}m ${_estimatedSecondsLeft % 60}s';
    }
    return '${_estimatedSecondsLeft}s';
  }

  Future<VersionInfo?> checkNow({bool force = false}) async {
    if (_state == UpdateState.downloading) return _lastVersionInfo;

    try {
      _setState(UpdateState.checking);
      final prefs = await SharedPreferences.getInstance();

      if (!force) {
        final lastCheck = prefs.getInt(_lastCheckKey) ?? 0;
        final now = DateTime.now().millisecondsSinceEpoch;
        if (now - lastCheck < _throttleInterval.inMilliseconds) {
          _setState(UpdateState.idle);
          return _lastVersionInfo;
        }
      }

      final versionInfo = await ApiService().checkForUpdate();
      if (versionInfo == null) {
        _setState(UpdateState.idle);
        return null;
      }

      _lastVersionInfo = versionInfo;
      await prefs.setInt(_lastCheckKey, DateTime.now().millisecondsSinceEpoch);

      if (!versionInfo.hasUpdate) {
        _setState(UpdateState.idle);
        return versionInfo;
      }

      // Skip dismissed (unless forced)
      if (!versionInfo.forceUpdate && !force) {
        final dismissed = prefs.getString(_dismissedVersionKey) ?? '';
        if (dismissed == versionInfo.latestVersion) {
          _setState(UpdateState.idle);
          return versionInfo;
        }
      }

      // Wi-Fi: try incremental first, fallback to full download
      if (_isWifi && !versionInfo.forceUpdate) {
        if (versionInfo.patchAvailable) {
          await _silentPatchUpdate(versionInfo);
        } else if (versionInfo.fullDownloadUrl.isNotEmpty) {
          // No patch available, download full APK directly
          final savePath = await getApkSavePath();
          await _fullApkDownload(versionInfo, savePath);
        } else {
          await _showUpdateNotification(versionInfo);
          _setState(UpdateState.idle);
        }
      } else {
        await _showUpdateNotification(versionInfo);
        _setState(UpdateState.idle);
      }

      return versionInfo;
    } catch (e) {
      if (kDebugMode) debugPrint('UpdateChecker error: $e');
      _setState(UpdateState.idle);
      return null;
    }
  }

  /// Key for saved baseline APK path (used as bspatch old file)
  static const String _baselineApkKey = 'baseline_apk_path';
  static const String _baselineVersionKey = 'baseline_apk_version';

  /// Get baseline APK for patching:
  /// 1. Saved baseline copy (guaranteed matches server hash)
  /// 2. System APK + hash check against server
  /// 3. Download current version from server as baseline
  Future<String?> _getBaselineApkPath(VersionInfo info) async {
    final prefs = await SharedPreferences.getInstance();

    // 1. Check saved baseline
    final baselinePath = prefs.getString(_baselineApkKey);
    final baselineVer = prefs.getString(_baselineVersionKey);
    if (baselinePath != null &&
        baselineVer == ServerConfig.appVersion &&
        await File(baselinePath).exists()) {
      if (kDebugMode)
        debugPrint('UpdateChecker: using saved baseline v$baselineVer');
      return baselinePath;
    }

    // 2. Try system APK, verify hash with server
    final sysPath = await ApiService.getCurrentApkPath();
    if (sysPath != null) {
      // Ask server for current version's hash
      final currentHash = await _getCurrentVersionHash();
      if (currentHash != null) {
        final sysHash = await _computeMd5(sysPath);
        if (sysHash == currentHash) {
          if (kDebugMode)
            debugPrint('UpdateChecker: system APK hash matches server');
          // Save as baseline for next time
          await _saveBaseline(sysPath, ServerConfig.appVersion);
          return sysPath;
        }
        if (kDebugMode)
          debugPrint(
            'UpdateChecker: system APK hash mismatch! sys=$sysHash server=$currentHash',
          );
      } else {
        // Can't verify, use system APK as-is
        if (kDebugMode)
          debugPrint(
            'UpdateChecker: no server hash to verify, using system APK',
          );
        return sysPath;
      }
    }

    // 3. Download current version APK from server as baseline
    if (kDebugMode)
      debugPrint('UpdateChecker: downloading current version APK as baseline');
    try {
      final dir = await getExternalStorageDirectory();
      if (dir == null) return sysPath;
      final baselineDir = Directory('${dir.path}/baseline');
      if (!await baselineDir.exists())
        await baselineDir.create(recursive: true);
      final dlPath =
          '${baselineDir.path}/tempo_v${ServerConfig.appVersion}.apk';

      final currentDlUrl =
          '/api/release/download/tempo_v${ServerConfig.appVersion}_b${ServerConfig.appBuild}.apk';
      final downloaded = await ApiService().downloadFile(
        downloadUrl: ServerConfig.fullDownloadUrl(currentDlUrl),
        savePath: dlPath,
        cleanStart: true,
      );
      if (downloaded != null) {
        await prefs.setString(_baselineApkKey, dlPath);
        await prefs.setString(_baselineVersionKey, ServerConfig.appVersion);
        if (kDebugMode)
          debugPrint('UpdateChecker: baseline downloaded: $dlPath');
        return dlPath;
      }
    } catch (e) {
      if (kDebugMode) debugPrint('UpdateChecker: baseline download failed: $e');
    }

    return sysPath; // Last resort
  }

  /// Get current version's APK hash from server
  Future<String?> _getCurrentVersionHash() async {
    try {
      // Check version with a build-1 to get current version info
      final resp = await ApiService().checkForUpdate();
      // If server says current version IS the latest, use apk_hash from response
      if (resp != null && resp.latestVersion == ServerConfig.appVersion) {
        return resp.apkHash.isNotEmpty ? resp.apkHash : null;
      }
      // If there's an update, server won't give us current version hash directly
      // Use a separate check: query with version=0.0.0 to always get latest, then
      // we need current version hash. Server doesn't provide that directly.
      // Alternative: download and hash. But that's what step 3 does.
      return null;
    } catch (_) {
      return null;
    }
  }

  /// Compute MD5 hash of a file
  Future<String?> _computeMd5(String filePath) async {
    try {
      return await ApiService.computeFileMd5(filePath);
    } catch (_) {
      return null;
    }
  }

  /// Save the successfully patched/installed APK as baseline for next update
  Future<void> _saveBaseline(String apkPath, String version) async {
    try {
      final dir = await getExternalStorageDirectory();
      if (dir == null) return;
      final baselineDir = Directory('${dir.path}/baseline');
      if (!await baselineDir.exists())
        await baselineDir.create(recursive: true);
      final baselinePath = '${baselineDir.path}/tempo_v$version.apk';
      await File(apkPath).copy(baselinePath);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_baselineApkKey, baselinePath);
      await prefs.setString(_baselineVersionKey, version);
      // Clean old baselines
      await for (final f in baselineDir.list()) {
        if (f is File && f.path != baselinePath) {
          try {
            await f.delete();
          } catch (_) {}
        }
      }
      if (kDebugMode) debugPrint('UpdateChecker: saved baseline $baselinePath');
    } catch (e) {
      if (kDebugMode) debugPrint('UpdateChecker: save baseline failed: $e');
    }
  }

  /// Silent incremental update on Wi-Fi
  Future<void> _silentPatchUpdate(VersionInfo info) async {
    if (_state == UpdateState.downloading) return;
    if (!info.patchAvailable) return;

    _cancelRequested = false;
    _speedTrackStart = 0;
    _speedTrackBytes = 0;
    _downloadSpeed = 0;
    _estimatedSecondsLeft = 0;
    _setState(
      UpdateState.downloading,
      version: info.latestVersion,
      progress: 0,
    );

    final savePath = await getApkSavePath();
    final currentApkPath = await _getBaselineApkPath(info);
    if (currentApkPath == null) {
      _setState(UpdateState.idle);
      return;
    }

    for (int attempt = 1; attempt <= _maxRetries; attempt++) {
      if (_cancelRequested) break;

      try {
        await _showProgressNotification(0, info.latestVersion);

        final result = await ApiService().downloadAndApplyPatch(
          info: info,
          currentApkPath: currentApkPath,
          savePath: savePath,
          onProgress: (received, total) {
            if (_cancelRequested) return;
            final effectiveTotal = info.patchSize > 0 ? info.patchSize : total;
            final pct = effectiveTotal > 0
                ? (received / effectiveTotal).clamp(0.0, 1.0)
                : 0.0;
            _downloadProgress = pct * 0.85;
            _updateSpeedAndEta(received, effectiveTotal);
            _showProgressNotification(_downloadProgress, info.latestVersion);
          },
          onStage: (stage) {
            if (_cancelRequested) return;
            switch (stage) {
              case 'patching':
                _downloadProgress = 0.90;
                break;
              case 'verifying':
                _downloadProgress = 0.95;
                break;
            }
            _showProgressNotification(_downloadProgress, info.latestVersion);
          },
        );

        await _notifications.cancel(_progressNotifyId);

        if (_cancelRequested) {
          _setState(UpdateState.idle);
          return;
        }

        // Success — save baseline for next update, then install
        await _saveBaseline(result, info.latestVersion);

        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_pendingApkKey, savePath);
        await prefs.setString(_pendingVersionKey, info.latestVersion);

        _setState(UpdateState.ready, version: info.latestVersion, progress: 1);

        bool installed = false;
        try {
          installed = await ApiService.installApk(result);
        } catch (_) {}

        if (!installed) {
          await _showReadyNotification(info.latestVersion);
        } else {
          await prefs.remove(_pendingApkKey);
          await prefs.remove(_pendingVersionKey);
          _setState(UpdateState.idle);
        }
        return;
      } catch (e) {
        await _notifications.cancel(_progressNotifyId);
        if (kDebugMode)
          debugPrint('Silent patch error (attempt $attempt/$_maxRetries): $e');
        if (attempt < _maxRetries) {
          await Future.delayed(Duration(seconds: 5 * (1 << (attempt - 1))));
          await _updateNetworkType();
          if (!_isWifi) break;
        }
      }
    }

    // Incremental failed after all retries — fallback to full APK download
    if (!_cancelRequested && info.fullDownloadUrl.isNotEmpty) {
      if (kDebugMode)
        debugPrint(
          'UpdateChecker: patch failed, falling back to full APK download',
        );
      await _fullApkDownload(info, savePath);
      return;
    }

    _setState(UpdateState.idle);
  }

  /// Full APK download fallback when incremental update fails
  Future<void> _fullApkDownload(VersionInfo info, String savePath) async {
    if (_cancelRequested) {
      _setState(UpdateState.idle);
      return;
    }

    _speedTrackStart = 0;
    _speedTrackBytes = 0;
    _downloadSpeed = 0;
    _estimatedSecondsLeft = 0;
    _setState(
      UpdateState.downloading,
      version: info.latestVersion,
      progress: 0,
    );

    try {
      await _showProgressNotification(0, info.latestVersion);

      final downloaded = await ApiService().downloadFile(
        downloadUrl: info.fullDownloadUrl,
        savePath: savePath,
        expectedSize: info.apkSize,
        expectedHash: info.apkHash.isNotEmpty ? info.apkHash : null,
        cleanStart: true,
        onProgress: (received, total) {
          if (_cancelRequested) return;
          final effectiveTotal = info.apkSize > 0 ? info.apkSize : total;
          final pct = effectiveTotal > 0
              ? (received / effectiveTotal).clamp(0.0, 1.0)
              : 0.0;
          _downloadProgress = pct;
          _updateSpeedAndEta(received, effectiveTotal);
          _showProgressNotification(pct, info.latestVersion);
        },
      );

      await _notifications.cancel(_progressNotifyId);

      if (_cancelRequested || downloaded == null) {
        _setState(UpdateState.idle);
        return;
      }

      // Save as baseline for next update
      await _saveBaseline(savePath, info.latestVersion);

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_pendingApkKey, savePath);
      await prefs.setString(_pendingVersionKey, info.latestVersion);

      _setState(UpdateState.ready, version: info.latestVersion, progress: 1);

      bool installed = false;
      try {
        installed = await ApiService.installApk(savePath);
      } catch (_) {}

      if (!installed) {
        await _showReadyNotification(info.latestVersion);
      } else {
        await prefs.remove(_pendingApkKey);
        await prefs.remove(_pendingVersionKey);
        _setState(UpdateState.idle);
      }
    } catch (e) {
      await _notifications.cancel(_progressNotifyId);
      if (kDebugMode) debugPrint('Full APK download failed: $e');
      _setState(UpdateState.idle);
    }
  }

  void cancelDownload() {
    _cancelRequested = true;
    _notifications.cancel(_progressNotifyId);
    _downloadSpeed = 0;
    _estimatedSecondsLeft = 0;
    _setState(UpdateState.idle);
  }

  Future<bool> installPendingUpdate() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final path = prefs.getString(_pendingApkKey);
      if (path == null) return false;
      final file = File(path);
      if (!await file.exists()) return false;
      _setState(UpdateState.installing);
      final installed = await ApiService.installApk(path);
      if (installed) {
        await prefs.remove(_pendingApkKey);
        await prefs.remove(_pendingVersionKey);
        _setState(UpdateState.idle);
      }
      return installed;
    } catch (e) {
      _setState(UpdateState.ready);
      return false;
    }
  }

  // ==========================================
  // Notifications
  // ==========================================

  Future<void> _showProgressNotification(
    double progress,
    String version,
  ) async {
    final pct = (progress * 100).clamp(0, 100).toInt();
    final speedText = speedFormatted;
    final etaText = etaFormatted;
    final subtitle = speedText.isNotEmpty
        ? '$pct%  $speedText${etaText.isNotEmpty ? '  ~$etaText' : ''}'
        : '$pct%';

    final details = AndroidNotificationDetails(
      'download_progress',
      '下载进度',
      channelDescription: '应用更新下载进度',
      importance: Importance.low,
      priority: Priority.low,
      icon: '@mipmap/ic_launcher',
      ongoing: true,
      showProgress: true,
      maxProgress: 100,
      progress: pct,
      autoCancel: false,
      onlyAlertOnce: true,
      playSound: false,
      enableVibration: false,
    );

    await _notifications.show(
      _progressNotifyId,
      '更新 v$version',
      subtitle,
      NotificationDetails(android: details),
    );
  }

  Future<void> _showReadyNotification(String version) async {
    const details = AndroidNotificationDetails(
      'update_ready',
      '更新就绪',
      channelDescription: '下载完成，点击安装',
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
      largeIcon: DrawableResourceAndroidBitmap('@mipmap/ic_launcher'),
      autoCancel: true,
    );

    await _notifications.show(
      _readyNotifyId,
      'TEMPO v$version 已就绪',
      '点击安装更新',
      const NotificationDetails(android: details),
      payload: 'install_$version',
    );
  }

  Future<void> _showUpdateNotification(VersionInfo info) async {
    const androidDetails = AndroidNotificationDetails(
      'app_update',
      '应用更新',
      channelDescription: '应用更新通知',
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
      largeIcon: DrawableResourceAndroidBitmap('@mipmap/ic_launcher'),
      styleInformation: BigTextStyleInformation(''),
      autoCancel: true,
    );

    String subtitle;
    if (info.patchAvailable && info.patchSize > 0) {
      final patchMB = (info.patchSize / (1024 * 1024)).toStringAsFixed(1);
      subtitle =
          '${info.releaseNotes.split('\n').first}\n'
          '增量更新仅需 ${patchMB}MB (节省${info.patchSavingsPercent.toStringAsFixed(0)}%)';
    } else {
      subtitle = '${info.releaseNotes.split('\n').first}\n连接Wi-Fi后自动更新';
    }

    await _notifications.show(
      _updateNotifyId,
      'TEMPO v${info.latestVersion} 可用${info.forceUpdate ? ' (重要)' : ''}',
      subtitle,
      const NotificationDetails(android: androidDetails),
      payload: 'update_${info.latestVersion}',
    );
  }

  void _onNotificationTapped(NotificationResponse response) {
    final payload = response.payload ?? '';
    if (payload.startsWith('install_')) {
      installPendingUpdate();
    } else if (payload.startsWith('update_')) {
      final version = payload.replaceFirst('update_', '');
      onUpdateTapped?.call(version);
    }
  }

  // ==========================================
  // Utility
  // ==========================================

  Future<void> dismissVersion(String version) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_dismissedVersionKey, version);
  }

  static Future<String> getApkSavePath() async {
    if (Platform.isAndroid) {
      try {
        final cacheDir = await getExternalStorageDirectory();
        if (cacheDir != null) {
          final updateDir = Directory('${cacheDir.path}/updates');
          if (!await updateDir.exists()) {
            await updateDir.create(recursive: true);
          }
          return '${updateDir.path}/tempo_update.apk';
        }
      } catch (_) {}

      try {
        final dir = Directory('/storage/emulated/0/Download');
        if (await dir.exists()) {
          return '${dir.path}/tempo_update.apk';
        }
      } catch (_) {}

      final cacheDir = await getTemporaryDirectory();
      return '${cacheDir.path}/tempo_update.apk';
    }
    final cacheDir = await getTemporaryDirectory();
    return '${cacheDir.path}/tempo_update.apk';
  }

  Future<void> _cleanupOldFiles() async {
    try {
      if (!Platform.isAndroid) return;
      final prefs = await SharedPreferences.getInstance();
      final pendingPath = prefs.getString(_pendingApkKey);
      final cacheDir = await getExternalStorageDirectory();
      if (cacheDir != null) {
        final updateDir = Directory('${cacheDir.path}/updates');
        if (await updateDir.exists()) {
          await for (final entity in updateDir.list()) {
            if (entity is File && entity.path != pendingPath) {
              if (entity.path.endsWith('.tmp') ||
                  entity.path.endsWith('.patch') ||
                  entity.path.contains('.part')) {
                await entity.delete();
              }
              if (entity.path.endsWith('.apk')) {
                final stat = await entity.stat();
                if (DateTime.now().difference(stat.modified) >
                    const Duration(days: 3)) {
                  await entity.delete();
                }
              }
            }
          }
        }
      }
    } catch (e) {
      if (kDebugMode) debugPrint('Cleanup error: $e');
    }
  }

  void dispose() {
    _timer?.cancel();
    _timer = null;
  }
}

enum UpdateState { idle, checking, downloading, ready, installing }
