CREATE OR REPLACE VIEW public.gaspos_trade_balances AS  SELECT id,
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
  WHERE (document_type = ANY (ARRAY['PURCHASE'::text, 'SALE'::text])) AND gaspos_private."current_role"() IN ('OWNER'::text,'KEUANGAN'::text);
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
 select document_total,paid_total into v_due,v_paid from public.gaspos_trade_balances where id=p_document_id;
 if v_due is null or v_paid is null then raise exception 'Saldo dokumen tidak tersedia';end if;
 if v_due<=0 or v_paid+p_amount>v_due then raise exception 'Pembayaran melebihi sisa tagihan';end if;
 insert into public.gas_payments(document_id,amount) values(p_document_id,p_amount) returning id into v_id;
 return v_id;
end;
$function$
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
if v_net is null then raise exception 'Saldo tagihan tidak tersedia';end if;
select coalesce(sum(amount),0) into v_paid from public.gas_payments where document_id=p_document_id;
select coalesce(sum(amount),0) into v_refunded from public.gas_customer_refunds where document_id=p_document_id;
if p_amount>v_paid-v_refunded-v_net then raise exception 'Refund melebihi saldo kredit';end if;
insert into public.gas_customer_refunds(document_id,amount,request_id) values(p_document_id,p_amount,p_request) returning id into v_id;
return v_id;
end;$function$
;
