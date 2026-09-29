import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// Hitokoto (hitokoto.cn) daily quote service
class HitokotoService {
  static final HitokotoService _instance = HitokotoService._();
  HitokotoService._();
  factory HitokotoService() => _instance;

  String? _content;
  String? _from;
  String? _type;
  DateTime? _lastFetch;

  String get content => _content ?? '向着光亮那方';
  String get from => _from ?? 'TEMPO';
  String get type => _type ?? '';

  /// Type mapping for hitokoto categories
  static const _typeMap = {
    'a': '动画',
    'b': '漫画',
    'c': '游戏',
    'd': '文学',
    'e': '原创',
    'f': '网络',
    'g': '其他',
    'h': '影视',
    'i': '诗词',
    'j': '网易云',
    'k': '哲学',
    'l': '抖机灵',
  };

  String get typeName => _typeMap[_type] ?? '';

  /// Negative keyword filter — skip quotes containing these words
  static const _negativeKeywords = [
    '死',
    '杀',
    '血',
    '恨',
    '仇',
    '葬',
    '亡',
    '毁灭',
    '绝望',
    '痛苦',
    '悲伤',
    '悲哀',
    '堕落',
    '黑暗',
    '地狱',
    '自杀',
    '崩溃',
    '末日',
    '孤独',
    '寂寞',
    '无望',
    '厌',
    '丧',
    '废',
    '腐烂',
    '尸',
    '棺',
    '坟',
    '哭泣',
    '眼泪',
    '分手',
    '背叛',
    '谎言',
    '欺骗',
    '虚伪',
    '残忍',
    '暴力',
    '战争',
    '奴隶',
    '囚',
    '牢',
    '刑',
    '罪',
  ];

  bool _isPositive(String text) {
    final lower = text.toLowerCase();
    for (final kw in _negativeKeywords) {
      if (lower.contains(kw)) return false;
    }
    return true;
  }

  /// Fetch from API with retry, skip negative quotes (max 3 retries)
  Future<Map<String, String>?> _fetchPositive({String? category}) async {
    for (int i = 0; i < 3; i++) {
      try {
        final catParam = category != null ? '?c=$category' : '';
        final resp = await http
            .get(
              Uri.parse('https://v1.hitokoto.cn/$catParam'),
              headers: {'Accept': 'application/json'},
            )
            .timeout(const Duration(seconds: 8));

        if (resp.statusCode == 200) {
          final data = json.decode(resp.body);
          final text = data['hitokoto'] as String? ?? '';
          if (text.isNotEmpty && _isPositive(text)) {
            return {
              'content': text,
              'from': data['from'] as String? ?? '',
              'type': data['type'] as String? ?? '',
            };
          }
          // Not positive, retry
          if (kDebugMode) debugPrint('[Hitokoto] skipped negative: $text');
        }
      } catch (e) {
        if (kDebugMode)
          debugPrint('[Hitokoto] fetch attempt ${i + 1} error: $e');
      }
    }
    return null;
  }

  /// Fetch a new quote from hitokoto.cn API (with negative filter)
  Future<bool> fetch({String? category}) async {
    // Cache for 30 min to avoid too many requests
    if (_lastFetch != null &&
        DateTime.now().difference(_lastFetch!).inMinutes < 30 &&
        _content != null) {
      return true;
    }

    try {
      // Try to load from local cache first
      final prefs = await SharedPreferences.getInstance();
      final cachedDate = prefs.getString('hitokoto_date');
      final today = DateTime.now().toIso8601String().substring(0, 10);

      if (cachedDate == today && _content == null) {
        _content = prefs.getString('hitokoto_content');
        _from = prefs.getString('hitokoto_from');
        _type = prefs.getString('hitokoto_type');
        if (_content != null) {
          _lastFetch = DateTime.now();
          return true;
        }
      }

      final result = await _fetchPositive(category: category);
      if (result != null) {
        _content = result['content'];
        _from = result['from'];
        _type = result['type'];
        _lastFetch = DateTime.now();

        // Cache locally
        await prefs.setString('hitokoto_content', _content!);
        await prefs.setString('hitokoto_from', _from!);
        await prefs.setString('hitokoto_type', _type!);
        await prefs.setString('hitokoto_date', today);

        return true;
      }
    } catch (e) {
      if (kDebugMode) debugPrint('[Hitokoto] fetch error: $e');
    }

    // Fallback: use cached data if available
    if (_content == null) {
      final prefs = await SharedPreferences.getInstance();
      _content = prefs.getString('hitokoto_content');
      _from = prefs.getString('hitokoto_from');
      _type = prefs.getString('hitokoto_type');
    }

    return _content != null;
  }

  /// Force refresh to get a new quote (bypasses all caches, with negative filter)
  Future<bool> refresh({String? category}) async {
    _lastFetch = null;
    _content = null;
    _from = null;
    _type = null;

    final result = await _fetchPositive(category: category);
    if (result != null) {
      _content = result['content'];
      _from = result['from'];
      _type = result['type'];
      _lastFetch = DateTime.now();

      // Update cache
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('hitokoto_content', _content!);
      await prefs.setString('hitokoto_from', _from!);
      await prefs.setString('hitokoto_type', _type!);
      await prefs.setString(
        'hitokoto_date',
        DateTime.now().toIso8601String().substring(0, 10),
      );

      return true;
    }
    return false;
  }
}
