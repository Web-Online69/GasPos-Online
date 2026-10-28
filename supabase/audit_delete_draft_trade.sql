-- Only OWNER can permanently delete unposted purchase/sale drafts.
-- Completed/approved documents must use cancellation/return workflows.
create or replace function public.gaspos_delete_draft_trade(p_document uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_status text;
  v_type text;
begin
  if auth.uid() is null or not exists (
    select 1 from public.gas_members
    where user_id = auth.uid() and role = 'OWNER' and active = true
  ) then
    raise exception 'Hanya Owner aktif dapat menghapus draft';
  end if;
  select status, document_type into v_status, v_type
  from public.gas_documents where id = p_document for update;
  if not found or v_type not in ('PURCHASE', 'SALE') or v_status <> 'DRAFT' then
    raise exception 'Hanya draft pembelian/penjualan yang boleh dihapus';
  end if;
  if exists (select 1 from public.gas_logistics_requests where document_id=p_document or purchase_document_id=p_document)
     or exists (select 1 from public.gas_payments where document_id=p_document)
     or exists (select 1 from public.gas_customer_refunds where document_id=p_document)
     or exists (select 1 from public.gas_supplier_refunds where document_id=p_document)
     or exists (select 1 from public.gas_customer_empty_returns where document_id=p_document)
     or exists (select 1 from public.gas_empty_returns where document_id=p_document)
     or exists (select 1 from public.gas_sale_returns where document_id=p_document)
     or exists (select 1 from public.gas_purchase_returns where return_document_id=p_document)
     or exists (select 1 from public.gas_trip_stops where invoice_document_id=p_document)
     or exists (select 1 from public.gas_financial_entries f join public.gas_document_items i on i.id=f.document_item_id where i.document_id=p_document)
     or exists (select 1 from public.gas_stock_movements m join public.gas_document_items i on i.id=m.document_item_id where i.document_id=p_document)
     or exists (select 1 from public.gas_empty_obligations o join public.gas_document_items i on i.id=o.document_item_id where i.document_id=p_document)
     or exists (select 1 from public.gas_customer_empty_obligations o join public.gas_document_items i on i.id=o.item_id where i.document_id=p_document)
     or exists (select 1 from public.gas_purchase_returns r join public.gas_document_items i on i.id=r.purchase_item_id where i.document_id=p_document)
     or exists (select 1 from public.gas_sale_returns r join public.gas_document_items i on i.id=r.sale_item_id where i.document_id=p_document)
  then
    raise exception 'Draft memiliki kaitan stok, logistik atau keuangan; batalkan melalui prosedur resmi';
  end if;
  delete from public.gas_document_items where document_id=p_document;
  delete from public.gas_documents where id=p_document and status='DRAFT';
  if not found then raise exception 'Draft berubah status; tidak dihapus'; end if;
end;
$$;
revoke all on function public.gaspos_delete_draft_trade(uuid) from public, anon;
grant execute on function public.gaspos_delete_draft_trade(uuid) to authenticated;
