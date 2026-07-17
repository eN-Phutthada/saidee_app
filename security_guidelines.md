# Saidee App Security Guidelines

This document outlines the security measures implemented in the Saidee App and provides instructions for secure deployments.

## 1. Code Obfuscation (การพรางโค้ด)

To protect the app from being easily reverse-engineered by hackers, you MUST build the release version of the application using Flutter's built-in code obfuscation.

**Command for Android App Bundle (AAB):**
```bash
flutter build appbundle --obfuscate --split-debug-info=build/app/outputs/symbols
```

**Command for Android APK:**
```bash
flutter build apk --obfuscate --split-debug-info=build/app/outputs/symbols
```

**Command for iOS:**
```bash
flutter build ipa --obfuscate --split-debug-info=build/app/outputs/symbols
```

*Note: Keep the files generated in the `symbols` directory in a safe place. They are required if you need to de-obfuscate crash logs later.*

## 2. Screenshot Prevention

Screenshot prevention has been applied to sensitive screens using `flutter_windowmanager_plus`:
- `ProfileScreen`
- `PrivacyPolicyScreen`

When users enter these screens on Android, they cannot take a screenshot or record the screen. The content will appear completely black in screenshots or multitasking views.

## 3. Root / Jailbreak Detection

The app checks for modified device environments during the `SplashScreen` initialization.
If the device is detected as Rooted (Android) or Jailbroken (iOS), a security warning dialog is shown, and the user is forced to exit the app. This prevents runtime memory injection and other exploitation techniques.

## 4. Git Security

- A `pre-commit` hook is located at `.git/hooks/pre-commit` to prevent accidental commits of API Keys (like Xendit, SlipOK, or Google Maps).
- The `.gitignore` file has been updated to ignore Firebase configuration files (`google-services.json`, `GoogleService-Info.plist`) and any `.env` files to prevent secret leakage into the repository.
