import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// Chinese holiday service using timor.tech free API
/// API: https://timor.tech/api/holiday
class HolidayService {
  static final HolidayService _instance = HolidayService._();
  HolidayService._();
  factory HolidayService() => _instance;

  // Cache: date string -> HolidayInfo
  final Map<String, HolidayInfo> _cache = {};
  String? _lastFetchMonth; // "2024-04" format

  /// Get holiday info for a specific date
  HolidayInfo? getInfo(DateTime date) {
    final key = _dateKey(date);
    return _cache[key];
  }

  /// Check if a date is a holiday
  bool isHoliday(DateTime date) {
    final info = _cache[_dateKey(date)];
    return info != null && info.isHoliday;
  }

  /// Check if a date is a work day (including weekend make-up work days)
  bool isWorkDay(DateTime date) {
    final info = _cache[_dateKey(date)];
    if (info != null) return !info.isHoliday;
    // Default: weekday = work day
    return date.weekday <= 5;
  }

  /// Get holiday name if any
  String? getHolidayName(DateTime date) {
    final info = _cache[_dateKey(date)];
    return info?.name;
  }

  /// Fetch holiday data for current month and next month
  Future<void> fetchMonth(DateTime month) async {
    final monthKey = '${month.year}-${month.month.toString().padLeft(2, '0')}';
    if (_lastFetchMonth == monthKey && _cache.isNotEmpty) return;

    try {
      // Fetch current month
      await _fetchMonthData(month.year, month.month);
      // Also prefetch next month
      final next = DateTime(month.year, month.month + 1);
      await _fetchMonthData(next.year, next.month);

      _lastFetchMonth = monthKey;
    } catch (e) {
      if (kDebugMode) debugPrint('[Holiday] fetch error: $e');
      // Try loading from local cache
      await _loadFromCache();
    }
  }

  Future<void> _fetchMonthData(int year, int month) async {
    try {
      final url =
          'https://timor.tech/api/holiday/year/$year-${month.toString().padLeft(2, '0')}';
      final resp = await http
          .get(Uri.parse(url))
          .timeout(const Duration(seconds: 8));

      if (resp.statusCode == 200) {
        final data = json.decode(resp.body);
        if (data['code'] == 0) {
          final holiday = data['holiday'] as Map<String, dynamic>? ?? {};
          for (final entry in holiday.entries) {
            final dateStr = entry.key; // "01-01" format
            final info = entry.value as Map<String, dynamic>;

            final fullDate =
                '$year-${month.toString().padLeft(2, '0')}-${dateStr.substring(dateStr.length - 2)}';
            _cache[fullDate] = HolidayInfo(
              date: fullDate,
              name: info['name'] as String? ?? '',
              isHoliday: info['holiday'] as bool? ?? false,
              wage: info['wage'] as int? ?? 1,
              target: info['target'] as String? ?? '',
              after: info['after'] as bool? ?? false,
            );
          }

          // Save to local cache
          await _saveToCache();
        }
      }
    } catch (e) {
      if (kDebugMode) debugPrint('[Holiday] _fetchMonthData error: $e');
    }
  }

  Future<void> _saveToCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final encoded = json.encode(
        _cache.map((k, v) => MapEntry(k, v.toJson())),
      );
      await prefs.setString('holiday_cache', encoded);
    } catch (_) {}
  }

  Future<void> _loadFromCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final encoded = prefs.getString('holiday_cache');
      if (encoded != null) {
        final decoded = json.decode(encoded) as Map<String, dynamic>;
        for (final entry in decoded.entries) {
          _cache[entry.key] = HolidayInfo.fromJson(
            entry.value as Map<String, dynamic>,
          );
        }
      }
    } catch (_) {}
  }

  String _dateKey(DateTime date) =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
}

class HolidayInfo {
  final String date;
  final String name;
  final bool isHoliday; // true=放假, false=补班
  final int wage; // 1=正常, 2=双倍, 3=三倍
  final String target; // Which holiday this make-up day belongs to
  final bool after; // true=调休在假期后

  HolidayInfo({
    required this.date,
    required this.name,
    required this.isHoliday,
    this.wage = 1,
    this.target = '',
    this.after = false,
  });

  Map<String, dynamic> toJson() => {
    'date': date,
    'name': name,
    'isHoliday': isHoliday,
    'wage': wage,
    'target': target,
    'after': after,
  };

  factory HolidayInfo.fromJson(Map<String, dynamic> json) => HolidayInfo(
    date: json['date'] as String? ?? '',
    name: json['name'] as String? ?? '',
    isHoliday: json['isHoliday'] as bool? ?? false,
    wage: json['wage'] as int? ?? 1,
    target: json['target'] as String? ?? '',
    after: json['after'] as bool? ?? false,
  );
}
