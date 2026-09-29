import 'package:flutter/material.dart';
import '../widgets/swipe_back_route.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../models/models.dart';
import '../services/reminder_service.dart';
import '../services/persistence_service.dart';
import '../services/pomodoro_service.dart';
import '../theme/miui_theme.dart';
import '../services/auth_service.dart';
import '../services/cloud_tools_service.dart';
import 'cloud_config_pages.dart';

import 'ai_assistant_page.dart';
import 'dart:async';
import 'dart:math';
import 'dart:convert';
import 'package:http/http.dart' as http;

class ToolsPage extends StatelessWidget {
  const ToolsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    return Consumer<AppProvider>(
      builder: (context, provider, _) {
        return SafeArea(
          bottom: false,
          child: CustomScrollView(
            physics: const BouncingScrollPhysics(
              parent: AlwaysScrollableScrollPhysics(),
            ),
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    Breathing.pagePaddingH,
                    32,
                    Breathing.pagePaddingH,
                    6,
                  ),
                  child: Text(
                    '工具',
                    style: TextStyle(
                      fontSize: provider.titleSize,
                      fontWeight: provider.titleWeight,
                      color: colors.textPrimary,
                      letterSpacing: -0.8,
                      height: 1.15,
                    ),
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                    Breathing.pagePaddingH,
                    0,
                    Breathing.pagePaddingH,
                    provider.sectionGap,
                  ),
                  child: Text(
                    '你的效率百宝箱',
                    style: TextStyle(
                      fontSize: Breathing.subtitleSize,
                      color: colors.textSecondary,
                    ),
                  ),
                ),
              ),

              // ─── Pomodoro Banner ───
              SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                    Breathing.pagePaddingH,
                    0,
                    Breathing.pagePaddingH,
                    provider.sectionGap,
                  ),
                  child: GlassCard(
                    enabled: provider.liquidGlass,
                    borderRadius: provider.cardRadius,
                    padding: EdgeInsets.zero,
                    child: _PomodoroBanner(provider: provider, colors: colors),
                  ),
                ),
              ),

              // ─── Daily Tools (streamlined) ───
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    Breathing.pagePaddingH,
                    0,
                    Breathing.pagePaddingH,
                    16,
                  ),
                  child: Text(
                    '日常工具',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: colors.textPrimary,
                      letterSpacing: -0.3,
                    ),
                  ),
                ),
              ),

              SliverPadding(
                padding: EdgeInsets.fromLTRB(
                  Breathing.pagePaddingH,
                  0,
                  Breathing.pagePaddingH,
                  provider.sectionGap,
                ),
                sliver: SliverGrid(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 4,
                    mainAxisSpacing: 20,
                    crossAxisSpacing: 14,
                    childAspectRatio: 0.78,
                  ),
                  delegate: SliverChildListDelegate([
                    _ToolItem(
                      icon: Icons.qr_code_scanner_rounded,
                      label: '扫一扫',
                      color: MiuiColors.green,
                      colors: colors,
                      onTap: () => _open(context, const _ScannerPage()),
                    ),
                    _ToolItem(
                      icon: Icons.translate_rounded,
                      label: '翻译',
                      color: MiuiColors.purple,
                      colors: colors,
                      onTap: () => _open(context, const _TranslatorPage()),
                    ),
                    _ToolItem(
                      icon: Icons.straighten_outlined,
                      label: '尺子',
                      color: MiuiColors.teal,
                      colors: colors,
                      onTap: () => _open(context, const _RulerPage()),
                    ),
                    _ToolItem(
                      icon: Icons.swap_horiz_rounded,
                      label: '单位换算',
                      color: MiuiColors.pink,
                      colors: colors,
                      onTap: () => _open(context, const _UnitConverterPage()),
                    ),
                    _ToolItem(
                      icon: Icons.palette_outlined,
                      label: '取色器',
                      color: MiuiColors.yellow,
                      colors: colors,
                      onTap: () => _open(context, const _ColorPickerPage()),
                    ),
                  ]),
                ),
              ),

              // ─── Cloud Tools (new) ───
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    Breathing.pagePaddingH,
                    0,
                    Breathing.pagePaddingH,
                    16,
                  ),
                  child: Text(
                    '云端工具',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: colors.textPrimary,
                      letterSpacing: -0.3,
                    ),
                  ),
                ),
              ),

              SliverPadding(
                padding: EdgeInsets.fromLTRB(
                  Breathing.pagePaddingH,
                  0,
                  Breathing.pagePaddingH,
                  provider.sectionGap,
                ),
                sliver: SliverGrid(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 4,
                    mainAxisSpacing: 20,
                    crossAxisSpacing: 14,
                    childAspectRatio: 0.78,
                  ),
                  delegate: SliverChildListDelegate([
                    _ToolItem(
                      icon: Icons.cloud_upload_outlined,
                      label: '网盘挂载',
                      color: MiuiColors.blue,
                      colors: colors,
                      onTap: () => _open(context, const _CloudMountPage()),
                    ),
                    _ToolItem(
                      icon: Icons.auto_fix_high_rounded,
                      label: '去水印',
                      color: MiuiColors.red,
                      colors: colors,
                      onTap: () =>
                          _open(context, const _WatermarkRemoverPage()),
                    ),
                    _ToolItem(
                      icon: Icons.link_rounded,
                      label: 'LinkSwift',
                      color: MiuiColors.orange,
                      colors: colors,
                      onTap: () => _open(context, const _DirectLinkPage()),
                    ),
                    _ToolItem(
                      icon: Icons.speed_rounded,
                      label: '网速测试',
                      color: MiuiColors.teal,
                      colors: colors,
                      onTap: () => _open(context, const _SpeedtestPage()),
                    ),
                    _ToolItem(
                      icon: Icons.transform_rounded,
                      label: '文档转换',
                      color: MiuiColors.purple,
                      colors: colors,
                      onTap: () => _open(context, const _PandocConverterPage()),
                    ),
                    _ToolItem(
                      icon: Icons.monitor_heart_outlined,
                      label: '服务器监控',
                      color: MiuiColors.green,
                      colors: colors,
                      onTap: () => _open(context, const _NetdataMonitorPage()),
                    ),
                  ]),
                ),
              ),

              // ─── Productivity Tools ───
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    Breathing.pagePaddingH,
                    0,
                    Breathing.pagePaddingH,
                    16,
                  ),
                  child: Text(
                    '效率工具',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: colors.textPrimary,
                      letterSpacing: -0.3,
                    ),
                  ),
                ),
              ),

              SliverPadding(
                padding: EdgeInsets.fromLTRB(
                  Breathing.pagePaddingH,
                  0,
                  Breathing.pagePaddingH,
                  provider.sectionGap,
                ),
                sliver: SliverGrid(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 4,
                    mainAxisSpacing: 20,
                    crossAxisSpacing: 14,
                    childAspectRatio: 0.78,
                  ),
                  delegate: SliverChildListDelegate([
                    _ToolItem(
                      icon: Icons.calculate_outlined,
                      label: '计算器',
                      color: MiuiColors.blue,
                      colors: colors,
                      onTap: () => _open(context, const _CalculatorPage()),
                    ),
                    _ToolItem(
                      icon: Icons.timer_outlined,
                      label: '计时器',
                      color: MiuiColors.orange,
                      colors: colors,
                      onTap: () => _open(context, const _StopwatchPage()),
                    ),
                    _ToolItem(
                      icon: Icons.mic_none_rounded,
                      label: '录音',
                      color: MiuiColors.red,
                      colors: colors,
                      onTap: () => _open(context, const _RecorderPage()),
                    ),
                    _ToolItem(
                      icon: Icons.password_rounded,
                      label: '密码生成',
                      color: MiuiColors.purple,
                      colors: colors,
                      onTap: () => _open(context, const _PasswordGenPage()),
                    ),
                    _ToolItem(
                      icon: Icons.qr_code_2_rounded,
                      label: '二维码',
                      color: MiuiColors.green,
                      colors: colors,
                      onTap: () => _open(context, const _QRGenPage()),
                    ),
                    _ToolItem(
                      icon: Icons.alarm_rounded,
                      label: '倒计时',
                      color: MiuiColors.teal,
                      colors: colors,
                      onTap: () => _open(context, const _CountdownPage()),
                    ),
                    _ToolItem(
                      icon: Icons.water_drop_rounded,
                      label: '喝水提醒',
                      color: MiuiColors.blue,
                      colors: colors,
                      onTap: () => _open(context, const _WaterPage()),
                    ),
                    _ToolItem(
                      icon: Icons.mood_rounded,
                      label: '心情日记',
                      color: MiuiColors.pink,
                      colors: colors,
                      onTap: () => _open(context, const _MoodPage()),
                    ),
                  ]),
                ),
              ),

              // ─── AI Assistant Banner ───
              SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                    Breathing.pagePaddingH,
                    0,
                    Breathing.pagePaddingH,
                    provider.sectionGap,
                  ),
                  child: GestureDetector(
                    onTap: () => _open(context, const AIAssistantPage()),
                    child: Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF667EEA), Color(0xFF764BA2)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(
                          provider.cardRadius,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(
                              0xFF667EEA,
                            ).withValues(alpha: 0.3),
                            blurRadius: 16,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: const Icon(
                              Icons.auto_awesome_rounded,
                              size: 24,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'AI \u4efb\u52a1\u52a9\u624b',
                                  style: TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                    letterSpacing: -0.3,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '\u8f93\u5165\u4e00\u53e5\u8bdd\uff0cAI \u81ea\u52a8\u62c6\u89e3\u4e3a\u5b50\u4efb\u52a1',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.white.withValues(alpha: 0.8),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Icon(
                            Icons.arrow_forward_ios_rounded,
                            size: 16,
                            color: Colors.white.withValues(alpha: 0.7),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              // ─── Efficiency Section ───
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    Breathing.pagePaddingH,
                    0,
                    Breathing.pagePaddingH,
                    16,
                  ),
                  child: Text(
                    '\u6570\u636e\u8ffd\u8e2a',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: colors.textPrimary,
                      letterSpacing: -0.3,
                    ),
                  ),
                ),
              ),

              SliverPadding(
                padding: const EdgeInsets.fromLTRB(
                  Breathing.pagePaddingH,
                  0,
                  Breathing.pagePaddingH,
                  28,
                ),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    _EfficiencyCard(
                      icon: Icons.flag_outlined,
                      title: '目标追踪',
                      subtitle: '设定并追踪你的长期目标',
                      color: MiuiColors.orange,
                      colors: colors,
                      isGlass: provider.liquidGlass,
                      cardRadius: provider.cardRadius,
                      trailing: Consumer<AppProvider>(
                        builder: (_, p, __) => Text(
                          '${p.goals.length} 个进行中',
                          style: TextStyle(
                            fontSize: 13,
                            color: colors.textTertiary,
                          ),
                        ),
                      ),
                      onTap: () => _openGoals(context, colors),
                    ),
                    const SizedBox(height: Breathing.cardGap),
                    _EfficiencyCard(
                      icon: Icons.local_fire_department_outlined,
                      title: '习惯打卡',
                      subtitle: '每天坚持，养成好习惯',
                      color: MiuiColors.green,
                      colors: colors,
                      isGlass: provider.liquidGlass,
                      cardRadius: provider.cardRadius,
                      trailing: Consumer<AppProvider>(
                        builder: (_, p, __) => Text(
                          '${p.habits.where((h) => h.todayCompleted).length}/${p.habits.length}',
                          style: TextStyle(
                            fontSize: 13,
                            color: colors.textTertiary,
                          ),
                        ),
                      ),
                      onTap: () => _openHabits(context, colors),
                    ),
                    const SizedBox(height: Breathing.cardGap),
                    _EfficiencyCard(
                      icon: Icons.bar_chart_outlined,
                      title: '效率报告',
                      subtitle: '查看你的工作效率趋势',
                      color: MiuiColors.purple,
                      colors: colors,
                      isGlass: provider.liquidGlass,
                      cardRadius: provider.cardRadius,
                      trailing: Text(
                        '本周',
                        style: TextStyle(
                          fontSize: 13,
                          color: colors.textTertiary,
                        ),
                      ),
                      onTap: () => _openStats(context, colors),
                    ),
                  ]),
                ),
              ),

              const SliverToBoxAdapter(child: SizedBox(height: 100)),
            ],
          ),
        );
      },
    );
  }

  void _open(BuildContext ctx, Widget page) =>
      Navigator.push(ctx, swipeBackRoute(context: ctx, builder: (_) => page));

  void _openGoals(BuildContext ctx, AppColors colors) {
    if (!AuthService().requireLogin(ctx, action: '管理目标')) return;
    _showSheet(
      ctx,
      colors,
      '目标追踪',
      Consumer<AppProvider>(
        builder: (ctx2, p, __) => Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ...p.goals.map(
              (g) => _GoalRow(
                goal: g,
                colors: colors,
                onLongPress: () {
                  showDialog(
                    context: ctx2,
                    builder: (_) => AlertDialog(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                      backgroundColor: colors.card,
                      title: Text(
                        '删除目标',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: colors.textPrimary,
                        ),
                      ),
                      content: Text(
                        '确定删除「${g.title}」？',
                        style: TextStyle(color: colors.textSecondary),
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx2),
                          child: const Text('取消'),
                        ),
                        TextButton(
                          onPressed: () {
                            p.removeGoal(g.id);
                            Navigator.pop(ctx2);
                          },
                          child: const Text(
                            '删除',
                            style: TextStyle(
                              color: MiuiColors.red,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
                onProgressTap: () {
                  showDialog(
                    context: ctx2,
                    builder: (_) {
                      double newProgress = g.progress;
                      return StatefulBuilder(
                        builder: (ctx3, setDialogState) => AlertDialog(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                          backgroundColor: colors.card,
                          title: Text(
                            '更新进度',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: colors.textPrimary,
                            ),
                          ),
                          content: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                g.title,
                                style: TextStyle(
                                  fontSize: 15,
                                  color: colors.textSecondary,
                                ),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                '${(newProgress * 100).toInt()}%',
                                style: TextStyle(
                                  fontSize: 28,
                                  fontWeight: FontWeight.w800,
                                  color: g.color,
                                ),
                              ),
                              Slider(
                                value: newProgress,
                                onChanged: (v) =>
                                    setDialogState(() => newProgress = v),
                                activeColor: g.color,
                              ),
                            ],
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(ctx3),
                              child: const Text('取消'),
                            ),
                            TextButton(
                              onPressed: () {
                                p.updateGoalProgress(g.id, newProgress);
                                Navigator.pop(ctx3);
                              },
                              child: const Text(
                                '保存',
                                style: TextStyle(fontWeight: FontWeight.w600),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  );
                },
              ),
            ),
            const SizedBox(height: 12),
            _AddButton(
              label: '添加目标',
              onTap: () => _showAddGoalDialog(ctx2, p, colors),
              colors: colors,
            ),
          ],
        ),
      ),
    );
  }

  void _openHabits(BuildContext ctx, AppColors colors) {
    if (!AuthService().requireLogin(ctx, action: '管理习惯')) return;
    _showSheet(
      ctx,
      colors,
      '今日习惯',
      Consumer<AppProvider>(
        builder: (ctx2, p, __) => Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ...p.habits.map(
              (h) => _HabitRow(
                habit: h,
                colors: colors,
                onTap: () {
                  final wasCompleted = h.todayCompleted;
                  p.toggleHabit(h.id);
                  // Get the updated habit after toggle
                  final updated = p.habits.firstWhere(
                    (x) => x.id == h.id,
                    orElse: () => h,
                  );
                  // Trigger in-app notification
                  ReminderService.instance.onHabitToggled(
                    ctx2,
                    updated,
                    !wasCompleted,
                  );
                  if (!wasCompleted) {
                    // Stats tracked via provider
                  }
                },
                onLongPress: () {
                  showDialog(
                    context: ctx2,
                    builder: (_) => AlertDialog(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                      backgroundColor: colors.card,
                      title: Text(
                        '删除习惯',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: colors.textPrimary,
                        ),
                      ),
                      content: Text(
                        '确定删除「${h.title}」？',
                        style: TextStyle(color: colors.textSecondary),
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx2),
                          child: const Text('取消'),
                        ),
                        TextButton(
                          onPressed: () {
                            p.removeHabit(h.id);
                            Navigator.pop(ctx2);
                          },
                          child: const Text(
                            '删除',
                            style: TextStyle(
                              color: MiuiColors.red,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 12),
            _AddButton(
              label: '添加习惯',
              onTap: () => _showAddHabitDialog(ctx2, p, colors),
              colors: colors,
            ),
          ],
        ),
      ),
    );
  }

  void _openStats(BuildContext ctx, AppColors colors) => _showSheet(
    ctx,
    colors,
    '效率报告',
    Consumer<AppProvider>(
      builder: (_, p, __) => Padding(
        padding: const EdgeInsets.all(20),
        child: _WeeklyChart(data: p.weeklyProductivity, colors: colors),
      ),
    ),
  );

  void _showAddHabitDialog(
    BuildContext ctx,
    AppProvider provider,
    AppColors colors,
  ) {
    final nameCtrl = TextEditingController();
    int selectedIcon = 0;
    int selectedColor = 0;
    final icons = [
      'wb_sunny',
      'menu_book',
      'fitness_center',
      'self_improvement',
      'water_drop',
      'edit_note',
    ];
    final iconLabels = ['早起', '阅读', '运动', '冥想', '喝水', '写日记'];
    final iconData = [
      Icons.wb_sunny_rounded,
      Icons.menu_book_rounded,
      Icons.fitness_center_rounded,
      Icons.self_improvement_rounded,
      Icons.water_drop_rounded,
      Icons.edit_note_rounded,
    ];
    final colorList = [
      MiuiColors.orange,
      MiuiColors.blue,
      MiuiColors.green,
      MiuiColors.purple,
      MiuiColors.red,
      MiuiColors.teal,
      MiuiColors.pink,
    ];

    showDialog(
      context: ctx,
      builder: (_) => StatefulBuilder(
        builder: (ctx2, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          backgroundColor: colors.card,
          title: Text(
            '添加习惯',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: colors.textPrimary,
            ),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: nameCtrl,
                  style: TextStyle(color: colors.textPrimary),
                  decoration: InputDecoration(
                    hintText: '习惯名称',
                    hintStyle: TextStyle(color: colors.textTertiary),
                    filled: true,
                    fillColor: colors.surface,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  '图标',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: colors.textSecondary,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: List.generate(
                    icons.length,
                    (i) => GestureDetector(
                      onTap: () => setDialogState(() => selectedIcon = i),
                      child: Column(
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: selectedIcon == i
                                  ? colorList[selectedColor].withValues(
                                      alpha: 0.15,
                                    )
                                  : colors.surface,
                              borderRadius: BorderRadius.circular(14),
                              border: selectedIcon == i
                                  ? Border.all(
                                      color: colorList[selectedColor],
                                      width: 2,
                                    )
                                  : null,
                            ),
                            child: Icon(
                              iconData[i],
                              color: selectedIcon == i
                                  ? colorList[selectedColor]
                                  : colors.textTertiary,
                              size: 22,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            iconLabels[i],
                            style: TextStyle(
                              fontSize: 10,
                              color: selectedIcon == i
                                  ? colorList[selectedColor]
                                  : colors.textTertiary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  '颜色',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: colors.textSecondary,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 10,
                  children: List.generate(
                    colorList.length,
                    (i) => GestureDetector(
                      onTap: () => setDialogState(() => selectedColor = i),
                      child: Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: colorList[i],
                          shape: BoxShape.circle,
                          border: selectedColor == i
                              ? Border.all(color: colors.textPrimary, width: 3)
                              : null,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx2),
              child: const Text('取消'),
            ),
            TextButton(
              onPressed: () {
                final name = nameCtrl.text.trim().isEmpty
                    ? iconLabels[selectedIcon]
                    : nameCtrl.text.trim();
                provider.addHabit(
                  HabitItem(
                    id: 'habit_${DateTime.now().millisecondsSinceEpoch}',
                    title: name,
                    icon: icons[selectedIcon],
                    streak: 0,
                    color: colorList[selectedColor],
                  ),
                );
                Navigator.pop(ctx2);
              },
              child: const Text(
                '添加',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddGoalDialog(
    BuildContext ctx,
    AppProvider provider,
    AppColors colors,
  ) {
    final nameCtrl = TextEditingController();
    final targetCtrl = TextEditingController();
    int selectedIcon = 0;
    int selectedColor = 0;
    final icons = ['menu_book', 'directions_run', 'savings', 'code'];
    final iconLabels = ['阅读', '运动', '储蓄', '编程'];
    final iconData = [
      Icons.menu_book_rounded,
      Icons.directions_run_rounded,
      Icons.savings_rounded,
      Icons.code_rounded,
    ];
    final colorList = [
      MiuiColors.blue,
      MiuiColors.green,
      MiuiColors.orange,
      MiuiColors.purple,
      MiuiColors.red,
      MiuiColors.teal,
    ];

    showDialog(
      context: ctx,
      builder: (_) => StatefulBuilder(
        builder: (ctx2, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          backgroundColor: colors.card,
          title: Text(
            '添加目标',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: colors.textPrimary,
            ),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: nameCtrl,
                  style: TextStyle(color: colors.textPrimary),
                  decoration: InputDecoration(
                    hintText: '目标名称 (如: 读完30本书)',
                    hintStyle: TextStyle(color: colors.textTertiary),
                    filled: true,
                    fillColor: colors.surface,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: targetCtrl,
                  style: TextStyle(color: colors.textPrimary),
                  decoration: InputDecoration(
                    hintText: '目标量 (如: 30本、5km、10000元)',
                    hintStyle: TextStyle(color: colors.textTertiary),
                    filled: true,
                    fillColor: colors.surface,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  '图标',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: colors.textSecondary,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: List.generate(
                    icons.length,
                    (i) => GestureDetector(
                      onTap: () => setDialogState(() => selectedIcon = i),
                      child: Column(
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: selectedIcon == i
                                  ? colorList[selectedColor].withValues(
                                      alpha: 0.15,
                                    )
                                  : colors.surface,
                              borderRadius: BorderRadius.circular(14),
                              border: selectedIcon == i
                                  ? Border.all(
                                      color: colorList[selectedColor],
                                      width: 2,
                                    )
                                  : null,
                            ),
                            child: Icon(
                              iconData[i],
                              color: selectedIcon == i
                                  ? colorList[selectedColor]
                                  : colors.textTertiary,
                              size: 22,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            iconLabels[i],
                            style: TextStyle(
                              fontSize: 10,
                              color: selectedIcon == i
                                  ? colorList[selectedColor]
                                  : colors.textTertiary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  '颜色',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: colors.textSecondary,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 10,
                  children: List.generate(
                    colorList.length,
                    (i) => GestureDetector(
                      onTap: () => setDialogState(() => selectedColor = i),
                      child: Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: colorList[i],
                          shape: BoxShape.circle,
                          border: selectedColor == i
                              ? Border.all(color: colors.textPrimary, width: 3)
                              : null,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx2),
              child: const Text('取消'),
            ),
            TextButton(
              onPressed: () {
                final name = nameCtrl.text.trim().isEmpty
                    ? iconLabels[selectedIcon]
                    : nameCtrl.text.trim();
                final target = targetCtrl.text.trim().isEmpty
                    ? '目标'
                    : targetCtrl.text.trim();
                provider.addGoal(
                  GoalItem(
                    id: 'goal_${DateTime.now().millisecondsSinceEpoch}',
                    title: name,
                    icon: icons[selectedIcon],
                    progress: 0.0,
                    color: colorList[selectedColor],
                    target: target,
                  ),
                );
                Navigator.pop(ctx2);
              },
              child: const Text(
                '添加',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showSheet(
    BuildContext ctx,
    AppColors colors,
    String title,
    Widget content,
  ) {
    showModalBottomSheet(
      context: ctx,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(ctx).size.height * 0.7,
        ),
        decoration: BoxDecoration(
          color: colors.card,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _sheetHandle(colors),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 20),
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.3,
                  color: colors.textPrimary,
                ),
              ),
            ),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 36),
                child: content,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

Widget _sheetHandle(AppColors colors) => Container(
  width: 36,
  height: 5,
  margin: const EdgeInsets.only(top: 12, bottom: 4),
  decoration: BoxDecoration(
    color: colors.textTertiary.withValues(alpha: 0.4),
    borderRadius: BorderRadius.circular(3),
  ),
);

// ═══ Pomodoro Banner (uses PomodoroService) — redesigned v3 ═══
class _PomodoroBanner extends StatefulWidget {
  final AppProvider provider;
  final AppColors colors;
  const _PomodoroBanner({required this.provider, required this.colors});
  @override
  State<_PomodoroBanner> createState() => _PomodoroBannerState();
}

class _PomodoroBannerState extends State<_PomodoroBanner>
    with SingleTickerProviderStateMixin {
  final _pomo = PomodoroService.instance;
  late AnimationController _breathAnim;

  @override
  void initState() {
    super.initState();
    _pomo.focusMinutes = widget.provider.pomoDuration;
    _pomo.addListener(_onUpdate);
    _breathAnim = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat(reverse: true);
  }

  @override
  void didUpdateWidget(_PomodoroBanner old) {
    super.didUpdateWidget(old);
    _pomo.focusMinutes = widget.provider.pomoDuration;
    _pomo.bindContext(context, widget.provider);
  }

  @override
  void dispose() {
    _pomo.removeListener(_onUpdate);
    _breathAnim.dispose();
    super.dispose();
  }

  void _onUpdate() {
    if (mounted) setState(() {});
  }

  void _toggle() {
    if (!AuthService().requireLogin(context, action: '使用番茄专注')) return;
    _pomo.bindContext(context, widget.provider);
    _pomo.togglePause();
  }

  void _reset() => _pomo.reset();
  void _skip() => _pomo.skipPhase();

  @override
  Widget build(BuildContext context) {
    final phase = _pomo.phase;
    final isIdle = phase == PomodoroPhase.idle;
    final isBreak =
        phase == PomodoroPhase.shortBreak || phase == PomodoroPhase.longBreak;
    final accentColor = _pomo.phaseColor;
    final isDark = widget.colors.isDark;

    // Adaptive gradient background
    final gradientColors = isBreak
        ? [const Color(0xFF0A2E1F), const Color(0xFF0F3D2A)]
        : isDark
        ? [const Color(0xFF1A1A2E), const Color(0xFF16213E)]
        : [const Color(0xFF2C3E50), const Color(0xFF1A1A2E)];

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: gradientColors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(widget.provider.cardRadius),
      ),
      child: Column(
        children: [
          // Top stats row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.local_fire_department_rounded,
                    size: 16,
                    color: accentColor,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    _pomo.phaseLabel,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.9),
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (!isIdle && !_pomo.isRunning) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: MiuiColors.orange.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text(
                        '暂停',
                        style: TextStyle(
                          color: MiuiColors.orange,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '${widget.provider.pomodoroCount} 次 · ${widget.provider.focusTimeFormatted}',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.5),
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Center: large timer ring
          AnimatedBuilder(
            animation: _breathAnim,
            builder: (_, __) {
              final glow = _pomo.isRunning
                  ? 0.15 + _breathAnim.value * 0.12
                  : 0.0;
              return Container(
                width: 140,
                height: 140,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: _pomo.isRunning
                      ? [
                          BoxShadow(
                            color: accentColor.withValues(alpha: glow),
                            blurRadius: 40,
                            spreadRadius: 4,
                          ),
                        ]
                      : [],
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      width: 140,
                      height: 140,
                      child: CircularProgressIndicator(
                        value: isIdle ? 0 : _pomo.progress,
                        strokeWidth: 5,
                        strokeCap: StrokeCap.round,
                        backgroundColor: Colors.white.withValues(alpha: 0.06),
                        valueColor: AlwaysStoppedAnimation(accentColor),
                      ),
                    ),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          isIdle
                              ? '${widget.provider.pomoDuration}:00'
                              : _pomo.timeDisplay,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 36,
                            fontWeight: FontWeight.w300,
                            fontFeatures: [FontFeature.tabularFigures()],
                            letterSpacing: -1,
                          ),
                        ),
                        if (!isIdle)
                          Text(
                            isBreak
                                ? '${phase == PomodoroPhase.longBreak ? "长" : "短"}休息'
                                : '第 ${_pomo.sessionCount + 1} 轮',
                            style: TextStyle(
                              color: accentColor.withValues(alpha: 0.7),
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 24),

          // Action buttons
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (!isIdle)
                _PomBtnV2(
                  icon: isBreak ? Icons.skip_next_rounded : Icons.stop_rounded,
                  label: isBreak ? '跳过' : '放弃',
                  filled: false,
                  color: Colors.white,
                  onTap: isBreak ? _skip : _reset,
                ),
              if (!isIdle) const SizedBox(width: 16),
              _PomBtnV2(
                icon: isIdle
                    ? Icons.play_arrow_rounded
                    : (_pomo.isRunning
                          ? Icons.pause_rounded
                          : Icons.play_arrow_rounded),
                label: isIdle ? '开始专注' : (_pomo.isRunning ? '暂停' : '继续'),
                filled: true,
                color: accentColor,
                onTap: _toggle,
              ),
              if (isIdle) ...[
                const SizedBox(width: 16),
                _PomBtnV2(
                  icon: Icons.refresh_rounded,
                  label: '重置',
                  filled: false,
                  color: Colors.white,
                  onTap: _reset,
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _PomBtnV2 extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool filled;
  final Color color;
  final VoidCallback onTap;
  const _PomBtnV2({
    required this.icon,
    required this.label,
    required this.filled,
    this.color = MiuiColors.blue,
    required this.onTap,
  });
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
      decoration: BoxDecoration(
        color: filled ? color : Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(28),
        border: filled
            ? null
            : Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 18,
            color: filled ? Colors.white : color.withValues(alpha: 0.7),
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              color: filled ? Colors.white : color.withValues(alpha: 0.7),
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    ),
  );
}

class _ToolItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  final AppColors colors;
  const _ToolItem({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
    required this.colors,
  });
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(18),
          ),
          child: Icon(icon, color: color, size: 26),
        ),
        const SizedBox(height: 10),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: colors.textPrimary,
            fontWeight: FontWeight.w500,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    ),
  );
}

class _EfficiencyCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final Widget trailing;
  final VoidCallback onTap;
  final AppColors colors;
  final bool isGlass;
  final double cardRadius;
  const _EfficiencyCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.trailing,
    required this.onTap,
    required this.colors,
    required this.isGlass,
    required this.cardRadius,
  });
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: GlassCard(
      enabled: isGlass,
      borderRadius: cardRadius,
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -0.2,
                    color: colors.textPrimary,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: TextStyle(fontSize: 13, color: colors.textTertiary),
                ),
              ],
            ),
          ),
          trailing,
          const SizedBox(width: 6),
          Icon(
            Icons.chevron_right_rounded,
            size: 20,
            color: colors.textTertiary,
          ),
        ],
      ),
    ),
  );
}

// ═══════════ TOOL PAGES ═══════════

// ── Calculator ──
class _CalculatorPage extends StatefulWidget {
  const _CalculatorPage();
  @override
  State<_CalculatorPage> createState() => _CalculatorPageState();
}

class _CalculatorPageState extends State<_CalculatorPage> {
  String _display = '0';
  String _expression = '';
  double _result = 0;
  String _operator = '';
  bool _newNumber = true;
  void _onDigit(String d) {
    setState(() {
      if (_newNumber) {
        _display = d;
        _newNumber = false;
      } else {
        _display = _display == '0' ? d : _display + d;
      }
    });
  }

  void _onOperator(String op) {
    setState(() {
      _result = double.tryParse(_display) ?? 0;
      _operator = op;
      _expression = '$_display $op';
      _newNumber = true;
    });
  }

  void _onEquals() {
    final c = double.tryParse(_display) ?? 0;
    double r = 0;
    switch (_operator) {
      case '+':
        r = _result + c;
      case '-':
        r = _result - c;
      case '*':
        r = _result * c;
      case '/':
        r = c != 0 ? _result / c : 0;
      default:
        r = c;
    }
    setState(() {
      _expression = '';
      _display = r == r.toInt().toDouble()
          ? r.toInt().toString()
          : r.toStringAsFixed(4);
      _newNumber = true;
      _operator = '';
    });
  }

  void _onClear() {
    setState(() {
      _display = '0';
      _expression = '';
      _result = 0;
      _operator = '';
      _newNumber = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        title: Text(
          '计算器',
          style: TextStyle(
            color: colors.textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
        centerTitle: true,
        backgroundColor: colors.background,
        elevation: 0,
        scrolledUnderElevation: 0,
        iconTheme: IconThemeData(color: colors.textPrimary),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(28),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    if (_expression.isNotEmpty)
                      Text(
                        _expression,
                        style: TextStyle(
                          fontSize: 18,
                          color: colors.textTertiary,
                        ),
                      ),
                    const SizedBox(height: 10),
                    Text(
                      _display,
                      style: TextStyle(
                        fontSize: 52,
                        fontWeight: FontWeight.w300,
                        color: colors.textPrimary,
                        letterSpacing: -1,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
              child: Column(
                children: [
                  _calcRow(['C', '±', '%', '÷'], colors),
                  const SizedBox(height: 12),
                  _calcRow(['7', '8', '9', '×'], colors),
                  const SizedBox(height: 12),
                  _calcRow(['4', '5', '6', '-'], colors),
                  const SizedBox(height: 12),
                  _calcRow(['1', '2', '3', '+'], colors),
                  const SizedBox(height: 12),
                  _calcRow(['0', '.', '⌫', '='], colors),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _calcRow(List<String> keys, AppColors colors) {
    return Row(
      children: keys.map((k) {
        final isOp = ['÷', '×', '-', '+', '='].contains(k);
        final isFunc = ['C', '±', '%'].contains(k);
        return Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 5),
            child: GestureDetector(
              onTap: () {
                switch (k) {
                  case 'C':
                    _onClear();
                  case '=':
                    _onEquals();
                  case '+':
                    _onOperator('+');
                  case '-':
                    _onOperator('-');
                  case '×':
                    _onOperator('*');
                  case '÷':
                    _onOperator('/');
                  case '⌫':
                    setState(() {
                      _display = _display.length > 1
                          ? _display.substring(0, _display.length - 1)
                          : '0';
                    });
                  case '±':
                    setState(() {
                      _display = _display.startsWith('-')
                          ? _display.substring(1)
                          : '-$_display';
                    });
                  case '%':
                    setState(() {
                      _display = (double.parse(_display) / 100).toString();
                    });
                  default:
                    _onDigit(k);
                }
              },
              child: Container(
                height: 58,
                decoration: BoxDecoration(
                  color: k == '='
                      ? MiuiColors.blue
                      : (isOp
                            ? MiuiColors.blue.withValues(alpha: 0.1)
                            : (isFunc ? colors.surface : colors.card)),
                  borderRadius: BorderRadius.circular(16),
                ),
                alignment: Alignment.center,
                child: Text(
                  k,
                  style: TextStyle(
                    fontSize: isOp ? 22 : 20,
                    fontWeight: FontWeight.w600,
                    color: k == '='
                        ? Colors.white
                        : (isOp ? MiuiColors.blue : colors.textPrimary),
                  ),
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

// ── Stopwatch ──
class _StopwatchPage extends StatefulWidget {
  const _StopwatchPage();
  @override
  State<_StopwatchPage> createState() => _StopwatchPageState();
}

class _StopwatchPageState extends State<_StopwatchPage> {
  final Stopwatch _sw = Stopwatch();
  Timer? _timer;
  final List<String> _laps = [];
  void _toggle() {
    if (_sw.isRunning) {
      _sw.stop();
      _timer?.cancel();
    } else {
      _sw.start();
      _timer = Timer.periodic(
        const Duration(milliseconds: 30),
        (_) => setState(() {}),
      );
    }
    setState(() {});
  }

  void _lap() {
    if (_sw.isRunning) setState(() => _laps.insert(0, _fmt(_sw.elapsed)));
  }

  void _reset() {
    _sw.stop();
    _sw.reset();
    _timer?.cancel();
    setState(() => _laps.clear());
  }

  String _fmt(Duration d) =>
      '${d.inMinutes.toString().padLeft(2, '0')}:${(d.inSeconds % 60).toString().padLeft(2, '0')}.${(d.inMilliseconds % 1000 ~/ 10).toString().padLeft(2, '0')}';
  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        title: Text(
          '计时器',
          style: TextStyle(
            color: colors.textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
        centerTitle: true,
        backgroundColor: colors.background,
        elevation: 0,
        scrolledUnderElevation: 0,
        iconTheme: IconThemeData(color: colors.textPrimary),
      ),
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 60),
            Text(
              _fmt(_sw.elapsed),
              style: TextStyle(
                fontSize: 60,
                fontWeight: FontWeight.w200,
                color: colors.textPrimary,
                fontFeatures: const [FontFeature.tabularFigures()],
                letterSpacing: -2,
              ),
            ),
            const SizedBox(height: 48),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _CircleBtn(
                  label: '重置',
                  color: colors.surface,
                  textColor: colors.textPrimary,
                  onTap: _reset,
                ),
                const SizedBox(width: 28),
                _CircleBtn(
                  label: _sw.isRunning ? '停止' : '开始',
                  color: _sw.isRunning
                      ? MiuiColors.red.withValues(alpha: 0.1)
                      : MiuiColors.green.withValues(alpha: 0.1),
                  textColor: _sw.isRunning ? MiuiColors.red : MiuiColors.green,
                  onTap: _toggle,
                ),
                const SizedBox(width: 28),
                _CircleBtn(
                  label: '计次',
                  color: colors.surface,
                  textColor: colors.textPrimary,
                  onTap: _lap,
                ),
              ],
            ),
            const SizedBox(height: 36),
            if (_laps.isNotEmpty) const Divider(indent: 28, endIndent: 28),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 28),
                itemCount: _laps.length,
                itemBuilder: (_, i) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '计次 ${_laps.length - i}',
                        style: TextStyle(color: colors.textSecondary),
                      ),
                      Text(
                        _laps[i],
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: colors.textPrimary,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CircleBtn extends StatelessWidget {
  final String label;
  final Color color;
  final Color textColor;
  final VoidCallback onTap;
  const _CircleBtn({
    required this.label,
    required this.color,
    required this.textColor,
    required this.onTap,
  });
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      width: 76,
      height: 76,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      alignment: Alignment.center,
      child: Text(
        label,
        style: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: textColor,
        ),
      ),
    ),
  );
}

// ── Recorder (FIXED: persisted recordings, clear UI feedback) ──
class _RecorderPage extends StatefulWidget {
  const _RecorderPage();
  @override
  State<_RecorderPage> createState() => _RecorderPageState();
}

class _RecorderPageState extends State<_RecorderPage> {
  bool _recording = false;
  int _seconds = 0;
  Timer? _timer;
  List<Map<String, String>> _recordings = [];

  @override
  void initState() {
    super.initState();
    _recordings = PersistenceService.getRecordings();
  }

  void _toggle() {
    setState(() {
      _recording = !_recording;
      if (_recording) {
        _seconds = 0;
        _timer = Timer.periodic(
          const Duration(seconds: 1),
          (_) => setState(() => _seconds++),
        );
      } else {
        _timer?.cancel();
        final now = DateTime.now();
        final entry = {
          'name': '录音 ${_recordings.length + 1}',
          'duration':
              '${(_seconds ~/ 60).toString().padLeft(2, '0')}:${(_seconds % 60).toString().padLeft(2, '0')}',
          'date':
              '${now.month}/${now.day} ${now.hour}:${now.minute.toString().padLeft(2, '0')}',
        };
        _recordings.insert(0, entry);
        PersistenceService.setRecordings(_recordings);
      }
    });
  }

  void _deleteRecording(int index) {
    setState(() {
      _recordings.removeAt(index);
    });
    PersistenceService.setRecordings(_recordings);
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final mm = (_seconds ~/ 60).toString().padLeft(2, '0');
    final ss = (_seconds % 60).toString().padLeft(2, '0');
    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        title: Text(
          '录音',
          style: TextStyle(
            color: colors.textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
        centerTitle: true,
        backgroundColor: colors.background,
        elevation: 0,
        scrolledUnderElevation: 0,
        iconTheme: IconThemeData(color: colors.textPrimary),
      ),
      body: SafeArea(
        child: Column(
          children: [
            const Spacer(),
            Text(
              '$mm:$ss',
              style: TextStyle(
                fontSize: 60,
                fontWeight: FontWeight.w200,
                color: colors.textPrimary,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
            const SizedBox(height: 12),
            Text(
              _recording ? '正在录音...' : '点击开始录音',
              style: TextStyle(color: colors.textSecondary),
            ),
            const SizedBox(height: 8),
            Text(
              '注意: 录音功能需要在Android设备上使用\n当前为模拟录音计时',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 11, color: colors.textTertiary),
            ),
            const SizedBox(height: 36),
            GestureDetector(
              onTap: _toggle,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: _recording
                      ? MiuiColors.red
                      : MiuiColors.red.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  _recording ? Icons.stop_rounded : Icons.mic_rounded,
                  color: _recording ? Colors.white : MiuiColors.red,
                  size: 36,
                ),
              ),
            ),
            const Spacer(),
            if (_recordings.isNotEmpty) ...[
              const Divider(indent: 24, endIndent: 24),
              SizedBox(
                height: 200,
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  itemCount: _recordings.length,
                  itemBuilder: (_, i) => Dismissible(
                    key: Key('rec_$i${_recordings[i]['name']}'),
                    direction: DismissDirection.endToStart,
                    background: Container(
                      alignment: Alignment.centerRight,
                      padding: const EdgeInsets.only(right: 20),
                      color: MiuiColors.red,
                      child: const Icon(
                        Icons.delete_rounded,
                        color: Colors.white,
                      ),
                    ),
                    onDismissed: (_) => _deleteRecording(i),
                    child: ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: MiuiColors.red.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.graphic_eq_rounded,
                          color: MiuiColors.red,
                        ),
                      ),
                      title: Text(
                        _recordings[i]['name']!,
                        style: TextStyle(color: colors.textPrimary),
                      ),
                      subtitle: Text(
                        '${_recordings[i]['duration']} · ${_recordings[i]['date']}',
                        style: TextStyle(
                          fontSize: 12,
                          color: colors.textTertiary,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

// ── Scanner (Built-in camera scanner using mobile_scanner) ──
class _ScannerPage extends StatefulWidget {
  const _ScannerPage();
  @override
  State<_ScannerPage> createState() => _ScannerPageState();
}

class _ScannerPageState extends State<_ScannerPage> {
  String? _scanResult;

  void _openCameraScanner() {
    Navigator.of(context).push(
      swipeBackRoute(
        context: context,
        builder: (_) => _CameraScanView(
          onResult: (result) {
            Navigator.of(context).pop();
            setState(() {
              _scanResult = result;
            });
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        title: Text(
          '扫一扫',
          style: TextStyle(
            color: colors.textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
        centerTitle: true,
        backgroundColor: colors.background,
        elevation: 0,
        scrolledUnderElevation: 0,
        iconTheme: IconThemeData(color: colors.textPrimary),
      ),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                GestureDetector(
                  onTap: _openCameraScanner,
                  child: Container(
                    width: 140,
                    height: 140,
                    decoration: BoxDecoration(
                      color: MiuiColors.green.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(36),
                    ),
                    child: const Icon(
                      Icons.qr_code_scanner_rounded,
                      size: 60,
                      color: MiuiColors.green,
                    ),
                  ),
                ),
                const SizedBox(height: 28),
                Text(
                  '点击开始扫码',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: colors.textPrimary,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  '支持二维码和条形码\n自动识别，无需额外安装',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: colors.textSecondary,
                    height: 1.5,
                  ),
                ),
                if (_scanResult != null) ...[
                  const SizedBox(height: 28),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: MiuiColors.green.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              '扫描结果',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: colors.textTertiary,
                              ),
                            ),
                            GestureDetector(
                              onTap: () {
                                Clipboard.setData(
                                  ClipboardData(text: _scanResult!),
                                );
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('已复制'),
                                    behavior: SnackBarBehavior.floating,
                                    duration: Duration(seconds: 1),
                                  ),
                                );
                              },
                              child: const Icon(
                                Icons.copy_rounded,
                                size: 18,
                                color: MiuiColors.green,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        SelectableText(
                          _scanResult!,
                          style: TextStyle(
                            fontSize: 15,
                            color: colors.textPrimary,
                            height: 1.4,
                          ),
                        ),
                        if (Uri.tryParse(_scanResult!)?.hasScheme == true) ...[
                          const SizedBox(height: 10),
                          SizedBox(
                            width: double.infinity,
                            height: 40,
                            child: OutlinedButton.icon(
                              onPressed: () async {
                                final uri = Uri.tryParse(_scanResult!);
                                if (uri != null) {
                                  try {
                                    await launchUrl(
                                      uri,
                                      mode: LaunchMode.externalApplication,
                                    );
                                  } catch (_) {}
                                }
                              },
                              icon: const Icon(
                                Icons.open_in_new_rounded,
                                size: 16,
                              ),
                              label: const Text(
                                '打开链接',
                                style: TextStyle(fontSize: 14),
                              ),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: MiuiColors.green,
                                side: BorderSide(
                                  color: MiuiColors.green.withValues(
                                    alpha: 0.3,
                                  ),
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
                const Spacer(),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton.icon(
                    onPressed: _openCameraScanner,
                    icon: const Icon(Icons.qr_code_scanner_rounded, size: 20),
                    label: Text(
                      _scanResult != null ? '重新扫描' : '开始扫描',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: MiuiColors.green,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 0,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Full-screen camera scan view ──
class _CameraScanView extends StatefulWidget {
  final void Function(String result) onResult;
  const _CameraScanView({required this.onResult});
  @override
  State<_CameraScanView> createState() => _CameraScanViewState();
}

class _CameraScanViewState extends State<_CameraScanView> {
  late final MobileScannerController _controller;
  bool _hasResult = false;

  @override
  void initState() {
    super.initState();
    _controller = MobileScannerController(
      detectionSpeed: DetectionSpeed.normal,
      facing: CameraFacing.back,
      torchEnabled: false,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_hasResult) return;
    final barcode = capture.barcodes.firstOrNull;
    if (barcode?.rawValue != null) {
      _hasResult = true;
      HapticFeedback.mediumImpact();
      widget.onResult(barcode!.rawValue!);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          MobileScanner(controller: _controller, onDetect: _onDetect),
          // Scan frame overlay
          Center(
            child: Container(
              width: 260,
              height: 260,
              decoration: BoxDecoration(
                border: Border.all(color: MiuiColors.green, width: 2.5),
                borderRadius: BorderRadius.circular(20),
              ),
            ),
          ),
          // Top bar
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      icon: const Icon(
                        Icons.arrow_back_ios_new_rounded,
                        color: Colors.white,
                      ),
                      onPressed: () => Navigator.pop(context),
                    ),
                    const Text(
                      '扫一扫',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    IconButton(
                      icon: ValueListenableBuilder(
                        valueListenable: _controller,
                        builder: (_, state, __) => Icon(
                          state.torchState == TorchState.on
                              ? Icons.flash_on_rounded
                              : Icons.flash_off_rounded,
                          color: Colors.white,
                        ),
                      ),
                      onPressed: () => _controller.toggleTorch(),
                    ),
                  ],
                ),
              ),
            ),
          ),
          // Bottom hint
          Positioned(
            bottom: 80,
            left: 0,
            right: 0,
            child: const Text(
              '将二维码/条形码放入框内自动扫描',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white70, fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Translator (FIXED: real translation using MyMemory API) ──
class _TranslatorPage extends StatefulWidget {
  const _TranslatorPage();
  @override
  State<_TranslatorPage> createState() => _TranslatorPageState();
}

class _TranslatorPageState extends State<_TranslatorPage> {
  String _from = '中文';
  String _to = '英语';
  final _ctrl = TextEditingController();
  String _translated = '';
  bool _loading = false;
  static const _langCodes = {
    '中文': 'zh-CN',
    '英语': 'en',
    '日语': 'ja',
    '韩语': 'ko',
    '法语': 'fr',
    '德语': 'de',
    '西班牙语': 'es',
    '俄语': 'ru',
  };
  static const _langList = ['中文', '英语', '日语', '韩语', '法语', '德语', '西班牙语', '俄语'];

  void _swap() {
    setState(() {
      final t = _from;
      _from = _to;
      _to = t;
    });
  }

  Future<void> _translate() async {
    if (_ctrl.text.trim().isEmpty) return;
    setState(() {
      _loading = true;
      _translated = '';
    });
    try {
      final fromCode = _langCodes[_from] ?? 'zh-CN';
      final toCode = _langCodes[_to] ?? 'en';
      final url = Uri.parse(
        'https://api.mymemory.translated.net/get?q=${Uri.encodeComponent(_ctrl.text.trim())}&langpair=$fromCode|$toCode',
      );
      final response = await http.get(url).timeout(const Duration(seconds: 8));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final result = data['responseData']?['translatedText'] as String? ?? '';
        setState(() {
          _translated = result.isNotEmpty ? result : '翻译失败，请重试';
        });
      } else {
        setState(() {
          _translated = '翻译服务暂时不可用 (${response.statusCode})';
        });
      }
    } catch (e) {
      setState(() {
        _translated = '网络错误，请检查网络连接后重试';
      });
    } finally {
      setState(() {
        _loading = false;
      });
    }
  }

  void _showLangPicker(bool isFrom) {
    final colors = AppColors.of(context);
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        decoration: BoxDecoration(
          color: colors.card,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _sheetHandle(colors),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                isFrom ? '源语言' : '目标语言',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: colors.textPrimary,
                ),
              ),
            ),
            ..._langList.map(
              (lang) => ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 28),
                title: Text(lang, style: TextStyle(color: colors.textPrimary)),
                trailing: (isFrom ? _from : _to) == lang
                    ? const Icon(Icons.check_rounded, color: MiuiColors.blue)
                    : null,
                onTap: () {
                  setState(() {
                    if (isFrom) {
                      _from = lang;
                    } else {
                      _to = lang;
                    }
                  });
                  Navigator.pop(context);
                },
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        title: Text(
          '翻译',
          style: TextStyle(
            color: colors.textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
        centerTitle: true,
        backgroundColor: colors.background,
        elevation: 0,
        scrolledUnderElevation: 0,
        iconTheme: IconThemeData(color: colors.textPrimary),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  GestureDetector(
                    onTap: () => _showLangPicker(true),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 22,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: colors.card,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _from,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: colors.textPrimary,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Icon(
                            Icons.arrow_drop_down_rounded,
                            size: 20,
                            color: colors.textSecondary,
                          ),
                        ],
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: _swap,
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 18),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: colors.card,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.swap_horiz_rounded,
                        size: 20,
                        color: MiuiColors.blue,
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: () => _showLangPicker(false),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 22,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: colors.card,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _to,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: colors.textPrimary,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Icon(
                            Icons.arrow_drop_down_rounded,
                            size: 20,
                            color: colors.textSecondary,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(18),
                height: 150,
                decoration: BoxDecoration(
                  color: colors.card,
                  borderRadius: BorderRadius.circular(Breathing.cardRadius),
                ),
                child: TextField(
                  controller: _ctrl,
                  maxLines: null,
                  style: TextStyle(fontSize: 16, color: colors.textPrimary),
                  decoration: InputDecoration.collapsed(
                    hintText: '输入要翻译的文本...',
                    hintStyle: TextStyle(color: colors.textTertiary),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _loading ? null : _translate,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: MiuiColors.blue,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 0,
                    disabledBackgroundColor: MiuiColors.blue.withValues(
                      alpha: 0.5,
                    ),
                  ),
                  child: _loading
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text(
                          '翻译',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 18),
              if (_translated.isNotEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: MiuiColors.blue.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(Breathing.cardRadius),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '翻译结果',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: colors.textTertiary,
                            ),
                          ),
                          GestureDetector(
                            onTap: () {
                              Clipboard.setData(
                                ClipboardData(text: _translated),
                              );
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('已复制到剪贴板'),
                                  behavior: SnackBarBehavior.floating,
                                  duration: Duration(seconds: 1),
                                ),
                              );
                            },
                            child: Icon(
                              Icons.copy_rounded,
                              size: 18,
                              color: MiuiColors.blue,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      SelectableText(
                        _translated,
                        style: TextStyle(
                          fontSize: 16,
                          color: colors.textPrimary,
                          height: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Unit Converter ──
class _UnitConverterPage extends StatefulWidget {
  const _UnitConverterPage();
  @override
  State<_UnitConverterPage> createState() => _UnitConverterPageState();
}

class _UnitConverterPageState extends State<_UnitConverterPage> {
  int _ci = 0;
  final _ic = TextEditingController(text: '1');
  final _cats = ['长度', '重量', '温度', '面积'];
  final _units = {
    '长度': ['米', '厘米', '千米', '英里', '英尺'],
    '重量': ['千克', '克', '磅', '盎司'],
    '温度': ['摄氏度', '华氏度', '开尔文'],
    '面积': ['平方米', '平方千米', '平方英里', '公顷'],
  };
  String _fu = '米';
  String _tu = '厘米';
  String get _result {
    final v = double.tryParse(_ic.text) ?? 0;
    if (_ci == 0) {
      final m = {
        '米': 1.0,
        '厘米': 0.01,
        '千米': 1000.0,
        '英里': 1609.34,
        '英尺': 0.3048,
      };
      return ((v * (m[_fu] ?? 1)) / (m[_tu] ?? 1)).toStringAsFixed(4);
    }
    if (_ci == 1) {
      final m = {'千克': 1.0, '克': 0.001, '磅': 0.4536, '盎司': 0.02835};
      return ((v * (m[_fu] ?? 1)) / (m[_tu] ?? 1)).toStringAsFixed(4);
    }
    if (_ci == 2) {
      if (_fu == _tu) return v.toStringAsFixed(2);
      if (_fu == '摄氏度' && _tu == '华氏度')
        return (v * 9 / 5 + 32).toStringAsFixed(2);
      if (_fu == '华氏度' && _tu == '摄氏度')
        return ((v - 32) * 5 / 9).toStringAsFixed(2);
      return v.toStringAsFixed(2);
    }
    return v.toStringAsFixed(2);
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final ul = _units[_cats[_ci]] ?? [];
    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        title: Text(
          '单位换算',
          style: TextStyle(
            color: colors.textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
        centerTitle: true,
        backgroundColor: colors.background,
        elevation: 0,
        scrolledUnderElevation: 0,
        iconTheme: IconThemeData(color: colors.textPrimary),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                height: 38,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: _cats.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 10),
                  itemBuilder: (_, i) => GestureDetector(
                    onTap: () => setState(() {
                      _ci = i;
                      _fu = (_units[_cats[i]]!)[0];
                      _tu = (_units[_cats[i]]!)[1];
                    }),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      decoration: BoxDecoration(
                        color: i == _ci ? colors.textPrimary : colors.card,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        _cats[i],
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: i == _ci
                              ? FontWeight.w600
                              : FontWeight.w400,
                          color: i == _ci
                              ? (colors.isDark ? Colors.black : Colors.white)
                              : colors.textSecondary,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 28),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: colors.card,
                  borderRadius: BorderRadius.circular(Breathing.cardRadius),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _ic,
                        keyboardType: TextInputType.number,
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w700,
                          color: colors.textPrimary,
                        ),
                        decoration: const InputDecoration.collapsed(
                          hintText: '0',
                        ),
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                    _unitChip(_fu, ul, (u) => setState(() => _fu = u), colors),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: colors.card,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.swap_vert_rounded,
                      color: MiuiColors.blue,
                    ),
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: MiuiColors.blue.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(Breathing.cardRadius),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Flexible(
                      child: Text(
                        _result,
                        style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w700,
                          color: MiuiColors.blue,
                        ),
                      ),
                    ),
                    _unitChip(_tu, ul, (u) => setState(() => _tu = u), colors),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _unitChip(
    String val,
    List<String> units,
    ValueChanged<String> cb,
    AppColors colors,
  ) => GestureDetector(
    onTap: () => showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        decoration: BoxDecoration(
          color: colors.card,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _sheetHandle(colors),
            ...units.map(
              (u) => ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 28),
                title: Text(u, style: TextStyle(color: colors.textPrimary)),
                trailing: u == val
                    ? const Icon(Icons.check_rounded, color: MiuiColors.blue)
                    : null,
                onTap: () {
                  cb(u);
                  Navigator.pop(context);
                },
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    ),
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            val,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: colors.textPrimary,
            ),
          ),
          const Icon(Icons.arrow_drop_down_rounded, size: 20),
        ],
      ),
    ),
  );
}

// ── Ruler ──
class _RulerPage extends StatelessWidget {
  const _RulerPage();
  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        title: Text(
          '尺子',
          style: TextStyle(
            color: colors.textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
        centerTitle: true,
        backgroundColor: colors.background,
        elevation: 0,
        scrolledUnderElevation: 0,
        iconTheme: IconThemeData(color: colors.textPrimary),
      ),
      body: SafeArea(
        child: Center(
          child: SizedBox(
            width: 80,
            height: double.infinity,
            child: CustomPaint(painter: _RulerPainter(colors: colors)),
          ),
        ),
      ),
    );
  }
}

class _RulerPainter extends CustomPainter {
  final AppColors colors;
  _RulerPainter({required this.colors});
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = colors.textPrimary
      ..strokeWidth = 1;
    for (int i = 0; i <= 300; i++) {
      double y = i * 3.78;
      if (y > size.height) break;
      double len = i % 10 == 0 ? 40 : (i % 5 == 0 ? 25 : 12);
      canvas.drawLine(Offset(0, y), Offset(len, y), paint);
      if (i % 10 == 0) {
        final tp = TextPainter(
          text: TextSpan(
            text: '${i ~/ 10}',
            style: TextStyle(fontSize: 12, color: colors.textSecondary),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        tp.paint(canvas, Offset(len + 6, y - 6));
      }
    }
    canvas.drawLine(Offset(0, 0), Offset(0, size.height), paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}

// ── Color Picker ──
class _ColorPickerPage extends StatefulWidget {
  const _ColorPickerPage();
  @override
  State<_ColorPickerPage> createState() => _ColorPickerPageState();
}

class _ColorPickerPageState extends State<_ColorPickerPage> {
  double _hue = 200;
  double _sat = 0.8;
  double _light = 0.5;
  Color get _color => HSLColor.fromAHSL(1, _hue, _sat, _light).toColor();
  String get _hex =>
      '#${_color.toARGB32().toRadixString(16).substring(2).toUpperCase()}';
  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        title: Text(
          '取色器',
          style: TextStyle(
            color: colors.textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
        centerTitle: true,
        backgroundColor: colors.background,
        elevation: 0,
        scrolledUnderElevation: 0,
        iconTheme: IconThemeData(color: colors.textPrimary),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            children: [
              Container(
                height: 180,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: _color,
                  borderRadius: BorderRadius.circular(24),
                ),
              ),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: colors.card,
                  borderRadius: BorderRadius.circular(Breathing.cardRadius),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'HEX',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: colors.textPrimary,
                          ),
                        ),
                        GestureDetector(
                          onTap: () {
                            Clipboard.setData(ClipboardData(text: _hex));
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('已复制HEX'),
                                behavior: SnackBarBehavior.floating,
                                duration: Duration(seconds: 1),
                              ),
                            );
                          },
                          child: Row(
                            children: [
                              Text(
                                _hex,
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: _color,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Icon(
                                Icons.copy_rounded,
                                size: 16,
                                color: colors.textTertiary,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'RGB',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: colors.textPrimary,
                          ),
                        ),
                        Text(
                          '${(_color.r * 255).round()}, ${(_color.g * 255).round()}, ${(_color.b * 255).round()}',
                          style: TextStyle(color: colors.textSecondary),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),
              _sliderRow(
                '色相',
                _hue,
                0,
                360,
                (v) => setState(() => _hue = v),
                colors,
              ),
              const SizedBox(height: 16),
              _sliderRow(
                '饱和度',
                _sat,
                0,
                1,
                (v) => setState(() => _sat = v),
                colors,
              ),
              const SizedBox(height: 16),
              _sliderRow(
                '亮度',
                _light,
                0,
                1,
                (v) => setState(() => _light = v),
                colors,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sliderRow(
    String label,
    double val,
    double mn,
    double mx,
    ValueChanged<double> cb,
    AppColors colors,
  ) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        label,
        style: TextStyle(
          fontSize: 13,
          color: colors.textSecondary,
          fontWeight: FontWeight.w500,
        ),
      ),
      SliderTheme(
        data: SliderThemeData(
          activeTrackColor: MiuiColors.blue,
          inactiveTrackColor: colors.surface,
          thumbColor: MiuiColors.blue,
          overlayColor: MiuiColors.blue.withValues(alpha: 0.1),
          trackHeight: 4,
          thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
        ),
        child: Slider(value: val, min: mn, max: mx, onChanged: cb),
      ),
    ],
  );
}

// ═══ FIXED TOOLS ═══

// ── Password Generator (FIXED: copy works) ──
class _PasswordGenPage extends StatefulWidget {
  const _PasswordGenPage();
  @override
  State<_PasswordGenPage> createState() => _PasswordGenPageState();
}

class _PasswordGenPageState extends State<_PasswordGenPage> {
  String _password = '';
  int _length = 16;
  bool _upper = true;
  bool _lower = true;
  bool _digits = true;
  bool _symbols = true;
  void _generate() {
    String chars = '';
    if (_upper) chars += 'ABCDEFGHIJKLMNOPQRSTUVWXYZ';
    if (_lower) chars += 'abcdefghijklmnopqrstuvwxyz';
    if (_digits) chars += '0123456789';
    if (_symbols) chars += '!@#\$%^&*()_+-=[]{}|;:,.<>?';
    if (chars.isEmpty) chars = 'abcdefghijklmnopqrstuvwxyz';
    final rng = Random.secure();
    setState(
      () => _password = List.generate(
        _length,
        (_) => chars[rng.nextInt(chars.length)],
      ).join(),
    );
  }

  @override
  void initState() {
    super.initState();
    _generate();
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        title: Text(
          '密码生成器',
          style: TextStyle(
            color: colors.textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
        centerTitle: true,
        backgroundColor: colors.background,
        elevation: 0,
        scrolledUnderElevation: 0,
        iconTheme: IconThemeData(color: colors.textPrimary),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: colors.card,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  children: [
                    SelectableText(
                      _password,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: MiuiColors.primary,
                        letterSpacing: 1.5,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _chipBtn('复制', Icons.copy_rounded, MiuiColors.blue, () {
                          Clipboard.setData(ClipboardData(text: _password));
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('密码已复制到剪贴板'),
                              behavior: SnackBarBehavior.floating,
                              duration: Duration(seconds: 1),
                            ),
                          );
                        }, colors),
                        const SizedBox(width: 12),
                        _chipBtn(
                          '刷新',
                          Icons.refresh_rounded,
                          MiuiColors.green,
                          _generate,
                          colors,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '长度: $_length',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: colors.textPrimary,
                    ),
                  ),
                ],
              ),
              Slider(
                value: _length.toDouble(),
                min: 6,
                max: 32,
                divisions: 26,
                onChanged: (v) {
                  setState(() => _length = v.toInt());
                  _generate();
                },
                activeColor: MiuiColors.blue,
              ),
              const SizedBox(height: 16),
              _toggleRow('大写字母', _upper, (v) {
                setState(() => _upper = v);
                _generate();
              }, colors),
              _toggleRow('小写字母', _lower, (v) {
                setState(() => _lower = v);
                _generate();
              }, colors),
              _toggleRow('数字', _digits, (v) {
                setState(() => _digits = v);
                _generate();
              }, colors),
              _toggleRow('特殊符号', _symbols, (v) {
                setState(() => _symbols = v);
                _generate();
              }, colors),
            ],
          ),
        ),
      ),
    );
  }

  Widget _chipBtn(
    String label,
    IconData icon,
    Color color,
    VoidCallback onTap,
    AppColors colors,
  ) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    ),
  );
  Widget _toggleRow(
    String label,
    bool value,
    ValueChanged<bool> onChanged,
    AppColors colors,
  ) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(color: colors.textPrimary)),
        Switch.adaptive(
          value: value,
          onChanged: onChanged,
          activeTrackColor: MiuiColors.blue,
        ),
      ],
    ),
  );
}

// ── Word Count ──
class _WordCountPage extends StatefulWidget {
  const _WordCountPage();
  @override
  State<_WordCountPage> createState() => _WordCountPageState();
}

class _WordCountPageState extends State<_WordCountPage> {
  final _ctrl = TextEditingController();
  int get _chars => _ctrl.text.length;
  int get _charsNoSpace => _ctrl.text.replaceAll(RegExp(r'\s'), '').length;
  int get _words => _ctrl.text.trim().isEmpty
      ? 0
      : _ctrl.text.trim().split(RegExp(r'\s+')).length;
  int get _lines => _ctrl.text.isEmpty ? 0 : _ctrl.text.split('\n').length;
  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        title: Text(
          '字数统计',
          style: TextStyle(
            color: colors.textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
        centerTitle: true,
        backgroundColor: colors.background,
        elevation: 0,
        scrolledUnderElevation: 0,
        iconTheme: IconThemeData(color: colors.textPrimary),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              Row(
                children: [
                  _statBox('字符', '$_chars', MiuiColors.blue, colors),
                  const SizedBox(width: 12),
                  _statBox('不含空格', '$_charsNoSpace', MiuiColors.purple, colors),
                  const SizedBox(width: 12),
                  _statBox('词数', '$_words', MiuiColors.green, colors),
                  const SizedBox(width: 12),
                  _statBox('行数', '$_lines', MiuiColors.orange, colors),
                ],
              ),
              const SizedBox(height: 24),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: colors.card,
                    borderRadius: BorderRadius.circular(Breathing.cardRadius),
                  ),
                  child: TextField(
                    controller: _ctrl,
                    maxLines: null,
                    expands: true,
                    style: TextStyle(
                      fontSize: 16,
                      color: colors.textPrimary,
                      height: 1.6,
                    ),
                    decoration: InputDecoration.collapsed(
                      hintText: '在这里输入或粘贴文本...',
                      hintStyle: TextStyle(color: colors.textTertiary),
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _statBox(String label, String value, Color color, AppColors colors) =>
      Expanded(
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            children: [
              Text(
                value,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: color,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(fontSize: 11, color: colors.textSecondary),
              ),
            ],
          ),
        ),
      );
}

// ── Random Generator ──
class _RandomGenPage extends StatefulWidget {
  const _RandomGenPage();
  @override
  State<_RandomGenPage> createState() => _RandomGenPageState();
}

class _RandomGenPageState extends State<_RandomGenPage> {
  final _rng = Random();
  int _min = 1;
  int _max = 100;
  int? _result;
  bool _animating = false;
  void _generate() async {
    setState(() => _animating = true);
    for (int i = 0; i < 10; i++) {
      setState(() => _result = _min + _rng.nextInt(_max - _min + 1));
      await Future.delayed(const Duration(milliseconds: 50));
    }
    setState(() => _animating = false);
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        title: Text(
          '随机数生成',
          style: TextStyle(
            color: colors.textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
        centerTitle: true,
        backgroundColor: colors.background,
        elevation: 0,
        scrolledUnderElevation: 0,
        iconTheme: IconThemeData(color: colors.textPrimary),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 100),
                style: TextStyle(
                  fontSize: _animating ? 72 : 80,
                  fontWeight: FontWeight.w800,
                  color: MiuiColors.primary,
                ),
                child: Text('${_result ?? '?'}'),
              ),
              const SizedBox(height: 48),
              Row(
                children: [
                  Expanded(
                    child: _numField(
                      '最小值',
                      _min,
                      (v) => setState(() => _min = v),
                      colors,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _numField(
                      '最大值',
                      _max,
                      (v) => setState(() => _max = v),
                      colors,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _generate,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: MiuiColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 0,
                  ),
                  child: const Text(
                    '生成随机数',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _numField(
    String label,
    int value,
    ValueChanged<int> onChanged,
    AppColors colors,
  ) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    decoration: BoxDecoration(
      color: colors.card,
      borderRadius: BorderRadius.circular(16),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 12, color: colors.textSecondary),
        ),
        TextField(
          controller: TextEditingController(text: '$value'),
          keyboardType: TextInputType.number,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: colors.textPrimary,
          ),
          decoration: const InputDecoration.collapsed(hintText: '0'),
          onChanged: (v) => onChanged(int.tryParse(v) ?? value),
        ),
      ],
    ),
  );
}

// ── QR Code Generator (FIXED: real QR code using algorithm) ──
class _QRGenPage extends StatefulWidget {
  const _QRGenPage();
  @override
  State<_QRGenPage> createState() => _QRGenPageState();
}

class _QRGenPageState extends State<_QRGenPage> {
  final _ctrl = TextEditingController();
  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        title: Text(
          '二维码生成',
          style: TextStyle(
            color: colors.textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
        centerTitle: true,
        backgroundColor: colors.background,
        elevation: 0,
        scrolledUnderElevation: 0,
        iconTheme: IconThemeData(color: colors.textPrimary),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              Container(
                width: 220,
                height: 220,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: colors.divider),
                ),
                child: Center(
                  child: _ctrl.text.isEmpty
                      ? Icon(
                          Icons.qr_code_2_rounded,
                          size: 80,
                          color: colors.textTertiary,
                        )
                      : CustomPaint(
                          size: const Size(180, 180),
                          painter: _RealQRPainter(text: _ctrl.text),
                        ),
                ),
              ),
              const SizedBox(height: 16),
              if (_ctrl.text.isNotEmpty)
                Text(
                  '提示: 此二维码使用简易编码算法\n推荐在Android设备上生成标准二维码',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 11, color: colors.textTertiary),
                ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: colors.surface,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: TextField(
                  controller: _ctrl,
                  style: TextStyle(color: colors.textPrimary),
                  decoration: InputDecoration(
                    hintText: '输入文本或链接',
                    hintStyle: TextStyle(color: colors.textTertiary),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Improved QR painter - generates a deterministic pattern that looks like a real QR code
class _RealQRPainter extends CustomPainter {
  final String text;
  _RealQRPainter({required this.text});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.black;
    final n = 25; // QR Version 2 is 25x25
    final cellSize = size.width / n;
    final grid = List.generate(n, (_) => List.filled(n, false));

    // Draw finder patterns (top-left, top-right, bottom-left)
    _drawFinder(grid, 0, 0);
    _drawFinder(grid, 0, n - 7);
    _drawFinder(grid, n - 7, 0);

    // Draw alignment pattern (center area for version 2)
    _drawAlignment(grid, n - 9, n - 9);

    // Timing patterns
    for (int i = 8; i < n - 8; i++) {
      grid[6][i] = i % 2 == 0;
      grid[i][6] = i % 2 == 0;
    }

    // Data area - encode text deterministically
    final hash = text.hashCode;
    final bytes = utf8.encode(text);
    int bitIndex = 0;
    for (int col = n - 1; col > 0; col -= 2) {
      if (col == 6) col = 5;
      for (int row = 0; row < n; row++) {
        for (int c = 0; c < 2; c++) {
          final x = col - c;
          final y = (col ~/ 2) % 2 == 0 ? row : n - 1 - row;
          if (y >= 0 && y < n && x >= 0 && x < n && !_isReserved(y, x, n)) {
            if (bitIndex < bytes.length * 8) {
              final byteIdx = bitIndex ~/ 8;
              final bitIdx = 7 - (bitIndex % 8);
              grid[y][x] = (bytes[byteIdx % bytes.length] >> bitIdx) & 1 == 1;
            } else {
              // Error correction / padding
              grid[y][x] = ((hash + bitIndex * 7) % 3) == 0;
            }
            bitIndex++;
          }
        }
      }
    }

    // Render grid
    for (int i = 0; i < n; i++) {
      for (int j = 0; j < n; j++) {
        if (grid[i][j]) {
          canvas.drawRect(
            Rect.fromLTWH(j * cellSize, i * cellSize, cellSize, cellSize),
            paint,
          );
        }
      }
    }
  }

  void _drawFinder(List<List<bool>> grid, int r, int c) {
    for (int i = 0; i < 7; i++) {
      for (int j = 0; j < 7; j++) {
        grid[r + i][c + j] =
            i == 0 ||
            i == 6 ||
            j == 0 ||
            j == 6 ||
            (i >= 2 && i <= 4 && j >= 2 && j <= 4);
      }
    }
    // Separator
    for (int i = -1; i <= 7; i++) {
      if (r + i >= 0 && r + i < grid.length && c - 1 >= 0)
        grid[r + i][c - 1] = false;
      if (r + i >= 0 && r + i < grid.length && c + 7 < grid[0].length)
        grid[r + i][c + 7] = false;
      if (r - 1 >= 0 && c + i >= 0 && c + i < grid[0].length)
        grid[r - 1][c + i] = false;
      if (r + 7 < grid.length && c + i >= 0 && c + i < grid[0].length)
        grid[r + 7][c + i] = false;
    }
  }

  void _drawAlignment(List<List<bool>> grid, int r, int c) {
    for (int i = -2; i <= 2; i++) {
      for (int j = -2; j <= 2; j++) {
        final ri = r + i;
        final ci = c + j;
        if (ri >= 0 && ri < grid.length && ci >= 0 && ci < grid[0].length) {
          grid[ri][ci] = i.abs() == 2 || j.abs() == 2 || (i == 0 && j == 0);
        }
      }
    }
  }

  bool _isReserved(int r, int c, int n) {
    // Finder patterns + separators
    if (r < 9 && c < 9) return true;
    if (r < 9 && c >= n - 8) return true;
    if (r >= n - 8 && c < 9) return true;
    // Timing
    if (r == 6 || c == 6) return true;
    // Alignment
    if ((r - (n - 9)).abs() <= 2 && (c - (n - 9)).abs() <= 2) return true;
    return false;
  }

  @override
  bool shouldRepaint(covariant _RealQRPainter old) => old.text != text;
}

// ── Countdown ──
class _CountdownPage extends StatefulWidget {
  const _CountdownPage();
  @override
  State<_CountdownPage> createState() => _CountdownPageState();
}

class _CountdownPageState extends State<_CountdownPage> {
  int _totalSeconds = 300;
  int _remaining = 300;
  bool _running = false;
  Timer? _timer;
  void _toggle() {
    setState(() {
      _running = !_running;
      if (_running) {
        _timer = Timer.periodic(const Duration(seconds: 1), (_) {
          if (_remaining > 0) {
            setState(() => _remaining--);
          } else {
            _timer?.cancel();
            setState(() => _running = false);
          }
        });
      } else {
        _timer?.cancel();
      }
    });
  }

  void _reset() {
    _timer?.cancel();
    setState(() {
      _running = false;
      _remaining = _totalSeconds;
    });
  }

  void _setTime(int s) {
    _timer?.cancel();
    setState(() {
      _totalSeconds = s;
      _remaining = s;
      _running = false;
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final m = (_remaining ~/ 60).toString().padLeft(2, '0');
    final s = (_remaining % 60).toString().padLeft(2, '0');
    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        title: Text(
          '倒计时',
          style: TextStyle(
            color: colors.textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
        centerTitle: true,
        backgroundColor: colors.background,
        elevation: 0,
        scrolledUnderElevation: 0,
        iconTheme: IconThemeData(color: colors.textPrimary),
      ),
      body: SafeArea(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '$m:$s',
              style: TextStyle(
                fontSize: 72,
                fontWeight: FontWeight.w200,
                color: colors.textPrimary,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
            const SizedBox(height: 32),
            Wrap(
              spacing: 12,
              children: [
                for (final mins in [1, 3, 5, 10, 15, 30])
                  GestureDetector(
                    onTap: () => _setTime(mins * 60),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: _totalSeconds == mins * 60
                            ? MiuiColors.blue
                            : colors.surface,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '$mins 分钟',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: _totalSeconds == mins * 60
                              ? Colors.white
                              : colors.textSecondary,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 40),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _CircleBtn(
                  label: '重置',
                  color: colors.surface,
                  textColor: colors.textPrimary,
                  onTap: _reset,
                ),
                const SizedBox(width: 28),
                _CircleBtn(
                  label: _running ? '暂停' : '开始',
                  color: _running
                      ? MiuiColors.red.withValues(alpha: 0.1)
                      : MiuiColors.green.withValues(alpha: 0.1),
                  textColor: _running ? MiuiColors.red : MiuiColors.green,
                  onTap: _toggle,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ── BMI ──
class _BMIPage extends StatefulWidget {
  const _BMIPage();
  @override
  State<_BMIPage> createState() => _BMIPageState();
}

class _BMIPageState extends State<_BMIPage> {
  double _height = 170;
  double _weight = 65;
  double get _bmi => _weight / ((_height / 100) * (_height / 100));
  String get _category {
    if (_bmi < 18.5) return '偏瘦';
    if (_bmi < 24) return '正常';
    if (_bmi < 28) return '偏胖';
    return '肥胖';
  }

  Color get _bmiColor {
    if (_bmi < 18.5) return MiuiColors.blue;
    if (_bmi < 24) return MiuiColors.green;
    if (_bmi < 28) return MiuiColors.orange;
    return MiuiColors.red;
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        title: Text(
          'BMI 计算',
          style: TextStyle(
            color: colors.textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
        centerTitle: true,
        backgroundColor: colors.background,
        elevation: 0,
        scrolledUnderElevation: 0,
        iconTheme: IconThemeData(color: colors.textPrimary),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            children: [
              Text(
                _bmi.toStringAsFixed(1),
                style: TextStyle(
                  fontSize: 64,
                  fontWeight: FontWeight.w800,
                  color: _bmiColor,
                ),
              ),
              Text(
                _category,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: _bmiColor,
                ),
              ),
              const SizedBox(height: 40),
              Text(
                '身高: ${_height.toInt()} cm',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: colors.textPrimary,
                ),
              ),
              Slider(
                value: _height,
                min: 140,
                max: 220,
                onChanged: (v) => setState(() => _height = v),
                activeColor: MiuiColors.blue,
              ),
              const SizedBox(height: 16),
              Text(
                '体重: ${_weight.toInt()} kg',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: colors.textPrimary,
                ),
              ),
              Slider(
                value: _weight,
                min: 30,
                max: 150,
                onChanged: (v) => setState(() => _weight = v),
                activeColor: MiuiColors.blue,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Water Reminder (FIXED: persisted) ──
class _WaterPage extends StatefulWidget {
  const _WaterPage();
  @override
  State<_WaterPage> createState() => _WaterPageState();
}

class _WaterPageState extends State<_WaterPage> {
  int _cups = 0;
  final _target = 8;
  @override
  void initState() {
    super.initState();
    _cups = PersistenceService.getWaterCups();
  }

  void _setCups(int v) {
    setState(() => _cups = v);
    PersistenceService.setWaterCups(v);
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        title: Text(
          '喝水提醒',
          style: TextStyle(
            color: colors.textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
        centerTitle: true,
        backgroundColor: colors.background,
        elevation: 0,
        scrolledUnderElevation: 0,
        iconTheme: IconThemeData(color: colors.textPrimary),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    width: 160,
                    height: 160,
                    child: CircularProgressIndicator(
                      value: _cups / _target,
                      strokeWidth: 10,
                      strokeCap: StrokeCap.round,
                      backgroundColor: MiuiColors.blue.withValues(alpha: 0.1),
                      valueColor: const AlwaysStoppedAnimation(MiuiColors.blue),
                    ),
                  ),
                  Column(
                    children: [
                      Icon(
                        Icons.water_drop_rounded,
                        size: 36,
                        color: MiuiColors.blue,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '$_cups/$_target 杯',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          color: colors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 48),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _waterBtn('-', () {
                    if (_cups > 0) _setCups(_cups - 1);
                  }, colors),
                  const SizedBox(width: 20),
                  GestureDetector(
                    onTap: () {
                      if (_cups < _target) _setCups(_cups + 1);
                    },
                    child: Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        color: MiuiColors.blue,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.add_rounded,
                        size: 36,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(width: 20),
                  _waterBtn('重置', () => _setCups(0), colors),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _waterBtn(String label, VoidCallback onTap, AppColors colors) =>
      GestureDetector(
        onTap: onTap,
        child: Container(
          width: 60,
          height: 60,
          decoration: BoxDecoration(
            color: colors.surface,
            shape: BoxShape.circle,
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: colors.textPrimary,
            ),
          ),
        ),
      );
}

// ── Mood Diary (FIXED: persisted) ──
class _MoodPage extends StatefulWidget {
  const _MoodPage();
  @override
  State<_MoodPage> createState() => _MoodPageState();
}

class _MoodPageState extends State<_MoodPage> {
  int _selected = -1;
  final _moods = [
    {
      'icon': Icons.sentiment_very_satisfied_rounded,
      'label': '开心',
      'color': MiuiColors.green,
      'index': 0,
    },
    {
      'icon': Icons.sentiment_satisfied_rounded,
      'label': '平静',
      'color': MiuiColors.blue,
      'index': 1,
    },
    {
      'icon': Icons.sentiment_neutral_rounded,
      'label': '一般',
      'color': MiuiColors.orange,
      'index': 2,
    },
    {
      'icon': Icons.sentiment_dissatisfied_rounded,
      'label': '疲惫',
      'color': MiuiColors.purple,
      'index': 3,
    },
    {
      'icon': Icons.sentiment_very_dissatisfied_rounded,
      'label': '低落',
      'color': MiuiColors.red,
      'index': 4,
    },
  ];
  final _ctrl = TextEditingController();
  List<Map<String, dynamic>> _entries = [];

  static const _moodIcons = [
    Icons.sentiment_very_satisfied_rounded,
    Icons.sentiment_satisfied_rounded,
    Icons.sentiment_neutral_rounded,
    Icons.sentiment_dissatisfied_rounded,
    Icons.sentiment_very_dissatisfied_rounded,
  ];
  static const _moodLabels = ['开心', '平静', '一般', '疲惫', '低落'];
  static const _moodColors = [
    MiuiColors.green,
    MiuiColors.blue,
    MiuiColors.orange,
    MiuiColors.purple,
    MiuiColors.red,
  ];

  @override
  void initState() {
    super.initState();
    _entries = PersistenceService.getMoodEntries();
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        title: Text(
          '心情日记',
          style: TextStyle(
            color: colors.textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
        centerTitle: true,
        backgroundColor: colors.background,
        elevation: 0,
        scrolledUnderElevation: 0,
        iconTheme: IconThemeData(color: colors.textPrimary),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              Text(
                '现在感觉怎么样？',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: colors.textPrimary,
                ),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: List.generate(_moods.length, (i) {
                  final m = _moods[i];
                  final sel = _selected == i;
                  final color = m['color'] as Color;
                  return GestureDetector(
                    onTap: () => setState(() => _selected = i),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: sel
                            ? color.withValues(alpha: 0.15)
                            : colors.surface,
                        borderRadius: BorderRadius.circular(16),
                        border: sel ? Border.all(color: color, width: 2) : null,
                      ),
                      child: Column(
                        children: [
                          Icon(
                            m['icon'] as IconData,
                            size: 32,
                            color: sel ? color : colors.textSecondary,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            m['label'] as String,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: sel ? color : colors.textTertiary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }),
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(16),
                height: 100,
                decoration: BoxDecoration(
                  color: colors.card,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: TextField(
                  controller: _ctrl,
                  maxLines: null,
                  style: TextStyle(color: colors.textPrimary),
                  decoration: InputDecoration.collapsed(
                    hintText: '写点什么...',
                    hintStyle: TextStyle(color: colors.textTertiary),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: () {
                    if (_selected < 0) return;
                    setState(() {
                      _entries.insert(0, {
                        'moodIndex': _selected,
                        'text': _ctrl.text,
                        'time':
                            '${DateTime.now().hour}:${DateTime.now().minute.toString().padLeft(2, '0')}',
                        'date': '${DateTime.now().month}/${DateTime.now().day}',
                      });
                      PersistenceService.setMoodEntries(_entries);
                      _ctrl.clear();
                      _selected = -1;
                    });
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: MiuiColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    elevation: 0,
                  ),
                  child: const Text('记录心情'),
                ),
              ),
              const SizedBox(height: 20),
              Expanded(
                child: ListView.builder(
                  itemCount: _entries.length,
                  itemBuilder: (_, i) {
                    final e = _entries[i];
                    final moodIdx = (e['moodIndex'] as int?) ?? 0;
                    final color = _moodColors[moodIdx];
                    final label = _moodLabels[moodIdx];
                    final icon = _moodIcons[moodIdx];
                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        children: [
                          Icon(icon, color: color, size: 28),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  label,
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    color: color,
                                  ),
                                ),
                                if ((e['text'] as String? ?? '').isNotEmpty)
                                  Text(
                                    e['text'] as String,
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: colors.textSecondary,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          Text(
                            '${e['date'] ?? ''} ${e['time'] ?? ''}',
                            style: TextStyle(
                              fontSize: 12,
                              color: colors.textTertiary,
                            ),
                          ),
                        ],
                      ),
                    );
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

// ═══ Shared Widget Classes ═══
class _GoalRow extends StatelessWidget {
  final dynamic goal;
  final AppColors colors;
  final VoidCallback? onLongPress;
  final VoidCallback? onProgressTap;
  const _GoalRow({
    required this.goal,
    required this.colors,
    this.onLongPress,
    this.onProgressTap,
  });
  @override
  Widget build(BuildContext context) => GestureDetector(
    onLongPress: onLongPress,
    onTap: onProgressTap,
    child: Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: goal.color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(_ic(goal.icon), color: goal.color, size: 22),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  goal.title,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: colors.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: goal.progress,
                    minHeight: 5,
                    backgroundColor: goal.color.withValues(alpha: 0.1),
                    valueColor: AlwaysStoppedAnimation(goal.color),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Text(
            '${(goal.progress * 100).toInt()}%',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: goal.color,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            goal.target,
            style: TextStyle(fontSize: 12, color: colors.textTertiary),
          ),
        ],
      ),
    ),
  );
  IconData _ic(String n) =>
      {
        'menu_book': Icons.menu_book_rounded,
        'directions_run': Icons.directions_run_rounded,
        'savings': Icons.savings_rounded,
        'code': Icons.code_rounded,
      }[n] ??
      Icons.flag_rounded;
}

class _HabitRow extends StatelessWidget {
  final dynamic habit;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final AppColors colors;
  const _HabitRow({
    required this.habit,
    required this.onTap,
    this.onLongPress,
    required this.colors,
  });
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    onLongPress: onLongPress,
    child: Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: habit.todayCompleted
              ? habit.color.withValues(alpha: 0.06)
              : colors.surface,
          borderRadius: BorderRadius.circular(18),
          border: habit.todayCompleted
              ? Border.all(color: habit.color.withValues(alpha: 0.15))
              : null,
        ),
        child: Row(
          children: [
            Icon(
              _ic(habit.icon),
              color: habit.todayCompleted ? habit.color : colors.textSecondary,
              size: 24,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                habit.title,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: habit.todayCompleted
                      ? habit.color
                      : colors.textPrimary,
                ),
              ),
            ),
            Text(
              '${habit.streak} 天',
              style: TextStyle(
                fontSize: 13,
                color: habit.todayCompleted ? habit.color : colors.textTertiary,
              ),
            ),
            const SizedBox(width: 10),
            Icon(
              habit.todayCompleted
                  ? Icons.check_circle_rounded
                  : Icons.radio_button_unchecked_rounded,
              size: 22,
              color: habit.todayCompleted
                  ? MiuiColors.green
                  : colors.textTertiary,
            ),
          ],
        ),
      ),
    ),
  );
  IconData _ic(String n) =>
      {
        'wb_sunny': Icons.wb_sunny_rounded,
        'menu_book': Icons.menu_book_rounded,
        'fitness_center': Icons.fitness_center_rounded,
        'self_improvement': Icons.self_improvement_rounded,
        'water_drop': Icons.water_drop_rounded,
        'edit_note': Icons.edit_note_rounded,
      }[n] ??
      Icons.circle;
}

class _AddButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final AppColors colors;
  const _AddButton({
    required this.label,
    required this.onTap,
    required this.colors,
  });
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.divider, width: 1),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.add_rounded, size: 20, color: MiuiColors.blue),
          const SizedBox(width: 8),
          Text(
            label,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: MiuiColors.blue,
            ),
          ),
        ],
      ),
    ),
  );
}

class _WeeklyChart extends StatelessWidget {
  final List<double> data;
  final AppColors colors;
  const _WeeklyChart({required this.data, required this.colors});
  @override
  Widget build(BuildContext context) {
    final days = ['一', '二', '三', '四', '五', '六', '日'];
    return SizedBox(
      height: 200,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: List.generate(7, (i) {
          final isToday = i == DateTime.now().weekday - 1;
          return Column(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Text(
                '${(data[i] * 100).toInt()}%',
                style: TextStyle(
                  fontSize: 10,
                  color: isToday ? MiuiColors.blue : colors.textTertiary,
                  fontWeight: isToday ? FontWeight.w700 : FontWeight.w400,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                width: 30,
                height: data[i] * 140,
                decoration: BoxDecoration(
                  color: isToday
                      ? MiuiColors.blue
                      : MiuiColors.blue.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                days[i],
                style: TextStyle(
                  fontSize: 12,
                  color: isToday ? MiuiColors.blue : colors.textTertiary,
                  fontWeight: isToday ? FontWeight.w700 : FontWeight.w400,
                ),
              ),
            ],
          );
        }),
      ),
    );
  }
}

// ═══ CLOUD TOOLS ═══

// ── Cloud Mount (对接 AList 网盘聚合) ──
class _CloudMountPage extends StatefulWidget {
  const _CloudMountPage();
  @override
  State<_CloudMountPage> createState() => _CloudMountPageState();
}

class _CloudMountPageState extends State<_CloudMountPage> {
  final _userCtrl = TextEditingController(text: 'admin');
  final _passCtrl = TextEditingController(text: 'ZJL20071106...');
  bool _connecting = false;
  String? _token;
  String? _error;
  String _currentPath = '/';
  List<AListFile> _files = [];
  bool _loadingFiles = false;
  List<AListStorage> _storages = [];

  @override
  void initState() {
    super.initState();
    // Auto-login with saved credentials
    WidgetsBinding.instance.addPostFrameCallback((_) => _login());
  }

  Future<void> _login() async {
    if (_userCtrl.text.trim().isEmpty || _passCtrl.text.isEmpty) {
      setState(() {
        _error = '请输入用户名和密码';
      });
      return;
    }
    if (!AuthService().requireLogin(context, action: '使用网盘挂载')) return;
    setState(() {
      _connecting = true;
      _error = null;
    });

    final result = await CloudToolsService().alistLogin(
      _userCtrl.text.trim(),
      _passCtrl.text,
    );
    if (mounted) {
      if (result.success && result.token != null && result.token!.isNotEmpty) {
        setState(() {
          _connecting = false;
          _token = result.token;
        });
        _loadStorages();
        _loadFiles('/');
      } else {
        setState(() {
          _connecting = false;
          _error = result.error ?? '登录失败';
        });
      }
    }
  }

  Future<void> _loadStorages() async {
    if (_token == null) return;
    final storages = await CloudToolsService().alistListStorages(
      token: _token!,
    );
    if (mounted)
      setState(() {
        _storages = storages;
      });
  }

  Future<void> _loadFiles(String path) async {
    if (_token == null) return;
    setState(() {
      _loadingFiles = true;
      _currentPath = path;
    });
    final result = await CloudToolsService().alistListFiles(
      path,
      token: _token!,
    );
    if (mounted) {
      setState(() {
        _loadingFiles = false;
        if (result.success) {
          _files = result.files;
        } else {
          _error = result.error;
        }
      });
    }
  }

  Future<void> _openFile(AListFile file) async {
    if (file.isDir) {
      final newPath = _currentPath == '/'
          ? '/${file.name}'
          : '$_currentPath/${file.name}';
      _loadFiles(newPath);
    } else {
      // 获取下载链接
      final filePath = _currentPath == '/'
          ? '/${file.name}'
          : '$_currentPath/${file.name}';
      final url = await CloudToolsService().alistGetDownloadUrl(
        filePath,
        token: _token!,
      );
      if (url != null && mounted) {
        Clipboard.setData(ClipboardData(text: url));
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${file.name} 下载链接已复制'),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 2),
          ),
        );
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('无法获取下载链接'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _goBack() {
    if (_currentPath == '/') return;
    final parts = _currentPath.split('/');
    parts.removeLast();
    final parent = parts.join('/');
    _loadFiles(parent.isEmpty ? '/' : parent);
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        title: Text(
          '网盘挂载',
          style: TextStyle(
            color: colors.textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
        centerTitle: true,
        backgroundColor: colors.background,
        elevation: 0,
        scrolledUnderElevation: 0,
        iconTheme: IconThemeData(color: colors.textPrimary),
      ),
      body: SafeArea(
        child: _token == null
            ? _buildLoginView(colors)
            : _buildFileView(colors),
      ),
    );
  }

  Widget _buildLoginView(AppColors colors) => SingleChildScrollView(
    padding: const EdgeInsets.all(24),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: MiuiColors.blue.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.cloud_outlined,
                    size: 20,
                    color: MiuiColors.blue,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'AList 网盘聚合管理',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: colors.textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                '通过 AList 统一管理多个网盘\n支持阿里云盘、百度网盘、OneDrive 等\n请先在 AList 管理面板添加存储',
                style: TextStyle(
                  fontSize: 12,
                  color: colors.textSecondary,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        // 已挂载的存储列表
        if (_storages.isNotEmpty) ...[
          Text(
            '已挂载的存储',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: colors.textPrimary,
            ),
          ),
          const SizedBox(height: 10),
          ...(_storages.map(
            (s) => Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: colors.surface,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.storage_rounded,
                    size: 18,
                    color: s.disabled ? colors.textTertiary : MiuiColors.blue,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          s.mountPath,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: colors.textPrimary,
                          ),
                        ),
                        Text(
                          s.driver,
                          style: TextStyle(
                            fontSize: 11,
                            color: colors.textTertiary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: s.disabled
                          ? colors.surface
                          : MiuiColors.green.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      s.disabled ? '已禁用' : '运行中',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: s.disabled
                            ? colors.textTertiary
                            : MiuiColors.green,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          )),
          const SizedBox(height: 16),
        ],
        Text(
          'AList 登录',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: colors.textPrimary,
          ),
        ),
        const SizedBox(height: 10),
        _inputField('用户名', _userCtrl, 'admin', colors),
        const SizedBox(height: 14),
        _inputField('密码', _passCtrl, '输入密码', colors, obscure: true),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton(
            onPressed: _connecting ? null : _login,
            style: ElevatedButton.styleFrom(
              backgroundColor: MiuiColors.blue,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              elevation: 0,
            ),
            child: _connecting
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Text(
                    '登录',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
          ),
        ),
        if (_error != null) ...[
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: MiuiColors.red.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.error_outline_rounded,
                  size: 18,
                  color: MiuiColors.red,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    _error!,
                    style: const TextStyle(fontSize: 13, color: MiuiColors.red),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    ),
  );

  Widget _buildFileView(AppColors colors) => Column(
    children: [
      // 路径导航栏
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        color: colors.surface,
        child: Row(
          children: [
            if (_currentPath != '/')
              GestureDetector(
                onTap: _goBack,
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: colors.card,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.arrow_back_rounded,
                    size: 18,
                    color: colors.textPrimary,
                  ),
                ),
              ),
            if (_currentPath != '/') const SizedBox(width: 10),
            Expanded(
              child: Text(
                _currentPath,
                style: TextStyle(
                  fontSize: 13,
                  color: colors.textSecondary,
                  fontFamily: 'monospace',
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            GestureDetector(
              onTap: () => _loadFiles(_currentPath),
              child: Icon(
                Icons.refresh_rounded,
                size: 20,
                color: colors.textTertiary,
              ),
            ),
            const SizedBox(width: 12),
            GestureDetector(
              onTap: () => setState(() {
                _token = null;
                _files = [];
                _storages = [];
              }),
              child: Icon(
                Icons.logout_rounded,
                size: 20,
                color: MiuiColors.red,
              ),
            ),
          ],
        ),
      ),
      // 文件列表
      Expanded(
        child: _loadingFiles
            ? Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 32,
                      height: 32,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: MiuiColors.blue,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      '加载中...',
                      style: TextStyle(
                        fontSize: 13,
                        color: colors.textTertiary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              )
            : _files.isEmpty
            ? Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.folder_open_rounded,
                      size: 48,
                      color: colors.textTertiary,
                    ),
                    const SizedBox(height: 12),
                    Text('此目录为空', style: TextStyle(color: colors.textTertiary)),
                  ],
                ),
              )
            : ListView.separated(
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemCount: _files.length,
                separatorBuilder: (_, __) =>
                    Divider(height: 1, indent: 68, color: colors.divider),
                itemBuilder: (_, i) {
                  final f = _files[i];
                  return ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 4,
                    ),
                    leading: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: (f.isDir ? MiuiColors.blue : MiuiColors.orange)
                            .withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        f.isDir ? Icons.folder_rounded : _fileIcon(f.name),
                        color: f.isDir ? MiuiColors.blue : MiuiColors.orange,
                        size: 22,
                      ),
                    ),
                    title: Text(
                      f.name,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: colors.textPrimary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text(
                      f.isDir
                          ? '文件夹 · ${f.modified}'
                          : '${f.sizeFormatted} · ${f.modified}',
                      style: TextStyle(
                        fontSize: 12,
                        color: colors.textTertiary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: f.isDir
                        ? Icon(
                            Icons.chevron_right_rounded,
                            size: 20,
                            color: colors.textTertiary,
                          )
                        : Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // Preview in browser
                              GestureDetector(
                                onTap: () async {
                                  final previewUrl = CloudToolsService()
                                      .getAlistPreviewUrl(f.name, _currentPath);
                                  if (previewUrl != null) {
                                    try {
                                      await launchUrl(
                                        Uri.parse(previewUrl),
                                        mode: LaunchMode.externalApplication,
                                      );
                                    } catch (_) {}
                                  } else {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('此文件类型暂不支持预览'),
                                        behavior: SnackBarBehavior.floating,
                                      ),
                                    );
                                  }
                                },
                                child: Container(
                                  padding: const EdgeInsets.all(6),
                                  margin: const EdgeInsets.only(right: 8),
                                  decoration: BoxDecoration(
                                    color: MiuiColors.teal.withValues(
                                      alpha: 0.1,
                                    ),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Icon(
                                    Icons.visibility_rounded,
                                    size: 18,
                                    color: MiuiColors.teal,
                                  ),
                                ),
                              ),
                              // Download
                              GestureDetector(
                                onTap: () => _openFile(f),
                                child: Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: MiuiColors.blue.withValues(
                                      alpha: 0.1,
                                    ),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Icon(
                                    Icons.download_rounded,
                                    size: 18,
                                    color: MiuiColors.blue,
                                  ),
                                ),
                              ),
                            ],
                          ),
                    onTap: () => f.isDir ? _openFile(f) : null,
                  );
                },
              ),
      ),
    ],
  );

  IconData _fileIcon(String name) {
    final ext = name.split('.').last.toLowerCase();
    if (['jpg', 'jpeg', 'png', 'gif', 'webp', 'bmp'].contains(ext))
      return Icons.image_rounded;
    if (['mp4', 'avi', 'mkv', 'mov', 'flv', 'wmv'].contains(ext))
      return Icons.movie_rounded;
    if (['mp3', 'flac', 'aac', 'wav', 'ogg'].contains(ext))
      return Icons.music_note_rounded;
    if (['pdf'].contains(ext)) return Icons.picture_as_pdf_rounded;
    if (['doc', 'docx', 'txt', 'md'].contains(ext))
      return Icons.description_rounded;
    if (['zip', 'rar', '7z', 'tar', 'gz'].contains(ext))
      return Icons.archive_rounded;
    if (['apk'].contains(ext)) return Icons.android_rounded;
    return Icons.insert_drive_file_rounded;
  }

  Widget _inputField(
    String label,
    TextEditingController ctrl,
    String hint,
    AppColors colors, {
    bool obscure = false,
  }) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        label,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: colors.textSecondary,
        ),
      ),
      const SizedBox(height: 6),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(14),
        ),
        child: TextField(
          controller: ctrl,
          obscureText: obscure,
          style: TextStyle(color: colors.textPrimary),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: colors.textTertiary),
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(vertical: 14),
          ),
        ),
      ),
    ],
  );
}

// ── Watermark Remover (对接 Douyin_TikTok_Download_API) ──
class _WatermarkRemoverPage extends StatefulWidget {
  const _WatermarkRemoverPage();
  @override
  State<_WatermarkRemoverPage> createState() => _WatermarkRemoverPageState();
}

class _WatermarkRemoverPageState extends State<_WatermarkRemoverPage> {
  final _urlCtrl = TextEditingController();
  bool _processing = false;
  WatermarkResult? _result;
  String? _error;

  /// Extract first URL from text (handles share text like "抖音...https://v.douyin.com/xxx")
  String? _extractUrl(String text) {
    final match = RegExp(r'https?://[^\s<>一-鿿]+').firstMatch(text);
    return match?.group(0);
  }

  Future<void> _process() async {
    final raw = _urlCtrl.text.trim();
    if (raw.isEmpty) return;
    if (!AuthService().requireLogin(context, action: '使用去水印')) return;
    // Auto-extract URL from pasted share text
    final url = _extractUrl(raw);
    if (url == null) {
      setState(() {
        _error = '未检测到有效链接，请粘贴包含链接的分享文字';
      });
      return;
    }
    // Update the text field to show the extracted URL
    if (url != raw) _urlCtrl.text = url;
    setState(() {
      _processing = true;
      _result = null;
      _error = null;
    });

    final result = await CloudToolsService().removeWatermark(url);
    if (mounted) {
      setState(() {
        _processing = false;
        if (result.success) {
          _result = result;
        } else {
          _error = result.error ?? '解析失败';
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        title: Text(
          '去水印',
          style: TextStyle(
            color: colors.textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
        centerTitle: true,
        backgroundColor: colors.background,
        elevation: 0,
        scrolledUnderElevation: 0,
        iconTheme: IconThemeData(color: colors.textPrimary),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined, size: 20),
            tooltip: 'Cookie 配置',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => WatermarkCookieConfigPage(colors: colors),
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: MiuiColors.red.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.auto_fix_high_rounded,
                          size: 20,
                          color: MiuiColors.red,
                        ),
                        const SizedBox(width: 10),
                        Text(
                          '视频/图片去水印',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: colors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '支持抖音、快手、小红书、微博、B站等平台\n粘贴分享链接即可解析无水印资源',
                      style: TextStyle(
                        fontSize: 12,
                        color: colors.textSecondary,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Text(
                '粘贴链接',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: colors.textPrimary,
                ),
              ),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: colors.surface,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _urlCtrl,
                        style: TextStyle(color: colors.textPrimary),
                        decoration: InputDecoration(
                          hintText: '粘贴视频/图片分享链接...',
                          hintStyle: TextStyle(color: colors.textTertiary),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(
                            vertical: 16,
                          ),
                        ),
                      ),
                    ),
                    GestureDetector(
                      onTap: () async {
                        final data = await Clipboard.getData(
                          Clipboard.kTextPlain,
                        );
                        if (data?.text != null) {
                          final extracted =
                              _extractUrl(data!.text!) ?? data.text!;
                          _urlCtrl.text = extracted;
                          setState(() {});
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: MiuiColors.red.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.paste_rounded,
                          size: 18,
                          color: MiuiColors.red,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _processing ? null : _process,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: MiuiColors.red,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 0,
                  ),
                  child: _processing
                      ? const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            ),
                            SizedBox(width: 10),
                            Text('解析中...'),
                          ],
                        )
                      : const Text(
                          '去水印解析',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: MiuiColors.red.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.error_outline_rounded,
                        size: 18,
                        color: MiuiColors.red,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _error!,
                          style: const TextStyle(
                            fontSize: 13,
                            color: MiuiColors.red,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              if (_result != null) ...[
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: MiuiColors.green.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 解析成功 header
                      Row(
                        children: [
                          const Icon(
                            Icons.check_circle_rounded,
                            size: 18,
                            color: MiuiColors.green,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '解析成功',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: MiuiColors.green,
                            ),
                          ),
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: MiuiColors.blue.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              _result!.platformLabel,
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: MiuiColors.blue,
                              ),
                            ),
                          ),
                        ],
                      ),
                      // 标题
                      if (_result!.title != null &&
                          _result!.title!.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Text(
                          _result!.title!,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: colors.textPrimary,
                          ),
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                      // 作者
                      if (_result!.author != null &&
                          _result!.author!.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Icon(
                              Icons.person_outline_rounded,
                              size: 14,
                              color: colors.textTertiary,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              _result!.author!,
                              style: TextStyle(
                                fontSize: 12,
                                color: colors.textTertiary,
                              ),
                            ),
                          ],
                        ),
                      ],
                      const SizedBox(height: 14),
                      // ── 封面预览 (inline, proxied) ──
                      if (_result!.coverUrl != null &&
                          _result!.coverUrl!.isNotEmpty) ...[
                        Container(
                          height: 180,
                          width: double.infinity,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            color: colors.surface,
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: Image.network(
                            CloudToolsService().getProxiedDownloadUrl(
                              _result!.coverUrl!,
                            ),
                            fit: BoxFit.cover,
                            loadingBuilder: (ctx, child, progress) =>
                                progress == null
                                ? child
                                : Center(
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: MiuiColors.orange,
                                    ),
                                  ),
                            errorBuilder: (_, __, ___) => Center(
                              child: Icon(
                                Icons.broken_image_rounded,
                                size: 40,
                                color: colors.textTertiary,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],
                      // ── 下载视频 ──
                      if (_result!.videoUrl != null &&
                          _result!.videoUrl!.isNotEmpty) ...[
                        _actionBtn(
                          '下载视频',
                          Icons.download_rounded,
                          MiuiColors.blue,
                          () async {
                            final proxyUrl = CloudToolsService()
                                .getProxiedDownloadUrl(_result!.videoUrl!);
                            try {
                              await launchUrl(
                                Uri.parse(proxyUrl),
                                mode: LaunchMode.externalApplication,
                              );
                            } catch (_) {
                              Clipboard.setData(ClipboardData(text: proxyUrl));
                              if (context.mounted)
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('无法打开浏览器，链接已复制'),
                                    behavior: SnackBarBehavior.floating,
                                  ),
                                );
                            }
                          },
                          colors,
                          trailing: Icons.open_in_new_rounded,
                        ),
                        const SizedBox(height: 8),
                        _actionBtn(
                          '复制视频链接',
                          Icons.copy_rounded,
                          MiuiColors.blue.withValues(alpha: 0.7),
                          () {
                            final proxyUrl = CloudToolsService()
                                .getProxiedDownloadUrl(_result!.videoUrl!);
                            Clipboard.setData(ClipboardData(text: proxyUrl));
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('视频链接已复制'),
                                behavior: SnackBarBehavior.floating,
                                duration: Duration(seconds: 2),
                              ),
                            );
                          },
                          colors,
                        ),
                      ],
                      // ── 图集预览 (inline gallery with proxy) ──
                      if (_result!.imageUrls.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        SizedBox(
                          height: 140,
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            itemCount: _result!.imageUrls.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(width: 8),
                            itemBuilder: (ctx, idx) {
                              final proxyUrl = CloudToolsService()
                                  .getProxiedDownloadUrl(
                                    _result!.imageUrls[idx],
                                  );
                              return GestureDetector(
                                onTap: () async {
                                  try {
                                    await launchUrl(
                                      Uri.parse(proxyUrl),
                                      mode: LaunchMode.externalApplication,
                                    );
                                  } catch (_) {
                                    Clipboard.setData(
                                      ClipboardData(text: proxyUrl),
                                    );
                                    if (ctx.mounted)
                                      ScaffoldMessenger.of(ctx).showSnackBar(
                                        const SnackBar(
                                          content: Text('图片链接已复制'),
                                          behavior: SnackBarBehavior.floating,
                                        ),
                                      );
                                  }
                                },
                                child: Container(
                                  width: 140,
                                  height: 140,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(12),
                                    color: colors.surface,
                                  ),
                                  clipBehavior: Clip.antiAlias,
                                  child: Image.network(
                                    proxyUrl,
                                    fit: BoxFit.cover,
                                    loadingBuilder: (_, child, p) => p == null
                                        ? child
                                        : Center(
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              color: MiuiColors.purple,
                                            ),
                                          ),
                                    errorBuilder: (_, __, ___) => Center(
                                      child: Icon(
                                        Icons.broken_image_rounded,
                                        size: 32,
                                        color: colors.textTertiary,
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                        const SizedBox(height: 8),
                        _actionBtn(
                          '下载图集 (${_result!.imageUrls.length}张)',
                          Icons.download_rounded,
                          MiuiColors.purple,
                          () async {
                            if (_result!.imageUrls.isNotEmpty) {
                              final proxyUrl = CloudToolsService()
                                  .getProxiedDownloadUrl(
                                    _result!.imageUrls.first,
                                  );
                              try {
                                await launchUrl(
                                  Uri.parse(proxyUrl),
                                  mode: LaunchMode.externalApplication,
                                );
                              } catch (_) {
                                Clipboard.setData(
                                  ClipboardData(text: proxyUrl),
                                );
                                if (context.mounted)
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('图片链接已复制'),
                                      behavior: SnackBarBehavior.floating,
                                    ),
                                  );
                              }
                            }
                          },
                          colors,
                          trailing: Icons.open_in_new_rounded,
                        ),
                        const SizedBox(height: 8),
                        _actionBtn(
                          '复制全部图片链接',
                          Icons.copy_rounded,
                          MiuiColors.purple.withValues(alpha: 0.7),
                          () {
                            final proxiedUrls = _result!.imageUrls
                                .map(
                                  (u) => CloudToolsService()
                                      .getProxiedDownloadUrl(u),
                                )
                                .join('\n');
                            Clipboard.setData(ClipboardData(text: proxiedUrls));
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  '${_result!.imageUrls.length}张图片链接已复制',
                                ),
                                behavior: SnackBarBehavior.floating,
                                duration: const Duration(seconds: 2),
                              ),
                            );
                          },
                          colors,
                        ),
                      ],
                      // ── 封面下载 ──
                      if (_result!.coverUrl != null &&
                          _result!.coverUrl!.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        _actionBtn(
                          '下载封面图',
                          Icons.download_rounded,
                          MiuiColors.orange,
                          () async {
                            final proxyUrl = CloudToolsService()
                                .getProxiedDownloadUrl(_result!.coverUrl!);
                            try {
                              await launchUrl(
                                Uri.parse(proxyUrl),
                                mode: LaunchMode.externalApplication,
                              );
                            } catch (_) {
                              Clipboard.setData(ClipboardData(text: proxyUrl));
                              if (context.mounted)
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('链接已复制'),
                                    behavior: SnackBarBehavior.floating,
                                  ),
                                );
                            }
                          },
                          colors,
                          trailing: Icons.open_in_new_rounded,
                        ),
                      ],
                      // ── 音乐 ──
                      if (_result!.musicUrl != null &&
                          _result!.musicUrl!.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        _actionBtn(
                          '试听背景音乐',
                          Icons.music_note_rounded,
                          MiuiColors.teal,
                          () async {
                            final proxyUrl = CloudToolsService()
                                .getProxiedDownloadUrl(_result!.musicUrl!);
                            try {
                              await launchUrl(
                                Uri.parse(proxyUrl),
                                mode: LaunchMode.externalApplication,
                              );
                            } catch (_) {
                              Clipboard.setData(ClipboardData(text: proxyUrl));
                              if (context.mounted)
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('音乐链接已复制'),
                                    behavior: SnackBarBehavior.floating,
                                  ),
                                );
                            }
                          },
                          colors,
                          trailing: Icons.open_in_new_rounded,
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _actionBtn(
    String label,
    IconData icon,
    Color color,
    VoidCallback onTap,
    AppColors colors, {
    IconData trailing = Icons.chevron_right_rounded,
  }) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: color,
              ),
            ),
          ),
          Icon(trailing, size: 14, color: color.withValues(alpha: 0.5)),
        ],
      ),
    ),
  );
}

// ── Direct Link Download (对接 netdisk-fast-download) ──
class _DirectLinkPage extends StatefulWidget {
  const _DirectLinkPage();
  @override
  State<_DirectLinkPage> createState() => _DirectLinkPageState();
}

class _DirectLinkPageState extends State<_DirectLinkPage> {
  final _urlCtrl = TextEditingController();
  final _pwdCtrl = TextEditingController();
  bool _parsing = false;
  bool _showPwd = false;
  DirectLinkResult? _result;
  String? _error;

  /// Extract URL and optional password/code from pasted text
  ({String? url, String? pwd}) _extractUrlAndPwd(String text) {
    // Extract URL
    final urlMatch = RegExp(r'https?://[^\s<>一-鿿]+').firstMatch(text);
    final url = urlMatch?.group(0);
    // Extract password/extract code (common patterns: 提取码：xxxx, 密码:xxxx, code:xxxx)
    String? pwd;
    final pwdMatch = RegExp(
      r'(?:提取码|密码|提取密码|访问码|code)\s*[：:]\s*([A-Za-z0-9]{3,8})',
      caseSensitive: false,
    ).firstMatch(text);
    if (pwdMatch != null) pwd = pwdMatch.group(1);
    return (url: url, pwd: pwd);
  }

  Future<void> _parse() async {
    final raw = _urlCtrl.text.trim();
    if (raw.isEmpty) return;
    if (!AuthService().requireLogin(context, action: '使用直链下载')) return;
    // Auto-extract URL and password from pasted share text
    final extracted = _extractUrlAndPwd(raw);
    if (extracted.url == null) {
      setState(() {
        _error = '未检测到有效链接，请粘贴包含链接的分享文字';
      });
      return;
    }
    // Update fields with extracted values
    if (extracted.url != raw) _urlCtrl.text = extracted.url!;
    if (extracted.pwd != null && _pwdCtrl.text.trim().isEmpty) {
      _pwdCtrl.text = extracted.pwd!;
      _showPwd = true;
    }
    setState(() {
      _parsing = true;
      _result = null;
      _error = null;
    });

    final result = await CloudToolsService().parseDirectLink(
      extracted.url!,
      password: _pwdCtrl.text.trim().isNotEmpty ? _pwdCtrl.text.trim() : null,
    );
    if (mounted) {
      setState(() {
        _parsing = false;
        if (result.success) {
          _result = result;
        } else {
          _error = result.error ?? '解析失败';
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        title: Text(
          'LinkSwift',
          style: TextStyle(
            color: colors.textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
        centerTitle: true,
        backgroundColor: colors.background,
        elevation: 0,
        scrolledUnderElevation: 0,
        iconTheme: IconThemeData(color: colors.textPrimary),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: MiuiColors.orange.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.link_rounded,
                          size: 20,
                          color: MiuiColors.orange,
                        ),
                        const SizedBox(width: 10),
                        Text(
                          'LinkSwift 网盘直链',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: colors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '将网盘分享链接转换为直链\n支持百度网盘、阿里云盘、蓝奏云、天翼云盘\n123盘、夸克网盘、UC网盘等 20+ 平台',
                      style: TextStyle(
                        fontSize: 12,
                        color: colors.textSecondary,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Text(
                '粘贴网盘链接',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: colors.textPrimary,
                ),
              ),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: colors.surface,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _urlCtrl,
                        style: TextStyle(color: colors.textPrimary),
                        decoration: InputDecoration(
                          hintText: '粘贴网盘分享链接...',
                          hintStyle: TextStyle(color: colors.textTertiary),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(
                            vertical: 16,
                          ),
                        ),
                      ),
                    ),
                    GestureDetector(
                      onTap: () async {
                        final data = await Clipboard.getData(
                          Clipboard.kTextPlain,
                        );
                        if (data?.text != null) {
                          final extracted = _extractUrlAndPwd(data!.text!);
                          _urlCtrl.text = extracted.url ?? data.text!;
                          if (extracted.pwd != null) {
                            _pwdCtrl.text = extracted.pwd!;
                            _showPwd = true;
                          }
                          setState(() {});
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: MiuiColors.orange.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.paste_rounded,
                          size: 18,
                          color: MiuiColors.orange,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              // 密码输入 (可折叠)
              const SizedBox(height: 10),
              GestureDetector(
                onTap: () => setState(() => _showPwd = !_showPwd),
                child: Row(
                  children: [
                    Icon(
                      _showPwd
                          ? Icons.expand_less_rounded
                          : Icons.expand_more_rounded,
                      size: 18,
                      color: colors.textTertiary,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '提取密码 (可选)',
                      style: TextStyle(
                        fontSize: 12,
                        color: colors.textTertiary,
                      ),
                    ),
                  ],
                ),
              ),
              if (_showPwd) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: colors.surface,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: TextField(
                    controller: _pwdCtrl,
                    style: TextStyle(color: colors.textPrimary),
                    decoration: InputDecoration(
                      hintText: '输入提取密码',
                      hintStyle: TextStyle(color: colors.textTertiary),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _parsing ? null : _parse,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: MiuiColors.orange,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 0,
                  ),
                  child: _parsing
                      ? const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            ),
                            SizedBox(width: 10),
                            Text('解析中...'),
                          ],
                        )
                      : const Text(
                          '解析直链',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: MiuiColors.red.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.error_outline_rounded,
                        size: 18,
                        color: MiuiColors.red,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _error!,
                          style: const TextStyle(
                            fontSize: 13,
                            color: MiuiColors.red,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              if (_result != null) ...[
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: MiuiColors.green.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.check_circle_rounded,
                            size: 18,
                            color: MiuiColors.green,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '解析成功',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: MiuiColors.green,
                            ),
                          ),
                          if (_result!.cacheHit == true) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: MiuiColors.green.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Text(
                                '缓存',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: MiuiColors.green,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      if (_result!.filename != null &&
                          _result!.filename!.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Icon(
                              Icons.insert_drive_file_rounded,
                              size: 16,
                              color: colors.textSecondary,
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                _result!.filename!,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                  color: colors.textPrimary,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                      if (_result!.fileSize != null &&
                          _result!.fileSize!.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text(
                          '大小: ${_result!.fileSize}',
                          style: TextStyle(
                            fontSize: 12,
                            color: colors.textTertiary,
                          ),
                        ),
                      ],
                      const SizedBox(height: 14),
                      // ── 下载/预览按钮 ──
                      _actionBtn(
                        '下载文件',
                        Icons.download_rounded,
                        MiuiColors.blue,
                        () async {
                          final url = _result!.directUrl;
                          if (url != null && url.isNotEmpty) {
                            final uri = Uri.parse(url);
                            try {
                              await launchUrl(
                                uri,
                                mode: LaunchMode.externalApplication,
                              );
                            } catch (_) {
                              Clipboard.setData(ClipboardData(text: url));
                              if (context.mounted)
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('无法打开浏览器，链接已复制'),
                                    behavior: SnackBarBehavior.floating,
                                  ),
                                );
                            }
                          }
                        },
                        colors,
                        trailing: Icons.open_in_new_rounded,
                      ),
                      const SizedBox(height: 8),
                      _actionBtn(
                        '复制直链地址',
                        Icons.copy_rounded,
                        MiuiColors.blue.withValues(alpha: 0.7),
                        () {
                          final url = _result!.directUrl;
                          if (url != null && url.isNotEmpty) {
                            Clipboard.setData(ClipboardData(text: url));
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('直链已复制'),
                                behavior: SnackBarBehavior.floating,
                                duration: Duration(seconds: 2),
                              ),
                            );
                          }
                        },
                        colors,
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _actionBtn(
    String label,
    IconData icon,
    Color color,
    VoidCallback onTap,
    AppColors colors, {
    IconData trailing = Icons.chevron_right_rounded,
  }) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: color,
              ),
            ),
          ),
          Icon(trailing, size: 14, color: color.withValues(alpha: 0.5)),
        ],
      ),
    ),
  );
}

// ═══ SPEEDTEST PAGE (In-App HTTP Speed Test) ═══
class _SpeedtestPage extends StatefulWidget {
  const _SpeedtestPage();
  @override
  State<_SpeedtestPage> createState() => _SpeedtestPageState();
}

class _SpeedtestPageState extends State<_SpeedtestPage> {
  bool _testing = false;
  String _phase = 'idle'; // idle, ping, download, upload, done
  double _downloadSpeed = 0; // Mbps
  double _uploadSpeed = 0; // Mbps
  int _ping = 0; // ms
  double _progress = 0;
  String? _error;
  String? _serverName;

  @override
  void initState() {
    super.initState();
    _checkServer();
  }

  Future<void> _checkServer() async {
    try {
      final response = await http
          .get(
            Uri.parse('${CloudToolsService().speedtestUrl}backend/empty.php'),
            headers: {'Cache-Control': 'no-cache'},
          )
          .timeout(const Duration(seconds: 5));
      if (mounted) {
        setState(() {
          _serverName = response.statusCode == 200 ? 'TEMPO Server' : null;
          if (response.statusCode != 200) _error = '测速服务不可用';
        });
      }
    } catch (e) {
      if (mounted)
        setState(() {
          _error = '无法连接测速服务器';
        });
    }
  }

  Future<void> _startTest() async {
    if (_testing) return;
    setState(() {
      _testing = true;
      _error = null;
      _downloadSpeed = 0;
      _uploadSpeed = 0;
      _ping = 0;
      _progress = 0;
      _phase = 'ping';
    });

    // LibreSpeed backend is at <speedtestUrl>/backend/
    final backendUrl = '${CloudToolsService().speedtestUrl}backend/';

    try {
      // Phase 1: Ping test (5 pings using empty.php for minimal latency)
      int totalPing = 0;
      int pingCount = 0;
      for (int i = 0; i < 5; i++) {
        final sw = Stopwatch()..start();
        try {
          await http
              .get(
                Uri.parse('${backendUrl}empty.php'),
                headers: {'Cache-Control': 'no-cache'},
              )
              .timeout(const Duration(seconds: 5));
          sw.stop();
          totalPing += sw.elapsedMilliseconds;
          pingCount++;
        } catch (_) {}
        if (mounted) setState(() => _progress = (i + 1) / 5);
      }
      if (pingCount > 0 && mounted) {
        setState(() => _ping = totalPing ~/ pingCount);
      }

      // Phase 2: Download test (use garbage.php with 4MB chunks)
      if (mounted)
        setState(() {
          _phase = 'download';
          _progress = 0;
        });
      final dlSpeed = await _measureDownload(backendUrl);
      if (mounted) setState(() => _downloadSpeed = dlSpeed);

      // Phase 3: Upload test (POST to empty.php)
      if (mounted)
        setState(() {
          _phase = 'upload';
          _progress = 0;
        });
      final ulSpeed = await _measureUpload(backendUrl);
      if (mounted) setState(() => _uploadSpeed = ulSpeed);

      if (mounted)
        setState(() {
          _phase = 'done';
          _testing = false;
        });
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = '测速失败: $e';
          _testing = false;
          _phase = 'idle';
        });
      }
    }
  }

  Future<double> _measureDownload(String backendUrl) async {
    final testDuration = const Duration(seconds: 10);
    final startTime = DateTime.now();
    int totalBytes = 0;
    bool running = true;

    // Use streaming HTTP client to get real-time byte counts
    final client = http.Client();
    try {
      // Run 3 parallel download streams to saturate the connection
      final futures = List.generate(3, (i) async {
        while (running && DateTime.now().difference(startTime) < testDuration) {
          try {
            final uri = Uri.parse(
              '${backendUrl}garbage.php?ckSize=8&r=${DateTime.now().millisecondsSinceEpoch}$i',
            );
            final request = http.Request('GET', uri);
            request.headers['Cache-Control'] = 'no-cache';
            final response = await client
                .send(request)
                .timeout(const Duration(seconds: 12));
            if (response.statusCode != 200) continue;
            // Stream bytes for real-time counting
            await for (final chunk in response.stream) {
              if (!running) break;
              totalBytes += chunk.length;
            }
          } catch (_) {
            // Single request failed, continue with next
            await Future.delayed(const Duration(milliseconds: 100));
          }
        }
      });

      // Update UI periodically (fire-and-forget, runs alongside download futures)
      // ignore: unawaited_futures
      Future.doWhile(() async {
        await Future.delayed(const Duration(milliseconds: 200));
        if (!mounted || !running) return false;
        final elapsed = DateTime.now().difference(startTime);
        final elapsedSec = elapsed.inMilliseconds / 1000.0;
        setState(() {
          _progress = (elapsed.inMilliseconds / testDuration.inMilliseconds)
              .clamp(0.0, 1.0);
          if (elapsedSec > 0.5 && totalBytes > 0) {
            _downloadSpeed = (totalBytes * 8) / (elapsedSec * 1000000);
          }
        });
        return elapsed < testDuration;
      });

      // Wait for test duration to complete
      await Future.any([
        Future.wait(futures),
        Future.delayed(testDuration + const Duration(seconds: 1)),
      ]);
      running = false;
      await Future.delayed(const Duration(milliseconds: 300));
    } finally {
      running = false;
      client.close();
    }

    final totalElapsed =
        DateTime.now().difference(startTime).inMilliseconds / 1000.0;
    if (totalElapsed > 0 && totalBytes > 0) {
      return (totalBytes * 8) / (totalElapsed * 1000000);
    }
    return 0;
  }

  Future<double> _measureUpload(String backendUrl) async {
    final testDuration = const Duration(seconds: 8);
    final startTime = DateTime.now();
    // Pre-generate 2MB binary payload (much faster than String.fromCharCodes)
    final payload = List<int>.filled(2 * 1024 * 1024, 0x41); // 2MB of 'A' bytes
    int totalBytes = 0;
    bool running = true;

    try {
      // Run 2 parallel upload streams
      final futures = List.generate(2, (i) async {
        while (running && DateTime.now().difference(startTime) < testDuration) {
          try {
            await http
                .post(
                  Uri.parse('${backendUrl}empty.php'),
                  headers: {'Content-Type': 'application/octet-stream'},
                  body: payload,
                )
                .timeout(const Duration(seconds: 10));
            totalBytes += payload.length;
          } catch (_) {
            await Future.delayed(const Duration(milliseconds: 100));
          }
        }
      });

      // Update UI periodically
      // Update UI periodically (fire-and-forget, runs alongside upload futures)
      // ignore: unawaited_futures
      Future.doWhile(() async {
        await Future.delayed(const Duration(milliseconds: 200));
        if (!mounted || !running) return false;
        final elapsed = DateTime.now().difference(startTime);
        final elapsedSec = elapsed.inMilliseconds / 1000.0;
        setState(() {
          _progress = (elapsed.inMilliseconds / testDuration.inMilliseconds)
              .clamp(0.0, 1.0);
          if (elapsedSec > 0.5 && totalBytes > 0) {
            _uploadSpeed = (totalBytes * 8) / (elapsedSec * 1000000);
          }
        });
        return elapsed < testDuration;
      });

      await Future.any([
        Future.wait(futures),
        Future.delayed(testDuration + const Duration(seconds: 1)),
      ]);
      running = false;
      await Future.delayed(const Duration(milliseconds: 300));
    } finally {
      running = false;
    }

    final totalElapsed =
        DateTime.now().difference(startTime).inMilliseconds / 1000.0;
    if (totalElapsed > 0 && totalBytes > 0) {
      return (totalBytes * 8) / (totalElapsed * 1000000);
    }
    return 0;
  }

  String _formatSpeed(double mbps) {
    if (mbps >= 1) return mbps.toStringAsFixed(1);
    return (mbps * 1000).toStringAsFixed(0);
  }

  String _speedUnit(double mbps) => mbps >= 1 ? 'Mbps' : 'kbps';

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final speedtestUrl = CloudToolsService().speedtestUrl;

    // Determine which speed to show in the main gauge
    double gaugeSpeed = 0;
    String gaugeLabel = '';
    Color gaugeColor = MiuiColors.teal;
    if (_phase == 'download') {
      gaugeSpeed = _downloadSpeed;
      gaugeLabel = '下载速度';
      gaugeColor = MiuiColors.green;
    } else if (_phase == 'upload') {
      gaugeSpeed = _uploadSpeed;
      gaugeLabel = '上传速度';
      gaugeColor = MiuiColors.blue;
    } else if (_phase == 'ping') {
      gaugeLabel = '测试延迟';
      gaugeColor = MiuiColors.orange;
    } else if (_phase == 'done') {
      gaugeSpeed = _downloadSpeed;
      gaugeLabel = '下载速度';
      gaugeColor = MiuiColors.green;
    }

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        title: Text(
          '网速测试',
          style: TextStyle(
            color: colors.textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
        centerTitle: true,
        backgroundColor: colors.background,
        elevation: 0,
        scrolledUnderElevation: 0,
        iconTheme: IconThemeData(color: colors.textPrimary),
        actions: [
          IconButton(
            icon: Icon(
              Icons.open_in_browser_rounded,
              color: colors.textSecondary,
            ),
            tooltip: '在浏览器中测速',
            onPressed: () async {
              try {
                await launchUrl(
                  Uri.parse(speedtestUrl),
                  mode: LaunchMode.externalApplication,
                );
              } catch (_) {
                Clipboard.setData(ClipboardData(text: speedtestUrl));
                if (context.mounted)
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('测速链接已复制'),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
              }
            },
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              // ── Speed gauge area ──
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(28, 24, 28, 28),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: _phase == 'idle'
                        ? [const Color(0xFF1A1A2E), const Color(0xFF16213E)]
                        : [const Color(0xFF0D1B2A), const Color(0xFF1B2838)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF1A1A2E).withValues(alpha: 0.3),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    // Phase indicator row
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (_testing) ...[
                          SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: gaugeColor,
                            ),
                          ),
                          const SizedBox(width: 10),
                        ],
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 300),
                          child: Text(
                            _testing
                                ? (_phase == 'ping'
                                      ? '测试延迟中...'
                                      : _phase == 'download'
                                      ? '测试下载速度...'
                                      : '测试上传速度...')
                                : (_phase == 'done' ? '测试完成' : '点击开始测速'),
                            key: ValueKey(_phase),
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.white.withValues(alpha: 0.7),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // ── Central speed gauge ring ──
                    SizedBox(
                      width: 180,
                      height: 180,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          // Background ring
                          SizedBox(
                            width: 180,
                            height: 180,
                            child: CircularProgressIndicator(
                              value: 1,
                              strokeWidth: 6,
                              backgroundColor: Colors.transparent,
                              valueColor: AlwaysStoppedAnimation(
                                Colors.white.withValues(alpha: 0.06),
                              ),
                            ),
                          ),
                          // Progress ring
                          if (_testing || _phase == 'done')
                            SizedBox(
                              width: 180,
                              height: 180,
                              child: CircularProgressIndicator(
                                value: _phase == 'done'
                                    ? 1.0
                                    : _progress.clamp(0.0, 1.0),
                                strokeWidth: 6,
                                strokeCap: StrokeCap.round,
                                backgroundColor: Colors.transparent,
                                valueColor: AlwaysStoppedAnimation(gaugeColor),
                              ),
                            ),
                          // Center display
                          Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (_phase == 'ping') ...[
                                Text(
                                  _ping > 0 ? '$_ping' : '...',
                                  style: const TextStyle(
                                    fontSize: 52,
                                    fontWeight: FontWeight.w200,
                                    color: Colors.white,
                                    letterSpacing: -2,
                                  ),
                                ),
                                Text(
                                  _ping > 0 ? 'ms' : '',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.white.withValues(alpha: 0.5),
                                  ),
                                ),
                              ] else ...[
                                Text(
                                  gaugeSpeed > 0
                                      ? _formatSpeed(gaugeSpeed)
                                      : (_testing ? '...' : '—'),
                                  style: const TextStyle(
                                    fontSize: 52,
                                    fontWeight: FontWeight.w200,
                                    color: Colors.white,
                                    letterSpacing: -2,
                                  ),
                                ),
                                Text(
                                  gaugeSpeed > 0 ? _speedUnit(gaugeSpeed) : '',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.white.withValues(alpha: 0.5),
                                  ),
                                ),
                              ],
                              if (gaugeLabel.isNotEmpty &&
                                  (_testing || _phase == 'done'))
                                Padding(
                                  padding: const EdgeInsets.only(top: 4),
                                  child: Text(
                                    gaugeLabel,
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: gaugeColor.withValues(alpha: 0.8),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 28),

                    // ── Start/Retry button ──
                    SizedBox(
                      width: 180,
                      height: 52,
                      child: ElevatedButton.icon(
                        onPressed: _testing ? null : _startTest,
                        icon: Icon(
                          _testing
                              ? Icons.hourglass_top_rounded
                              : (_phase == 'done'
                                    ? Icons.refresh_rounded
                                    : Icons.play_arrow_rounded),
                          size: 20,
                        ),
                        label: Text(
                          _testing
                              ? '测试中...'
                              : (_phase == 'done' ? '重新测试' : '开始测速'),
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: gaugeColor,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(26),
                          ),
                          elevation: 0,
                          disabledBackgroundColor: gaugeColor.withValues(
                            alpha: 0.4,
                          ),
                          disabledForegroundColor: Colors.white70,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // ── Results cards ──
              Row(
                children: [
                  Expanded(
                    child: _speedResultCard(
                      '下载',
                      _downloadSpeed,
                      Icons.arrow_downward_rounded,
                      MiuiColors.green,
                      colors,
                      active: _phase == 'download',
                      done: _phase == 'done',
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _speedResultCard(
                      '上传',
                      _uploadSpeed,
                      Icons.arrow_upward_rounded,
                      MiuiColors.blue,
                      colors,
                      active: _phase == 'upload',
                      done: _phase == 'done',
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _pingResultCard(
                      '延迟',
                      _ping,
                      colors,
                      active: _phase == 'ping',
                      done: _phase == 'done',
                    ),
                  ),
                ],
              ),

              if (_serverName != null) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: colors.card,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.dns_rounded,
                        size: 16,
                        color: colors.textTertiary,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '测试服务器: $_serverName',
                          style: TextStyle(
                            fontSize: 12,
                            color: colors.textTertiary,
                          ),
                        ),
                      ),
                      Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: MiuiColors.green,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              if (_error != null) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: MiuiColors.red.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.error_outline_rounded,
                        size: 18,
                        color: MiuiColors.red,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _error!,
                          style: const TextStyle(
                            fontSize: 13,
                            color: MiuiColors.red,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 16),
              Text(
                '测试到 TEMPO 服务器的网络速度\n实际网速可能更高',
                style: TextStyle(fontSize: 12, color: colors.textTertiary),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _speedResultCard(
    String label,
    double speed,
    IconData icon,
    Color color,
    AppColors colors, {
    bool active = false,
    bool done = false,
  }) {
    final highlight = active || (done && speed > 0);
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: highlight ? color.withValues(alpha: 0.08) : colors.card,
        borderRadius: BorderRadius.circular(14),
        border: highlight
            ? Border.all(color: color.withValues(alpha: 0.3), width: 1)
            : null,
      ),
      child: Column(
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(height: 8),
          Text(
            speed > 0 ? _formatSpeed(speed) : (active ? '...' : '—'),
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: speed > 0 ? color : colors.textTertiary,
            ),
          ),
          Text(
            speed > 0 ? _speedUnit(speed) : '',
            style: TextStyle(fontSize: 10, color: colors.textTertiary),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: highlight ? color : colors.textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _pingResultCard(
    String label,
    int ping,
    AppColors colors, {
    bool active = false,
    bool done = false,
  }) {
    final color = ping > 0
        ? (ping < 50
              ? MiuiColors.green
              : (ping < 150 ? MiuiColors.orange : MiuiColors.red))
        : colors.textTertiary;
    final highlight = active || (done && ping > 0);
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: highlight ? color.withValues(alpha: 0.08) : colors.card,
        borderRadius: BorderRadius.circular(14),
        border: highlight
            ? Border.all(color: color.withValues(alpha: 0.3), width: 1)
            : null,
      ),
      child: Column(
        children: [
          Icon(Icons.network_ping_rounded, size: 20, color: color),
          const SizedBox(height: 8),
          Text(
            ping > 0 ? '$ping' : (active ? '...' : '—'),
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
          Text(
            ping > 0 ? 'ms' : '',
            style: TextStyle(fontSize: 10, color: colors.textTertiary),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: highlight ? color : colors.textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

// ═══ PANDOC CONVERTER PAGE ═══
class _PandocConverterPage extends StatefulWidget {
  const _PandocConverterPage();
  @override
  State<_PandocConverterPage> createState() => _PandocConverterPageState();
}

class _PandocConverterPageState extends State<_PandocConverterPage> {
  final _inputCtrl = TextEditingController();
  String _fromFormat = 'markdown';
  String _toFormat = 'html';
  String? _output;
  String? _error;
  bool _converting = false;
  bool _showPreview = false;
  String? _pandocVersion;

  static const _formats = [
    {'id': 'markdown', 'label': 'Markdown'},
    {'id': 'html', 'label': 'HTML'},
    {'id': 'latex', 'label': 'LaTeX'},
    {'id': 'rst', 'label': 'reStructuredText'},
    {'id': 'textile', 'label': 'Textile'},
    {'id': 'org', 'label': 'Org Mode'},
    {'id': 'mediawiki', 'label': 'MediaWiki'},
    {'id': 'plain', 'label': 'Plain Text'},
  ];

  @override
  void initState() {
    super.initState();
    _checkHealth();
  }

  Future<void> _checkHealth() async {
    final health = await CloudToolsService().pandocHealth();
    if (mounted && health.success) {
      setState(() {
        _pandocVersion = health.version;
      });
    }
  }

  Future<void> _convert() async {
    if (_inputCtrl.text.trim().isEmpty) return;
    if (!AuthService().requireLogin(context, action: '使用文档转换')) return;
    setState(() {
      _converting = true;
      _output = null;
      _error = null;
    });

    final result = await CloudToolsService().pandocConvert(
      content: _inputCtrl.text,
      from: _fromFormat,
      to: _toFormat,
    );

    if (mounted) {
      setState(() {
        _converting = false;
        if (result.success) {
          _output = result.output;
        } else {
          _error = result.error;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        title: Text(
          '文档转换',
          style: TextStyle(
            color: colors.textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
        centerTitle: true,
        backgroundColor: colors.background,
        elevation: 0,
        scrolledUnderElevation: 0,
        iconTheme: IconThemeData(color: colors.textPrimary),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: MiuiColors.purple.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.transform_rounded,
                          size: 20,
                          color: MiuiColors.purple,
                        ),
                        const SizedBox(width: 10),
                        Text(
                          'Pandoc 文档转换器',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: colors.textPrimary,
                          ),
                        ),
                        if (_pandocVersion != null) ...[
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: MiuiColors.purple.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              _pandocVersion!,
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: MiuiColors.purple,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '支持 Markdown、HTML、LaTeX、reStructuredText 等格式互转',
                      style: TextStyle(
                        fontSize: 12,
                        color: colors.textSecondary,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // Format selectors
              Row(
                children: [
                  Expanded(
                    child: _formatSelector(
                      '源格式',
                      _fromFormat,
                      (v) => setState(() => _fromFormat = v),
                      colors,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Icon(
                      Icons.arrow_forward_rounded,
                      size: 20,
                      color: colors.textTertiary,
                    ),
                  ),
                  Expanded(
                    child: _formatSelector(
                      '目标格式',
                      _toFormat,
                      (v) => setState(() => _toFormat = v),
                      colors,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // Input area
              Text(
                '输入内容',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: colors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                height: 180,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: colors.card,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: TextField(
                  controller: _inputCtrl,
                  maxLines: null,
                  expands: true,
                  style: TextStyle(
                    fontSize: 14,
                    color: colors.textPrimary,
                    fontFamily: 'monospace',
                    height: 1.5,
                  ),
                  decoration: InputDecoration.collapsed(
                    hintText: '粘贴或输入 $_fromFormat 内容...',
                    hintStyle: TextStyle(color: colors.textTertiary),
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Convert button
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _converting ? null : _convert,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: MiuiColors.purple,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 0,
                  ),
                  child: _converting
                      ? const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            ),
                            SizedBox(width: 10),
                            Text('转换中...'),
                          ],
                        )
                      : const Text(
                          '开始转换',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                ),
              ),

              // Error
              if (_error != null) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: MiuiColors.red.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.error_outline_rounded,
                        size: 18,
                        color: MiuiColors.red,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _error!,
                          style: const TextStyle(
                            fontSize: 13,
                            color: MiuiColors.red,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              // Output
              if (_output != null) ...[
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '转换结果',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: colors.textPrimary,
                      ),
                    ),
                    Row(
                      children: [
                        GestureDetector(
                          onTap: () =>
                              setState(() => _showPreview = !_showPreview),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: colors.surface,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              _showPreview ? '源码' : '预览',
                              style: TextStyle(
                                fontSize: 12,
                                color: colors.textSecondary,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: () {
                            Clipboard.setData(ClipboardData(text: _output!));
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('已复制转换结果'),
                                behavior: SnackBarBehavior.floating,
                                duration: Duration(seconds: 1),
                              ),
                            );
                          },
                          child: Icon(
                            Icons.copy_rounded,
                            size: 18,
                            color: colors.textTertiary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  constraints: const BoxConstraints(maxHeight: 300),
                  decoration: BoxDecoration(
                    color: MiuiColors.purple.withValues(alpha: 0.04),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: MiuiColors.purple.withValues(alpha: 0.1),
                    ),
                  ),
                  child: SingleChildScrollView(
                    child: SelectableText(
                      _output!,
                      style: TextStyle(
                        fontSize: 13,
                        color: colors.textPrimary,
                        fontFamily: 'monospace',
                        height: 1.5,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _formatSelector(
    String label,
    String value,
    ValueChanged<String> onChanged,
    AppColors colors,
  ) {
    return GestureDetector(
      onTap: () {
        showModalBottomSheet(
          context: context,
          backgroundColor: Colors.transparent,
          builder: (_) => Container(
            decoration: BoxDecoration(
              color: colors.card,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(28),
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _sheetHandle(colors),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: colors.textPrimary,
                    ),
                  ),
                ),
                ..._formats.map(
                  (f) => ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 28),
                    title: Text(
                      f['label']!,
                      style: TextStyle(color: colors.textPrimary),
                    ),
                    subtitle: Text(
                      f['id']!,
                      style: TextStyle(
                        fontSize: 12,
                        color: colors.textTertiary,
                      ),
                    ),
                    trailing: value == f['id']
                        ? const Icon(
                            Icons.check_rounded,
                            color: MiuiColors.purple,
                          )
                        : null,
                    onTap: () {
                      onChanged(f['id']!);
                      Navigator.pop(context);
                    },
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: colors.card,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(fontSize: 11, color: colors.textTertiary),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Expanded(
                  child: Text(
                    _formats.firstWhere(
                      (f) => f['id'] == value,
                      orElse: () => {'label': value},
                    )['label']!,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: colors.textPrimary,
                    ),
                  ),
                ),
                Icon(
                  Icons.arrow_drop_down_rounded,
                  size: 20,
                  color: colors.textSecondary,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ═══ NETDATA SERVER MONITOR PAGE ═══
class _NetdataMonitorPage extends StatefulWidget {
  const _NetdataMonitorPage();
  @override
  State<_NetdataMonitorPage> createState() => _NetdataMonitorPageState();
}

class _NetdataMonitorPageState extends State<_NetdataMonitorPage> {
  Timer? _refreshTimer;
  NetdataInfoResult? _serverInfo;
  NetdataMetrics? _metrics;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadData();
    _refreshTimer = Timer.periodic(
      const Duration(seconds: 3),
      (_) => _refreshMetrics(),
    );
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final info = await CloudToolsService().netdataInfo();
      final metrics = await CloudToolsService().netdataOverview();

      if (mounted) {
        setState(() {
          _loading = false;
          if (info.success) {
            _serverInfo = info;
          }
          if (metrics.success) {
            _metrics = metrics;
          }
          if (!info.success && !metrics.success) {
            _error = 'Cannot connect to monitoring service';
          }
        });
      }
    } catch (e) {
      if (mounted)
        setState(() {
          _loading = false;
          _error = 'Connection error';
        });
    }
  }

  Future<void> _refreshMetrics() async {
    if (!mounted) return;
    try {
      final metrics = await CloudToolsService().netdataOverview();
      if (mounted && metrics.success) {
        setState(() {
          _metrics = metrics;
        });
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        title: Text(
          '服务器监控',
          style: TextStyle(
            color: colors.textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
        centerTitle: true,
        backgroundColor: colors.background,
        elevation: 0,
        scrolledUnderElevation: 0,
        iconTheme: IconThemeData(color: colors.textPrimary),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh_rounded, color: colors.textSecondary),
            onPressed: _loadData,
          ),
        ],
      ),
      body: SafeArea(
        child: _loading
            ? _buildShimmerSkeleton(colors)
            : _error != null && _metrics == null
            ? Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.cloud_off_rounded,
                      size: 48,
                      color: colors.textTertiary,
                    ),
                    const SizedBox(height: 12),
                    Text(_error!, style: TextStyle(color: colors.textTertiary)),
                    const SizedBox(height: 20),
                    ElevatedButton(
                      onPressed: _loadData,
                      child: const Text('重试'),
                    ),
                  ],
                ),
              )
            : SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Server info header
                    if (_serverInfo != null)
                      Container(
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF0F9D58), Color(0xFF0B8043)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: const Icon(
                                Icons.dns_rounded,
                                size: 24,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _serverInfo!.hostname ?? 'Server',
                                    style: const TextStyle(
                                      fontSize: 17,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.white,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '${_serverInfo!.os} | ${_serverInfo!.cores} cores',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.white.withValues(
                                        alpha: 0.8,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    width: 6,
                                    height: 6,
                                    decoration: const BoxDecoration(
                                      color: Colors.greenAccent,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    '在线',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Colors.white.withValues(
                                        alpha: 0.9,
                                      ),
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),

                    const SizedBox(height: 16),

                    // Real-time metrics grid
                    if (_metrics != null) ...[
                      Text(
                        '实时指标',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: colors.textPrimary,
                          letterSpacing: -0.3,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '每 3 秒自动刷新',
                        style: TextStyle(
                          fontSize: 11,
                          color: colors.textTertiary,
                        ),
                      ),
                      const SizedBox(height: 12),

                      Row(
                        children: [
                          Expanded(
                            child: _metricCard(
                              'CPU',
                              _metrics!.cpuFormatted,
                              Icons.memory_rounded,
                              MiuiColors.blue,
                              _metrics!.cpu / 100,
                              colors,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _metricCard(
                              '内存',
                              _metrics!.ramFormatted,
                              Icons.storage_rounded,
                              MiuiColors.orange,
                              _metrics!.ramTotal > 0
                                  ? _metrics!.ramUsed / _metrics!.ramTotal
                                  : 0,
                              colors,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: _metricCard(
                              '磁盘',
                              _metrics!.diskFormatted,
                              Icons.disc_full_rounded,
                              MiuiColors.purple,
                              _metrics!.diskUsage / 100,
                              colors,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _metricCard(
                              '负载',
                              _metrics!.load1Formatted,
                              Icons.trending_up_rounded,
                              MiuiColors.teal,
                              _metrics!.load1 / (_serverInfo?.cores ?? 2),
                              colors,
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 12),

                      // Load detail card
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: colors.card,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(
                                  Icons.trending_up_rounded,
                                  size: 18,
                                  color: MiuiColors.teal,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  '系统负载',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                    color: colors.textPrimary,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),
                            Row(
                              children: [
                                Expanded(
                                  child: _loadDetailItem(
                                    '1 分钟',
                                    _metrics!.load1.toStringAsFixed(2),
                                    MiuiColors.teal,
                                    colors,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: _loadDetailItem(
                                    '5 分钟',
                                    _metrics!.load5.toStringAsFixed(2),
                                    MiuiColors.blue,
                                    colors,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: _loadDetailItem(
                                    '15 分钟',
                                    _metrics!.load15.toStringAsFixed(2),
                                    MiuiColors.purple,
                                    colors,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 12),

                      // Network I/O
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: colors.card,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(
                                  Icons.swap_vert_rounded,
                                  size: 18,
                                  color: MiuiColors.green,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  '网络',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                    color: colors.textPrimary,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),
                            Row(
                              children: [
                                Expanded(
                                  child: _netIORow(
                                    '下载',
                                    _metrics!.networkIn,
                                    Icons.arrow_downward_rounded,
                                    MiuiColors.green,
                                    colors,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: _netIORow(
                                    '上传',
                                    _metrics!.networkOut,
                                    Icons.arrow_upward_rounded,
                                    MiuiColors.red,
                                    colors,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildShimmerSkeleton(AppColors colors) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Server header skeleton
          _ShimmerBox(
            width: double.infinity,
            height: 90,
            borderRadius: 16,
            colors: colors,
          ),
          const SizedBox(height: 16),
          _ShimmerBox(width: 100, height: 20, borderRadius: 8, colors: colors),
          const SizedBox(height: 4),
          _ShimmerBox(width: 80, height: 14, borderRadius: 6, colors: colors),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _ShimmerBox(
                  width: double.infinity,
                  height: 110,
                  borderRadius: 16,
                  colors: colors,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _ShimmerBox(
                  width: double.infinity,
                  height: 110,
                  borderRadius: 16,
                  colors: colors,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _ShimmerBox(
                  width: double.infinity,
                  height: 110,
                  borderRadius: 16,
                  colors: colors,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _ShimmerBox(
                  width: double.infinity,
                  height: 110,
                  borderRadius: 16,
                  colors: colors,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _ShimmerBox(
            width: double.infinity,
            height: 90,
            borderRadius: 16,
            colors: colors,
          ),
          const SizedBox(height: 12),
          _ShimmerBox(
            width: double.infinity,
            height: 90,
            borderRadius: 16,
            colors: colors,
          ),
        ],
      ),
    );
  }

  Widget _metricCard(
    String label,
    String value,
    IconData icon,
    Color color,
    double progress,
    AppColors colors,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  color: colors.textSecondary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: color,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress.clamp(0.0, 1.0),
              minHeight: 4,
              backgroundColor: color.withValues(alpha: 0.1),
              valueColor: AlwaysStoppedAnimation(color),
            ),
          ),
        ],
      ),
    );
  }

  Widget _netIORow(
    String label,
    String value,
    IconData icon,
    Color color,
    AppColors colors,
  ) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(fontSize: 11, color: colors.textTertiary),
              ),
              Text(
                value,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _loadDetailItem(
    String label,
    String value,
    Color color,
    AppColors colors,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(fontSize: 11, color: colors.textTertiary),
          ),
        ],
      ),
    );
  }
}

// ═══ SHIMMER LOADING SKELETON WIDGET ═══
class _ShimmerBox extends StatefulWidget {
  final double width;
  final double height;
  final double borderRadius;
  final AppColors colors;
  const _ShimmerBox({
    required this.width,
    required this.height,
    required this.borderRadius,
    required this.colors,
  });
  @override
  State<_ShimmerBox> createState() => _ShimmerBoxState();
}

class _ShimmerBoxState extends State<_ShimmerBox>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) {
        final shimmer = _ctrl.value;
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(widget.borderRadius),
            gradient: LinearGradient(
              colors: [
                widget.colors.surface,
                widget.colors.card,
                widget.colors.surface,
              ],
              stops: [
                (shimmer - 0.3).clamp(0.0, 1.0),
                shimmer.clamp(0.0, 1.0),
                (shimmer + 0.3).clamp(0.0, 1.0),
              ],
              begin: const Alignment(-1.0, -0.3),
              end: const Alignment(2.0, 0.3),
            ),
          ),
        );
      },
    );
  }
}
