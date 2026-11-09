create extension if not exists pgcrypto;
create schema if not exists private;

create table public.profiles (
 id uuid primary key references auth.users(id) on delete cascade,
 display_name text not null default '', avatar_url text,
 preferred_currency char(3) not null default 'INR',
 created_at timestamptz not null default now(), updated_at timestamptz not null default now()
);
create table public.groups (
 id uuid primary key default gen_random_uuid(),
 name text not null check(char_length(trim(name)) between 1 and 80),
 description text, created_by uuid not null references auth.users(id),
 currency char(3) not null default 'INR', archived_at timestamptz,
 created_at timestamptz not null default now(), updated_at timestamptz not null default now()
);
create table public.group_members (
 group_id uuid not null references public.groups(id) on delete cascade,
 user_id uuid not null references auth.users(id) on delete cascade,
 role text not null default 'member' check(role in ('owner','member')),
 joined_at timestamptz not null default now(), left_at timestamptz,
 primary key(group_id,user_id)
);
create index group_members_user_idx on public.group_members(user_id,group_id) where left_at is null;
create table public.expenses (
 id uuid primary key default gen_random_uuid(),
 group_id uuid not null references public.groups(id) on delete restrict,
 title text not null check(char_length(trim(title)) between 1 and 160),
 amount_minor bigint not null check(amount_minor>0), currency char(3) not null,
 paid_by uuid not null references auth.users(id),
 split_method text not null default 'equal' check(split_method in ('equal','exact','percentage','shares')),
 category text not null default 'Other', note text, occurred_at timestamptz not null default now(),
 created_by uuid not null references auth.users(id), updated_by uuid not null references auth.users(id),
 version integer not null default 1 check(version>0),
 created_at timestamptz not null default now(), updated_at timestamptz not null default now(),
 deleted_at timestamptz, deleted_by uuid references auth.users(id)
);
create index expenses_group_time_idx on public.expenses(group_id,occurred_at desc) where deleted_at is null;
create table public.expense_splits (
 id uuid primary key default gen_random_uuid(),
 expense_id uuid not null references public.expenses(id) on delete cascade,
 user_id uuid not null references auth.users(id), amount_minor bigint not null check(amount_minor>=0),
 created_at timestamptz not null default now(), unique(expense_id,user_id)
);
create table public.settlements (
 id uuid primary key default gen_random_uuid(),
 group_id uuid not null references public.groups(id) on delete restrict,
 from_user uuid not null references auth.users(id), to_user uuid not null references auth.users(id),
 amount_minor bigint not null check(amount_minor>0), currency char(3) not null,
 note text, recorded_by uuid not null references auth.users(id),
 occurred_at timestamptz not null default now(), created_at timestamptz not null default now(),
 voided_at timestamptz, voided_by uuid references auth.users(id),
 check(from_user<>to_user)
);
create table public.group_invites (
 id uuid primary key default gen_random_uuid(), group_id uuid not null references public.groups(id) on delete cascade,
 token_hash text not null unique, created_by uuid not null references auth.users(id),
 expires_at timestamptz not null, max_uses integer check(max_uses is null or max_uses>0),
 uses integer not null default 0 check(uses>=0), revoked_at timestamptz,
 created_at timestamptz not null default now()
);
create table public.expense_comments (
 id uuid primary key default gen_random_uuid(), expense_id uuid not null references public.expenses(id) on delete cascade,
 author_id uuid not null references auth.users(id),
 body text not null check(char_length(trim(body)) between 1 and 2000), created_at timestamptz not null default now()
);
create table public.audit_events (
 id bigint generated always as identity primary key, actor_id uuid references auth.users(id),
 group_id uuid references public.groups(id) on delete set null,
 entity_type text not null, entity_id uuid, action text not null,
 payload jsonb not null default '{}'::jsonb, created_at timestamptz not null default now()
);
create index audit_group_time_idx on public.audit_events(group_id,created_at desc);
create table public.sync_cursors (
 user_id uuid primary key references auth.users(id) on delete cascade,
 last_seen_at timestamptz not null default now(), device_id text, updated_at timestamptz not null default now()
);

create function private.is_group_member(p_group uuid,p_user uuid default auth.uid())
returns boolean language sql stable security definer set search_path=public,pg_temp
as $$ select exists(select 1 from public.group_members m where m.group_id=p_group and m.user_id=p_user and m.left_at is null) $$;
create function private.is_group_owner(p_group uuid,p_user uuid default auth.uid())
returns boolean language sql stable security definer set search_path=public,pg_temp
as $$ select exists(select 1 from public.groups g where g.id=p_group and g.created_by=p_user) $$;
create function private.audit(p_group uuid,p_type text,p_id uuid,p_action text,p_payload jsonb default '{}'::jsonb)
returns void language plpgsql security definer set search_path=public,pg_temp
as $$ begin insert into public.audit_events(actor_id,group_id,entity_type,entity_id,action,payload)
values(auth.uid(),p_group,p_type,p_id,p_action,coalesce(p_payload,'{}'::jsonb)); end $$;

