# 📡 Phone Tracker

An offline Bluetooth device tracker built with Flutter. Detects nearby 
Bluetooth devices, estimates distance using RSSI signal strength, and 
allows users to pin and monitor specific devices — all without internet.

## Demo

> Screenshots coming soon

## Features

- 🔍 **Real-time BLE scanning** — detects all nearby Bluetooth devices instantly
- 📏 **Distance estimation** — calculates approximate distance using RSSI 
  path-loss model
- 📌 **Device pinning** — pin a specific device to monitor it separately
- 🔎 **Search** — filter devices by name or MAC address
- 📡 **Beacon broadcasting** — broadcast this device so others running 
  the app can detect it
- 🌙 **Dark theme** — full dark mode support

## The Technical Challenge

Modern Android phones (12+) use **MAC address randomization** — they 
broadcast a different random MAC address every time Bluetooth turns on, 
making it impossible to identify a phone by its MAC address alone.

This app solves that using a **UUID-based identification system**:
- Each device running the app generates a permanent UUID stored locally
- This UUID is embedded in the BLE advertisement payload
- The scanner identifies devices by UUID, not MAC address
- Works even when MAC address changes every session

## Tech Stack

- **Flutter** — cross-platform mobile framework
- **flutter_blue_plus** — BLE scanning and advertising
- **permission_handler** — runtime permission management  
- **shared_preferences** — persistent local storage for device UUID

## Architecture Decisions

Works entirely over Bluetooth — no internet connection required. 
Firebase integration planned for location history and remote alerts.

**Why UUID over MAC address?**
Android 12+ randomizes Bluetooth MAC addresses for privacy. Using a 
self-generated UUID embedded in the BLE payload ensures reliable 
device identification regardless of MAC changes.

**Stream lifecycle management**
All BLE stream subscriptions are stored and cancelled in `dispose()` 
to prevent memory leaks and setState calls on unmounted widgets.

## Getting Started

### Prerequisites
- Flutter SDK
- Android phone (Android 8.0+)
- Bluetooth enabled

### Installation

```bash
git clone https://github.com/Krishnadevelop/Phone-Tracker-.git
cd Phone-Tracker-/tracker
flutter pub get
flutter run
```

### Permissions required
- Bluetooth Scan
- Bluetooth Connect
- Bluetooth Advertise
- Location (required by Android for BLE scanning)

## Current Status

| Feature | Status |
|---|---|
| BLE scanning |  Working |
| Distance calculation |  Working |
| Search and filtering |  Working |
| Device pinning |  Working |
| Dark theme |  Working |
| BLE broadcasting |  In progress |
| Phone-to-phone identification | In progress |
| Proximity alerts |  Planned |
| Persistent device naming |  Planned |

## Known Limitations

- Distance calculation is an estimate based on the RSSI path-loss model — 
  accuracy varies with environment, obstacles, and device orientation
- BLE range is hardware limited to approximately 10-15m indoors
- Phones with MAC randomization enabled will not show a device name 
  unless they are also running this app

## What I Learned

- BLE protocol fundamentals — scanning, advertising, RSSI, service UUIDs
- Android Bluetooth permission model changes across API levels
- Stream subscription lifecycle management in Flutter
- MAC address randomization in Android 12+ and privacy implications
- Dart async patterns — StreamSubscription, async/await, mounted checks

## Author

**Mridul** — 4th semester CS student  
Building this as a learning project to understand BLE, Flutter, 
and offline-first mobile architecture.
