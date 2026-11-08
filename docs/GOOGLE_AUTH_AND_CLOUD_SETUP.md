# Google OAuth and Google Cloud setup

1. Create/select a Google Cloud project and configure OAuth consent screen.
2. Create OAuth clients for Android (package and SHA-1), iOS (bundle ID) and Web.
3. Enable Google in Supabase Dashboard → Authentication → Providers. Enter the Web client ID and secret.
4. Add the Supabase callback URL shown in the dashboard to the Web OAuth client's authorized redirect URIs.
5. Configure Flutter deep links and allowed redirects in Supabase Auth URL settings.
6. Require verified email for password accounts. Test signup, verification, cancellation, revoked consent and session refresh.
7. Create a private GCS bucket with uniform bucket-level access and public access prevention.
8. Create a dedicated service account with narrow bucket-scoped permissions; store credentials only as an Edge Function secret.
9. Configure bucket CORS, lifecycle, retention, monitoring and backup policies.
10. Test signed URL expiry, MIME type, size, group authorization and object overwrite resistance.

Secrets (never commit):
- GOOGLE_OAUTH_CLIENT_ID / GOOGLE_OAUTH_CLIENT_SECRET in Supabase provider settings.
- GOOGLE_CLOUD_PROJECT, GCS_RECEIPTS_BUCKET, GOOGLE_SERVICE_ACCOUNT_JSON in Edge Function secrets.
- APP_ORIGIN and INVITE_BASE_URL in Edge Function secrets.

Google Cloud Storage is for receipts, not the app's database. PostgreSQL is the system of record and Supabase Realtime provides update notifications.
