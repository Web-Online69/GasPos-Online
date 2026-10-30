-- Short, stable display labels. Technical identifiers and idempotency keys are preserved.
lock table public.gas_documents,public.gas_logistics_requests,public.gas_trips,public.gas_trip_stops in share row exclusive mode;
alter table public.gas_documents add column if not exists display_no text;
alter table public.gas_logistics_requests add column if not exists display_no text;
alter table public.gas_trips add column if not exists display_no text;
alter table public.gas_trip_stops add column if not exists display_no text;
create table if not exists gaspos_private.document_number_counters(prefix text primary key,value bigint not null check(value>=0));
alter table gaspos_private.document_number_counters enable row level security;
revoke all on gaspos_private.document_number_counters from public,anon,authenticated;
drop policy if exists document_number_counters_no_client_access on gaspos_private.document_number_counters;
create policy document_number_counters_no_client_access on gaspos_private.document_number_counters for all to authenticated,anon using(false) with check(false);
create or replace function gaspos_private.next_document_label(p_prefix text)
returns text language plpgsql security definer set search_path='' as $$
declare n bigint;
begin
 if p_prefix not in ('INV','BEL','SJ','TBM','FK','TRP','KOR','RETJ','RETB','TKM') then raise exception 'Awalan dokumen tidak valid';end if;
 insert into gaspos_private.document_number_counters(prefix,value) values(p_prefix,1)
 on conflict(prefix) do update set value=gaspos_private.document_number_counters.value+1 returning value into n;
 return p_prefix||' '||lpad(n::text,greatest(5,length(n::text)),'0');
end $$;
revoke all on function gaspos_private.next_document_label(text) from public,anon,authenticated;
create or replace function gaspos_private.document_label_prefix(p_type text,p_old text)
returns text language sql immutable set search_path='' as $$
select case p_type when 'SALE' then 'INV' when 'PURCHASE' then 'BEL' when 'DISPATCH' then 'SJ' when 'RECEIPT' then 'TBM' when 'EMPTY_RETURN' then 'TKM' else case when p_old like 'PR-%' then 'RETB' when p_old like 'SR-%' then 'RETJ' else 'KOR' end end
$$;
revoke all on function gaspos_private.document_label_prefix(text,text) from public,anon,authenticated;
-- Seed only upwards, including safe re-application of this migration.
insert into gaspos_private.document_number_counters(prefix,value)
select split_part(display_no,' ',1),max(split_part(display_no,' ',2)::bigint)
from (select display_no from public.gas_documents union all select display_no from public.gas_logistics_requests union all select display_no from public.gas_trips union all select display_no from public.gas_trip_stops) x
where display_no ~ '^[A-Z]+ [0-9]+$' group by split_part(display_no,' ',1)
on conflict(prefix) do update set value=greatest(gaspos_private.document_number_counters.value,excluded.value);
do $$ declare r record;label text;prefix text;begin
 for r in select id,document_type,document_no from public.gas_documents where display_no is null order by created_at,id loop
  update public.gas_documents set display_no=gaspos_private.next_document_label(gaspos_private.document_label_prefix(r.document_type,r.document_no)) where id=r.id;
 end loop;
 for r in select id,direction,document_id from public.gas_logistics_requests where display_no is null order by created_at,id loop
  prefix:=case when r.direction='OUT' then 'SJ' else 'TBM' end;
  select display_no into label from public.gas_documents where id=r.document_id and display_no like prefix||' %';
  update public.gas_logistics_requests set display_no=coalesce(label,gaspos_private.next_document_label(prefix)) where id=r.id;
 end loop;
 for r in select id from public.gas_trips where display_no is null order by created_at,id loop update public.gas_trips set display_no=gaspos_private.next_document_label('TRP') where id=r.id;end loop;
 for r in select id from public.gas_trip_stops where display_no is null order by created_at,id loop update public.gas_trip_stops set display_no=gaspos_private.next_document_label('FK') where id=r.id;end loop;
end $$;
create unique index if not exists gas_documents_display_no_uidx on public.gas_documents(display_no);
create unique index if not exists gas_logistics_requests_display_no_uidx on public.gas_logistics_requests(display_no);
create unique index if not exists gas_trips_display_no_uidx on public.gas_trips(display_no);
create unique index if not exists gas_trip_stops_display_no_uidx on public.gas_trip_stops(display_no);
alter table public.gas_documents alter column display_no set not null;
alter table public.gas_logistics_requests alter column display_no set not null;
alter table public.gas_trips alter column display_no set not null;
alter table public.gas_trip_stops alter column display_no set not null;
create or replace function gaspos_private.assign_short_document_number()
returns trigger language plpgsql security definer set search_path='' as $$
declare label text;prefix text;
begin
 if tg_op='UPDATE' then
  if tg_table_name='gas_documents' then if new.document_type is distinct from old.document_type then raise exception 'Jenis dokumen tidak dapat diubah';end if;end if;
  if tg_table_name='gas_logistics_requests' then if new.direction is distinct from old.direction then raise exception 'Arah dokumen tidak dapat diubah';end if;end if;
  if new.display_no is distinct from old.display_no then raise exception 'Nomor dokumen dibuat otomatis dan tidak dapat diubah';end if;
  return new;
 end if;
 if tg_table_name='gas_documents' then
  prefix:=gaspos_private.document_label_prefix(new.document_type,new.document_no);
  if new.document_type in ('DISPATCH','RECEIPT') then
   select r.display_no into label from public.gas_logistics_requests r where new.document_no='LOG-'||r.id::text and r.display_no like prefix||' %';
  end if;
 elsif tg_table_name='gas_logistics_requests' then
  prefix:=case when new.direction='OUT' then 'SJ' else 'TBM' end;
  select d.display_no into label from public.gas_documents d where d.id=new.document_id and d.display_no like prefix||' %';
 elsif tg_table_name='gas_trips' then prefix:='TRP';
 elsif tg_table_name='gas_trip_stops' then prefix:='FK';
 else raise exception 'Tabel dokumen tidak didukung';end if;
 new.display_no:=coalesce(label,gaspos_private.next_document_label(prefix));return new;
