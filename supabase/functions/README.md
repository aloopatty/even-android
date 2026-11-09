# Supabase Edge Functions

Deploy with the Supabase CLI after linking the production project.

- create-group-invite: authenticated group creator only; generates a cryptographically random 256-bit token and stores only its SHA-256 hash. Expiry is 1–30 days; optional use limit.
- accept-group-invite: authenticated redemption; database locks the invite row while membership and usage count are changed atomically.
- create-receipt-upload: authenticated active group member receives a five-minute V4 signed GCS upload URL. Allows JPEG, PNG, WebP and PDF up to 10 MiB.

Required secrets:
APP_ORIGIN, INVITE_BASE_URL, GOOGLE_CLOUD_PROJECT, GCS_RECEIPTS_BUCKET, GOOGLE_SERVICE_ACCOUNT_JSON.

Use a private bucket with uniform bucket-level access and public access prevention. Service account should have bucket-scoped permissions only. Never put service account JSON or Supabase service-role keys in Flutter or Git.
IMPORTANT: Receipt metadata persistence, content scanning, and a separate membership-checked signed download endpoint are still required before enabling receipt upload in production.
