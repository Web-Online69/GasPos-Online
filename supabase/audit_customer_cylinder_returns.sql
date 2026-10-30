-- Independent customer cylinder returns. No financial entries or sale invoice are created.
CREATE TABLE public.gas_customer_cylinder_returns (
 id uuid PRIMARY KEY, display_no text NOT NULL UNIQUE DEFAULT gaspos_private.next_document_label('TKM'),
 customer_id uuid NOT NULL REFERENCES public.gas_partners(id),product_id uuid NOT NULL REFERENCES public.gas_products(id),
 quantity integer NOT NULL CHECK(quantity BETWEEN 1 AND 1000000),trip_id uuid REFERENCES public.gas_trips(id),
 status text NOT NULL CHECK(status IN ('IN_VEHICLE','RECEIVED','VOID')),
 customer_name text NOT NULL CHECK(length(btrim(customer_name)) BETWEEN 3 AND 120),signature jsonb NOT NULL,
 notes text,created_by uuid NOT NULL REFERENCES auth.users(id),created_at timestamptz NOT NULL DEFAULT now(),
 received_by uuid REFERENCES auth.users(id),received_at timestamptz,document_id uuid REFERENCES public.gas_documents(id),
 void_reason text,voided_by uuid REFERENCES auth.users(id),voided_at timestamptz,
 CHECK((status='IN_VEHICLE' AND trip_id IS NOT NULL AND received_at IS NULL) OR
       (status='RECEIVED' AND received_at IS NOT NULL AND received_by IS NOT NULL AND document_id IS NOT NULL) OR
       (status='VOID' AND voided_by IS NOT NULL AND length(btrim(void_reason))>=5))
);
CREATE INDEX gas_customer_cylinder_returns_balance_idx ON public.gas_customer_cylinder_returns(customer_id,product_id) WHERE status<>'VOID';
CREATE INDEX gas_customer_cylinder_returns_trip_idx ON public.gas_customer_cylinder_returns(trip_id);
ALTER TABLE public.gas_customer_cylinder_returns ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.gas_customer_cylinder_returns FROM PUBLIC,anon,authenticated;
GRANT SELECT ON public.gas_customer_cylinder_returns TO authenticated;
CREATE POLICY cylinder_return_read ON public.gas_customer_cylinder_returns FOR SELECT TO authenticated
 USING(gaspos_private.current_role() IN ('OWNER','LOGISTIK') OR (gaspos_private.current_role()='SALES_SOPIR' AND EXISTS(SELECT 1 FROM public.gas_trips t WHERE t.id=trip_id AND t.driver_user_id=auth.uid())));
CREATE OR REPLACE FUNCTION gaspos_private.customer_cylinder_balances()
RETURNS TABLE(customer_id uuid,product_id uuid,owed_qty bigint)
LANGUAGE sql STABLE SECURITY DEFINER SET search_path='' AS $$
WITH legacy AS (
 SELECT o.customer_id,i.product_id,
  sum(o.owed_qty-coalesce(ret.returned,0)-coalesce(sr.net_returned,0))::bigint qty
 FROM public.gas_customer_empty_obligations o JOIN public.gas_document_items i ON i.id=o.item_id
 LEFT JOIN (SELECT obligation_item_id,sum(quantity) returned FROM public.gas_customer_empty_returns GROUP BY obligation_item_id) ret ON ret.obligation_item_id=o.item_id
 LEFT JOIN (SELECT sale_item_id,sum(quantity-empty_reissued) net_returned FROM public.gas_sale_returns GROUP BY sale_item_id) sr ON sr.sale_item_id=o.item_id
 -- A trip invoice is counted only through its verified stops, not a second obligation.
 WHERE NOT EXISTS (SELECT 1 FROM public.gas_trip_stops s WHERE s.invoice_document_id=i.document_id)
 GROUP BY o.customer_id,i.product_id
), trips AS (
 SELECT s.customer_id,r.product_id,sum(s.full_qty-s.empty_qty)::bigint qty
 FROM public.gas_trip_stops s JOIN public.gas_trips t ON t.id=s.trip_id
 JOIN public.gas_logistics_requests r ON r.id=t.request_id
 WHERE t.status in ('ON_ROUTE','RETURNED') AND s.receiver_confirmed
 GROUP BY s.customer_id,r.product_id
), trip_returns AS (
 SELECT d.partner_id customer_id,i.product_id,-sum(sr.quantity-sr.empty_reissued)::bigint qty
 FROM public.gas_sale_returns sr JOIN public.gas_document_items i ON i.id=sr.sale_item_id
 JOIN public.gas_documents d ON d.id=i.document_id
 JOIN public.gaspos_sales_delivery_progress progress ON progress.item_id=i.id
 WHERE progress.delivered_full>0 AND EXISTS (SELECT 1 FROM public.gas_trip_stops s WHERE s.invoice_document_id=i.document_id)
 GROUP BY d.partner_id,i.product_id
)
SELECT x.customer_id,x.product_id,sum(x.qty)::bigint
FROM (SELECT * FROM legacy UNION ALL SELECT * FROM trips UNION ALL SELECT * FROM trip_returns UNION ALL SELECT customer_id,product_id,-sum(quantity)::bigint qty FROM public.gas_customer_cylinder_returns WHERE status<>'VOID' GROUP BY customer_id,product_id) x
GROUP BY x.customer_id,x.product_id;
$$;
REVOKE ALL ON FUNCTION gaspos_private.customer_cylinder_balances() FROM PUBLIC,anon,authenticated;
CREATE OR REPLACE FUNCTION public.gaspos_customer_empty_all_balances()
RETURNS TABLE(customer_id uuid,product_id uuid,owed_qty bigint)
LANGUAGE sql STABLE SECURITY DEFINER SET search_path='' AS $$
 SELECT * FROM gaspos_private.customer_cylinder_balances() WHERE gaspos_private.current_role()='OWNER';
