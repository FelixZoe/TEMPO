const fs = require('fs');
const path = require('path');

function resolveAppVersion() {
  if (process.env.TEMPO_APP_VERSION) return process.env.TEMPO_APP_VERSION;

  const pubspec = fs.readFileSync(path.join(__dirname, '..', 'flutter', 'pubspec.yaml'), 'utf8');
  const match = pubspec.match(/^version:\s*([0-9]+\.[0-9]+\.[0-9]+)/m);
  if (!match) throw new Error('Unable to resolve Tempo version from apps/flutter/pubspec.yaml');
  return match[1];
}

function resolveRuntimeVersion() {
  const value = fs.readFileSync(path.join(__dirname, 'runtime-version.txt'), 'utf8').trim();
  if (!/^\d+\.\d+\.\d+$/.test(value)) {
    throw new Error(`Invalid iOS runtime version: ${value}`);
  }
  return value;
}

const appVersion = resolveAppVersion();
const runtimeVersion = resolveRuntimeVersion();
const projectId = '3f6ada73-f58c-47e5-b146-935f18f8ba4c';

module.exports = {
  expo: {
    name: 'Tempo',
    slug: 'tempo-ios-runtime',
    owner: 'felixo1',
    platforms: ['ios'],
    version: appVersion,
    orientation: 'default',
    scheme: 'tempo',
    userInterfaceStyle: 'automatic',
    newArchEnabled: true,
    plugins: [
      ['expo-build-properties', { ios: { usePrecompiledModules: true } }],
      [
        'expo-brownfield',
        {
          ios: {
            targetName: 'TempoRuntime',
            bundleIdentifier: 'one.darker.qingxu.runtime',
          },
        },
      ],
    ],
    ios: {
      bundleIdentifier: 'one.darker.qingxu',
      supportsTablet: true,
    },
    updates: {
      enabled: true,
      checkAutomatically: 'ON_LOAD',
      fallbackToCacheTimeout: 0,
      url: `https://u.expo.dev/${projectId}`,
      requestHeaders: {
        'expo-channel-name': 'production',
      },
    },
    runtimeVersion,
    extra: {
      eas: {
        projectId,
      },
    },
  },
};
