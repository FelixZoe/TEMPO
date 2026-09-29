import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../providers/app_provider.dart';
import '../theme/miui_theme.dart';
import '../services/api_service.dart';
import '../services/update_checker.dart';
import '../services/auth_service.dart';
import '../services/cloud_sync_service.dart';
import '../services/weather_service.dart';
import '../services/deepseek_service.dart';

import 'auth_page.dart';
import 'files_page.dart';
import 'cloud_config_pages.dart';
import '../widgets/swipe_back_route.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});
  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool _checkingUpdate = false;
  bool _serverOnline = false;

  @override
  void initState() {
    super.initState();
    _checkServer();
  }

  Future<void> _checkServer() async {
    final ok = await ApiService().checkHealth();
    if (mounted)
      setState(() {
        _serverOnline = ok;
      });
  }

  Future<void> _manualCheckUpdate(AppColors colors) async {
    setState(() {
      _checkingUpdate = true;
    });
    final info = await ApiService().checkForUpdate();
    if (mounted) {
      setState(() {
        _checkingUpdate = false;
      });
      if (info != null && info.hasUpdate) {
        _showUpdateDialog(info, colors);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('已是最新版本'),
            backgroundColor: MiuiColors.green,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            margin: const EdgeInsets.all(16),
          ),
        );
      }
    }
  }

  void _showUpdateDialog(VersionInfo info, AppColors colors) {
    showDialog(
      context: context,
      barrierDismissible: !info.forceUpdate,
      builder: (ctx) => _UpdateSettingsDialog(info: info, colors: colors),
    );
  }

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
              // ─── Header ───
              SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                    Breathing.pagePaddingH,
                    32,
                    Breathing.pagePaddingH,
                    28,
                  ),
                  child: Text(
                    '设置',
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

              // ─── Personal workspace identity ───
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
                      padding: const EdgeInsets.all(22),
                      child: Row(
                        children: [
                          Container(
                            width: 54,
                            height: 54,
                            decoration: BoxDecoration(
                              color: colors.textPrimary,
                              borderRadius: BorderRadius.circular(18),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              'T',
                              style: TextStyle(
                                fontSize: 25,
                                fontWeight: FontWeight.w700,
                                color: colors.background,
                              ),
                            ),
                          ),
                          const SizedBox(width: 18),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'TEMPO',
                                  style: TextStyle(
                                    fontSize: 19,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 0.2,
                                    color: colors.textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 5),
                                Text(
                                  '个人工作台 · 本地优先 · 无需账号',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: colors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                  ),
                ),
              ),

              // ═══ 外观 (NO 备选图标 — REMOVED) ═══
              _sectionLabel('外观', colors),
              _buildGroup(context, colors, provider, [
                _SettingRow(
                  icon: Icons.palette_outlined,
                  title: '主题',
                  subtitle: _themeDescription(provider.themeMode),
                  colors: colors,
                  trailing: _DropdownChip(
                    value: provider.themeMode,
                    colors: colors,
                    onTap: () => _showPicker(
                      context,
                      colors,
                      '主题',
                      ['跟随系统', '浅色模式', '深色模式'],
                      provider.themeMode,
                      (v) {
                        provider.setThemeMode(v);
                        // Update system UI overlay for new theme
                        final isDark =
                            v == '深色模式' ||
                            (v == '跟随系统' &&
                                MediaQuery.of(context).platformBrightness ==
                                    Brightness.dark);
                        SystemChrome.setSystemUIOverlayStyle(
                          SystemUiOverlayStyle(
                            statusBarIconBrightness: isDark
                                ? Brightness.light
                                : Brightness.dark,
                            statusBarColor: Colors.transparent,
                          ),
                        );
                        _showSnack(context, colors, '主题已切换为「$v」');
                      },
                    ),
                  ),
                ),
                _SettingRow(
                  icon: Icons.swipe_rounded,
                  title: '侧滑跟手返回',
                  subtitle: provider.predictiveBack
                      ? '实时跟手 · 可中断取消 · 预览上一页'
                      : '使用 Material Zoom 页面过渡动画',
                  colors: colors,
                  trailing: _buildSwitch(provider.predictiveBack, colors, (v) {
                    provider.setPredictiveBack(v);
                    _showSnack(
                      context,
                      colors,
                      v ? '已启用侧滑跟手返回，从边缘滑动体验丝滑动画' : '已切换为 Material 过渡动画',
                    );
                  }),
                ),
                _SettingRow(
                  icon: Icons.blur_on_rounded,
                  title: '模糊效果',
                  subtitle: provider.blurEffect
                      ? '底栏和弹出层使用高斯模糊'
                      : '使用纯色背景，降低 GPU 占用',
                  colors: colors,
                  trailing: _buildSwitch(provider.blurEffect, colors, (v) {
                    provider.setBlurEffect(v);
                    _showSnack(
                      context,
                      colors,
                      v ? '模糊已开启 (BackdropFilter σ=30)' : '模糊已关闭，使用纯色背景',
                    );
                  }),
                ),
                _SettingRow(
                  icon: Icons.panorama_horizontal_select_rounded,
                  title: '悬浮底栏',
                  subtitle: provider.floatingBar
                      ? '底栏悬浮于内容之上，圆角胶囊形态'
                      : '底栏吸附于屏幕底部',
                  colors: colors,
                  trailing: _buildSwitch(provider.floatingBar, colors, (v) {
                    provider.setFloatingBar(v);
                    _showSnack(
                      context,
                      colors,
                      v
                          ? '悬浮底栏已开启，圆角 ${provider.bottomBarRadius.toInt()}px'
                          : '底栏已吸附到底部',
                    );
                  }),
                ),
                _SettingRow(
                  icon: Icons.auto_awesome_rounded,
                  title: '液态玻璃',
                  subtitle: provider.liquidGlass
                      ? '卡片使用毛玻璃半透明效果'
                      : '卡片使用纯色不透明背景',
                  colors: colors,
                  trailing: _buildSwitch(provider.liquidGlass, colors, (v) {
                    provider.setLiquidGlass(v);
                    _showSnack(
                      context,
                      colors,
                      v ? '液态玻璃已开启 (BackdropFilter σ=24)' : '已切换为纯色卡片',
                    );
                  }),
                ),
              ]),

              // ═══ 通知 ═══
              _sectionLabel('通知', colors),
              _buildGroup(context, colors, provider, [
                _SettingRow(
                  icon: Icons.notifications_none_rounded,
                  title: '推送通知',
                  subtitle: '接收任务提醒和日程通知',
                  colors: colors,
                  trailing: _buildSwitch(provider.notifyEnabled, colors, (v) {
                    provider.setNotifyEnabled(v);
                    _showSnack(context, colors, v ? '通知已开启' : '通知已关闭');
                  }),
                ),
                _SettingRow(
                  icon: Icons.volume_up_outlined,
                  title: '提示音',
                  subtitle: '完成任务时播放提示音效',
                  colors: colors,
                  trailing: _buildSwitch(provider.soundEnabled, colors, (v) {
                    provider.setSoundEnabled(v);
                    if (v) HapticFeedback.lightImpact();
                    _showSnack(context, colors, v ? '提示音已开启' : '提示音已关闭');
                  }),
                ),
                _SettingRow(
                  icon: Icons.vibration_rounded,
                  title: '振动反馈',
                  subtitle: '操作时提供触觉反馈',
                  colors: colors,
                  trailing: _buildSwitch(provider.vibrateEnabled, colors, (v) {
                    provider.setVibrateEnabled(v);
                    if (v) HapticFeedback.mediumImpact();
                    _showSnack(context, colors, v ? '振动反馈已开启' : '振动反馈已关闭');
                  }),
                ),
              ]),

              // ═══ 番茄钟 ═══
              _sectionLabel('番茄钟', colors),
              _buildGroup(context, colors, provider, [
                _SettingRow(
                  icon: Icons.timer_outlined,
                  title: '专注时长',
                  subtitle: '每个番茄的专注时间',
                  colors: colors,
                  trailing: _DropdownChip(
                    value: '${provider.pomoDuration} 分钟',
                    colors: colors,
                    onTap: () => _showPicker(
                      context,
                      colors,
                      '专注时长',
                      ['15 分钟', '20 分钟', '25 分钟', '30 分钟', '45 分钟', '60 分钟'],
                      '${provider.pomoDuration} 分钟',
                      (v) {
                        provider.setPomoDuration(
                          int.parse(v.replaceAll(' 分钟', '')),
                        );
                        _showSnack(context, colors, '专注时长已设为 $v');
                      },
                    ),
                  ),
                ),
                _SettingRow(
                  icon: Icons.coffee_outlined,
                  title: '休息时长',
                  subtitle: '番茄间的短休息时间',
                  colors: colors,
                  trailing: _DropdownChip(
                    value: '${provider.breakDuration} 分钟',
                    colors: colors,
                    onTap: () => _showPicker(
                      context,
                      colors,
                      '休息时长',
                      ['3 分钟', '5 分钟', '10 分钟', '15 分钟'],
                      '${provider.breakDuration} 分钟',
                      (v) {
                        provider.setBreakDuration(
                          int.parse(v.replaceAll(' 分钟', '')),
                        );
                        _showSnack(context, colors, '休息时长已设为 $v');
                      },
                    ),
                  ),
                ),
                _SettingRow(
                  icon: Icons.repeat_rounded,
                  title: '长休息间隔',
                  subtitle: '触发长休息的番茄数',
                  colors: colors,
                  trailing: _DropdownChip(
                    value: '${provider.longBreakInterval} 个',
                    colors: colors,
                    onTap: () => _showPicker(
                      context,
                      colors,
                      '长休息间隔',
                      ['2 个', '3 个', '4 个', '5 个', '6 个'],
                      '${provider.longBreakInterval} 个',
                      (v) {
                        provider.setLongBreakInterval(
                          int.parse(v.replaceAll(' 个', '')),
                        );
                        _showSnack(context, colors, '长休息间隔已设为 $v');
                      },
                    ),
                  ),
                ),
              ]),

              // ═══ 云同步 ═══
              _sectionLabel('云同步', colors),
              _buildGroup(context, colors, provider, [
                _SettingRow(
                  icon: Icons.cloud_sync_outlined,
                  title: '自动同步',
                  subtitle: '数据变更自动上传，登录后自动恢复',
                  colors: colors,
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: AuthService().isLoggedIn
                              ? MiuiColors.green
                              : colors.textTertiary,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        AuthService().isLoggedIn ? '已启用' : '未登录',
                        style: TextStyle(
                          fontSize: 12,
                          color: AuthService().isLoggedIn
                              ? MiuiColors.green
                              : colors.textTertiary,
                        ),
                      ),
                    ],
                  ),
                ),
                if (CloudSyncService().lastSyncTime != null)
                  _SettingRow(
                    icon: Icons.access_time_rounded,
                    title: '上次同步',
                    subtitle: CloudSyncService().lastSyncTime ?? '',
                    colors: colors,
                    trailing: const SizedBox.shrink(),
                  ),
                _SettingRow(
                  icon: Icons.sync_rounded,
                  title: '立即同步',
                  subtitle: '手动触发一次完整同步',
                  colors: colors,
                  trailing: Icon(
                    Icons.chevron_right_rounded,
                    size: 20,
                    color: colors.textTertiary,
                  ),
                  onTap: () => _manualSync(context, provider, colors),
                ),
              ]),

              // ═══ 数据 ═══
              _sectionLabel('数据', colors),
              _buildGroup(context, colors, provider, [
                _SettingRow(
                  icon: Icons.download_outlined,
                  title: '导出数据',
                  subtitle: '将数据导出为文件',
                  colors: colors,
                  trailing: provider.isExporting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Icon(
                          Icons.chevron_right_rounded,
                          size: 20,
                          color: colors.textTertiary,
                        ),
                  onTap: () => _exportData(context, provider, colors),
                ),
                _SettingRow(
                  icon: Icons.delete_outline_rounded,
                  title: '清除缓存',
                  subtitle: '释放存储空间',
                  colors: colors,
                  trailing: provider.isClearingCache
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(
                          provider.cacheSize > 0.01
                              ? '${provider.cacheSize.toStringAsFixed(1)} MB'
                              : '已清理',
                          style: TextStyle(
                            fontSize: 13,
                            color: provider.cacheSize > 0.01
                                ? colors.textTertiary
                                : MiuiColors.green,
                          ),
                        ),
                  onTap: provider.isClearingCache
                      ? null
                      : () => _clearCache(context, provider, colors),
                ),
              ]),

              // ═══ 统计 ═══
              _sectionLabel('使用统计', colors),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    Breathing.pagePaddingH,
                    0,
                    Breathing.pagePaddingH,
                    24,
                  ),
                  child: GlassCard(
                    enabled: provider.liquidGlass,
                    borderRadius: provider.cardRadius,
                    padding: const EdgeInsets.all(22),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            _StatMini(
                              label: '完成任务',
                              value:
                                  '${provider.events.where((e) => e.isCompleted).length}',
                              color: MiuiColors.blue,
                              colors: colors,
                            ),
                            _StatMini(
                              label: '番茄钟',
                              value: '${provider.pomodoroCount}',
                              color: MiuiColors.orange,
                              colors: colors,
                            ),
                            _StatMini(
                              label: '完成率',
                              value:
                                  '${(provider.completionRate * 100).toInt()}%',
                              color: MiuiColors.green,
                              colors: colors,
                            ),
                          ],
                        ),
                        const SizedBox(height: 18),
                        SizedBox(
                          height: 48,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: List.generate(7, (i) {
                              final v = provider.weeklyProductivity[i];
                              final isToday = i == DateTime.now().weekday - 1;
                              return Container(
                                width: 24,
                                height: v * 44 + 4,
                                decoration: BoxDecoration(
                                  color: isToday
                                      ? MiuiColors.blue
                                      : MiuiColors.blue.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                              );
                            }),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: ['一', '二', '三', '四', '五', '六', '日']
                              .asMap()
                              .entries
                              .map(
                                (e) => SizedBox(
                                  width: 24,
                                  child: Text(
                                    e.value,
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: e.key == DateTime.now().weekday - 1
                                          ? MiuiColors.blue
                                          : colors.textTertiary,
                                    ),
                                  ),
                                ),
                              )
                              .toList(),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // ═══ 服务器 ═══
              _sectionLabel('服务器', colors),
              _buildGroup(context, colors, provider, [
                _SettingRow(
                  icon: Icons.dns_outlined,
                  title: '远程服务器',
                  subtitle: _serverOnline
                      ? '已连接 · ${ServerConfig.baseUrl}'
                      : '未连接',
                  colors: colors,
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: _serverOnline
                              ? MiuiColors.green
                              : MiuiColors.red,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _serverOnline ? '在线' : '离线',
                        style: TextStyle(
                          fontSize: 13,
                          color: _serverOnline
                              ? MiuiColors.green
                              : MiuiColors.red,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  onTap: _checkServer,
                ),
                _SettingRow(
                  icon: Icons.system_update_outlined,
                  title: '检查更新',
                  subtitle:
                      '当前版本 v${ServerConfig.appVersion} (Build ${ServerConfig.appBuild})',
                  colors: colors,
                  trailing: _checkingUpdate
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Icon(
                          Icons.chevron_right_rounded,
                          size: 20,
                          color: colors.textTertiary,
                        ),
                  onTap: _checkingUpdate
                      ? null
                      : () => _manualCheckUpdate(colors),
                ),
              ]),

              // ═══ API 服务 ═══
              _sectionLabel('API \u670d\u52a1', colors),
              _buildGroup(context, colors, provider, [
                _SettingRow(
                  icon: Icons.cloud_outlined,
                  title: '\u548c\u98ce\u5929\u6c14',
                  subtitle: WeatherService().hasApiKey
                      ? '\u5df2\u914d\u7f6e (${WeatherService().cityName})'
                      : '\u672a\u914d\u7f6e API Key',
                  colors: colors,
                  trailing: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: WeatherService().hasApiKey
                          ? MiuiColors.green.withValues(alpha: 0.1)
                          : MiuiColors.orange.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      WeatherService().hasApiKey
                          ? '\u5df2\u8fde\u63a5'
                          : '\u8bbe\u7f6e',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: WeatherService().hasApiKey
                            ? MiuiColors.green
                            : MiuiColors.orange,
                      ),
                    ),
                  ),
                  onTap: () => _showWeatherApiDialog(context, colors),
                ),
                _SettingRow(
                  icon: Icons.auto_awesome_rounded,
                  title: 'DeepSeek AI',
                  subtitle: DeepSeekService().hasApiKey
                      ? '\u5df2\u914d\u7f6e'
                      : '\u672a\u914d\u7f6e API Key',
                  colors: colors,
                  trailing: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: DeepSeekService().hasApiKey
                          ? MiuiColors.green.withValues(alpha: 0.1)
                          : MiuiColors.orange.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      DeepSeekService().hasApiKey
                          ? '\u5df2\u8fde\u63a5'
                          : '\u8bbe\u7f6e',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: DeepSeekService().hasApiKey
                            ? MiuiColors.green
                            : MiuiColors.orange,
                      ),
                    ),
                  ),
                  onTap: () => _showDeepSeekApiDialog(context, colors),
                ),
              ]),

              // ═══ 云端工具配置 ═══
              _sectionLabel('云端工具', colors),
              _buildGroup(context, colors, provider, [
                _SettingRow(
                  icon: Icons.link_rounded,
                  title: 'LinkSwift 直链',
                  subtitle: '配置网盘账号以支持更多平台直链下载',
                  colors: colors,
                  trailing: Icon(
                    Icons.chevron_right_rounded,
                    size: 20,
                    color: colors.textTertiary,
                  ),
                  onTap: () => _showLinkSwiftConfigDialog(context, colors),
                ),
                _SettingRow(
                  icon: Icons.auto_fix_high_rounded,
                  title: '去水印 Cookie',
                  subtitle: '配置抖音 Cookie 以解锁去水印功能',
                  colors: colors,
                  trailing: Icon(
                    Icons.chevron_right_rounded,
                    size: 20,
                    color: colors.textTertiary,
                  ),
                  onTap: () => _showWatermarkCookieDialog(context, colors),
                ),
                _SettingRow(
                  icon: Icons.network_check_rounded,
                  title: '测试通路',
                  subtitle: '检测云端工具是否可用、延迟如何',
                  colors: colors,
                  trailing: Icon(
                    Icons.chevron_right_rounded,
                    size: 20,
                    color: colors.textTertiary,
                  ),
                  onTap: () => _showCloudReachabilityPage(context, colors),
                ),
              ]),

              // ═══ 关于 ═══
              _sectionLabel('关于', colors),
              _buildGroup(context, colors, provider, [
                _SettingRow(
                  icon: Icons.info_outline_rounded,
                  title: '版本',
                  subtitle: 'TEMPO',
                  colors: colors,
                  trailing: Text(
                    'v${ServerConfig.appVersion}',
                    style: TextStyle(fontSize: 13, color: colors.textTertiary),
                  ),
                ),
                _SettingRow(
                  icon: Icons.star_outline_rounded,
                  title: '给应用评分',
                  subtitle: '在应用商店为我们打分',
                  colors: colors,
                  trailing: Icon(
                    Icons.chevron_right_rounded,
                    size: 20,
                    color: colors.textTertiary,
                  ),
                  onTap: () => _showRatingDialog(context, colors),
                ),
                _SettingRow(
                  icon: Icons.description_outlined,
                  title: '隐私政策',
                  subtitle: '查看我们的隐私条款',
                  colors: colors,
                  trailing: Icon(
                    Icons.chevron_right_rounded,
                    size: 20,
                    color: colors.textTertiary,
                  ),
                  onTap: () => _showPrivacyPolicy(context, colors),
                ),
                _SettingRow(
                  icon: Icons.help_outline_rounded,
                  title: '帮助与反馈',
                  subtitle: '获取帮助或提交反馈',
                  colors: colors,
                  trailing: Icon(
                    Icons.chevron_right_rounded,
                    size: 20,
                    color: colors.textTertiary,
                  ),
                  onTap: () => _showHelpSheet(context, colors),
                ),
              ]),

              const SliverToBoxAdapter(child: SizedBox(height: 120)),
            ],
          ),
        );
      },
    );
  }

  // ═══ Description helpers ═══
  String _themeDescription(String mode) {
    switch (mode) {
      case '浅色模式':
        return '始终使用浅色主题';
      case '深色模式':
        return '始终使用深色主题，OLED 纯黑';
      default:
        return '自动跟随系统暗色模式设置';
    }
  }

  // ═══ Cloud Sync ═══

  Future<void> _manualSync(
    BuildContext context,
    AppProvider provider,
    AppColors colors,
  ) async {
    final auth = AuthService();
    if (!auth.isLoggedIn) {
      _showSnack(context, colors, '请先登录账号');
      return;
    }
    _showSnack(context, colors, '正在同步...');
    // Push local → cloud, then pull cloud → local
    final pushResult = await CloudSyncService().pushToCloud();
    if (!context.mounted) return;
    if (pushResult.success) {
      final ok = await provider.pullAndReload();
      if (!context.mounted) return;
      _showSnack(context, colors, ok ? '同步完成' : '上传成功，拉取失败');
    } else {
      _showSnack(context, colors, pushResult.error ?? '同步失败');
    }
  }

  // ═══ Real Functions ═══

  Future<void> _exportData(
    BuildContext context,
    AppProvider provider,
    AppColors colors,
  ) async {
    final success = await provider.exportData();
    if (!context.mounted) return;
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        backgroundColor: colors.card,
        title: Row(
          children: [
            Icon(
              success ? Icons.check_circle_rounded : Icons.error_rounded,
              color: success ? MiuiColors.green : MiuiColors.red,
              size: 24,
            ),
            const SizedBox(width: 10),
            Text(
              success ? '导出成功' : '导出失败',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: colors.textPrimary,
              ),
            ),
          ],
        ),
        content: Text(
          success
              ? '所有数据已导出为 tempo_data.json\n\n包含：\n· ${provider.events.length} 条日程\n· ${provider.habits.length} 个习惯\n· ${provider.goals.length} 个目标\n· ${provider.pomodoroCount} 个番茄钟记录'
              : '导出过程中遇到问题，请重试。',
          style: TextStyle(
            fontSize: 14,
            height: 1.6,
            color: colors.textSecondary,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              '确定',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _clearCache(
    BuildContext context,
    AppProvider provider,
    AppColors colors,
  ) async {
    final sizeText = provider.cacheSize > 0.01
        ? '确定要清除 ${provider.cacheSize.toStringAsFixed(1)} MB 的缓存数据？'
        : '确定要清除所有临时缓存数据？';
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        backgroundColor: colors.card,
        title: Text(
          '清除缓存',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: colors.textPrimary,
          ),
        ),
        content: Text(
          sizeText,
          style: TextStyle(
            fontSize: 14,
            height: 1.6,
            color: colors.textSecondary,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              '清除',
              style: TextStyle(
                color: MiuiColors.red,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await provider.clearCache();
      if (context.mounted) _showSnack(context, colors, '缓存已清除');
    }
  }

  void _showWeatherApiDialog(BuildContext context, AppColors colors) {
    final keyCtrl = TextEditingController();
    final hostCtrl = TextEditingController();
    final cityCtrl = TextEditingController();
    String? testResult;
    bool testing = false;

    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          backgroundColor: colors.card,
          title: Row(
            children: [
              Icon(Icons.cloud_rounded, size: 22, color: MiuiColors.blue),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '和风天气设置',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: colors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Step guide
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: MiuiColors.blue.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '配置步骤:',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: colors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '1. 注册 console.qweather.com',
                        style: TextStyle(
                          fontSize: 11,
                          color: colors.textSecondary,
                        ),
                      ),
                      Text(
                        '2. 创建凭据时选择 API KEY 方式',
                        style: TextStyle(
                          fontSize: 11,
                          color: colors.textSecondary,
                        ),
                      ),
                      Text(
                        '3. 复制 API Key 和 API Host',
                        style: TextStyle(
                          fontSize: 11,
                          color: colors.textSecondary,
                        ),
                      ),
                      Text(
                        '4. 填入下方后点"测试"验证',
                        style: TextStyle(
                          fontSize: 11,
                          color: colors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  'API Host',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: colors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '控制台 → 设置 中查看',
                  style: TextStyle(fontSize: 11, color: colors.textTertiary),
                ),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: colors.surface,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: TextField(
                    controller: hostCtrl,
                    style: TextStyle(fontSize: 13, color: colors.textPrimary),
                    decoration: InputDecoration(
                      hintText: 'xxx.re.qweatherapi.com',
                      hintStyle: TextStyle(
                        color: colors.textTertiary,
                        fontSize: 13,
                      ),
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  'API Key',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: colors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '项目 → 凭据 中生成',
                  style: TextStyle(fontSize: 11, color: colors.textTertiary),
                ),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: colors.surface,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: TextField(
                    controller: keyCtrl,
                    style: TextStyle(fontSize: 13, color: colors.textPrimary),
                    decoration: InputDecoration(
                      hintText: '输入 API Key...',
                      hintStyle: TextStyle(
                        color: colors.textTertiary,
                        fontSize: 13,
                      ),
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    obscureText: true,
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  '城市',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: colors.textPrimary,
                  ),
                ),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: colors.surface,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: TextField(
                    controller: cityCtrl,
                    style: TextStyle(fontSize: 13, color: colors.textPrimary),
                    decoration: InputDecoration(
                      hintText: '例如: 北京 / 上海 / 深圳',
                      hintStyle: TextStyle(
                        color: colors.textTertiary,
                        fontSize: 13,
                      ),
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                if (WeatherService().hasApiKey) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: MiuiColors.blue.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '已配置 (留空保留当前设置)',
                          style: TextStyle(
                            fontSize: 12,
                            color: MiuiColors.blue,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        Text(
                          'Host: ${WeatherService().maskedHost}',
                          style: TextStyle(
                            fontSize: 11,
                            color: MiuiColors.blue.withValues(alpha: 0.7),
                          ),
                        ),
                        if (WeatherService().cityName != '未设置')
                          Text(
                            '城市: ${WeatherService().cityName}',
                            style: TextStyle(
                              fontSize: 11,
                              color: MiuiColors.green,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
                if (testResult != null) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: testResult!.startsWith('OK')
                          ? MiuiColors.green.withValues(alpha: 0.1)
                          : MiuiColors.red.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      testResult!,
                      style: TextStyle(
                        fontSize: 12,
                        color: testResult!.startsWith('OK')
                            ? MiuiColors.green
                            : MiuiColors.red,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('取消', style: TextStyle(color: colors.textSecondary)),
            ),
            TextButton(
              onPressed: testing
                  ? null
                  : () async {
                      final key = keyCtrl.text.trim().isNotEmpty
                          ? keyCtrl.text.trim()
                          : (WeatherService().hasApiKey ? null : '');
                      final host = hostCtrl.text.trim().isNotEmpty
                          ? hostCtrl.text.trim()
                          : (WeatherService().hasApiKey ? null : '');
                      if ((key ?? '').isEmpty || (host ?? '').isEmpty) {
                        setS(() => testResult = '请填写 API Host 和 Key');
                        return;
                      }
                      setS(() {
                        testing = true;
                        testResult = '测试中...';
                      });
                      // Test with new or stored credentials
                      if (keyCtrl.text.trim().isNotEmpty &&
                          hostCtrl.text.trim().isNotEmpty) {
                        final result = await WeatherService.testConnection(
                          keyCtrl.text.trim(),
                          hostCtrl.text.trim(),
                        );
                        setS(() {
                          testing = false;
                          testResult = result;
                        });
                      } else {
                        // Test with currently saved credentials
                        final ok = await WeatherService().fetch(force: true);
                        setS(() {
                          testing = false;
                          testResult = ok
                              ? 'OK: ${WeatherService().text} ${WeatherService().temp}\u00B0C'
                              : (WeatherService().lastError ?? '未知错误');
                        });
                      }
                    },
              child: Text(
                testing ? '测试中...' : '测试',
                style: TextStyle(
                  color: MiuiColors.blue,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            ElevatedButton(
              onPressed: testing
                  ? null
                  : () async {
                      final key = keyCtrl.text.trim();
                      final host = hostCtrl.text.trim();
                      if (key.isNotEmpty && host.isNotEmpty) {
                        await WeatherService.setCredentials(key, host);
                      } else if (key.isNotEmpty || host.isNotEmpty) {
                        if (ctx.mounted) {
                          setS(() => testResult = '请同时填写 API Host 和 Key');
                        }
                        return;
                      }
                      // Search city
                      if (cityCtrl.text.trim().isNotEmpty) {
                        final results = await WeatherService().searchCity(
                          cityCtrl.text.trim(),
                        );
                        if (results.isNotEmpty) {
                          await WeatherService.setLocation(
                            results[0]['id']!,
                            '${results[0]['adm1']} ${results[0]['name']}',
                          );
                        } else if (ctx.mounted) {
                          setS(
                            () => testResult =
                                '未找到城市"${cityCtrl.text.trim()}"，请检查名称',
                          );
                          return;
                        }
                      }
                      // Fetch weather
                      final ok = await WeatherService().fetch(force: true);
                      if (ok) {
                        if (ctx.mounted) Navigator.pop(ctx);
                        if (context.mounted) {
                          setState(() {});
                          _showSnack(
                            context,
                            colors,
                            '天气配置成功: ${WeatherService().text} ${WeatherService().temp}\u00B0C',
                          );
                        }
                      } else if (ctx.mounted) {
                        setS(
                          () => testResult =
                              WeatherService().lastError ?? '获取天气失败，请检查配置',
                        );
                      }
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: MiuiColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
              ),
              child: const Text('保存'),
            ),
          ],
        ),
      ),
    );
  }

  void _showDeepSeekApiDialog(BuildContext context, AppColors colors) {
    final keyCtrl = TextEditingController();
    String? testResult;
    bool testing = false;
    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          backgroundColor: colors.card,
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF667EEA), Color(0xFF764BA2)],
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.auto_awesome_rounded,
                  size: 16,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'DeepSeek AI 设置',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: colors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '注册: platform.deepseek.com',
                  style: TextStyle(fontSize: 12, color: colors.textTertiary),
                ),
                Text(
                  '免费额度: 500万 tokens',
                  style: TextStyle(fontSize: 12, color: colors.textTertiary),
                ),
                const SizedBox(height: 14),
                Text(
                  'API Key',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: colors.textPrimary,
                  ),
                ),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: colors.surface,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: TextField(
                    controller: keyCtrl,
                    style: TextStyle(fontSize: 13, color: colors.textPrimary),
                    decoration: InputDecoration(
                      hintText: 'sk-...',
                      hintStyle: TextStyle(
                        color: colors.textTertiary,
                        fontSize: 13,
                      ),
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    obscureText: true,
                  ),
                ),
                if (DeepSeekService().hasApiKey) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: MiuiColors.blue.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '已配置 (留空保留当前Key)',
                      style: TextStyle(
                        fontSize: 12,
                        color: MiuiColors.blue,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
                if (testResult != null) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: testResult!.startsWith('OK')
                          ? MiuiColors.green.withValues(alpha: 0.1)
                          : MiuiColors.red.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      testResult!,
                      style: TextStyle(
                        fontSize: 12,
                        color: testResult!.startsWith('OK')
                            ? MiuiColors.green
                            : MiuiColors.red,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('取消', style: TextStyle(color: colors.textSecondary)),
            ),
            // Test button
            TextButton(
              onPressed: testing
                  ? null
                  : () async {
                      final key = keyCtrl.text.trim();
                      if (key.isEmpty && !DeepSeekService().hasApiKey) return;
                      setS(() {
                        testing = true;
                        testResult = '验证中...';
                      });
                      if (key.isNotEmpty) {
                        await DeepSeekService.setApiKey(key);
                        await DeepSeekService.reload();
                      }
                      final result = await DeepSeekService().chat('说"OK"两个字');
                      setS(() {
                        testing = false;
                        testResult = result.startsWith('[Error]')
                            ? result
                            : 'OK: 连接正常';
                      });
                    },
              child: Text(
                '测试',
                style: TextStyle(
                  color: const Color(0xFF667EEA),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () async {
                final key = keyCtrl.text.trim();
                if (key.isNotEmpty) {
                  await DeepSeekService.setApiKey(key);
                  await DeepSeekService.reload();
                }
                if (ctx.mounted) Navigator.pop(ctx);
                if (context.mounted) {
                  setState(() {});
                  _showSnack(context, colors, 'DeepSeek AI 已配置');
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF667EEA),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
              ),
              child: const Text('保存'),
            ),
          ],
        ),
      ),
    );
  }

  void _showRatingDialog(BuildContext context, AppColors colors) {
    int rating = 0;
    showDialog(
      context: context,
      useRootNavigator: true,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          backgroundColor: colors.card,
          title: Text(
            '给应用评分',
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
                '你的评分是我们改进的动力',
                style: TextStyle(fontSize: 14, color: colors.textSecondary),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  5,
                  (i) => GestureDetector(
                    onTap: () => setS(() => rating = i + 1),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      child: Icon(
                        i < rating
                            ? Icons.star_rounded
                            : Icons.star_outline_rounded,
                        size: 36,
                        color: i < rating
                            ? MiuiColors.yellow
                            : colors.textTertiary,
                      ),
                    ),
                  ),
                ),
              ),
              if (rating > 0) ...[
                const SizedBox(height: 16),
                Text(
                  rating >= 4
                      ? '太棒了！感谢你的支持'
                      : (rating >= 2 ? '感谢反馈，我们会继续改进' : '很抱歉体验不佳，请告诉我们如何改进'),
                  style: TextStyle(fontSize: 14, color: colors.textSecondary),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('取消'),
            ),
            TextButton(
              onPressed: rating > 0
                  ? () {
                      Navigator.pop(ctx);
                      _showSnack(context, colors, '感谢你的 $rating 星评分！');
                    }
                  : null,
              child: const Text(
                '提交',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showPrivacyPolicy(BuildContext context, AppColors colors) {
    Navigator.push(
      context,
      swipeBackRoute(
        context: context,
        builder: (_) => _PrivacyPolicyPage(colors: colors),
      ),
    );
  }

  void _showHelpSheet(BuildContext context, AppColors colors) {
    Navigator.push(
      context,
      swipeBackRoute(
        context: context,
        builder: (_) => _HelpFeedbackPage(
          colors: colors,
          onShowFeedback: (ctx, c, {type = '反馈'}) =>
              _showFeedbackDialog(ctx, c, type: type),
        ),
      ),
    );
  }

  void _showFeedbackDialog(
    BuildContext context,
    AppColors colors, {
    String type = '反馈',
  }) {
    final ctrl = TextEditingController();
    String selectedType = type;
    showDialog(
      context: context,
      useRootNavigator: true,
      barrierDismissible: true,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          backgroundColor: colors.card,
          title: Text(
            '提交$selectedType',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: colors.textPrimary,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Type selector
              Row(
                children: [
                  _feedbackChip(
                    '问题报告',
                    selectedType == '问题报告',
                    colors,
                    () => setS(() => selectedType = '问题报告'),
                  ),
                  const SizedBox(width: 8),
                  _feedbackChip(
                    '功能建议',
                    selectedType == '功能建议',
                    colors,
                    () => setS(() => selectedType = '功能建议'),
                  ),
                  const SizedBox(width: 8),
                  _feedbackChip(
                    '其他',
                    selectedType == '其他',
                    colors,
                    () => setS(() => selectedType = '其他'),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Container(
                height: 140,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: colors.surface,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: TextField(
                  controller: ctrl,
                  maxLines: null,
                  style: TextStyle(color: colors.textPrimary, fontSize: 14),
                  decoration: InputDecoration.collapsed(
                    hintText: selectedType == '问题报告'
                        ? '请描述你遇到的问题、复现步骤和设备信息...'
                        : selectedType == '功能建议'
                        ? '请描述你期望的功能和使用场景...'
                        : '请在此输入...',
                    hintStyle: TextStyle(color: colors.textTertiary),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(
                    Icons.info_outline_rounded,
                    size: 14,
                    color: colors.textTertiary,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      '反馈将通过邮件发送至开发者',
                      style: TextStyle(
                        fontSize: 11,
                        color: colors.textTertiary,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('取消', style: TextStyle(color: colors.textSecondary)),
            ),
            TextButton(
              onPressed: () async {
                final content = ctrl.text.trim();
                if (content.isEmpty) {
                  _showSnack(context, colors, '请输入反馈内容');
                  return;
                }
                Navigator.pop(ctx);
                // Compose feedback email
                final deviceInfo = Platform.isAndroid
                    ? 'Android'
                    : Platform.operatingSystem;
                final subject = Uri.encodeComponent(
                  '[TEMPO$selectedType] v${ServerConfig.appVersion}',
                );
                final body = Uri.encodeComponent(
                  '$content\n\n---\n设备: $deviceInfo\n版本: v${ServerConfig.appVersion} (Build ${ServerConfig.appBuild})\n类型: $selectedType',
                );
                final emailUri = Uri.parse(
                  'mailto:zhuj3188@gmail.com?subject=$subject&body=$body',
                );
                try {
                  if (await canLaunchUrl(emailUri)) {
                    await launchUrl(emailUri);
                  } else {
                    // Copy to clipboard as fallback
                    await Clipboard.setData(
                      ClipboardData(text: '反馈类型: $selectedType\n内容: $content'),
                    );
                    if (context.mounted)
                      _showSnack(
                        context,
                        colors,
                        '已复制反馈内容，请发送邮件至 zhuj3188@gmail.com',
                      );
                  }
                } catch (_) {
                  await Clipboard.setData(
                    ClipboardData(text: '反馈类型: $selectedType\n内容: $content'),
                  );
                  if (context.mounted)
                    _showSnack(
                      context,
                      colors,
                      '已复制反馈内容，请发送邮件至 zhuj3188@gmail.com',
                    );
                }
              },
              child: const Text(
                '发送',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _feedbackChip(
    String label,
    bool selected,
    AppColors colors,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected
              ? MiuiColors.blue.withValues(alpha: 0.1)
              : colors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected
                ? MiuiColors.blue.withValues(alpha: 0.4)
                : Colors.transparent,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
            color: selected ? MiuiColors.blue : colors.textSecondary,
          ),
        ),
      ),
    );
  }

  void _handleProfileTap(BuildContext context, AppColors colors) {
    if (AuthService().isLoggedIn) {
      _showLoggedInProfileSheet(context, colors);
    } else {
      _openAuthPage(context);
    }
  }

  Future<void> _openAuthPage(BuildContext context) async {
    final result = await Navigator.of(context).push<bool>(
      swipeBackRoute<bool>(
        context: context,
        builder: (_) => AuthPage(
          onLoginSuccess: () {
            if (mounted) setState(() {});
          },
        ),
      ),
    );
    if (result == true && mounted) setState(() {});
  }

  void _showLoggedInProfileSheet(BuildContext context, AppColors colors) {
    final user = AuthService().currentUser;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
        decoration: BoxDecoration(
          color: colors.card,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildSheetHandle(colors),
              const SizedBox(height: 24),
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      MiuiColors.green.withValues(alpha: 0.2),
                      MiuiColors.teal.withValues(alpha: 0.15),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.person_rounded,
                  size: 40,
                  color: MiuiColors.green,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                user?.nickname ?? '用户',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.3,
                  color: colors.textPrimary,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                user?.email ?? '',
                style: TextStyle(fontSize: 14, color: colors.textSecondary),
              ),
              const SizedBox(height: 6),
              Consumer<AppProvider>(
                builder: (_, p, __) => Text(
                  '已坚持使用 ${p.usageDays} 天',
                  style: TextStyle(fontSize: 13, color: colors.textTertiary),
                ),
              ),
              const SizedBox(height: 20),
              Consumer<AppProvider>(
                builder: (_, p, __) => Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Row(
                    children: [
                      _ProfileStat(
                        label: '完成任务',
                        value: '${p.events.where((e) => e.isCompleted).length}',
                        colors: colors,
                      ),
                      _ProfileStat(
                        label: '番茄钟',
                        value: '${p.pomodoroCount}',
                        colors: colors,
                      ),
                      _ProfileStat(
                        label: '习惯天数',
                        value:
                            '${p.habits.fold<int>(0, (sum, h) => sum + h.streak)}',
                        colors: colors,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              // Action buttons
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  children: [
                    _ProfileAction(
                      icon: Icons.edit_rounded,
                      label: '修改昵称',
                      colors: colors,
                      onTap: () {
                        Navigator.pop(context);
                        _showEditNickname(context, colors);
                      },
                    ),
                    _ProfileAction(
                      icon: Icons.lock_outline_rounded,
                      label: '修改密码',
                      colors: colors,
                      onTap: () {
                        Navigator.pop(context);
                        _showChangePassword(context, colors);
                      },
                    ),
                    _ProfileAction(
                      icon: Icons.logout_rounded,
                      label: '退出登录',
                      colors: colors,
                      isDestructive: true,
                      onTap: () async {
                        // Show confirmation dialog first
                        final confirm = await showDialog<bool>(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            backgroundColor: colors.card,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                            title: Text(
                              '确认退出',
                              style: TextStyle(
                                color: colors.textPrimary,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            content: Text(
                              '退出后本地数据保留，云端数据不会删除。',
                              style: TextStyle(color: colors.textSecondary),
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(ctx, false),
                                child: Text(
                                  '取消',
                                  style: TextStyle(color: colors.textSecondary),
                                ),
                              ),
                              ElevatedButton(
                                onPressed: () => Navigator.pop(ctx, true),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: MiuiColors.red,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  elevation: 0,
                                ),
                                child: const Text('退出登录'),
                              ),
                            ],
                          ),
                        );
                        if (confirm != true) return;
                        // Close the profile sheet
                        if (context.mounted) Navigator.pop(context);
                        // Perform logout
                        await AuthService().logout();
                        // Clear all in-memory caches to prevent cross-account data leaking
                        FilesPage.clearCache();
                        if (context.mounted) {
                          final provider = context.read<AppProvider>();
                          provider
                              .clearUserDataAndReload(); // Clear in-memory data
                          setState(() {});
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: const Text('已退出登录，数据已安全保存到云端'),
                              backgroundColor: MiuiColors.green,
                              behavior: SnackBarBehavior.floating,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                              margin: const EdgeInsets.all(16),
                            ),
                          );
                        }
                      },
                    ),
                  ],
                ),
              ),
              SizedBox(height: MediaQuery.of(context).padding.bottom + 32),
            ],
          ),
        ),
      ),
    );
  }

  void _showEditNickname(BuildContext context, AppColors colors) {
    final ctrl = TextEditingController(
      text: AuthService().currentUser?.nickname ?? '',
    );
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: colors.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('修改昵称', style: TextStyle(color: colors.textPrimary)),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          style: TextStyle(color: colors.textPrimary),
          decoration: InputDecoration(
            hintText: '输入新昵称',
            hintStyle: TextStyle(color: colors.textTertiary),
            filled: true,
            fillColor: colors.surface,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('取消', style: TextStyle(color: colors.textSecondary)),
          ),
          TextButton(
            onPressed: () async {
              final name = ctrl.text.trim();
              if (name.isEmpty) return;
              Navigator.pop(ctx);
              final ok = await AuthService().updateProfile(nickname: name);
              if (ctx.mounted) {
                setState(() {});
                ScaffoldMessenger.of(ctx).showSnackBar(
                  SnackBar(
                    content: Text(ok ? '昵称已更新' : '更新失败'),
                    backgroundColor: ok ? MiuiColors.green : MiuiColors.red,
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    margin: const EdgeInsets.all(16),
                  ),
                );
              }
            },
            child: const Text('确认', style: TextStyle(color: MiuiColors.blue)),
          ),
        ],
      ),
    );
  }

  void _showChangePassword(BuildContext context, AppColors colors) {
    final oldCtrl = TextEditingController();
    final newCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: colors.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('修改密码', style: TextStyle(color: colors.textPrimary)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: oldCtrl,
              obscureText: true,
              style: TextStyle(color: colors.textPrimary),
              decoration: InputDecoration(
                hintText: '当前密码',
                hintStyle: TextStyle(color: colors.textTertiary),
                filled: true,
                fillColor: colors.surface,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: newCtrl,
              obscureText: true,
              style: TextStyle(color: colors.textPrimary),
              decoration: InputDecoration(
                hintText: '新密码（至少6位）',
                hintStyle: TextStyle(color: colors.textTertiary),
                filled: true,
                fillColor: colors.surface,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('取消', style: TextStyle(color: colors.textSecondary)),
          ),
          TextButton(
            onPressed: () async {
              final old = oldCtrl.text;
              final nw = newCtrl.text;
              if (old.isEmpty || nw.isEmpty) return;
              Navigator.pop(ctx);
              final result = await AuthService().changePassword(
                oldPassword: old,
                newPassword: nw,
              );
              if (ctx.mounted) {
                ScaffoldMessenger.of(ctx).showSnackBar(
                  SnackBar(
                    content: Text(
                      result.success ? '密码已修改' : (result.error ?? '修改失败'),
                    ),
                    backgroundColor: result.success
                        ? MiuiColors.green
                        : MiuiColors.red,
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    margin: const EdgeInsets.all(16),
                  ),
                );
              }
            },
            child: const Text('确认', style: TextStyle(color: MiuiColors.blue)),
          ),
        ],
      ),
    );
  }

  // ═══ LinkSwift Config Dialog ═══
  void _showLinkSwiftConfigDialog(BuildContext context, AppColors colors) {
    Navigator.push(
      context,
      swipeBackRoute(
        context: context,
        builder: (_) => LinkSwiftConfigPage(colors: colors),
      ),
    );
  }

  // ═══ Watermark Cookie Dialog ═══
  void _showWatermarkCookieDialog(BuildContext context, AppColors colors) {
    Navigator.push(
      context,
      swipeBackRoute(
        context: context,
        builder: (_) => WatermarkCookieConfigPage(colors: colors),
      ),
    );
  }

  // ═══ Cloud Reachability Page ═══
  void _showCloudReachabilityPage(BuildContext context, AppColors colors) {
    Navigator.push(
      context,
      swipeBackRoute(
        context: context,
        builder: (_) => CloudReachabilityPage(colors: colors),
      ),
    );
  }

  // ═══ Builder Helpers ═══

  Widget _buildSwitch(
    bool value,
    AppColors colors,
    ValueChanged<bool> onChanged,
  ) {
    return SizedBox(
      width: 52,
      height: 30,
      child: FittedBox(
        child: Switch.adaptive(
          value: value,
          onChanged: onChanged,
          activeTrackColor: MiuiColors.blue,
          inactiveTrackColor: colors.isDark
              ? const Color(0xFF3A3A3C)
              : const Color(0xFFE0E0E0),
          thumbColor: WidgetStateProperty.all(Colors.white),
        ),
      ),
    );
  }

  SliverToBoxAdapter _sectionLabel(String title, AppColors colors) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          Breathing.pagePaddingH,
          8,
          Breathing.pagePaddingH,
          12,
        ),
        child: Text(
          title,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: colors.textTertiary,
          ),
        ),
      ),
    );
  }

  SliverToBoxAdapter _buildGroup(
    BuildContext context,
    AppColors colors,
    AppProvider provider,
    List<_SettingRow> rows,
  ) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          Breathing.pagePaddingH,
          0,
          Breathing.pagePaddingH,
          24,
        ),
        child: GlassCard(
          enabled: provider.liquidGlass,
          borderRadius: provider.cardRadius,
          padding: EdgeInsets.zero,
          child: Column(
            children: List.generate(rows.length * 2 - 1, (i) {
              if (i.isOdd)
                return Padding(
                  padding: const EdgeInsets.only(left: 68),
                  child: Divider(
                    height: 0.5,
                    thickness: 0.5,
                    color: colors.divider.withValues(alpha: 0.5),
                  ),
                );
              return rows[i ~/ 2];
            }),
          ),
        ),
      ),
    );
  }

  void _showPicker(
    BuildContext context,
    AppColors colors,
    String title,
    List<String> options,
    String selected,
    ValueChanged<String> onSelected,
  ) {
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
            _buildSheetHandle(colors),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
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
            ...options.map(
              (opt) => ListTile(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 28,
                  vertical: 4,
                ),
                title: Text(
                  opt,
                  style: TextStyle(fontSize: 16, color: colors.textPrimary),
                ),
                trailing: opt == selected
                    ? const Icon(
                        Icons.check_rounded,
                        color: MiuiColors.blue,
                        size: 22,
                      )
                    : null,
                onTap: () {
                  onSelected(opt);
                  Navigator.pop(context);
                },
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildSheetHandle(AppColors colors) => Container(
    width: 36,
    height: 5,
    margin: const EdgeInsets.only(top: 12, bottom: 4),
    decoration: BoxDecoration(
      color: colors.textTertiary.withValues(alpha: 0.4),
      borderRadius: BorderRadius.circular(3),
    ),
  );

  void _showSnack(BuildContext context, AppColors colors, String msg) {
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: const TextStyle(fontWeight: FontWeight.w500)),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 2),
      ),
    );
  }
}

