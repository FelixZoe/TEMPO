import { useEffect, useMemo, useRef, useState } from 'react';
import {
  Animated, FlatList, Keyboard, PanResponder, Pressable, StyleSheet, Text, TextInput, View,
} from 'react-native';

import { ActionRow, ActionSheet, NativeChromeGap, PrimaryButton, Screen, Sheet } from '../components/Primitives';
import { radius, type TempoTheme } from '../theme';
import type { TempoTask } from '../types';

type Props = {
  route: 'inbox' | 'today'; theme: TempoTheme; tasks: TempoTask[]; quote?: string;
  command?: string; consumeCommand: () => void;
  perform: <T>(action: string, payload?: Record<string, unknown>) => Promise<T>;
};

export function TasksScreen({ route, theme, tasks, quote, command, consumeCommand, perform }: Props) {
  const [composerVisible, setComposerVisible] = useState(false);
  const [optionsVisible, setOptionsVisible] = useState(false);
  const [editing, setEditing] = useState<TempoTask>();
  const [draftTitle, setDraftTitle] = useState('');
  const [draftNotes, setDraftNotes] = useState('');
  const [query, setQuery] = useState('');
  const [showCompleted, setShowCompleted] = useState(true);
  const [undo, setUndo] = useState<TempoTask>();
  const [selectedDate, setSelectedDate] = useState(new Date());
  const searchRef = useRef<TextInput>(null);
  const calendar = useRef(new Animated.Value(0)).current;
  const expanded = useRef(false);
  const listAtTop = useRef(true);

  useEffect(() => {
    if (command === 'search') searchRef.current?.focus();
    if (command === 'options') setOptionsVisible(true);
    if (command) consumeCommand();
  }, [command, consumeCommand]);

  useEffect(() => {
    if (!undo) return;
    const timer = setTimeout(() => setUndo(undefined), 4200);
    return () => clearTimeout(timer);
  }, [undo]);

  const pan = useMemo(() => PanResponder.create({
    onMoveShouldSetPanResponder: (_, gesture) => route === 'today' && listAtTop.current && Math.abs(gesture.dy) > 6 && Math.abs(gesture.dy) > Math.abs(gesture.dx),
    onPanResponderMove: (_, gesture) => calendar.setValue(Math.max(0, Math.min(1, (expanded.current ? 1 : 0) + gesture.dy / 220))),
    onPanResponderRelease: (_, gesture) => {
      const target = gesture.vy > .25 || gesture.dy > 70 ? 1 : gesture.vy < -.25 || gesture.dy < -70 ? 0 : expanded.current ? 1 : 0;
      expanded.current = target === 1;
      Animated.spring(calendar, { toValue: target, useNativeDriver: false, stiffness: 190, damping: 25, mass: .8 }).start();
    },
  }), [calendar, route]);

  const scoped = useMemo(() => tasks
    .filter((task) => task.status !== 'cancelled')
    .filter((task) => route === 'inbox' ? !task.startAt : sameDay(task.startAt, selectedDate)),
  [tasks, route, selectedDate]);

  const shown = useMemo(() => scoped
    .filter((task) => showCompleted || task.status !== 'completed')
    .filter((task) => `${task.title} ${task.notes}`.toLowerCase().includes(query.trim().toLowerCase()))
    .sort((a, b) => Number(a.status === 'completed') - Number(b.status === 'completed') || a.createdAt.localeCompare(b.createdAt)),
  [scoped, showCompleted, query]);

  const completedCount = scoped.filter((task) => task.status === 'completed').length;
  const openCount = scoped.length - completedCount;

  function openComposer(task?: TempoTask) {
    setEditing(task);
    setDraftTitle(task?.title ?? '');
    setDraftNotes(task?.notes ?? '');
    setComposerVisible(true);
  }

  function closeComposer() {
    Keyboard.dismiss();
    setTimeout(() => setComposerVisible(false), 80);
  }

  async function saveTask() {
    const title = draftTitle.trim();
    if (!title) return;
    if (editing) {
      await perform('task.update', { id: editing.id, title, notes: draftNotes.trim() });
    } else {
      await perform('task.add', {
        title,
        notes: draftNotes.trim(),
        forToday: route === 'today',
        scheduledAt: route === 'today' ? selectedDate.toISOString() : undefined,
      });
    }
    setDraftTitle('');
    setDraftNotes('');
    setEditing(undefined);
    setComposerVisible(false);
  }

  async function remove(task: TempoTask) {
    await perform('task.delete', { id: task.id });
    setUndo(task);
  }

  function runOption(action: () => void) {
    setOptionsVisible(false);
    setTimeout(action, 160);
  }

  return (
    <Screen theme={theme}>
      <View style={styles.flex} {...pan.panHandlers}>
        <NativeChromeGap />
        <View style={styles.heading}>
          <Text style={[styles.title, { color: theme.text }]}>{route === 'today' ? greeting() : '收集箱'}</Text>
          <Text style={[styles.subtitle, { color: theme.secondary }]}>
            {route === 'today' ? fullDate(selectedDate) : openCount ? `${openCount} 项待整理` : '随手记下，稍后安排'}
            {completedCount ? ` · ${completedCount} 项已完成` : ''}
          </Text>
        </View>

        <View style={[styles.search, { backgroundColor: theme.surfaceMuted }]}>
          <TextInput
            ref={searchRef}
            value={query}
            onChangeText={setQuery}
            placeholder={route === 'inbox' ? '搜索收集箱' : '搜索这一天'}
            placeholderTextColor={theme.secondary}
            returnKeyType="search"
            clearButtonMode="while-editing"
            style={[styles.searchInput, { color: theme.text }]}
          />
          {query ? <Pressable onPress={() => setQuery('')} hitSlop={10}><Text style={[styles.clear, { color: theme.secondary }]}>×</Text></Pressable> : null}
        </View>

        {route === 'today' ? <CalendarStrip theme={theme} selected={selectedDate} onSelect={setSelectedDate} progress={calendar} /> : null}

        <View style={[styles.listPanel, { backgroundColor: theme.surface }]}>
          <FlatList
            data={shown}
            keyExtractor={(item) => item.id}
            keyboardDismissMode="on-drag"
            keyboardShouldPersistTaps="handled"
            onScroll={(event) => { listAtTop.current = event.nativeEvent.contentOffset.y <= 1; }}
            scrollEventThrottle={16}
            ListHeaderComponent={shown.length ? (
              <View style={styles.groupHeader}>
                <Text style={[styles.groupTitle, { color: theme.text }]}>{route === 'today' ? dayTitle(selectedDate) : query ? '搜索结果' : '待整理'}</Text>
                <Text style={[styles.groupCount, { color: theme.secondary }]}>{shown.length}</Text>
              </View>
            ) : null}
            ListFooterComponent={route === 'inbox' && quote ? <Text style={[styles.quote, { color: theme.secondary }]}>“{quote}”</Text> : null}
            ListEmptyComponent={<EmptyState theme={theme} route={route} searching={!!query} />}
            renderItem={({ item, index }) => (
              <TaskRow
                theme={theme}
                task={item}
                separated={index < shown.length - 1}
                onOpen={() => openComposer(item)}
                onToggle={() => perform('task.toggle', { id: item.id })}
                onDelete={() => remove(item)}
                onReschedule={(date) => perform('task.update', { id: item.id, scheduledAt: date })}
              />
            )}
            contentContainerStyle={shown.length ? styles.listContent : styles.emptyContent}
          />
        </View>

        <Pressable onPress={() => openComposer()} style={({ pressed }) => [styles.fab, { backgroundColor: theme.accent, opacity: pressed ? .78 : 1 }]}>
          <Text style={styles.plus}>＋</Text>
        </Pressable>

        {undo ? (
          <Pressable onPress={() => { perform('task.restore', { id: undo.id }); setUndo(undefined); }} style={[styles.undo, { backgroundColor: theme.text }]}>
            <Text style={{ color: theme.background, fontWeight: '700' }}>↶  撤销删除</Text>
          </Pressable>
        ) : null}
      </View>

      <ActionSheet visible={optionsVisible} onClose={() => setOptionsVisible(false)} theme={theme} title={route === 'inbox' ? '收集箱选项' : '今天选项'}>
        <ActionRow theme={theme} title="新建任务" detail={route === 'today' ? `安排到${dayTitle(selectedDate)}` : '先记录，稍后安排'} onPress={() => runOption(() => openComposer())} />
        <ActionRow theme={theme} title={showCompleted ? '隐藏已完成任务' : '显示已完成任务'} detail={completedCount ? `${completedCount} 项已完成` : '当前没有已完成任务'} onPress={() => runOption(() => setShowCompleted((value) => !value))} />
        {query ? <ActionRow theme={theme} title="清除搜索" detail={`当前关键词：${query}`} onPress={() => runOption(() => setQuery(''))} /> : null}
        {route === 'today' && !sameDay(selectedDate, new Date()) ? <ActionRow theme={theme} title="回到今天" onPress={() => runOption(() => setSelectedDate(new Date()))} /> : null}
      </ActionSheet>

      <Sheet visible={composerVisible} onClose={closeComposer} theme={theme}>
        <View style={styles.sheetBody}>
          <Text style={[styles.sheetTitle, { color: theme.text }]}>{editing ? '编辑任务' : route === 'today' ? '安排任务' : '记到收集箱'}</Text>
          <TextInput
            autoFocus
            value={draftTitle}
            onChangeText={setDraftTitle}
            onSubmitEditing={saveTask}
            returnKeyType="next"
            placeholder="准备做什么？"
            placeholderTextColor={theme.tertiary}
            style={[styles.titleInput, { color: theme.text, backgroundColor: theme.surface }]}
          />
          <TextInput
            value={draftNotes}
            onChangeText={setDraftNotes}
            placeholder="补充说明（可选）"
            placeholderTextColor={theme.tertiary}
            multiline
            textAlignVertical="top"
            style={[styles.notesInput, { color: theme.text, backgroundColor: theme.surface }]}
          />
          <Text style={[styles.destination, { color: theme.secondary }]}>{route === 'today' ? `将安排到 ${fullDate(selectedDate)}` : '保存后留在收集箱，之后再安排日期'}</Text>
          <PrimaryButton theme={theme} label={editing ? '保存修改' : '添加任务'} onPress={saveTask} disabled={!draftTitle.trim()} />
        </View>
      </Sheet>
    </Screen>
  );
}

