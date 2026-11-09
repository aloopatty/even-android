-- EVEN backend hardening: durable idempotency for retry-safe expense creation.
-- This is deliberately additive and does not rewrite existing expense data.

create table if not exists public.idempotency_keys (
  user_id uuid not null references auth.users(id) on delete cascade,
  idempotency_key uuid not null,
  operation text not null check (operation in ('create_group_expense')),
  request_hash text not null check (length(request_hash) = 64),
  resource_id uuid,
  created_at timestamptz not null default now(),
  primary key (user_id, idempotency_key)
);

alter table public.idempotency_keys enable row level security;
revoke all on public.idempotency_keys from anon, authenticated;

create or replace function public.create_group_expense(
 p_group_id uuid,p_title text,p_amount_minor bigint,p_currency char(3),p_paid_by uuid,
 p_split_method text,p_category text,p_note text,p_occurred_at timestamptz,p_splits jsonb,p_idempotency_key uuid
) returns uuid
language plpgsql security definer
set search_path=public,private,pg_temp
as $$
declare
 v_id uuid;
 v_sum numeric;
 v_count integer;
 v_user uuid;
 v_hash text;
 v_existing public.idempotency_keys%rowtype;
begin
 if auth.uid() is null then
  raise exception 'authentication required' using errcode='28000';
 end if;
 if p_idempotency_key is null then raise exception 'idempotency key is required'; end if;

 -- Hash every semantic input. A retry with the same key but altered data is rejected.
 v_hash := encode(digest(jsonb_build_object(
   'group_id',p_group_id,'title',trim(p_title),'amount_minor',p_amount_minor,
   'currency',upper(p_currency::text),'paid_by',p_paid_by,'split_method',p_split_method,
   'category',coalesce(p_category,'Other'),'note',p_note,
   'occurred_at',coalesce(p_occurred_at,now()),'splits',p_splits
 )::text,'sha256'),'hex');

 insert into public.idempotency_keys(user_id,idempotency_key,operation,request_hash)
 values(auth.uid(),p_idempotency_key,'create_group_expense',v_hash)
 on conflict(user_id,idempotency_key) do nothing;

 select * into v_existing from public.idempotency_keys
 where user_id=auth.uid() and idempotency_key=p_idempotency_key for update;

 if v_existing.request_hash <> v_hash then
  raise exception 'idempotency key was already used for a different request' using errcode='22023';
 end if;
 if v_existing.resource_id is not null then return v_existing.resource_id; end if;

 if not private.is_group_member(p_group_id) then
  raise exception 'not a group member' using errcode='42501';
 end if;
 if p_amount_minor<=0 or char_length(trim(p_title)) not between 1 and 160 then
  raise exception 'invalid expense';
 end if;
 if p_split_method not in ('equal','exact','percentage','shares') then
  raise exception 'invalid split method';
 end if;
 if not private.is_group_member(p_group_id,p_paid_by) then
  raise exception 'payer must be a group member';
 end if;
 if jsonb_typeof(p_splits)<>'array' or jsonb_array_length(p_splits)=0 then
  raise exception 'at least one split required';
 end if;
 select coalesce(sum((x->>'amount_minor')::bigint),0),count(*)
 into v_sum,v_count from jsonb_array_elements(p_splits) x;
 if v_sum<>p_amount_minor or v_count<>(select count(distinct x->>'user_id') from jsonb_array_elements(p_splits) x) then
  raise exception 'split amounts must be unique and sum to total';
 end if;
 for v_user in select (x->>'user_id')::uuid from jsonb_array_elements(p_splits) x loop
  if not private.is_group_member(p_group_id,v_user) then
   raise exception 'participants must be active group members';
  end if;
 end loop;

 insert into public.expenses(group_id,title,amount_minor,currency,paid_by,split_method,category,note,occurred_at,created_by,updated_by)
 values(p_group_id,trim(p_title),p_amount_minor,upper(p_currency),p_paid_by,p_split_method,
        coalesce(p_category,'Other'),p_note,coalesce(p_occurred_at,now()),auth.uid(),auth.uid())
 returning id into v_id;

 insert into public.expense_splits(expense_id,user_id,amount_minor)
 select v_id,(x->>'user_id')::uuid,(x->>'amount_minor')::bigint
 from jsonb_array_elements(p_splits) x;

 update public.idempotency_keys set resource_id=v_id
 where user_id=auth.uid() and idempotency_key=p_idempotency_key;

 perform private.audit(p_group_id,'expense',v_id,'created',
   jsonb_build_object('amount_minor',p_amount_minor,'currency',upper(p_currency)));
 return v_id;
end $$;

grant execute on function public.create_group_expense(uuid,text,bigint,char(3),uuid,text,text,text,timestamptz,jsonb,uuid) to authenticated;
