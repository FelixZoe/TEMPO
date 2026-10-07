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
          <Text style={[styles.title, { color: theme.text }]}>{route === 'today' ? greeting() : '收集箱'}</Text>
          <Text style={[styles.eyebrow, { color: theme.secondary }]}>{route === 'today' ? fullDate(selectedDate) : '快速记录，稍后整理'}</Text>
          {route === 'inbox' && quote ? <Text numberOfLines={2} style={[styles.quote, { color: theme.secondary }]}>“{quote}”</Text> : null}
        </View>
        {searching ? (
          <View style={[styles.search, { backgroundColor: theme.surfaceMuted }]}>
            <TextInput autoFocus value={query} onChangeText={setQuery} placeholder="搜索任务" placeholderTextColor={theme.tertiary} style={[styles.searchInput, { color: theme.text }]} />
            <Pressable onPress={() => { setQuery(''); setSearching(false); }}><Text style={{ color: theme.accent }}>取消</Text></Pressable>
          </View>
        ) : null}
        {route === 'today' ? <CalendarStrip theme={theme} selected={selectedDate} onSelect={setSelectedDate} progress={calendar} /> : null}
        <View style={[styles.listPanel, route === 'inbox' ? styles.inboxListPanel : { backgroundColor: theme.surface }]}>
          <FlatList
            data={shown}
            keyExtractor={(item) => item.id}
            onScroll={(event) => { listAtTop.current = event.nativeEvent.contentOffset.y <= 1; }}
            scrollEventThrottle={16}
            ListHeaderComponent={shown.length ? <Text style={[styles.groupTitle, { color: theme.secondary }]}>{route === 'today' ? dayTitle(selectedDate) : '待整理'}</Text> : null}
            ListEmptyComponent={<EmptyState theme={theme} route={route} />}
            renderItem={({ item }) => <TaskRow theme={theme} task={item} card={route === 'inbox'} onToggle={() => perform('task.toggle', { id: item.id })} onDelete={() => remove(item)} onReschedule={(date) => perform('task.update', { id: item.id, scheduledAt: date })} />}
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