$$;
CREATE OR REPLACE FUNCTION public.gaspos_customer_cylinder_balances()
RETURNS TABLE(customer_id uuid,product_id uuid,owed_qty bigint)
LANGUAGE sql STABLE SECURITY DEFINER SET search_path='' AS $$
 SELECT * FROM gaspos_private.customer_cylinder_balances() WHERE auth.uid() IS NOT NULL AND gaspos_private.current_role() IN ('OWNER','LOGISTIK','SALES_SOPIR');
$$;
REVOKE ALL ON FUNCTION public.gaspos_customer_cylinder_balances() FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.gaspos_customer_cylinder_balances() TO authenticated;
CREATE OR REPLACE FUNCTION gaspos_private.validate_cylinder_signature(p_signature jsonb)
RETURNS void LANGUAGE plpgsql SET search_path='' AS $$
DECLARE stroke jsonb;point jsonb;samples integer:=0;
BEGIN
 IF p_signature IS NULL OR jsonb_typeof(p_signature)<>'array' OR length(p_signature::text)>12000 THEN RAISE EXCEPTION 'Tanda tangan pelanggan wajib diisi';END IF;
 FOR stroke IN SELECT value FROM jsonb_array_elements(p_signature) LOOP
  IF jsonb_typeof(stroke)<>'array' THEN RAISE EXCEPTION 'Format tanda tangan tidak valid';END IF;
  FOR point IN SELECT value FROM jsonb_array_elements(stroke) LOOP
   IF jsonb_typeof(point)<>'array' OR jsonb_array_length(point)<>2 THEN RAISE EXCEPTION 'Format titik tidak valid';END IF;
   IF jsonb_typeof(point->0)<>'number' OR jsonb_typeof(point->1)<>'number' THEN RAISE EXCEPTION 'Koordinat harus angka';END IF;
   IF (point->>0)::numeric NOT BETWEEN 0 AND 320 OR (point->>1)::numeric NOT BETWEEN 0 AND 160 THEN RAISE EXCEPTION 'Koordinat di luar area';END IF;
   samples:=samples+1;
  END LOOP;
 END LOOP;
 IF samples<3 THEN RAISE EXCEPTION 'Tanda tangan pelanggan belum lengkap';END IF;
END $$;
REVOKE ALL ON FUNCTION gaspos_private.validate_cylinder_signature(jsonb) FROM PUBLIC,anon,authenticated;
CREATE OR REPLACE FUNCTION public.gaspos_collect_customer_cylinders(p_customer uuid,p_product uuid,p_qty integer,p_trip uuid,p_customer_name text,p_signature jsonb,p_notes text,p_request uuid)
RETURNS uuid LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE role_name text:=coalesce(gaspos_private.current_role(),'');old public.gas_customer_cylinder_returns%rowtype;
 t public.gas_trips%rowtype;r public.gas_logistics_requests%rowtype;balance bigint;doc uuid;item uuid;
