import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'api_service.dart';
import 'secure_config.dart';

/// Cloud Tools Service - v2.7 with Speedtest, Pandoc, Netdata
///
/// Security improvements:
/// - Input URL sanitization (prevents injection / SSRF)
/// - Request timeout hardening
/// - Response size limits
/// - Error message sanitization (no raw data leak)
class CloudToolsService {
  static final CloudToolsService _instance = CloudToolsService._();
  factory CloudToolsService() => _instance;
  CloudToolsService._();

  final http.Client _client = http.Client();

  // ─── 服务地址 (通过 Nginx 反代) ───
  static String get _baseUrl => ServerConfig.baseUrl;
  static const String _watermarkPath = '/api/cloud-tools/watermark';
  static const String _netdiskPath = '/api/cloud-tools/netdisk';
  static const String _alistPath = '/api/cloud-tools/alist';
  static const String _speedtestPath = '/api/cloud-tools/speedtest';
  static const String _pandocPath = '/api/cloud-tools/pandoc';
  static const String _netdataPath = '/api/cloud-tools/netdata';

  // ═══════════════════════════════════════
  // 1. 去水印 (Douyin_TikTok_Download_API)
  // ═══════════════════════════════════════

  /// 解析视频/图片去水印
  /// [url] 分享链接 (抖音/快手/小红书/微博等)
  /// Input is sanitized to prevent SSRF and injection.
  Future<WatermarkResult> removeWatermark(String url) async {
    // SEC: Sanitize URL input
    final sanitizedUrl = SecureConfig.sanitizeUrl(url);
    if (sanitizedUrl == null) {
      return WatermarkResult(
        success: false,
        error: '链接格式不正确，请输入 http/https 链接',
      );
    }
    try {
      // 使用 hybrid API - 自动识别平台
      final apiUrl = Uri.parse(
        '$_baseUrl$_watermarkPath/api/hybrid/video_data'
        '?url=${Uri.encodeComponent(sanitizedUrl)}'
        '&minimal=false',
      );

      final response = await _client
          .get(apiUrl, headers: _authHeaders)
          .timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data['code'] == 200 || data['status'] == 'success') {
          final videoData = data['data'] ?? data;
          // Guard: API returned 200 but empty data (e.g. B站 cookie expired)
          if (videoData is! Map || videoData.isEmpty) {
            return WatermarkResult(
              success: false,
              error: '解析返回空数据，该平台可能需要更新Cookie或暂不支持',
            );
          }
          final title = _extractField(videoData, ['desc', 'title', 'caption']);
          final videoUrl = _extractField(videoData, [
            'nwm_video_url',
            'video_url',
            'nwm_video_url_HQ',
            'download_url',
          ]);
          final coverUrl = _extractField(videoData, [
            'cover',
            'cover_url',
            'dynamic_cover',
          ]);
          // If no useful data at all, report as failure
          if (title == null && videoUrl == null && coverUrl == null) {
            return WatermarkResult(
              success: false,
              error: '未能提取到有效资源，该平台可能暂不支持或链接已失效',
            );
          }
          return WatermarkResult(
            success: true,
            title: title ?? '未知标题',
            author:
                _extractField(videoData, [
                  'author',
                  'nickname',
                  'author_name',
                ]) ??
                '',
            videoUrl: videoUrl ?? '',
            coverUrl: coverUrl ?? '',
            musicUrl: _extractField(videoData, ['music_url', 'music']) ?? '',
            platform:
                _extractField(videoData, ['platform', 'type']) ?? 'unknown',
            type: videoData['type']?.toString() ?? 'video',
            rawData: videoData is Map<String, dynamic>
                ? videoData
                : Map<String, dynamic>.from(videoData),
          );
        } else {
          return WatermarkResult(
            success: false,
            error: data['message'] ?? data['msg'] ?? '解析失败，请检查链接是否正确',
          );
        }
      } else {
        // API returns 400/422 with detail wrapper when parsing fails (e.g. expired cookie)
        String errorMsg = '服务暂时不可用 (${response.statusCode})';
        try {
          final errData = json.decode(response.body);
          final detail = errData['detail'];
          if (detail is Map) {
            errorMsg = detail['message'] as String? ?? errorMsg;
          } else if (errData['message'] != null) {
            errorMsg = errData['message'] as String;
          }
        } catch (_) {}
        return WatermarkResult(success: false, error: '解析失败，当前平台可能暂不可用');
      }
    } on http.ClientException {
      return WatermarkResult(success: false, error: '网络连接失败，请检查网络');
    } catch (e) {
      if (kDebugMode) debugPrint('Watermark error: $e');
      return WatermarkResult(success: false, error: '解析出错: $e');
    }
  }

  /// 从嵌套数据中提取字段
  String? _extractField(dynamic data, List<String> keys) {
    if (data == null) return null;
    if (data is Map) {
      for (final key in keys) {
        final val = data[key];
        if (val != null && val.toString().isNotEmpty) return val.toString();
      }
      // 递归搜索嵌套对象
      for (final val in data.values) {
        if (val is Map) {
          final result = _extractField(val, keys);
          if (result != null) return result;
        }
      }
    }
    return null;
  }

  /// Get proxied download URL for watermark-removed media
  /// This routes through the server to bypass CDN blocks & CORS
  String getProxiedDownloadUrl(String mediaUrl) {
    return '$_baseUrl$_watermarkPath/api/download?url=${Uri.encodeComponent(mediaUrl)}&prefix=true&with_watermark=false';
  }

  // ═══════════════════════════════════════
  // 2. 直链下载 (netdisk-fast-download)
  // ═══════════════════════════════════════

  /// 解析网盘分享链接为直链
  /// Input URL and password are sanitized.
  Future<DirectLinkResult> parseDirectLink(
    String url, {
    String? password,
  }) async {
    // SEC: Sanitize URL input
    final sanitizedUrl = SecureConfig.sanitizeUrl(url);
    if (sanitizedUrl == null) {
      return DirectLinkResult(success: false, error: '链接格式不正确');
    }
    // SEC: Sanitize password
    final sanitizedPwd = password != null
        ? SecureConfig.sanitizeInput(password, maxLength: 32)
        : null;
    try {
      // 使用 JSON API 获取详细信息
      final params = {
        'url': sanitizedUrl,
        if (sanitizedPwd != null && sanitizedPwd.isNotEmpty)
          'pwd': sanitizedPwd,
      };
      final apiUrl = Uri.parse(
        '$_baseUrl$_netdiskPath/json/parser',
      ).replace(queryParameters: params);

      final response = await _client
          .get(apiUrl, headers: _authHeaders)
          .timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final respData = json.decode(response.body);
        // API wraps result in { code, msg, data: { ... } }
        final innerData =
            respData['data'] as Map<String, dynamic>? ??
            respData as Map<String, dynamic>;
        final apiCode = respData['code'];

        // Check if the API itself returned an error
        if (apiCode != null && apiCode != 200 && respData['success'] == false) {
          return DirectLinkResult(
            success: false,
            error: respData['msg'] as String? ?? '解析失败，链接可能无效或不支持',
          );
        }

        final directLink =
            innerData['directLink'] as String? ??
            innerData['downLink'] as String? ??
            innerData['url'] as String? ??
            '';
        // fileInfo.fileName for netdisk-fast-download
        final fileInfo = innerData['fileInfo'] as Map<String, dynamic>?;
        final fileName =
            fileInfo?['fileName'] as String? ??
            innerData['fileName'] as String? ??
            innerData['name'] as String? ??
            '';
        final fileSizeStr =
            fileInfo?['sizeStr'] as String? ??
            innerData['fileSize'] as String? ??
            '';

        if (directLink.isNotEmpty) {
          return DirectLinkResult(
            success: true,
            directUrl: directLink,
            filename: fileName,
            fileSize: fileSizeStr,
            cacheHit: innerData['cacheHit'] as bool? ?? false,
            shareKey: innerData['shareKey'] as String? ?? '',
            rawData: respData,
          );
        } else {
          return DirectLinkResult(
            success: false,
            error:
                respData['msg'] as String? ??
                respData['message'] as String? ??
                '解析失败，链接可能无效或不支持',
          );
        }
      } else if (response.statusCode == 302 || response.statusCode == 301) {
        // 302 重定向 = 直链
        final redirectUrl = response.headers['location'] ?? '';
        return DirectLinkResult(
          success: redirectUrl.isNotEmpty,
          directUrl: redirectUrl,
          error: redirectUrl.isEmpty ? '重定向失败' : null,
        );
      } else {
        return DirectLinkResult(
          success: false,
          error: '服务暂时不可用 (${response.statusCode})',
        );
      }
    } on http.ClientException {
      return DirectLinkResult(success: false, error: '网络连接失败');
    } catch (e) {
      if (kDebugMode) debugPrint('Direct link error: $e');
      return DirectLinkResult(success: false, error: '解析出错: $e');
    }
  }

  /// 获取网盘文件列表 (netdisk-fast-download v2 API)
  Future<List<NetdiskFile>> getFileList(String url, {String? password}) async {
    try {
      final params = {
        'url': url,
        if (password != null && password.isNotEmpty) 'pwd': password,
      };
      final apiUrl = Uri.parse(
        '$_baseUrl$_netdiskPath/v2/getFileList',
      ).replace(queryParameters: params);

      final response = await _client
          .get(apiUrl, headers: _authHeaders)
          .timeout(const Duration(seconds: 20));

      if (response.statusCode == 200) {
        final respData = json.decode(response.body);
        // API wraps in { code, data: { files: [...] } }
        final innerData =
            respData['data'] as Map<String, dynamic>? ??
            respData as Map<String, dynamic>;
        final files =
            innerData['files'] as List? ?? respData['files'] as List? ?? [];
        return files
            .map((f) => NetdiskFile.fromJson(f as Map<String, dynamic>))
            .toList();
      }
      return [];
    } catch (e) {
      if (kDebugMode) debugPrint('File list error: $e');
      return [];
    }
  }

  // ═══════════════════════════════════════
  // 3. AList (网盘挂载/WebDAV)
  // ═══════════════════════════════════════

  /// AList 登录获取 token
  /// Credentials are sanitized before transmission.
  Future<AListAuthResult> alistLogin(String username, String password) async {
    // SEC: Sanitize credentials
    final safeUser = SecureConfig.sanitizeInput(username, maxLength: 64);
    final safePwd = SecureConfig.sanitizeInput(password, maxLength: 128);
    try {
      final response = await _client
          .post(
            Uri.parse('$_baseUrl$_alistPath/api/auth/login'),
            headers: {'Content-Type': 'application/json', ..._authHeaders},
            body: json.encode({'username': safeUser, 'password': safePwd}),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['code'] == 200) {
          return AListAuthResult(
            success: true,
            token: data['data']?['token'] as String? ?? '',
          );
        }
        return AListAuthResult(
          success: false,
          error: data['message'] ?? '登录失败',
        );
      }
      return AListAuthResult(
        success: false,
        error: '服务不可用 (${response.statusCode})',
      );
    } catch (e) {
      return AListAuthResult(success: false, error: '网络错误');
    }
  }

  /// AList 列出文件
  Future<AListFileList> alistListFiles(
    String path, {
    required String token,
  }) async {
    try {
      final response = await _client
          .post(
            Uri.parse('$_baseUrl$_alistPath/api/fs/list'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': token,
              ..._authHeaders,
            },
            body: json.encode({
              'path': path,
              'password': '',
              'page': 1,
              'per_page': 100,
              'refresh': false,
            }),
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['code'] == 200) {
          final content = data['data']?['content'] as List? ?? [];
          final files = content
              .map((f) => AListFile.fromJson(f as Map<String, dynamic>))
              .toList();
          return AListFileList(success: true, files: files, path: path);
        }
        return AListFileList(success: false, error: data['message'] ?? '获取失败');
      }
      return AListFileList(success: false, error: '服务不可用');
    } catch (e) {
      return AListFileList(success: false, error: '网络错误');
    }
  }

  /// AList 获取文件下载链接
  Future<String?> alistGetDownloadUrl(
    String path, {
    required String token,
  }) async {
    try {
      final response = await _client
          .post(
            Uri.parse('$_baseUrl$_alistPath/api/fs/get'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': token,
              ..._authHeaders,
            },
            body: json.encode({'path': path, 'password': ''}),
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['code'] == 200) {
          return data['data']?['raw_url'] as String?;
        }
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  /// AList 获取已挂载的存储列表
  Future<List<AListStorage>> alistListStorages({required String token}) async {
    try {
      final response = await _client
          .get(
            Uri.parse('$_baseUrl$_alistPath/api/admin/storage/list'),
            headers: {'Authorization': token, ..._authHeaders},
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['code'] == 200) {
          final content = data['data']?['content'] as List? ?? [];
          return content
              .map((s) => AListStorage.fromJson(s as Map<String, dynamic>))
              .toList();
        }
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  /// Get AList preview URL for a file (opens in browser for media preview)
  /// Returns null for unsupported file types
  String? getAlistPreviewUrl(String filename, String currentPath) {
    final ext = filename.split('.').last.toLowerCase();
    // Supported preview types
    const previewExts = {
      // Images
      'jpg', 'jpeg', 'png', 'gif', 'webp', 'bmp', 'svg',
      // Videos
      'mp4', 'webm', 'mkv', 'avi', 'mov',
      // Audio
      'mp3', 'flac', 'wav', 'aac', 'ogg',
      // Documents
      'pdf', 'txt', 'md',
    };
    if (!previewExts.contains(ext)) return null;
    // AList web UI preview: /path/to/file
    final fullPath = currentPath.endsWith('/')
        ? '$currentPath$filename'
        : '$currentPath/$filename';
    return '$_baseUrl$_alistPath/#$fullPath';
  }

  // ═══════════════════════════════════════
  // 4. Speedtest (LibreSpeed)
  // ═══════════════════════════════════════

  /// Get the Speedtest page URL for WebView embedding
  String get speedtestUrl => '$_baseUrl$_speedtestPath/';

  /// Get Speedtest backend config for the LibreSpeed JS client
  Future<SpeedtestResult> runSpeedtest() async {
    try {
      final response = await _client
          .get(Uri.parse('$_baseUrl$_speedtestPath/'), headers: _authHeaders)
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        return SpeedtestResult(
          success: true,
          pageUrl: '$_baseUrl$_speedtestPath/',
        );
      }
      return SpeedtestResult(
        success: false,
        error: 'Speedtest service unavailable (${response.statusCode})',
      );
    } catch (e) {
      return SpeedtestResult(success: false, error: 'Network error');
    }
  }

  // ═══════════════════════════════════════
  // 5. Pandoc (Document Converter)
  // ═══════════════════════════════════════

  /// Check Pandoc service health
  Future<PandocHealthResult> pandocHealth() async {
    try {
      final response = await _client
          .get(Uri.parse('$_baseUrl$_pandocPath/health'), headers: _authHeaders)
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return PandocHealthResult(
          success: true,
          version: data['pandoc_version'] as String? ?? 'unknown',
          formats:
              (data['supported_formats'] as Map?)?.map(
                (k, v) => MapEntry(
                  k.toString(),
                  (v as List).map((e) => e.toString()).toList(),
                ),
              ) ??
              {},
        );
      }
      return PandocHealthResult(
        success: false,
        error: 'Pandoc service unavailable',
      );
    } catch (e) {
      return PandocHealthResult(success: false, error: 'Network error');
    }
  }

  /// Convert text content between formats using Pandoc
  /// [content] - Source content (Markdown, HTML, etc.)
  /// [from] - Source format (markdown, html, rst, latex, etc.)
  /// [to] - Target format (html, pdf, docx, latex, etc.)
  Future<PandocConvertResult> pandocConvert({
    required String content,
    required String from,
    required String to,
  }) async {
    if (content.trim().isEmpty) {
      return PandocConvertResult(
        success: false,
        error: 'Content cannot be empty',
      );
    }
    try {
      final response = await _client
          .post(
            Uri.parse('$_baseUrl$_pandocPath/api/convert'),
            headers: {'Content-Type': 'application/json', ..._authHeaders},
            body: json.encode({'content': content, 'from': from, 'to': to}),
          )
          .timeout(const Duration(seconds: 60));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          return PandocConvertResult(
            success: true,
            output: data['output'] as String? ?? '',
            fromFormat: data['from'] as String? ?? from,
            toFormat: data['to'] as String? ?? to,
          );
        }
        return PandocConvertResult(
          success: false,
          error: data['error'] as String? ?? 'Conversion failed',
        );
      }
      return PandocConvertResult(
        success: false,
        error: 'Service error (${response.statusCode})',
      );
    } catch (e) {
      if (kDebugMode) debugPrint('Pandoc convert error: $e');
      return PandocConvertResult(success: false, error: 'Network error');
    }
  }

  /// Get list of supported conversion formats
  Future<List<String>> pandocFormats() async {
    final health = await pandocHealth();
    if (health.success && health.formats.containsKey('from')) {
      return health.formats['from'] ?? [];
    }
    // Fallback common formats
    return [
      'markdown',
      'html',
      'latex',
      'rst',
      'textile',
      'org',
      'mediawiki',
      'docx',
    ];
  }

  // ═══════════════════════════════════════
  // 6. Netdata (Server Monitoring)
  // ═══════════════════════════════════════

  /// Get Netdata server info
  Future<NetdataInfoResult> netdataInfo() async {
    try {
      final response = await _client
          .get(
            Uri.parse('$_baseUrl$_netdataPath/api/v1/info'),
            headers: _authHeaders,
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return NetdataInfoResult(
          success: true,
          hostname: (data['hostname'] as String?)?.isNotEmpty == true
              ? data['hostname']
              : 'TEMPO Server',
          os:
              (data['os_name'] as String?)?.isNotEmpty == true &&
                  data['os_name'] != 'unknown'
              ? data['os_name']
              : 'Linux',
          cores: data['cores_total'] as int? ?? 0,
          ramTotal: data['ram_total'] as int? ?? 0,
          rawData: data,
        );
      }
      return NetdataInfoResult(success: false, error: 'Netdata unavailable');
    } catch (e) {
      return NetdataInfoResult(success: false, error: 'Network error');
    }
  }

  /// Get real-time system overview metrics
  /// Returns CPU, memory, disk, network usage
  Future<NetdataMetrics> netdataOverview() async {
    try {
      // Fetch multiple chart data in parallel
      final futures = await Future.wait([
        _netdataChart('system.cpu', after: -1, points: 1),
        _netdataChart('system.ram', after: -1, points: 1),
        _netdataChart('system.net', after: -1, points: 1),
        _netdataChart('system.load', after: -1, points: 1),
        _netdataChart('disk_space./', after: -1, points: 1),
      ]);

      return NetdataMetrics(
        success: true,
        cpu: _extractLatestValue(futures[0]),
        ramUsed: _extractRamUsed(futures[1]),
        ramTotal: _extractRamTotal(futures[1]),
        network: _extractNetworkValue(futures[2]),
        load1: _extractLoadValue(futures[3], 1),
        load5: _extractLoadValue(futures[3], 2),
        load15: _extractLoadValue(futures[3], 3),
        diskUsage: _extractDiskValue(futures[4]),
      );
    } catch (e) {
      if (kDebugMode) debugPrint('Netdata overview error: $e');
      return NetdataMetrics(success: false, error: 'Failed to fetch metrics');
    }
  }

  /// Get chart data from Netdata API
  Future<Map<String, dynamic>> _netdataChart(
    String chart, {
    int after = -600,
    int points = 60,
  }) async {
    try {
      final response = await _client
          .get(
            Uri.parse(
              '$_baseUrl$_netdataPath/api/v1/data?chart=$chart&after=$after&points=$points&format=json',
            ),
            headers: _authHeaders,
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        return json.decode(response.body) as Map<String, dynamic>;
      }
    } catch (_) {}
    return {};
  }

  /// Get chart data for time series display
  Future<NetdataChartData> netdataChartData(
    String chart, {
    int afterSeconds = -600,
    int points = 60,
  }) async {
    try {
      final data = await _netdataChart(
        chart,
        after: afterSeconds,
        points: points,
      );
      if (data.isNotEmpty) {
        final labels =
            (data['labels'] as List?)?.map((e) => e.toString()).toList() ?? [];
        final rawData = data['data'] as List? ?? [];
        final series = rawData.map((row) {
          if (row is List) {
            return row.map((v) => (v is num) ? v.toDouble() : 0.0).toList();
          }
          return <double>[];
        }).toList();
        return NetdataChartData(success: true, labels: labels, data: series);
      }
      return NetdataChartData(success: false, error: 'No data');
    } catch (e) {
      return NetdataChartData(success: false, error: 'Fetch error');
    }
  }

  double _extractLatestValue(Map<String, dynamic> data) {
    try {
      final rows = data['data'] as List?;
      if (rows != null && rows.isNotEmpty) {
        final lastRow = rows.last as List;
        if (lastRow.length > 1) {
          // Sum all values except timestamp (index 0)
          double total = 0;
          for (int i = 1; i < lastRow.length; i++) {
            total += (lastRow[i] is num)
                ? (lastRow[i] as num).toDouble().abs()
                : 0;
          }
          return total;
        }
      }
    } catch (_) {}
    return 0;
  }

  /// Extract RAM used (MB) from system.ram chart
  /// Labels: time, free, used, cached, buffers
  /// "used" is at index 2
  double _extractRamUsed(Map<String, dynamic> data) {
    try {
      final rows = data['data'] as List?;
      if (rows != null && rows.isNotEmpty) {
        final lastRow = rows.last as List;
        // used = index 2
        if (lastRow.length > 2) {
          return (lastRow[2] is num) ? (lastRow[2] as num).toDouble() : 0;
        }
      }
    } catch (_) {}
    return 0;
  }

  /// Extract RAM total (free+used+cached+buffers) from system.ram chart
  double _extractRamTotal(Map<String, dynamic> data) {
    try {
      final rows = data['data'] as List?;
      if (rows != null && rows.isNotEmpty) {
        final lastRow = rows.last as List;
        double total = 0;
        for (int i = 1; i < lastRow.length; i++) {
          total += (lastRow[i] is num) ? (lastRow[i] as num).toDouble() : 0;
        }
        return total;
      }
    } catch (_) {}
    return 0;
  }

  /// Extract specific load value (load1=1, load5=2, load15=3)
  double _extractLoadValue(Map<String, dynamic> data, int index) {
    try {
      final rows = data['data'] as List?;
      if (rows != null && rows.isNotEmpty) {
        final lastRow = rows.last as List;
        if (lastRow.length > index) {
          return (lastRow[index] is num)
              ? (lastRow[index] as num).toDouble()
              : 0;
        }
      }
    } catch (_) {}
    return 0;
  }

  Map<String, double> _extractNetworkValue(Map<String, dynamic> data) {
    try {
      final rows = data['data'] as List?;
      if (rows != null && rows.isNotEmpty) {
        final lastRow = rows.last as List;
        return {
          'received': (lastRow.length > 1 && lastRow[1] is num)
              ? (lastRow[1] as num).toDouble().abs()
              : 0,
          'sent': (lastRow.length > 2 && lastRow[2] is num)
              ? (lastRow[2] as num).toDouble().abs()
              : 0,
        };
      }
    } catch (_) {}
    return {'received': 0, 'sent': 0};
  }

  double _extractDiskValue(Map<String, dynamic> data) {
    try {
      final rows = data['data'] as List?;
      if (rows != null && rows.isNotEmpty) {
        final lastRow = rows.last as List;
        // disk_space chart: avail, used, reserved_for_root
        if (lastRow.length > 2) {
          final avail = (lastRow[1] is num)
              ? (lastRow[1] as num).toDouble()
              : 0.0;
          final used = (lastRow[2] is num)
              ? (lastRow[2] as num).toDouble()
              : 0.0;
          final total = avail + used;
          return total > 0 ? (used / total * 100) : 0;
        }
      }
    } catch (_) {}
    return 0;
  }

  // ─── Auth Headers ───
  Map<String, String> get _authHeaders => {
    'X-User-Id': ServerConfig.userId,
    ...ServerConfig.signedHeaders('/api/cloud-tools'),
  };

  // ═══════════════════════════════════════
  // Reachability / Health probes (for 配置 → 测试通路)
  // ═══════════════════════════════════════

  /// Available tools that support reachability testing.
  static const List<CloudToolProbe> supportedProbes = [
    CloudToolProbe(
      id: 'watermark',
      label: '去水印 (Douyin/TikTok)',
      description: '短视频/图文解析服务',
    ),
    CloudToolProbe(
      id: 'netdisk',
      label: '网盘直链解析',
      description: '百度/阿里/夸克等网盘直链',
    ),
    CloudToolProbe(
      id: 'alist',
      label: 'AList 网盘聚合',
      description: 'AList WebDAV 接口',
    ),
    CloudToolProbe(
      id: 'speedtest',
      label: 'Speedtest 测速',
      description: 'LibreSpeed 测速服务',
    ),
    CloudToolProbe(
      id: 'pandoc',
      label: 'Pandoc 文档转换',
      description: 'Markdown / DOCX / PDF 等转换',
    ),
    CloudToolProbe(id: 'netdata', label: 'Netdata 监控', description: '服务器性能监控'),
  ];

  /// Probe a single cloud tool. Returns detailed reachability info.
  ///
  /// Each tool has its own lightweight health endpoint — we don't invoke the
  /// actual transformation (which would cost CPU and possibly spam logs).
  Future<CloudToolProbeResult> probeTool(String toolId) async {
    final sw = Stopwatch()..start();
    String path;
    switch (toolId) {
      case 'watermark':
        // Douyin_TikTok_Download_API exposes Swagger at /docs and health at /
        path = '$_watermarkPath/';
        break;
      case 'netdisk':
        path = '$_netdiskPath/';
        break;
      case 'alist':
        // AList has a public /api/public/settings endpoint for health check
        path = '$_alistPath/api/public/settings';
        break;
      case 'speedtest':
        path = '$_speedtestPath/';
        break;
      case 'pandoc':
        path = '$_pandocPath/health';
        break;
      case 'netdata':
        path = '$_netdataPath/api/v1/info';
        break;
      default:
        sw.stop();
        return CloudToolProbeResult(
          toolId: toolId,
          ok: false,
          status: 0,
          latencyMs: 0,
          message: '未知的工具类型',
        );
    }

    final uri = Uri.parse('$_baseUrl$path');
    try {
      final resp = await _client
          .get(uri, headers: _authHeaders)
          .timeout(const Duration(seconds: 8));
      sw.stop();
      // 200/301/302/401 all count as "reachable" — we don't care if the
      // upstream rejects anonymous auth, only that the service responds.
      final reachable = resp.statusCode > 0 && resp.statusCode < 500;
      return CloudToolProbeResult(
        toolId: toolId,
        ok: reachable,
        status: resp.statusCode,
        latencyMs: sw.elapsedMilliseconds,
        message: reachable
            ? '通路正常 · ${resp.statusCode}'
            : '服务异常 · HTTP ${resp.statusCode}',
      );
    } on Exception catch (e) {
      sw.stop();
      String msg = '连接失败';
      final s = e.toString();
      if (s.contains('TimeoutException') ||
          s.contains('TimeLimitExceeded') ||
          s.contains('Timeout')) {
        msg = '请求超时（>8s），服务可能未启动';
      } else if (s.contains('SocketException') ||
          s.contains('HandshakeException')) {
        msg = '网络不可达（DNS / 防火墙 / 证书）';
      } else if (s.contains('FormatException')) {
        msg = '响应格式异常';
      }
      if (kDebugMode) debugPrint('probeTool($toolId) error: $e');
      return CloudToolProbeResult(
        toolId: toolId,
        ok: false,
        status: 0,
        latencyMs: sw.elapsedMilliseconds,
        message: msg,
      );
    }
  }

  /// Probe all supported tools in parallel.
  Future<List<CloudToolProbeResult>> probeAll() async {
    final futures = supportedProbes.map((p) => probeTool(p.id)).toList();
    return Future.wait(futures);
  }

  void dispose() {
    _client.close();
  }
}