end $$;
revoke all on function gaspos_private.assign_short_document_number() from public,anon,authenticated;
drop trigger if exists gaspos_short_document_number on public.gas_documents;
create trigger gaspos_short_document_number before insert or update on public.gas_documents for each row execute function gaspos_private.assign_short_document_number();
drop trigger if exists gaspos_short_document_number on public.gas_logistics_requests;
create trigger gaspos_short_document_number before insert or update on public.gas_logistics_requests for each row execute function gaspos_private.assign_short_document_number();
drop trigger if exists gaspos_short_document_number on public.gas_trips;
create trigger gaspos_short_document_number before insert or update on public.gas_trips for each row execute function gaspos_private.assign_short_document_number();
drop trigger if exists gaspos_short_document_number on public.gas_trip_stops;
create trigger gaspos_short_document_number before insert or update on public.gas_trip_stops for each row execute function gaspos_private.assign_short_document_number();

CREATE OR REPLACE VIEW public.gaspos_trade_balances AS  SELECT id,
    COALESCE(display_no,document_no) AS document_no,
    document_type,
    status,
    partner_id,
    created_at,
    COALESCE(( SELECT sum(f.total) AS sum
           FROM gas_document_items i
             JOIN gas_financial_entries f ON f.document_item_id = i.id
          WHERE i.document_id = d.id), 0::numeric) +
        CASE
            WHEN document_type = 'PURCHASE'::text THEN freight_cost + other_cost - COALESCE(( SELECT sum(r.amount) AS sum
               FROM gas_purchase_returns r
                 JOIN gas_document_items i ON i.id = r.purchase_item_id
              WHERE i.document_id = d.id), 0::numeric)
            ELSE - COALESCE(( SELECT sum(r.amount) AS sum
               FROM gas_sale_returns r
                 JOIN gas_document_items i ON i.id = r.sale_item_id
              WHERE i.document_id = d.id), 0::numeric)
        END AS document_total,
    COALESCE(( SELECT sum(p.amount) AS sum
           FROM gas_payments p
          WHERE p.document_id = d.id), 0::numeric) -
        CASE
            WHEN document_type = 'PURCHASE'::text THEN COALESCE(( SELECT sum(r.amount) AS sum
               FROM gas_supplier_refunds r
              WHERE r.document_id = d.id), 0::numeric)
            ELSE COALESCE(( SELECT sum(r.amount) AS sum
               FROM gas_customer_refunds r
              WHERE r.document_id = d.id), 0::numeric)
        END AS paid_total,
    reference_no,
    invoice_date,
    due_date,
    d.document_no AS legacy_document_no
   FROM gas_documents d
  WHERE (document_type = ANY (ARRAY['PURCHASE'::text, 'SALE'::text])) AND gaspos_private."current_role"() IN ('OWNER'::text,'KEUANGAN'::text);

create or replace function public.gaspos_logistics_history()
returns table(document_no text, product_id uuid, delta_full integer, delta_empty integer, created_at timestamptz)
language sql stable security definer set search_path = ''
as $$
select coalesce(d.display_no,d.document_no),i.product_id,m.delta_full,m.delta_empty,m.created_at
from public.gas_stock_movements m
join public.gas_document_items i on i.id=m.document_item_id
join public.gas_documents d on d.id=i.document_id
where gaspos_private.current_role() in ('OWNER','LOGISTIK')
order by m.created_at desc,m.id;
$$;

CREATE OR REPLACE FUNCTION public.gaspos_pending_purchase_lines()
RETURNS TABLE(document_id uuid,document_no text,supplier_id uuid,product_id uuid,product_name text,remaining_full bigint,remaining_empty bigint)
LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO '' AS $$
select d.id,coalesce(d.display_no,d.document_no),d.partner_id,i.product_id,p.name,
(i.quantity_full-coalesce(m.full_qty,0)-coalesce(pending.full_qty,0))::bigint,
(i.quantity_empty-coalesce(m.empty_qty,0)-coalesce(pending.empty_qty,0))::bigint
from public.gas_documents d join public.gas_document_items i on i.document_id=d.id join public.gas_products p on p.id=i.product_id
left join lateral(select sum(delta_full) full_qty,sum(-delta_empty) empty_qty from public.gas_stock_movements where document_item_id=i.id) m on true
left join lateral(select sum(full_qty) full_qty,sum(empty_qty) empty_qty from public.gas_logistics_requests r where r.purchase_document_id=d.id and r.product_id=i.product_id and r.status='PENDING') pending on true
where d.document_type='PURCHASE' and d.status in ('DRAFT','PARTIAL')
and gaspos_private.current_role() in ('OWNER','LOGISTIK')
and 1=(select count(*) from public.gas_document_items x where x.document_id=d.id and x.product_id=i.product_id)
and (i.quantity_full>coalesce(m.full_qty,0)+coalesce(pending.full_qty,0) or i.quantity_empty>coalesce(m.empty_qty,0)+coalesce(pending.empty_qty,0))
$$;
