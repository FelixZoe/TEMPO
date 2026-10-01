import { useEffect, useState } from 'react';
import {
  ActivityIndicator,
  SafeAreaView,
  StyleSheet,
  Text,
  useColorScheme,
  useWindowDimensions,
  View,
} from 'react-native';
import { StatusBar } from 'expo-status-bar';

import { tempoNative, type TempoBootstrap } from './native/TempoNative';

export default function App() {
  const systemScheme = useColorScheme();
  const { width, height } = useWindowDimensions();
  const [bootstrap, setBootstrap] = useState<TempoBootstrap>();

  useEffect(() => {
    let active = true;
    tempoNative.bootstrap().then((value) => {
      if (active) setBootstrap(value);
    });
    const unsubscribe = tempoNative.subscribe((value) => {
      if (active) setBootstrap(value);
    });
    return () => {
      active = false;
      unsubscribe();
    };
  }, []);

  const dark = bootstrap?.colorScheme === 'dark' || (!bootstrap && systemScheme === 'dark');
  const palette = dark ? darkPalette : lightPalette;
  const landscape = width > height;

  return (
    <SafeAreaView style={[styles.safeArea, { backgroundColor: palette.background }]}>
      <StatusBar style={dark ? 'light' : 'dark'} />
      <View style={[styles.content, landscape && styles.landscapeContent]}>
        {bootstrap ? (
          <View style={[styles.runtimePanel, landscape && styles.landscapePanel]}>
            <Text style={[styles.eyebrow, { color: palette.secondary }]}>TEMPO CONTENT RUNTIME</Text>
            <Text style={[styles.title, { color: palette.primary }]}>OTA 层已就绪</Text>
            <Text style={[styles.body, { color: palette.secondary }]}>
              当前路由：{routeName(bootstrap.route)}。原生导航、搜索与液态玻璃按钮继续由 SwiftUI
              提供，页面内容将从这里逐步迁移。
            </Text>
            <Text style={[styles.meta, { color: palette.tertiary }]}>数据修订 {bootstrap.revision}</Text>
          </View>
        ) : (
          <ActivityIndicator color={palette.primary} />
        )}
      </View>
    </SafeAreaView>
  );
}

function routeName(route: TempoBootstrap['route']) {
  switch (route) {
    case 'inbox': return '收集箱';
    case 'today': return '今天';
    case 'focus': return '番茄钟';
    case 'rss': return 'RSS';
    case 'settings': return '设置';
  }
}

const lightPalette = {
  background: '#F7F8FA',
  primary: '#15171A',
  secondary: '#5D636D',
  tertiary: '#9298A1',
};

const darkPalette = {
  background: '#0E1012',
  primary: '#F4F5F6',
  secondary: '#AEB4BD',
  tertiary: '#707680',
};

const styles = StyleSheet.create({
  safeArea: { flex: 1 },
  content: {
    flex: 1,
    justifyContent: 'center',
    paddingHorizontal: 28,
  },
  landscapeContent: {
    alignItems: 'center',
    paddingHorizontal: 56,
  },
  runtimePanel: {
    width: '100%',
  },
  landscapePanel: {
    maxWidth: 720,
  },
  eyebrow: {
    fontSize: 12,
    fontWeight: '600',
    letterSpacing: 1.2,
    marginBottom: 14,
  },
  title: {
    fontSize: 34,
    fontWeight: '700',
    letterSpacing: -0.8,
    marginBottom: 14,
  },
  body: {
    fontSize: 17,
    lineHeight: 27,
    maxWidth: 560,
  },
  meta: {
    fontSize: 13,
    marginTop: 20,
  },
});
