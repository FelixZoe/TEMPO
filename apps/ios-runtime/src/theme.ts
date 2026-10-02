import type { ColorSchemeName } from 'react-native';

export type TempoTheme = ReturnType<typeof makeTheme>;

export function makeTheme(scheme: ColorSchemeName | 'light' | 'dark') {
  const dark = scheme === 'dark';
  return {
    dark,
    background: dark ? '#0C0E10' : '#F7F8FA',
    surface: dark ? '#171A1E' : '#FFFFFF',
    surfaceMuted: dark ? '#20242A' : '#EFF2F6',
    text: dark ? '#F5F6F7' : '#15171A',
    secondary: dark ? '#AEB4BD' : '#656C76',
    tertiary: dark ? '#737B86' : '#9CA3AD',
    separator: dark ? '#2A2F36' : '#E4E7EB',
    accent: dark ? '#79A8FF' : '#356FD6',
    accentSoft: dark ? '#172A49' : '#E8F0FE',
    success: dark ? '#6CCB91' : '#228B55',
    danger: dark ? '#FF8585' : '#C94343',
    warning: dark ? '#E9BB69' : '#A46911',
    shadow: dark ? '#000000' : '#8C97A8',
  };
}

export const radius = { small: 12, medium: 18, large: 26, pill: 999 };
export const spacing = { xs: 6, sm: 10, md: 16, lg: 22, xl: 30 };
