import { useRef, useState } from 'react';
import { KeyboardAvoidingView, Platform, Pressable, ScrollView, StyleSheet, Text, TextInput, View } from 'react-native';
import { DarkTheme, DefaultTheme, NavigationContainer } from '@react-navigation/native';
import { createNativeStackNavigator } from '@react-navigation/native-stack';

import { Divider, Pill, PrimaryButton, Row, Screen, Section, ToggleRow } from '../components/Primitives';
import { radius, type TempoTheme } from '../theme';
import type { TempoSnapshot } from '../types';

type Page = 'sync' | 'ai' | 'focus' | 'calendar' | 'update' | 'modules';
type SettingsStackParamList = {
  home: undefined;
  detail: { page: Page };
};

const Stack = createNativeStackNavigator<SettingsStackParamList>();

export function SettingsScreen({ theme, snapshot, perform }: { theme: TempoTheme; snapshot: TempoSnapshot; perform: <T>(action: string, payload?: Record<string, unknown>) => Promise<T> }) {
  const [message, setMessage] = useState('');
  const navigationThemeBase = theme.dark ? DarkTheme : DefaultTheme;
  const navigationTheme = {
    ...navigationThemeBase,
    colors: {
      ...navigationThemeBase.colors,
      primary: theme.accent,
      background: theme.background,
      card: theme.background,
      text: theme.text,
      border: theme.separator,
      notification: theme.accent,
    },
  };

  return <NavigationContainer theme={navigationTheme}>
    <Stack.Navigator screenOptions={{
      contentStyle: { backgroundColor: theme.background },
      headerStyle: { backgroundColor: theme.background },
      headerTintColor: theme.accent,
      headerTitleStyle: { color: theme.text, fontWeight: '700' },
      headerShadowVisible: false,
      headerBackTitle: '设置',
      gestureEnabled: true,
    }}>
      <Stack.Screen name="home" options={{ headerShown: false }}>
        {({ navigation }) => <SettingsHome theme={theme} snapshot={snapshot} perform={perform} openPage={(page) => { setMessage(''); navigation.navigate('detail', { page }); }} />}
      </Stack.Screen>
      <Stack.Screen name="detail" options={({ route }) => ({ title: pageTitle(route.params.page) })}>
        {({ route }) => <DetailPage page={route.params.page} theme={theme} snapshot={snapshot} perform={perform} message={message} setMessage={setMessage} />}
      </Stack.Screen>
    </Stack.Navigator>
  </NavigationContainer>;
}

function SettingsHome({ theme, snapshot, perform, openPage }: { theme: TempoTheme; snapshot: TempoSnapshot; perform: <T>(action: string, payload?: Record<string, unknown>) => Promise<T>; openPage: (page: Page) => void }) {
  const taps = useRef<number[]>([]);
  function developerTap() { const now = Date.now(); taps.current = [...taps.current.filter((value) => now - value < 1200), now]; if (taps.current.length >= 4) { taps.current = []; void perform('developer.open'); } }
  return <Screen theme={theme}>
    <ScrollView contentContainerStyle={styles.content}>
      <Pressable onPress={developerTap} onLongPress={() => perform('developer.open')}><Text style={[styles.title, { color: theme.text }]}>设置</Text></Pressable>
      <Text style={[styles.caption, { color: theme.secondary }]}>账户、同步与应用偏好</Text>
      <Section theme={theme} title="服务">
        <SettingRow theme={theme} icon="↻" tint={theme.accent} title="自托管同步" detail={snapshot.sync?.configured ? syncLabel(snapshot.sync.phase, snapshot.sync.pendingChangeCount) : '未配置'} onPress={() => openPage('sync')} /><Divider theme={theme} />
        <SettingRow theme={theme} icon="✦" tint={theme.text} title="AI 助手" detail={snapshot.ai?.configured ? snapshot.ai.model : '未配置'} onPress={() => openPage('ai')} /><Divider theme={theme} />
        <SettingRow theme={theme} icon="◉" tint={theme.accent} title="番茄钟" detail={`${snapshot.pomodoro?.focusMinutes ?? 25} 分钟 · 目标 ${snapshot.pomodoro?.dailyFocusGoal ?? 4}`} onPress={() => openPage('focus')} />
      </Section>
      <Section theme={theme} title="应用">
        <SettingRow theme={theme} icon="▦" tint={theme.secondary} title="日期与日历" detail="周起始、节日与任务标记" onPress={() => openPage('calendar')} /><Divider theme={theme} />
        <SettingRow theme={theme} icon="≡" tint={theme.secondary} title="功能模块" detail="调整模块顺序" onPress={() => openPage('modules')} /><Divider theme={theme} />
        <SettingRow theme={theme} icon="↓" tint={theme.success} title="软件更新" detail={`v${snapshot.app?.version ?? '—'} (${snapshot.app?.build ?? '—'})`} onPress={() => openPage('update')} />
      </Section>
      <Section theme={theme} title="关于 TEMPO"><Row theme={theme} title="本地优先个人工作台" detail="时间、信息、当下、效率，一切井然有序。" /></Section>
    </ScrollView>
  </Screen>;
}