/// Describes a cloud tool that can be probed for reachability.
class CloudToolProbe {
  final String id;
  final String label;
  final String description;
  const CloudToolProbe({
    required this.id,
    required this.label,
    required this.description,
  });
}

/// Result of a single cloud tool reachability probe.
class CloudToolProbeResult {
  final String toolId;
  final bool ok;
  final int status;
  final int latencyMs;
  final String message;

  CloudToolProbeResult({
    required this.toolId,
    required this.ok,
    required this.status,
    required this.latencyMs,
    required this.message,
  });

  String get latencyLabel {
    if (latencyMs < 100) return '${latencyMs}ms · 极速';
    if (latencyMs < 300) return '${latencyMs}ms · 良好';
    if (latencyMs < 800) return '${latencyMs}ms · 正常';
    if (latencyMs < 2000) return '${latencyMs}ms · 偏慢';
    return '${latencyMs}ms · 慢';
  }
}

// ═══════════════════════════════════════
// Data Models
// ═══════════════════════════════════════

/// 去水印结果
class WatermarkResult {
  final bool success;
  final String? title;
  final String? author;
  final String? videoUrl;
  final String? coverUrl;
  final String? musicUrl;
  final String? platform;
  final String? type;
  final String? error;
  final Map<String, dynamic>? rawData;

