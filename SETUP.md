# HealChain — Developer Setup Guide

## Prerequisites

1. **Flutter SDK** (≥ 3.11.1) — [Install Flutter](https://docs.flutter.dev/get-started/install)
2. **Android Studio** or **VS Code** with Flutter/Dart extensions
3. **Java JDK 17** (for Android builds)
4. **Firebase CLI** (optional, for Firestore rules deployment)

## Quick Start

```bash
# 1. Clone or unzip the project
cd lifelink

# 2. Install dependencies
flutter pub get

# 3. Run the app
flutter run
```

## Shared Debug Keystore (No SHA-1 Setup Needed!)

The project includes a **shared debug keystore** (`android/debug.keystore`) so that all developers and laptops use the exact same SHA-1 fingerprint. This means:

✅ **No need to register SHA-1 per laptop**
✅ **Google Sign-In works immediately** after `flutter pub get && flutter run`
✅ **Just zip and transfer** — it works on any machine with Flutter installed

> **How it works:** The `android/app/build.gradle.kts` is configured to use the project-bundled `android/debug.keystore` instead of each developer's personal `~/.android/debug.keystore`.

## Firebase Configuration

The project uses Firebase for authentication, Firestore, messaging, and storage.
The `google-services.json` (Android) is included in the repo and works with the shared Firebase project.

## API Keys (AI Chatbot)

AI chatbot uses Gemini and OpenRouter APIs. Keys are stored **securely in Firestore** (not in source code).

### Setup:
1. Log in as **Admin** in the app
2. Go to **Settings** tab → **API Providers** section
3. Enter your Gemini and/or OpenRouter API keys
4. Click **Save** — keys are stored in Firestore (`admin_settings/api_keys`)
5. Use **Run Diagnostics** to test if the keys are working (live API test)

### Manual Firestore setup (alternative):
Go to Firebase Console → Firestore → `admin_settings` collection → `api_keys` document → create with fields:
- `gemini_key` (string)
- `openrouter_key` (string)
- `gemini_enabled` (boolean: true)
- `openrouter_enabled` (boolean: true)
- `provider_order` (array: ["gemini", "openrouter"])

## Moving to Another Laptop

1. **Zip** the entire project folder
2. **Unzip** on the new laptop
3. Run:
   ```bash
   flutter pub get
   flutter run
   ```
4. That's it! The shared keystore ensures Google Sign-In works automatically.

> **Note:** The `android/local.properties` file is auto-generated per machine and is git-ignored. Flutter recreates it automatically on the new laptop.

## Project Structure

```
lib/
├── app.dart                  # MaterialApp with theme & scroll config
├── main.dart                 # Entry point, Firebase init
├── config/
│   ├── constants.dart        # App-wide constants
│   ├── routes.dart           # GoRouter navigation
│   └── theme.dart            # AppTheme (colors, gradients, ThemeData)
├── models/                   # Data models
├── providers/                # State management (ChangeNotifier)
├── screens/                  # UI screens
├── services/                 # Business logic & API services
└── widgets/                  # Reusable UI components
```

## Troubleshooting

| Issue | Solution |
|-------|----------|
| `pub get` fails | Run `flutter pub get` (not just `pub get`) |
| Google Sign-In fails | Should work automatically with shared keystore. If not, run `flutter clean && flutter pub get` |
| Gradle build fails | Ensure Java 17 is installed and `JAVA_HOME` is set |
| iOS build fails | Run `cd ios && pod install && cd ..` |
| "No Firebase App" error | Ensure `google-services.json` exists in `android/app/` |
| AI chatbot not responding | Check Firestore `admin_settings/api_keys` has valid keys. Use Admin → Settings → Run Diagnostics to test |

## Building for Release

```bash
flutter build apk --release
flutter build appbundle --release  # For Play Store
```