// ═══ Setting Row ═══
class _SettingRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Widget trailing;
  final VoidCallback? onTap;
  final AppColors colors;
  const _SettingRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.trailing,
    this.onTap,
    required this.colors,
  });
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 24,
              color: colors.textPrimary.withValues(alpha: 0.6),
            ),
            const SizedBox(width: 18),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: colors.textPrimary,
                      height: 1.2,
                      letterSpacing: -0.1,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: colors.textTertiary,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 14),
            trailing,
          ],
        ),
      ),
    );
  }
}

// ═══ Dropdown Chip ═══
class _DropdownChip extends StatelessWidget {
  final String value;
  final VoidCallback onTap;
  final AppColors colors;
  const _DropdownChip({
    required this.value,
    required this.onTap,
    required this.colors,
  });
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              color: colors.textSecondary,
              fontWeight: FontWeight.w400,
            ),
          ),
          const SizedBox(width: 3),
          Icon(Icons.unfold_more_rounded, size: 18, color: colors.textTertiary),
        ],
      ),
    );
  }
}

// ═══ Stat Mini ═══
class _StatMini extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final AppColors colors;
  const _StatMini({
    required this.label,
    required this.value,
    required this.color,
    required this.colors,
  });
  @override
  Widget build(BuildContext context) => Expanded(
    child: Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: color,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 4),
        Text(label, style: TextStyle(fontSize: 12, color: colors.textTertiary)),
      ],
    ),
  );
}

