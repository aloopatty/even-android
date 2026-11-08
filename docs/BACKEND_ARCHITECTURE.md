# EVEN production backend architecture

## System of record
PostgreSQL is authoritative. Flutter SQLite is a cache and durable offline outbox only. Do not use last-write-wins for money.

## Rules enforced server-side
- A group creator is the immutable owner. Any active member can add expenses; only the creator can edit or soft-delete expenses.
- The payer is independent of participants, but must be an active group member. Every split participant must be an active member. Splits are unique, non-negative integer minor units and sum exactly to the expense amount.
- Expense updates require an expected version. Stale updates fail rather than silently overwriting.
- Settlements record external payments; EVEN does not move money.
- Invite links are high entropy, hashed at rest, expiring, revocable and optionally use-limited.
- RLS protects reads; security-definer RPCs validate writes. Never rely on hiding UI controls.
- Currency is ISO 4217 and all monetary values are integer minor units. Never aggregate unlike currencies without an explicit conversion record.

## Google sign-in
Enable Google provider in Supabase Auth. Create OAuth clients in Google Cloud Console for Android package/signing SHA-1, iOS bundle ID and Web. The Web client callback must be the Supabase Auth callback URL. Configure deep-link redirects for the Flutter app. Never put OAuth client secrets or service-role credentials in Flutter.

## Google Cloud Storage
Use a private GCS bucket for receipt images and PDFs. The Edge Function issues short-lived signed upload URLs after checking authenticated group membership. Keep service-account credentials in Edge Function secrets, never in the repository or app. PostgreSQL remains the database and source of truth; GCS is object storage, not sync.

## Realtime and offline
Realtime events are invalidation hints; refetch authoritative rows. Local outbox operations have stable UUIDs and base versions. Retry with the same idempotency key. Migration 0002 adds a server-managed idempotency ledger keyed by authenticated user and request UUID. Reuse the same key for every retry; reusing it with changed request data is rejected. Always send a stable occurred_at timestamp so the request hash remains stable.

## Before public launch
Configure real Supabase project and OAuth credentials; add durable idempotency; add receipt metadata/download authorization; member leave/remove and ownership transfer flows; account deletion/export; rate limiting and invitation throttling; database integration tests for RLS and all RPCs; pagination; backup restore drills; monitoring/alerts; privacy and legal review; load, concurrency and penetration tests; Flutter auth/deep-link/outbox/realtime integration.
