# Plant Reminder Feature - Setup Instructions

## 📦 Required Dependencies

Add these dependencies to your `pubspec.yaml` file:

```yaml
dependencies:
  flutter_local_notifications: ^17.0.0
  timezone: ^0.9.2
  intl: ^0.19.0
```

Then run:
```bash
flutter pub get
```

## 🔧 Android Configuration

### 1. Update `android/app/src/main/AndroidManifest.xml`

Add these permissions inside the `<manifest>` tag:

```xml
<uses-permission android:name="android.permission.RECEIVE_BOOT_COMPLETED"/>
<uses-permission android:name="android.permission.VIBRATE" />
<uses-permission android:name="android.permission.USE_FULL_SCREEN_INTENT" />
<uses-permission android:name="android.permission.POST_NOTIFICATIONS"/>
<uses-permission android:name="android.permission.SCHEDULE_EXACT_ALARM"/>
```

Add this inside the `<application>` tag:

```xml
<receiver android:exported="false" android:name="com.dexterous.flutterlocalnotifications.ScheduledNotificationReceiver" />
<receiver android:exported="false" android:name="com.dexterous.flutterlocalnotifications.ScheduledNotificationBootReceiver">
    <intent-filter>
        <action android:name="android.intent.action.BOOT_COMPLETED"/>
        <action android:name="android.intent.action.MY_PACKAGE_REPLACED"/>
        <action android:name="android.intent.action.QUICKBOOT_POWERON" />
        <action android:name="com.htc.intent.action.QUICKBOOT_POWERON"/>
    </intent-filter>
</receiver>
```

### 2. Update `android/app/build.gradle`

Ensure minimum SDK version is 21 or higher:

```gradle
android {
    defaultConfig {
        minSdkVersion 21  // Must be 21 or higher
    }
}
```

## 🍎 iOS Configuration

### 1. Update `ios/Runner/AppDelegate.swift`

Add this code:

```swift
import UIKit
import Flutter

@UIApplicationMain
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    if #available(iOS 10.0, *) {
      UNUserNotificationCenter.current().delegate = self as UNUserNotificationCenterDelegate
    }
    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
```

### 2. Update `ios/Runner/Info.plist`

Add notification permissions:

```xml
<key>UIBackgroundModes</key>
<array>
    <string>fetch</string>
    <string>remote-notification</string>
</array>
```

## ✅ Features Implemented

### 1. **Reminder Model** (`reminder_model.dart`)
- Plant name
- Task type (Watering, Fertilizing, Soil check, etc.)
- Date & Time
- Completion status
- Smart filters: Pending, Today, Upcoming

### 2. **Reminder Provider** (`reminder_provider.dart`)
- Create, read, update, delete reminders
- Persistent storage with SharedPreferences
- Automatic notification scheduling
- Filter by status (pending/today/upcoming)

### 3. **Notification Service** (`notification_service.dart`)
- Schedule notifications at specific date/time
- Cancel notifications
- Handle notification permissions
- Support for Android & iOS

### 4. **Reminder Screen** (`plant_reminder_screen.dart`)
- Tab-based interface (Pending, Today, Upcoming)
- Color-coded task types
- Mark reminders as complete
- Delete reminders
- Beautiful UI with plant-themed colors

### 5. **Add Reminder Dialog** (`add_reminder_dialog.dart`)
- Plant name input
- Task type dropdown (8 types)
- Date picker
- Time picker
- Form validation

### 6. **Integration Points**
- ✅ Home Screen → "Plant Reminder" card
- ✅ Result Screen → New "Reminder" tab (5th tab)
- ✅ Pre-filled plant name when adding from result screen

## 🎨 Task Types & Colors

| Task Type | Icon | Color |
|-----------|------|-------|
| Watering the plant | 💧 | Blue (#2196F3) |
| Adding fertilizer | 🌱 | Green (#4CAF50) |
| Soil check | 🏔️ | Brown (#795548) |
| Cutting the plant | ✂️ | Red (#FF5722) |
| Repotting | ⬆️ | Purple (#9C27B0) |
| Pest control | 🐛 | Orange |
| Pruning | ✂️ | Red |
| Misting | 💦 | Blue |

## 🚀 Usage Flow

### From Home Screen:
1. Tap "Plant Reminder" card
2. View reminders in tabs (Pending/Today/Upcoming)
3. Tap "Add Reminder" button
4. Fill in details and save

### From Plant Analysis Result:
1. After identifying a plant
2. Go to "Reminder" tab (5th tab)
3. Tap "Add New Reminder"
4. Plant name is pre-filled
5. Select task type, date & time
6. Save reminder

## 📱 Notification Behavior

- **Scheduled**: Notifications fire at exact date/time
- **Permission**: Auto-requests on first launch
- **Cancellation**: Auto-cancelled when reminder is deleted or marked complete
- **Persistence**: Survives app restarts
- **Android 13+**: Requires runtime notification permission

## 🔔 Testing Notifications

1. Create a reminder for 1-2 minutes in the future
2. Close the app
3. Wait for the scheduled time
4. Notification should appear with:
   - Title: "[Task Type] Reminder"
   - Body: "Time to [task] your [plant name]"

## 📝 Notes

- Reminders are stored locally using SharedPreferences
- Notifications use flutter_local_notifications
- Timezone support for accurate scheduling
- Works offline (no internet required)
- Beautiful, plant-themed UI matching app design

## 🎯 Next Steps

1. Add dependencies to pubspec.yaml
2. Configure Android manifest
3. Configure iOS permissions
4. Run `flutter pub get`
5. Test on real device (notifications don't work on simulators/emulators reliably)

---

**All files have been created and integrated!** 🎉