function CalendarStrip({ theme, selected, onSelect, progress }: { theme: TempoTheme; selected: Date; onSelect: (date: Date) => void; progress: Animated.Value }) {
  const days = useMemo(() => {
    const today = new Date(); const weekday = (today.getDay() + 6) % 7; const monday = addDays(today, -weekday);
    return Array.from({ length: 35 }, (_, index) => addDays(monday, index - 14));
  }, []);
  const height = progress.interpolate({ inputRange: [0, 1], outputRange: [78, 278] });
  const visible = progress.interpolate({ inputRange: [0, .18, 1], outputRange: [0, 0, 1] });
  return (
    <Animated.View style={[styles.calendar, { height }]}>
      <View style={styles.weekRow}>{days.slice(14, 21).map((date) => <DateCell key={date.toISOString()} date={date} selected={sameDay(date, selected)} theme={theme} onPress={() => onSelect(date)} />)}</View>
      <Animated.View style={{ opacity: visible }}>{[0, 1, 2, 3].map((row) => <View key={row} style={styles.weekRow}>{days.slice(row * 7, row * 7 + 7).map((date) => <DateCell key={date.toISOString()} date={date} selected={sameDay(date, selected)} theme={theme} onPress={() => onSelect(date)} />)}</View>)}</Animated.View>
    </Animated.View>
  );
}

