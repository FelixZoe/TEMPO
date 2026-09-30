import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// DeepSeek AI assistant service
/// Free tier: 5M tokens
/// Register at: https://platform.deepseek.com/
class DeepSeekService {
  static final DeepSeekService _instance = DeepSeekService._();
  DeepSeekService._();
  factory DeepSeekService() => _instance;

  static String _apiKey = '';
  bool get hasApiKey => _apiKey.isNotEmpty;

  static const String _baseUrl = 'https://api.deepseek.com/v1/chat/completions';
  static const String _model = 'deepseek-chat';

  /// Initialize with stored API key
  static Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _apiKey = prefs.getString('deepseek_api_key') ?? '';
    if (kDebugMode)
      debugPrint(
        '[DeepSeek] init: key=${_apiKey.isNotEmpty ? "set(${_apiKey.length}chars)" : "empty"}',
      );
  }

  /// Reload API key from SharedPreferences (call after saving)
  static Future<void> reload() async {
    final prefs = await SharedPreferences.getInstance();
    _apiKey = prefs.getString('deepseek_api_key') ?? '';
    if (kDebugMode)
      debugPrint(
        '[DeepSeek] reload: key=${_apiKey.isNotEmpty ? "set" : "empty"}',
      );
  }

  /// Set API key
  static Future<void> setApiKey(String key) async {
    _apiKey = key.trim();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('deepseek_api_key', _apiKey);
  }

  /// Send a chat message and get response
  Future<String> chat(
    String message, {
    String? systemPrompt,
    double temperature = 0.7,
  }) async {
    if (_apiKey.isEmpty) return '[Error] Please set DeepSeek API key first';

    try {
      final messages = <Map<String, String>>[];

      if (systemPrompt != null) {
        messages.add({'role': 'system', 'content': systemPrompt});
      }
      messages.add({'role': 'user', 'content': message});

      final resp = await http
          .post(
            Uri.parse(_baseUrl),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $_apiKey',
            },
            body: json.encode({
              'model': _model,
              'messages': messages,
              'temperature': temperature,
              'max_tokens': 2048,
              'stream': false,
            }),
          )
          .timeout(const Duration(seconds: 30));

      if (resp.statusCode == 200) {
        final data = json.decode(resp.body);
        final choices = data['choices'] as List?;
        if (choices != null && choices.isNotEmpty) {
          return choices[0]['message']['content'] as String? ?? '';
        }
        return '[Error] Empty response';
      } else if (resp.statusCode == 401) {
        return '[Error] API key invalid, please check your DeepSeek API key';
      } else if (resp.statusCode == 429) {
        return '[Error] Rate limited, please try again later';
      } else {
        return '[Error] Server error: ${resp.statusCode}';
      }
    } catch (e) {
      if (kDebugMode) debugPrint('[DeepSeek] chat error: $e');
      return '[Error] Network error, please check your connection';
    }
  }

  /// AI task decomposition: break one sentence into sub-tasks
  Future<List<String>> decomposeTask(String taskDescription) async {
    const systemPrompt =
        '''You are a productivity assistant for a Chinese task management app called "Tempo".
Your job is to decompose a user's task description into actionable sub-tasks.

Rules:
1. Output in Chinese
2. Return 3-7 sub-tasks, each on a new line
3. Each sub-task should be clear, actionable, and estimated time if possible
4. Start each line with a number and period like "1. "
5. Keep each sub-task concise (under 30 chars)
6. Order by suggested execution priority
7. Do NOT include any other text, only the numbered list''';

    final result = await chat(
      taskDescription,
      systemPrompt: systemPrompt,
      temperature: 0.5,
    );

    if (result.startsWith('[Error]')) return [result];

    // Parse numbered list
    final lines = result
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .map((l) => l.replaceFirst(RegExp(r'^\d+[\.\、\)] *'), ''))
        .where((l) => l.isNotEmpty)
        .toList();

    return lines.isEmpty
        ? ['AI returned empty result, please try again']
        : lines;
  }

  /// AI daily encouragement based on productivity data
  Future<String> dailyEncouragement({
    required int pomodoroCount,
    required int focusMinutes,
    required int completedTasks,
    required int totalTasks,
    required int streak,
  }) async {
    const systemPrompt =
        '''You are a warm, encouraging productivity buddy for the "Tempo" app.
Generate a short motivational message (1-2 sentences) in Chinese based on the user's daily stats.

Rules:
1. Be warm, specific, and reference their actual numbers
2. If they did well, celebrate; if not, be gentle and encouraging
3. Keep it under 50 Chinese characters
4. Use a natural, friendly tone (not formal)
5. Output only the message, no other text''';

    final message =
        '''Today's stats:
- Pomodoro sessions: $pomodoroCount
- Focus time: $focusMinutes minutes
- Tasks completed: $completedTasks/$totalTasks
- Current streak: $streak days''';

    return chat(message, systemPrompt: systemPrompt, temperature: 0.8);
  }

  /// AI focus analysis after pomodoro session
  Future<String> focusAnalysis({
    required int sessionMinutes,
    required String taskName,
    required int todayTotal,
  }) async {
    const systemPrompt = '''You are a focus coach for the "Tempo" app.
After a pomodoro session, give brief feedback in Chinese.

Rules:
1. 1-2 sentences max
2. Reference the specific session data
3. Give a quick actionable tip if applicable
4. Keep it under 60 Chinese characters
5. Output only the feedback''';

    final message =
        'Just completed a $sessionMinutes min focus session on "$taskName". Today total: $todayTotal sessions.';

    return chat(message, systemPrompt: systemPrompt, temperature: 0.7);
  }

  /// Context-aware chat: injects real app data into system prompt
  /// so AI responses are grounded in the user's actual situation
  Future<String> contextAwareChat(
    String message, {
    required Map<String, dynamic> appContext,
    double temperature = 0.7,
  }) async {
    final events = appContext['events'] as List<Map<String, String>>? ?? [];
    final habits = appContext['habits'] as List<Map<String, dynamic>>? ?? [];
    final goals = appContext['goals'] as List<Map<String, dynamic>>? ?? [];
    final pomo = appContext['pomodoroCount'] as int? ?? 0;
    final focus = appContext['focusMinutes'] as int? ?? 0;
    final completion = appContext['completionRate'] as double? ?? 0;
    final usageDays = appContext['usageDays'] as int? ?? 0;

    final buffer = StringBuffer();
    buffer.writeln(
      'You are a smart productivity assistant built into the "Tempo" app.',
    );
    buffer.writeln(
      'You have full access to the user\'s real-time app data below.',
    );
    buffer.writeln(
      'Always respond in Chinese. Be concise, warm, and actionable.',
    );
    buffer.writeln(
      'Reference the user\'s ACTUAL data when relevant — do not make up numbers.',
    );
    buffer.writeln('');
    buffer.writeln('=== 用户今日数据 ===');
    buffer.writeln('使用天数: $usageDays 天');
    buffer.writeln('番茄钟: $pomo 个 | 专注: $focus 分钟');
    buffer.writeln('任务完成率: ${(completion * 100).toStringAsFixed(0)}%');

    if (events.isNotEmpty) {
      buffer.writeln('');
      buffer.writeln('今日日程 (${events.length}项):');
      for (final e in events) {
        final done = e['done'] == 'true' ? '✅' : '⬜';
        buffer.writeln('  $done ${e['time']} ${e['title']}');
      }
    }

    if (habits.isNotEmpty) {
      buffer.writeln('');
      buffer.writeln('习惯打卡:');
      for (final h in habits) {
        final done = h['todayDone'] == true ? '✅' : '⬜';
        buffer.writeln('  $done ${h['title']} (连续${h['streak']}天)');
      }
    }

    if (goals.isNotEmpty) {
      buffer.writeln('');
      buffer.writeln('目标:');
      for (final g in goals) {
        final pct = ((g['progress'] as double? ?? 0) * 100).toStringAsFixed(0);
        buffer.writeln('  ${g['title']} — $pct%');
      }
    }

    buffer.writeln('');
    buffer.writeln('=== 能力 ===');
    buffer.writeln('你可以帮用户：分析日程安排、建议时间规划、鼓励打气、拆解任务、习惯建议、目标复盘、效率建议。');
    buffer.writeln('如果用户问到和日程/习惯/目标相关的问题，直接引用上面的真实数据回答。');

    return chat(
      message,
      systemPrompt: buffer.toString(),
      temperature: temperature,
    );
  }
}