function TaskRow({ task, theme, card, onToggle, onDelete, onReschedule }: { task: TempoTask; theme: TempoTheme; card: boolean; onToggle: () => void; onDelete: () => void; onReschedule: (date?: string) => void }) {
  const x = useRef(new Animated.Value(0)).current;
  const pan = useMemo(() => PanResponder.create({
    onMoveShouldSetPanResponder: (_, gesture) => Math.abs(gesture.dx) > 10 && Math.abs(gesture.dx) > Math.abs(gesture.dy),
    onPanResponderMove: (_, gesture) => x.setValue(Math.max(-154, Math.min(0, gesture.dx))),
    onPanResponderRelease: (_, gesture) => Animated.spring(x, { toValue: gesture.dx < -64 ? -154 : 0, useNativeDriver: true, stiffness: 240, damping: 25 }).start(),
  }), [x]);
  return (
    <View style={[styles.swipeWrap, card && styles.cardWrap]}>
      <View style={styles.actions}>
        <Pressable onPress={() => onReschedule(addDays(new Date(), 1).toISOString())} style={[styles.action, { backgroundColor: theme.accent }]}><Text style={styles.actionText}>明天</Text></Pressable>
        <Pressable onPress={onDelete} style={[styles.action, { backgroundColor: theme.danger }]}><Text style={styles.actionText}>删除</Text></Pressable>
      </View>
      <Animated.View {...pan.panHandlers} style={[styles.taskRow, card && styles.cardRow, { backgroundColor: theme.surface, transform: [{ translateX: x }] }]}>
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
function greeting() { const hour = new Date().getHours(); return hour < 12 ? '早上好' : hour < 18 ? '下午好' : '晚上好'; }
function fullDate(date: Date) { const weekdays = ['星期日', '星期一', '星期二', '星期三', '星期四', '星期五', '星期六']; return `${date.getMonth() + 1}月${date.getDate()}日  ${weekdays[date.getDay()]}`; }
function shortDate(value: string) { const date = new Date(value); return `${date.getMonth() + 1}/${date.getDate()}`; }

const styles = StyleSheet.create({
  flex: { flex: 1 }, heading: { paddingHorizontal: 20, paddingTop: 6, paddingBottom: 12 }, eyebrow: { fontSize: 15, fontWeight: '400', marginTop: 7 }, title: { fontSize: 32, fontWeight: '700', letterSpacing: -.8 }, quote: { fontSize: 13, lineHeight: 19, marginTop: 10, maxWidth: '88%', fontStyle: 'italic' },
  search: { marginHorizontal: 20, height: 44, borderRadius: 14, paddingHorizontal: 14, flexDirection: 'row', alignItems: 'center', gap: 12 }, searchInput: { flex: 1, fontSize: 16 },
  calendar: { overflow: 'hidden', paddingHorizontal: 16 }, weekRow: { height: 68, flexDirection: 'row' }, dateCell: { flex: 1, alignItems: 'center', justifyContent: 'center' }, weekday: { fontSize: 11, marginBottom: 4 }, dateDot: { width: 38, height: 38, borderRadius: 19, alignItems: 'center', justifyContent: 'center' }, dateNumber: { fontSize: 16, fontWeight: '600' },
  listPanel: { flex: 1, marginHorizontal: 20, borderRadius: radius.large, overflow: 'hidden' }, inboxListPanel: { marginHorizontal: 15, borderRadius: 0, overflow: 'visible' }, listContent: { paddingTop: 8, paddingBottom: 120 }, emptyContent: { flexGrow: 1 }, groupTitle: { fontSize: 13, fontWeight: '600', paddingHorizontal: 6, paddingVertical: 10 },
  swipeWrap: { minHeight: 66, overflow: 'hidden' }, cardWrap: { marginHorizontal: 5, marginVertical: 5, borderRadius: 18 }, actions: { ...StyleSheet.absoluteFill, flexDirection: 'row', justifyContent: 'flex-end' }, action: { width: 74, justifyContent: 'center', alignItems: 'center' }, actionText: { color: '#fff', fontWeight: '600' },
  taskRow: { minHeight: 66, flexDirection: 'row', alignItems: 'center', paddingHorizontal: 14, paddingVertical: 12 }, cardRow: { borderRadius: 18 }, checkbox: { width: 24, height: 24, borderWidth: 1.6, borderRadius: 6, alignItems: 'center', justifyContent: 'center', marginRight: 13 }, check: { color: '#fff', fontWeight: '800' }, taskText: { flex: 1 }, taskTitle: { fontSize: 17, fontWeight: '500', lineHeight: 22 }, taskNotes: { fontSize: 13, lineHeight: 18, marginTop: 3 }, taskDate: { fontSize: 12, fontWeight: '500', marginLeft: 10 },
  empty: { flex: 1, alignItems: 'center', justifyContent: 'center', paddingBottom: 64 }, emptyIcon: { fontSize: 48, fontWeight: '200' }, emptyTitle: { fontSize: 19, fontWeight: '600', marginTop: 12 }, emptyBody: { fontSize: 15, marginTop: 6 },
  fab: { position: 'absolute', right: 20, bottom: 18, width: 54, height: 54, borderRadius: 27, alignItems: 'center', justifyContent: 'center', shadowColor: '#000', shadowOpacity: .12, shadowRadius: 18, shadowOffset: { width: 0, height: 8 } }, plus: { color: '#fff', fontSize: 29, lineHeight: 33, fontWeight: '300' }, undo: { position: 'absolute', left: 20, bottom: 23, borderRadius: 20, paddingHorizontal: 16, height: 42, justifyContent: 'center' },
  sheetBody: { flex: 1, paddingTop: 18 }, sheetTitle: { fontSize: 28, fontWeight: '700', paddingHorizontal: 22, marginBottom: 20 }, editor: { marginHorizontal: 20, minHeight: 58, borderRadius: radius.medium, paddingHorizontal: 16, fontSize: 17, marginBottom: 18 },
});
