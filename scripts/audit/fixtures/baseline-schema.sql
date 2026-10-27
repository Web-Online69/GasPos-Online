CREATE ROLE authenticated; CREATE ROLE anon; CREATE SCHEMA auth; CREATE SCHEMA gaspos_private; CREATE TABLE auth.users(id uuid primary key, email text, raw_user_meta_data jsonb DEFAULT '{}'::jsonb); CREATE FUNCTION auth.uid() RETURNS uuid LANGUAGE sql STABLE AS $$select nullif(current_setting('request.jwt.claim.sub', true),'')::uuid$$; CREATE SEQUENCE public.gas_product_code_seq; 
CREATE TABLE public.gas_customer_empty_obligations ("item_id" uuid NOT NULL,"customer_id" uuid NOT NULL,"owed_qty" integer NOT NULL);
CREATE TABLE public.gas_customer_empty_returns ("id" uuid DEFAULT gen_random_uuid() NOT NULL,"obligation_item_id" uuid NOT NULL,"quantity" integer NOT NULL,"request_id" uuid NOT NULL,"document_id" uuid NOT NULL,"created_at" timestamp with time zone DEFAULT now() NOT NULL);
CREATE TABLE public.gas_customer_prices ("customer_id" uuid NOT NULL,"product_id" uuid NOT NULL,"price" numeric(18,2) NOT NULL);
CREATE TABLE public.gas_customer_refunds ("id" uuid DEFAULT gen_random_uuid() NOT NULL,"document_id" uuid NOT NULL,"amount" numeric NOT NULL,"request_id" uuid NOT NULL,"created_at" timestamp with time zone DEFAULT now());
CREATE TABLE public.gas_document_items ("id" uuid DEFAULT gen_random_uuid() NOT NULL,"document_id" uuid NOT NULL,"product_id" uuid NOT NULL,"quantity_full" integer DEFAULT 0 NOT NULL,"quantity_empty" integer DEFAULT 0 NOT NULL,"purchase_mode" text DEFAULT 'EXCHANGE'::text NOT NULL,"cylinder_unit_price" numeric DEFAULT 0 NOT NULL,"sale_mode" text DEFAULT 'EXCHANGE'::text NOT NULL);
CREATE TABLE public.gas_documents ("id" uuid DEFAULT gen_random_uuid() NOT NULL,"document_no" text NOT NULL,"document_type" text NOT NULL,"partner_id" uuid,"status" text DEFAULT 'DRAFT'::text NOT NULL,"created_by" uuid,"approved_by" uuid,"reference_no" text,"notes" text,"created_at" timestamp with time zone DEFAULT now() NOT NULL,"invoice_date" date,"due_date" date,"freight_cost" numeric DEFAULT 0 NOT NULL,"other_cost" numeric DEFAULT 0 NOT NULL,"recipient_name" text);
CREATE TABLE public.gas_empty_obligations ("document_item_id" uuid NOT NULL,"supplier_id" uuid NOT NULL,"owed_qty" integer NOT NULL,"created_at" timestamp with time zone DEFAULT now() NOT NULL);
CREATE TABLE public.gas_empty_returns ("id" uuid DEFAULT gen_random_uuid() NOT NULL,"obligation_item_id" uuid NOT NULL,"quantity" integer NOT NULL,"request_id" uuid NOT NULL,"created_by" uuid NOT NULL,"created_at" timestamp with time zone DEFAULT now() NOT NULL,"document_id" uuid NOT NULL);
CREATE TABLE public.gas_financial_entries ("id" uuid DEFAULT gen_random_uuid() NOT NULL,"document_item_id" uuid NOT NULL,"unit_price" numeric(18,2) NOT NULL,"total" numeric(18,2) NOT NULL,"created_at" timestamp with time zone DEFAULT now() NOT NULL);
CREATE TABLE public.gas_inventory_opening_costs ("product_id" uuid NOT NULL,"full_qty" integer NOT NULL,"unit_cost" numeric(16,2) NOT NULL,"notes" text,"created_by" uuid NOT NULL,"created_at" timestamp with time zone DEFAULT now() NOT NULL);
CREATE TABLE public.gas_logistics_requests ("id" uuid DEFAULT gen_random_uuid() NOT NULL,"direction" text NOT NULL,"partner_id" uuid,"product_id" uuid NOT NULL,"full_qty" integer DEFAULT 0 NOT NULL,"empty_qty" integer DEFAULT 0 NOT NULL,"notes" text,"created_by" uuid NOT NULL,"created_at" timestamp with time zone DEFAULT now() NOT NULL,"status" text DEFAULT 'PENDING'::text NOT NULL,"reviewed_by" uuid,"reviewed_at" timestamp with time zone,"rejection_reason" text,"document_id" uuid);
CREATE TABLE public.gas_members ("user_id" uuid NOT NULL,"role" text NOT NULL,"active" boolean DEFAULT true NOT NULL);
CREATE TABLE public.gas_operating_expenses ("id" uuid DEFAULT gen_random_uuid() NOT NULL,"expense_date" date DEFAULT CURRENT_DATE NOT NULL,"category" text NOT NULL,"description" text NOT NULL,"amount" numeric(16,2) NOT NULL,"created_by" uuid NOT NULL,"created_at" timestamp with time zone DEFAULT now() NOT NULL);
CREATE TABLE public.gas_partners ("id" uuid DEFAULT gen_random_uuid() NOT NULL,"name" text NOT NULL,"partner_type" text NOT NULL,"phone" text,"address" text,"created_at" timestamp with time zone DEFAULT now() NOT NULL);
CREATE TABLE public.gas_payments ("id" uuid DEFAULT gen_random_uuid() NOT NULL,"document_id" uuid NOT NULL,"amount" numeric(18,2) NOT NULL,"paid_at" timestamp with time zone DEFAULT now() NOT NULL);
CREATE TABLE public.gas_products ("id" uuid DEFAULT gen_random_uuid() NOT NULL,"code" text NOT NULL,"name" text NOT NULL,"created_at" timestamp with time zone DEFAULT now() NOT NULL);
CREATE TABLE public.gas_purchase_returns ("id" uuid DEFAULT gen_random_uuid() NOT NULL,"purchase_item_id" uuid NOT NULL,"return_document_id" uuid NOT NULL,"quantity" integer NOT NULL,"unit_price" numeric NOT NULL,"amount" numeric NOT NULL,"reason" text NOT NULL,"request_id" uuid NOT NULL,"created_by" uuid NOT NULL,"created_at" timestamp with time zone DEFAULT now() NOT NULL);
CREATE TABLE public.gas_sale_returns ("id" uuid DEFAULT gen_random_uuid() NOT NULL,"sale_item_id" uuid NOT NULL,"document_id" uuid NOT NULL,"quantity" integer NOT NULL,"unit_price" numeric NOT NULL,"amount" numeric NOT NULL,"reason" text NOT NULL,"request_id" uuid NOT NULL,"created_at" timestamp with time zone DEFAULT now() NOT NULL,"empty_reissued" integer DEFAULT 0 NOT NULL);
CREATE TABLE public.gas_stock_movements ("id" uuid DEFAULT gen_random_uuid() NOT NULL,"document_item_id" uuid NOT NULL,"movement_key" text NOT NULL,"delta_full" integer DEFAULT 0 NOT NULL,"delta_empty" integer DEFAULT 0 NOT NULL,"created_at" timestamp with time zone DEFAULT now() NOT NULL);
CREATE TABLE public.gas_supplier_refunds ("id" uuid DEFAULT gen_random_uuid() NOT NULL,"document_id" uuid NOT NULL,"amount" numeric NOT NULL,"request_id" uuid NOT NULL,"created_by" uuid NOT NULL,"received_at" timestamp with time zone DEFAULT now() NOT NULL);
CREATE TABLE public.gas_trip_stop_audit ("id" bigint NOT NULL,"stop_id" uuid NOT NULL,"changed_at" timestamp with time zone DEFAULT now() NOT NULL,"changed_by" uuid,"old_customer_id" uuid,"old_full" integer,"old_empty" integer,"new_customer_id" uuid,"new_full" integer,"new_empty" integer,"reason" text);
CREATE TABLE public.gas_trip_stops ("id" uuid DEFAULT gen_random_uuid() NOT NULL,"trip_id" uuid NOT NULL,"customer_id" uuid NOT NULL,"full_qty" integer NOT NULL,"empty_qty" integer NOT NULL,"notes" text,"created_by" uuid NOT NULL,"created_at" timestamp with time zone DEFAULT now() NOT NULL,"receiver_name" text,"receiver_confirmed" boolean DEFAULT false NOT NULL,"confirmed_at" timestamp with time zone,"correction_note" text,"corrected_by" uuid,"corrected_at" timestamp with time zone,"invoice_document_id" uuid,"receiver_signature" jsonb);
CREATE TABLE public.gas_trips ("id" uuid DEFAULT gen_random_uuid() NOT NULL,"request_id" uuid NOT NULL,"driver_user_id" uuid NOT NULL,"vehicle_plate" text NOT NULL,"status" text DEFAULT 'ON_ROUTE'::text NOT NULL,"created_at" timestamp with time zone DEFAULT now() NOT NULL,"returned_at" timestamp with time zone,"return_full" integer,"return_empty" integer,"returned_by" uuid);
ALTER TABLE public.gas_customer_empty_obligations ADD CHECK ((owed_qty >= 0));
ALTER TABLE public.gas_customer_empty_returns ADD CHECK ((quantity > 0));
ALTER TABLE public.gas_customer_prices ADD CHECK ((price >= (0)::numeric));
ALTER TABLE public.gas_customer_refunds ADD CHECK ((amount > (0)::numeric));
ALTER TABLE public.gas_document_items ADD CHECK ((quantity_full >= 0));
ALTER TABLE public.gas_document_items ADD CHECK ((purchase_mode = ANY (ARRAY['EXCHANGE'::text, 'REFILL_NO_EXCHANGE'::text, 'NEW_CYLINDER'::text])));
ALTER TABLE public.gas_document_items ADD CHECK ((sale_mode = ANY (ARRAY['EXCHANGE'::text, 'NO_EXCHANGE'::text, 'NEW_CYLINDER'::text])));
ALTER TABLE public.gas_document_items ADD CHECK ((cylinder_unit_price >= (0)::numeric));
ALTER TABLE public.gas_document_items ADD CHECK ((quantity_empty >= 0));
ALTER TABLE public.gas_documents ADD CHECK ((status = ANY (ARRAY['DRAFT'::text, 'PENDING'::text, 'PARTIAL'::text, 'APPROVED'::text, 'CANCELLED'::text])));
ALTER TABLE public.gas_documents ADD CHECK ((freight_cost >= (0)::numeric));
ALTER TABLE public.gas_documents ADD CHECK ((other_cost >= (0)::numeric));
ALTER TABLE public.gas_documents ADD CHECK ((document_type = ANY (ARRAY['PURCHASE'::text, 'SALE'::text, 'RECEIPT'::text, 'DISPATCH'::text, 'EMPTY_RETURN'::text, 'STOCK_ADJUSTMENT'::text])));
ALTER TABLE public.gas_empty_obligations ADD CHECK ((owed_qty >= 0));
ALTER TABLE public.gas_empty_returns ADD CHECK ((quantity > 0));
ALTER TABLE public.gas_financial_entries ADD CHECK ((total >= (0)::numeric));
ALTER TABLE public.gas_financial_entries ADD CHECK ((unit_price >= (0)::numeric));
ALTER TABLE public.gas_inventory_opening_costs ADD CHECK ((unit_cost >= (0)::numeric));
ALTER TABLE public.gas_inventory_opening_costs ADD CHECK ((full_qty >= 0));
ALTER TABLE public.gas_logistics_requests ADD CHECK ((status = ANY (ARRAY['PENDING'::text, 'APPROVED'::text, 'REJECTED'::text])));
ALTER TABLE public.gas_logistics_requests ADD CHECK (((full_qty >= 0) AND (full_qty <= 1000000)));
ALTER TABLE public.gas_logistics_requests ADD CHECK ((direction = ANY (ARRAY['IN'::text, 'OUT'::text])));
ALTER TABLE public.gas_logistics_requests ADD CHECK (((full_qty > 0) OR (empty_qty > 0)));
ALTER TABLE public.gas_logistics_requests ADD CHECK (((empty_qty >= 0) AND (empty_qty <= 1000000)));
ALTER TABLE public.gas_members ADD CHECK ((role = ANY (ARRAY['OWNER'::text, 'LOGISTIK'::text, 'SALES_SOPIR'::text, 'KEUANGAN'::text])));
ALTER TABLE public.gas_operating_expenses ADD CHECK (((length(btrim(description)) >= 1) AND (length(btrim(description)) <= 300)));
ALTER TABLE public.gas_operating_expenses ADD CHECK (((amount > (0)::numeric) AND (amount <= ('100000000000'::bigint)::numeric)));
ALTER TABLE public.gas_operating_expenses ADD CHECK ((category = ANY (ARRAY['BBM'::text, 'TOL_PARKIR'::text, 'MAKAN'::text, 'BONGKAR_MUAT'::text, 'PERAWATAN'::text, 'LAINNYA'::text])));
ALTER TABLE public.gas_partners ADD CHECK ((partner_type = ANY (ARRAY['CUSTOMER'::text, 'SUPPLIER'::text])));
ALTER TABLE public.gas_payments ADD CHECK ((amount > (0)::numeric));
ALTER TABLE public.gas_purchase_returns ADD CHECK ((unit_price >= (0)::numeric));
ALTER TABLE public.gas_purchase_returns ADD CHECK ((amount >= (0)::numeric));
ALTER TABLE public.gas_purchase_returns ADD CHECK ((quantity > 0));
ALTER TABLE public.gas_sale_returns ADD CHECK ((unit_price >= (0)::numeric));
ALTER TABLE public.gas_sale_returns ADD CHECK ((quantity > 0));
ALTER TABLE public.gas_sale_returns ADD CHECK ((amount >= (0)::numeric));
ALTER TABLE public.gas_sale_returns ADD CHECK ((empty_reissued >= 0));
ALTER TABLE public.gas_supplier_refunds ADD CHECK ((amount > (0)::numeric));
ALTER TABLE public.gas_trip_stops ADD CHECK ((empty_qty >= 0));
ALTER TABLE public.gas_trip_stops ADD CHECK ((full_qty > 0));
ALTER TABLE public.gas_trips ADD CHECK ((status = ANY (ARRAY['ON_ROUTE'::text, 'RETURNED'::text])));
ALTER TABLE public.gas_customer_empty_obligations ADD PRIMARY KEY (item_id);
ALTER TABLE public.gas_customer_empty_returns ADD PRIMARY KEY (id);
ALTER TABLE public.gas_customer_prices ADD PRIMARY KEY (customer_id, product_id);
ALTER TABLE public.gas_customer_refunds ADD PRIMARY KEY (id);
ALTER TABLE public.gas_document_items ADD PRIMARY KEY (id);
ALTER TABLE public.gas_documents ADD PRIMARY KEY (id);
ALTER TABLE public.gas_empty_obligations ADD PRIMARY KEY (document_item_id);
ALTER TABLE public.gas_empty_returns ADD PRIMARY KEY (id);
ALTER TABLE public.gas_financial_entries ADD PRIMARY KEY (id);
ALTER TABLE public.gas_inventory_opening_costs ADD PRIMARY KEY (product_id);
ALTER TABLE public.gas_logistics_requests ADD PRIMARY KEY (id);
ALTER TABLE public.gas_members ADD PRIMARY KEY (user_id);
ALTER TABLE public.gas_operating_expenses ADD PRIMARY KEY (id);
ALTER TABLE public.gas_partners ADD PRIMARY KEY (id);
ALTER TABLE public.gas_payments ADD PRIMARY KEY (id);
ALTER TABLE public.gas_products ADD PRIMARY KEY (id);
ALTER TABLE public.gas_purchase_returns ADD PRIMARY KEY (id);
ALTER TABLE public.gas_sale_returns ADD PRIMARY KEY (id);
ALTER TABLE public.gas_stock_movements ADD PRIMARY KEY (id);
ALTER TABLE public.gas_supplier_refunds ADD PRIMARY KEY (id);
ALTER TABLE public.gas_trip_stop_audit ADD PRIMARY KEY (id);
ALTER TABLE public.gas_trip_stops ADD PRIMARY KEY (id);
ALTER TABLE public.gas_trips ADD PRIMARY KEY (id);
ALTER TABLE public.gas_customer_empty_returns ADD UNIQUE (request_id);
ALTER TABLE public.gas_customer_empty_returns ADD UNIQUE (document_id);
ALTER TABLE public.gas_customer_refunds ADD UNIQUE (request_id);
ALTER TABLE public.gas_documents ADD UNIQUE (document_no);
ALTER TABLE public.gas_empty_returns ADD UNIQUE (request_id);
ALTER TABLE public.gas_empty_returns ADD UNIQUE (document_id);
ALTER TABLE public.gas_logistics_requests ADD UNIQUE (document_id);
ALTER TABLE public.gas_products ADD UNIQUE (code);
ALTER TABLE public.gas_purchase_returns ADD UNIQUE (return_document_id);
ALTER TABLE public.gas_purchase_returns ADD UNIQUE (request_id);
ALTER TABLE public.gas_sale_returns ADD UNIQUE (document_id);
ALTER TABLE public.gas_sale_returns ADD UNIQUE (request_id);
ALTER TABLE public.gas_stock_movements ADD UNIQUE (movement_key);
ALTER TABLE public.gas_supplier_refunds ADD UNIQUE (request_id);
ALTER TABLE public.gas_trip_stops ADD UNIQUE (id, trip_id);
ALTER TABLE public.gas_trips ADD UNIQUE (request_id);
CREATE OR REPLACE FUNCTION gaspos_private.adjust_stock(p_product uuid, p_delta_full integer, p_delta_empty integer, p_notes text, p_request_id uuid)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare v_id uuid;v_item uuid;v_full bigint;v_empty bigint;v_no text;
begin
 if auth.uid() is null or gaspos_private.current_role()<>'OWNER' then raise exception 'Khusus Owner';end if;
 if p_product is null or not exists(select 1 from public.gas_products where id=p_product) then raise exception 'Produk tidak ditemukan';end if;
 if p_delta_full is null or p_delta_empty is null or (p_delta_full=0 and p_delta_empty=0) or abs(p_delta_full::bigint)>1000000 or abs(p_delta_empty::bigint)>1000000 then raise exception 'Jumlah penyesuaian tidak valid';end if;
 if p_notes is null or length(btrim(p_notes))<5 then raise exception 'Alasan penyesuaian minimal 5 karakter';end if;
 if p_request_id is null then raise exception 'ID transaksi wajib';end if;
 perform pg_advisory_xact_lock(948621);
 v_no:='ADJ-'||p_request_id::text;
 select id into v_id from public.gas_documents where document_no=v_no;
 if found then
  if not exists(select 1 from public.gas_documents where id=v_id and document_type='STOCK_ADJUSTMENT' and created_by=auth.uid()) then raise exception 'Kunci transaksi tidak valid';end if;
  return v_id;
 end if;
 select coalesce(sum(m.delta_full),0),coalesce(sum(m.delta_empty),0) into v_full,v_empty from public.gas_stock_movements m join public.gas_document_items i on i.id=m.document_item_id where i.product_id=p_product;
 if v_full+p_delta_full<0 or v_empty+p_delta_empty<0 then raise exception 'Penyesuaian menyebabkan stok negatif';end if;
 insert into public.gas_documents(document_no,document_type,partner_id,status,created_by,approved_by,notes) values(v_no,'STOCK_ADJUSTMENT',null,'APPROVED',auth.uid(),auth.uid(),btrim(p_notes)) returning id into v_id;
 insert into public.gas_document_items(document_id,product_id,quantity_full,quantity_empty) values(v_id,p_product,abs(p_delta_full),abs(p_delta_empty)) returning id into v_item;
 insert into public.gas_stock_movements(document_item_id,movement_key,delta_full,delta_empty) values(v_item,'ADJ-'||v_item::text,p_delta_full,p_delta_empty);
 return v_id;
