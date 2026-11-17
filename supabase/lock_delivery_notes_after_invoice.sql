create or replace function public.gaspos_edit_driver_stop_notes(p_stop uuid, p_notes text)
returns void language plpgsql security definer set search_path = ''
as $$
declare
  rec public.gas_trip_stops%rowtype;
  trip public.gas_trips%rowtype;
  actor text;
begin
  actor := gaspos_private.current_role();
  if auth.uid() is null or actor not in ('OWNER','SALES_SOPIR') then
    raise exception 'Hanya Owner atau Sopir dapat mengedit catatan pengiriman';
  end if;
  if length(coalesce(p_notes,''))>500 then raise exception 'Catatan terlalu panjang'; end if;
  perform pg_catalog.pg_advisory_xact_lock(948621);
  select * into rec from public.gas_trip_stops where id=p_stop for update;
  if not found then raise exception 'Pengiriman tidak ditemukan'; end if;
  select * into trip from public.gas_trips where id=rec.trip_id for update;
  if actor='SALES_SOPIR' and trip.driver_user_id is distinct from auth.uid() then
    raise exception 'Bukan pengiriman Sopir ini';
  end if;
  if rec.invoice_document_id is not null then raise exception 'INV sudah dibuat; pengiriman terkunci'; end if;
  if trip.status<>'ON_ROUTE' or trip.driver_arrived_at is not null then
    raise exception 'Perjalanan sudah selesai; catatan tidak bisa diubah';
  end if;
  update public.gas_trip_stops set notes=btrim(coalesce(p_notes,'')) where id=p_stop;
end;
$$;
revoke all on function public.gaspos_edit_driver_stop_notes(uuid,text) from public,anon;
grant execute on function public.gaspos_edit_driver_stop_notes(uuid,text) to authenticated;