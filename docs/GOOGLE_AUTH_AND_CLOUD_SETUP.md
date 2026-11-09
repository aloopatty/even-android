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
2. In Authentication → Email Templates → **Magic Link**, set the subject to:
   `Your EVEN sign-in code`
3. Replace the template body with this minimal, text-only branded HTML. It intentionally contains no image and no confirmation URL:
   ```html
   <div style="font-family:Arial,sans-serif;max-width:480px;margin:0 auto;padding:32px 24px;color:#211D30">
     <div style="font-size:22px;font-weight:700;letter-spacing:3px;color:#7568D8">EVEN</div>
     <h2 style="font-size:20px;margin:28px 0 8px">Your sign-in code</h2>
     <p style="font-size:14px;line-height:1.6;color:#625D70">Use this one-time code to verify your email address and continue to your EVEN account.</p>
     <div style="margin:24px 0;padding:18px;background:#F0EEFA;border-radius:12px;text-align:center;font-size:30px;letter-spacing:8px;font-weight:700;color:#211D30">{{ .Token }}</div>
     <p style="font-size:12px;line-height:1.6;color:#777184">This code can only be used once and expires shortly. If you did not request it, you can safely ignore this email.</p>
     <p style="font-size:12px;color:#8A8498;margin-top:28px">EVEN · Shared expenses, made clearer.</p>
   </div>
   ```
4. The app calls `signInWithOtp` and verifies the entered number with `verifyOTP(type: OtpType.email)`. The email template must therefore include `{{ .Token }}`, not only `{{ .ConfirmationURL }}`. A confirmation URL may send users to the configured Site URL (for example localhost:3000) instead of opening the Android app.
5. In Authentication → URL Configuration, add this exact mobile redirect URL to **Redirect URLs**:
   `even://login-callback`
6. Check Auth rate limits and SMTP delivery configuration. For real users, configure a reliable custom SMTP provider and verify its sender domain. The built-in email service is rate-limited and is intended for testing.
7. Test with a real inbox: the email should show a numeric code, not a clickable sign-in link.

## Google profile onboarding

The Android app requires Google users to complete a profile after OAuth verification:
- **Username:** 3–20 characters, lowercase letters, numbers or underscores; unique across EVEN.
- **Display name:** 1–60 characters; may be shared by multiple users.
- Apply the database migration `supabase/migrations/0004_profile_usernames.sql` before testing this screen. Existing Google users with no username will be prompted on their next sign-in.
- The database enforces username uniqueness. Never rely only on a client-side availability check.

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
