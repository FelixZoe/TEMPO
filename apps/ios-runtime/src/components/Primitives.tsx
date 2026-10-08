import type { PropsWithChildren, ReactNode } from 'react';
import { ActivityIndicator, Modal, Pressable, ScrollView, StyleSheet, Switch, Text, View } from 'react-native';

import { radius, spacing, type TempoTheme } from '../theme';

export function Screen({ children, theme, scroll = false }: PropsWithChildren<{ theme: TempoTheme; scroll?: boolean }>) {
  const content = <View style={styles.screenContent}>{children}</View>;
  return (
    <View style={[styles.screen, { backgroundColor: theme.background }]}>
      {scroll ? <ScrollView contentContainerStyle={styles.scrollContent}>{content}</ScrollView> : content}
    </View>
  );
}

export function NativeChromeGap() { return <View style={styles.chromeGap} />; }

export function Section({ children, theme, title }: PropsWithChildren<{ theme: TempoTheme; title?: string }>) {
  return (
    <View style={styles.sectionWrap}>
      {title ? <Text style={[styles.sectionLabel, { color: theme.secondary }]}>{title}</Text> : null}
      <View style={[styles.section, { borderColor: theme.separator }]}>{children}</View>
    </View>
  );
}

export function Divider({ theme }: { theme: TempoTheme }) {
  return <View style={[styles.divider, { backgroundColor: theme.separator }]} />;
}

export function Row({
  theme,
  title,
  detail,
  onPress,
  right,
  destructive,
}: {
  theme: TempoTheme;
  title: string;
  detail?: string;
  onPress?: () => void;
  right?: ReactNode;
  destructive?: boolean;
}) {
  const body = (
    <View style={styles.row}>
      <View style={styles.rowText}>
        <Text style={[styles.rowTitle, { color: destructive ? theme.danger : theme.text }]}>{title}</Text>
        {detail ? <Text style={[styles.rowDetail, { color: theme.secondary }]}>{detail}</Text> : null}
      </View>
      {right ?? (onPress ? <Text style={[styles.chevron, { color: theme.tertiary }]}>›</Text> : null)}
    </View>
  );
  return onPress ? <Pressable onPress={onPress} style={({ pressed }) => pressed && styles.pressed}>{body}</Pressable> : body;
}

export function ToggleRow({ theme, title, value, onValueChange, detail }: {
  theme: TempoTheme; title: string; value: boolean; onValueChange: (value: boolean) => void; detail?: string;
}) {
  return <Row theme={theme} title={title} detail={detail} right={<Switch value={value} onValueChange={onValueChange} trackColor={{ true: theme.accent }} />} />;
}

export function Pill({ theme, label, selected, onPress }: {
  theme: TempoTheme; label: string; selected?: boolean; onPress: () => void;
}) {
  return (
    <Pressable onPress={onPress} style={({ pressed }) => [styles.pill, { backgroundColor: selected ? theme.accentSoft : theme.surfaceMuted }, pressed && styles.pressed]}>
      <Text style={[styles.pillText, { color: selected ? theme.accent : theme.secondary }]}>{label}</Text>
    </Pressable>
  );
}

export function PrimaryButton({ theme, label, onPress, loading, disabled }: {
  theme: TempoTheme; label: string; onPress: () => void; loading?: boolean; disabled?: boolean;
}) {
  return (
    <Pressable disabled={disabled || loading} onPress={onPress} style={({ pressed }) => [styles.primary, { backgroundColor: theme.accent, opacity: disabled ? .42 : pressed ? .78 : 1 }]}>
      {loading ? <ActivityIndicator color="#fff" /> : <Text style={styles.primaryText}>{label}</Text>}
    </Pressable>
  );
}

export function Sheet({ visible, onClose, children, theme }: PropsWithChildren<{ visible: boolean; onClose: () => void; theme: TempoTheme }>) {
  return (
    <Modal visible={visible} animationType="slide" presentationStyle="pageSheet" onRequestClose={onClose}>
      <View style={[styles.sheet, { backgroundColor: theme.background }]}>
        <View style={[styles.grabber, { backgroundColor: theme.tertiary }]} />
        {children}
      </View>
    </Modal>
  );
}

const styles = StyleSheet.create({
  screen: { flex: 1 },
  screenContent: { flex: 1 },
  scrollContent: { paddingBottom: 40 },
  chromeGap: { height: 62 },
  sectionWrap: { marginHorizontal: 20, marginBottom: 24 },
  sectionLabel: { fontSize: 13, fontWeight: '600', marginBottom: 8 },
  section: { borderTopWidth: StyleSheet.hairlineWidth, borderBottomWidth: StyleSheet.hairlineWidth },
  divider: { height: StyleSheet.hairlineWidth, marginLeft: 18 },
  row: { minHeight: 58, flexDirection: 'row', alignItems: 'center', paddingHorizontal: 16, paddingVertical: 11 },
  rowText: { flex: 1 },
  rowTitle: { fontSize: 16, fontWeight: '500', letterSpacing: -.1 },
  rowDetail: { fontSize: 13, lineHeight: 18, marginTop: 3 },
  chevron: { fontSize: 25, fontWeight: '300' },
  pill: { height: 34, paddingHorizontal: spacing.md, borderRadius: radius.pill, alignItems: 'center', justifyContent: 'center' },
  pillText: { fontSize: 14, fontWeight: '600' },
  primary: { height: 50, borderRadius: radius.pill, alignItems: 'center', justifyContent: 'center', marginHorizontal: 20 },
  primaryText: { color: '#fff', fontSize: 16, fontWeight: '600' },
  sheet: { flex: 1 },
  grabber: { width: 38, height: 5, borderRadius: 3, alignSelf: 'center', opacity: .45, marginTop: 8, marginBottom: 8 },
  pressed: { opacity: .62 },
});
