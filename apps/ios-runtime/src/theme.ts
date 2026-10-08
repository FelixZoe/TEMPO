import type { ColorSchemeName } from 'react-native';

export type TempoTheme = ReturnType<typeof makeTheme>;

export function makeTheme(scheme: ColorSchemeName | 'light' | 'dark') {
  const dark = scheme === 'dark';
  return {
    dark,
    background: dark ? '#000000' : '#F7F9FC',
    surface: dark ? '#0C0F14' : '#FFFFFF',
    surfaceElevated: dark ? '#151A21' : '#FFFFFF',
    surfaceMuted: dark ? '#12161D' : '#EEF3F8',
    text: dark ? '#F5F7FA' : '#05070A',
    secondary: dark ? '#A7AFBA' : '#606A76',
    tertiary: dark ? '#68727F' : '#98A1AC',
    separator: dark ? '#2A303A' : '#DCE2E9',
    accent: '#1D7FF2',
    accentSoft: dark ? '#0B315D' : '#E8F2FF',
    success: '#34C759',
    danger: '#FF3B30',
    warning: '#FF9500',
    shadow: '#000000',
  };
}

export const radius = { small: 10, medium: 16, large: 24, pill: 999 };
export const spacing = { xs: 4, sm: 8, md: 12, lg: 16, xl: 24, xxl: 32 };