BEGIN
 IF auth.uid() IS NULL OR role_name NOT IN ('OWNER','LOGISTIK','SALES_SOPIR') THEN RAISE EXCEPTION 'Akses pengembalian tabung ditolak';END IF;
 IF p_request IS NULL OR p_qty IS NULL OR p_qty NOT BETWEEN 1 AND 1000000 OR length(btrim(coalesce(p_customer_name,''))) NOT BETWEEN 3 AND 120 THEN RAISE EXCEPTION 'Data pengembalian tidak valid';END IF;
 PERFORM pg_advisory_xact_lock(948621);
 SELECT * INTO old FROM public.gas_customer_cylinder_returns WHERE id=p_request;
 IF FOUND THEN
  IF old.created_by IS DISTINCT FROM auth.uid() OR old.customer_id IS DISTINCT FROM p_customer OR old.product_id IS DISTINCT FROM p_product OR old.quantity IS DISTINCT FROM p_qty OR old.trip_id IS DISTINCT FROM p_trip OR old.customer_name IS DISTINCT FROM btrim(p_customer_name) OR old.signature IS DISTINCT FROM p_signature OR coalesce(old.notes,'') IS DISTINCT FROM left(btrim(coalesce(p_notes,'')),500) THEN RAISE EXCEPTION 'Nomor permintaan sudah digunakan untuk data berbeda';END IF;
  RETURN old.id;
 END IF;
 PERFORM gaspos_private.validate_cylinder_signature(p_signature);
 IF NOT EXISTS(SELECT 1 FROM public.gas_partners WHERE id=p_customer AND partner_type IN ('CUSTOMER','BOTH')) THEN RAISE EXCEPTION 'Pelanggan tidak valid';END IF;
 IF p_trip IS NULL THEN
  IF role_name='SALES_SOPIR' THEN RAISE EXCEPTION 'Sopir wajib memilih perjalanan aktif';END IF;
 ELSE
  SELECT * INTO t FROM public.gas_trips WHERE id=p_trip FOR UPDATE;
  IF NOT FOUND OR t.status<>'ON_ROUTE' THEN RAISE EXCEPTION 'Perjalanan tidak aktif';END IF;
  IF role_name='SALES_SOPIR' AND t.driver_user_id IS DISTINCT FROM auth.uid() THEN RAISE EXCEPTION 'Bukan sopir perjalanan ini';END IF;
  SELECT * INTO r FROM public.gas_logistics_requests WHERE id=t.request_id;
  IF r.product_id IS DISTINCT FROM p_product THEN RAISE EXCEPTION 'Jenis tabung harus sesuai perjalanan';END IF;
 END IF;
 SELECT owed_qty INTO balance FROM gaspos_private.customer_cylinder_balances() WHERE customer_id=p_customer AND product_id=p_product;
 IF p_qty>coalesce(balance,0) THEN RAISE EXCEPTION 'Pengembalian melebihi sisa pinjaman pelanggan';END IF;
 IF p_trip IS NULL THEN
  INSERT INTO public.gas_documents(document_no,document_type,partner_id,status,created_by,approved_by,notes)
  VALUES('CER2-'||p_request::text,'EMPTY_RETURN',p_customer,'APPROVED',auth.uid(),auth.uid(),'Penerimaan kosong pelanggan di gudang') RETURNING id INTO doc;
  INSERT INTO public.gas_document_items(document_id,product_id,quantity_full,quantity_empty) VALUES(doc,p_product,0,p_qty) RETURNING id INTO item;
  INSERT INTO public.gas_stock_movements(document_item_id,movement_key,delta_full,delta_empty) VALUES(item,'CER2-'||p_request::text,0,p_qty);
 END IF;
 INSERT INTO public.gas_customer_cylinder_returns(id,display_no,customer_id,product_id,quantity,trip_id,status,customer_name,signature,notes,created_by,received_by,received_at,document_id)
 VALUES(p_request,coalesce((SELECT display_no FROM public.gas_documents WHERE id=doc),gaspos_private.next_document_label('TKM')),p_customer,p_product,p_qty,p_trip,CASE WHEN p_trip IS NULL THEN 'RECEIVED' ELSE 'IN_VEHICLE' END,btrim(p_customer_name),p_signature,nullif(left(btrim(coalesce(p_notes,'')),500),''),auth.uid(),CASE WHEN p_trip IS NULL THEN auth.uid() END,CASE WHEN p_trip IS NULL THEN now() END,doc);
 RETURN p_request;