create function public.handle_new_user() returns trigger language plpgsql security definer set search_path=public,pg_temp
as $$ begin insert into public.profiles(id,display_name,avatar_url)
values(new.id,coalesce(new.raw_user_meta_data->>'full_name',new.raw_user_meta_data->>'name',''),new.raw_user_meta_data->>'avatar_url')
on conflict(id) do nothing; return new; end $$;
create trigger on_auth_user_created after insert on auth.users for each row execute function public.handle_new_user();

create function public.create_group(p_name text,p_currency char(3) default 'INR',p_description text default null)
returns uuid language plpgsql security definer set search_path=public,private,pg_temp
as $$ declare v_id uuid; begin
 if auth.uid() is null then raise exception 'authentication required' using errcode='28000'; end if;
 if char_length(trim(p_name)) not between 1 and 80 then raise exception 'invalid group name'; end if;
 insert into public.groups(name,currency,description,created_by) values(trim(p_name),upper(p_currency),p_description,auth.uid()) returning id into v_id;
 insert into public.group_members(group_id,user_id,role) values(v_id,auth.uid(),'owner');
 perform private.audit(v_id,'group',v_id,'created'); return v_id;
end $$;

-- Group members can add expenses. Payer is intentionally independent of participants.
create function public.create_group_expense(
 p_group_id uuid,p_title text,p_amount_minor bigint,p_currency char(3),p_paid_by uuid,
 p_split_method text,p_category text,p_note text,p_occurred_at timestamptz,p_splits jsonb,p_idempotency_key uuid
) returns uuid language plpgsql security definer set search_path=public,private,pg_temp
as $$ declare v_id uuid; v_sum numeric; v_count integer; v_user uuid; begin
 if auth.uid() is null then raise exception 'authentication required' using errcode='28000'; end if;
 if not private.is_group_member(p_group_id) then raise exception 'not a group member' using errcode='42501'; end if;
 if p_amount_minor<=0 or char_length(trim(p_title)) not between 1 and 160 then raise exception 'invalid expense'; end if;
 if p_split_method not in ('equal','exact','percentage','shares') then raise exception 'invalid split method'; end if;
 if not private.is_group_member(p_group_id,p_paid_by) then raise exception 'payer must be a group member'; end if;
 if jsonb_typeof(p_splits)<>'array' or jsonb_array_length(p_splits)=0 then raise exception 'at least one split required'; end if;
 select coalesce(sum((x->>'amount_minor')::bigint),0),count(*) into v_sum,v_count from jsonb_array_elements(p_splits) x;
 if v_sum<>p_amount_minor or v_count<>(select count(distinct x->>'user_id') from jsonb_array_elements(p_splits) x) then raise exception 'split amounts must be unique and sum to total'; end if;
 for v_user in select (x->>'user_id')::uuid from jsonb_array_elements(p_splits) x loop
  if not private.is_group_member(p_group_id,v_user) then raise exception 'participants must be active group members'; end if;
 end loop;
 insert into public.expenses(group_id,title,amount_minor,currency,paid_by,split_method,category,note,occurred_at,created_by,updated_by)
 values(p_group_id,trim(p_title),p_amount_minor,upper(p_currency),p_paid_by,p_split_method,coalesce(p_category,'Other'),p_note,coalesce(p_occurred_at,now()),auth.uid(),auth.uid()) returning id into v_id;
 insert into public.expense_splits(expense_id,user_id,amount_minor)
 select v_id,(x->>'user_id')::uuid,(x->>'amount_minor')::bigint from jsonb_array_elements(p_splits) x;
 perform private.audit(p_group_id,'expense',v_id,'created',jsonb_build_object('amount_minor',p_amount_minor,'currency',upper(p_currency)));
 return v_id;
end $$;

