alter table public.gas_document_items drop constraint gas_document_items_purchase_mode_check;
alter table public.gas_document_items add constraint gas_document_items_purchase_mode_check check (purchase_mode in ('EXCHANGE','REFILL_NO_EXCHANGE','NEW_CYLINDER','EMPTY_ONLY'));
CREATE OR REPLACE FUNCTION gaspos_private.create_purchase(p_partner_id uuid, p_notes text, p_items jsonb, p_reference text, p_invoice_date date, p_due_date date, p_freight numeric, p_other numeric)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare v_id uuid;v_item_id uuid;v_no text;v_item jsonb;v_mode text;v_product uuid;v_qty integer;v_empty integer;v_price numeric;v_cyl numeric;
begin
 if auth.uid() is null or gaspos_private.current_role()<>'OWNER' then raise exception 'Khusus Owner';end if;
 if not exists(select 1 from public.gas_partners where id=p_partner_id and partner_type='SUPPLIER') then raise exception 'Suplayer tidak valid';end if;
 if p_items is null or jsonb_typeof(p_items)<>'array' or jsonb_array_length(p_items) not between 1 and 100 then raise exception 'Minimal satu barang diperlukan';end if;
 if p_freight is null or p_other is null or p_freight<0 or p_other<0 or p_freight>100000000000 or p_other>100000000000 then raise exception 'Biaya tidak valid';end if;
 if p_invoice_date is not null and p_due_date is not null and p_due_date<p_invoice_date then raise exception 'Jatuh tempo sebelum tanggal faktur';end if;
 for v_item in select value from jsonb_array_elements(p_items) loop
  if jsonb_typeof(v_item)<>'object' or coalesce(v_item->>'quantity_full','') !~ '^[0-9]+$' or coalesce(v_item->>'quantity_empty','0') !~ '^[0-9]+$' or coalesce(v_item->>'unit_price','') !~ '^[0-9]+$' or coalesce(v_item->>'cylinder_unit_price','0') !~ '^[0-9]+$' then raise exception 'Jumlah atau harga tidak valid';end if;
  v_product:=(v_item->>'product_id')::uuid;v_qty:=(v_item->>'quantity_full')::integer;v_empty:=coalesce(v_item->>'quantity_empty','0')::integer;v_price:=(v_item->>'unit_price')::numeric;v_cyl:=coalesce(v_item->>'cylinder_unit_price','0')::numeric;v_mode:=coalesce(v_item->>'purchase_mode','EXCHANGE');
  if v_mode not in('EXCHANGE','REFILL_NO_EXCHANGE','NEW_CYLINDER','EMPTY_ONLY') or (v_mode in ('NEW_CYLINDER','REFILL_NO_EXCHANGE') and v_empty<>0) or (v_mode<>'NEW_CYLINDER' and v_cyl<>0) or (v_mode='EMPTY_ONLY' and (v_qty<>0 or v_empty<1)) or (v_mode<>'EMPTY_ONLY' and v_qty not between 1 and 1000000) or v_empty not between 0 and 1000000 or v_price<0 or v_cyl<0 or v_price+v_cyl>100000000000 or not exists(select 1 from public.gas_products where id=v_product) then raise exception 'Barang dan harga tidak valid';end if;
 end loop;
 v_no:='BEL-'||to_char(clock_timestamp(),'YYYYMMDDHH24MISSMS')||'-'||upper(substr(replace(gen_random_uuid()::text,'-',''),1,5));
 insert into public.gas_documents(document_no,document_type,partner_id,status,created_by,notes,reference_no,invoice_date,due_date,freight_cost,other_cost) values(v_no,'PURCHASE',p_partner_id,'DRAFT',auth.uid(),nullif(btrim(p_notes),''),nullif(left(btrim(p_reference),120),''),p_invoice_date,p_due_date,p_freight,p_other) returning id into v_id;
 for v_item in select value from jsonb_array_elements(p_items) loop
  v_qty:=(v_item->>'quantity_full')::integer;v_empty:=coalesce(v_item->>'quantity_empty','0')::integer;v_price:=(v_item->>'unit_price')::numeric;v_cyl:=coalesce(v_item->>'cylinder_unit_price','0')::numeric;
  insert into public.gas_document_items(document_id,product_id,quantity_full,quantity_empty,purchase_mode,cylinder_unit_price) values(v_id,(v_item->>'product_id')::uuid,v_qty,v_empty,coalesce(v_item->>'purchase_mode','EXCHANGE'),v_cyl) returning id into v_item_id;
  insert into public.gas_financial_entries(document_item_id,unit_price,total) values(v_item_id,v_price+v_cyl,(v_price+v_cyl)*case when coalesce(v_item->>'purchase_mode','EXCHANGE')='EMPTY_ONLY' then v_empty else v_qty end);
 end loop;
 return v_id;
