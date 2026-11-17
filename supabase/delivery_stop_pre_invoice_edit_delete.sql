-- GASPOS: perubahan catatan pengiriman sebelum INV; stok SJ tidak diubah.
create or replace function public.gaspos_update_delivery_stop(
  p_stop uuid, p_customer uuid, p_full integer, p_empty integer, p_notes text
) returns void
language plpgsql security definer set search_path = ''
as $$
declare
  s public.gas_trip_stops%rowtype;
  t public.gas_trips%rowtype;
  r public.gas_logistics_requests%rowtype;
  qty_other bigint;
  actor text;
  changed boolean;
begin
  actor := gaspos_private.current_role();
  if auth.uid() is null or actor not in ('OWNER','SALES_SOPIR') then
    raise exception 'Hanya Owner atau Sopir dapat mengedit pengiriman';
  end if;
  perform pg_catalog.pg_advisory_xact_lock(948621);
  select * into s from public.gas_trip_stops where id=p_stop for update;
  if not found then raise exception 'Pengiriman tidak ditemukan'; end if;
  select * into t from public.gas_trips where id=s.trip_id for update;
  if actor='SALES_SOPIR' and t.driver_user_id is distinct from auth.uid() then
    raise exception 'Pengiriman bukan milik Sopir ini';
  end if;
  if t.status<>'ON_ROUTE' or t.driver_arrived_at is not null then
    raise exception 'Perjalanan sudah ditutup atau kembali; koreksi perlu pemeriksaan gudang';
  end if;
  if s.invoice_document_id is not null then raise exception 'INV sudah dibuat; pengiriman terkunci'; end if;
  if p_full is null or p_full<1 or p_empty is null or p_empty<0 then
    raise exception 'Jumlah tabung tidak valid';
  end if;
  if not exists(select 1 from public.gas_partners where id=p_customer and partner_type in ('CUSTOMER','BOTH')) then
    raise exception 'Pelanggan tidak valid';
  end if;
  if length(coalesce(p_notes,''))>300 then raise exception 'Catatan terlalu panjang'; end if;
  select * into r from public.gas_logistics_requests where id=t.request_id;
  select coalesce(sum(full_qty),0) into qty_other from public.gas_trip_stops where trip_id=s.trip_id and id<>p_stop;
  if qty_other+p_full>r.full_qty then raise exception 'Jumlah melebihi sisa muatan SJ'; end if;
  changed := s.customer_id is distinct from p_customer or s.full_qty is distinct from p_full or s.empty_qty is distinct from p_empty;
  if not changed and coalesce(s.notes,'')=coalesce(p_notes,'') then return; end if;
  insert into public.gas_trip_stop_audit
   (stop_id,changed_by,old_customer_id,old_full,old_empty,new_customer_id,new_full,new_empty,reason)
  values (p_stop,auth.uid(),s.customer_id,s.full_qty,s.empty_qty,p_customer,p_full,p_empty,'Edit pengiriman sebelum INV');
  update public.gas_trip_stops
  set customer_id=p_customer, full_qty=p_full, empty_qty=p_empty, notes=left(coalesce(p_notes,''),300),
      correction_note='Edit sebelum INV', corrected_by=auth.uid(),corrected_at=now(),
      receiver_confirmed=case when changed then false else receiver_confirmed end,
      receiver_name=case when changed then null else receiver_name end,
      receiver_signature=case when changed then null else receiver_signature end,
      confirmed_at=case when changed then null else confirmed_at end
  where id=p_stop;
end;
$$;

create or replace function public.gaspos_delete_delivery_stop(p_stop uuid)
returns void language plpgsql security definer set search_path = ''
as $$
declare
  s public.gas_trip_stops%rowtype;
  t public.gas_trips%rowtype;
  actor text;
begin
  actor := gaspos_private.current_role();
  if auth.uid() is null or actor not in ('OWNER','SALES_SOPIR') then
    raise exception 'Hanya Owner atau Sopir dapat menghapus pengiriman';
  end if;
  perform pg_catalog.pg_advisory_xact_lock(948621);
  select * into s from public.gas_trip_stops where id=p_stop for update;
  if not found then raise exception 'Pengiriman tidak ditemukan'; end if;
  select * into t from public.gas_trips where id=s.trip_id for update;
  if actor='SALES_SOPIR' and t.driver_user_id is distinct from auth.uid() then
    raise exception 'Pengiriman bukan milik Sopir ini';
  end if;
  if t.status<>'ON_ROUTE' or t.driver_arrived_at is not null then
    raise exception 'Perjalanan sudah ditutup atau kembali; koreksi perlu pemeriksaan gudang';
  end if;
  if s.invoice_document_id is not null then raise exception 'INV sudah dibuat; pengiriman terkunci'; end if;
  insert into public.gas_trip_stop_audit
   (stop_id,changed_by,old_customer_id,old_full,old_empty,new_customer_id,new_full,new_empty,reason)
  values(p_stop,auth.uid(),s.customer_id,s.full_qty,s.empty_qty,null,null,null,'Hapus pengiriman sebelum INV');
  delete from public.gas_trip_stops where id=p_stop;
end;
$$;
revoke all on function public.gaspos_update_delivery_stop(uuid,uuid,integer,integer,text) from public,anon;
revoke all on function public.gaspos_delete_delivery_stop(uuid) from public,anon;
grant execute on function public.gaspos_update_delivery_stop(uuid,uuid,integer,integer,text) to authenticated;
grant execute on function public.gaspos_delete_delivery_stop(uuid) to authenticated;