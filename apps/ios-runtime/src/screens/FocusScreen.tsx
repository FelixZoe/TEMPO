import { useEffect, useMemo, useState } from 'react';
import { Pressable, ScrollView, StyleSheet, Text, View } from 'react-native';

import { NativeChromeGap, Pill, Screen, Sheet } from '../components/Primitives';
import type { TempoTheme } from '../theme';
import type { PomodoroState, TempoCommand } from '../types';

export function FocusScreen({ theme, pomodoro, remaining, command, consumeCommand, perform }: {
  theme: TempoTheme; pomodoro?: PomodoroState; remaining: number; command?: TempoCommand; consumeCommand: () => void;
  perform: <T>(action: string, payload?: Record<string, unknown>) => Promise<T>;
}) {
  const [statistics, setStatistics] = useState(false);
  useEffect(() => {
    if (command?.type === 'statistics') setStatistics(true);
    if (command?.type === 'resetTimer') void perform('pomodoro.reset');
    if (command?.type === 'stopTimer') void perform('pomodoro.stop');
    if (command) consumeCommand();
  }, [command, consumeCommand]);
  const state = pomodoro ?? { mode: 'focus', status: 'idle', remainingSeconds: remaining, completedFocusSessions: 0, focusMinutes: 25, shortBreakMinutes: 5, longBreakMinutes: 15, longBreakEvery: 4, dailyFocusGoal: 4, timerDirection: 'countdown', focusHistory: [] } as PomodoroState;
  const totalSeconds = Math.max(1, (state.mode === 'focus' ? state.focusMinutes : state.mode === 'shortBreak' ? state.shortBreakMinutes : state.longBreakMinutes) * 60);
  const progress = state.timerDirection === 'countUp'
    ? Math.min(1, remaining / totalSeconds)
    : Math.min(1, Math.max(0, 1 - remaining / totalSeconds));
  return (
    <Screen theme={theme}>
      <NativeChromeGap />
      <View style={styles.segmentWrap}><View style={[styles.segment, { backgroundColor: theme.surfaceMuted }]}>
        <Segment label="番茄计时" selected={state.timerDirection === 'countdown'} theme={theme} onPress={() => perform('pomodoro.direction', { direction: 'countdown' })} />
        <Segment label="正计时" selected={state.timerDirection === 'countUp'} theme={theme} onPress={() => perform('pomodoro.direction', { direction: 'countUp' })} />
      </View></View>
      <View style={styles.timerBody}>
        <Pressable onPress={() => setStatistics(true)} style={({ pressed }) => pressed && styles.pressed}><Text style={[styles.mode, { color: theme.text }]}>{modeTitle(state.mode)}  <Text style={{ color: theme.tertiary }}>›</Text></Text></Pressable>
        <ProgressRing theme={theme} progress={progress}><Text style={[styles.time, { color: theme.text }]}>{formatTime(remaining)}</Text><Text style={[styles.status, { color: theme.secondary }]}>{state.status === 'running' ? '专注进行中' : state.status === 'paused' ? '已暂停' : `今日 ${state.completedFocusSessions} / ${state.dailyFocusGoal}`}</Text></ProgressRing>
        {state.status === 'idle' ? (
          <Pressable onPress={() => perform('pomodoro.toggle')} style={({ pressed }) => [styles.startButton, { backgroundColor: theme.accent, opacity: pressed ? .78 : 1 }]}><Text style={styles.startText}>开始</Text></Pressable>
        ) : (
          <View style={styles.controls}><RoundButton theme={theme} label="↶" onPress={() => perform('pomodoro.reset')} /><Pressable onPress={() => perform('pomodoro.toggle')} style={({ pressed }) => [styles.mainButton, { backgroundColor: theme.accent, opacity: pressed ? .78 : 1 }]}><Text style={styles.mainButtonText}>{state.status === 'running' ? 'Ⅱ' : '▶'}</Text></Pressable><RoundButton theme={theme} label="■" onPress={() => perform('pomodoro.stop')} /></View>
        )}
      </View>
      <Sheet visible={statistics} onClose={() => setStatistics(false)} theme={theme}>
        <ScrollView contentContainerStyle={styles.stats}>
          <Text style={[styles.statsTitle, { color: theme.text }]}>专注统计</Text>
          <View style={styles.metrics}><Metric theme={theme} label="今日番茄" value={`${state.completedFocusSessions}`} /><Metric theme={theme} label="今日目标" value={`${state.dailyFocusGoal}`} /><Metric theme={theme} label="总专注" value={`${Math.round(state.focusHistory.reduce((sum, item) => sum + item.durationSeconds, 0) / 3600)}h`} /></View>
          <Text style={[styles.heatTitle, { color: theme.text }]}>专注热力图</Text><Heatmap theme={theme} history={state.focusHistory} />
          <Text style={[styles.heatTitle, { color: theme.text }]}>时长</Text><View style={styles.pills}>{[25, 35, 45, 60].map((minutes) => <Pill key={minutes} theme={theme} label={`${minutes} 分钟`} selected={state.focusMinutes === minutes} onPress={() => perform('pomodoro.settings', { focus: minutes })} />)}</View>
          <Text style={[styles.heatTitle, { color: theme.text }]}>今日目标</Text><View style={styles.pills}>{[2, 4, 6, 8].map((count) => <Pill key={count} theme={theme} label={`${count} 个`} selected={state.dailyFocusGoal === count} onPress={() => perform('pomodoro.settings', { dailyFocusGoal: count })} />)}</View>
        </ScrollView>
      </Sheet>
    </Screen>
  );
}
function Segment({ label, selected, theme, onPress }: { label: string; selected: boolean; theme: TempoTheme; onPress: () => void }) { return <Pressable onPress={onPress} style={[styles.segmentItem, selected && { backgroundColor: theme.surface }]}><Text style={[styles.segmentText, { color: selected ? theme.text : theme.secondary }]}>{label}</Text></Pressable>; }
function ProgressRing({ theme, progress, children }: { theme: TempoTheme; progress: number; children: React.ReactNode }) { const count = 72; const active = Math.round(progress * count); return <View style={styles.ring}>{Array.from({ length: count }, (_, index) => <View key={index} style={[styles.tick, { backgroundColor: index < active ? theme.accent : theme.separator, opacity: index < active ? 1 : .52, transform: [{ rotate: `${index * (360 / count)}deg` }, { translateY: -137 }] }]} />)}<View style={styles.ringContent}>{children}</View></View>; }
function RoundButton({ theme, label, onPress }: { theme: TempoTheme; label: string; onPress: () => void }) { return <Pressable onPress={onPress} style={({ pressed }) => [styles.roundButton, { backgroundColor: theme.surface, borderColor: theme.separator, opacity: pressed ? .62 : 1 }]}><Text style={[styles.roundLabel, { color: theme.secondary }]}>{label}</Text></Pressable>; }
function Metric({ theme, label, value }: { theme: TempoTheme; label: string; value: string }) { return <View style={[styles.metric, { backgroundColor: theme.surface }]}><Text style={[styles.metricLabel, { color: theme.secondary }]}>{label}</Text><Text style={[styles.metricValue, { color: theme.accent }]}>{value}</Text></View>; }
function Heatmap({ theme, history }: { theme: TempoTheme; history: PomodoroState['focusHistory'] }) { const values = useMemo(() => Array.from({ length: 98 }, (_, i) => history.filter((item) => sameDate(new Date(item.startedAt), addDays(new Date(), i - 97))).length), [history]); return <View style={styles.heatmap}>{values.map((value, index) => <View key={index} style={[styles.heatCell, { backgroundColor: value ? theme.accent : theme.surfaceMuted, opacity: value ? Math.min(1, .35 + value * .2) : 1 }]} />)}</View>; }
function modeTitle(mode: PomodoroState['mode']) { return mode === 'focus' ? '专注' : mode === 'shortBreak' ? '短休息' : '长休息'; }
function formatTime(seconds: number) { const safe = Math.max(0, seconds); return `${String(Math.floor(safe / 60)).padStart(2, '0')}:${String(safe % 60).padStart(2, '0')}`; }
function addDays(date: Date, count: number) { const result = new Date(date); result.setDate(result.getDate() + count); return result; }
function sameDate(a: Date, b: Date) { return a.toDateString() === b.toDateString(); }
const styles = StyleSheet.create({
  segmentWrap: { alignItems: 'center', marginTop: 2 }, segment: { width: 188, height: 34, borderRadius: 10, padding: 3, flexDirection: 'row' }, segmentItem: { flex: 1, borderRadius: 8, justifyContent: 'center', alignItems: 'center' }, segmentText: { fontSize: 13, fontWeight: '600' }, timerBody: { flex: 1, alignItems: 'center', justifyContent: 'space-evenly', paddingBottom: 24 }, mode: { fontSize: 17, fontWeight: '600' }, ring: { width: 292, height: 292, borderRadius: 146, alignItems: 'center', justifyContent: 'center' }, tick: { position: 'absolute', left: 145, top: 141, width: 2, height: 10, borderRadius: 1 }, ringContent: { alignItems: 'center', justifyContent: 'center' }, time: { fontSize: 60, fontWeight: '300', letterSpacing: -1.8, fontVariant: ['tabular-nums'] }, status: { fontSize: 14, marginTop: 9 }, controls: { flexDirection: 'row', alignItems: 'center', gap: 36 }, roundButton: { width: 52, height: 52, borderRadius: 26, borderWidth: StyleSheet.hairlineWidth, alignItems: 'center', justifyContent: 'center' }, roundLabel: { fontSize: 20 }, mainButton: { width: 72, height: 72, borderRadius: 36, alignItems: 'center', justifyContent: 'center' }, mainButtonText: { color: '#fff', fontSize: 24, fontWeight: '600' }, startButton: { width: 148, height: 54, borderRadius: 27, alignItems: 'center', justifyContent: 'center' }, startText: { color: '#fff', fontSize: 17, fontWeight: '600' }, stats: { padding: 20, paddingBottom: 52 }, statsTitle: { fontSize: 30, fontWeight: '700', marginBottom: 20 }, metrics: { flexDirection: 'row', gap: 10 }, metric: { flex: 1, borderRadius: 16, padding: 15, minHeight: 100 }, metricLabel: { fontSize: 12, fontWeight: '500' }, metricValue: { fontSize: 27, fontWeight: '700', marginTop: 13 }, heatTitle: { fontSize: 18, fontWeight: '600', marginTop: 26, marginBottom: 12 }, heatmap: { flexDirection: 'row', flexWrap: 'wrap', gap: 5 }, heatCell: { width: 14, height: 14, borderRadius: 4 }, pills: { flexDirection: 'row', flexWrap: 'wrap', gap: 9 }, pressed: { opacity: .62 },
});
