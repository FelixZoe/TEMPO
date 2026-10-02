import { useEffect, useMemo, useRef, useState } from 'react';
import {
  Animated, FlatList, Keyboard, PanResponder, Pressable, StyleSheet, Text, TextInput, View,
} from 'react-native';

import { NativeChromeGap, PrimaryButton, Screen, Sheet } from '../components/Primitives';
import { radius, type TempoTheme } from '../theme';
import type { TempoTask } from '../types';

type Props = {
  route: 'inbox' | 'today'; theme: TempoTheme; tasks: TempoTask[]; quote?: string;
  command?: string; consumeCommand: () => void;
  perform: <T>(action: string, payload?: Record<string, unknown>) => Promise<T>;
};

export function TasksScreen({ route, theme, tasks, quote, command, consumeCommand, perform }: Props) {
  const [adding, setAdding] = useState(false);
  const [title, setTitle] = useState('');
  const [searching, setSearching] = useState(false);
  const [query, setQuery] = useState('');
  const [undo, setUndo] = useState<TempoTask>();
  const [selectedDate, setSelectedDate] = useState(new Date());
  const calendar = useRef(new Animated.Value(0)).current;
  const expanded = useRef(false);
  const listAtTop = useRef(true);

  useEffect(() => {
    if (command === 'search') setSearching(true);
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

  const shown = useMemo(() => tasks
    .filter((task) => task.status !== 'cancelled')
    .filter((task) => route === 'inbox' ? !task.startAt : sameDay(task.startAt, selectedDate))
    .filter((task) => task.title.toLowerCase().includes(query.trim().toLowerCase()))
    .sort((a, b) => Number(a.status === 'completed') - Number(b.status === 'completed') || a.createdAt.localeCompare(b.createdAt)),
  [tasks, route, selectedDate, query]);

  async function addTask() {
    const clean = title.trim();
    if (!clean) return;
    await perform('task.add', { title: clean, forToday: route === 'today', scheduledAt: route === 'today' ? selectedDate.toISOString() : undefined });
    setTitle('');
    setAdding(false);
  }

  async function remove(task: TempoTask) {
    await perform('task.delete', { id: task.id });
    setUndo(task);
  }

  return (
    <Screen theme={theme}>
      <View style={styles.flex} {...pan.panHandlers}>
        <NativeChromeGap />
        <View style={styles.heading}>
          <Text style={[styles.eyebrow, { color: theme.secondary }]}>{route === 'today' ? monthLabel(selectedDate) : '快速记录，稍后整理'}</Text>
          <Text style={[styles.title, { color: theme.text }]}>{route === 'today' ? dayTitle(selectedDate) : '收集箱'}</Text>
          {route === 'inbox' && quote ? <Text numberOfLines={2} style={[styles.quote, { color: theme.secondary }]}>“{quote}”</Text> : null}
        </View>
        {searching ? (
          <View style={[styles.search, { backgroundColor: theme.surfaceMuted }]}>
            <TextInput autoFocus value={query} onChangeText={setQuery} placeholder="搜索任务" placeholderTextColor={theme.tertiary} style={[styles.searchInput, { color: theme.text }]} />
            <Pressable onPress={() => { setQuery(''); setSearching(false); }}><Text style={{ color: theme.accent }}>取消</Text></Pressable>
          </View>
        ) : null}
        {route === 'today' ? <CalendarStrip theme={theme} selected={selectedDate} onSelect={setSelectedDate} progress={calendar} /> : null}
        <View style={[styles.listPanel, { backgroundColor: theme.surface }]}>
          <FlatList
            data={shown}
            keyExtractor={(item) => item.id}
            onScroll={(event) => { listAtTop.current = event.nativeEvent.contentOffset.y <= 1; }}
            scrollEventThrottle={16}
            ListHeaderComponent={shown.length ? <Text style={[styles.groupTitle, { color: theme.secondary }]}>{route === 'today' ? dayTitle(selectedDate) : '待整理'}</Text> : null}
            ListEmptyComponent={<EmptyState theme={theme} route={route} />}
            renderItem={({ item }) => <TaskRow theme={theme} task={item} onToggle={() => perform('task.toggle', { id: item.id })} onDelete={() => remove(item)} onReschedule={(date) => perform('task.update', { id: item.id, scheduledAt: date })} />}
            contentContainerStyle={shown.length ? styles.listContent : styles.emptyContent}
          />
        </View>
        <Pressable onPress={() => setAdding(true)} style={[styles.fab, { backgroundColor: theme.accent }]}><Text style={styles.plus}>＋</Text></Pressable>
        {undo ? (
          <Pressable onPress={() => { perform('task.restore', { id: undo.id }); setUndo(undefined); }} style={[styles.undo, { backgroundColor: theme.text }]}>
            <Text style={{ color: theme.background, fontWeight: '700' }}>↶  撤销删除</Text>
          </Pressable>
        ) : null}
      </View>
      <Sheet visible={adding} onClose={() => { Keyboard.dismiss(); setTimeout(() => setAdding(false), 90); }} theme={theme}>
        <View style={styles.sheetBody}>
          <Text style={[styles.sheetTitle, { color: theme.text }]}>新增任务</Text>
          <TextInput autoFocus value={title} onChangeText={setTitle} onSubmitEditing={addTask} returnKeyType="done" placeholder="准备做什么？" placeholderTextColor={theme.tertiary} style={[styles.editor, { color: theme.text, backgroundColor: theme.surface }]} />
          <PrimaryButton theme={theme} label="保存" onPress={addTask} disabled={!title.trim()} />
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
  const height = progress.interpolate({ inputRange: [0, 1], outputRange: [84, 292] });
  const visible = progress.interpolate({ inputRange: [0, .18, 1], outputRange: [0, 0, 1] });
  return (
    <Animated.View style={[styles.calendar, { height }]}>
      <View style={styles.weekRow}>{days.slice(14, 21).map((date) => <DateCell key={date.toISOString()} date={date} selected={sameDay(date, selected)} theme={theme} onPress={() => onSelect(date)} />)}</View>
      <Animated.View style={{ opacity: visible }}>{[0, 1, 2, 3].map((row) => <View key={row} style={styles.weekRow}>{days.slice(row * 7, row * 7 + 7).map((date) => <DateCell key={date.toISOString()} date={date} selected={sameDay(date, selected)} theme={theme} onPress={() => onSelect(date)} />)}</View>)}</Animated.View>
    </Animated.View>
  );
}

function DateCell({ date, selected, theme, onPress }: { date: Date; selected: boolean; theme: TempoTheme; onPress: () => void }) {
  return <Pressable onPress={onPress} style={styles.dateCell}><Text style={[styles.weekday, { color: theme.tertiary }]}>{'一二三四五六日'[(date.getDay() + 6) % 7]}</Text><View style={[styles.dateDot, selected && { backgroundColor: theme.accent }]}><Text style={[styles.dateNumber, { color: selected ? '#fff' : theme.text }]}>{date.getDate()}</Text></View></Pressable>;
}

function TaskRow({ task, theme, onToggle, onDelete, onReschedule }: { task: TempoTask; theme: TempoTheme; onToggle: () => void; onDelete: () => void; onReschedule: (date?: string) => void }) {
  const x = useRef(new Animated.Value(0)).current;
  const pan = useMemo(() => PanResponder.create({
    onMoveShouldSetPanResponder: (_, gesture) => Math.abs(gesture.dx) > 10 && Math.abs(gesture.dx) > Math.abs(gesture.dy),
    onPanResponderMove: (_, gesture) => x.setValue(Math.max(-154, Math.min(0, gesture.dx))),
    onPanResponderRelease: (_, gesture) => Animated.spring(x, { toValue: gesture.dx < -64 ? -154 : 0, useNativeDriver: true, stiffness: 240, damping: 25 }).start(),
  }), [x]);
  return (
    <View style={styles.swipeWrap}>
      <View style={styles.actions}>
        <Pressable onPress={() => onReschedule(addDays(new Date(), 1).toISOString())} style={[styles.action, { backgroundColor: theme.accent }]}><Text style={styles.actionText}>明天</Text></Pressable>
        <Pressable onPress={onDelete} style={[styles.action, { backgroundColor: theme.danger }]}><Text style={styles.actionText}>删除</Text></Pressable>
      </View>
      <Animated.View {...pan.panHandlers} style={[styles.taskRow, { backgroundColor: theme.surface, transform: [{ translateX: x }] }]}>
        <Pressable onPress={onToggle} style={[styles.checkbox, { borderColor: task.status === 'completed' ? theme.accent : theme.tertiary, backgroundColor: task.status === 'completed' ? theme.accent : 'transparent' }]}>{task.status === 'completed' ? <Text style={styles.check}>✓</Text> : null}</Pressable>
        <View style={styles.taskText}><Text numberOfLines={2} style={[styles.taskTitle, { color: task.status === 'completed' ? theme.tertiary : theme.text, textDecorationLine: task.status === 'completed' ? 'line-through' : 'none' }]}>{task.title}</Text>{task.notes ? <Text numberOfLines={1} style={[styles.taskNotes, { color: theme.secondary }]}>{task.notes}</Text> : null}</View>
        {task.startAt ? <Text style={[styles.taskDate, { color: theme.accent }]}>{sameDay(task.startAt, new Date()) ? '今天' : shortDate(task.startAt)}</Text> : null}
      </Animated.View>
    </View>
  );
}

function EmptyState({ theme, route }: { theme: TempoTheme; route: string }) { return <View style={styles.empty}><Text style={[styles.emptyIcon, { color: theme.tertiary }]}>✓</Text><Text style={[styles.emptyTitle, { color: theme.text }]}>{route === 'today' ? '这一天没有任务' : '收集箱是空的'}</Text><Text style={[styles.emptyBody, { color: theme.secondary }]}>留一点时间给自己</Text></View>; }
function sameDay(value: string | Date | null | undefined, compare: Date) { if (!value) return false; const date = typeof value === 'string' ? new Date(value) : value; return date.getFullYear() === compare.getFullYear() && date.getMonth() === compare.getMonth() && date.getDate() === compare.getDate(); }
function addDays(date: Date, count: number) { const result = new Date(date); result.setDate(result.getDate() + count); return result; }
function dayTitle(date: Date) { const today = new Date(); if (sameDay(date, today)) return '今天'; if (sameDay(date, addDays(today, -1))) return '昨天'; if (sameDay(date, addDays(today, 1))) return '明天'; return `${date.getMonth() + 1}月${date.getDate()}日`; }
function monthLabel(date: Date) { return `${date.getMonth() + 1}月`; }
function shortDate(value: string) { const date = new Date(value); return `${date.getMonth() + 1}/${date.getDate()}`; }

const styles = StyleSheet.create({
  flex: { flex: 1 }, heading: { paddingHorizontal: 24, paddingTop: 6, paddingBottom: 8 }, eyebrow: { fontSize: 13, fontWeight: '600', marginBottom: 1 }, title: { fontSize: 33, fontWeight: '800', letterSpacing: -.8 }, quote: { fontSize: 14, lineHeight: 20, marginTop: 9, maxWidth: '86%' },
  search: { marginHorizontal: 18, height: 48, borderRadius: 20, paddingHorizontal: 16, flexDirection: 'row', alignItems: 'center', gap: 12 }, searchInput: { flex: 1, fontSize: 16 },
  calendar: { overflow: 'hidden', paddingHorizontal: 12 }, weekRow: { height: 72, flexDirection: 'row' }, dateCell: { flex: 1, alignItems: 'center', justifyContent: 'center' }, weekday: { fontSize: 12, marginBottom: 3 }, dateDot: { width: 38, height: 38, borderRadius: 19, alignItems: 'center', justifyContent: 'center' }, dateNumber: { fontSize: 17, fontWeight: '700' },
  listPanel: { flex: 1, marginHorizontal: 14, borderTopLeftRadius: radius.large, borderTopRightRadius: radius.large, overflow: 'hidden' }, listContent: { paddingTop: 8, paddingBottom: 130 }, emptyContent: { flexGrow: 1 }, groupTitle: { fontSize: 14, fontWeight: '700', paddingHorizontal: 18, paddingVertical: 10 },
  swipeWrap: { minHeight: 70, overflow: 'hidden' }, actions: { ...StyleSheet.absoluteFill, flexDirection: 'row', justifyContent: 'flex-end' }, action: { width: 77, justifyContent: 'center', alignItems: 'center' }, actionText: { color: '#fff', fontWeight: '700' },
  taskRow: { minHeight: 70, flexDirection: 'row', alignItems: 'center', paddingHorizontal: 17, paddingVertical: 11 }, checkbox: { width: 27, height: 27, borderWidth: 2, borderRadius: 9, alignItems: 'center', justifyContent: 'center', marginRight: 13 }, check: { color: '#fff', fontWeight: '900' }, taskText: { flex: 1 }, taskTitle: { fontSize: 17, fontWeight: '600', lineHeight: 22 }, taskNotes: { fontSize: 13, marginTop: 2 }, taskDate: { fontSize: 13, fontWeight: '600', marginLeft: 10 },
  empty: { flex: 1, alignItems: 'center', justifyContent: 'center', paddingBottom: 72 }, emptyIcon: { fontSize: 54, fontWeight: '200' }, emptyTitle: { fontSize: 20, fontWeight: '700', marginTop: 12 }, emptyBody: { fontSize: 15, marginTop: 6 },
  fab: { position: 'absolute', right: 26, bottom: 28, width: 62, height: 62, borderRadius: 31, alignItems: 'center', justifyContent: 'center', shadowColor: '#000', shadowOpacity: .14, shadowRadius: 14, shadowOffset: { width: 0, height: 7 } }, plus: { color: '#fff', fontSize: 34, lineHeight: 38, fontWeight: '300' }, undo: { position: 'absolute', left: 24, bottom: 34, borderRadius: 22, paddingHorizontal: 17, height: 44, justifyContent: 'center' },
  sheetBody: { flex: 1, paddingTop: 16 }, sheetTitle: { fontSize: 30, fontWeight: '800', paddingHorizontal: 22, marginBottom: 20 }, editor: { marginHorizontal: 18, minHeight: 62, borderRadius: radius.medium, paddingHorizontal: 18, fontSize: 18, marginBottom: 18 },
});