// ═══ Profile Stat ═══
class _ProfileStat extends StatelessWidget {
  final String label;
  final String value;
  final AppColors colors;
  const _ProfileStat({
    required this.label,
    required this.value,
    required this.colors,
  });
  @override
  Widget build(BuildContext context) => Expanded(
    child: Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w800,
            color: MiuiColors.blue,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 4),
        Text(label, style: TextStyle(fontSize: 12, color: colors.textTertiary)),
      ],
    ),
  );
}

// ═══ Profile Action ═══
class _ProfileAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final AppColors colors;
  final VoidCallback onTap;
  final bool isDestructive;

  const _ProfileAction({
    required this.icon,
    required this.label,
    required this.colors,
    required this.onTap,
    this.isDestructive = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = isDestructive ? MiuiColors.red : colors.textPrimary;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
        child: Row(
          children: [
            Icon(icon, size: 22, color: color),
            const SizedBox(width: 14),
            Text(
              label,
              style: TextStyle(
                fontSize: 16,
                color: color,
                fontWeight: FontWeight.w500,
              ),
            ),
            const Spacer(),
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
}

// ═══ Privacy Policy Full Page ═══
class _PrivacyPolicyPage extends StatelessWidget {
  final AppColors colors;
  const _PrivacyPolicyPage({required this.colors});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        title: Text(
          '隐私政策',
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
      body: ScrollConfiguration(
        behavior: const _SmoothScrollBehavior(),
        child: ListView(
          physics: const BouncingScrollPhysics(
            parent: AlwaysScrollableScrollPhysics(),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          cacheExtent: 1200,
          children: [
            Text(
              'TEMPO 隐私政策',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.5,
                color: colors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: MiuiColors.blue.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '最后更新：2025年7月',
                    style: TextStyle(
                      fontSize: 12,
                      color: MiuiColors.blue,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: MiuiColors.green.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '版本 2.0',
                    style: TextStyle(
                      fontSize: 12,
                      color: MiuiColors.green,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // ─── 摘要卡片 ───
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    MiuiColors.green.withValues(alpha: 0.08),
                    MiuiColors.teal.withValues(alpha: 0.04),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: MiuiColors.green.withValues(alpha: 0.15),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.verified_user_rounded,
                        size: 18,
                        color: MiuiColors.green,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '隐私承诺摘要',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: MiuiColors.green,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _summaryRow(
                    Icons.check_circle_outline,
                    '不集成任何广告和第三方追踪 SDK',
                    colors,
                  ),
                  _summaryRow(
                    Icons.check_circle_outline,
                    '不收集位置、通讯录等敏感信息',
                    colors,
                  ),
                  _summaryRow(
                    Icons.check_circle_outline,
                    '数据默认存储在本地，云同步可选',
                    colors,
                  ),
                  _summaryRow(
                    Icons.check_circle_outline,
                    '所有传输均使用 HTTPS 加密',
                    colors,
                  ),
                  _summaryRow(
                    Icons.check_circle_outline,
                    '您可随时导出或删除全部数据',
                    colors,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),

            _pText(
              '欢迎使用TEMPO（以下简称"本应用"）。我们深知个人信息对您的重要性，并会尽全力保护您的隐私安全。请您在使用本应用前仔细阅读本隐私政策。',
              colors,
            ),
            const SizedBox(height: 28),

            _pTitle('1. 我们收集的信息', colors),
            _pSubTitle('1.1 账户信息', colors),
            _pText('当您注册账户时，我们会收集：', colors),
            _pBullet('邮箱地址：用于账户登录和验证码发送', colors),
            _pBullet('昵称：用于应用内显示（可选）', colors),
            _pBullet('密码：使用不可逆加密算法处理后存储，我们无法查看您的明文密码', colors),
            const SizedBox(height: 12),
            _pSubTitle('1.2 应用数据', colors),
            _pText('您在使用过程中产生的数据均存储在您的设备本地，包括：', colors),
            _pBullet('日程事件、习惯打卡记录、目标管理数据', colors),
            _pBullet('番茄钟计时记录和专注时长统计', colors),
            _pBullet('水杯记录、心情记录等生活数据', colors),
            _pBullet('界面设置偏好（主题、模糊效果等）', colors),
            const SizedBox(height: 12),
            _pSubTitle('1.3 设备信息（仅限诊断）', colors),
            _pText('为了优化体验和排查问题，我们可能在您主动提交反馈时附带以下信息：', colors),
            _pBullet('设备品牌和型号', colors),
            _pBullet('操作系统版本', colors),
            _pBullet('应用版本号', colors),
            _pText('这些信息仅在您主动发送反馈邮件时附带，不会自动采集或上报。', colors),
            const SizedBox(height: 12),
            _pSubTitle('1.4 我们不收集的信息', colors),
            _pBullet('我们不收集您的位置信息（GPS、基站定位等）', colors),
            _pBullet('我们不收集您的通讯录、短信或通话记录', colors),
            _pBullet('我们不收集您的相册、相机数据', colors),
            _pBullet('我们不集成任何第三方分析 SDK（如友盟、Firebase Analytics 等）', colors),
            _pBullet('我们不集成任何广告 SDK', colors),
            _pBullet('我们不集成任何第三方用户行为追踪 SDK', colors),
            _pBullet('我们不向任何第三方分享、出售或转让您的数据', colors),
            const SizedBox(height: 28),

            _pTitle('2. 数据存储与传输', colors),
            _pSubTitle('2.1 本地存储', colors),
            _pText(
              '您的应用数据默认存储在设备本地，使用 Hive 数据库。数据存储于应用私有目录，其他应用无法访问。卸载应用后本地数据将被清除。',
              colors,
            ),
            const SizedBox(height: 12),
            _pSubTitle('2.2 云同步', colors),
            _pText('当您登录账户后，云同步功能自动启用。同步机制如下：', colors),
            _pBullet('数据通过 HTTPS/TLS 加密通道传输', colors),
            _pBullet('API 请求使用 HMAC-SHA256 签名，防止中间人篡改', colors),
            _pBullet('同步数据仅用于您在多设备间恢复数据', colors),
            _pBullet('我们不会访问、查看或分析您的同步数据内容', colors),
            _pBullet('您可以在设置中手动触发同步或退出登录停止同步', colors),
            const SizedBox(height: 12),
            _pSubTitle('2.3 文件存储', colors),
            _pText('当您使用文件上传功能时：', colors),
            _pBullet('文件通过 HTTPS 加密传输至服务器', colors),
            _pBullet('上传请求附带签名验证，确保身份真实', colors),
            _pBullet('文件仅您本人可访问和管理', colors),
            _pBullet('分享链接可设置有效期和下载次数限制', colors),
            _pBullet('您可以随时删除已上传的文件', colors),
            const SizedBox(height: 12),
            _pSubTitle('2.4 服务器信息', colors),
            _pText('我们的服务器部署信息如下：', colors),
            _pBullet('服务器提供方：独立部署服务器', colors),
            _pBullet('传输协议：HTTPS (TLS 1.2+)', colors),
            _pBullet('接口安全：HMAC-SHA256 签名 + 时间戳 + 随机数防重放', colors),
            const SizedBox(height: 28),

            _pTitle('3. 权限说明', colors),
            _pText('本应用仅申请必要的系统权限，且所有权限均可在系统设置中随时关闭：', colors),
            const SizedBox(height: 12),
            _permRow(
              Icons.storage_outlined,
              '存储权限',
              '用于保存导出数据、下载更新包和文件管理。仅在您主动执行导出、下载操作时使用。',
              colors,
            ),
            _permRow(
              Icons.notifications_outlined,
              '通知权限',
              '用于日程提醒、习惯打卡提醒、番茄钟计时完成通知和应用更新通知。可在系统设置中单独控制各通知频道。',
              colors,
            ),
            _permRow(
              Icons.wifi_outlined,
              '网络权限',
              '用于账户登录、云同步、文件上传下载和应用更新检查。离线模式下所有本地功能正常使用。',
              colors,
            ),
            _permRow(
              Icons.install_mobile_outlined,
              '安装权限',
              '仅用于应用自更新时安装新版本 APK。首次使用时系统会弹窗确认。',
              colors,
            ),
            const SizedBox(height: 28),

            _pTitle('4. 数据安全措施', colors),
            _pSubTitle('4.1 传输安全', colors),
            _pBullet('所有网络通信均使用 HTTPS/TLS 加密传输', colors),
            _pBullet('API 请求使用 HMAC-SHA256 签名防篡改', colors),
            _pBullet('每个请求附带时间戳和随机数，防止重放攻击', colors),
            const SizedBox(height: 12),
            _pSubTitle('4.2 存储安全', colors),
            _pBullet('用户密码使用不可逆加密算法处理后存储', colors),
            _pBullet('本地数据存储在应用私有目录，其他应用无法直接访问', colors),
            _pBullet('认证令牌使用安全存储（SharedPreferences 加密存储）', colors),
            const SizedBox(height: 12),
            _pSubTitle('4.3 防滥用机制', colors),
            _pBullet('内置请求频率限制，防止暴力破解', colors),
            _pBullet('设备指纹识别，防止恶意批量注册', colors),
            _pBullet('异常行为检测和自动锁定', colors),
            const SizedBox(height: 28),

            _pTitle('5. 第三方服务', colors),
            _pText('本应用使用的第三方服务极少，且均不涉及用户数据追踪：', colors),
            _pBullet('Flutter 框架：Google 开源 UI 框架，用于界面渲染，不收集用户数据', colors),
            _pBullet('Hive 数据库：纯 Dart 编写的本地数据库，数据完全存储在本地', colors),

            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: MiuiColors.green.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.shield_outlined,
                    size: 18,
                    color: MiuiColors.green,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      '本应用不包含任何广告 SDK、统计分析 SDK（如友盟、Google Analytics、Firebase Analytics）、社交分享 SDK 或推送 SDK。所有推送通知均通过 Android 原生通知系统实现。',
                      style: TextStyle(
                        fontSize: 13,
                        color: colors.textSecondary,
                        height: 1.6,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),

            _pTitle('6. 数据保留与删除', colors),
            _pSubTitle('6.1 本地数据', colors),
            _pBullet('本地数据在您卸载应用后自动清除', colors),
            _pBullet('您可以在 设置 → 数据 → 清除缓存 清除临时数据', colors),
            _pBullet('您可以在 设置 → 数据 → 导出数据 后手动删除', colors),
            const SizedBox(height: 12),
            _pSubTitle('6.2 云端数据', colors),
            _pBullet('退出登录后，云端数据保留以便您重新登录恢复', colors),
            _pBullet('如需彻底删除云端数据，请发邮件至 zhuj3188@gmail.com 申请', colors),
            _pBullet('收到删除申请后，我们将在 7 个工作日内完成删除', colors),
            _pBullet('删除后数据不可恢复，请确保已备份重要数据', colors),
            const SizedBox(height: 12),
            _pSubTitle('6.3 账户注销', colors),
            _pText('您可以通过发送邮件至 zhuj3188@gmail.com 申请注销账户。注销后：', colors),
            _pBullet('您的账户信息（邮箱、昵称）将被永久删除', colors),
            _pBullet('云端同步数据将被永久删除', colors),
            _pBullet('已上传的文件将被永久删除', colors),
            _pBullet('本地数据不受影响，但将无法再同步', colors),
            const SizedBox(height: 28),

            _pTitle('7. 您的权利', colors),
            _pText('根据相关法律法规，您享有以下权利：', colors),
            _pBullet('知情权：您有权了解我们如何收集和使用您的信息（本政策即为告知）', colors),
            _pBullet('访问权：您可以随时在应用内查看您的所有数据', colors),
            _pBullet('导出权：您可以在 设置 → 数据 → 导出数据 将全部数据导出为 JSON 文件', colors),
            _pBullet('删除权：您可以随时清除本地数据，或申请删除云端数据和注销账户', colors),
            _pBullet('更正权：您可以在应用内修改您的昵称、密码等个人信息', colors),
            _pBullet('选择权：云同步为可选功能，您可以完全离线使用本应用的全部核心功能', colors),
            _pBullet('撤回同意权：您可以随时在系统设置中关闭本应用的各项权限', colors),
            const SizedBox(height: 28),

            _pTitle('8. 未成年人保护', colors),
            _pText('我们非常重视未成年人的隐私保护：', colors),
            _pBullet('本应用不针对 14 岁以下未成年人', colors),
            _pBullet('我们不会故意收集 14 岁以下未成年人的个人信息', colors),
            _pBullet('如果您是 14-18 岁的未成年人，请在监护人的陪同和同意下使用本应用', colors),
            _pBullet('如果我们发现在未经家长同意的情况下收集了未成年人信息，将立即删除相关数据', colors),
            const SizedBox(height: 28),

            _pTitle('9. 政策更新', colors),
            _pText('我们可能会不时更新本隐私政策。更新时：', colors),
            _pBullet('我们会通过应用内通知告知您政策变更', colors),
            _pBullet('重大变更会在应用启动时弹窗提醒', colors),
            _pBullet('您可以在本页面顶部查看最后更新日期', colors),
            _pBullet('继续使用本应用即表示您同意更新后的隐私政策', colors),
            _pBullet('如您不同意变更，可以停止使用并申请删除数据', colors),
            const SizedBox(height: 28),

            _pTitle('10. 适用法律', colors),
            _pText(
              '本隐私政策的解释和执行适用中华人民共和国法律法规，包括但不限于《个人信息保护法》《网络安全法》《数据安全法》。',
              colors,
            ),
            const SizedBox(height: 28),

            _pTitle('11. 联系我们', colors),
            _pText('如您对本隐私政策有任何疑问、建议或投诉，或需要行使上述权利，请通过以下方式联系我们：', colors),
            const SizedBox(height: 12),
            _contactCard(context, colors),
            const SizedBox(height: 60),
          ],
        ),
      ),
    );
  }

  Widget _summaryRow(IconData icon, String text, AppColors colors) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Row(
      children: [
        Icon(icon, size: 16, color: MiuiColors.green),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 13,
              color: colors.textSecondary,
              height: 1.5,
            ),
          ),
        ),
      ],
    ),
  );

  Widget _pTitle(String text, AppColors colors) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Text(
      text,
      style: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.2,
        color: colors.textPrimary,
      ),
    ),
  );

  Widget _pSubTitle(String text, AppColors colors) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(
      text,
      style: TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w600,
        color: colors.textPrimary,
      ),
    ),
  );

  Widget _pText(String text, AppColors colors) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(
      text,
      style: TextStyle(fontSize: 14, color: colors.textSecondary, height: 1.7),
    ),
  );

  Widget _pBullet(String text, AppColors colors) => Padding(
    padding: const EdgeInsets.only(left: 8, bottom: 6),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 7),
          child: Container(
            width: 5,
            height: 5,
            decoration: BoxDecoration(
              color: colors.textTertiary,
              shape: BoxShape.circle,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 14,
              color: colors.textSecondary,
              height: 1.6,
            ),
          ),
        ),
      ],
    ),
  );

  Widget _permRow(IconData icon, String title, String desc, AppColors colors) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: MiuiColors.blue.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, size: 20, color: MiuiColors.blue),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: colors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    desc,
                    style: TextStyle(
                      fontSize: 13,
                      color: colors.textSecondary,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );

  Widget _contactCard(BuildContext context, AppColors colors) => Container(
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: MiuiColors.blue.withValues(alpha: 0.06),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: MiuiColors.blue.withValues(alpha: 0.15)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.email_outlined, size: 18, color: MiuiColors.blue),
            const SizedBox(width: 10),
            Text(
              '开发者邮箱',
              style: TextStyle(fontSize: 13, color: colors.textTertiary),
            ),
          ],
        ),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: () async {
            final uri = Uri.parse('mailto:zhuj3188@gmail.com');
            try {
              if (await canLaunchUrl(uri)) {
                await launchUrl(uri);
              } else {
                await Clipboard.setData(
                  const ClipboardData(text: 'zhuj3188@gmail.com'),
                );
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: const Text('邮箱已复制到剪贴板'),
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      margin: const EdgeInsets.all(16),
                    ),
                  );
                }
              }
            } catch (_) {
              await Clipboard.setData(
                const ClipboardData(text: 'zhuj3188@gmail.com'),
              );
            }
          },
          child: Text(
            'zhuj3188@gmail.com',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: MiuiColors.blue,
              decoration: TextDecoration.underline,
              decorationColor: MiuiColors.blue.withValues(alpha: 0.4),
            ),
          ),
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Icon(Icons.apps_rounded, size: 18, color: MiuiColors.blue),
            const SizedBox(width: 10),
            Text(
              '应用名称',
              style: TextStyle(fontSize: 13, color: colors.textTertiary),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          'TEMPO',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: colors.textPrimary,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Time. Everything. Moments. Productivity. Organized.',
          style: TextStyle(
            fontSize: 13,
            height: 1.45,
            color: colors.textSecondary,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '时间、信息、当下与效率，一切井然有序。',
          style: TextStyle(fontSize: 13, color: colors.textSecondary),
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Icon(
              Icons.person_outline_rounded,
              size: 18,
              color: MiuiColors.blue,
            ),
            const SizedBox(width: 10),
            Text(
              '开发者',
              style: TextStyle(fontSize: 13, color: colors.textTertiary),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          'TEMPO 独立开发者',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: colors.textPrimary,
          ),
        ),
      ],
    ),
  );
}