end;
$function$
;
CREATE OR REPLACE FUNCTION gaspos_private.approve_trade(p_id uuid)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare d public.gas_documents%rowtype;it record;v_stock bigint;v_owed integer;
begin
 if auth.uid() is null or gaspos_private.current_role()<>'OWNER' then raise exception 'Khusus Owner';end if;
 perform pg_advisory_xact_lock(948621);
 select * into d from public.gas_documents where id=p_id for update;
 if not found or d.document_type not in ('PURCHASE','SALE') or d.status<>'DRAFT' then raise exception 'Hanya Draft Pembelian/Penjualan yang dapat disetujui';end if;
 raise exception 'Gunakan Terima Barang untuk Pembelian atau Kirim Barang untuk Penjualan'; if not exists(select 1 from public.gas_document_items where document_id=p_id) then raise exception 'Dokumen tidak punya barang';end if;
 for it in select id,product_id,quantity_full,quantity_empty,purchase_mode from public.gas_document_items where document_id=p_id order by id loop
  if it.quantity_full<=0 or it.quantity_empty<0 then raise exception 'Jumlah barang tidak valid';end if;
  if d.document_type='SALE' then
   select coalesce(sum(m.delta_full),0) into v_stock from public.gas_stock_movements m join public.gas_document_items x on x.id=m.document_item_id where x.product_id=it.product_id;
   if v_stock<it.quantity_full then raise exception 'Stok penuh tidak cukup';end if;
  elsif it.quantity_empty>0 then
   select coalesce(sum(m.delta_empty),0) into v_stock from public.gas_stock_movements m join public.gas_document_items x on x.id=m.document_item_id where x.product_id=it.product_id;
   if v_stock<it.quantity_empty then raise exception 'Stok tabung kosong tidak cukup';end if;
  end if;
  insert into public.gas_stock_movements(document_item_id,movement_key,delta_full,delta_empty) values(it.id,'TRADE-'||it.id::text,case when d.document_type='PURCHASE' then it.quantity_full else -it.quantity_full end,case when d.document_type='PURCHASE' then -it.quantity_empty else it.quantity_empty end);
  if d.document_type='PURCHASE' then
   v_owed:=case when it.purchase_mode='NEW_CYLINDER' then 0 else greatest(0,it.quantity_full-it.quantity_empty) end;
   if v_owed>0 then insert into public.gas_empty_obligations(document_item_id,supplier_id,owed_qty) values(it.id,d.partner_id,v_owed);end if;
  end if;
 end loop;
 update public.gas_documents set status='APPROVED',approved_by=auth.uid() where id=p_id;