-- Creator-only edit/delete, enforced by DB and optimistic version.
create function public.update_group_expense(
 p_expense_id uuid,p_expected_version integer,p_title text,p_amount_minor bigint,p_currency char(3),p_paid_by uuid,
 p_split_method text,p_category text,p_note text,p_occurred_at timestamptz,p_splits jsonb
) returns integer language plpgsql security definer set search_path=public,private,pg_temp
as $$ declare v_group uuid; v_version integer; v_sum numeric; v_count integer; v_user uuid; begin
 select group_id,version into v_group,v_version from public.expenses where id=p_expense_id and deleted_at is null for update;
 if v_group is null then raise exception 'expense not found'; end if;
 if not private.is_group_owner(v_group) then raise exception 'only group creator may edit expenses' using errcode='42501'; end if;
 if v_version<>p_expected_version then raise exception 'stale expense version; refresh and retry' using errcode='40001'; end if;
 if p_amount_minor<=0 or char_length(trim(p_title)) not between 1 and 160 then raise exception 'invalid expense'; end if;
 if not private.is_group_member(v_group,p_paid_by) then raise exception 'payer must be active member'; end if;
 select coalesce(sum((x->>'amount_minor')::bigint),0),count(*) into v_sum,v_count from jsonb_array_elements(p_splits) x;
 if v_sum<>p_amount_minor or v_count=0 or v_count<>(select count(distinct x->>'user_id') from jsonb_array_elements(p_splits) x) then raise exception 'invalid split totals'; end if;
 for v_user in select (x->>'user_id')::uuid from jsonb_array_elements(p_splits) x loop
  if not private.is_group_member(v_group,v_user) then raise exception 'participants must be active group members'; end if;
 end loop;
 update public.expenses set title=trim(p_title),amount_minor=p_amount_minor,currency=upper(p_currency),paid_by=p_paid_by,
 split_method=p_split_method,category=coalesce(p_category,'Other'),note=p_note,occurred_at=p_occurred_at,
 updated_by=auth.uid(),updated_at=now(),version=version+1 where id=p_expense_id;
 delete from public.expense_splits where expense_id=p_expense_id;
 insert into public.expense_splits(expense_id,user_id,amount_minor)
 select p_expense_id,(x->>'user_id')::uuid,(x->>'amount_minor')::bigint from jsonb_array_elements(p_splits) x;
 perform private.audit(v_group,'expense',p_expense_id,'updated',jsonb_build_object('version',v_version+1));
 return v_version+1;
end $$;
create function public.delete_group_expense(p_expense_id uuid,p_reason text default null)
returns void language plpgsql security definer set search_path=public,private,pg_temp
as $$ declare v_group uuid; begin
 select group_id into v_group from public.expenses where id=p_expense_id and deleted_at is null for update;
 if v_group is null then raise exception 'expense not found'; end if;
 if not private.is_group_owner(v_group) then raise exception 'only group creator may delete expenses' using errcode='42501'; end if;
 update public.expenses set deleted_at=now(),deleted_by=auth.uid(),updated_at=now(),version=version+1 where id=p_expense_id;
 perform private.audit(v_group,'expense',p_expense_id,'deleted',jsonb_build_object('reason',p_reason));
end $$;
create function public.record_group_settlement(p_group_id uuid,p_from uuid,p_to uuid,p_amount_minor bigint,p_currency char(3),p_note text,p_occurred_at timestamptz)
returns uuid language plpgsql security definer set search_path=public,private,pg_temp
as $$ declare v_id uuid; begin
 if not private.is_group_member(p_group_id) or not private.is_group_member(p_group_id,p_from) or not private.is_group_member(p_group_id,p_to) then raise exception 'group membership required' using errcode='42501'; end if;
 if p_from=p_to or p_amount_minor<=0 then raise exception 'invalid settlement'; end if;
 insert into public.settlements(group_id,from_user,to_user,amount_minor,currency,note,recorded_by,occurred_at)
 values(p_group_id,p_from,p_to,p_amount_minor,upper(p_currency),p_note,auth.uid(),coalesce(p_occurred_at,now())) returning id into v_id;
 perform private.audit(p_group_id,'settlement',v_id,'recorded'); return v_id;
end $$;

create function public.create_group_invite(p_group_id uuid,p_token_hash text,p_expires_at timestamptz,p_max_uses integer default null)
returns uuid language plpgsql security definer set search_path=public,private,pg_temp
as $$ declare v_id uuid; begin
 if not private.is_group_owner(p_group_id) then raise exception 'only group creator may invite users' using errcode='42501'; end if;
 if p_expires_at<=now() or p_expires_at>now()+interval '30 days' or length(p_token_hash)<>64 then raise exception 'invalid invite'; end if;
 insert into public.group_invites(group_id,token_hash,created_by,expires_at,max_uses)
 values(p_group_id,p_token_hash,auth.uid(),p_expires_at,p_max_uses) returning id into v_id;
 perform private.audit(p_group_id,'invite',v_id,'created'); return v_id;
