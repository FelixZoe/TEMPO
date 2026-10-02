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

type RuntimeProps = {
  route?: TempoBootstrap['route'];
  locale?: string;
};

export default function App(props: RuntimeProps) {
  const systemScheme = useColorScheme();
  const { width, height } = useWindowDimensions();
  const [bootstrap, setBootstrap] = useState<TempoBootstrap>();

  useEffect(() => {
    let active = true;
    tempoNative.bootstrap().then((value) => {
      if (active) {
        setBootstrap({
          ...value,
          route: props.route ?? value.route,
          locale: props.locale ?? value.locale,
        });
      }
    });
    const unsubscribe = tempoNative.subscribe((value) => {
      if (active) setBootstrap(value);
    });
    return () => {
      active = false;
      unsubscribe();
    };
  }, [props.locale, props.route]);

  const dark = bootstrap?.colorScheme === 'dark' || (!bootstrap && systemScheme === 'dark');
  const palette = dark ? darkPalette : lightPalette;
  const landscape = width > height;

  return (
    <SafeAreaView style={[styles.safeArea, { backgroundColor: palette.background }]}>
      <StatusBar style={dark ? 'light' : 'dark'} />
      <View style={[styles.content, landscape && styles.landscapeContent]}>
        {bootstrap ? (
          <View style={[styles.runtimePanel, landscape && styles.landscapePanel]}>
            <Text style={[styles.eyebrow, { color: palette.secondary }]}>TEMPO · OTA CONTENT</Text>
            <Text style={[styles.title, { color: palette.primary }]}>内容层已接入</Text>
            <Text style={[styles.body, { color: palette.secondary }]}>
              当前路由：{routeName(bootstrap.route)}。这个页面的 TypeScript、布局、样式和图片可通过
              Expo OTA 更新；底部导航、搜索、系统权限、小组件和灵动岛仍由原生层负责。
            </Text>
            <Text style={[styles.meta, { color: palette.tertiary }]}>数据修订 {bootstrap.revision} · {bootstrap.locale}</Text>
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