// ═══ Help & Feedback Full Page ═══
class _HelpFeedbackPage extends StatelessWidget {
  final AppColors colors;
  final void Function(BuildContext, AppColors, {String type}) onShowFeedback;
  const _HelpFeedbackPage({required this.colors, required this.onShowFeedback});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        title: Text(
          '帮助与反馈',
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
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Contact card
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    MiuiColors.blue.withValues(alpha: 0.08),
                    MiuiColors.teal.withValues(alpha: 0.05),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: MiuiColors.blue.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Icon(
                      Icons.support_agent_rounded,
                      size: 26,
                      color: MiuiColors.blue,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '需要帮助？',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: colors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '我们随时为您提供支持',
                          style: TextStyle(
                            fontSize: 13,
                            color: colors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),

            // Quick actions
            Text(
              '快速操作',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: colors.textTertiary,
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: _actionCard(
                    Icons.bug_report_outlined,
                    '报告问题',
                    MiuiColors.red,
                    colors,
                    () => onShowFeedback(context, colors, type: '问题报告'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _actionCard(
                    Icons.lightbulb_outline_rounded,
                    '功能建议',
                    MiuiColors.orange,
                    colors,
                    () => onShowFeedback(context, colors, type: '功能建议'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _actionCard(
                    Icons.email_outlined,
                    '发邮件',
                    MiuiColors.blue,
                    colors,
                    () async {
                      final uri = Uri.parse(
                        'mailto:zhuj3188@gmail.com?subject=${Uri.encodeComponent('[TEMPO反馈] ')}',
                      );
                      try {
                        await launchUrl(uri);
                      } catch (_) {
                        if (context.mounted) {
                          await Clipboard.setData(
                            const ClipboardData(text: 'zhuj3188@gmail.com'),
                          );
                          if (context.mounted)
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: const Text('邮箱已复制到剪贴板'),
                                behavior: SnackBarBehavior.floating,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                margin: const EdgeInsets.all(16),
                              ),
                            );
                        }
                      }
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),

            // ─── 使用技巧 ───
            Text(
              '使用技巧',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: colors.textTertiary,
              ),
            ),
            const SizedBox(height: 14),
            _tipCard(
              Icons.timer_rounded,
              '高效番茄钟',
              '25 分钟专注 + 5 分钟休息是经典节奏。每 4 个番茄钟后建议长休息 15-30 分钟，效率更高。',
              MiuiColors.orange,
              colors,
            ),
            const SizedBox(height: 10),
            _tipCard(
              Icons.checklist_rounded,
              '日程管理',
              '将大任务拆分成小步骤，利用日历视图规划一周安排。完成后及时勾选，保持成就感。',
              MiuiColors.blue,
              colors,
            ),
            const SizedBox(height: 10),
            _tipCard(
              Icons.trending_up_rounded,
              '习惯养成',
              '每天固定时间打卡，连续 21 天即可初步养成习惯。TEMPO会自动统计连续天数，帮你保持动力。',
              MiuiColors.green,
              colors,
            ),
            const SizedBox(height: 10),
            _tipCard(
              Icons.cloud_sync_outlined,
              '数据安全',
              '建议登录账户并开启云同步，换机或重装后数据自动恢复，再也不怕丢失。',
              MiuiColors.teal,
              colors,
            ),
            const SizedBox(height: 32),

            // FAQ
            Text(
              '常见问题',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: colors.textTertiary,
              ),
            ),
            const SizedBox(height: 14),
            _faqItem(
              '如何同步数据到新设备？',
              '在旧设备上登录账户并开启云同步，数据会自动上传。在新设备上登录同一账户，数据会自动恢复。也可以在设置中手动点击"立即同步"。',
              colors,
            ),
            _faqItem(
              '番茄钟计时被系统杀后台怎么办？',
              '请在系统设置中将TEMPO加入电池优化白名单，并开启"允许后台运行"。具体步骤：\n\n'
                  '  OPPO/realme：设置 → 电池 → 更多电池设置 → 优化电池使用 → 找到TEMPO → 不优化\n'
                  '  华为/荣耀：设置 → 电池 → 启动管理 → 找到TEMPO → 设为手动管理，开启全部开关\n'
                  '  小米/红米：设置 → 应用设置 → 应用管理 → 找到TEMPO → 省电策略 → 无限制\n'
                  '  vivo：设置 → 电池 → 后台高耗电 → 允许TEMPO后台高耗电',
              colors,
            ),
            _faqItem(
              '如何导出我的数据？',
              '前往 设置 → 数据 → 导出数据，所有数据将导出为 JSON 文件，包含日程、习惯、目标、番茄钟记录等全部数据。导出的文件可作为备份保存，也可用于迁移。',
              colors,
            ),
            _faqItem(
              '应用更新失败怎么办？',
              '请按以下步骤排查：\n\n'
                  '1. 确保设备已允许"安装未知来源应用"权限（设置 → 安全 → 安装未知应用 → 允许TEMPO）\n'
                  '2. 检查存储空间是否充足（至少需要 200MB 可用空间）\n'
                  '3. 增量更新失败时，请连接Wi-Fi后重试，系统会自动重新下载增量包\n'
                  '4. 如仍失败，到 设置 → 服务器 → 检查更新 手动重试\n'
                  '5. 检查网络连接是否稳定，建议在 WiFi 环境下更新',
              colors,
            ),

            _faqItem(
              '文件分享功能怎么用？',
              '在文件管理中，点击文件右上角的分享按钮，可以生成带有精美下载页面的分享链接，支持设置下载次数和过期时间。对方无需安装任何应用即可下载。',
              colors,
            ),
            _faqItem(
              '数据存储在哪里？安全吗？',
              '您的数据默认存储在设备本地，使用 Hive 加密数据库。如开启云同步，数据通过 HTTPS 加密传输至服务器，接口使用 HMAC-SHA256 签名防篡改。我们不收集任何无关个人信息，不集成第三方追踪 SDK，不向任何第三方分享数据。',
              colors,
            ),
            _faqItem(
              '支持哪些设备和系统版本？',
              'TEMPO支持 Android 7.0（API 24）及以上系统。推荐使用 Android 10+ 以获得最佳体验。暂不支持 iOS。',
              colors,
            ),
            _faqItem(
              '如何注销账户？',
              '进入 设置 → 点击顶部头像 → 退出登录。退出后本地数据保留，云端数据不会删除。如需彻底删除云端数据，请发邮件至 zhuj3188@gmail.com 申请。',
              colors,
            ),
            const SizedBox(height: 32),

            // ─── 版本信息 ───
            Text(
              '版本信息',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: colors.textTertiary,
              ),
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: colors.surface,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [MiuiColors.blue, MiuiColors.teal],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Icon(
                          Icons.spa_rounded,
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
                              'TEMPO',
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w700,
                                color: colors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              'v${ServerConfig.appVersion} (Build ${ServerConfig.appBuild})',
                              style: TextStyle(
                                fontSize: 13,
                                color: colors.textTertiary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Divider(
                    height: 1,
                    thickness: 0.5,
                    color: colors.divider.withValues(alpha: 0.5),
                  ),
                  const SizedBox(height: 16),
                  _versionRow('应用版本', 'v${ServerConfig.appVersion}', colors),
                  _versionRow('构建号', '${ServerConfig.appBuild}', colors),
                  _versionRow('最低系统', 'Android 7.0 (API 24)', colors),
                  _versionRow('目标系统', 'Android 15 (API 35)', colors),
                  _versionRow('开发框架', 'Flutter', colors),
                ],
              ),
            ),
            const SizedBox(height: 32),

            // Contact info
            Text(
              '联系方式',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: colors.textTertiary,
              ),
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: colors.surface,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Column(
                children: [
                  _contactRow(
                    Icons.email_outlined,
                    '开发者邮箱',
                    'zhuj3188@gmail.com',
                    MiuiColors.blue,
                    colors,
                    () async {
                      final uri = Uri.parse('mailto:zhuj3188@gmail.com');
                      try {
                        await launchUrl(uri);
                      } catch (_) {
                        await Clipboard.setData(
                          const ClipboardData(text: 'zhuj3188@gmail.com'),
                        );
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: const Text('邮箱已复制到剪贴板'),
                              behavior: SnackBarBehavior.floating,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                              margin: const EdgeInsets.all(16),
                            ),
                          );
                        }
                      }
                    },
                  ),
                  Divider(
                    height: 28,
                    thickness: 0.5,
                    color: colors.divider.withValues(alpha: 0.5),
                  ),
                  _contactRow(
                    Icons.schedule_outlined,
                    '响应时间',
                    '通常 24 小时内回复',
                    MiuiColors.green,
                    colors,
                    null,
                  ),
                  Divider(
                    height: 28,
                    thickness: 0.5,
                    color: colors.divider.withValues(alpha: 0.5),
                  ),
                  _contactRow(
                    Icons.language_outlined,
                    '开发者',
                    'TEMPO 独立开发',
                    MiuiColors.teal,
                    colors,
                    null,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),

            // ─── 反馈须知 ───
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: MiuiColors.orange.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: MiuiColors.orange.withValues(alpha: 0.15),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.tips_and_updates_rounded,
                        size: 18,
                        color: MiuiColors.orange,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '反馈小贴士',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: MiuiColors.orange,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    '提交 Bug 时请尽量附上以下信息，帮助我们更快定位问题：\n'
                    '  1. 手机品牌、型号和系统版本\n'
                    '  2. 出现问题时的操作步骤\n'
                    '  3. 截图或录屏（如有）\n'
                    '  4. 问题出现的频率（每次都出现/偶尔出现）',
                    style: TextStyle(
                      fontSize: 13,
                      color: colors.textSecondary,
                      height: 1.7,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 60),
          ],
        ),
      ),
    );
  }

  Widget _actionCard(
    IconData icon,
    String label,
    Color color,
    AppColors colors,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            Icon(icon, size: 28, color: color),
            const SizedBox(height: 10),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: colors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _tipCard(
    IconData icon,
    String title,
    String desc,
    Color color,
    AppColors colors,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.12)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 18, color: color),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: colors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  desc,
                  style: TextStyle(
                    fontSize: 13,
                    color: colors.textSecondary,
                    height: 1.6,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _faqItem(String question, String answer, AppColors colors) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 4),
        childrenPadding: const EdgeInsets.fromLTRB(4, 0, 4, 16),
        shape: const Border(),
        collapsedShape: const Border(),
        leading: Icon(
          Icons.help_outline_rounded,
          size: 20,
          color: MiuiColors.blue.withValues(alpha: 0.6),
        ),
        title: Text(
          question,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: colors.textPrimary,
            height: 1.4,
          ),
        ),
        children: [
          Text(
            answer,
            style: TextStyle(
              fontSize: 13,
              color: colors.textSecondary,
              height: 1.7,
            ),
          ),
        ],
      ),
    );
  }

  Widget _versionRow(String label, String value, AppColors colors) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: TextStyle(fontSize: 13, color: colors.textTertiary),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 13,
                color: colors.textPrimary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _contactRow(
    IconData icon,
    String label,
    String value,
    Color color,
    AppColors colors,
    VoidCallback? onTap,
  ) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 18, color: color),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(fontSize: 12, color: colors.textTertiary),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: onTap != null ? MiuiColors.blue : colors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
          if (onTap != null)
            Icon(
              Icons.open_in_new_rounded,
              size: 16,
              color: colors.textTertiary,
            ),
        ],
      ),
    );
  }
}

