CREATE OR REPLACE FUNCTION gaspos_private.receive_purchase(p_id uuid, p_items jsonb, p_request uuid)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare d public.gas_documents%rowtype;v record;v_item jsonb;v_full integer;v_empty integer;v_seen_full bigint;v_seen_empty bigint;v_total_full bigint;v_total_empty bigint;v_complete boolean:=true;v_entry uuid;v_owed bigint;v_stock bigint;
begin
 if auth.uid() is null or gaspos_private.current_role() not in ('OWNER','LOGISTIK') then raise exception 'Hanya Owner atau Logistik';end if;
 if p_request is null or p_items is null or jsonb_typeof(p_items)<>'array' or jsonb_array_length(p_items)<1 or jsonb_array_length(p_items)>100 then raise exception 'Penerimaan tidak valid';end if;
 perform pg_advisory_xact_lock(948621);
 select * into d from public.gas_documents where id=p_id for update;
 if not found or d.document_type<>'PURCHASE' or d.status not in ('DRAFT','PARTIAL') then raise exception 'Pembelian tidak dapat diterima';end if;
 if exists(select 1 from public.gas_stock_movements m join public.gas_document_items i on i.id=m.document_item_id where i.document_id=p_id and m.movement_key like ('RECEIPT-'||p_request::text||'-%')) then return p_id;end if;
 for v_item in select value from jsonb_array_elements(p_items) loop
  if coalesce(v_item->>'quantity_full','') !~ '^[0-9]+$' or coalesce(v_item->>'quantity_empty','') !~ '^[0-9]+$' then raise exception 'Kuantitas harus bilangan bulat';end if;
  v_full:=(v_item->>'quantity_full')::integer;v_empty:=(v_item->>'quantity_empty')::integer;
  if v_full<0 or v_empty<0 or v_full>1000000 or v_empty>1000000 or (v_full=0 and v_empty=0) then raise exception 'Jumlah penerimaan tidak valid';end if;
  select * into v from public.gas_document_items where id=(v_item->>'item_id')::uuid and document_id=p_id;
  if not found then raise exception 'Barang bukan bagian pembelian';end if;
  select coalesce(sum(m.delta_full),0),coalesce(sum(-m.delta_empty),0) into v_seen_full,v_seen_empty from public.gas_stock_movements m where m.document_item_id=v.id;
  if v_seen_full+v_full>v.quantity_full or v_seen_empty+v_empty>v.quantity_empty then raise exception 'Penerimaan melebihi pesanan';end if;
  if v_empty>0 then
   select coalesce(sum(m.delta_empty),0) into v_stock from public.gas_stock_movements m join public.gas_document_items i on i.id=m.document_item_id where i.product_id=v.product_id;
   if v_stock<v_empty then raise exception 'Stok tabung kosong tidak mencukupi';end if;
  end if;
  insert into public.gas_stock_movements(document_item_id,movement_key,delta_full,delta_empty) values(v.id,'RECEIPT-'||p_request::text||'-'||v.id::text,v_full,-v_empty);
  if v.purchase_mode<>'NEW_CYLINDER' then
   v_owed:=greatest(0,v_seen_full+v_full-v_seen_empty-v_empty);
   insert into public.gas_empty_obligations(document_item_id,supplier_id,owed_qty) values(v.id,d.partner_id,v_owed)
   on conflict(document_item_id) do update set owed_qty=excluded.owed_qty;
  end if;
 end loop;
 for v in select id,quantity_full,quantity_empty from public.gas_document_items where document_id=p_id loop
  select coalesce(sum(m.delta_full),0),coalesce(sum(-m.delta_empty),0) into v_total_full,v_total_empty from public.gas_stock_movements m where m.document_item_id=v.id;
  if v_total_full<v.quantity_full or v_total_empty<v.quantity_empty then v_complete:=false;end if;
 end loop;
 update public.gas_documents set status=case when v_complete then 'APPROVED' else 'PARTIAL' end,approved_by=case when v_complete then auth.uid() else null end where id=p_id;
 return p_id;