end;
$function$
;
CREATE OR REPLACE FUNCTION gaspos_private.cancel_trade(p_id uuid)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare d public.gas_documents%rowtype;
begin
 if auth.uid() is null or gaspos_private.current_role()<>'OWNER' then raise exception 'Khusus Owner';end if;
 select * into d from public.gas_documents where id=p_id for update;
 if not found or d.document_type not in ('PURCHASE','SALE') or d.status<>'DRAFT' then raise exception 'Hanya transaksi DRAFT yang bisa dibatalkan';end if;
 update public.gas_documents set status='CANCELLED' where id=p_id;
end;
$function$
;
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
  if v_mode not in('EXCHANGE','REFILL_NO_EXCHANGE','NEW_CYLINDER') or (v_mode in ('NEW_CYLINDER','REFILL_NO_EXCHANGE') and v_empty<>0) or (v_mode<>'NEW_CYLINDER' and v_cyl<>0) or v_qty not between 1 and 1000000 or v_empty not between 0 and 1000000 or v_price<0 or v_cyl<0 or v_price+v_cyl>100000000000 or not exists(select 1 from public.gas_products where id=v_product) then raise exception 'Barang dan harga tidak valid';end if;
 end loop;
 v_no:='BEL-'||to_char(clock_timestamp(),'YYYYMMDDHH24MISSMS')||'-'||upper(substr(replace(gen_random_uuid()::text,'-',''),1,5));
 insert into public.gas_documents(document_no,document_type,partner_id,status,created_by,notes,reference_no,invoice_date,due_date,freight_cost,other_cost) values(v_no,'PURCHASE',p_partner_id,'DRAFT',auth.uid(),nullif(btrim(p_notes),''),nullif(left(btrim(p_reference),120),''),p_invoice_date,p_due_date,p_freight,p_other) returning id into v_id;
 for v_item in select value from jsonb_array_elements(p_items) loop
  v_qty:=(v_item->>'quantity_full')::integer;v_empty:=coalesce(v_item->>'quantity_empty','0')::integer;v_price:=(v_item->>'unit_price')::numeric;v_cyl:=coalesce(v_item->>'cylinder_unit_price','0')::numeric;
  insert into public.gas_document_items(document_id,product_id,quantity_full,quantity_empty,purchase_mode,cylinder_unit_price) values(v_id,(v_item->>'product_id')::uuid,v_qty,v_empty,coalesce(v_item->>'purchase_mode','EXCHANGE'),v_cyl) returning id into v_item_id;
  insert into public.gas_financial_entries(document_item_id,unit_price,total) values(v_item_id,v_price+v_cyl,(v_price+v_cyl)*v_qty);
 end loop;
 return v_id;
end;
$function$
;
CREATE OR REPLACE FUNCTION gaspos_private."current_role"()
 RETURNS text
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
 select m.role from public.gas_members m where m.user_id = (select auth.uid()) and m.active = true
$function$
;
CREATE OR REPLACE FUNCTION gaspos_private.customer_empty_return(p_item uuid, p_qty integer, p_request uuid)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare o public.gas_customer_empty_obligations%rowtype;v_old bigint;v_doc uuid;v_line uuid;v_product uuid;
begin
if auth.uid() is null or gaspos_private.current_role()<>'OWNER' then raise exception 'Khusus Owner';end if;
if p_request is null or p_qty is null or p_qty<1 or p_qty>1000000 then raise exception 'Jumlah tidak valid';end if;
perform pg_advisory_xact_lock(948621);
select document_id into v_doc from public.gas_customer_empty_returns where request_id=p_request;if found then return v_doc;end if;
select * into o from public.gas_customer_empty_obligations where item_id=p_item for update;if not found then raise exception 'Kewajiban tidak ada';end if;
select coalesce(sum(quantity),0) into v_old from public.gas_customer_empty_returns where obligation_item_id=p_item;
if v_old+p_qty>greatest(0,o.owed_qty-coalesce((select sum(quantity-empty_reissued) from public.gas_sale_returns where sale_item_id=p_item),0)) then raise exception 'Pengembalian melebihi sisa';end if;
select product_id into v_product from public.gas_document_items where id=p_item;
insert into public.gas_documents(document_no,document_type,partner_id,status,created_by,approved_by,notes) values('CER-'||p_request::text,'EMPTY_RETURN',o.customer_id,'APPROVED',auth.uid(),auth.uid(),'Pengembalian tabung kosong pelanggan') returning id into v_doc;
insert into public.gas_document_items(document_id,product_id,quantity_full,quantity_empty) values(v_doc,v_product,0,p_qty) returning id into v_line;
insert into public.gas_stock_movements(document_item_id,movement_key,delta_full,delta_empty) values(v_line,'CER-'||v_line::text,0,p_qty);
insert into public.gas_customer_empty_returns(obligation_item_id,quantity,request_id,document_id) values(p_item,p_qty,p_request,v_doc);
return v_doc;
end;$function$
;
CREATE OR REPLACE FUNCTION gaspos_private.customer_refund(p_document_id uuid, p_amount numeric, p_request uuid)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare d public.gas_documents%rowtype;v_net numeric;v_paid numeric;v_refunded numeric;v_id uuid;
begin
if auth.uid() is null or gaspos_private.current_role() not in ('OWNER','KEUANGAN') then raise exception 'Khusus Owner';end if;
if p_request is null or p_amount is null or p_amount<=0 or p_amount>100000000000 then raise exception 'Jumlah refund tidak valid';end if;
select id into v_id from public.gas_customer_refunds where request_id=p_request;if found then return v_id;end if;
select * into d from public.gas_documents where id=p_document_id for update;
if not found or d.document_type<>'SALE' or d.status<>'APPROVED' then raise exception 'Penjualan belum selesai';end if;
select document_total into v_net from public.gaspos_trade_balances where id=p_document_id;
select coalesce(sum(amount),0) into v_paid from public.gas_payments where document_id=p_document_id;
select coalesce(sum(amount),0) into v_refunded from public.gas_customer_refunds where document_id=p_document_id;
if p_amount>v_paid-v_refunded-v_net then raise exception 'Refund melebihi saldo kredit';end if;
insert into public.gas_customer_refunds(document_id,amount,request_id) values(p_document_id,p_amount,p_request) returning id into v_id;
return v_id;
end;$function$
;
CREATE OR REPLACE FUNCTION gaspos_private.deliver_sale(p_id uuid, p_items jsonb, p_request uuid)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare d public.gas_documents%rowtype;v jsonb;it record;v_full int;v_empty int;v_delivered bigint;v_returned bigint;v_stock bigint;v_complete boolean:=true;v_owed int;
begin
if auth.uid() is null or gaspos_private.current_role()<>'OWNER' then raise exception 'Khusus Owner';end if;
if p_request is null or p_items is null or jsonb_typeof(p_items)<>'array' or jsonb_array_length(p_items) not between 1 and 100 then raise exception 'Pengiriman tidak valid';end if;
perform pg_advisory_xact_lock(948621);
select * into d from public.gas_documents where id=p_id for update;
if not found or d.document_type<>'SALE' or d.status not in ('DRAFT','PARTIAL') then raise exception 'Hanya penjualan DRAFT atau PARTIAL bisa dikirim';end if;
if exists(select 1 from public.gas_stock_movements m join public.gas_document_items i on i.id=m.document_item_id where i.document_id=p_id and m.movement_key like ('DELIVERY-'||p_request::text||'-%')) then return p_id;end if;
for v in select value from jsonb_array_elements(p_items) loop
if coalesce(v->>'quantity_full','') !~ '^[0-9]+$' or coalesce(v->>'quantity_empty','') !~ '^[0-9]+$' then raise exception 'Jumlah tidak valid';end if;
v_full:=(v->>'quantity_full')::int;v_empty:=(v->>'quantity_empty')::int;
if v_full<0 or v_empty<0 or v_full>1000000 or v_empty>1000000 or (v_full=0 and v_empty=0) then raise exception 'Jumlah kirim tidak valid';end if;
select * into it from public.gas_document_items where id=(v->>'item_id')::uuid and document_id=p_id;
if not found then raise exception 'Barang tidak sesuai dokumen';end if;
select coalesce(sum(-delta_full),0),coalesce(sum(delta_empty),0) into v_delivered,v_returned from public.gas_stock_movements where document_item_id=it.id;
if v_delivered+v_full>it.quantity_full or v_returned+v_empty>it.quantity_empty or (it.sale_mode<>'EXCHANGE' and v_empty>0) then raise exception 'Pengiriman melebihi pesanan';end if;
select coalesce(sum(m.delta_full),0) into v_stock from public.gas_stock_movements m join public.gas_document_items i on i.id=m.document_item_id where i.product_id=it.product_id;
if v_stock<v_full then raise exception 'Stok penuh tidak cukup';end if;
insert into public.gas_stock_movements(document_item_id,movement_key,delta_full,delta_empty) values(it.id,'DELIVERY-'||p_request::text||'-'||it.id::text,-v_full,v_empty);
if it.sale_mode<>'NEW_CYLINDER' then
v_owed:=greatest(0,v_delivered+v_full-v_returned-v_empty);
insert into public.gas_customer_empty_obligations(item_id,customer_id,owed_qty) values(it.id,d.partner_id,v_owed) on conflict(item_id) do update set owed_qty=excluded.owed_qty;
end if;
end loop;
for it in select id,quantity_full,quantity_empty from public.gas_document_items where document_id=p_id loop
select coalesce(sum(-delta_full),0),coalesce(sum(delta_empty),0) into v_delivered,v_returned from public.gas_stock_movements where document_item_id=it.id;
if v_delivered<it.quantity_full or v_returned<it.quantity_empty then v_complete:=false;end if;
end loop;
update public.gas_documents set status=case when v_complete then 'APPROVED' else 'PARTIAL' end,approved_by=case when v_complete then auth.uid() else null end where id=p_id;
return p_id;
end;$function$
;
CREATE OR REPLACE FUNCTION gaspos_private.receive_purchase(p_id uuid, p_items jsonb, p_request uuid)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare d public.gas_documents%rowtype;v record;v_item jsonb;v_full integer;v_empty integer;v_seen_full bigint;v_seen_empty bigint;v_total_full bigint;v_total_empty bigint;v_complete boolean:=true;v_entry uuid;v_owed bigint;v_stock bigint;
begin
 if auth.uid() is null or gaspos_private.current_role()<>'OWNER' then raise exception 'Khusus Owner';end if;
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
CREATE OR REPLACE FUNCTION gaspos_private.record_payment(p_document_id uuid, p_amount numeric)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare d public.gas_documents%rowtype;v_due numeric;v_paid numeric;v_id uuid;
begin
 if auth.uid() is null or gaspos_private.current_role() not in ('OWNER','KEUANGAN') then raise exception 'Khusus Owner';end if;
 if p_amount is null or p_amount<=0 or p_amount>100000000000000 then raise exception 'Jumlah bayar tidak valid';end if;
 select * into d from public.gas_documents where id=p_document_id for update;
 if not found or d.document_type not in ('PURCHASE','SALE') or d.status<>'APPROVED' then raise exception 'Dokumen harus berstatus APPROVED';end if;
 select coalesce(sum(f.total),0) into v_due from public.gas_document_items i join public.gas_financial_entries f on f.document_item_id=i.id where i.document_id=p_document_id;
 select coalesce(sum(amount),0) into v_paid from public.gas_payments where document_id=p_document_id;
 if v_due<=0 or v_paid+p_amount>v_due then raise exception 'Pembayaran melebihi sisa tagihan';end if;
 insert into public.gas_payments(document_id,amount) values(p_document_id,p_amount) returning id into v_id;
 return v_id;
