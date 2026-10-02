import * as Brownfield from 'expo-brownfield';
import { Platform } from 'react-native';

import type { TempoCommand, TempoSnapshot } from '../types';

type NativeMessage = {
  type?: string;
  requestId?: string;
  ok?: boolean;
  result?: unknown;
  error?: string;
  snapshot?: TempoSnapshot;
  command?: TempoCommand;
};

type PendingRequest = {
  resolve(value: unknown): void;
  reject(reason: Error): void;
  timeout: ReturnType<typeof setTimeout>;
};

const pendingRequests = new Map<string, PendingRequest>();
const snapshotListeners = new Set<(snapshot: TempoSnapshot) => void>();
const commandListeners = new Set<(command: TempoCommand) => void>();
let nextRequestSequence = 0;

Brownfield.addMessageListener((message: NativeMessage) => {
  if (message.type === 'tempo.response' && message.requestId) {
    const pending = pendingRequests.get(message.requestId);
    if (!pending) return;
    clearTimeout(pending.timeout);
    pendingRequests.delete(message.requestId);
    if (message.ok === false) {
      pending.reject(new Error(message.error || '原生操作失败'));
    } else {
      pending.resolve(message.result);
    }
    return;
  }

  if (message.type === 'tempo.snapshot' && message.snapshot) {
    snapshotListeners.forEach((listener) => listener(message.snapshot!));
    return;
  }

  if (message.type === 'tempo.command' && message.command) {
    commandListeners.forEach((listener) => listener(message.command!));
  }
});

function request<T>(message: Record<string, unknown>): Promise<T> {
  const requestId = `tempo-${Date.now()}-${nextRequestSequence++}`;
  return new Promise<T>((resolve, reject) => {
    const timeout = setTimeout(() => {
      pendingRequests.delete(requestId);
      reject(new Error('原生容器响应超时'));
    }, 15_000);
    pendingRequests.set(requestId, {
      resolve: resolve as (value: unknown) => void,
      reject,
      timeout,
    });
    Brownfield.sendMessage({ ...message, requestId });
  });
}

export const tempoNative = {
  isEmbedded: Platform.OS === 'ios',

  bootstrap(): Promise<TempoSnapshot> {
    return request<TempoSnapshot>({ type: 'tempo.bootstrap' });
  },

  perform(action: string, payload: Record<string, unknown> = {}) {
    return request<unknown>({ type: 'tempo.perform', action, payload });
  },

  subscribe(listener: (snapshot: TempoSnapshot) => void) {
    snapshotListeners.add(listener);
    return () => snapshotListeners.delete(listener);
  },

  subscribeCommands(listener: (command: TempoCommand) => void) {
    commandListeners.add(listener);
    return () => commandListeners.delete(listener);
  },
};