function DateCell({ date, selected, theme, onPress }: { date: Date; selected: boolean; theme: TempoTheme; onPress: () => void }) {
  return <Pressable onPress={onPress} style={({ pressed }) => [styles.dateCell, pressed && { opacity: .55 }]}><Text style={[styles.weekday, { color: theme.secondary }]}>{'一二三四五六日'[(date.getDay() + 6) % 7]}</Text><View style={[styles.dateDot, selected && { backgroundColor: theme.accent }]}><Text style={[styles.dateNumber, { color: selected ? '#fff' : theme.text }]}>{date.getDate()}</Text></View></Pressable>;
}

function TaskRow({ task, theme, separated, onOpen, onToggle, onDelete, onReschedule }: { task: TempoTask; theme: TempoTheme; separated: boolean; onOpen: () => void; onToggle: () => void; onDelete: () => void; onReschedule: (date?: string) => void }) {
  const x = useRef(new Animated.Value(0)).current;
  const pan = useMemo(() => PanResponder.create({
    onMoveShouldSetPanResponder: (_, gesture) => Math.abs(gesture.dx) > 10 && Math.abs(gesture.dx) > Math.abs(gesture.dy),
    onPanResponderMove: (_, gesture) => x.setValue(Math.max(-148, Math.min(0, gesture.dx))),
    onPanResponderRelease: (_, gesture) => Animated.spring(x, { toValue: gesture.dx < -62 ? -148 : 0, useNativeDriver: true, stiffness: 240, damping: 25 }).start(),
  }), [x]);
  return (
    <View style={styles.swipeWrap}>
      <View style={styles.actions}>
        <Pressable onPress={() => onReschedule(addDays(new Date(), 1).toISOString())} style={[styles.action, { backgroundColor: theme.accent }]}><Text style={styles.actionText}>明天</Text></Pressable>
        <Pressable onPress={onDelete} style={[styles.action, { backgroundColor: theme.danger }]}><Text style={styles.actionText}>删除</Text></Pressable>
      </View>
      <Animated.View {...pan.panHandlers} style={[styles.taskRow, { backgroundColor: theme.surface, transform: [{ translateX: x }] }]}>
        <Pressable onPress={onToggle} hitSlop={8} style={[styles.checkbox, { borderColor: task.status === 'completed' ? theme.success : theme.secondary, backgroundColor: task.status === 'completed' ? theme.success : 'transparent' }]}>{task.status === 'completed' ? <Text style={styles.check}>✓</Text> : null}</Pressable>
        <Pressable onPress={onOpen} style={({ pressed }) => [styles.taskMain, pressed && { opacity: .58 }]}>
          <View style={styles.taskText}>
            <Text numberOfLines={2} style={[styles.taskTitle, { color: task.status === 'completed' ? theme.secondary : theme.text, textDecorationLine: task.status === 'completed' ? 'line-through' : 'none' }]}>{task.title}</Text>
            {task.notes ? <Text numberOfLines={2} style={[styles.taskNotes, { color: theme.secondary }]}>{task.notes}</Text> : null}
          </View>
          {task.startAt ? <Text style={[styles.taskDate, { color: theme.secondary }]}>{sameDay(task.startAt, new Date()) ? '今天' : shortDate(task.startAt)}</Text> : null}
          <Text style={[styles.rowChevron, { color: theme.tertiary }]}>›</Text>
        </Pressable>
        {separated ? <View style={[styles.rowDivider, { backgroundColor: theme.separator }]} /> : null}
      </Animated.View>
    </View>
  );
}