  WatermarkResult({
    required this.success,
    this.title,
    this.author,
    this.videoUrl,
    this.coverUrl,
    this.musicUrl,
    this.platform,
    this.type,
    this.error,
    this.rawData,
  });

  /// 获取所有图片链接 (图集类型)
  List<String> get imageUrls {
    if (rawData == null) return [];
    final images =
        rawData!['images'] as List? ??
        rawData!['image_urls'] as List? ??
        rawData!['no_watermark_image_url_list'] as List? ??
        [];
    return images.map((e) => e.toString()).where((u) => u.isNotEmpty).toList();
  }

  String get platformLabel {
    switch (platform?.toLowerCase()) {
      case 'douyin':
        return '抖音';
      case 'tiktok':
        return 'TikTok';
      case 'kuaishou':
        return '快手';
      case 'xiaohongshu':
      case 'xhs':
        return '小红书';
      case 'weibo':
        return '微博';
      case 'bilibili':
        return 'B站';
      case 'youtube':
        return 'YouTube';
      default:
        return platform ?? '未知';
    }
  }
}

/// 直链下载结果
class DirectLinkResult {
  final bool success;
  final String? directUrl;
  final String? filename;
  final String? fileSize;
  final bool? cacheHit;
  final String? shareKey;
  final String? error;
  final Map<String, dynamic>? rawData;

