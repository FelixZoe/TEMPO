import { useCallback, useEffect, useMemo, useState } from 'react';
import { useColorScheme } from 'react-native';

import { tempoNative } from '../native/TempoNative';
import { makeTheme } from '../theme';
import type { TempoCommand, TempoSnapshot } from '../types';

export function useTempo(routeOverride?: TempoSnapshot['route']) {
  const systemScheme = useColorScheme();
  const [snapshot, setSnapshot] = useState<TempoSnapshot>();
  const [command, setCommand] = useState<TempoCommand>();
  const [error, setError] = useState<string>();

  useEffect(() => {
    let active = true;
    tempoNative.bootstrap().then((value) => active && setSnapshot(value)).catch((reason) => {
      if (active) setError(messageOf(reason));
    });
    const offState = tempoNative.subscribe((value) => active && setSnapshot(value));
    const offCommand = tempoNative.subscribeCommands((value) => active && setCommand(value));
    return () => {
      active = false;
      offState();
      offCommand();
    };
  }, []);

  const perform = useCallback(async <T,>(action: string, payload: Record<string, unknown> = {}) => {
    try {
      setError(undefined);
      return await tempoNative.perform(action, payload) as T;
    } catch (reason) {
      const message = messageOf(reason);
      setError(message);
      throw new Error(message);
    }
  }, []);

  const consumeCommand = useCallback(() => setCommand(undefined), []);
  const route = routeOverride ?? snapshot?.route ?? 'today';
  const theme = useMemo(
    () => makeTheme(snapshot?.colorScheme ?? systemScheme),
    [snapshot?.colorScheme, systemScheme],
  );

  return { snapshot, route, theme, command, consumeCommand, perform, error, clearError: () => setError(undefined) };
}

function messageOf(reason: unknown) {
  if (reason instanceof Error) return reason.message;
  return String(reason ?? '操作失败，请稍后重试');
}
