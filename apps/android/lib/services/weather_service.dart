import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// QWeather (和风天气) service
/// API KEY mode: key=xxx as URL parameter
/// Host from console (e.g. abc123.re.qweatherapi.com)
/// Register at: https://console.qweather.com/
class WeatherService {
  static final WeatherService _instance = WeatherService._();
  WeatherService._();
  factory WeatherService() => _instance;

  // API credentials
  static String _apiKey = '';
  static String _apiHost = ''; // e.g. abc123.re.qweatherapi.com
  static String _locationId = '101010100'; // Default: Beijing

  String? _temp;
  String? _text;
  String? _icon;
  String? _cityName;
  String? _windDir;
  String? _humidity;
  DateTime? _lastFetch;

  String get temp => _temp ?? '--';
  String get text => _text ?? '未知';
  String get icon => _icon ?? '999';
  String get cityName => _cityName ?? '未设置';
  String get windDir => _windDir ?? '';
  String get humidity => _humidity ?? '';
  bool get hasApiKey => _apiKey.isNotEmpty && _apiHost.isNotEmpty;
  bool get hasData => _temp != null;
  String get maskedHost {
    if (_apiHost.isEmpty) return '';
    return '${_apiHost.substring(0, _apiHost.length > 8 ? 8 : _apiHost.length)}...';
  }

  String get maskedKey {
    if (_apiKey.isEmpty) return '';
    return '${_apiKey.substring(0, _apiKey.length > 6 ? 6 : _apiKey.length)}...';
  }

