# ClearTok Pro — Reborn (Open Engine)

High-performance, unconstrained TikTok Repost management & batch un-reposting engine built on Flutter/Dart, reverse-engineered and reconstructed from original binaries.

## 🚀 Key Architectural Improvements
- **100% Unlimited**: Zero paywalls, no RevenueCat gating, no 100/day artificial quotas.
- **OTA Dynamic Script Injection**: Reads live TikTok API endpoints and headers from `config/remote_payload.json`. No app updates required when TikTok tweaks internal API routes.
- **Anti-Bot Jitter Controller**: Emulates human interactions with randomized delays (600ms - 1200ms) and automatic cooldown on HTTP 429 / rate limits.
- **Native Android Foreground Service**: Background sync support with ongoing notifications.
- **Embedded Hive NoSQL Storage**: High-throughput offline caching for tens of thousands of repost records.

## 🛠 Project Structure
- `lib/api/`: Headless WebKit request execution & cookie capture.
- `lib/core/`: Remote config synchronization and JavaScript generator.
- `lib/database/`: Hive NoSQL local boxes (`reposts_box`, `history_box`, `settings_box`).
- `lib/models/`: Clean Dart models with JSON serialization.
- `lib/services/`: Batch deletion orchestration engine with pause/resume/stop controls.
- `lib/ui/`: Material 3 dark-themed user interface.
- `config/remote_payload.json`: OTA configuration file controlling endpoints dynamically.

## 📱 Build Instructions
Ensure Flutter 3.x is installed:
```bash
flutter pub get
flutter build apk --release
```
Artifact will be generated at `build/app/outputs/flutter-apk/app-release.apk`.