function EmptyState({ theme, route, searching }: { theme: TempoTheme; route: string; searching: boolean }) {
  return <View style={styles.empty}><Text style={[styles.emptyIcon, { color: theme.tertiary }]}>{searching ? '⌕' : '✓'}</Text><Text style={[styles.emptyTitle, { color: theme.text }]}>{searching ? '没有匹配的任务' : route === 'today' ? '这一天没有任务' : '收集箱已经清空'}</Text><Text style={[styles.emptyBody, { color: theme.secondary }]}>{searching ? '换个关键词试试' : route === 'today' ? '留一点时间给自己' : '想到什么就先记下来'}</Text></View>;
}

function sameDay(value: string | Date | null | undefined, compare: Date) { if (!value) return false; const date = typeof value === 'string' ? new Date(value) : value; return date.getFullYear() === compare.getFullYear() && date.getMonth() === compare.getMonth() && date.getDate() === compare.getDate(); }
function addDays(date: Date, count: number) { const result = new Date(date); result.setDate(result.getDate() + count); return result; }
function dayTitle(date: Date) { const today = new Date(); if (sameDay(date, today)) return '今天'; if (sameDay(date, addDays(today, -1))) return '昨天'; if (sameDay(date, addDays(today, 1))) return '明天'; return `${date.getMonth() + 1}月${date.getDate()}日`; }
function greeting() { const hour = new Date().getHours(); return hour < 12 ? '早上好' : hour < 18 ? '下午好' : '晚上好'; }
function fullDate(date: Date) { const weekdays = ['星期日', '星期一', '星期二', '星期三', '星期四', '星期五', '星期六']; return `${date.getMonth() + 1}月${date.getDate()}日  ${weekdays[date.getDay()]}`; }
function shortDate(value: string) { const date = new Date(value); return `${date.getMonth() + 1}/${date.getDate()}`; }

