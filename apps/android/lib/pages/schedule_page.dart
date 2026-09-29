import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/app_provider.dart';
import '../services/reminder_service.dart';
import '../services/hitokoto_service.dart';
import '../services/weather_service.dart';
import '../services/holiday_service.dart';
import '../theme/miui_theme.dart';
import '../models/models.dart';
import '../services/auth_service.dart';

class SchedulePage extends StatefulWidget {
  const SchedulePage({super.key});

  @override
  State<SchedulePage> createState() => _SchedulePageState();
}

class _SchedulePageState extends State<SchedulePage> {
  String _quote = '';
  String _quoteFrom = '';
  bool _quoteLoaded = false;
  bool _isLoadingExternal = false;

  @override
  void initState() {
    super.initState();
    _loadExternalData();
  }

  Future<void> _loadExternalData() async {
    if (_isLoadingExternal) return;
    _isLoadingExternal = true;

    await Future.wait([
      _loadQuote(),
      _loadHolidays(),
      if (WeatherService().hasApiKey) _loadWeather(),
    ]);

    if (mounted) setState(() {});
    _isLoadingExternal = false;
  }

  Future<void> _loadQuote() async {
    final ok = await HitokotoService().fetch();
    if (ok && mounted) {
      setState(() {
        _quote = HitokotoService().content;
        _quoteFrom = HitokotoService().from;
        _quoteLoaded = true;
      });
    }
  }

  Future<void> _loadHolidays() async {
    await HolidayService().fetchMonth(DateTime.now());
  }