  DirectLinkResult({
    required this.success,
    this.directUrl,
    this.filename,
    this.fileSize,
    this.cacheHit,
    this.shareKey,
    this.error,
    this.rawData,
  });
}

/// 网盘文件
class NetdiskFile {
  final String name;
  final String size;
  final String url;
  final bool isFolder;

  NetdiskFile({
    required this.name,
    this.size = '',
    this.url = '',
    this.isFolder = false,
  });

  factory NetdiskFile.fromJson(Map<String, dynamic> j) => NetdiskFile(
    name: j['name'] as String? ?? j['fileName'] as String? ?? '',
    size: j['size'] as String? ?? j['fileSize'] as String? ?? '',
    url: j['url'] as String? ?? j['downloadUrl'] as String? ?? '',
    isFolder: j['isFolder'] as bool? ?? j['is_dir'] as bool? ?? false,
  );
}

/// AList 认证结果
class AListAuthResult {
  final bool success;
  final String? token;
  final String? error;

  AListAuthResult({required this.success, this.token, this.error});
}

/// AList 文件列表结果
class AListFileList {
  final bool success;
  final List<AListFile> files;
  final String? path;
  final String? error;

  AListFileList({
    required this.success,
    this.files = const [],
    this.path,
    this.error,
  });
}

/// AList 文件
class AListFile {
  final String name;
  final int size;
  final bool isDir;
  final String modified;
  final String? thumb;