end;
$function$
;
CREATE OR REPLACE FUNCTION public.gaspos_invoice_trip_stop(p_stop uuid, p_unit_price numeric, p_invoice_date date, p_due_date date)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare s public.gas_trip_stops%rowtype;t public.gas_trips%rowtype;r public.gas_logistics_requests%rowtype;v_doc uuid;v_item uuid;v_trip uuid;
begin
if auth.uid() is null or gaspos_private.current_role()<>'OWNER' then raise exception 'Hanya Owner membuat invoice';end if;
select trip_id into v_trip from public.gas_trip_stops where id=p_stop;
select * into t from public.gas_trips where id=v_trip for update;
select * into s from public.gas_trip_stops where id=p_stop for update;
if not found or s.invoice_document_id is not null then raise exception 'Pengiriman sudah ditagihkan atau tidak ditemukan';end if;
select * into t from public.gas_trips where id=s.trip_id;select * into r from public.gas_logistics_requests where id=t.request_id;
if t.status not in ('ON_ROUTE','RETURNED') or not s.receiver_confirmed then raise exception 'Faktur Sopir belum dikonfirmasi penerima';end if;
if p_unit_price is null or p_unit_price<0 or p_unit_price>100000000000 or p_invoice_date is null or (p_due_date is not null and p_due_date<p_invoice_date) then raise exception 'Harga/tanggal tidak valid';end if;
insert into public.gas_documents(document_no,document_type,partner_id,status,created_by,approved_by,reference_no,invoice_date,due_date,recipient_name,notes)
values('INV-SJ-'||left(s.id::text,18),'SALE',s.customer_id,'APPROVED',auth.uid(),auth.uid(),'SJ-'||left(r.id::text,12),p_invoice_date,p_due_date,s.receiver_name,'Invoice berdasarkan pengiriman sopir terverifikasi') returning id into v_doc;
insert into public.gas_document_items(document_id,product_id,quantity_full,quantity_empty,sale_mode) values(v_doc,r.product_id,s.full_qty,s.empty_qty,'EXCHANGE') returning id into v_item;
insert into public.gas_financial_entries(document_item_id,unit_price,total) values(v_item,p_unit_price,p_unit_price*s.full_qty);
update public.gas_trip_stops set invoice_document_id=v_doc where id=p_stop;
return v_doc;
end;$function$
;
CREATE OR REPLACE FUNCTION public.gaspos_invoice_trip_customer(p_trip uuid, p_customer uuid, p_unit_price numeric, p_invoice_date date, p_due_date date)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare t public.gas_trips%rowtype;r public.gas_logistics_requests%rowtype;v_doc uuid;v_item uuid;v_full integer;v_empty integer;v_count int;
begin
if auth.uid() is null or gaspos_private.current_role()<>'OWNER' then raise exception 'Hanya Owner dapat membuat invoice';end if;
select * into t from public.gas_trips where id=p_trip for update;
if not found or t.status not in ('ON_ROUTE','RETURNED') then raise exception 'Perjalanan tidak valid';end if;
select * into r from public.gas_logistics_requests where id=t.request_id;
if p_unit_price is null or p_unit_price<0 or p_unit_price>100000000000 or p_invoice_date is null or (p_due_date is not null and p_due_date<p_invoice_date) then raise exception 'Harga dan tanggal tidak valid';end if;
if exists(select 1 from public.gas_trip_stops where trip_id=p_trip and customer_id=p_customer and invoice_document_id is null and not receiver_confirmed) then raise exception 'Ada pengiriman belum dikonfirmasi';end if;
select count(*),coalesce(sum(full_qty),0)::int,coalesce(sum(empty_qty),0)::int into v_count,v_full,v_empty
from public.gas_trip_stops where trip_id=p_trip and customer_id=p_customer and invoice_document_id is null and receiver_confirmed;
if v_count=0 then raise exception 'Tidak ada pengiriman siap ditagihkan';end if;
insert into public.gas_documents(document_no,document_type,partner_id,status,created_by,approved_by,reference_no,invoice_date,due_date,notes)
values('INV-GAB-'||left(gen_random_uuid()::text,18),'SALE',p_customer,'APPROVED',auth.uid(),auth.uid(),'SJ-'||left(r.id::text,12),p_invoice_date,p_due_date,'Gabungan pengiriman Sopir pada satu perjalanan, tanpa posting stok') returning id into v_doc;
insert into public.gas_document_items(document_id,product_id,quantity_full,quantity_empty,sale_mode)
values(v_doc,r.product_id,v_full,v_empty,'EXCHANGE') returning id into v_item;
insert into public.gas_financial_entries(document_item_id,unit_price,total) values(v_item,p_unit_price,p_unit_price*v_full);
update public.gas_trip_stops set invoice_document_id=v_doc where trip_id=p_trip and customer_id=p_customer and invoice_document_id is null and receiver_confirmed;
return v_doc;
end;$function$
;

