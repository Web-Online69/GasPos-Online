-- Allow multiple distinct item receipts against one purchase document.
-- The purchase document remains the shared document_id; each receipt has its own request ID.
-- Preserve the outbound document's one-to-one constraint.
alter table public.gas_logistics_requests
 drop constraint gas_logistics_requests_document_id_key;
create unique index gas_logistics_requests_outbound_document_uidx
 on public.gas_logistics_requests(document_id)
 where direction='OUT' and document_id is not null;
create index if not exists gas_logistics_requests_purchase_doc_idx
 on public.gas_logistics_requests(purchase_document_id)
 where purchase_document_id is not null;
