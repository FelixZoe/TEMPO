import { NativeEventEmitter, NativeModules, Platform } from 'react-native';

export type TempoRoute = 'inbox' | 'today' | 'focus' | 'rss' | 'settings';

export type TempoBootstrap = {
  route: TempoRoute;
  locale: string;
  colorScheme: 'light' | 'dark';
  revision: number;
};

type TempoNativeBridgeShape = {
  bootstrap(): Promise<TempoBootstrap>;
  perform(action: string, payload: Record<string, unknown>): Promise<unknown>;
};

const nativeBridge = NativeModules.TempoNativeBridge as TempoNativeBridgeShape | undefined;

export const tempoNative = {
  isEmbedded: Platform.OS === 'ios' && nativeBridge != null,

  async bootstrap(): Promise<TempoBootstrap> {
    if (nativeBridge) {
      return nativeBridge.bootstrap();
    }

    return {
      route: 'today',
      locale: 'zh-Hans',
      colorScheme: 'light',
      revision: 0,
    };
  },

  async perform(action: string, payload: Record<string, unknown> = {}) {
    if (!nativeBridge) {
      throw new Error(`Native action is unavailable outside the Tempo shell: ${action}`);
    }
    return nativeBridge.perform(action, payload);
  },

  subscribe(listener: (bootstrap: TempoBootstrap) => void) {
    if (!nativeBridge) {
      return () => undefined;
    }

    const subscription = new NativeEventEmitter(NativeModules.TempoNativeBridge).addListener(
      'tempoStateDidChange',
      listener,
    );
    return () => subscription.remove();
  },
};
