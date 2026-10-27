-- Accept the canvas format: strokes -> points -> [x,y], including one stroke.
-- Validate every coordinate before storing; keep the existing role/assignment locks.
CREATE OR REPLACE FUNCTION public.gaspos_confirm_stop_signed(p_stop uuid, p_receiver text, p_signature jsonb)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path TO '' AS $$
declare
 s public.gas_trip_stops%rowtype;
 t public.gas_trips%rowtype;
 stroke jsonb;
 point jsonb;
 samples integer := 0;
 x numeric;
 y numeric;
begin
 if auth.uid() is null then raise exception 'Login diperlukan'; end if;
 select * into s from public.gas_trip_stops where id=p_stop for update;
 if not found then raise exception 'Catatan tidak ditemukan'; end if;
 select * into t from public.gas_trips where id=s.trip_id;
 if gaspos_private.current_role() not in ('OWNER','SALES_SOPIR') or (gaspos_private.current_role()='SALES_SOPIR' and t.driver_user_id is distinct from auth.uid()) then raise exception 'Akses ditolak'; end if;
 if t.status<>'ON_ROUTE' or s.invoice_document_id is not null or s.receiver_confirmed then raise exception 'Catatan telah terkunci'; end if;
 if length(btrim(coalesce(p_receiver,'')))<3 then raise exception 'Nama penerima minimal 3 karakter'; end if;
 if p_signature is null or jsonb_typeof(p_signature)<>'array' or length(p_signature::text)>12000 then raise exception 'Format tanda tangan tidak valid'; end if;
 if jsonb_array_length(p_signature)<1 then raise exception 'Tanda tangan penerima wajib diisi'; end if;
 for stroke in select value from jsonb_array_elements(p_signature) loop
  if jsonb_typeof(stroke)<>'array' then raise exception 'Format goresan tanda tangan tidak valid'; end if;
  if jsonb_array_length(stroke)<1 then raise exception 'Goresan tanda tangan kosong'; end if;
  for point in select value from jsonb_array_elements(stroke) loop
   if jsonb_typeof(point)<>'array' then raise exception 'Format titik tanda tangan tidak valid'; end if;
   if jsonb_array_length(point)<>2 then raise exception 'Titik tanda tangan harus berisi x dan y'; end if;
   if jsonb_typeof(point->0)<>'number' or jsonb_typeof(point->1)<>'number' then raise exception 'Koordinat tanda tangan harus angka'; end if;
   x := (point->>0)::numeric; y := (point->>1)::numeric;
   if x not between 0 and 320 or y not between 0 and 160 then raise exception 'Koordinat tanda tangan di luar area'; end if;
   samples := samples + 1;
  end loop;
 end loop;
 if samples<3 then raise exception 'Tanda tangan minimal 3 titik'; end if;
 update public.gas_trip_stops set receiver_name=left(btrim(p_receiver),120),receiver_signature=p_signature,receiver_confirmed=true,confirmed_at=now() where id=p_stop;
end;
$$;
REVOKE ALL ON FUNCTION public.gaspos_confirm_stop_signed(uuid,text,jsonb) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.gaspos_confirm_stop_signed(uuid,text,jsonb) TO authenticated;