// ═══ Smooth scroll behavior (removes overscroll glow, keeps bounce) ═══
class _SmoothScrollBehavior extends ScrollBehavior {
  const _SmoothScrollBehavior();

  @override
  ScrollPhysics getScrollPhysics(BuildContext context) {
    return const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics());
  }

  @override
  Widget buildOverscrollIndicator(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) {
    // Remove the default Android overscroll glow for a cleaner scroll experience
    return child;
  }
}

// ═══ Update Dialog for Settings Page — Pure Incremental v4 ═══
class _UpdateSettingsDialog extends StatefulWidget {
  final VersionInfo info;
  final AppColors colors;
  const _UpdateSettingsDialog({required this.info, required this.colors});
  @override
  State<_UpdateSettingsDialog> createState() => _UpdateSettingsDialogState();
}

class _UpdateSettingsDialogState extends State<_UpdateSettingsDialog> {
  bool _downloading = false;
  double _progress = 0;
  String _statusText = '';
  bool _downloadComplete = false;
  String? _completedApkPath;
  double _speed = 0;
  int _speedTrackStart = 0;
  int _speedTrackBytes = 0;

  String get _speedText {
    if (_speed <= 0) return '';
    if (_speed > 1024 * 1024)
      return '${(_speed / (1024 * 1024)).toStringAsFixed(1)} MB/s';
    return '${(_speed / 1024).toStringAsFixed(0)} KB/s';
  }

