import { ActivityIndicator, SafeAreaView, StyleSheet, Text, View } from 'react-native';
import { StatusBar } from 'expo-status-bar';

import { useTempo } from './hooks/useTempo';
import { FocusScreen } from './screens/FocusScreen';
import { RSSScreen } from './screens/RSSScreen';
import { SettingsScreen } from './screens/SettingsScreen';
import { TasksScreen } from './screens/TasksScreen';
import type { TempoRoute } from './types';

type RuntimeProps = {
  route?: TempoRoute;
  locale?: string;
};

export default function App(props: RuntimeProps) {
  const tempo = useTempo(props.route);
  const { snapshot, route, theme } = tempo;

  return (
    <SafeAreaView style={[styles.safeArea, { backgroundColor: theme.background }]}>
      <StatusBar style={theme.dark ? 'light' : 'dark'} />
      {snapshot ? <RouteView tempo={tempo} /> : <View style={styles.loading}><ActivityIndicator color={theme.accent} /></View>}
      {tempo.error ? <View style={[styles.toast, { backgroundColor: theme.text }]}><Text style={{ color: theme.background, fontWeight: '600' }}>{tempo.error}</Text></View> : null}
    </SafeAreaView>
  );
}

function RouteView({ tempo }: { tempo: ReturnType<typeof useTempo> }) {
  const { snapshot, route, theme, command, consumeCommand, perform } = tempo;
  if (!snapshot) return null;
  if (route === 'inbox' || route === 'today') return <TasksScreen route={route} theme={theme} tasks={snapshot.tasks} quote={snapshot.ambient?.quote?.text} command={command} consumeCommand={consumeCommand} perform={perform} />;
  if (route === 'focus') return <FocusScreen theme={theme} pomodoro={snapshot.pomodoro} remaining={snapshot.displayedRemainingSeconds} command={command} consumeCommand={consumeCommand} perform={perform} />;
  if (route === 'rss') return <RSSScreen theme={theme} articles={snapshot.rss?.articles ?? []} subscriptions={snapshot.rss?.subscriptions ?? []} folders={snapshot.rss?.folders ?? []} phase={snapshot.rss?.phase ?? 'idle'} command={command} consumeCommand={consumeCommand} perform={perform} />;
  return <SettingsScreen theme={theme} snapshot={snapshot} perform={perform} />;
}

const styles = StyleSheet.create({
  safeArea: { flex: 1 },
  loading: { flex: 1, alignItems: 'center', justifyContent: 'center' },
  toast: { position: 'absolute', left: 22, right: 22, bottom: 20, minHeight: 48, borderRadius: 24, paddingHorizontal: 18, alignItems: 'center', justifyContent: 'center' },
});
