-- Keep the four existing roles. Each account selects one authorized active job.
alter table public.gas_members add column if not exists assigned_roles text[];
update public.gas_members set assigned_roles=array[role] where assigned_roles is null;
alter table public.gas_members alter column assigned_roles set not null;
create or replace function gaspos_private.validate_member_jobs()
returns trigger language plpgsql set search_path='' as $$
begin
 if new.assigned_roles is null then new.assigned_roles:=array[new.role];end if;
 if cardinality(new.assigned_roles)<1 or cardinality(new.assigned_roles)>3 or exists(select 1 from unnest(new.assigned_roles) r where r is null or r not in ('OWNER','LOGISTIK','SALES_SOPIR','KEUANGAN')) then raise exception 'Pilih tugas yang valid';end if;
 new.assigned_roles:=array(select distinct r from unnest(new.assigned_roles) r order by r);
 if 'OWNER'=any(new.assigned_roles) and (new.role<>'OWNER' or cardinality(new.assigned_roles)<>1) then raise exception 'Owner tidak dapat digabung dengan tugas petugas';end if;
 if not(new.role=any(new.assigned_roles)) then raise exception 'Tugas aktif harus termasuk penugasan akun';end if;
 if tg_op='UPDATE' then if old.role='OWNER' and new.role<>'OWNER' then raise exception 'Peran Owner tidak dapat diganti';end if;end if;
 return new;
end $$;
revoke all on function gaspos_private.validate_member_jobs() from public,anon,authenticated;
drop trigger if exists gaspos_validate_member_jobs on public.gas_members;
create trigger gaspos_validate_member_jobs before insert or update on public.gas_members for each row execute function gaspos_private.validate_member_jobs();
create or replace function public.gaspos_switch_job(p_role text)
returns text language plpgsql security definer set search_path='' as $$
declare jobs text[];
begin
 if auth.uid() is null then raise exception 'Login diperlukan';end if;
 select assigned_roles into jobs from public.gas_members where user_id=auth.uid() and active for update;
 if not found or p_role is null or not(p_role=any(jobs)) then raise exception 'Tugas tidak ditugaskan atau akun nonaktif';end if;
 update public.gas_members set role=p_role where user_id=auth.uid();
 return p_role;
end $$;
revoke all on function public.gaspos_switch_job(text) from public,anon;
grant execute on function public.gaspos_switch_job(text) to authenticated;
-- Driver assignment considers assigned jobs even while the driver's other job is active.
do $$ declare target regprocedure;definition text;begin
 foreach target in array array['public.gaspos_start_trip(uuid,uuid,text)'::regprocedure,'public.gaspos_create_delivery_sj(uuid,integer,uuid,text,text,uuid)'::regprocedure] loop
  definition:=pg_get_functiondef(target);
  if strpos(definition,'role=''SALES_SOPIR''')=0 then raise exception 'Pemeriksaan Sopir tidak ditemukan';end if;
  definition:=replace(definition,'role=''SALES_SOPIR''','''SALES_SOPIR''=any(assigned_roles)');execute definition;
 end loop;
 definition:=pg_get_functiondef('public.gaspos_list_drivers()'::regprocedure);
 if strpos(definition,'m.role=''SALES_SOPIR''')=0 then raise exception 'Daftar Sopir tidak ditemukan';end if;
 execute replace(definition,'m.role=''SALES_SOPIR''','''SALES_SOPIR''=any(m.assigned_roles)');
end $$;