  /// Initialize with user's credentials from settings
  static Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _apiKey = prefs.getString('weather_api_key') ?? '';
    _apiHost = prefs.getString('weather_api_host') ?? '';
    _locationId = prefs.getString('weather_location_id') ?? '101010100';
    _instance._cityName = prefs.getString('weather_city_name');
    // Migrate from old Bearer Token format
    if (_apiKey.isEmpty) {
      final legacyToken = prefs.getString('weather_api_token') ?? '';
      if (legacyToken.isNotEmpty) {
        _apiKey = legacyToken;
        await prefs.setString('weather_api_key', _apiKey);
        await prefs.remove('weather_api_token');
      }
    }
    // Load cached weather data
    _instance._temp = prefs.getString('weather_temp');
    _instance._text = prefs.getString('weather_text');
    _instance._icon = prefs.getString('weather_icon');
    _instance._windDir = prefs.getString('weather_wind');
    _instance._humidity = prefs.getString('weather_humidity');
    if (kDebugMode) {
      debugPrint(
        '[Weather] init: key=${_apiKey.isNotEmpty ? "set(${_apiKey.length}chars)" : "empty"}, host=${_apiHost.isNotEmpty ? "set" : "empty"}, city=${_instance._cityName}',
      );
    }
  }

  /// Reload from SharedPreferences (call after saving)
  static Future<void> reload() async {
    final prefs = await SharedPreferences.getInstance();
    _apiKey = prefs.getString('weather_api_key') ?? '';
    _apiHost = prefs.getString('weather_api_host') ?? '';
    _locationId = prefs.getString('weather_location_id') ?? '101010100';
    _instance._cityName = prefs.getString('weather_city_name');
    _instance._lastFetch = null; // Force re-fetch
    if (kDebugMode) {
      debugPrint(
        '[Weather] reload: key=${_apiKey.isNotEmpty ? "set" : "empty"}, host=$_apiHost',
      );
    }
  }

  /// Save API credentials
  static Future<void> setCredentials(String key, String host) async {
    _apiKey = key.trim();
    _apiHost = host
        .trim()
        .replaceAll(RegExp(r'^https?://'), '')
        .replaceAll(RegExp(r'/+$'), '');
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('weather_api_key', _apiKey);
    await prefs.setString('weather_api_host', _apiHost);
  }

  /// Set location by city ID
  static Future<void> setLocation(String locationId, String cityName) async {
    _locationId = locationId;
    _instance._cityName = cityName;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('weather_location_id', _locationId);
    await prefs.setString('weather_city_name', cityName);
    _instance._lastFetch = null;
  }

  /// Get weather icon data
  static IconData getWeatherIcon(String code) {
    final c = int.tryParse(code) ?? 999;
    if (c >= 100 && c <= 103) return Icons.wb_sunny_rounded;
    if (c == 104) return Icons.cloud_rounded;
    if (c >= 150 && c <= 153) return Icons.nights_stay_rounded;
    if (c >= 300 && c <= 315) return Icons.grain_rounded;
    if (c >= 316 && c <= 318) return Icons.thunderstorm_rounded;
    if (c >= 399 && c <= 499) return Icons.ac_unit_rounded;
    if (c >= 500 && c <= 515) return Icons.foggy;
    return Icons.wb_cloudy_rounded;
  }

  static Color getWeatherColor(String code) {
    final c = int.tryParse(code) ?? 999;
    if (c >= 100 && c <= 103) return const Color(0xFFFF9500);
    if (c >= 150 && c <= 153) return const Color(0xFF5856D6);
    if (c >= 300 && c <= 315) return const Color(0xFF007AFF);
    if (c >= 316 && c <= 399) return const Color(0xFFFF3B30);
    if (c >= 400 && c <= 499) return const Color(0xFF5AC8FA);
    if (c >= 500 && c <= 515) return const Color(0xFF8E8E93);
    return const Color(0xFF34C759);
  }

  /// Test connection with given credentials (without saving)
  static Future<String> testConnection(
    String key,
    String host, {
    String location = '101010100',
  }) async {
    if (key.isEmpty || host.isEmpty) return 'API Key 和 Host 都不能为空';
    final cleanHost = host
        .trim()
        .replaceAll(RegExp(r'^https?://'), '')
        .replaceAll(RegExp(r'/+$'), '');
    try {
      final url =
          'https://$cleanHost/v7/weather/now?location=$location&key=$key';
      if (kDebugMode)
        debugPrint(
          '[Weather] test URL: https://$cleanHost/v7/weather/now?location=$location&key=***',
        );
      final resp = await http
          .get(Uri.parse(url))
          .timeout(const Duration(seconds: 10));

      if (kDebugMode) {
        debugPrint(
          '[Weather] test resp: ${resp.statusCode} body=${resp.body.length > 200 ? resp.body.substring(0, 200) : resp.body}',
        );
      }

      if (resp.statusCode == 200) {
        try {
          final data = json.decode(resp.body);
          final code = data['code']?.toString() ?? '';
          if (code == '200') {
            final now = data['now'];
            return 'OK: ${now['text']} ${now['temp']}\u00B0C';
          }
          final errMap = {
            '400': '请求参数错误',
            '401': 'API Key无效或过期',
            '402': '额度不足，请充值',
            '403': '无此数据访问权限',
            '404': '数据不存在',
            '429': '请求过于频繁',
            '500': '和风天气服务器错误',
          };
          return errMap[code] ?? '接口返回错误 (code=$code)';
        } catch (_) {
          return '响应解析失败，检查Host是否正确';
        }
      } else if (resp.statusCode == 401) {
        return 'API Key无效 (HTTP 401)';
      } else if (resp.statusCode == 403) {
        return 'Host无效或未授权 (HTTP 403)';
      } else if (resp.statusCode == 404) {
        return 'Host地址错误 (HTTP 404)';
      }
      return 'HTTP错误: ${resp.statusCode}';
    } on http.ClientException catch (e) {
      return '网络错误: $e';
    } catch (e) {
      if (e.toString().contains('TimeoutException')) {
        return '连接超时，检查Host是否正确';
      }
      return '连接失败: $e';
    }
  }

  /// Last fetch error message (for UI display)
  String? _lastError;
  String? get lastError => _lastError;

  /// Fetch current weather from QWeather API (API KEY mode)
  Future<bool> fetch({bool force = false}) async {
    _lastError = null;
    if (_apiKey.isEmpty || _apiHost.isEmpty) {
      _lastError = 'API Host 或 Key 未配置';
      return false;
    }

    // Cache for 30 min (unless forced)
    if (!force &&
        _lastFetch != null &&
        DateTime.now().difference(_lastFetch!).inMinutes < 30 &&
        _temp != null) {
      return true;
    }

    try {
      final url =
          'https://$_apiHost/v7/weather/now?location=$_locationId&key=$_apiKey';
      if (kDebugMode)
        debugPrint(
          '[Weather] fetch URL: https://$_apiHost/v7/weather/now?location=$_locationId&key=***',
        );
      final resp = await http
          .get(Uri.parse(url))
          .timeout(const Duration(seconds: 10));

      if (kDebugMode) debugPrint('[Weather] fetch resp: ${resp.statusCode}');

      if (resp.statusCode == 200) {
        try {
          final data = json.decode(resp.body);
          final code = data['code']?.toString() ?? '';
          if (code == '200') {
            final now = data['now'];
            _temp = now['temp'] as String?;
            _text = now['text'] as String?;
            _icon = now['icon'] as String?;
            _windDir = now['windDir'] as String?;
            _humidity = now['humidity'] as String?;
            _lastFetch = DateTime.now();

            // Cache locally
            final prefs = await SharedPreferences.getInstance();
            if (_temp != null) await prefs.setString('weather_temp', _temp!);
            if (_text != null) await prefs.setString('weather_text', _text!);
            if (_icon != null) await prefs.setString('weather_icon', _icon!);
            if (_windDir != null)
              await prefs.setString('weather_wind', _windDir!);
            if (_humidity != null)
              await prefs.setString('weather_humidity', _humidity!);

            return true;
          }
          _lastError = '和风天气返回错误 (code=$code)';
        } catch (_) {
          _lastError = '响应解析失败';
        }
      } else if (resp.statusCode == 401) {
        _lastError = 'API Key无效 (401)';
      } else if (resp.statusCode == 403) {
        _lastError = 'Host无效或未授权 (403)';
      } else {
        _lastError = 'HTTP ${resp.statusCode}';
      }
      if (kDebugMode) debugPrint('[Weather] fetch failed: $_lastError');
    } catch (e) {
      _lastError = '网络错误: $e';
      if (kDebugMode) debugPrint('[Weather] fetch error: $e');
    }

    return false;
  }

  /// Search city by name using GeoAPI
  Future<List<Map<String, String>>> searchCity(String query) async {
    if (_apiKey.isEmpty || _apiHost.isEmpty || query.trim().isEmpty) return [];

    try {
      final url =
          'https://$_apiHost/geo/v2/city/lookup?location=${Uri.encodeComponent(query)}&number=5&key=$_apiKey';
      if (kDebugMode)
        debugPrint(
          '[Weather] searchCity URL: https://$_apiHost/geo/v2/city/lookup?location=${Uri.encodeComponent(query)}&number=5&key=***',
        );
      final resp = await http
          .get(Uri.parse(url))
          .timeout(const Duration(seconds: 8));

      if (kDebugMode)
        debugPrint('[Weather] searchCity resp: ${resp.statusCode}');

      if (resp.statusCode == 200) {
        final data = json.decode(resp.body);
        final code = data['code']?.toString() ?? '';
        if (code == '200') {
          final locations = data['location'] as List? ?? [];
          return locations
              .map<Map<String, String>>(
                (loc) => {
                  'id': loc['id'] as String? ?? '',
                  'name': loc['name'] as String? ?? '',
                  'adm1': loc['adm1'] as String? ?? '',
                  'adm2': loc['adm2'] as String? ?? '',
                },
              )
              .toList();
        }
        if (kDebugMode) debugPrint('[Weather] searchCity error code=$code');
      }
    } catch (e) {
      if (kDebugMode) debugPrint('[Weather] search error: $e');
    }
    return [];
  }
}