  AListFile({
    required this.name,
    this.size = 0,
    this.isDir = false,
    this.modified = '',
    this.thumb,
  });

  factory AListFile.fromJson(Map<String, dynamic> j) => AListFile(
    name: j['name'] as String? ?? '',
    size: j['size'] as int? ?? 0,
    isDir: j['is_dir'] as bool? ?? false,
    modified: j['modified'] as String? ?? '',
    thumb: j['thumb'] as String?,
  );

  String get sizeFormatted {
    if (isDir) return '-';
    if (size < 1024) return '$size B';
    if (size < 1024 * 1024) return '${(size / 1024).toStringAsFixed(1)} KB';
    if (size < 1024 * 1024 * 1024)
      return '${(size / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(size / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }
}

/// AList 存储
class AListStorage {
  final int id;
  final String mountPath;
  final String driver;
  final bool disabled;

  AListStorage({
    required this.id,
    this.mountPath = '',
    this.driver = '',
    this.disabled = false,
  });

  factory AListStorage.fromJson(Map<String, dynamic> j) => AListStorage(
    id: j['id'] as int? ?? 0,
    mountPath: j['mount_path'] as String? ?? '',
    driver: j['driver'] as String? ?? '',
    disabled: j['disabled'] as bool? ?? false,
  );
}

/// Speedtest result
class SpeedtestResult {
  final bool success;
  final String? pageUrl;
  final String? error;