function DetailPage({ page, theme, snapshot, perform, message, setMessage }: { page: Page; theme: TempoTheme; snapshot: TempoSnapshot; perform: <T>(action: string, payload?: Record<string, unknown>) => Promise<T>; message: string; setMessage: (value: string) => void }) {
  return <Screen theme={theme}><KeyboardAvoidingView style={{ flex: 1 }} behavior={Platform.OS === 'ios' ? 'padding' : undefined}><ScrollView keyboardShouldPersistTaps="handled" contentContainerStyle={styles.detailContent}>{page === 'sync' ? <SyncSettings theme={theme} value={snapshot.sync} perform={perform} setMessage={setMessage} /> : page === 'ai' ? <AISettings theme={theme} value={snapshot.ai} perform={perform} setMessage={setMessage} /> : page === 'focus' ? <FocusSettings theme={theme} value={snapshot.pomodoro} perform={perform} /> : page === 'calendar' ? <CalendarSettings theme={theme} value={snapshot.preferences} perform={perform} /> : page === 'modules' ? <ModuleSettings theme={theme} value={snapshot.preferences?.moduleOrder} perform={perform} /> : <UpdateSettings theme={theme} value={snapshot.app} perform={perform} setMessage={setMessage} />}{message ? <Text style={[styles.message, { color: theme.secondary }]}>{message}</Text> : null}</ScrollView></KeyboardAvoidingView></Screen>;
}
function SyncSettings({ theme, value, perform, setMessage }: any) { const [serverURL, setServerURL] = useState(value?.serverURL ?? ''); const [deviceName, setDeviceName] = useState(value?.deviceName ?? 'iPhone'); const [token, setToken] = useState(''); const [autoSync, setAutoSync] = useState(value?.autoSync ?? true); async function save(test = false) { setMessage(test ? '正在测试连接…' : '正在保存…'); try { const payload = { serverURL, deviceName, token, autoSync }; await perform(test ? 'sync.test' : 'sync.save', payload); setMessage(test ? '连接成功' : '已保存，将自动实时同步'); } catch { setMessage('连接失败，请检查地址与验证密钥'); } } return <><Section theme={theme} title="服务器"><Field theme={theme} label="服务器地址" value={serverURL} onChange={setServerURL} placeholder="https://sync.example.com" /><Divider theme={theme} /><Field theme={theme} label="设备名称" value={deviceName} onChange={setDeviceName} /><Divider theme={theme} /><Field theme={theme} label="64 位验证密钥" value={token} onChange={setToken} placeholder={value?.hasToken ? '已保存，留空保持不变' : '粘贴服务器生成的密钥'} secure /></Section><Section theme={theme}><ToggleRow theme={theme} title="自动实时同步" detail="数据变化后立即上传，网络恢复后自动补传" value={autoSync} onValueChange={setAutoSync} /><Divider theme={theme} /><Row theme={theme} title="当前状态" detail={`${syncLabel(value?.phase, value?.pendingChangeCount ?? 0)} · revision ${value?.revision ?? 0}`} /></Section><View style={styles.buttonGap}><PrimaryButton theme={theme} label="保存配置" onPress={() => save(false)} /><Pressable onPress={() => save(true)}><Text style={[styles.linkButton, { color: theme.accent }]}>测试连接</Text></Pressable><Pressable onPress={() => perform('sync.now')}><Text style={[styles.linkButton, { color: theme.accent }]}>立即同步</Text></Pressable></View></>; }
function AISettings({ theme, value, perform, setMessage }: any) { const [mode, setMode] = useState(value?.mode ?? 'openAI'); const [baseURL, setBaseURL] = useState(value?.baseURL ?? 'https://api.openai.com/v1'); const [model, setModel] = useState(value?.model ?? 'gpt-5-mini'); const [apiKey, setAPIKey] = useState(''); const [summaryPrompt, setPrompt] = useState(value?.summaryPrompt ?? ''); const presets: Record<string, { url: string; model: string }> = { openAI: { url: 'https://api.openai.com/v1', model: 'gpt-5-mini' }, deepSeek: { url: 'https://api.deepseek.com/v1', model: 'deepseek-chat' }, compatible: { url: baseURL, model } }; async function save(test = false) { const payload = { mode, baseURL, model, apiKey, summaryPrompt }; setMessage('正在保存…'); try { await perform('ai.save', payload); if (test) await perform('ai.test'); setMessage(test ? '模型连接正常' : 'AI 配置已保存'); } catch { setMessage('模型连接失败，请检查 API 地址、模型和密钥'); } } return <><Section theme={theme} title="服务商"><View style={styles.pills}>{['openAI', 'deepSeek', 'compatible'].map((item) => <Pill key={item} theme={theme} label={item === 'openAI' ? 'OpenAI' : item === 'deepSeek' ? 'DeepSeek' : '兼容接口'} selected={mode === item} onPress={() => { setMode(item); const preset = presets[item]; if (preset) { setBaseURL(preset.url); setModel(preset.model); } }} />)}</View></Section><Section theme={theme} title="模型"><Field theme={theme} label="API 地址" value={baseURL} onChange={setBaseURL} /><Divider theme={theme} /><Field theme={theme} label="模型" value={model} onChange={setModel} /><Divider theme={theme} /><Field theme={theme} label="API 密钥" value={apiKey} onChange={setAPIKey} secure placeholder={value?.hasAPIKey ? '已安全保存，留空保持不变' : 'sk-…'} /><Divider theme={theme} /><Field theme={theme} label="RSS 摘要提示词（可选）" value={summaryPrompt} onChange={setPrompt} placeholder="留空使用 TEMPO 内置提示词" multiline /></Section><View style={styles.buttonGap}><PrimaryButton theme={theme} label="保存" onPress={() => save(false)} /><Pressable onPress={() => save(true)}><Text style={[styles.linkButton, { color: theme.accent }]}>保存并测试</Text></Pressable></View></>; }
function FocusSettings({ theme, value, perform }: any) { return <Section theme={theme} title="专注"><ChoiceRow theme={theme} title="番茄时长" current={value?.focusMinutes ?? 25} choices={[25, 35, 45, 60]} unit="分钟" action={(focus: number) => perform('pomodoro.settings', { focus })} /><Divider theme={theme} /><ChoiceRow theme={theme} title="每日目标" current={value?.dailyFocusGoal ?? 4} choices={[2, 4, 6, 8]} unit="个" action={(dailyFocusGoal: number) => perform('pomodoro.settings', { dailyFocusGoal })} /><Divider theme={theme} /><ChoiceRow theme={theme} title="长休息间隔" current={value?.longBreakEvery ?? 4} choices={[2, 3, 4, 5]} unit="次" action={(longBreakEvery: number) => perform('pomodoro.settings', { longBreakEvery })} /></Section>; }
function CalendarSettings({ theme, value, perform }: any) { const save = (payload: Record<string, boolean>) => perform('preferences.save', payload); return <Section theme={theme}><ToggleRow theme={theme} title="星期从周一开始" value={value?.weekStartsMonday ?? true} onValueChange={(weekStartsMonday) => save({ weekStartsMonday })} /><Divider theme={theme} /><ToggleRow theme={theme} title="显示节日" value={value?.showFestivals ?? true} onValueChange={(showFestivals) => save({ showFestivals })} /><Divider theme={theme} /><ToggleRow theme={theme} title="显示任务标记" value={value?.showTaskIndicators ?? true} onValueChange={(showTaskIndicators) => save({ showTaskIndicators })} /></Section>; }
function ModuleSettings({ theme, value, perform }: any) { const initial = String(value ?? 'inbox,today,focus,rss,settings').split(','); const [items, setItems] = useState(initial); function move(index: number, delta: number) { const target = index + delta; if (target < 0 || target >= items.length) return; const next = [...items]; const first = next[index]; const second = next[target]; if (!first || !second) return; next[index] = second; next[target] = first; setItems(next); perform('preferences.save', { moduleOrder: next.join(',') }); } return <Section theme={theme} title="最多显示 5 个一级导航">{items.map((item: string, index: number) => <View key={item}><View style={styles.moduleRow}><Text style={[styles.moduleTitle, { color: theme.text }]}>{moduleTitle(item)}</Text><Pressable onPress={() => move(index, -1)}><Text style={[styles.moduleAction, { color: theme.accent }]}>↑</Text></Pressable><Pressable onPress={() => move(index, 1)}><Text style={[styles.moduleAction, { color: theme.accent }]}>↓</Text></Pressable></View>{index < items.length - 1 ? <Divider theme={theme} /> : null}</View>)}</Section>; }
function UpdateSettings({ theme, value, perform, setMessage }: any) { const update = value?.update; return <><Section theme={theme}><Row theme={theme} title="当前版本" detail={`v${value?.version ?? '—'} (${value?.build ?? '—'})`} /><Divider theme={theme} /><Row theme={theme} title="更新状态" detail={update?.state === 'available' ? `发现 v${update.version}` : update?.state === 'current' ? '已是最新版' : update?.message ?? '尚未检查'} /></Section><PrimaryButton theme={theme} label="检查更新" onPress={async () => { setMessage('正在检查…'); await perform('update.check'); setMessage('检查完成'); }} />{update?.state === 'available' ? <Pressable onPress={() => perform('update.download')}><Text style={[styles.linkButton, { color: theme.accent }]}>下载并覆盖安装</Text></Pressable> : null}</>; }
function SettingRow({ theme, icon, tint, title, detail, onPress }: { theme: TempoTheme; icon: string; tint: string; title: string; detail: string; onPress: () => void }) { return <Pressable onPress={onPress} style={({ pressed }) => [styles.settingRow, { opacity: pressed ? .62 : 1 }]}><View style={styles.iconBox}><Text style={[styles.icon, { color: tint }]}>{icon}</Text></View><View style={styles.settingText}><Text style={[styles.settingTitle, { color: theme.text }]}>{title}</Text><Text numberOfLines={1} style={[styles.settingDetail, { color: theme.secondary }]}>{detail}</Text></View><Text style={[styles.chevron, { color: theme.tertiary }]}>›</Text></Pressable>; }
function Field({ theme, label, value, onChange, placeholder, secure, multiline }: any) { return <View style={styles.field}><Text style={[styles.fieldLabel, { color: theme.secondary }]}>{label}</Text><TextInput value={value} onChangeText={onChange} placeholder={placeholder} placeholderTextColor={theme.tertiary} secureTextEntry={secure} multiline={multiline} autoCapitalize="none" style={[styles.fieldInput, multiline && { minHeight: 70 }, { color: theme.text }]} /></View>; }
function ChoiceRow({ theme, title, current, choices, unit, action }: any) { return <View style={styles.choice}><Text style={[styles.choiceTitle, { color: theme.text }]}>{title}</Text><View style={styles.pills}>{choices.map((value: number) => <Pill key={value} theme={theme} label={`${value}${unit}`} selected={current === value} onPress={() => action(value)} />)}</View></View>; }
function syncLabel(phase?: string, pending = 0) { if (pending) return `${pending} 项待同步`; if (phase === 'syncing') return '正在同步'; if (phase === 'error') return '同步异常'; return '已实时同步'; }
function pageTitle(page: Page) { return ({ sync: '自托管同步', ai: 'AI 助手', focus: '番茄钟', calendar: '日期与日历', update: '软件更新', modules: '功能模块' } as const)[page]; }
function moduleTitle(value: string) { return ({ inbox: '收集箱', today: '今天', focus: '番茄钟', rss: 'RSS', settings: '设置' } as Record<string, string>)[value] ?? value; }
const styles = StyleSheet.create({ content: { paddingTop: 8, paddingBottom: 60 }, title: { fontSize: 34, fontWeight: '800', letterSpacing: -1.15, paddingHorizontal: 20 }, caption: { paddingHorizontal: 20, fontSize: 14, marginTop: 7, marginBottom: 22 }, settingRow: { minHeight: 66, flexDirection: 'row', alignItems: 'center' }, iconBox: { width: 30, height: 36, alignItems: 'flex-start', justifyContent: 'center', marginRight: 10 }, icon: { fontSize: 20, fontWeight: '600' }, settingText: { flex: 1 }, settingTitle: { fontSize: 16, fontWeight: '600' }, settingDetail: { fontSize: 12, marginTop: 4 }, chevron: { fontSize: 25, fontWeight: '300' }, detailContent: { paddingTop: 10, paddingBottom: 60 }, field: { paddingHorizontal: 0, paddingVertical: 12 }, fieldLabel: { fontSize: 12, fontWeight: '500', marginBottom: 5 }, fieldInput: { fontSize: 16, padding: 0 }, buttonGap: { gap: 12 }, linkButton: { textAlign: 'center', fontSize: 15, fontWeight: '600', paddingVertical: 9 }, message: { textAlign: 'center', marginTop: 18, paddingHorizontal: 24 }, pills: { flexDirection: 'row', flexWrap: 'wrap', gap: 8, paddingVertical: 14 }, choice: { paddingVertical: 12 }, choiceTitle: { fontSize: 16, fontWeight: '600' }, moduleRow: { minHeight: 60, flexDirection: 'row', alignItems: 'center' }, moduleTitle: { flex: 1, fontSize: 16, fontWeight: '500' }, moduleAction: { fontSize: 22, fontWeight: '600', paddingHorizontal: 12 }, });