END $$;
REVOKE ALL ON FUNCTION public.gaspos_collect_customer_cylinders(uuid,uuid,integer,uuid,text,jsonb,text,uuid) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.gaspos_collect_customer_cylinders(uuid,uuid,integer,uuid,text,jsonb,text,uuid) TO authenticated;
CREATE OR REPLACE FUNCTION public.gaspos_return_trip(p_trip uuid,p_full integer,p_empty integer)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE t public.gas_trips%rowtype;r public.gas_logistics_requests%rowtype;sent bigint;collected bigint;extra bigint;unconfirmed bigint;item uuid;
BEGIN
 IF auth.uid() IS NULL OR gaspos_private.current_role() NOT IN ('OWNER','LOGISTIK') THEN RAISE EXCEPTION 'Hanya Logistik atau Owner';END IF;
 PERFORM pg_advisory_xact_lock(948621);
 SELECT * INTO t FROM public.gas_trips WHERE id=p_trip FOR UPDATE;
 IF NOT FOUND THEN RAISE EXCEPTION 'Perjalanan tidak ditemukan';END IF;
 IF t.status='RETURNED' THEN
  IF t.return_full IS DISTINCT FROM p_full OR t.return_empty IS DISTINCT FROM p_empty THEN RAISE EXCEPTION 'Perjalanan sudah diterima dengan jumlah berbeda';END IF;
  RETURN;
 END IF;
 IF t.status<>'ON_ROUTE' THEN RAISE EXCEPTION 'Perjalanan tidak aktif';END IF;
 SELECT * INTO r FROM public.gas_logistics_requests WHERE id=t.request_id;
 SELECT coalesce(sum(full_qty),0),coalesce(sum(empty_qty),0),count(*) FILTER(WHERE NOT receiver_confirmed) INTO sent,collected,unconfirmed FROM public.gas_trip_stops WHERE trip_id=p_trip;
 IF unconfirmed>0 THEN RAISE EXCEPTION 'Semua pengiriman harus dikonfirmasi penerima sebelum pulang';END IF;
 SELECT coalesce(sum(quantity),0) INTO extra FROM public.gas_customer_cylinder_returns WHERE trip_id=p_trip AND status='IN_VEHICLE';
 IF p_full IS NULL OR p_empty IS NULL OR p_full<0 OR p_empty<0 OR p_full<>r.full_qty-sent OR p_empty<>r.empty_qty+collected+extra THEN RAISE EXCEPTION 'Jumlah pulang tidak cocok; periksa sisa penuh dan seluruh kosong terkumpul';END IF;
 SELECT id INTO item FROM public.gas_document_items WHERE document_id=r.document_id LIMIT 1;
 IF item IS NULL THEN RAISE EXCEPTION 'Item Surat Jalan tidak ditemukan';END IF;
 INSERT INTO public.gas_stock_movements(document_item_id,movement_key,delta_full,delta_empty) VALUES(item,'TRIP-RETURN-'||p_trip::text,p_full,p_empty);
 UPDATE public.gas_customer_cylinder_returns SET status='RECEIVED',received_by=auth.uid(),received_at=now(),document_id=r.document_id WHERE trip_id=p_trip AND status='IN_VEHICLE';
 UPDATE public.gas_trips SET status='RETURNED',return_full=p_full,return_empty=p_empty,returned_by=auth.uid(),returned_at=now() WHERE id=p_trip;
END $$;
CREATE OR REPLACE FUNCTION public.gaspos_void_cylinder_collection(p_return uuid,p_reason text)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE old public.gas_customer_cylinder_returns%rowtype;
BEGIN
 IF auth.uid() IS NULL OR gaspos_private.current_role()<>'OWNER' THEN RAISE EXCEPTION 'Koreksi memerlukan Owner';END IF;
 IF length(btrim(coalesce(p_reason,'')))<5 THEN RAISE EXCEPTION 'Alasan minimal 5 karakter';END IF;
 PERFORM pg_advisory_xact_lock(948621);
 SELECT * INTO old FROM public.gas_customer_cylinder_returns WHERE id=p_return FOR UPDATE;
 IF NOT FOUND OR old.status<>'IN_VEHICLE' THEN RAISE EXCEPTION 'Hanya pengumpulan yang belum diterima gudang dapat dibatalkan';END IF;
 UPDATE public.gas_customer_cylinder_returns SET status='VOID',void_reason=left(btrim(p_reason),500),voided_by=auth.uid(),voided_at=now() WHERE id=p_return;
