
CREATE POLICY "gas_documents_finance_read" ON public.gas_documents FOR SELECT TO authenticated USING ((gaspos_private."current_role"() = 'KEUANGAN'::text));

CREATE POLICY "gas_documents_insert" ON public.gas_documents FOR INSERT TO authenticated WITH CHECK (((gaspos_private."current_role"() = ANY (ARRAY['OWNER'::text, 'LOGISTIK'::text])) AND (created_by = ( SELECT auth.uid() AS uid)) AND (status = ANY (ARRAY['DRAFT'::text, 'PENDING'::text])) AND (approved_by IS NULL)));

CREATE POLICY "gas_documents_read" ON public.gas_documents FOR SELECT TO authenticated USING ((gaspos_private."current_role"() = ANY (ARRAY['OWNER'::text, 'KEUANGAN'::text])));

CREATE POLICY "gas_products_driver_read" ON public.gas_products FOR SELECT TO authenticated USING ((gaspos_private."current_role"() = 'SALES_SOPIR'::text));

CREATE POLICY "gas_products_owner_write" ON public.gas_products FOR ALL TO authenticated USING ((gaspos_private."current_role"() = 'OWNER'::text)) WITH CHECK ((gaspos_private."current_role"() = 'OWNER'::text));

CREATE POLICY "gas_products_read" ON public.gas_products FOR SELECT TO authenticated USING ((gaspos_private."current_role"() = ANY (ARRAY['OWNER'::text, 'LOGISTIK'::text])));

CREATE POLICY "gas_partners_driver_customers_read" ON public.gas_partners FOR SELECT TO authenticated USING (((gaspos_private."current_role"() = 'SALES_SOPIR'::text) AND (partner_type = 'CUSTOMER'::text)));

CREATE POLICY "gas_partners_owner_write" ON public.gas_partners FOR ALL TO authenticated USING ((gaspos_private."current_role"() = 'OWNER'::text)) WITH CHECK ((gaspos_private."current_role"() = 'OWNER'::text));

CREATE POLICY "gas_partners_read" ON public.gas_partners FOR SELECT TO authenticated USING ((gaspos_private."current_role"() = ANY (ARRAY['OWNER'::text, 'LOGISTIK'::text])));

CREATE POLICY "gas_customer_prices_owner" ON public.gas_customer_prices FOR ALL TO authenticated USING ((gaspos_private."current_role"() = 'OWNER'::text)) WITH CHECK ((gaspos_private."current_role"() = 'OWNER'::text));

CREATE POLICY "gas_stock_movements_read" ON public.gas_stock_movements FOR SELECT TO authenticated USING ((gaspos_private."current_role"() = ANY (ARRAY['OWNER'::text, 'LOGISTIK'::text])));

CREATE POLICY "gas_financial_entries_finance_read" ON public.gas_financial_entries FOR SELECT TO authenticated USING ((gaspos_private."current_role"() = 'KEUANGAN'::text));

CREATE POLICY "gas_financial_entries_owner" ON public.gas_financial_entries FOR ALL TO authenticated USING ((gaspos_private."current_role"() = 'OWNER'::text)) WITH CHECK ((gaspos_private."current_role"() = 'OWNER'::text));

CREATE POLICY "gas_payments_finance_read" ON public.gas_payments FOR SELECT TO authenticated USING ((gaspos_private."current_role"() = 'KEUANGAN'::text));

CREATE POLICY "gas_payments_owner" ON public.gas_payments FOR ALL TO authenticated USING ((gaspos_private."current_role"() = 'OWNER'::text)) WITH CHECK ((gaspos_private."current_role"() = 'OWNER'::text));

CREATE POLICY "gas_members_owner_manage_logistik" ON public.gas_members FOR UPDATE TO authenticated USING (((gaspos_private."current_role"() = 'OWNER'::text) AND (role = 'LOGISTIK'::text))) WITH CHECK (((gaspos_private."current_role"() = 'OWNER'::text) AND (role = 'LOGISTIK'::text)));

CREATE POLICY "gas_members_owner_read" ON public.gas_members FOR SELECT TO authenticated USING ((gaspos_private."current_role"() = 'OWNER'::text));

CREATE POLICY "gas_members_self_read" ON public.gas_members FOR SELECT TO authenticated USING ((user_id = ( SELECT auth.uid() AS uid)));

CREATE POLICY "gas_empty_obligations_owner_read" ON public.gas_empty_obligations FOR SELECT TO authenticated USING ((gaspos_private."current_role"() = 'OWNER'::text));