  Future<void> _loadWeather() async {
    await WeatherService().fetch();
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    return Consumer<AppProvider>(
      builder: (context, provider, _) {
        final now = DateTime.now();
        final sel = provider.selectedDate;
        final isToday =
            sel.day == now.day &&
            sel.month == now.month &&
            sel.year == now.year;
        final greeting = now.hour < 12
            ? '早上好'
            : (now.hour < 18 ? '下午好' : '晚上好');
        final dayEvents = provider.events; // auto-filtered by selectedDate

        return SafeArea(
          bottom: false,
          child: CustomScrollView(
            physics: const BouncingScrollPhysics(
              parent: AlwaysScrollableScrollPhysics(),
            ),
            slivers: [
              // ─── Header with Weather ───
              SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                    Breathing.pagePaddingH,
                    32,
                    Breathing.pagePaddingH,
                    0,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              greeting,
                              style: TextStyle(
                                fontSize: provider.titleSize,
                                fontWeight: provider.titleWeight,
                                color: colors.textPrimary,
                                letterSpacing: -0.8,
                                height: 1.15,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Text(
                                  DateFormat('M月d日 EEEE', 'zh_CN').format(sel),
                                  style: TextStyle(
                                    fontSize: Breathing.subtitleSize,
                                    color: colors.textSecondary,
                                    fontWeight: FontWeight.w400,
                                    letterSpacing: 0.1,
                                  ),
                                ),
                                // Holiday indicator (inline)
                                if (_holidayName(sel) != null) ...[
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 7,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color:
                                          (HolidayService().isHoliday(sel)
                                                  ? MiuiColors.red
                                                  : MiuiColors.orange)
                                              .withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      _holidayName(sel)!,
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w500,
                                        color: HolidayService().isHoliday(sel)
                                            ? MiuiColors.red
                                            : MiuiColors.orange,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            // ─── Hitokoto inline ───
                            if (_quoteLoaded)
                              Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: GestureDetector(
                                  onTap: _refreshQuote,
                                  child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Padding(
                                        padding: const EdgeInsets.only(top: 2),
                                        child: Icon(
                                          Icons.format_quote_rounded,
                                          size: 14,
                                          color: colors.isDark
                                              ? const Color(0xFF8AB4F8)
                                              : const Color(0xFF5B7FA6),
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              _quote,
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: colors.isDark
                                                    ? const Color(0xFF8AB4F8)
                                                    : const Color(0xFF5B7FA6),
                                                height: 1.4,
                                                fontStyle: FontStyle.italic,
                                              ),
                                              maxLines: 3,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            if (_quoteFrom.isNotEmpty)
                                              Padding(
                                                padding: const EdgeInsets.only(
                                                  top: 2,
                                                ),
                                                child: Text(
                                                  '— $_quoteFrom',
                                                  style: TextStyle(
                                                    fontSize: 11,
                                                    color:
                                                        (colors.isDark
                                                                ? const Color(
                                                                    0xFF8AB4F8,
                                                                  )
                                                                : const Color(
                                                                    0xFF5B7FA6,
                                                                  ))
                                                            .withValues(
                                                              alpha: 0.7,
                                                            ),
                                                    fontStyle: FontStyle.italic,
                                                  ),
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                              ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                      // Weather or avatar
                      if (WeatherService().hasData)
                        _WeatherBadge(colors: colors)
                      else
                        Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                MiuiColors.primary.withValues(alpha: 0.15),
                                MiuiColors.teal.withValues(alpha: 0.1),
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.person_rounded,
                            size: 22,
                            color: MiuiColors.primary,
                          ),
                        ),
                    ],
                  ),
                ),
              ),

              // ─── Week Date Selector (with holiday dots) ───
              SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                    Breathing.pagePaddingH,
                    provider.sectionGap,
                    Breathing.pagePaddingH,
                    0,
                  ),
                  child: GlassCard(
                    enabled: provider.liquidGlass,
                    borderRadius: provider.cardRadius,
                    padding: const EdgeInsets.symmetric(
                      vertical: 10,
                      horizontal: 8,
                    ),
                    child: _WeekSelector(
                      selectedDate: provider.selectedDate,
                      onDateSelected: provider.setSelectedDate,
                      colors: colors,
                    ),
                  ),
                ),
              ),

              // ─── Stats Row ───
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    Breathing.pagePaddingH,
                    28,
                    Breathing.pagePaddingH,
                    0,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: GlassCard(
                          enabled: provider.liquidGlass,
                          borderRadius: provider.cardRadius,
                          child: _StatContent(
                            label: '待办',
                            value:
                                '${dayEvents.where((e) => !e.isCompleted).length}',
                            unit: '项',
                            color: MiuiColors.blue,
                            colors: colors,
                          ),
                        ),
                      ),
                      const SizedBox(width: Breathing.cardGap),
                      Expanded(
                        child: GlassCard(
                          enabled: provider.liquidGlass,
                          borderRadius: provider.cardRadius,
                          child: _StatContent(
                            label: '专注',
                            value: provider.focusTimeFormatted,
                            unit: '',
                            color: MiuiColors.orange,
                            colors: colors,
                          ),
                        ),
                      ),
                      const SizedBox(width: Breathing.cardGap),
                      Expanded(
                        child: GlassCard(
                          enabled: provider.liquidGlass,
                          borderRadius: provider.cardRadius,
                          child: _StatContent(
                            label: '完成率',
                            value: '${(provider.completionRate * 100).toInt()}',
                            unit: '%',
                            color: MiuiColors.green,
                            colors: colors,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // ─── Section Title ───
              SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                    Breathing.pagePaddingH,
                    provider.sectionGap,
                    Breathing.pagePaddingH,
                    8,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        isToday ? '今日日程' : '${sel.month}月${sel.day}日日程',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: colors.textPrimary,
                          letterSpacing: -0.3,
                        ),
                      ),
                      Text(
                        '${dayEvents.where((e) => e.isCompleted).length}/${dayEvents.length}',
                        style: TextStyle(
                          fontSize: 14,
                          color: colors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // ─── Schedule Cards or Empty State ───
              if (dayEvents.isEmpty)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(
                      Breathing.pagePaddingH,
                      40,
                      Breathing.pagePaddingH,
                      120,
                    ),
                    child: Center(
                      child: Column(
                        children: [
                          Icon(
                            Icons.event_available_rounded,
                            size: 64,
                            color: colors.textTertiary.withValues(alpha: 0.4),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            '这天没有日程',
                            style: TextStyle(
                              fontSize: 16,
                              color: colors.textTertiary,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            '点击右下角 + 添加',
                            style: TextStyle(
                              fontSize: 13,
                              color: colors.textTertiary.withValues(alpha: 0.6),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(
                    Breathing.pagePaddingH,
                    8,
                    Breathing.pagePaddingH,
                    120,
                  ),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate((context, index) {
                      final event = dayEvents[index];
                      return _ScheduleCardWrapper(
                        event: event,
                        colors: colors,
                        isGlass: provider.liquidGlass,
                        cardRadius: provider.cardRadius,
                        index: index,
                      );
                    }, childCount: dayEvents.length),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  String? _holidayName(DateTime date) {
    return HolidayService().getHolidayName(date);
  }

  Future<void> _refreshQuote() async {
    final ok = await HitokotoService().refresh();
    if (ok && mounted) {
      setState(() {
        _quote = HitokotoService().content;
        _quoteFrom = HitokotoService().from;
      });
    }
  }
}

// ─── Weather Badge ───
class _WeatherBadge extends StatelessWidget {
  final AppColors colors;
  const _WeatherBadge({required this.colors});

  @override
  Widget build(BuildContext context) {
    final ws = WeatherService();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: WeatherService.getWeatherColor(ws.icon).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            WeatherService.getWeatherIcon(ws.icon),
            size: 22,
            color: WeatherService.getWeatherColor(ws.icon),
          ),
          const SizedBox(height: 2),
          Text(
            '${ws.temp}\u00B0',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: colors.textPrimary,
            ),
          ),
          Text(
            ws.text,
            style: TextStyle(fontSize: 10, color: colors.textSecondary),
          ),
        ],
      ),
    );
  }
}

// ─── Week Day Selector (with holiday indicators) ───
class _WeekSelector extends StatelessWidget {
  final DateTime selectedDate;
  final ValueChanged<DateTime> onDateSelected;
  final AppColors colors;
  const _WeekSelector({
    required this.selectedDate,
    required this.onDateSelected,
    required this.colors,
  });

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
    final days = List.generate(7, (i) => startOfWeek.add(Duration(days: i)));
    final dayNames = ['一', '二', '三', '四', '五', '六', '日'];

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: List.generate(7, (i) {
        final day = days[i];
        final isSelected =
            day.day == selectedDate.day &&
            day.month == selectedDate.month &&
            day.year == selectedDate.year;
        final isToday =
            day.day == now.day &&
            day.month == now.month &&
            day.year == now.year;
        final holidayInfo = HolidayService().getInfo(day);
        final isHoliday = holidayInfo != null && holidayInfo.isHoliday;
        final isWorkDay = holidayInfo != null && !holidayInfo.isHoliday; // 补班

        return GestureDetector(
          onTap: () => onDateSelected(day),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOutCubic,
            width: 42,
            padding: const EdgeInsets.symmetric(vertical: 6),
            decoration: BoxDecoration(
              color: isSelected ? MiuiColors.primary : Colors.transparent,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              children: [
                Text(
                  dayNames[i],
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: isSelected
                        ? Colors.white.withValues(alpha: 0.7)
                        : colors.textTertiary,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '${day.day}',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: isSelected
                        ? Colors.white
                        : (isToday
                              ? MiuiColors.primary
                              : (isHoliday
                                    ? MiuiColors.red
                                    : colors.textPrimary)),
                  ),
                ),
                const SizedBox(height: 3),
                // Holiday/workday dot indicator
                if (isHoliday && !isSelected)
                  Text(
                    '休',
                    style: TextStyle(
                      fontSize: 8,
                      fontWeight: FontWeight.w700,
                      color: MiuiColors.red,
                    ),
                  )
                else if (isWorkDay && !isSelected)
                  Text(
                    '班',
                    style: TextStyle(
                      fontSize: 8,
                      fontWeight: FontWeight.w700,
                      color: MiuiColors.orange,
                    ),
                  )
                else
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 5,
                    height: 5,
                    decoration: BoxDecoration(
                      color: isToday && !isSelected
                          ? MiuiColors.primary
                          : Colors.transparent,
                      shape: BoxShape.circle,
                    ),
                  ),
              ],
            ),
          ),
        );
      }),
    );
  }
}

// ─── Stat Content ───
class _StatContent extends StatelessWidget {
  final String label;
  final String value;
  final String unit;
  final Color color;
  final AppColors colors;
  const _StatContent({
    required this.label,
    required this.value,
    required this.unit,
    required this.color,
    required this.colors,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: colors.textSecondary,
            fontWeight: FontWeight.w400,
          ),
        ),
        const SizedBox(height: 10),
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(
              value,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w800,
                color: color,
                height: 1.0,
                letterSpacing: -0.5,
              ),
            ),
            if (unit.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(left: 3),
                child: Text(
                  unit,
                  style: TextStyle(
                    fontSize: 12,
                    color: color.withValues(alpha: 0.5),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

// ─── Schedule Card Wrapper ───
class _ScheduleCardWrapper extends StatelessWidget {
  final ScheduleEvent event;
  final AppColors colors;
  final bool isGlass;
  final double cardRadius;
  final int index;

  const _ScheduleCardWrapper({
    required this.event,
    required this.colors,
    required this.isGlass,
    required this.cardRadius,
    required this.index,
  });

  @override
  Widget build(BuildContext context) {
    final provider = context.read<AppProvider>();
    return Padding(
      padding: const EdgeInsets.only(bottom: Breathing.cardGap),
      child: _ScheduleCard(
        event: event,
        colors: colors,
        isGlass: isGlass,
        cardRadius: cardRadius,
        onTap: () {
          if (!AuthService().requireLogin(context, action: '完成日程打卡')) {
            return;
          }
          final wasCompleted = event.isCompleted;
          provider.toggleEvent(event.id);
          if (!wasCompleted) {
            ReminderService.instance.onEventToggled(context, event, true);
          }
        },
        onDelete: () {
          if (!AuthService().requireLogin(context, action: '删除日程')) {
            return;
          }
          provider.removeEvent(event.id);
        },
      ),
    );
  }
}

// ─── Schedule Card ───
class _ScheduleCard extends StatelessWidget {
  final ScheduleEvent event;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  final AppColors colors;
  final bool isGlass;
  final double cardRadius;

  const _ScheduleCard({
    required this.event,
    required this.onTap,
    required this.onDelete,
    required this.colors,
    required this.isGlass,
    required this.cardRadius,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      onLongPress: () => _showDeleteDialog(context),
      child: GlassCard(
        enabled: isGlass && !event.isCompleted,
        borderRadius: cardRadius,
        child: Row(
          children: [
            SizedBox(
              width: 52,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    event.time,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: event.isCompleted
                          ? colors.textTertiary
                          : colors.textPrimary,
                      letterSpacing: -0.3,
                    ),
                  ),
                  const SizedBox(height: 3),
                  if (event.endTime.isNotEmpty)
                    Text(
                      event.endTime,
                      style: TextStyle(
                        fontSize: 11,
                        color: colors.textTertiary,
                      ),
                    ),
                ],
              ),
            ),
            Container(
              width: 28,
              alignment: Alignment.center,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                width: event.isCompleted ? 10 : 8,
                height: event.isCompleted ? 10 : 8,
                decoration: BoxDecoration(
                  color: event.isCompleted
                      ? MiuiColors.green
                      : event.accentColor.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                  border: event.isCompleted
                      ? null
                      : Border.all(color: event.accentColor, width: 2),
                ),
                child: event.isCompleted
                    ? const Icon(Icons.check, size: 7, color: Colors.white)
                    : null,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    event.title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: event.isCompleted
                          ? colors.textTertiary
                          : colors.textPrimary,
                      decoration: event.isCompleted
                          ? TextDecoration.lineThrough
                          : null,
                      decorationColor: colors.textTertiary,
                      letterSpacing: -0.2,
                    ),
                  ),
                  if (event.description.isNotEmpty) ...[
                    const SizedBox(height: 5),
                    Text(
                      event.description,
                      style: TextStyle(
                        fontSize: 13,
                        color: event.isCompleted
                            ? colors.textTertiary
                            : colors.textSecondary,
                        fontWeight: FontWeight.w400,
                        height: 1.3,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: event.isCompleted
                    ? colors.surface
                    : event.accentColor.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                event.category,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: event.isCompleted
                      ? colors.textTertiary
                      : event.accentColor,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showDeleteDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: colors.card,
        title: Text(
          '删除日程',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: colors.textPrimary,
          ),
        ),
        content: Text(
          '确定删除「${event.title}」？',
          style: TextStyle(fontSize: 14, color: colors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('取消', style: TextStyle(color: colors.textSecondary)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              onDelete();
            },
            child: const Text(
              '删除',
              style: TextStyle(
                color: Color(0xFFFF3B30),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