end;
$function$
;
CREATE OR REPLACE FUNCTION gaspos_private.record_supplier_refund(p_document_id uuid, p_amount numeric, p_request uuid)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare d public.gas_documents%rowtype;v_gross numeric;v_paid numeric;v_refunded numeric;v_id uuid;
begin
 if auth.uid() is null or gaspos_private.current_role() not in ('OWNER','KEUANGAN') then raise exception 'Khusus Owner';end if;
 if p_request is null or p_amount is null or p_amount<=0 or p_amount>100000000000 then raise exception 'Jumlah refund tidak valid';end if;
 select id into v_id from public.gas_supplier_refunds where request_id=p_request;
 if found then return v_id;end if;
 select * into d from public.gas_documents where id=p_document_id for update;
 if not found or d.document_type<>'PURCHASE' or d.status<>'APPROVED' then raise exception 'Refund harus dari Pembelian disetujui';end if;
 select coalesce(sum(f.total),0)+d.freight_cost+d.other_cost into v_gross from public.gas_document_items i join public.gas_financial_entries f on f.document_item_id=i.id where i.document_id=p_document_id;
 select v_gross-coalesce(sum(r.amount),0) into v_gross from public.gas_purchase_returns r join public.gas_document_items i on i.id=r.purchase_item_id where i.document_id=p_document_id;
 if v_gross is null then v_gross:=0;end if;
 select coalesce(sum(amount),0) into v_paid from public.gas_payments where document_id=p_document_id;
 select coalesce(sum(amount),0) into v_refunded from public.gas_supplier_refunds where document_id=p_document_id;
 if p_amount>v_paid-v_refunded-v_gross then raise exception 'Refund melebihi kelebihan pembayaran';end if;
 insert into public.gas_supplier_refunds(document_id,amount,request_id,created_by) values(p_document_id,p_amount,p_request,auth.uid()) returning id into v_id;
 return v_id;
end;
$function$
;
CREATE OR REPLACE FUNCTION gaspos_private.return_purchase(p_item uuid, p_qty integer, p_reason text, p_request uuid)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare v_item record;v_received bigint;v_returned bigint;v_available bigint;v_price numeric;v_doc uuid;v_movement_item uuid;
begin
 if auth.uid() is null or gaspos_private.current_role()<>'OWNER' then raise exception 'Khusus Owner';end if;
 if p_request is null or p_qty is null or p_qty<=0 or p_qty>1000000 or length(btrim(coalesce(p_reason,'')))<5 then raise exception 'Jumlah atau alasan retur tidak valid';end if;
 perform pg_advisory_xact_lock(948621);
 select return_document_id into v_doc from public.gas_purchase_returns where request_id=p_request;
 if found then return v_doc;end if;
 select i.id,i.product_id,i.document_id,d.partner_id,d.status into v_item from public.gas_document_items i join public.gas_documents d on d.id=i.document_id where i.id=p_item and d.document_type='PURCHASE' and d.status in ('APPROVED','PARTIAL');
 if not found then raise exception 'Barang pembelian belum diterima';end if;
 select coalesce(sum(m.delta_full),0) into v_received from public.gas_stock_movements m where m.document_item_id=p_item;
 select coalesce(sum(quantity),0) into v_returned from public.gas_purchase_returns where purchase_item_id=p_item;
 if v_returned+p_qty>v_received then raise exception 'Retur melebihi jumlah yang diterima';end if;
 select coalesce(sum(m.delta_full),0) into v_available from public.gas_stock_movements m join public.gas_document_items i on i.id=m.document_item_id where i.product_id=v_item.product_id;
 if v_available<p_qty then raise exception 'Stok penuh tidak cukup untuk retur';end if;
 select f.unit_price into v_price from public.gas_financial_entries f where f.document_item_id=p_item;
 if v_price is null then raise exception 'Harga pembelian tidak ditemukan';end if;
 insert into public.gas_documents(document_no,document_type,partner_id,status,created_by,approved_by,notes) values('PR-'||p_request::text,'STOCK_ADJUSTMENT',v_item.partner_id,'APPROVED',auth.uid(),auth.uid(),'Retur Pembelian: '||btrim(p_reason)) returning id into v_doc;
 insert into public.gas_document_items(document_id,product_id,quantity_full,quantity_empty) values(v_doc,v_item.product_id,p_qty,0) returning id into v_movement_item;
 insert into public.gas_stock_movements(document_item_id,movement_key,delta_full,delta_empty) values(v_movement_item,'PR-'||v_movement_item::text,-p_qty,0);
 insert into public.gas_purchase_returns(purchase_item_id,return_document_id,quantity,unit_price,amount,reason,request_id,created_by) values(p_item,v_doc,p_qty,v_price,p_qty*v_price,btrim(p_reason),p_request,auth.uid());
 return v_doc;
end;
$function$
;
CREATE OR REPLACE FUNCTION gaspos_private.return_sale(p_item uuid, p_qty integer, p_reason text, p_request uuid)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare v record;v_delivered bigint;v_returned bigint;v_price numeric;v_doc uuid;v_line uuid;
begin
if auth.uid() is null or gaspos_private.current_role()<>'OWNER' then raise exception 'Khusus Owner';end if;
if p_request is null or p_qty is null or p_qty not between 1 and 1000000 or length(btrim(coalesce(p_reason,'')))<5 then raise exception 'Jumlah atau alasan retur tidak valid';end if;
perform pg_advisory_xact_lock(948621);
select document_id into v_doc from public.gas_sale_returns where request_id=p_request;if found then return v_doc;end if;
select i.id,i.product_id,i.document_id,d.partner_id,d.status into v from public.gas_document_items i join public.gas_documents d on d.id=i.document_id where i.id=p_item and d.document_type='SALE' and d.status in ('APPROVED','PARTIAL');
if not found then raise exception 'Penjualan belum dikirim';end if;
select coalesce(sum(-m.delta_full),0) into v_delivered from public.gas_stock_movements m where m.document_item_id=p_item;
select coalesce(sum(quantity),0) into v_returned from public.gas_sale_returns where sale_item_id=p_item;
if v_returned+p_qty>v_delivered then raise exception 'Retur melebihi yang sudah dikirim';end if;
select unit_price into v_price from public.gas_financial_entries where document_item_id=p_item;
if v_price is null then raise exception 'Harga jual tidak ditemukan';end if;
insert into public.gas_documents(document_no,document_type,partner_id,status,created_by,approved_by,notes) values('SR-'||p_request::text,'STOCK_ADJUSTMENT',v.partner_id,'APPROVED',auth.uid(),auth.uid(),'Retur Penjualan: '||btrim(p_reason)) returning id into v_doc;
insert into public.gas_document_items(document_id,product_id,quantity_full,quantity_empty) values(v_doc,v.product_id,p_qty,0) returning id into v_line;
insert into public.gas_stock_movements(document_item_id,movement_key,delta_full,delta_empty) values(v_line,'SR-'||v_line::text,p_qty,0);
insert into public.gas_sale_returns(sale_item_id,document_id,quantity,unit_price,amount,reason,request_id) values(p_item,v_doc,p_qty,v_price,v_price*p_qty,btrim(p_reason),p_request);
return v_doc;
end;$function$
;
CREATE OR REPLACE FUNCTION gaspos_private.return_sale_v2(p_item uuid, p_qty integer, p_empty integer, p_reason text, p_request uuid)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare v record;v_delivered bigint;v_returned bigint;v_empty_in bigint;v_empty_back bigint;v_empty_stock bigint;v_price numeric;v_doc uuid;v_line uuid;
begin
if auth.uid() is null or gaspos_private.current_role()<>'OWNER' then raise exception 'Khusus Owner';end if;
if p_request is null or p_qty is null or p_qty not between 1 and 1000000 or p_empty is null or p_empty<0 or p_empty>p_qty or length(btrim(coalesce(p_reason,'')))<5 then raise exception 'Jumlah atau alasan retur tidak valid';end if;
perform pg_advisory_xact_lock(948621);
select document_id into v_doc from public.gas_sale_returns where request_id=p_request;if found then return v_doc;end if;
select i.id,i.product_id,i.document_id,d.partner_id,d.status into v from public.gas_document_items i join public.gas_documents d on d.id=i.document_id where i.id=p_item and d.document_type='SALE' and d.status in('APPROVED','PARTIAL');
if not found then raise exception 'Penjualan belum dikirim';end if;
select coalesce(sum(-m.delta_full),0),coalesce(sum(m.delta_empty),0) into v_delivered,v_empty_in from public.gas_stock_movements m where m.document_item_id=p_item;
select coalesce(sum(quantity),0),coalesce(sum(empty_reissued),0) into v_returned,v_empty_back from public.gas_sale_returns where sale_item_id=p_item;
if v_returned+p_qty>v_delivered or v_empty_back+p_empty>v_empty_in then raise exception 'Retur melebihi jumlah pengiriman atau kosong yang diterima';end if;
select coalesce(sum(m.delta_empty),0) into v_empty_stock from public.gas_stock_movements m join public.gas_document_items i on i.id=m.document_item_id where i.product_id=v.product_id;
if v_empty_stock<p_empty then raise exception 'Stok kosong tidak cukup untuk dikembalikan';end if;
select unit_price into v_price from public.gas_financial_entries where document_item_id=p_item;
if v_price is null then raise exception 'Harga jual tidak ditemukan';end if;
insert into public.gas_documents(document_no,document_type,partner_id,status,created_by,approved_by,notes) values('SR-'||p_request::text,'STOCK_ADJUSTMENT',v.partner_id,'APPROVED',auth.uid(),auth.uid(),'Retur Penjualan: '||btrim(p_reason)) returning id into v_doc;
insert into public.gas_document_items(document_id,product_id,quantity_full,quantity_empty) values(v_doc,v.product_id,p_qty,p_empty) returning id into v_line;
insert into public.gas_stock_movements(document_item_id,movement_key,delta_full,delta_empty) values(v_line,'SR-'||v_line::text,p_qty,-p_empty);
insert into public.gas_sale_returns(sale_item_id,document_id,quantity,empty_reissued,unit_price,amount,reason,request_id) values(p_item,v_doc,p_qty,p_empty,v_price,v_price*p_qty,btrim(p_reason),p_request);
return v_doc;
end;$function$
;
CREATE OR REPLACE FUNCTION gaspos_private.return_supplier_empty(p_item uuid, p_quantity integer, p_request uuid, p_notes text)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare v_o record;v_balance bigint;v_returned bigint;v_doc uuid;v_item uuid;v_no text;
begin
 if auth.uid() is null or gaspos_private.current_role()<>'OWNER' then raise exception 'Khusus Owner';end if;
 if p_quantity is null or p_quantity<=0 or p_quantity>1000000 or p_request is null then raise exception 'Jumlah atau kunci transaksi tidak valid';end if;
 perform pg_advisory_xact_lock(948621);
 select document_id into v_doc from public.gas_empty_returns where request_id=p_request;
 if found then return v_doc;end if;
 select o.owed_qty,i.product_id,o.supplier_id into v_o from public.gas_empty_obligations o join public.gas_document_items i on i.id=o.document_item_id where o.document_item_id=p_item for update of o;
 if not found then raise exception 'Kewajiban kosong tidak ditemukan';end if;
 select coalesce(sum(quantity),0) into v_returned from public.gas_empty_returns where obligation_item_id=p_item;
 if v_returned+p_quantity>v_o.owed_qty then raise exception 'Pengembalian melebihi sisa kewajiban';end if;
 select coalesce(sum(m.delta_empty),0) into v_balance from public.gas_stock_movements m join public.gas_document_items i on i.id=m.document_item_id where i.product_id=v_o.product_id;
 if v_balance<p_quantity then raise exception 'Stok kosong tidak cukup';end if;
 v_no:='RET-'||p_request::text;
 insert into public.gas_documents(document_no,document_type,partner_id,status,created_by,approved_by,notes) values(v_no,'EMPTY_RETURN',v_o.supplier_id,'APPROVED',auth.uid(),auth.uid(),coalesce(nullif(btrim(p_notes),''),'Pengembalian kewajiban tabung kosong')) returning id into v_doc;
 insert into public.gas_document_items(document_id,product_id,quantity_full,quantity_empty) values(v_doc,v_o.product_id,0,p_quantity) returning id into v_item;
 insert into public.gas_stock_movements(document_item_id,movement_key,delta_full,delta_empty) values(v_item,'RET-'||v_item::text,0,-p_quantity);
 insert into public.gas_empty_returns(obligation_item_id,quantity,request_id,created_by,document_id) values(p_item,p_quantity,p_request,auth.uid(),v_doc);
 return v_doc;