end;
$function$;
CREATE OR REPLACE FUNCTION gaspos_private.update_purchase(p_id uuid, p_partner_id uuid, p_notes text, p_items jsonb, p_reference text, p_invoice_date date, p_due_date date, p_freight numeric, p_other numeric)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare d public.gas_documents%rowtype;v_item jsonb;v_mode text;v_product uuid;v_qty integer;v_empty integer;v_price numeric;v_cyl numeric;v_id uuid;
begin
 if auth.uid() is null or gaspos_private.current_role()<>'OWNER' then raise exception 'Khusus Owner';end if;
 select * into d from public.gas_documents where id=p_id for update;
 if not found or d.document_type<>'PURCHASE' or d.status<>'DRAFT' then raise exception 'Hanya Pembelian DRAFT dapat diubah';end if;
 if not exists(select 1 from public.gas_partners where id=p_partner_id and partner_type='SUPPLIER') then raise exception 'Suplayer tidak valid';end if;
 if p_freight is null or p_other is null or p_freight<0 or p_other<0 or p_freight>100000000000 or p_other>100000000000 then raise exception 'Biaya tidak valid';end if;
 if p_invoice_date is not null and p_due_date is not null and p_due_date<p_invoice_date then raise exception 'Jatuh tempo sebelum tanggal faktur';end if;
 if p_items is null or jsonb_typeof(p_items)<>'array' or jsonb_array_length(p_items) not between 1 and 100 then raise exception 'Daftar barang kosong';end if;
 for v_item in select value from jsonb_array_elements(p_items) loop
  if jsonb_typeof(v_item)<>'object' or coalesce(v_item->>'quantity_full','') !~ '^[0-9]+$' or coalesce(v_item->>'quantity_empty','0') !~ '^[0-9]+$' or coalesce(v_item->>'unit_price','') !~ '^[0-9]+$' or coalesce(v_item->>'cylinder_unit_price','0') !~ '^[0-9]+$' then raise exception 'Nilai barang tidak valid';end if;
  v_product:=(v_item->>'product_id')::uuid;v_qty:=(v_item->>'quantity_full')::integer;v_empty:=coalesce(v_item->>'quantity_empty','0')::integer;v_price:=(v_item->>'unit_price')::numeric;v_cyl:=coalesce(v_item->>'cylinder_unit_price','0')::numeric;v_mode:=coalesce(v_item->>'purchase_mode','EXCHANGE');
  if v_mode not in('EXCHANGE','REFILL_NO_EXCHANGE','NEW_CYLINDER','EMPTY_ONLY') or (v_mode in ('NEW_CYLINDER','REFILL_NO_EXCHANGE') and v_empty<>0) or (v_mode<>'NEW_CYLINDER' and v_cyl<>0) or (v_mode='EMPTY_ONLY' and (v_qty<>0 or v_empty<1)) or (v_mode<>'EMPTY_ONLY' and v_qty not between 1 and 1000000) or v_empty not between 0 and 1000000 or v_price<0 or v_cyl<0 or v_price+v_cyl>100000000000 or not exists(select 1 from public.gas_products where id=v_product) then raise exception 'Barang tidak valid';end if;
 end loop;
 delete from public.gas_financial_entries where document_item_id in(select id from public.gas_document_items where document_id=p_id);
 delete from public.gas_document_items where document_id=p_id;
 update public.gas_documents set partner_id=p_partner_id,notes=nullif(btrim(p_notes),''),reference_no=nullif(left(btrim(p_reference),120),''),invoice_date=p_invoice_date,due_date=p_due_date,freight_cost=p_freight,other_cost=p_other where id=p_id;
 for v_item in select value from jsonb_array_elements(p_items) loop
  v_qty:=(v_item->>'quantity_full')::integer;v_empty:=coalesce(v_item->>'quantity_empty','0')::integer;v_price:=(v_item->>'unit_price')::numeric;v_cyl:=coalesce(v_item->>'cylinder_unit_price','0')::numeric;
  insert into public.gas_document_items(document_id,product_id,quantity_full,quantity_empty,purchase_mode,cylinder_unit_price) values(p_id,(v_item->>'product_id')::uuid,v_qty,v_empty,coalesce(v_item->>'purchase_mode','EXCHANGE'),v_cyl) returning id into v_id;
  insert into public.gas_financial_entries(document_item_id,unit_price,total) values(v_id,v_price+v_cyl,(v_price+v_cyl)*case when coalesce(v_item->>'purchase_mode','EXCHANGE')='EMPTY_ONLY' then v_empty else v_qty end);
 end loop;
 return p_id;