-- Logistik confirms physical arrival directly; one receipt posts stock once.
CREATE OR REPLACE FUNCTION public.gaspos_confirm_purchase_arrival(p_purchase uuid,p_product uuid,p_full integer,p_empty integer,p_notes text,p_request uuid DEFAULT NULL)
RETURNS uuid LANGUAGE plpgsql SECURITY DEFINER SET search_path TO '' AS $$
declare d public.gas_documents%rowtype;old public.gas_logistics_requests%rowtype;item uuid;line_count integer;request_id uuid:=coalesce(p_request,gen_random_uuid());
begin
 if auth.uid() is null or gaspos_private.current_role() not in ('OWNER','LOGISTIK') then raise exception 'Hanya Logistik atau Owner mengonfirmasi barang datang';end if;
 perform pg_advisory_xact_lock(948621);
 select * into old from public.gas_logistics_requests where id=request_id;
 if found then
  if old.created_by is distinct from auth.uid() or old.status<>'APPROVED' or old.purchase_document_id is distinct from p_purchase or old.product_id is distinct from p_product or old.full_qty is distinct from p_full or old.empty_qty is distinct from p_empty then raise exception 'Nomor permintaan sudah digunakan';end if;
  return old.document_id;
 end if;
 select * into d from public.gas_documents where id=p_purchase for update;
 if not found or d.document_type<>'PURCHASE' or d.status not in ('DRAFT','PARTIAL') then raise exception 'Pembelian sudah diterima atau tidak ditemukan';end if;
 select count(*),(array_agg(id))[1] into line_count,item from public.gas_document_items where document_id=p_purchase and product_id=p_product;
 if line_count<>1 then raise exception 'Periksa rincian jenis tabung pada pembelian';end if;
 if exists(select 1 from public.gas_logistics_requests where purchase_document_id=p_purchase and product_id=p_product and status='PENDING') then raise exception 'Masih ada pengajuan lama yang menunggu penyelesaian';end if;
 perform gaspos_private.receive_purchase(p_purchase,jsonb_build_array(jsonb_build_object('item_id',item,'quantity_full',p_full,'quantity_empty',p_empty)),request_id);
 insert into public.gas_logistics_requests(id,direction,partner_id,product_id,full_qty,empty_qty,notes,created_by,status,reviewed_by,reviewed_at,document_id,purchase_document_id)
 values(request_id,'IN',d.partner_id,p_product,p_full,p_empty,nullif(left(btrim(p_notes),500),''),auth.uid(),'APPROVED',auth.uid(),now(),p_purchase,p_purchase);
 return p_purchase;
end $$;
REVOKE ALL ON FUNCTION public.gaspos_confirm_purchase_arrival(uuid,uuid,integer,integer,text,uuid) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.gaspos_confirm_purchase_arrival(uuid,uuid,integer,integer,text,uuid) TO authenticated;

