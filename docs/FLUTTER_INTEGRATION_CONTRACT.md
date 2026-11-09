# Flutter backend integration contract

Packages: add compatible stable supabase_flutter and app_links versions after checking the current Flutter/Dart constraints. Keep SQLite as a cache/outbox.

Authentication:
- Email signup: auth.signUp(email,password,data:{full_name}); require verified email.
- Email login: auth.signInWithPassword.
- Google: Supabase OAuth provider Google with redirect even://login-callback; configure Android/iOS deep links.
- Logout clears cached private data and user-scoped pending state.
- Account deletion must be a verified server-side workflow.

Group creation: RPC create_group(p_name,p_currency,p_description). Owner membership is created atomically.

Expense creation: RPC create_group_expense with group ID, title, amount_minor, currency, payer UUID, split method, category, note, occurred_at, JSON splits [{user_id,amount_minor}], and a stable idempotency UUID. Payer is independent of participants. All IDs are authenticated user UUIDs, never display names.

Edit: update_group_expense with current version. Only group creator succeeds. A stale version returns SQLSTATE 40001.
Delete: delete_group_expense; creator only; soft deletion and audit event.
Settlement: record_group_settlement records an external payment only.
Invites: invoke create-group-invite; recipient authenticates and invokes accept-group-invite with token. Do not expose membership through client-supplied IDs.
Realtime: subscribe to group changes and refetch canonical state after an event.
Offline: persist pending operations in an outbox, reuse idempotency UUID on retry, and show pending/failed states. Never silently overwrite a newer server version.