end;
$function$
;
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
  if v_mode not in('EXCHANGE','REFILL_NO_EXCHANGE','NEW_CYLINDER') or (v_mode in ('NEW_CYLINDER','REFILL_NO_EXCHANGE') and v_empty<>0) or (v_mode<>'NEW_CYLINDER' and v_cyl<>0) or v_qty not between 1 and 1000000 or v_empty not between 0 and 1000000 or v_price<0 or v_cyl<0 or v_price+v_cyl>100000000000 or not exists(select 1 from public.gas_products where id=v_product) then raise exception 'Barang tidak valid';end if;
 end loop;
 delete from public.gas_financial_entries where document_item_id in(select id from public.gas_document_items where document_id=p_id);
 delete from public.gas_document_items where document_id=p_id;
 update public.gas_documents set partner_id=p_partner_id,notes=nullif(btrim(p_notes),''),reference_no=nullif(left(btrim(p_reference),120),''),invoice_date=p_invoice_date,due_date=p_due_date,freight_cost=p_freight,other_cost=p_other where id=p_id;
 for v_item in select value from jsonb_array_elements(p_items) loop
  v_qty:=(v_item->>'quantity_full')::integer;v_empty:=coalesce(v_item->>'quantity_empty','0')::integer;v_price:=(v_item->>'unit_price')::numeric;v_cyl:=coalesce(v_item->>'cylinder_unit_price','0')::numeric;
  insert into public.gas_document_items(document_id,product_id,quantity_full,quantity_empty,purchase_mode,cylinder_unit_price) values(p_id,(v_item->>'product_id')::uuid,v_qty,v_empty,coalesce(v_item->>'purchase_mode','EXCHANGE'),v_cyl) returning id into v_id;
  insert into public.gas_financial_entries(document_item_id,unit_price,total) values(v_id,v_price+v_cyl,(v_price+v_cyl)*v_qty);
 end loop;
 return p_id;
end;
$function$
;
CREATE OR REPLACE FUNCTION gaspos_private.update_sale(p_id uuid, p_partner_id uuid, p_notes text, p_items jsonb, p_invoice_date date, p_due_date date, p_recipient text)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare d public.gas_documents%rowtype;v jsonb;v_id uuid;v_mode text;v_qty int;v_empty int;v_price numeric;v_cyl numeric;
begin
if auth.uid() is null or gaspos_private.current_role()<>'OWNER' then raise exception 'Khusus Owner';end if;
select * into d from public.gas_documents where id=p_id for update;
if not found or d.document_type<>'SALE' or d.status<>'DRAFT' then raise exception 'Hanya Penjualan DRAFT yang dapat diubah';end if;
if not exists(select 1 from public.gas_partners where id=p_partner_id and partner_type='CUSTOMER') then raise exception 'Pelanggan tidak valid';end if;
if p_due_date is not null and p_invoice_date is not null and p_due_date<p_invoice_date then raise exception 'Jatuh tempo salah';end if;
if p_items is null or jsonb_typeof(p_items)<>'array' or jsonb_array_length(p_items) not between 1 and 100 then raise exception 'Minimal satu barang';end if;
if (select count(*) from jsonb_array_elements(p_items))<>(select count(distinct v->>'product_id') from jsonb_array_elements(p_items) as v) then raise exception 'Produk tidak boleh ganda';end if;
for v in select value from jsonb_array_elements(p_items) loop
if coalesce(v->>'quantity_full','') !~ '^[0-9]+$' or coalesce(v->>'quantity_empty','0') !~ '^[0-9]+$' or coalesce(v->>'unit_price','') !~ '^[0-9]+$' or coalesce(v->>'cylinder_unit_price','0') !~ '^[0-9]+$' then raise exception 'Jumlah atau harga tidak valid';end if;
v_mode:=coalesce(v->>'sale_mode','EXCHANGE');v_qty:=(v->>'quantity_full')::int;v_empty:=coalesce(v->>'quantity_empty','0')::int;v_price:=(v->>'unit_price')::numeric;v_cyl:=coalesce(v->>'cylinder_unit_price','0')::numeric;
if v_mode not in ('EXCHANGE','NO_EXCHANGE','NEW_CYLINDER') or (v_mode<>'EXCHANGE' and v_empty<>0) or (v_mode<>'NEW_CYLINDER' and v_cyl<>0) or v_qty not between 1 and 1000000 or v_empty not between 0 and 1000000 or v_price<0 or v_cyl<0 or v_price+v_cyl>100000000000 or not exists(select 1 from public.gas_products where id=(v->>'product_id')::uuid) then raise exception 'Detail barang tidak valid';end if;
end loop;
delete from public.gas_financial_entries where document_item_id in(select id from public.gas_document_items where document_id=p_id);
delete from public.gas_document_items where document_id=p_id;
update public.gas_documents set partner_id=p_partner_id,notes=nullif(btrim(p_notes),''),invoice_date=p_invoice_date,due_date=p_due_date,recipient_name=nullif(left(btrim(p_recipient),200),'') where id=p_id;
for v in select value from jsonb_array_elements(p_items) loop
v_qty:=(v->>'quantity_full')::int;v_empty:=coalesce(v->>'quantity_empty','0')::int;v_price:=(v->>'unit_price')::numeric;v_cyl:=coalesce(v->>'cylinder_unit_price','0')::numeric;
insert into public.gas_document_items(document_id,product_id,quantity_full,quantity_empty,sale_mode,cylinder_unit_price) values(p_id,(v->>'product_id')::uuid,v_qty,v_empty,coalesce(v->>'sale_mode','EXCHANGE'),v_cyl) returning id into v_id;
insert into public.gas_financial_entries(document_item_id,unit_price,total) values(v_id,v_price+v_cyl,v_qty*(v_price+v_cyl));
end loop;
return p_id;
end;$function$
;
CREATE OR REPLACE FUNCTION public.gas_product_auto_code()
 RETURNS trigger
 LANGUAGE plpgsql
 SET search_path TO 'pg_catalog', 'public'
AS $function$ declare candidate text; begin if tg_op='INSERT' then if new.code is not null and btrim(new.code)<>'' then raise exception 'Kode produk dibuat otomatis' using errcode='23514'; end if; loop candidate:='GAS-'||lpad(nextval('public.gas_product_code_seq')::text,3,'0'); exit when not exists(select 1 from public.gas_products where code=candidate); end loop; new.code:=candidate; elsif new.code is distinct from old.code then raise exception 'Kode produk tidak boleh diubah' using errcode='23514'; end if; return new; end $function$
;
CREATE OR REPLACE FUNCTION public.gaspos_set_opening_cost(p_product uuid, p_qty integer, p_cost numeric, p_notes text)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
begin
if auth.uid() is null or gaspos_private.current_role()<>'OWNER' then raise exception 'Hanya Owner dapat mengatur nilai stok awal';end if;
if p_qty is null or p_qty<0 or p_cost is null or p_cost<0 or p_cost>1000000000 then raise exception 'Nilai stok awal tidak valid';end if;
if exists(select 1 from public.gas_inventory_opening_costs where product_id=p_product) then raise exception 'Nilai stok awal sudah ditetapkan. Perubahan harus diaudit terpisah';end if;
insert into public.gas_inventory_opening_costs(product_id,full_qty,unit_cost,notes,created_by) values(p_product,p_qty,p_cost,left(coalesce(p_notes,''),500),auth.uid());
end;$function$
;
CREATE OR REPLACE FUNCTION public.gaspos_submit_logistics(p_direction text, p_partner uuid, p_product uuid, p_full integer, p_empty integer, p_notes text)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare v_id uuid;
begin
if auth.uid() is null or gaspos_private.current_role() not in ('LOGISTIK','OWNER') then raise exception 'Hanya Logistik atau Owner yang dapat input pergerakan barang';end if;
if p_direction not in ('IN','OUT') or p_full is null or p_empty is null or p_full<0 or p_empty<0 or p_full>1000000 or p_empty>1000000 or p_full+p_empty=0 then raise exception 'Jumlah atau jenis mutasi tidak valid';end if;
if not exists(select 1 from public.gas_products where id=p_product) then raise exception 'Produk tidak ditemukan';end if;
if p_partner is not null and not exists(select 1 from public.gas_partners where id=p_partner) then raise exception 'Mitra tidak ditemukan';end if;
insert into public.gas_logistics_requests(direction,partner_id,product_id,full_qty,empty_qty,notes,created_by) values(p_direction,p_partner,p_product,p_full,p_empty,nullif(left(btrim(p_notes),500),''),auth.uid()) returning id into v_id;return v_id;
end;$function$
;
CREATE OR REPLACE FUNCTION public.gaspos_create_trade(p_type text, p_partner_id uuid, p_notes text, p_items jsonb)
 RETURNS uuid
 LANGUAGE plpgsql
 SET search_path TO ''