END $$;
REVOKE ALL ON FUNCTION public.gaspos_void_cylinder_collection(uuid,text) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.gaspos_void_cylinder_collection(uuid,text) TO authenticated;
-- Prevent the legacy item-based endpoint from bypassing the aggregate loan balance.
CREATE OR REPLACE FUNCTION public.gaspos_customer_empty_return(p_item uuid,p_qty integer,p_request uuid)
RETURNS uuid LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE customer uuid;product uuid;balance bigint;
BEGIN
 IF auth.uid() IS NULL OR gaspos_private.current_role()<>'OWNER' THEN RAISE EXCEPTION 'Khusus Owner';END IF;
 PERFORM pg_advisory_xact_lock(948621);
 IF NOT EXISTS(SELECT 1 FROM public.gas_customer_empty_returns WHERE request_id=p_request) THEN
  SELECT o.customer_id,i.product_id INTO customer,product FROM public.gas_customer_empty_obligations o JOIN public.gas_document_items i ON i.id=o.item_id WHERE o.item_id=p_item;
  SELECT owed_qty INTO balance FROM gaspos_private.customer_cylinder_balances() WHERE customer_id=customer AND product_id=product;
  IF p_qty>coalesce(balance,0) THEN RAISE EXCEPTION 'Pengembalian melebihi sisa pinjaman pelanggan';END IF;
 END IF;
 RETURN gaspos_private.customer_empty_return(p_item,p_qty,p_request);
END $$;
-- Protect a loan already collected against deleting its confirmed source via correction.
CREATE OR REPLACE FUNCTION gaspos_private.guard_collected_loan()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE product uuid;balance bigint;old_qty bigint;new_qty bigint;
BEGIN
 PERFORM pg_advisory_xact_lock(948621);
 SELECT r.product_id INTO product FROM public.gas_trips t JOIN public.gas_logistics_requests r ON r.id=t.request_id WHERE t.id=OLD.trip_id;
 IF OLD.receiver_confirmed AND EXISTS(SELECT 1 FROM public.gas_customer_cylinder_returns WHERE customer_id=OLD.customer_id AND product_id=product AND status<>'VOID') THEN
  SELECT owed_qty INTO balance FROM gaspos_private.customer_cylinder_balances() WHERE customer_id=OLD.customer_id AND product_id=product;
  old_qty:=OLD.full_qty-OLD.empty_qty;
  new_qty:=CASE WHEN NEW.receiver_confirmed AND NEW.customer_id=OLD.customer_id THEN NEW.full_qty-NEW.empty_qty ELSE 0 END;
  IF coalesce(balance,0)-old_qty+new_qty<0 THEN RAISE EXCEPTION 'Pinjaman sudah dikembalikan; periksa atau batalkan pengumpulan melalui Owner sebelum koreksi';END IF;
 END IF;
 RETURN NEW;
END $$;
REVOKE ALL ON FUNCTION gaspos_private.guard_collected_loan() FROM PUBLIC,anon,authenticated;
CREATE TRIGGER guard_collected_customer_loan BEFORE UPDATE OF customer_id,full_qty,empty_qty,receiver_confirmed ON public.gas_trip_stops FOR EACH ROW EXECUTE FUNCTION gaspos_private.guard_collected_loan();

