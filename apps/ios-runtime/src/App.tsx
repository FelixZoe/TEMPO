import { useEffect, useRef } from 'react';
import { ActivityIndicator, AppState, SafeAreaView, StyleSheet, Text, View } from 'react-native';
import { StatusBar } from 'expo-status-bar';
import * as Updates from 'expo-updates';

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
  useAutomaticRuntimeUpdates();
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

function useAutomaticRuntimeUpdates() {
  const checking = useRef(false);
  const lastCheckAt = useRef(0);

  useEffect(() => {
    if (__DEV__ || !Updates.isEnabled) return undefined;

    const checkAndApply = async () => {
      const now = Date.now();
      if (checking.current || now - lastCheckAt.current < 15 * 60 * 1000) return;
      checking.current = true;
      lastCheckAt.current = now;
      try {
        const available = await Updates.checkForUpdateAsync();
        if (!available.isAvailable && !available.isRollBackToEmbedded) return;
        const downloaded = await Updates.fetchUpdateAsync();
        if (downloaded.isNew || downloaded.isRollBackToEmbedded) {
          await Updates.reloadAsync();
        }
      } catch {
        // Offline or disabled update services must never block the local-first app.
      } finally {
        checking.current = false;
      }
    };

    const startup = setTimeout(() => { void checkAndApply(); }, 1200);
    const foreground = AppState.addEventListener('change', (state) => {
      if (state === 'active') void checkAndApply();
    });
    return () => {
      clearTimeout(startup);
      foreground.remove();
    };
  }, []);
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