AS $function$
declare v_id uuid;v_item_id uuid;v_no text;v_partner_type text;v_item jsonb;v_product uuid;v_qty integer;v_empty integer;v_price numeric;v_uid uuid;
begin
 v_uid:=auth.uid();
 if v_uid is null or gaspos_private.current_role()<>'OWNER' then raise exception 'Khusus Owner';end if;
 if p_type not in ('PURCHASE','SALE') then raise exception 'Jenis transaksi tidak valid';end if;
 select partner_type into v_partner_type from public.gas_partners where id=p_partner_id;
 if v_partner_type is distinct from (case when p_type='PURCHASE' then 'SUPPLIER' else 'CUSTOMER' end) then raise exception 'Mitra transaksi tidak sesuai';end if;
 if p_items is null or jsonb_typeof(p_items)<>'array' or jsonb_array_length(p_items)<1 or jsonb_array_length(p_items)>100 then raise exception 'Minimal satu barang diperlukan';end if;
 for v_item in select value from jsonb_array_elements(p_items) loop
  if jsonb_typeof(v_item)<>'object' or coalesce(v_item->>'quantity_full','') !~ '^[0-9]+$' or coalesce(v_item->>'quantity_empty','0') !~ '^[0-9]+$' or coalesce(v_item->>'unit_price','') !~ '^[0-9]+$' then raise exception 'Jumlah atau harga tidak valid';end if;
  v_product:=(v_item->>'product_id')::uuid;v_qty:=(v_item->>'quantity_full')::integer;v_empty:=coalesce(v_item->>'quantity_empty','0')::integer;v_price:=(v_item->>'unit_price')::numeric;
  if v_qty not between 1 and 1000000 or v_empty not between 0 and 1000000 or v_price<0 or v_price>100000000000 or not exists(select 1 from public.gas_products where id=v_product) then raise exception 'Produk jumlah atau harga tidak valid';end if;
 end loop;
 v_no:=(case when p_type='PURCHASE' then 'BEL' else 'JUL' end)||'-'||to_char(clock_timestamp(),'YYYYMMDDHH24MISSMS')||'-'||upper(substr(replace(gen_random_uuid()::text,'-',''),1,5));
 insert into public.gas_documents(document_no,document_type,partner_id,status,created_by,notes) values(v_no,p_type,p_partner_id,'DRAFT',v_uid,nullif(btrim(p_notes),'')) returning id into v_id;
 for v_item in select value from jsonb_array_elements(p_items) loop
  v_qty:=(v_item->>'quantity_full')::integer;v_empty:=coalesce(v_item->>'quantity_empty','0')::integer;v_price:=(v_item->>'unit_price')::numeric;
  insert into public.gas_document_items(document_id,product_id,quantity_full,quantity_empty) values(v_id,(v_item->>'product_id')::uuid,v_qty,v_empty) returning id into v_item_id;
  insert into public.gas_financial_entries(document_item_id,unit_price,total) values(v_item_id,v_price,v_price*v_qty);
 end loop;
 return v_id;
end;
$function$
;
CREATE OR REPLACE FUNCTION public.gaspos_create_sale(p_partner_id uuid, p_notes text, p_items jsonb, p_invoice_date date, p_due_date date, p_recipient text)
 RETURNS uuid
 LANGUAGE plpgsql
 SET search_path TO ''
AS $function$
declare v_id uuid;v_item jsonb;v_mode text;v_empty int;v_cyl numeric;
begin
if auth.uid() is null or gaspos_private.current_role()<>'OWNER' then raise exception 'Khusus Owner';end if;
if p_due_date is not null and p_invoice_date is not null and p_due_date<p_invoice_date then raise exception 'Jatuh tempo sebelum faktur';end if;
if p_items is null or jsonb_typeof(p_items)<>'array' or jsonb_array_length(p_items) not between 1 and 100 then raise exception 'Barang wajib ada';end if;
for v_item in select value from jsonb_array_elements(p_items) loop
v_mode:=coalesce(v_item->>'sale_mode','EXCHANGE');v_empty:=coalesce((v_item->>'quantity_empty')::int,0);v_cyl:=coalesce((v_item->>'cylinder_unit_price')::numeric,0);
if v_mode not in ('EXCHANGE','NO_EXCHANGE','NEW_CYLINDER') or (v_mode<>'EXCHANGE' and v_empty<>0) or v_cyl<0 or v_cyl>100000000000 or (v_mode<>'NEW_CYLINDER' and v_cyl<>0) then raise exception 'Jenis penjualan atau harga tabung salah';end if;
end loop;
v_id:=public.gaspos_create_trade('SALE',p_partner_id,p_notes,p_items);
update public.gas_documents set invoice_date=p_invoice_date,due_date=p_due_date,recipient_name=nullif(left(btrim(p_recipient),200),'') where id=v_id;
for v_item in select value from jsonb_array_elements(p_items) loop
update public.gas_document_items set sale_mode=coalesce(v_item->>'sale_mode','EXCHANGE'),cylinder_unit_price=coalesce((v_item->>'cylinder_unit_price')::numeric,0) where document_id=v_id and product_id=(v_item->>'product_id')::uuid;
update public.gas_financial_entries set unit_price=unit_price+coalesce((v_item->>'cylinder_unit_price')::numeric,0),total=total+coalesce((v_item->>'cylinder_unit_price')::numeric,0)*(v_item->>'quantity_full')::int where document_item_id in(select id from public.gas_document_items where document_id=v_id and product_id=(v_item->>'product_id')::uuid);
end loop;
return v_id;
end;$function$
;
CREATE OR REPLACE FUNCTION public.gaspos_review_logistics(p_id uuid, p_approve boolean, p_reason text)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare req public.gas_logistics_requests%rowtype;v_doc uuid;v_item uuid;v_full bigint;v_empty bigint;
begin
if auth.uid() is null or gaspos_private.current_role()<>'OWNER' then raise exception 'ACC hanya untuk Owner';end if;
perform pg_advisory_xact_lock(948621);
select * into req from public.gas_logistics_requests where id=p_id for update;
if not found or req.status<>'PENDING' then raise exception 'Dokumen sudah diproses atau tidak ditemukan';end if;
if p_approve is null then raise exception 'Keputusan harus diisi';end if;
if not p_approve then
 if length(btrim(coalesce(p_reason,'')))<5 then raise exception 'Alasan penolakan minimal 5 karakter';end if;
 update public.gas_logistics_requests set status='REJECTED',reviewed_by=auth.uid(),reviewed_at=now(),rejection_reason=btrim(p_reason) where id=p_id;
 return null;
end if;
if req.direction='OUT' then
 select coalesce(sum(m.delta_full),0),coalesce(sum(m.delta_empty),0) into v_full,v_empty from public.gas_stock_movements m join public.gas_document_items i on i.id=m.document_item_id where i.product_id=req.product_id;
 if v_full<req.full_qty or v_empty<req.empty_qty then raise exception 'Stok penuh atau kosong tidak cukup';end if;
end if;
insert into public.gas_documents(document_no,document_type,partner_id,status,created_by,approved_by,notes) values('LOG-'||req.id::text,case when req.direction='IN' then 'RECEIPT' else 'DISPATCH' end,req.partner_id,'APPROVED',req.created_by,auth.uid(),req.notes) returning id into v_doc;
insert into public.gas_document_items(document_id,product_id,quantity_full,quantity_empty) values(v_doc,req.product_id,req.full_qty,req.empty_qty) returning id into v_item;
insert into public.gas_stock_movements(document_item_id,movement_key,delta_full,delta_empty) values(v_item,'LOG-'||req.id::text,case when req.direction='IN' then req.full_qty else -req.full_qty end,case when req.direction='IN' then req.empty_qty else -req.empty_qty end);
update public.gas_logistics_requests set status='APPROVED',reviewed_by=auth.uid(),reviewed_at=now(),document_id=v_doc where id=p_id;
return v_doc;
end;$function$
;
CREATE OR REPLACE FUNCTION public.gaspos_add_operating_expense(p_date date, p_category text, p_description text, p_amount numeric)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare v_id uuid;
begin
 if auth.uid() is null or gaspos_private.current_role() not in ('OWNER','KEUANGAN') then raise exception 'Hanya Owner atau Keuangan dapat mencatat biaya';end if;
 if p_date is null or p_category not in ('BBM','TOL_PARKIR','MAKAN','BONGKAR_MUAT','PERAWATAN','LAINNYA') or p_category is null or length(btrim(coalesce(p_description,''))) not between 1 and 300 or p_amount is null or p_amount<=0 or p_amount>100000000000 then raise exception 'Data biaya operasional tidak valid';end if;
 insert into public.gas_operating_expenses(expense_date,category,description,amount,created_by) values(p_date,p_category,btrim(p_description),p_amount,auth.uid()) returning id into v_id;
 return v_id;
