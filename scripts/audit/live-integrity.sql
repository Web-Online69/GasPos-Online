-- GASPOS read-only production integrity checks. Expected affected_rows = 0 for every check.
-- Never writes production transactions or stock.
with purchase_progress as (
  select d.id,d.status,
   bool_and(
    i.quantity_full = coalesce((select sum(m.delta_full) from public.gas_stock_movements m where m.document_item_id=i.id),0)
    and i.quantity_empty = coalesce((select sum(case when i.purchase_mode='EMPTY_ONLY' then m.delta_empty else -m.delta_empty end) from public.gas_stock_movements m where m.document_item_id=i.id),0)
   ) complete
  from public.gas_documents d join public.gas_document_items i on i.document_id=d.id
  where d.document_type='PURCHASE' group by d.id
),
stock_history as (
 select i.product_id,m.id,m.created_at,
  sum(m.delta_full) over(partition by i.product_id order by m.created_at,m.id) full_running,
  sum(m.delta_empty) over(partition by i.product_id order by m.created_at,m.id) empty_running
 from public.gas_stock_movements m join public.gas_document_items i on i.id=m.document_item_id
),
shipment_quantities as (
 select s.trip_id,sum(s.full_qty) shipped,r.full_qty loaded
 from public.gas_trip_stops s join public.gas_trips t on t.id=s.trip_id
 join public.gas_logistics_requests r on r.id=t.request_id
 group by s.trip_id,r.full_qty
),
checks as (
 select 'purchase_status_mismatch' check_name,count(*)::bigint affected_rows
 from purchase_progress where (status='APPROVED') is distinct from complete
 union all select 'stock_running_negative',count(*) from stock_history where full_running<0 or empty_running<0
 union all select 'trip_over_delivered',count(*) from shipment_quantities where shipped>loaded
 union all select 'duplicate_movement_keys',count(*) from (
  select movement_key from public.gas_stock_movements group by movement_key having count(*)>1
 ) bad
 union all select 'invoice_missing_finance',count(*) from public.gas_documents d
 where d.document_type='SALE' and d.status='APPROVED'
 and not exists (
  select 1 from public.gas_document_items i join public.gas_financial_entries f on f.document_item_id=i.id
  where i.document_id=d.id
 )
 union all select 'orphan_invoice_stop',count(*) from public.gas_trip_stops s
 left join public.gas_documents d on d.id=s.invoice_document_id
 where s.invoice_document_id is not null and (d.id is null or d.document_type<>'SALE')
 union all select 'receipt_missing_stock_movement',count(*) from public.gas_logistics_requests r
 where r.direction='IN' and r.status='APPROVED' and r.purchase_document_id is not null
 and not exists(
  select 1 from public.gas_stock_movements m join public.gas_document_items i on i.id=m.document_item_id
  where i.document_id=r.purchase_document_id and m.movement_key like 'RECEIPT-'||r.id::text||'-%'
 )
 union all select 'empty_only_wrong_stock_direction',count(*) from public.gas_document_items i
 join public.gas_stock_movements m on m.document_item_id=i.id
 where i.purchase_mode='EMPTY_ONLY' and m.movement_key like 'RECEIPT-%'
 and (m.delta_full<>0 or m.delta_empty<=0)
 union all select 'receipt_amount_exceeds_purchase',count(*) from (
  select i.id from public.gas_document_items i join public.gas_documents d on d.id=i.document_id
  where d.document_type='PURCHASE' and (
   coalesce((select sum(m.delta_full) from public.gas_stock_movements m where m.document_item_id=i.id),0)>i.quantity_full
   or coalesce((select sum(case when i.purchase_mode='EMPTY_ONLY' then m.delta_empty else -m.delta_empty end) from public.gas_stock_movements m where m.document_item_id=i.id),0)>i.quantity_empty
  )
 ) x
)
select check_name,affected_rows,case when affected_rows=0 then 'PASS' else 'REVIEW' end status
from checks order by check_name;