const styles = StyleSheet.create({
  flex: { flex: 1 },
  heading: { paddingHorizontal: 20, paddingTop: 6, paddingBottom: 14 },
  title: { fontSize: 32, fontWeight: '700', letterSpacing: -.8 },
  subtitle: { fontSize: 14, lineHeight: 20, marginTop: 6 },
  search: { marginHorizontal: 20, height: 44, borderRadius: 14, paddingHorizontal: 14, flexDirection: 'row', alignItems: 'center' },
  searchInput: { flex: 1, fontSize: 16, paddingVertical: 0 },
  clear: { fontSize: 24, fontWeight: '300', paddingLeft: 10 },
  calendar: { overflow: 'hidden', paddingHorizontal: 16 },
  weekRow: { height: 66, flexDirection: 'row' },
  dateCell: { flex: 1, alignItems: 'center', justifyContent: 'center' },
  weekday: { fontSize: 11, marginBottom: 4 },
  dateDot: { width: 38, height: 38, borderRadius: 19, alignItems: 'center', justifyContent: 'center' },
  dateNumber: { fontSize: 16, fontWeight: '600' },
  listPanel: { flex: 1, marginHorizontal: 20, marginTop: 14, borderRadius: radius.large, overflow: 'hidden' },
  listContent: { paddingBottom: 112 },
  emptyContent: { flexGrow: 1 },
  groupHeader: { height: 54, flexDirection: 'row', alignItems: 'center', paddingHorizontal: 18 },
  groupTitle: { flex: 1, fontSize: 19, fontWeight: '700', letterSpacing: -.3 },
  groupCount: { fontSize: 13, fontWeight: '600' },
  swipeWrap: { minHeight: 72, overflow: 'hidden' },
  actions: { ...StyleSheet.absoluteFill, flexDirection: 'row', justifyContent: 'flex-end' },
  action: { width: 74, justifyContent: 'center', alignItems: 'center' },
  actionText: { color: '#fff', fontWeight: '600' },
  taskRow: { minHeight: 72, flexDirection: 'row', alignItems: 'center', paddingLeft: 16 },
  checkbox: { width: 24, height: 24, borderWidth: 1.6, borderRadius: 7, alignItems: 'center', justifyContent: 'center', marginRight: 13 },
  check: { color: '#fff', fontWeight: '800' },
  taskMain: { minHeight: 72, flex: 1, flexDirection: 'row', alignItems: 'center', paddingRight: 14 },
  taskText: { flex: 1, paddingVertical: 12 },
  taskTitle: { fontSize: 17, fontWeight: '500', lineHeight: 22 },
  taskNotes: { fontSize: 13, lineHeight: 18, marginTop: 3 },
  taskDate: { fontSize: 12, fontWeight: '500', marginLeft: 10 },
  rowChevron: { fontSize: 23, fontWeight: '300', marginLeft: 8 },
  rowDivider: { position: 'absolute', height: StyleSheet.hairlineWidth, left: 53, right: 0, bottom: 0 },
  quote: { fontSize: 13, lineHeight: 20, fontStyle: 'italic', paddingHorizontal: 20, paddingTop: 28, paddingBottom: 24 },
  empty: { flex: 1, alignItems: 'center', justifyContent: 'center', paddingBottom: 46 },
  emptyIcon: { fontSize: 46, fontWeight: '200' },
  emptyTitle: { fontSize: 19, fontWeight: '600', marginTop: 12 },
  emptyBody: { fontSize: 14, marginTop: 6 },
  fab: { position: 'absolute', right: 20, bottom: 18, width: 54, height: 54, borderRadius: 27, alignItems: 'center', justifyContent: 'center', shadowColor: '#000', shadowOpacity: .12, shadowRadius: 18, shadowOffset: { width: 0, height: 8 } },
  plus: { color: '#fff', fontSize: 29, lineHeight: 33, fontWeight: '300' },
  undo: { position: 'absolute', left: 20, bottom: 23, borderRadius: 20, paddingHorizontal: 16, height: 42, justifyContent: 'center' },
  sheetBody: { flex: 1, paddingTop: 18 },
  sheetTitle: { fontSize: 28, fontWeight: '700', paddingHorizontal: 20, marginBottom: 20 },
  titleInput: { marginHorizontal: 20, height: 58, borderRadius: 16, paddingHorizontal: 16, fontSize: 17 },
  notesInput: { marginHorizontal: 20, minHeight: 112, borderRadius: 16, padding: 16, fontSize: 15, lineHeight: 21, marginTop: 12 },
  destination: { fontSize: 13, lineHeight: 18, marginHorizontal: 22, marginTop: 12, marginBottom: 20 },
});