CREATE POLICY "gas_document_items_insert" ON public.gas_document_items FOR INSERT TO authenticated WITH CHECK (((gaspos_private."current_role"() = ANY (ARRAY['OWNER'::text, 'LOGISTIK'::text])) AND (EXISTS ( SELECT 1
   FROM gas_documents d
  WHERE ((d.id = gas_document_items.document_id) AND (d.created_by = ( SELECT auth.uid() AS uid)) AND (d.status = 'DRAFT'::text))))));

CREATE POLICY "gas_document_items_read" ON public.gas_document_items FOR SELECT TO authenticated USING ((gaspos_private."current_role"() = ANY (ARRAY['OWNER'::text, 'KEUANGAN'::text])));

CREATE POLICY "gas_empty_returns_owner_read" ON public.gas_empty_returns FOR SELECT TO authenticated USING ((gaspos_private."current_role"() = 'OWNER'::text));

CREATE POLICY "gas_supplier_refunds_owner_read" ON public.gas_supplier_refunds FOR SELECT TO authenticated USING ((gaspos_private."current_role"() = 'OWNER'::text));

CREATE POLICY "gas_purchase_returns_owner_read" ON public.gas_purchase_returns FOR SELECT TO authenticated USING ((gaspos_private."current_role"() = 'OWNER'::text));

CREATE POLICY "customer_empty_owner_read" ON public.gas_customer_empty_obligations FOR SELECT TO authenticated USING ((gaspos_private."current_role"() = 'OWNER'::text));

CREATE POLICY "customer_empty_returns_owner_read" ON public.gas_customer_empty_returns FOR SELECT TO authenticated USING ((gaspos_private."current_role"() = 'OWNER'::text));

CREATE POLICY "gas_logistics_sopir_trip_read" ON public.gas_logistics_requests FOR SELECT TO authenticated USING (((gaspos_private."current_role"() = 'SALES_SOPIR'::text) AND (EXISTS ( SELECT 1
   FROM gas_trips t
  WHERE ((t.request_id = t.id) AND (t.driver_user_id = auth.uid()))))));

CREATE POLICY "logistics_request_read" ON public.gas_logistics_requests FOR SELECT TO authenticated USING (((gaspos_private."current_role"() = 'OWNER'::text) OR ((gaspos_private."current_role"() = 'LOGISTIK'::text) AND (created_by = auth.uid()))));

CREATE POLICY "customer_refunds_owner_read" ON public.gas_customer_refunds FOR SELECT TO authenticated USING ((gaspos_private."current_role"() = 'OWNER'::text));

CREATE POLICY "sale_returns_owner_read" ON public.gas_sale_returns FOR SELECT TO authenticated USING ((gaspos_private."current_role"() = 'OWNER'::text));

CREATE POLICY "gas_operating_expenses_finance_read" ON public.gas_operating_expenses FOR SELECT TO authenticated USING ((gaspos_private."current_role"() = 'KEUANGAN'::text));

CREATE POLICY "gas_operating_expenses_owner_select" ON public.gas_operating_expenses FOR SELECT TO authenticated USING ((gaspos_private."current_role"() = 'OWNER'::text));

CREATE POLICY "gas_trips_read" ON public.gas_trips FOR SELECT TO authenticated USING (((gaspos_private."current_role"() = ANY (ARRAY['OWNER'::text, 'LOGISTIK'::text])) OR ((gaspos_private."current_role"() = 'SALES_SOPIR'::text) AND (driver_user_id = auth.uid()))));

CREATE POLICY "opening_costs_finance" ON public.gas_inventory_opening_costs FOR SELECT TO authenticated USING ((gaspos_private."current_role"() = 'KEUANGAN'::text));

CREATE POLICY "opening_costs_owner" ON public.gas_inventory_opening_costs FOR SELECT TO authenticated USING ((gaspos_private."current_role"() = 'OWNER'::text));

CREATE POLICY "trip_audit_owner_read" ON public.gas_trip_stop_audit FOR SELECT TO authenticated USING ((gaspos_private."current_role"() = 'OWNER'::text));

CREATE POLICY "gas_trip_stops_read" ON public.gas_trip_stops FOR SELECT TO authenticated USING (((gaspos_private."current_role"() = ANY (ARRAY['OWNER'::text, 'LOGISTIK'::text])) OR (EXISTS ( SELECT 1
   FROM gas_trips t
  WHERE ((t.id = gas_trip_stops.trip_id) AND (t.driver_user_id = auth.uid()) AND (gaspos_private."current_role"() = 'SALES_SOPIR'::text))))));

