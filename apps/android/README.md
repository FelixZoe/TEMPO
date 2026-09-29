# TEMPO Android

TEMPO Android is an independent Flutter client derived from
[FelixZoe/flowtime](https://github.com/FelixZoe/flowtime). The Android client
keeps Flowtime's mature layout and interaction foundation while using TEMPO's
brand, release pipeline, and stable application identity.

## Identity

- Visible name: `TEMPO`
- Meaning: `Time. Everything. Moments. Productivity. Organized.`
- Chinese expression: `时间、信息、当下与效率，一切井然有序。`
- Android application ID: `one.darker.qingxu`

The application ID remains unchanged so existing installations can be upgraded
in place when the APK is signed with the same Android signing key.

## Development

```bash
cd apps/android
flutter pub get
flutter analyze --no-fatal-infos --no-fatal-warnings
flutter test
flutter run
```

Release builds are produced by `.github/workflows/build-release.yml` and are
published as `TEMPO-<version>-Android.apk`.

## Attribution

The imported Flowtime source is licensed under the MIT License. Its license is
preserved in [FLOWTIME_LICENSE](./FLOWTIME_LICENSE), and the project-level
notice is recorded in `THIRD_PARTY_NOTICES.md`.