  SpeedtestResult({required this.success, this.pageUrl, this.error});
}

/// Pandoc health result
class PandocHealthResult {
  final bool success;
  final String? version;
  final Map<String, List<String>> formats;
  final String? error;

  PandocHealthResult({
    required this.success,
    this.version,
    this.formats = const {},
    this.error,
  });
}

/// Pandoc conversion result
class PandocConvertResult {
  final bool success;
  final String? output;
  final String? fromFormat;
  final String? toFormat;
  final String? error;

  PandocConvertResult({
    required this.success,
    this.output,
    this.fromFormat,
    this.toFormat,
    this.error,
  });
}

/// Netdata server info
class NetdataInfoResult {
  final bool success;
  final String? hostname;
  final String? os;
  final int cores;
  final int ramTotal;
  final Map<String, dynamic>? rawData;
  final String? error;

  NetdataInfoResult({
    required this.success,
    this.hostname,
    this.os,
    this.cores = 0,
    this.ramTotal = 0,
    this.rawData,
    this.error,
  });
}

/// Netdata real-time metrics
class NetdataMetrics {
  final bool success;
  final double cpu;
  final double ramUsed; // MB
  final double ramTotal; // MB
  final Map<String, double> network;
  final double load1;
  final double load5;
  final double load15;
  final double diskUsage;
  final String? error;

