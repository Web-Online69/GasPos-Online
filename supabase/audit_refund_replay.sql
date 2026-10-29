-- Refund retries must acknowledge only the original document and amount.
CREATE OR REPLACE FUNCTION gaspos_private.customer_refund(p_document_id uuid, p_amount numeric, p_request uuid)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare d public.gas_documents%rowtype;v_net numeric;v_paid numeric;v_refunded numeric;v_id uuid;
begin
if auth.uid() is null or gaspos_private.current_role() not in ('OWNER','KEUANGAN') then raise exception 'Hanya Owner atau Keuangan dapat mencatat refund';end if;
if p_request is null or p_amount is null or p_amount<=0 or p_amount>100000000000 then raise exception 'Jumlah refund tidak valid';end if;
perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(p_request::text,0));
 select id into v_id from public.gas_customer_refunds where request_id=p_request;
 if found then
  if not exists(select 1 from public.gas_customer_refunds where id=v_id and document_id=p_document_id and amount=p_amount) then
   raise exception 'ID permintaan refund sudah digunakan untuk dokumen atau nominal berbeda';
  end if;
  return v_id;
 end if;
select * into d from public.gas_documents where id=p_document_id for update;
if not found or d.document_type<>'SALE' or d.status<>'APPROVED' then raise exception 'Penjualan belum selesai';end if;
select document_total into v_net from public.gaspos_trade_balances where id=p_document_id;
if v_net is null then raise exception 'Saldo tagihan tidak tersedia';end if;
select coalesce(sum(amount),0) into v_paid from public.gas_payments where document_id=p_document_id;
select coalesce(sum(amount),0) into v_refunded from public.gas_customer_refunds where document_id=p_document_id;
if p_amount>v_paid-v_refunded-v_net then raise exception 'Refund melebihi saldo kredit';end if;
insert into public.gas_customer_refunds(document_id,amount,request_id) values(p_document_id,p_amount,p_request) returning id into v_id;
return v_id;
end;$function$
;

CREATE OR REPLACE FUNCTION gaspos_private.record_supplier_refund(p_document_id uuid, p_amount numeric, p_request uuid)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare d public.gas_documents%rowtype;v_gross numeric;v_paid numeric;v_refunded numeric;v_id uuid;
begin
 if auth.uid() is null or gaspos_private.current_role() not in ('OWNER','KEUANGAN') then raise exception 'Hanya Owner atau Keuangan dapat mencatat refund';end if;
 if p_request is null or p_amount is null or p_amount<=0 or p_amount>100000000000 then raise exception 'Jumlah refund tidak valid';end if;
 perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(p_request::text,0));
 select id into v_id from public.gas_supplier_refunds where request_id=p_request;
 if found then
  if not exists(select 1 from public.gas_supplier_refunds where id=v_id and document_id=p_document_id and amount=p_amount) then
   raise exception 'ID permintaan refund sudah digunakan untuk dokumen atau nominal berbeda';
  end if;
  return v_id;
 end if;
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
