# Even — Android expense sharing

Even is a minimalist shared-expense Android app built with Flutter. It is designed around quick expense entry, clear group/personal separation, and transparent balances.

## Current app

- Personal expenses are separate from named groups.
- Open a personal or group space before adding an expense.
- Add and remove participants with a people picker; choose the payer from the selected participants.
- Split expenses equally, by exact amounts, percentages, or weighted shares.
- View expense activity and open a transaction for its payer and participant-share breakdown.
- Copy a ready-to-send reminder message from a transaction.
- Record a settlement after a payment has been made outside the app.
- Purple/indigo visual identity with Android system light/dark appearance.
- INR amounts are stored as integer paise to avoid floating-point accounting errors.

## Build an Android APK

The repository uses GitHub Actions so a Windows computer does not need a local Flutter/Android build setup.

1. Open the repository's **Actions** tab.
2. Select **Build EVEN Android APK**.
3. Open the latest successful run on `main`.
4. Under **Artifacts**, download `even-android-release`.
5. Extract the downloaded ZIP and install `app-release.apk` on your Android phone.
6. If Android asks, allow your browser or file manager to install unknown apps.

Pushes to `main` and pull requests targeting `main` run the same Flutter analysis, tests, and release APK build.

## Local development

Requirements: Flutter stable and the Android SDK.

```bash
flutter pub get
flutter analyze
flutter test
flutter build apk --release
```

The APK is generated at `build/app/outputs/flutter-apk/app-release.apk`.

## Important scope notes

- The current app stores data locally on the device. Cloud accounts and cross-device sync are not implemented yet.
- Reminder actions copy text; they do not send messages automatically.
- Settlement records a payment already made externally; the app does not initiate UPI or bank transfers.
- The GitHub Actions APK is for testing. Before Play Store distribution, configure and protect an Android release-signing key and complete production QA.
- Confirm trademark, domain, and app-store availability before public launch.