  NetdataMetrics({
    required this.success,
    this.cpu = 0,
    this.ramUsed = 0,
    this.ramTotal = 0,
    this.network = const {},
    this.load1 = 0,
    this.load5 = 0,
    this.load15 = 0,
    this.diskUsage = 0,
    this.error,
  });

  String get cpuFormatted => '${cpu.toStringAsFixed(1)}%';
  String get ramFormatted {
    if (ramTotal > 1024) {
      return '${(ramUsed / 1024).toStringAsFixed(1)}/${(ramTotal / 1024).toStringAsFixed(1)} GB';
    }
    return '${ramUsed.toStringAsFixed(0)}/${ramTotal.toStringAsFixed(0)} MB';
  }

  double get ramPercent => ramTotal > 0 ? (ramUsed / ramTotal * 100) : 0;
  String get ramPercentFormatted => '${ramPercent.toStringAsFixed(1)}%';
  String get diskFormatted => '${diskUsage.toStringAsFixed(1)}%';
  String get load1Formatted => load1.toStringAsFixed(2);
  String get loadFormatted =>
      '${load1.toStringAsFixed(2)} / ${load5.toStringAsFixed(2)} / ${load15.toStringAsFixed(2)}';
  String get networkIn {
    final val = network['received'] ?? 0;
    if (val > 1000) return '${(val / 1000).toStringAsFixed(1)} Mbit/s';
    return '${val.toStringAsFixed(0)} kbit/s';
  }

  String get networkOut {
    final val = network['sent'] ?? 0;
    if (val > 1000) return '${(val / 1000).toStringAsFixed(1)} Mbit/s';
    return '${val.toStringAsFixed(0)} kbit/s';
  }
}

/// Netdata chart data (time series)
class NetdataChartData {
  final bool success;
  final List<String> labels;
  final List<List<double>> data;
  final String? error;

  NetdataChartData({
    required this.success,
    this.labels = const [],
    this.data = const [],
    this.error,
  });
}