end $$;
create function public.accept_group_invite(p_token_hash text)
returns uuid language plpgsql security definer set search_path=public,private,pg_temp
as $$ declare v_inv public.group_invites%rowtype; begin
 if auth.uid() is null then raise exception 'authentication required' using errcode='28000'; end if;
 select * into v_inv from public.group_invites where token_hash=p_token_hash and revoked_at is null and expires_at>now()
 and (max_uses is null or uses<max_uses) for update;
 if not found then raise exception 'invite invalid, expired or exhausted'; end if;
 insert into public.group_members(group_id,user_id,role) values(v_inv.group_id,auth.uid(),'member')
 on conflict(group_id,user_id) do update set left_at=null;
 update public.group_invites set uses=uses+1 where id=v_inv.id;
 perform private.audit(v_inv.group_id,'membership',auth.uid(),'joined'); return v_inv.group_id;
end $$;
create function public.revoke_group_invite(p_invite_id uuid) returns void
language plpgsql security definer set search_path=public,private,pg_temp
as $$ declare v_group uuid; begin
 select group_id into v_group from public.group_invites where id=p_invite_id;
 if not found or not private.is_group_owner(v_group) then raise exception 'not permitted' using errcode='42501'; end if;
 update public.group_invites set revoked_at=now() where id=p_invite_id and revoked_at is null;
 perform private.audit(v_group,'invite',p_invite_id,'revoked');
end $$;

alter table public.profiles enable row level security;
alter table public.groups enable row level security;
alter table public.group_members enable row level security;
alter table public.expenses enable row level security;
alter table public.expense_splits enable row level security;
alter table public.settlements enable row level security;
alter table public.group_invites enable row level security;
alter table public.expense_comments enable row level security;
alter table public.audit_events enable row level security;
alter table public.sync_cursors enable row level security;
create policy profiles_read_peers on public.profiles for select to authenticated using(id=auth.uid() or exists(
 select 1 from public.group_members a join public.group_members b on b.group_id=a.group_id
 where a.user_id=auth.uid() and a.left_at is null and b.user_id=profiles.id and b.left_at is null));
create policy profiles_update_self on public.profiles for update to authenticated using(id=auth.uid()) with check(id=auth.uid());
create policy groups_read_members on public.groups for select to authenticated using(private.is_group_member(id));
create policy members_read_group on public.group_members for select to authenticated using(private.is_group_member(group_id));
create policy expenses_read_members on public.expenses for select to authenticated using(private.is_group_member(group_id));
create policy splits_read_members on public.expense_splits for select to authenticated using(exists(select 1 from public.expenses e where e.id=expense_id and private.is_group_member(e.group_id)));
create policy settlements_read_members on public.settlements for select to authenticated using(private.is_group_member(group_id));
create policy invites_read_owner on public.group_invites for select to authenticated using(private.is_group_owner(group_id));
create policy comments_read_members on public.expense_comments for select to authenticated using(exists(select 1 from public.expenses e where e.id=expense_id and private.is_group_member(e.group_id)));
create policy comments_insert_member on public.expense_comments for insert to authenticated with check(author_id=auth.uid() and exists(select 1 from public.expenses e where e.id=expense_id and e.deleted_at is null and private.is_group_member(e.group_id)));
create policy audit_read_members on public.audit_events for select to authenticated using(group_id is not null and private.is_group_member(group_id));
create policy sync_cursor_self on public.sync_cursors for all to authenticated using(user_id=auth.uid()) with check(user_id=auth.uid());

revoke insert,update,delete on public.groups,public.group_members,public.expenses,public.expense_splits,public.settlements,public.group_invites,public.audit_events from anon,authenticated;
grant select on public.profiles,public.groups,public.group_members,public.expenses,public.expense_splits,public.settlements,public.group_invites,public.expense_comments,public.audit_events to authenticated;
grant update(display_name,avatar_url,preferred_currency,updated_at) on public.profiles to authenticated;
grant insert on public.expense_comments to authenticated;
grant select,insert,update on public.sync_cursors to authenticated;
grant execute on function public.create_group(text,char(3),text) to authenticated;
grant execute on function public.create_group_expense(uuid,text,bigint,char(3),uuid,text,text,text,timestamptz,jsonb,uuid) to authenticated;
grant execute on function public.update_group_expense(uuid,integer,text,bigint,char(3),uuid,text,text,text,timestamptz,jsonb) to authenticated;
grant execute on function public.delete_group_expense(uuid,text) to authenticated;
grant execute on function public.record_group_settlement(uuid,uuid,uuid,bigint,char(3),text,timestamptz) to authenticated;
grant execute on function public.create_group_invite(uuid,text,timestamptz,integer) to authenticated;
grant execute on function public.accept_group_invite(text) to authenticated;
grant execute on function public.revoke_group_invite(uuid) to authenticated;
revoke all on schema private from public,anon,authenticated;
grant usage on schema private to authenticated;
revoke execute on all functions in schema private from public,anon,authenticated;
grant execute on function private.is_group_member(uuid,uuid) to authenticated;
grant execute on function private.is_group_owner(uuid,uuid) to authenticated;
