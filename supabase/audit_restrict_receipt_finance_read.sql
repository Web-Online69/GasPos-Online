-- Limit receipt progress to authorized staff. Keep the existing return columns.
create or replace view public.gaspos_purchase_receipt_progress as  SELECT i.document_id,
    i.id AS item_id,
    i.product_id,
    i.quantity_full AS ordered_full,
    i.quantity_empty AS ordered_empty,
    COALESCE(( SELECT sum(m.delta_full) AS sum
           FROM gas_stock_movements m
          WHERE m.document_item_id = i.id), 0::bigint)::integer AS received_full,
    COALESCE(( SELECT sum(
                CASE
                    WHEN i.purchase_mode = 'EMPTY_ONLY'::text THEN m.delta_empty
                    ELSE - m.delta_empty
                END) AS sum
           FROM gas_stock_movements m
          WHERE m.document_item_id = i.id), 0::bigint)::integer AS sent_empty
   FROM gas_document_items i
     JOIN gas_documents d ON d.id = i.document_id
  WHERE d.document_type = 'PURCHASE'::text AND gaspos_private.current_role() IN ('OWNER','LOGISTIK');
revoke all on public.gaspos_purchase_receipt_progress from public,anon;
grant select on public.gaspos_purchase_receipt_progress to authenticated;
-- Finance view already role-filters, but anonymous users must not query it.
revoke all on public.gaspos_trade_balances from public,anon;
grant select on public.gaspos_trade_balances to authenticated;
-- Authenticated-only RPC; function itself also checks user and role.
revoke all on function public.gaspos_receive_unassigned_cylinder_collection(uuid) from public,anon;
grant execute on function public.gaspos_receive_unassigned_cylinder_collection(uuid) to authenticated;
