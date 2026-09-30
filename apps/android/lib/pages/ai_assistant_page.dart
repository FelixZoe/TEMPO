import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../theme/miui_theme.dart';
import '../services/deepseek_service.dart';
import '../providers/app_provider.dart';
import '../models/models.dart';
import '../services/auth_service.dart';

/// DeepSeek AI Task Assistant Page
class AIAssistantPage extends StatefulWidget {
  const AIAssistantPage({super.key});

  @override
  State<AIAssistantPage> createState() => _AIAssistantPageState();
}

class _AIAssistantPageState extends State<AIAssistantPage> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  final List<_ChatMessage> _messages = [];
  bool _loading = false;
  bool _showApiKeyInput = false;
  final _apiKeyController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _checkApiKey();
  }

  void _checkApiKey() {
    if (!DeepSeekService().hasApiKey) {
      setState(() => _showApiKeyInput = true);
    } else {
      _addSystemMessage(
        'AI 助手已连接你的Tempo数据。试试：\n\n'
        '📋 "今天还剩什么没做" — 分析日程\n'
        '💪 "鼓励" — 基于真实数据打气\n'
        '📊 "帮我复盘今天" — 效率分析\n'
        '✂️ 输入任务描述 — AI拆解并添加日程\n'
        '🎯 "目标进展" — 查看目标建议',
      );
    }
  }

  void _addSystemMessage(String text) {
    _messages.add(_ChatMessage(text: text, isUser: false, isSystem: true));
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    _apiKeyController.dispose();
    super.dispose();
  }

  Future<void> _saveApiKey() async {
    final key = _apiKeyController.text.trim();
    if (key.isEmpty) return;
    await DeepSeekService.setApiKey(key);
    setState(() => _showApiKeyInput = false);
    _checkApiKey();
  }

  Future<void> _sendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _loading) return;
    if (!AuthService().requireLogin(context, action: '使用 AI 助手')) return;

    setState(() {
      _messages.add(_ChatMessage(text: text, isUser: true));
      _loading = true;
    });
    _controller.clear();
    _scrollToBottom();

    try {
      final provider = context.read<AppProvider>();
      final appContext = _buildAppContext(provider);

      if (text == '鼓励' || text.contains('鼓励我') || text.contains('打气')) {
        final result = await DeepSeekService().dailyEncouragement(
          pomodoroCount: provider.pomodoroCount,
          focusMinutes: provider.focusMinutes,
          completedTasks: provider.events.where((e) => e.isCompleted).length,
          totalTasks: provider.events.length,
          streak: 0,
        );
        _addResponse(result);
      } else if (_looksLikeTask(text)) {
        // Task decomposition for task-like input
        final tasks = await DeepSeekService().decomposeTask(text);
        if (tasks.length > 1 && !tasks[0].startsWith('[Error]')) {
          final taskList = tasks
              .asMap()
              .entries
              .map((e) => '${e.key + 1}. ${e.value}')
              .join('\n');
          _addResponse('已为你拆解任务：\n\n$taskList\n\n点击下方按钮可以一键添加到日程。');
          setState(() {
            _messages.last.subtasks = tasks;
          });
        } else if (tasks[0].startsWith('[Error]')) {
          _addResponse(tasks[0].replaceFirst('[Error] ', ''));
        } else {
          final result = await DeepSeekService().contextAwareChat(
            text,
            appContext: appContext,
          );
          _addResponse(result);
        }
      } else {
        // Context-aware chat — AI sees all real app data
        final result = await DeepSeekService().contextAwareChat(
          text,
          appContext: appContext,
        );
        _addResponse(result);
      }
    } catch (e) {
      _addResponse('出错了: $e');
    }

    setState(() => _loading = false);
    _scrollToBottom();
  }

  void _addResponse(String text) {
    setState(() {
      _messages.add(_ChatMessage(text: text, isUser: false));
    });
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  /// Build real-time app context for AI
  Map<String, dynamic> _buildAppContext(AppProvider provider) {
    return {
      'pomodoroCount': provider.pomodoroCount,
      'focusMinutes': provider.focusMinutes,
      'completionRate': provider.completionRate,
      'usageDays': provider.usageDays,
      'events': provider.events
          .map(
            (e) => {
              'title': e.title,
              'time': '${e.time}-${e.endTime}',
              'category': e.category,
              'done': e.isCompleted.toString(),
            },
          )
          .toList(),
      'habits': provider.habits
          .map(
            (h) => {
              'title': h.title,
              'streak': h.streak,
              'todayDone': h.todayCompleted,
            },
          )
          .toList(),
      'goals': provider.goals
          .map(
            (g) => {
              'title': g.title,
              'progress': g.progress,
              'target': g.target,
            },
          )
          .toList(),
    };
  }

  /// Heuristic: does this text look like a task to decompose?
  bool _looksLikeTask(String text) {
    // Short commands / questions are NOT tasks
    if (text.length < 6) return false;
    // Questions are not tasks
    if (text.contains('?') ||
        text.contains('？') ||
        text.contains('吗') ||
        text.contains('呢'))
      return false;
    // Common chat prefixes
    final chatPrefixes = [
      '帮我',
      '今天',
      '分析',
      '复盘',
      '建议',
      '怎么',
      '为什么',
      '什么',
      '目标',
      '习惯',
      '日程',
    ];
    for (final p in chatPrefixes) {
      if (text.startsWith(p)) return false;
    }
    // Likely a task: contains action verbs and is medium length
    final taskVerbs = [
      '准备',
      '完成',
      '写',
      '做',
      '开发',
      '设计',
      '整理',
      '学习',
      '看',
      '读',
      '练',
    ];
    for (final v in taskVerbs) {
      if (text.contains(v) && text.length > 8) return true;
    }
    return false;
  }

  void _addSubtasksToSchedule(List<String> tasks) {
    final provider = context.read<AppProvider>();
    final now = TimeOfDay.now();
    for (int i = 0; i < tasks.length; i++) {
      final startHour = (now.hour + i) % 24;
      provider.addEvent(
        ScheduleEvent(
          id: 'ai_${DateTime.now().millisecondsSinceEpoch}_$i',
          title: tasks[i],
          description: 'AI generated subtask',
          time:
              '${startHour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}',
          endTime:
              '${((startHour + 1) % 24).toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}',
          category: '工作',
          accentColor: MiuiColors.purple,
        ),
      );
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('已添加 ${tasks.length} 个子任务到今日日程'),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF667EEA), Color(0xFF764BA2)],
                ),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.auto_awesome_rounded,
                size: 18,
                color: Colors.white,
              ),
            ),
            const SizedBox(width: 10),
            Text(
              'AI 任务助手',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: colors.textPrimary,
              ),
            ),
          ],
        ),
        backgroundColor: colors.background,
        elevation: 0,
        scrolledUnderElevation: 0,
        iconTheme: IconThemeData(color: colors.textPrimary),
        actions: [
          IconButton(
            icon: Icon(
              Icons.key_rounded,
              size: 20,
              color: colors.textSecondary,
            ),
            onPressed: () =>
                setState(() => _showApiKeyInput = !_showApiKeyInput),
            tooltip: 'API Key',
          ),
        ],
      ),
      body: Column(
        children: [
          // API Key input panel
          if (_showApiKeyInput) _buildApiKeyPanel(colors),

          // Messages
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              itemCount: _messages.length,
              itemBuilder: (context, index) =>
                  _buildMessage(_messages[index], colors),
            ),
          ),

          // Loading indicator
          if (_loading)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Row(
                children: [
                  SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: MiuiColors.purple,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'AI 思考中...',
                    style: TextStyle(fontSize: 13, color: colors.textSecondary),
                  ),
                ],
              ),
            ),

          // Input bar
          _buildInputBar(colors),
        ],
      ),
    );
  }

  Widget _buildApiKeyPanel(AppColors colors) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: MiuiColors.purple.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.vpn_key_rounded, size: 16, color: MiuiColors.purple),
              const SizedBox(width: 8),
              Text(
                'DeepSeek API Key',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: colors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Visit platform.deepseek.com to get free API key (5M tokens)',
            style: TextStyle(fontSize: 11, color: colors.textTertiary),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: colors.card,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: TextField(
                    controller: _apiKeyController,
                    style: TextStyle(fontSize: 13, color: colors.textPrimary),
                    decoration: InputDecoration(
                      hintText: 'sk-...',
                      hintStyle: TextStyle(
                        color: colors.textTertiary,
                        fontSize: 13,
                      ),
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                    obscureText: true,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: _saveApiKey,
                style: ElevatedButton.styleFrom(
                  backgroundColor: MiuiColors.purple,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  elevation: 0,
                ),
                child: const Text(
                  'Save',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMessage(_ChatMessage msg, AppColors colors) {
    if (msg.isSystem) {
      return Container(
        margin: const EdgeInsets.symmetric(vertical: 8),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              MiuiColors.purple.withValues(alpha: 0.08),
              MiuiColors.blue.withValues(alpha: 0.05),
            ],
          ),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: MiuiColors.purple.withValues(alpha: 0.1)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              Icons.auto_awesome_rounded,
              size: 16,
              color: MiuiColors.purple,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                msg.text,
                style: TextStyle(
                  fontSize: 13.5,
                  color: colors.textSecondary,
                  height: 1.5,
                ),
              ),
            ),
          ],
        ),
      );
    }

    final isUser = msg.isUser;
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.78,
        ),
        margin: const EdgeInsets.symmetric(vertical: 5),
        child: Column(
          crossAxisAlignment: isUser
              ? CrossAxisAlignment.end
              : CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: isUser ? MiuiColors.primary : colors.surface,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(16),
                  topRight: const Radius.circular(16),
                  bottomLeft: Radius.circular(isUser ? 16 : 4),
                  bottomRight: Radius.circular(isUser ? 4 : 16),
                ),
              ),
              child: SelectableText(
                msg.text,
                style: TextStyle(
                  fontSize: 14,
                  color: isUser ? Colors.white : colors.textPrimary,
                  height: 1.5,
                ),
              ),
            ),
            // Add to schedule button for task decomposition
            if (!isUser && msg.subtasks != null && msg.subtasks!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Row(
                  children: [
                    _ActionChip(
                      icon: Icons.add_task_rounded,
                      label: '添加到日程',
                      color: MiuiColors.green,
                      onTap: () => _addSubtasksToSchedule(msg.subtasks!),
                    ),
                    const SizedBox(width: 8),
                    _ActionChip(
                      icon: Icons.copy_rounded,
                      label: '复制',
                      color: MiuiColors.blue,
                      onTap: () {
                        Clipboard.setData(ClipboardData(text: msg.text));
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: const Text('已复制'),
                            behavior: SnackBarBehavior.floating,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            duration: const Duration(seconds: 1),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildInputBar(AppColors colors) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        16,
        10,
        16,
        MediaQuery.of(context).padding.bottom + 10,
      ),
      decoration: BoxDecoration(
        color: colors.card,
        border: Border(
          top: BorderSide(
            color: colors.divider.withValues(alpha: 0.3),
            width: 0.5,
          ),
        ),
      ),
      child: Row(
        children: [
          // Quick prompts
          GestureDetector(
            onTap: () => _showQuickPrompts(colors),
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: colors.surface,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.bolt_rounded,
                size: 20,
                color: MiuiColors.purple,
              ),
            ),
          ),
          const SizedBox(width: 10),
          // Text input
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: colors.surface,
                borderRadius: BorderRadius.circular(22),
              ),
              child: TextField(
                controller: _controller,
                style: TextStyle(fontSize: 14, color: colors.textPrimary),
                decoration: InputDecoration(
                  hintText: '描述你的任务...',
                  hintStyle: TextStyle(
                    color: colors.textTertiary,
                    fontSize: 14,
                  ),
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(vertical: 10),
                ),
                onSubmitted: (_) => _sendMessage(),
                textInputAction: TextInputAction.send,
              ),
            ),
          ),
          const SizedBox(width: 10),
          GestureDetector(
            onTap: _sendMessage,
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF667EEA), Color(0xFF764BA2)],
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.send_rounded,
                size: 20,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showQuickPrompts(AppColors colors) {
    final prompts = [
      {
        'icon': Icons.today_rounded,
        'label': '今天还剩什么',
        'text': '今天还有哪些任务没完成？帮我分析一下优先级',
      },
      {'icon': Icons.emoji_emotions_rounded, 'label': '鼓励打气', 'text': '鼓励'},
      {
        'icon': Icons.analytics_rounded,
        'label': '复盘今天',
        'text': '帮我复盘今天的效率表现，给出改进建议',
      },
      {
        'icon': Icons.flag_rounded,
        'label': '目标进展',
        'text': '分析一下我的目标完成情况，给出下一步建议',
      },
      {
        'icon': Icons.self_improvement_rounded,
        'label': '习惯建议',
        'text': '看看我的习惯打卡情况，给出坚持建议',
      },
      {'icon': Icons.checklist_rounded, 'label': '拆解任务', 'text': '帮我拆解这个任务：'},
      {
        'icon': Icons.schedule_rounded,
        'label': '规划明天',
        'text': '根据我今天的完成情况，帮我规划明天的安排',
      },
    ];

    showModalBottomSheet(
      context: context,
      // Use the root navigator so the sheet never touches the current
      // ColorOSPageRoute's secondaryAnimation — prevents the brief black
      // flash when opening on top of a swipe-back page (v2.10.6 fix).
      useRootNavigator: true,
      backgroundColor: colors.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: colors.textTertiary.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                '快捷指令',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: colors.textPrimary,
                ),
              ),
              const SizedBox(height: 14),
              ...prompts.map(
                (p) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: MiuiColors.purple.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      p['icon'] as IconData,
                      size: 20,
                      color: MiuiColors.purple,
                    ),
                  ),
                  title: Text(
                    p['label'] as String,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: colors.textPrimary,
                    ),
                  ),
                  onTap: () {
                    Navigator.pop(ctx);
                    final t = p['text'] as String;
                    _controller.text = t;
                    // Auto-send unless it's a prefix that needs user input
                    if (!t.endsWith('：')) _sendMessage();
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ChatMessage {
  final String text;
  final bool isUser;
  final bool isSystem;
  List<String>? subtasks;

  _ChatMessage({
    required this.text,
    required this.isUser,
    this.isSystem = false,
  });
}

class _ActionChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ActionChip({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
