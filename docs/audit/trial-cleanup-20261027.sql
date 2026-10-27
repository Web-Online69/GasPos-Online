-- NOT EXECUTED. Run only when this exact GASPOS-TRIAL-20261027 dataset is disposable.
-- Accounts, sessions and trial transactions are intentionally retained for review now.
BEGIN;
CREATE TEMP TABLE cleanup_docs(id uuid primary key) ON COMMIT DROP;
INSERT INTO cleanup_docs VALUES ('a3695b6f-4df6-4a0a-a601-9c37a19b91a2'::uuid),('67a0604e-4503-43b1-8d70-0e4109da98dd'::uuid),('901abf54-f2d6-4eae-a4a2-5b4bf1f85f8c'::uuid),('d4de1d87-1a38-43a6-9c85-c4a092ee3c4c'::uuid),('73c1e4c3-bab5-41b9-a12d-df715137440d'::uuid);
DO $$ BEGIN
 IF NOT EXISTS(SELECT 1 FROM public.gas_products WHERE id='ee84e952-533d-4f8e-b585-16e33a8348e2' AND name='GASPOS-TRIAL-20261027 CYLINDER') THEN RAISE EXCEPTION 'Trial product guard failed';END IF;
 IF EXISTS(SELECT 1 FROM public.gas_document_items WHERE product_id='ee84e952-533d-4f8e-b585-16e33a8348e2' AND document_id NOT IN(SELECT id FROM cleanup_docs)) THEN RAISE EXCEPTION 'Additional documents exist; review instead of deleting';END IF;
END $$;
DELETE FROM public.gas_trip_stop_audit WHERE stop_id IN(SELECT id FROM public.gas_trip_stops WHERE trip_id='19a31de9-d755-4021-a564-29c8c1219529');
DELETE FROM public.gas_trip_stops WHERE trip_id='19a31de9-d755-4021-a564-29c8c1219529';
DELETE FROM public.gas_trips WHERE id='19a31de9-d755-4021-a564-29c8c1219529';
DELETE FROM public.gas_logistics_requests WHERE id IN('94a0d61b-a55f-47f8-8691-8318ee92dc84'::uuid,'ff242fa7-b912-4d78-8882-7c43972d3e07'::uuid) OR (product_id='ee84e952-533d-4f8e-b585-16e33a8348e2' AND notes LIKE 'GASPOS-TRIAL-20261027%' AND document_id IS NULL);
DELETE FROM public.gas_stock_movements WHERE document_item_id IN(SELECT id FROM public.gas_document_items WHERE document_id IN(SELECT id FROM cleanup_docs));
DELETE FROM public.gas_customer_empty_returns WHERE document_id IN(SELECT id FROM cleanup_docs);
DELETE FROM public.gas_empty_returns WHERE document_id IN(SELECT id FROM cleanup_docs);
DELETE FROM public.gas_customer_empty_obligations WHERE item_id IN(SELECT id FROM public.gas_document_items WHERE document_id IN(SELECT id FROM cleanup_docs));
DELETE FROM public.gas_empty_obligations WHERE document_item_id IN(SELECT id FROM public.gas_document_items WHERE document_id IN(SELECT id FROM cleanup_docs));
DELETE FROM public.gas_customer_refunds WHERE document_id IN(SELECT id FROM cleanup_docs);
DELETE FROM public.gas_supplier_refunds WHERE document_id IN(SELECT id FROM cleanup_docs);
DELETE FROM public.gas_payments WHERE document_id IN(SELECT id FROM cleanup_docs);
DELETE FROM public.gas_financial_entries WHERE document_item_id IN(SELECT id FROM public.gas_document_items WHERE document_id IN(SELECT id FROM cleanup_docs));
DELETE FROM public.gas_document_items WHERE document_id IN(SELECT id FROM cleanup_docs);
DELETE FROM public.gas_documents WHERE id IN(SELECT id FROM cleanup_docs);
DELETE FROM public.gas_operating_expenses WHERE id='b1eb1ef0-db27-4477-9692-3f3bea723276' AND description='GASPOS-TRIAL-20261027 SIMULATED FUEL';
DELETE FROM public.gas_partners WHERE id IN('04881ae6-f724-4d64-abe3-7e38822b06ce'::uuid,'5941d4b0-b89d-458b-8c2d-2c2b9a089c1f'::uuid,'14197212-32d3-4c1a-b1a6-0eb54971a9cc'::uuid,'40237209-ca4c-4977-8391-094471450244'::uuid) AND name LIKE 'GASPOS-TRIAL-20261027%';
DELETE FROM public.gas_products WHERE id='ee84e952-533d-4f8e-b585-16e33a8348e2' AND name='GASPOS-TRIAL-20261027 CYLINDER';
DELETE FROM public.gas_members WHERE user_id IN('192ee15f-00c9-4ec9-a197-abe7ad6afd9a'::uuid,'2dc5defa-4db1-4502-8d0b-fd3e44e513f4'::uuid,'a02d530d-c5fd-402f-8ad1-ab69b7d6cee2'::uuid,'806b897e-6b11-4469-8520-8e442aff828a'::uuid);
DELETE FROM auth.users WHERE id IN('192ee15f-00c9-4ec9-a197-abe7ad6afd9a'::uuid,'2dc5defa-4db1-4502-8d0b-fd3e44e513f4'::uuid,'a02d530d-c5fd-402f-8ad1-ab69b7d6cee2'::uuid,'806b897e-6b11-4469-8520-8e442aff828a'::uuid) AND email LIKE 'trial_%@users.gaspos.local';
-- Membership removal makes outstanding JWTs fail GASPOS authorization immediately.
-- Product sequence is deliberately not reset. Any new dependencies cause FK failure/rollback.
COMMIT;
