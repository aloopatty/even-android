# Google OAuth and Google Cloud setup

## Supabase project and Android build

1. In Supabase Dashboard → Project Settings → API, copy the **Project URL** and **publishable key**.
2. In GitHub → repository Settings → Secrets and variables → Actions, set:
   - `SUPABASE_URL` = the exact Project URL, including `https://`, with no trailing slash.
   - `SUPABASE_PUBLISHABLE_KEY` = the project's publishable key (never the secret/service-role key).
3. Rebuild the APK after changing either secret. GitHub secrets are injected only at build time; changing a secret does not update an already-installed APK.
4. Confirm the project is not paused and the phone can open the Project URL in its browser.

## Email one-time codes

1. In Supabase Dashboard → Authentication → Providers → Email, keep Email enabled.
2. In Authentication → Email Templates → **Magic Link**, change the message body to include the numeric token, for example:
   `Your EVEN verification code is {{ .Token }}`
   Do not use only `{{ .ConfirmationURL }}` when the app expects a code entry.
3. In Authentication → URL Configuration, add this exact mobile redirect URL to **Redirect URLs**:
   `even://login-callback`
4. Check Auth rate limits and SMTP delivery configuration. For real users, configure a reliable custom SMTP provider and verify its sender domain. The built-in email service is rate-limited and is intended for testing.
5. Test with a real inbox and check spam/junk. Requesting a code successfully does not guarantee delivery if SMTP is not configured.

## Google sign-in

1. Create/select a Google Cloud project and configure the OAuth consent screen.
2. Create a **Web application** OAuth client. Add the exact Supabase callback URL shown in Supabase Authentication → Providers → Google to its Authorized redirect URIs. It has this form:
   `https://<project-ref>.supabase.co/auth/v1/callback`
3. Enable Google in Supabase Dashboard → Authentication → Providers → Google. Enter the Web client ID and client secret.
4. In Supabase Authentication → URL Configuration → Redirect URLs, add:
   `even://login-callback`
5. The Android app's package/deep-link callback is `even://login-callback`. Keep this value identical in the app, Android manifest, and Supabase allowed redirect URLs.
6. Test Google sign-in on a physical Android device. After Google consent, Android must return to EVEN and Supabase must establish a session.

## Google Cloud Storage receipts

1. Create a private GCS bucket with uniform bucket-level access and public access prevention.
2. Create a dedicated service account with narrow bucket-scoped permissions; store credentials only as an Edge Function secret.
3. Configure bucket CORS, lifecycle, retention, monitoring and backup policies.
4. Test signed URL expiry, MIME type, size, group authorization and object overwrite resistance.

Secrets (never commit):
- `GOOGLE_OAUTH_CLIENT_ID` / `GOOGLE_OAUTH_CLIENT_SECRET` in Supabase provider settings.
- `GOOGLE_CLOUD_PROJECT`, `GCS_RECEIPTS_BUCKET`, `GOOGLE_SERVICE_ACCOUNT_JSON` in Edge Function secrets.
- `APP_ORIGIN` and `INVITE_BASE_URL` in Edge Function secrets.

Google Cloud Storage is for receipts, not the app's database. PostgreSQL is the system of record and Supabase Realtime provides update notifications.