  void _trackSpeed(int received) {
    final now = DateTime.now().millisecondsSinceEpoch;
    if (_speedTrackStart == 0) {
      _speedTrackStart = now;
      _speedTrackBytes = received;
      return;
    }
    final elapsed = (now - _speedTrackStart) / 1000.0;
    if (elapsed < 0.5) return;
    _speed = (received - _speedTrackBytes) / elapsed;
    _speedTrackStart = now;
    _speedTrackBytes = received;
  }

  Future<void> _startDownload() async {
    setState(() {
      _downloading = true;
      _progress = 0;
      _completedApkPath = null;
      _speed = 0;
      _speedTrackStart = 0;
      _speedTrackBytes = 0;
    });

    if (!Platform.isAndroid) {
      setState(() {
        _downloading = false;
        _statusText = '请在 Android 设备上更新';
      });
      return;
    }

    final savePath = await UpdateChecker.getApkSavePath();

    // Strategy: try incremental patch first, then fall back to full APK
    if (widget.info.patchAvailable) {
      setState(() {
        _statusText = '准备增量更新...';
      });
      final currentApkPath = await ApiService.getCurrentApkPath();
      if (currentApkPath != null) {
        try {
          final result = await ApiService().downloadAndApplyPatch(
            info: widget.info,
            currentApkPath: currentApkPath,
            savePath: savePath,
            onStage: (stage) {
              if (!mounted) return;
              switch (stage) {
                case 'downloading':
                  setState(() {
                    _statusText = '下载增量包...';
                  });
                  break;
                case 'patching':
                  setState(() {
                    _statusText = '合并更新中...';
                    _progress = 0.9;
                  });
                  break;
                case 'verifying':
                  setState(() {
                    _statusText = '校验文件...';
                    _progress = 0.95;
                  });
                  break;
              }
            },
            onProgress: (received, total) {
              if (!mounted) return;
              _trackSpeed(received);
              final effectiveTotal = widget.info.patchSize > 0
                  ? widget.info.patchSize
                  : total;
              final receivedMB = (received / (1024 * 1024)).toStringAsFixed(1);
              if (effectiveTotal > 0 && effectiveTotal >= received) {
                final pct = received / effectiveTotal;
                final totalMB = (effectiveTotal / (1024 * 1024))
                    .toStringAsFixed(1);
                setState(() {
                  _progress = pct * 0.85;
                  _statusText =
                      '增量下载 $receivedMB / $totalMB MB${_speedText.isNotEmpty ? '  $_speedText' : ''}';
                });
              } else {
                setState(() {
                  _progress = -1;
                  _statusText = '增量下载 $receivedMB MB...';
                });
              }
            },
          );

          _completedApkPath = result;
          setState(() {
            _downloadComplete = true;
            _progress = 1.0;
            _statusText = '更新完成，正在安装...';
          });
          final installed = await ApiService.installApk(result);
          if (mounted) {
            setState(() {
              _downloading = false;
              _statusText = installed ? '安装已启动，请确认安装' : '请点击下方按钮安装';
            });
          }
          return; // Patch succeeded, done
        } catch (e) {
          if (mounted) {
            debugPrint('Patch failed, falling back to full APK: $e');
            // Reset progress for full APK download
            setState(() {
              _progress = 0;
              _speed = 0;
              _speedTrackStart = 0;
              _speedTrackBytes = 0;
              _statusText = '增量更新失败，正在下载完整安装包...';
            });
          }
        }
      }
    }

    // Full APK download — either no patch available or patch failed
    if (widget.info.fullDownloadUrl.isEmpty) {
      if (mounted)
        setState(() {
          _downloading = false;
          _statusText = '服务器暂无可用安装包';
        });
      return;
    }

    if (mounted) {
      setState(() {
        _statusText = widget.info.patchAvailable
            ? '增量失败，下载完整安装包...'
            : '下载完整安装包...';
      });
    }

    try {
      final downloaded = await ApiService().downloadFile(
        downloadUrl: widget.info.fullDownloadUrl,
        savePath: savePath,
        expectedSize: widget.info.apkSize,
        expectedHash: widget.info.apkHash.isNotEmpty
            ? widget.info.apkHash
            : null,
        cleanStart: true,
        onProgress: (received, total) {
          if (!mounted) return;
          _trackSpeed(received);
          final effectiveTotal = widget.info.apkSize > 0
              ? widget.info.apkSize
              : total;
          final receivedMB = (received / (1024 * 1024)).toStringAsFixed(1);
          if (effectiveTotal > 0 && effectiveTotal >= received) {
            final pct = received / effectiveTotal;
            final totalMB = (effectiveTotal / (1024 * 1024)).toStringAsFixed(1);
            setState(() {
              _progress = pct;
              _statusText =
                  '下载 $receivedMB / $totalMB MB${_speedText.isNotEmpty ? '  $_speedText' : ''}';
            });
          } else {
            setState(() {
              _progress = -1;
              _statusText = '下载 $receivedMB MB...';
            });
          }
        },
      );

      if (downloaded == null) {
        if (mounted)
          setState(() {
            _downloading = false;
            _statusText = '下载失败，请检查网络后重试';
          });
        return;
      }

      _completedApkPath = savePath;
      setState(() {
        _downloadComplete = true;
        _progress = 1.0;
        _statusText = '下载完成，正在安装...';
      });
      final installed = await ApiService.installApk(savePath);
      if (mounted) {
        setState(() {
          _downloading = false;
          _statusText = installed ? '安装已启动，请确认安装' : '请点击下方按钮安装';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _downloading = false;
          _statusText = '下载失败: $e';
        });
      }
    }
  }