end;$function$
;
CREATE OR REPLACE FUNCTION public.gaspos_start_trip(p_request uuid, p_driver uuid, p_plate text)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare r public.gas_logistics_requests%rowtype;v_id uuid;
begin
if gaspos_private.current_role() not in ('OWNER','LOGISTIK') or auth.uid() is null then raise exception 'Akses ditolak';end if;
select * into r from public.gas_logistics_requests where id=p_request for update;
if not found or r.status<>'APPROVED' or r.direction<>'OUT' or r.full_qty<=0 then raise exception 'Surat Jalan keluar belum ACC atau tidak valid';end if;
if not exists(select 1 from public.gas_members where user_id=p_driver and role='SALES_SOPIR' and active) then raise exception 'Pilih akun sopir aktif';end if;
if length(btrim(coalesce(p_plate,'')))<3 then raise exception 'Nomor kendaraan wajib diisi';end if;
insert into public.gas_trips(request_id,driver_user_id,vehicle_plate) values(p_request,p_driver,upper(left(btrim(p_plate),24))) returning id into v_id;
return v_id;
end;$function$
;
CREATE OR REPLACE FUNCTION public.gaspos_record_stop(p_trip uuid, p_customer uuid, p_full integer, p_empty integer, p_notes text)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare t public.gas_trips%rowtype;r public.gas_logistics_requests%rowtype;v_sent int;v_id uuid;
begin
if auth.uid() is null then raise exception 'Login diperlukan';end if;
select * into t from public.gas_trips where id=p_trip for update;
if not found or t.status<>'ON_ROUTE' then raise exception 'Perjalanan sudah selesai atau tidak ditemukan';end if;
if gaspos_private.current_role()<>'OWNER' and not(gaspos_private.current_role()='SALES_SOPIR' and t.driver_user_id=auth.uid()) then raise exception 'Bukan sopir perjalanan ini';end if;
select * into r from public.gas_logistics_requests where id=t.request_id;
if p_full is null or p_full<=0 or p_empty is null or p_empty<0 then raise exception 'Jumlah tidak valid';end if;
if not exists(select 1 from public.gas_partners where id=p_customer and partner_type in ('CUSTOMER','BOTH')) then raise exception 'Pelanggan tidak valid';end if;
select coalesce(sum(full_qty),0)::int into v_sent from public.gas_trip_stops where trip_id=p_trip;
if v_sent+p_full>r.full_qty then raise exception 'Jumlah melebihi muatan sopir';end if;
insert into public.gas_trip_stops(trip_id,customer_id,full_qty,empty_qty,notes,created_by) values(p_trip,p_customer,p_full,p_empty,left(coalesce(p_notes,''),300),auth.uid()) returning id into v_id;
return v_id;
end;$function$
;
CREATE OR REPLACE FUNCTION public.gaspos_confirm_stop(p_stop uuid, p_receiver text)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$ begin raise exception 'Gunakan konfirmasi dengan tanda tangan penerima';end;$function$
;
CREATE OR REPLACE FUNCTION public.gaspos_invoice_trip_stop(p_stop uuid, p_unit_price numeric, p_invoice_date date, p_due_date date)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare s public.gas_trip_stops%rowtype;t public.gas_trips%rowtype;r public.gas_logistics_requests%rowtype;v_doc uuid;v_item uuid;
begin
if auth.uid() is null or gaspos_private.current_role()<>'OWNER' then raise exception 'Hanya Owner membuat invoice';end if;
select * into s from public.gas_trip_stops where id=p_stop for update;
if not found or s.invoice_document_id is not null then raise exception 'Pengiriman sudah ditagihkan atau tidak ditemukan';end if;
select * into t from public.gas_trips where id=s.trip_id;select * into r from public.gas_logistics_requests where id=t.request_id;
if t.status<>'RETURNED' or not s.receiver_confirmed then raise exception 'Pengiriman belum selesai dan dikonfirmasi';end if;
if p_unit_price is null or p_unit_price<0 or p_unit_price>100000000000 or p_invoice_date is null or (p_due_date is not null and p_due_date<p_invoice_date) then raise exception 'Harga/tanggal tidak valid';end if;
insert into public.gas_documents(document_no,document_type,partner_id,status,created_by,approved_by,reference_no,invoice_date,due_date,recipient_name,notes)
values('INV-SJ-'||left(s.id::text,18),'SALE',s.customer_id,'APPROVED',auth.uid(),auth.uid(),'SJ-'||left(r.id::text,12),p_invoice_date,p_due_date,s.receiver_name,'Invoice berdasarkan pengiriman sopir terverifikasi') returning id into v_doc;
insert into public.gas_document_items(document_id,product_id,quantity_full,quantity_empty,sale_mode) values(v_doc,r.product_id,s.full_qty,s.empty_qty,'EXCHANGE') returning id into v_item;
insert into public.gas_financial_entries(document_item_id,unit_price,total) values(v_item,p_unit_price,p_unit_price*s.full_qty);
update public.gas_trip_stops set invoice_document_id=v_doc where id=p_stop;
return v_doc;
end;$function$
;
CREATE OR REPLACE FUNCTION public.gaspos_correct_stop(p_stop uuid, p_customer uuid, p_full integer, p_empty integer, p_reason text)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare s public.gas_trip_stops%rowtype;t public.gas_trips%rowtype;r public.gas_logistics_requests%rowtype;v_other int;v_trip uuid;
begin
if auth.uid() is null or gaspos_private.current_role()<>'OWNER' then raise exception 'Koreksi memerlukan Owner';end if;
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
CREATE OR REPLACE FUNCTION public.gaspos_return_trip(p_trip uuid, p_full integer, p_empty integer)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare t public.gas_trips%rowtype;r public.gas_logistics_requests%rowtype;v_sent int;v_collected int;v_unconfirmed int;v_item uuid;
begin
if auth.uid() is null or gaspos_private.current_role() not in ('OWNER','LOGISTIK') then raise exception 'Hanya Logistik atau Owner';end if;
perform pg_advisory_xact_lock(948621);
select * into t from public.gas_trips where id=p_trip for update;
if not found or t.status<>'ON_ROUTE' then raise exception 'Perjalanan tidak aktif';end if;
select * into r from public.gas_logistics_requests where id=t.request_id;
select coalesce(sum(full_qty),0)::int,coalesce(sum(empty_qty),0)::int,count(*) filter(where not receiver_confirmed)::int into v_sent,v_collected,v_unconfirmed from public.gas_trip_stops where trip_id=p_trip;
if v_unconfirmed>0 then raise exception 'Semua pengiriman harus dikonfirmasi penerima sebelum pulang';end if;
if p_full is null or p_empty is null or p_full<0 or p_empty<0 or p_full<>r.full_qty-v_sent or p_empty<>r.empty_qty+v_collected then raise exception 'Jumlah pulang tidak cocok';end if;
select id into v_item from public.gas_document_items where document_id=r.document_id limit 1;
if v_item is null then raise exception 'Item dokumen Surat Jalan tidak ditemukan';end if;
insert into public.gas_stock_movements(document_item_id,movement_key,delta_full,delta_empty) values(v_item,'TRIP-RETURN-'||p_trip::text,p_full,p_empty);
update public.gas_trips set status='RETURNED',return_full=p_full,return_empty=p_empty,returned_by=auth.uid(),returned_at=now() where id=p_trip;
end;$function$
;
CREATE OR REPLACE FUNCTION public.gaspos_confirm_stop_signed(p_stop uuid, p_receiver text, p_signature jsonb)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare s public.gas_trip_stops%rowtype;t public.gas_trips%rowtype;
begin
if auth.uid() is null then raise exception 'Login diperlukan';end if;
select * into s from public.gas_trip_stops where id=p_stop for update;
if not found then raise exception 'Catatan tidak ditemukan';end if;
select * into t from public.gas_trips where id=s.trip_id;
if gaspos_private.current_role() not in ('OWNER','SALES_SOPIR') or (gaspos_private.current_role()='SALES_SOPIR' and t.driver_user_id is distinct from auth.uid()) then raise exception 'Akses ditolak';end if;
if t.status<>'ON_ROUTE' or s.invoice_document_id is not null or s.receiver_confirmed then raise exception 'Catatan telah terkunci';end if;
if length(btrim(coalesce(p_receiver,'')))<3 then raise exception 'Nama penerima minimal 3 karakter';end if;
if p_signature is null or jsonb_typeof(p_signature)<>'array' or jsonb_array_length(p_signature)<2 or length(p_signature::text)>12000 then raise exception 'Tanda tangan penerima wajib diisi';end if;
update public.gas_trip_stops set receiver_name=left(btrim(p_receiver),120),receiver_signature=p_signature,receiver_confirmed=true,confirmed_at=now() where id=p_stop;
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
if not found or t.status<>'RETURNED' then raise exception 'Perjalanan belum direkonsiliasi';end if;
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
CREATE OR REPLACE FUNCTION public.gaspos_clear_stale_signature_on_correction()
 RETURNS trigger
 LANGUAGE plpgsql
 SET search_path TO ''
AS $function$
begin
if old.customer_id is distinct from new.customer_id or old.full_qty is distinct from new.full_qty or old.empty_qty is distinct from new.empty_qty then
 new.receiver_signature:=null;new.receiver_confirmed:=false;new.receiver_name:=null;new.confirmed_at:=null;
end if;
return new;
end;$function$
;
CREATE VIEW public.gaspos_stock_balances AS  SELECT i.product_id,
    sum(m.delta_full) AS full_balance,
    sum(m.delta_empty) AS empty_balance
   FROM gas_document_items i
     JOIN gas_stock_movements m ON m.document_item_id = i.id
  GROUP BY i.product_id;;
CREATE VIEW public.gaspos_trade_balances AS  SELECT id,
    document_no,
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
    due_date
   FROM gas_documents d
  WHERE (document_type = ANY (ARRAY['PURCHASE'::text, 'SALE'::text])) AND gaspos_private."current_role"() = 'OWNER'::text;;
CREATE VIEW public.gaspos_purchase_receipt_progress AS  SELECT i.document_id,
    i.id AS item_id,
    i.product_id,
    i.quantity_full AS ordered_full,
    i.quantity_empty AS ordered_empty,
    COALESCE(( SELECT sum(m.delta_full) AS sum
           FROM gas_stock_movements m
          WHERE m.document_item_id = i.id), 0::bigint)::integer AS received_full,
    COALESCE(( SELECT sum(- m.delta_empty) AS sum
           FROM gas_stock_movements m
          WHERE m.document_item_id = i.id), 0::bigint)::integer AS sent_empty
   FROM gas_document_items i
     JOIN gas_documents d ON d.id = i.document_id
  WHERE d.document_type = 'PURCHASE'::text;;
CREATE VIEW public.gaspos_supplier_empty_balances AS  SELECT o.document_item_id,
    o.supplier_id,
    i.product_id,
    o.owed_qty,
    COALESCE(( SELECT sum(r.quantity) AS sum
           FROM gas_empty_returns r
          WHERE r.obligation_item_id = o.document_item_id), 0::bigint) AS returned_qty,
    GREATEST(0::bigint, o.owed_qty - COALESCE(( SELECT sum(r.quantity) AS sum
           FROM gas_empty_returns r
          WHERE r.obligation_item_id = o.document_item_id), 0::bigint) - COALESCE(( SELECT sum(p.quantity) AS sum
           FROM gas_purchase_returns p
          WHERE p.purchase_item_id = o.document_item_id), 0::bigint)) AS outstanding,
    COALESCE(( SELECT sum(p.quantity) AS sum
           FROM gas_purchase_returns p
          WHERE p.purchase_item_id = o.document_item_id), 0::bigint) AS purchase_return_qty,
    i.document_id AS purchase_document_id
   FROM gas_empty_obligations o
     JOIN gas_document_items i ON i.id = o.document_item_id;;
CREATE VIEW public.gaspos_customer_empty_balances AS  SELECT o.item_id,
    o.customer_id,
    i.product_id,
    i.document_id,
    o.owed_qty,
    COALESCE(( SELECT sum(r.quantity) AS sum
           FROM gas_customer_empty_returns r
          WHERE r.obligation_item_id = o.item_id), 0::bigint) AS returned_qty,
    GREATEST(0::bigint, o.owed_qty - COALESCE(( SELECT sum(r.quantity) AS sum
           FROM gas_customer_empty_returns r
          WHERE r.obligation_item_id = o.item_id), 0::bigint) - COALESCE(( SELECT sum(r.quantity - r.empty_reissued) AS sum
           FROM gas_sale_returns r
          WHERE r.sale_item_id = o.item_id), 0::bigint)) AS outstanding
   FROM gas_customer_empty_obligations o
     JOIN gas_document_items i ON i.id = o.item_id;;
CREATE VIEW public.gaspos_supplier_empty_debts AS  SELECT supplier_id,
    sum(outstanding)::bigint AS owed_qty
   FROM gaspos_supplier_empty_balances
  GROUP BY supplier_id;;
CREATE VIEW public.gaspos_sales_delivery_progress AS  SELECT i.document_id,
    i.id AS item_id,
    i.product_id,
    i.quantity_full AS ordered_full,
    i.quantity_empty AS ordered_empty,
    COALESCE(( SELECT sum(- m.delta_full) AS sum
           FROM gas_stock_movements m
          WHERE m.document_item_id = i.id), 0::bigint)::integer AS delivered_full,
    COALESCE(( SELECT sum(m.delta_empty) AS sum
           FROM gas_stock_movements m
          WHERE m.document_item_id = i.id), 0::bigint)::integer AS received_empty
   FROM gas_document_items i
     JOIN gas_documents d ON d.id = i.document_id
  WHERE d.document_type = 'SALE'::text;;
CREATE VIEW public.gaspos_logistics_stock_history AS  SELECT m.id,
    m.created_at,
    d.document_no,
    i.product_id,
    m.delta_full,
    m.delta_empty
   FROM gas_stock_movements m
     JOIN gas_document_items i ON i.id = m.document_item_id
     JOIN gas_documents d ON d.id = i.document_id;;
CREATE OR REPLACE FUNCTION public.gaspos_record_payment(p_document_id uuid, p_amount numeric)
 RETURNS uuid
 LANGUAGE sql
 SET search_path TO ''
AS $function$ select gaspos_private.record_payment(p_document_id,p_amount); $function$
;
CREATE OR REPLACE FUNCTION public.gaspos_create_purchase(p_partner_id uuid, p_notes text, p_items jsonb, p_reference text, p_invoice_date date, p_due_date date, p_freight numeric, p_other numeric)
 RETURNS uuid
 LANGUAGE sql
 SET search_path TO ''
