-- Trip invoices describe physical deliveries already posted through the SJ.
-- Use verified trip provenance OR direct SALE stock movements, never both.
CREATE OR REPLACE VIEW public.gaspos_sales_delivery_progress WITH (security_invoker=true) AS
SELECT i.document_id,i.id AS item_id,i.product_id,
 i.quantity_full AS ordered_full,i.quantity_empty AS ordered_empty,
 (CASE WHEN coalesce(trip.stops,0)>0 THEN
   CASE WHEN trip.valid AND trip.full_qty=i.quantity_full AND trip.empty_qty=i.quantity_empty
      AND (SELECT count(*) FROM public.gas_document_items same_doc WHERE same_doc.document_id=i.document_id)=1
     THEN trip.full_qty ELSE 0 END
  ELSE coalesce(m.delivered_full,0) END)::integer AS delivered_full,
 (CASE WHEN coalesce(trip.stops,0)>0 THEN
   CASE WHEN trip.valid AND trip.full_qty=i.quantity_full AND trip.empty_qty=i.quantity_empty
      AND (SELECT count(*) FROM public.gas_document_items same_doc WHERE same_doc.document_id=i.document_id)=1
     THEN trip.empty_qty ELSE 0 END
  ELSE coalesce(m.received_empty,0) END)::integer AS received_empty
FROM public.gas_document_items i JOIN public.gas_documents d ON d.id=i.document_id
LEFT JOIN LATERAL (
 SELECT count(*) stops,
  coalesce(bool_and(t.status='RETURNED' AND s.receiver_confirmed AND s.customer_id=d.partner_id AND r.product_id=i.product_id),false) valid,
  sum(s.full_qty) full_qty,sum(s.empty_qty) empty_qty
 FROM public.gas_trip_stops s JOIN public.gas_trips t ON t.id=s.trip_id
 JOIN public.gas_logistics_requests r ON r.id=t.request_id
 WHERE s.invoice_document_id=i.document_id
) trip ON true
LEFT JOIN LATERAL (
 SELECT sum(-delta_full) delivered_full,sum(delta_empty) received_empty
 FROM public.gas_stock_movements WHERE document_item_id=i.id
) m ON true
WHERE d.document_type='SALE';

CREATE OR REPLACE FUNCTION gaspos_private.return_sale_v2(p_item uuid,p_qty integer,p_empty integer,p_reason text,p_request uuid)
RETURNS uuid LANGUAGE plpgsql SECURITY DEFINER SET search_path TO '' AS $$
declare v record;v_delivered bigint;v_returned bigint;v_empty_in bigint;v_empty_back bigint;v_empty_stock bigint;v_price numeric;v_doc uuid;v_line uuid;
begin
 if auth.uid() is null or gaspos_private.current_role()<>'OWNER' then raise exception 'Khusus Owner';end if;
 if p_request is null or p_qty is null or p_qty not between 1 and 1000000 or p_empty is null or p_empty<0 or p_empty>p_qty or length(btrim(coalesce(p_reason,'')))<5 then raise exception 'Jumlah atau alasan retur tidak valid';end if;
 perform pg_advisory_xact_lock(948621);
 select document_id into v_doc from public.gas_sale_returns where request_id=p_request;if found then return v_doc;end if;
 select i.id,i.product_id,i.document_id,d.partner_id,d.status into v from public.gas_document_items i join public.gas_documents d on d.id=i.document_id where i.id=p_item and d.document_type='SALE' and d.status in('APPROVED','PARTIAL');
 if not found then raise exception 'Penjualan belum dikirim';end if;
 select delivered_full,received_empty into v_delivered,v_empty_in from public.gaspos_sales_delivery_progress where item_id=p_item;
 select coalesce(sum(quantity),0),coalesce(sum(empty_reissued),0) into v_returned,v_empty_back from public.gas_sale_returns where sale_item_id=p_item;
 if v_delivered is null or v_empty_in is null or v_returned+p_qty>v_delivered or v_empty_back+p_empty>v_empty_in then raise exception 'Retur melebihi jumlah pengiriman atau kosong yang diterima';end if;
 select coalesce(sum(m.delta_empty),0) into v_empty_stock from public.gas_stock_movements m join public.gas_document_items i on i.id=m.document_item_id where i.product_id=v.product_id;
 if v_empty_stock<p_empty then raise exception 'Stok kosong tidak cukup untuk dikembalikan';end if;
 select unit_price into v_price from public.gas_financial_entries where document_item_id=p_item;
 if v_price is null then raise exception 'Harga jual tidak ditemukan';end if;
 insert into public.gas_documents(document_no,document_type,partner_id,status,created_by,approved_by,notes) values('SR-'||p_request::text,'STOCK_ADJUSTMENT',v.partner_id,'APPROVED',auth.uid(),auth.uid(),'Retur Penjualan: '||btrim(p_reason)) returning id into v_doc;
 insert into public.gas_document_items(document_id,product_id,quantity_full,quantity_empty) values(v_doc,v.product_id,p_qty,p_empty) returning id into v_line;
 insert into public.gas_stock_movements(document_item_id,movement_key,delta_full,delta_empty) values(v_line,'SR-'||v_line::text,p_qty,-p_empty);
 insert into public.gas_sale_returns(sale_item_id,document_id,quantity,empty_reissued,unit_price,amount,reason,request_id) values(p_item,v_doc,p_qty,p_empty,v_price,v_price*p_qty,btrim(p_reason),p_request);
 return v_doc;
end;
$$;
CREATE OR REPLACE FUNCTION gaspos_private.return_sale(p_item uuid,p_qty integer,p_reason text,p_request uuid)
RETURNS uuid LANGUAGE sql SECURITY DEFINER SET search_path TO '' AS $$
 SELECT gaspos_private.return_sale_v2(p_item,p_qty,0,p_reason,p_request);
$$;

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
 WHERE t.status='RETURNED' AND s.receiver_confirmed
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
REVOKE ALL ON FUNCTION gaspos_private.return_sale_v2(uuid,integer,integer,text,uuid) FROM PUBLIC,anon;
REVOKE ALL ON FUNCTION gaspos_private.return_sale(uuid,integer,text,uuid) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION gaspos_private.return_sale_v2(uuid,integer,integer,text,uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION gaspos_private.return_sale(uuid,integer,text,uuid) TO authenticated;
REVOKE ALL ON FUNCTION public.gaspos_customer_empty_all_balances() FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.gaspos_customer_empty_all_balances() TO authenticated;