  Future<void> _triggerInstall() async {
    if (_completedApkPath == null) return;
    setState(() {
      _statusText = '正在启动安装...';
    });
    final installed = await ApiService.installApk(_completedApkPath!);
    if (mounted) {
      setState(() {
        _statusText = installed ? '安装已启动，请确认安装' : '启动安装失败，请手动安装';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.colors;
    final info = widget.info;
    return AlertDialog(
      backgroundColor: c.card,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: MiuiColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.system_update_rounded,
              color: MiuiColors.primary,
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              '发现新版本',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: c.textPrimary,
              ),
            ),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: MiuiColors.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  'v${info.latestVersion} (Build ${info.latestBuild})',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: MiuiColors.primary,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              if (info.patchAvailable && info.patchSize > 0)
                Text(
                  '增量 ${info.patchSizeFormatted}',
                  style: TextStyle(fontSize: 12, color: MiuiColors.green),
                )
              else if (info.apkSize > 0)
                Text(
                  info.apkSizeFormatted,
                  style: TextStyle(fontSize: 12, color: c.textTertiary),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            info.releaseNotes,
            style: TextStyle(fontSize: 14, color: c.textSecondary, height: 1.5),
          ),
          if (_downloading) ...[
            const SizedBox(height: 20),
            if (!_downloadComplete)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  color: MiuiColors.green.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      info.patchAvailable
                          ? Icons.bolt_rounded
                          : Icons.download_rounded,
                      size: 14,
                      color: MiuiColors.green,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      info.patchAvailable ? '增量更新' : '完整安装包',
                      style: TextStyle(
                        fontSize: 11,
                        color: MiuiColors.green,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: _downloadComplete
                    ? 1.0
                    : (_progress < 0 ? null : _progress),
                minHeight: 6,
                backgroundColor: MiuiColors.primary.withValues(alpha: 0.1),
                valueColor: AlwaysStoppedAnimation(
                  _downloadComplete ? MiuiColors.green : MiuiColors.primary,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                if (!_downloadComplete)
                  SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: MiuiColors.primary,
                    ),
                  ),
                if (!_downloadComplete) const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _statusText,
                    style: TextStyle(
                      fontSize: 12,
                      color: _downloadComplete
                          ? MiuiColors.green
                          : c.textSecondary,
                    ),
                  ),
                ),
                if (!_downloadComplete && _progress >= 0)
                  Text(
                    '${(_progress * 100).toInt()}%',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: MiuiColors.primary,
                    ),
                  ),
              ],
            ),
          ],
          if (!_downloading && _statusText.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              _statusText,
              style: TextStyle(
                fontSize: 12,
                color: _statusText.contains('失败')
                    ? MiuiColors.red
                    : MiuiColors.green,
              ),
            ),
          ],
        ],
      ),
      actions: [
        if (!info.forceUpdate && !_downloading)
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('稍后再说', style: TextStyle(color: c.textSecondary)),
          ),
        if (!_downloading && _downloadComplete && _completedApkPath != null)
          ElevatedButton.icon(
            onPressed: _triggerInstall,
            icon: const Icon(Icons.install_mobile_rounded, size: 18),
            label: const Text('安装更新'),
            style: ElevatedButton.styleFrom(
              backgroundColor: MiuiColors.green,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 0,
            ),
          ),
        if (!_downloading && !_downloadComplete)
          ElevatedButton(
            onPressed: _startDownload,
            style: ElevatedButton.styleFrom(
              backgroundColor: MiuiColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 0,
            ),
            child: Text(_statusText.contains('失败') ? '重试' : '立即更新'),
          ),
      ],
    );
  }
}