-- Logistik issues an SJ and assigns its vehicle/driver in the same transaction.
CREATE OR REPLACE FUNCTION public.gaspos_create_delivery_sj(p_product uuid,p_full integer,p_driver uuid,p_plate text,p_notes text,p_request uuid DEFAULT NULL)
RETURNS uuid LANGUAGE plpgsql SECURITY DEFINER SET search_path TO '' AS $$
declare request_id uuid:=coalesce(p_request,gen_random_uuid());old public.gas_logistics_requests%rowtype;trip public.gas_trips%rowtype;stock bigint;doc uuid;item uuid;plate text:=upper(left(btrim(coalesce(p_plate,'')),24));
begin
 if auth.uid() is null or gaspos_private.current_role() not in ('OWNER','LOGISTIK') then raise exception 'Hanya Logistik atau Owner membuat Surat Jalan';end if;
 perform pg_advisory_xact_lock(948621);
 select * into old from public.gas_logistics_requests where id=request_id;
 if found then
  select * into trip from public.gas_trips t where t.request_id=old.id;
  if old.created_by is distinct from auth.uid() or old.status<>'APPROVED' or old.direction<>'OUT' or old.purchase_document_id is not null or old.product_id is distinct from p_product or old.full_qty is distinct from p_full or old.empty_qty<>0 or trip.id is null or trip.driver_user_id is distinct from p_driver or trip.vehicle_plate is distinct from plate then raise exception 'Nomor permintaan sudah digunakan';end if;
  return old.id;
 end if;
 if p_full is null or p_full not between 1 and 1000000 then raise exception 'Isi jumlah tabung penuh dengan benar';end if;
 if not exists(select 1 from public.gas_products where id=p_product) then raise exception 'Pilih jenis tabung';end if;
 if not exists(select 1 from public.gas_members where user_id=p_driver and role='SALES_SOPIR' and active) then raise exception 'Pilih Sopir aktif';end if;
 if length(plate)<3 then raise exception 'Isi nomor kendaraan';end if;
 select coalesce(sum(m.delta_full),0) into stock from public.gas_stock_movements m join public.gas_document_items i on i.id=m.document_item_id where i.product_id=p_product;
 if stock<p_full then raise exception 'Stok penuh gudang tidak cukup';end if;
 insert into public.gas_documents(document_no,document_type,status,created_by,approved_by,notes)
 values('LOG-'||request_id::text,'DISPATCH','APPROVED',auth.uid(),auth.uid(),nullif(left(btrim(p_notes),500),'')) returning id into doc;
 insert into public.gas_document_items(document_id,product_id,quantity_full,quantity_empty) values(doc,p_product,p_full,0) returning id into item;
 insert into public.gas_stock_movements(document_item_id,movement_key,delta_full,delta_empty) values(item,'LOG-'||request_id::text,-p_full,0);
 insert into public.gas_logistics_requests(id,direction,product_id,full_qty,empty_qty,notes,created_by,status,reviewed_by,reviewed_at,document_id)
 values(request_id,'OUT',p_product,p_full,0,nullif(left(btrim(p_notes),500),''),auth.uid(),'APPROVED',auth.uid(),now(),doc);
 insert into public.gas_trips(request_id,driver_user_id,vehicle_plate) values(request_id,p_driver,plate);
 return request_id;
end $$;
REVOKE ALL ON FUNCTION public.gaspos_create_delivery_sj(uuid,integer,uuid,text,text,uuid) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.gaspos_create_delivery_sj(uuid,integer,uuid,text,text,uuid) TO authenticated;

-- Customer physical empty-cylinder balance starts at confirmed delivery, not vehicle return.
CREATE OR REPLACE FUNCTION public.gaspos_customer_empty_all_balances()
RETURNS TABLE(customer_id uuid,product_id uuid,owed_qty bigint)
LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO '' AS $$
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
FROM (SELECT * FROM legacy UNION ALL SELECT * FROM trips UNION ALL SELECT * FROM trip_returns) x
WHERE gaspos_private.current_role()='OWNER'
GROUP BY x.customer_id,x.product_id;
$$;
