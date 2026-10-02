import { NativeEventEmitter, NativeModules, Platform } from 'react-native';
import type { TempoCommand, TempoSnapshot } from '../types';

type TempoNativeBridgeShape = {
  bootstrap(): Promise<TempoSnapshot>;
  perform(action: string, payload: Record<string, unknown>): Promise<unknown>;
};

const nativeBridge = NativeModules.TempoNativeBridge as TempoNativeBridgeShape | undefined;

export const tempoNative = {
  isEmbedded: Platform.OS === 'ios' && nativeBridge != null,

  async bootstrap(): Promise<TempoSnapshot> {
    if (nativeBridge) {
      return nativeBridge.bootstrap();
    }

    return {
      route: 'today',
      locale: 'zh-Hans',
      colorScheme: 'light',
      revision: 0,
      tasks: [],
      displayedRemainingSeconds: 25 * 60,
    };
  },

  async perform(action: string, payload: Record<string, unknown> = {}) {
    if (!nativeBridge) {
      throw new Error(`Native action is unavailable outside the Tempo shell: ${action}`);
    }
    return nativeBridge.perform(action, payload);
  },

  subscribe(listener: (snapshot: TempoSnapshot) => void) {
    if (!nativeBridge) {
      return () => undefined;
    }

    const subscription = new NativeEventEmitter(NativeModules.TempoNativeBridge).addListener(
      'tempoStateDidChange',
      listener,
    );
    return () => subscription.remove();
  },

  subscribeCommands(listener: (command: TempoCommand) => void) {
    if (!nativeBridge) return () => undefined;
    const subscription = new NativeEventEmitter(NativeModules.TempoNativeBridge).addListener(
      'tempoCommand',
      listener,
    );
    return () => subscription.remove();
  },
};
