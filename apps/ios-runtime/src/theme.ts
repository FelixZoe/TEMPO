import type { ColorSchemeName } from 'react-native';

export type TempoTheme = ReturnType<typeof makeTheme>;

export function makeTheme(scheme: ColorSchemeName | 'light' | 'dark') {
  const dark = scheme === 'dark';
  return {
    dark,
    background: dark ? '#121214' : '#FAFAFA',
    surface: dark ? '#1E1E22' : '#FFFFFF',
    surfaceElevated: dark ? '#2A2A2E' : '#FFFFFF',
    surfaceMuted: dark ? '#2A2A2E' : '#F2F2F7',
    text: dark ? '#F0F0F5' : '#1C1C1E',
    secondary: dark ? '#98989D' : '#8E8E93',
    tertiary: dark ? '#6C6C72' : '#C7C7CC',
    separator: dark ? '#3A3A3E' : '#E5E5EA',
    accent: '#007AFF',
    accentSoft: dark ? '#17314B' : '#E8F0FE',
    success: '#34C759',
    danger: '#FF3B30',
    warning: '#FF9500',
    shadow: '#000000',
  };
}

export const radius = { small: 10, medium: 16, large: 24, pill: 999 };
export const spacing = { xs: 4, sm: 8, md: 12, lg: 16, xl: 24, xxl: 32 };
