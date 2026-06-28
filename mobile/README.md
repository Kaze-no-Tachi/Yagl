# Yagl — Flutter app (mobile + web)

One Flutter codebase for **iOS, Android, and the web dashboard**. It talks to the
Yagl backend (see [`../backend`](../backend)).

## Prerequisites

- Flutter SDK (stable channel, Dart ≥ 3.3)
- The backend running and reachable (default `http://localhost:8000`)

## First-time setup

This repo ships the app source (`lib/`, `test/`, `pubspec.yaml`) but **not** the
generated platform folders. Generate them once, then fetch packages:

```bash
cd mobile
flutter create --platforms=android,ios,web .   # creates android/ ios/ web/ (keeps lib/ & pubspec)
flutter pub get
```

## Run

Point the app at your API with `--dart-define=API_BASE_URL=...`:

```bash
# Web dashboard
flutter run -d chrome --dart-define=API_BASE_URL=http://localhost:8000

# iOS simulator / device
flutter run -d ios --dart-define=API_BASE_URL=http://localhost:8000

# Android emulator (host machine is 10.0.2.2 from inside the emulator)
flutter run -d android --dart-define=API_BASE_URL=http://10.0.2.2:8000

# Build the web dashboard for deployment
flutter build web --dart-define=API_BASE_URL=https://yagl.example.com
```

> No `API_BASE_URL` defined → defaults to `http://localhost:8000`.

## Camera & photo permissions

Barcode scanning (`mobile_scanner`) and photo capture (`image_picker`) need
camera/library permissions. After `flutter create`, add:

**iOS** — `ios/Runner/Info.plist`:
```xml
<key>NSCameraUsageDescription</key>
<string>Scan game barcodes and take photos of your items.</string>
<key>NSPhotoLibraryUsageDescription</key>
<string>Attach photos of your items from your library.</string>
```

**Android** — `android/app/src/main/AndroidManifest.xml` (inside `<manifest>`):
```xml
<uses-permission android:name="android.permission.CAMERA" />
```
Also ensure `minSdkVersion` is at least 21 (`android/app/build.gradle`).

> On **web**, live camera barcode scanning is unreliable, so the Add screen
> hides the “Scan” button and you enter the barcode (or search by name) instead.

## What's here

| Area | File(s) |
|---|---|
| API client + JWT | `lib/api/api_client.dart` |
| Models | `lib/api/models.dart` |
| Repositories (auth, items, scan, imports) | `lib/api/repositories.dart` |
| State (Riverpod) | `lib/state/providers.dart` |
| Login / register | `lib/features/auth/` |
| Library grid + filters | `lib/features/library/` |
| Add (scan / barcode / search → confirm) | `lib/features/add_item/` |
| Item detail (condition, photos, lending) | `lib/features/item_detail/` |
| Digital import (Steam / CSV) | `lib/features/import/` |

## Test

```bash
flutter test
```