end;
$function$;
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
  select coalesce(sum(m.delta_full),0),coalesce(sum(case when v.purchase_mode='EMPTY_ONLY' then m.delta_empty else -m.delta_empty end),0) into v_seen_full,v_seen_empty from public.gas_stock_movements m where m.document_item_id=v.id;
  if v_seen_full+v_full>v.quantity_full or v_seen_empty+v_empty>v.quantity_empty then raise exception 'Penerimaan melebihi pesanan';end if;
  if v_empty>0 and v.purchase_mode<>'EMPTY_ONLY' then
   select coalesce(sum(m.delta_empty),0) into v_stock from public.gas_stock_movements m join public.gas_document_items i on i.id=m.document_item_id where i.product_id=v.product_id;
   if v_stock<v_empty then raise exception 'Stok tabung kosong tidak mencukupi';end if;
  end if;
  insert into public.gas_stock_movements(document_item_id,movement_key,delta_full,delta_empty) values(v.id,'RECEIPT-'||p_request::text||'-'||v.id::text,v_full,case when v.purchase_mode='EMPTY_ONLY' then v_empty else -v_empty end);
  if v.purchase_mode not in ('NEW_CYLINDER','EMPTY_ONLY') then
   v_owed:=greatest(0,v_seen_full+v_full-v_seen_empty-v_empty);
   insert into public.gas_empty_obligations(document_item_id,supplier_id,owed_qty) values(v.id,d.partner_id,v_owed)
   on conflict(document_item_id) do update set owed_qty=excluded.owed_qty;
  end if;
 end loop;
 for v in select id,quantity_full,quantity_empty,purchase_mode from public.gas_document_items where document_id=p_id loop
  select coalesce(sum(m.delta_full),0),coalesce(sum(case when v.purchase_mode='EMPTY_ONLY' then m.delta_empty else -m.delta_empty end),0) into v_total_full,v_total_empty from public.gas_stock_movements m where m.document_item_id=v.id;
  if v_total_full<v.quantity_full or v_total_empty<v.quantity_empty then v_complete:=false;end if;
 end loop;
 update public.gas_documents set status=case when v_complete then 'APPROVED' else 'PARTIAL' end,approved_by=case when v_complete then auth.uid() else null end where id=p_id;
 return p_id;
end;
$function$;
CREATE OR REPLACE FUNCTION public.gaspos_pending_purchase_lines()
 RETURNS TABLE(document_id uuid, document_no text, supplier_id uuid, product_id uuid, product_name text, remaining_full bigint, remaining_empty bigint)
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
select d.id,coalesce(d.display_no,d.document_no),d.partner_id,i.product_id,p.name,
(i.quantity_full-coalesce(m.full_qty,0)-coalesce(pending.full_qty,0))::bigint,
(i.quantity_empty-coalesce(m.empty_qty,0)-coalesce(pending.empty_qty,0))::bigint
from public.gas_documents d join public.gas_document_items i on i.document_id=d.id join public.gas_products p on p.id=i.product_id
left join lateral(select sum(delta_full) full_qty,sum(case when i.purchase_mode='EMPTY_ONLY' then delta_empty else -delta_empty end) empty_qty from public.gas_stock_movements where document_item_id=i.id) m on true
left join lateral(select sum(full_qty) full_qty,sum(empty_qty) empty_qty from public.gas_logistics_requests r where r.purchase_document_id=d.id and r.product_id=i.product_id and r.status='PENDING') pending on true
where d.document_type='PURCHASE' and d.status in ('DRAFT','PARTIAL')
and gaspos_private.current_role() in ('OWNER','LOGISTIK')
and 1=(select count(*) from public.gas_document_items x where x.document_id=d.id and x.product_id=i.product_id)
and (i.quantity_full>coalesce(m.full_qty,0)+coalesce(pending.full_qty,0) or i.quantity_empty>coalesce(m.empty_qty,0)+coalesce(pending.empty_qty,0))
$function$;
