-- Preserve the existing role guard and result shape; remove the silent 500-row cutoff.
create or replace function public.gaspos_logistics_history()
returns table(document_no text, product_id uuid, delta_full integer, delta_empty integer, created_at timestamptz)
language sql stable security definer set search_path = ''
as $$
select d.document_no,i.product_id,m.delta_full,m.delta_empty,m.created_at
from public.gas_stock_movements m
join public.gas_document_items i on i.id=m.document_item_id
join public.gas_documents d on d.id=i.document_id
where gaspos_private.current_role() in ('OWNER','LOGISTIK')
order by m.created_at desc,m.id;
$$;