AS $function$ select gaspos_private.create_purchase(p_partner_id,p_notes,p_items,p_reference,p_invoice_date,p_due_date,p_freight,p_other); $function$
;
CREATE OR REPLACE FUNCTION public.gaspos_receive_purchase(p_id uuid, p_items jsonb, p_request uuid)
 RETURNS uuid
 LANGUAGE sql
 SET search_path TO ''
AS $function$ select gaspos_private.receive_purchase(p_id,p_items,p_request); $function$
;
CREATE OR REPLACE FUNCTION public.gaspos_approve_trade(p_id uuid)
 RETURNS void
 LANGUAGE sql
 SET search_path TO ''
AS $function$ select gaspos_private.approve_trade(p_id); $function$
;
CREATE OR REPLACE FUNCTION public.gaspos_adjust_stock(p_product uuid, p_delta_full integer, p_delta_empty integer, p_notes text, p_request_id uuid)
 RETURNS uuid
 LANGUAGE sql
 SET search_path TO ''
AS $function$ select gaspos_private.adjust_stock(p_product,p_delta_full,p_delta_empty,p_notes,p_request_id); $function$
;
CREATE OR REPLACE FUNCTION public.gaspos_cancel_trade(p_id uuid)
 RETURNS void
 LANGUAGE sql
 SET search_path TO ''
AS $function$ select gaspos_private.cancel_trade(p_id); $function$
;
CREATE OR REPLACE FUNCTION public.gaspos_return_supplier_empty(p_item uuid, p_quantity integer, p_request uuid, p_notes text)
 RETURNS uuid
 LANGUAGE sql
 SET search_path TO ''
AS $function$ select gaspos_private.return_supplier_empty(p_item,p_quantity,p_request,p_notes); $function$
;
CREATE OR REPLACE FUNCTION public.gaspos_return_purchase(p_item uuid, p_qty integer, p_reason text, p_request uuid)
 RETURNS uuid
 LANGUAGE sql
 SET search_path TO ''
AS $function$ select gaspos_private.return_purchase(p_item,p_qty,p_reason,p_request); $function$
;
CREATE OR REPLACE FUNCTION public.gaspos_update_purchase(p_id uuid, p_partner_id uuid, p_notes text, p_items jsonb, p_reference text, p_invoice_date date, p_due_date date, p_freight numeric, p_other numeric)
 RETURNS uuid
 LANGUAGE sql
 SET search_path TO ''
AS $function$ select gaspos_private.update_purchase(p_id,p_partner_id,p_notes,p_items,p_reference,p_invoice_date,p_due_date,p_freight,p_other); $function$
;
CREATE OR REPLACE FUNCTION public.gaspos_record_supplier_refund(p_document_id uuid, p_amount numeric, p_request uuid)
 RETURNS uuid
 LANGUAGE sql
 SET search_path TO ''
AS $function$ select gaspos_private.record_supplier_refund(p_document_id,p_amount,p_request); $function$
;
CREATE OR REPLACE FUNCTION public.gaspos_return_sale_v2(p_item uuid, p_qty integer, p_empty integer, p_reason text, p_request uuid)
 RETURNS uuid
 LANGUAGE sql
 SET search_path TO ''
AS $function$ select gaspos_private.return_sale_v2(p_item,p_qty,p_empty,p_reason,p_request);$function$
;
CREATE OR REPLACE FUNCTION public.gaspos_deliver_sale(p_id uuid, p_items jsonb, p_request uuid)
 RETURNS uuid
 LANGUAGE sql
 SET search_path TO ''
AS $function$ select gaspos_private.deliver_sale(p_id,p_items,p_request);$function$
;
CREATE OR REPLACE FUNCTION public.gaspos_customer_empty_return(p_item uuid, p_qty integer, p_request uuid)
 RETURNS uuid
 LANGUAGE sql
 SET search_path TO ''
AS $function$ select gaspos_private.customer_empty_return(p_item,p_qty,p_request);$function$
;
CREATE OR REPLACE FUNCTION public.gaspos_return_sale(p_item uuid, p_qty integer, p_reason text, p_request uuid)
 RETURNS uuid
 LANGUAGE sql
 SET search_path TO ''
AS $function$ select gaspos_private.return_sale(p_item,p_qty,p_reason,p_request);$function$
;
CREATE OR REPLACE FUNCTION public.gaspos_update_sale(p_id uuid, p_partner_id uuid, p_notes text, p_items jsonb, p_invoice_date date, p_due_date date, p_recipient text)
 RETURNS uuid
 LANGUAGE sql
 SET search_path TO ''
AS $function$ select gaspos_private.update_sale(p_id,p_partner_id,p_notes,p_items,p_invoice_date,p_due_date,p_recipient);$function$
;
CREATE OR REPLACE FUNCTION public.gaspos_customer_refund(p_document_id uuid, p_amount numeric, p_request uuid)
 RETURNS uuid
 LANGUAGE sql
 SET search_path TO ''
AS $function$ select gaspos_private.customer_refund(p_document_id,p_amount,p_request);$function$
;
CREATE OR REPLACE FUNCTION public.gaspos_logistics_history()
 RETURNS TABLE(document_no text, product_id uuid, delta_full integer, delta_empty integer, created_at timestamp with time zone)
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
select d.document_no,i.product_id,m.delta_full,m.delta_empty,m.created_at
from public.gas_stock_movements m join public.gas_document_items i on i.id=m.document_item_id join public.gas_documents d on d.id=i.document_id
where gaspos_private.current_role() in ('OWNER','LOGISTIK') order by m.created_at desc limit 500
$function$
;
CREATE OR REPLACE FUNCTION public.gaspos_list_drivers()
 RETURNS TABLE(user_id uuid, username text)
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
 select m.user_id,coalesce(u.raw_user_meta_data->>'username',split_part(u.email,'@',1)) from public.gas_members m join auth.users u on u.id=m.user_id where m.role='SALES_SOPIR' and m.active and gaspos_private.current_role() in ('OWNER','LOGISTIK') order by 2
$function$
;
CREATE OR REPLACE FUNCTION public.gaspos_logistics_balances()
 RETURNS TABLE(product_id uuid, full_balance bigint, empty_balance bigint)
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
select i.product_id,coalesce(sum(m.delta_full),0)::bigint,coalesce(sum(m.delta_empty),0)::bigint from public.gas_stock_movements m join public.gas_document_items i on i.id=m.document_item_id where gaspos_private.current_role() in ('OWNER','LOGISTIK') group by i.product_id
$function$
;
CREATE OR REPLACE FUNCTION public.gaspos_trip_empty_balances()
 RETURNS TABLE(customer_id uuid, product_id uuid, owed_qty bigint)
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
select s.customer_id,r.product_id,sum(s.full_qty-s.empty_qty)::bigint from public.gas_trip_stops s join public.gas_trips t on t.id=s.trip_id join public.gas_logistics_requests r on r.id=t.request_id where t.status='RETURNED' and s.receiver_confirmed and gaspos_private.current_role() in ('OWNER','LOGISTIK') group by s.customer_id,r.product_id
$function$
;
CREATE OR REPLACE FUNCTION public.gaspos_customer_empty_all_balances()
 RETURNS TABLE(customer_id uuid, product_id uuid, owed_qty bigint)
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
with legacy as (
 select o.customer_id,i.product_id,sum(o.owed_qty-coalesce(ret.returned,0))::bigint qty
 from public.gas_customer_empty_obligations o
 join public.gas_document_items i on i.id=o.item_id
 left join (select obligation_item_id,sum(quantity) returned from public.gas_customer_empty_returns group by obligation_item_id) ret on ret.obligation_item_id=o.item_id
 group by o.customer_id,i.product_id
), trips as (
 select s.customer_id,r.product_id,sum(s.full_qty-s.empty_qty)::bigint qty
 from public.gas_trip_stops s
 join public.gas_trips t on t.id=s.trip_id
 join public.gas_logistics_requests r on r.id=t.request_id
 where t.status='RETURNED' and s.receiver_confirmed
 group by s.customer_id,r.product_id
)
select x.customer_id,x.product_id,sum(x.qty)::bigint as owed_qty
from (select * from legacy union all select * from trips) x
where gaspos_private.current_role()='OWNER'
group by x.customer_id,x.product_id
$function$
;
CREATE OR REPLACE FUNCTION public.gaspos_profit_loss_summary()
 RETURNS TABLE(revenue numeric, hpp numeric, gross_profit numeric, operating_expenses numeric, net_profit numeric, unpriced_sold_qty bigint, method text)
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
with bought as (
 select i.product_id,sum(i.quantity_full)::numeric qty,sum(f.total)::numeric cost
 from public.gas_documents d join public.gas_document_items i on i.document_id=d.id join public.gas_financial_entries f on f.document_item_id=i.id
 where d.document_type='PURCHASE' and d.status='APPROVED' group by i.product_id
), buyreturns as (
 select i.product_id,sum(r.quantity)::numeric qty,sum(r.amount)::numeric cost
 from public.gas_purchase_returns r join public.gas_document_items i on i.id=r.purchase_item_id group by i.product_id
), opening as(select product_id,full_qty::numeric qty,full_qty*unit_cost cost from public.gas_inventory_opening_costs),
costbase as (
 select product_id,sum(qty) qty,sum(cost) cost from (
 select product_id,qty,cost from bought union all select product_id,-qty,-cost from buyreturns union all select product_id,qty,cost from opening
 ) x group by product_id
), sold as (
 select i.product_id,sum(i.quantity_full)::numeric qty,sum(f.total)::numeric revenue
 from public.gas_documents d join public.gas_document_items i on i.document_id=d.id join public.gas_financial_entries f on f.document_item_id=i.id
 where d.document_type='SALE' and d.status='APPROVED' group by i.product_id
), returned as(
 select i.product_id,sum(r.quantity)::numeric qty,sum(r.amount)::numeric revenue
 from public.gas_sale_returns r join public.gas_document_items i on i.id=r.sale_item_id group by i.product_id
), net_sales as(
 select product_id,sum(qty) qty,sum(revenue) revenue from (
 select product_id,qty,revenue from sold union all select product_id,-qty,-revenue from returned
 ) x group by product_id
), vals as (
 select coalesce(sum(s.revenue),0)::numeric sales,
 coalesce(sum(case when c.qty>0 then s.qty*c.cost/c.qty else 0 end),0)::numeric cost,
 coalesce(sum(case when (c.qty is null or c.qty<=0) and s.qty>0 then s.qty else 0 end),0)::bigint missing
 from net_sales s left join costbase c using(product_id)
), ops as(select coalesce(sum(amount),0)::numeric total from public.gas_operating_expenses)
select round(v.sales,2),case when v.missing=0 then round(v.cost,2) end,
case when v.missing=0 then round(v.sales-v.cost,2) end,ops.total,
case when v.missing=0 then round(v.sales-v.cost-ops.total,2) end,v.missing,
'Estimasi HPP rata-rata tertimbang keseluruhan: pembelian dikurangi retur pembelian plus nilai stok awal; penjualan dikurangi retur penjualan. Belum menggunakan HPP FIFO/per tanggal, biaya angkut persediaan, atau penyesuaian periode'::text
from vals v cross join ops where gaspos_private.current_role() in ('OWNER','KEUANGAN')
$function$
;

