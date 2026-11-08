# Connecting the EVEN Flutter app to Supabase

The app reads its Supabase connection values at build/run time. Do not paste credentials into Dart source files or commit a local secrets file.

## Required values

- Project URL: the base URL, for example `https://YOUR_PROJECT_REF.supabase.co` (do not include `/rest/v1/`).
- Publishable key: the `sb_publishable_...` key from Supabase Project Settings → API Keys.

The publishable key is intended for client applications. Database access must still be protected by Row Level Security (RLS). Never use a Supabase secret key or legacy `service_role` key in Flutter.

## Run on Windows PowerShell

From the EVEN project root (the folder containing `pubspec.yaml`):

```powershell
flutter pub get
flutter run --dart-define=SUPABASE_URL=https://YOUR_PROJECT_REF.supabase.co --dart-define=SUPABASE_PUBLISHABLE_KEY=YOUR_PUBLISHABLE_KEY
```

Replace the two placeholders with your own values. Keep the command private if you have copied your publishable key into terminal history.

For an APK:

```powershell
flutter build apk --release --dart-define=SUPABASE_URL=https://YOUR_PROJECT_REF.supabase.co --dart-define=SUPABASE_PUBLISHABLE_KEY=YOUR_PUBLISHABLE_KEY
```

## Current scope

This bootstrap initializes the Supabase client only when both values are supplied. It intentionally leaves the existing local-first UI running if values are absent. It does not yet enable login, cloud writes, realtime sync, or migration of local SQLite data. Those are separate steps and must be implemented and tested before the app is described as cloud-connected.
