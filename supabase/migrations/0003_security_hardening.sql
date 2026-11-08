-- EVEN security hardening: explicitly deny implicit PUBLIC RPC execution.
-- Additive migration; does not alter or delete user data.

-- SECURITY DEFINER functions are privileged entry points. PostgreSQL grants
-- EXECUTE to PUBLIC by default, so grant only the application RPCs to
-- authenticated users. Trigger execution is unaffected by revoking direct
-- invocation of the trigger function.
revoke execute on all functions in schema public from public, anon, authenticated;

grant execute on function public.create_group(text, char(3), text) to authenticated;
grant execute on function public.create_group_expense(uuid, text, bigint, char(3), uuid, text, text, text, timestamptz, jsonb, uuid) to authenticated;
grant execute on function public.update_group_expense(uuid, integer, text, bigint, char(3), uuid, text, text, text, timestamptz, jsonb) to authenticated;
grant execute on function public.delete_group_expense(uuid, text) to authenticated;
grant execute on function public.record_group_settlement(uuid, uuid, uuid, bigint, char(3), text, timestamptz) to authenticated;
grant execute on function public.create_group_invite(uuid, text, timestamptz, integer) to authenticated;
grant execute on function public.accept_group_invite(text) to authenticated;
grant execute on function public.revoke_group_invite(uuid) to authenticated;

-- Remove any broad/default table grants on profiles, then restore only the
-- operations required by the client. Profiles are created by the auth trigger;
-- clients must not be able to insert arbitrary profile IDs.
revoke all privileges on table public.profiles from public, anon, authenticated;
grant select on table public.profiles to authenticated;
grant update (display_name, avatar_url, preferred_currency, updated_at)
  on table public.profiles to authenticated;

-- The idempotency ledger is server-managed only.
revoke all privileges on table public.idempotency_keys from public, anon, authenticated;

-- Keep the private helper schema unavailable through the Data API.
revoke all on schema private from public, anon, authenticated;
grant usage on schema private to authenticated;
revoke execute on all functions in schema private from public, anon, authenticated;
grant execute on function private.is_group_member(uuid, uuid) to authenticated;
grant execute on function private.is_group_owner(uuid, uuid) to authenticated;
