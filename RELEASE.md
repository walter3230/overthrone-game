# Overthrone - Release Build Instructions

## Prerequisites
- Flutter SDK installed
- Android SDK installed
- Firebase configured (google-services.json in place)

## Build Commands

### Debug Build (testing)
```bash
flutter run
```

### Release APK (local testing)
```bash
flutter build apk --release
```
Output: build/app/outputs/flutter-apk/app-release.apk

### Release App Bundle (Play Store)
```bash
flutter build appbundle --release
```
Output: build/app/outputs/bundle/release/app-release.aab

## Upload to Play Store

1. Go to Google Play Console: https://play.google.com/console
2. Create new app
3. Fill in store listing (use store_listing.txt)
4. Upload app-release.aab to Production track
5. Complete content rating questionnaire
6. Set up pricing & distribution
7. Submit for review

## Notes
- Current build uses debug signing for release (line 37 in build.gradle.kts)
- For production, either:
  a) Let Play Console handle signing (recommended)
  b) Create your own keystore and update signingConfig

## App Bundle Location After Build
build/app/outputs/bundle/release/app-release.aab