CREATE OR REPLACE FUNCTION public.gaspos_correct_stop(p_stop uuid, p_customer uuid, p_full integer, p_empty integer, p_reason text)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare s public.gas_trip_stops%rowtype;t public.gas_trips%rowtype;r public.gas_logistics_requests%rowtype;v_other int;v_trip uuid;
begin
if auth.uid() is null or gaspos_private.current_role()<>'OWNER' then raise exception 'Koreksi memerlukan Owner';end if;
perform pg_advisory_xact_lock(948621);
select trip_id into v_trip from public.gas_trip_stops where id=p_stop;
if v_trip is null then raise exception 'Pengiriman tidak ditemukan';end if;
select * into t from public.gas_trips where id=v_trip for update;
select * into s from public.gas_trip_stops where id=p_stop for update;
select * into r from public.gas_logistics_requests where id=t.request_id;
if t.status<>'ON_ROUTE' or s.invoice_document_id is not null then raise exception 'Pengiriman dikunci';end if;
if length(btrim(coalesce(p_reason,'')))<5 or p_full is null or p_full<=0 or p_empty is null or p_empty<0 then raise exception 'Data koreksi tidak valid';end if;
if not exists(select 1 from public.gas_partners where id=p_customer and partner_type='CUSTOMER') then raise exception 'Pelanggan tidak valid';end if;
select coalesce(sum(full_qty),0)::int into v_other from public.gas_trip_stops where trip_id=s.trip_id and id<>p_stop;
if v_other+p_full>r.full_qty then raise exception 'Melebihi muatan';end if;
insert into public.gas_trip_stop_audit(stop_id,changed_by,old_customer_id,old_full,old_empty,new_customer_id,new_full,new_empty,reason) values(p_stop,auth.uid(),s.customer_id,s.full_qty,s.empty_qty,p_customer,p_full,p_empty,btrim(p_reason));
update public.gas_trip_stops set customer_id=p_customer,full_qty=p_full,empty_qty=p_empty,correction_note=left(btrim(p_reason),500),corrected_by=auth.uid(),corrected_at=now(),receiver_confirmed=false,receiver_name=null,confirmed_at=null where id=p_stop;
end;$function$
;

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
 perform pg_advisory_xact_lock(948621);
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
REVOKE ALL ON FUNCTION public.gaspos_customer_empty_all_balances(),public.gaspos_return_trip(uuid,integer,integer),public.gaspos_customer_empty_return(uuid,integer,uuid),public.gaspos_correct_stop(uuid,uuid,integer,integer,text) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.gaspos_customer_empty_all_balances(),public.gaspos_return_trip(uuid,integer,integer),public.gaspos_customer_empty_return(uuid,integer,uuid),public.gaspos_correct_stop(uuid,uuid,integer,integer,text) TO authenticated;
-- Owner correction is a new reversing entry, including after warehouse receipt.
ALTER TABLE public.gas_customer_cylinder_returns ADD COLUMN void_document_id uuid REFERENCES public.gas_documents(id);
CREATE OR REPLACE FUNCTION public.gaspos_void_cylinder_collection(p_return uuid,p_reason text)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE old public.gas_customer_cylinder_returns%rowtype;stock bigint;doc uuid;item uuid;
BEGIN
 IF auth.uid() IS NULL OR gaspos_private.current_role()<>'OWNER' THEN RAISE EXCEPTION 'Koreksi memerlukan Owner';END IF;
 IF length(btrim(coalesce(p_reason,'')))<5 THEN RAISE EXCEPTION 'Alasan minimal 5 karakter';END IF;
 PERFORM pg_advisory_xact_lock(948621);
 SELECT * INTO old FROM public.gas_customer_cylinder_returns WHERE id=p_return FOR UPDATE;
 IF NOT FOUND THEN RAISE EXCEPTION 'Pengembalian tidak ditemukan';END IF;
 IF old.status='VOID' THEN RETURN;END IF;
 IF old.status='RECEIVED' THEN
  SELECT coalesce(sum(m.delta_empty),0) INTO stock FROM public.gas_stock_movements m JOIN public.gas_document_items i ON i.id=m.document_item_id WHERE i.product_id=old.product_id;
  IF stock<old.quantity THEN RAISE EXCEPTION 'Stok kosong tidak cukup untuk membalik pengembalian; periksa fisik dahulu';END IF;
  INSERT INTO public.gas_documents(document_no,document_type,partner_id,status,created_by,approved_by,notes)
  VALUES('CER-VOID-'||old.id::text,'STOCK_ADJUSTMENT',old.customer_id,'APPROVED',auth.uid(),auth.uid(),'Pembalik '||old.display_no||': '||left(btrim(p_reason),500)) RETURNING id INTO doc;
  INSERT INTO public.gas_document_items(document_id,product_id,quantity_full,quantity_empty) VALUES(doc,old.product_id,0,old.quantity) RETURNING id INTO item;
  INSERT INTO public.gas_stock_movements(document_item_id,movement_key,delta_full,delta_empty) VALUES(item,'CER-VOID-'||old.id::text,0,-old.quantity);
 END IF;
 UPDATE public.gas_customer_cylinder_returns SET status='VOID',void_reason=left(btrim(p_reason),500),voided_by=auth.uid(),voided_at=now(),void_document_id=doc WHERE id=p_return;
END $$;
REVOKE ALL ON FUNCTION public.gaspos_void_cylinder_collection(uuid,text) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.gaspos_void_cylinder_collection(uuid,text) TO authenticated;
