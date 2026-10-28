-- Ledger facts are written only by validated SECURITY DEFINER transaction RPCs.
-- Owner/Finance retain SELECT; no browser role may insert, alter, delete or truncate.
REVOKE ALL ON TABLE public.gas_financial_entries,public.gas_payments FROM PUBLIC,anon,authenticated;
GRANT SELECT ON TABLE public.gas_financial_entries,public.gas_payments TO authenticated;
DROP POLICY IF EXISTS gas_financial_entries_owner ON public.gas_financial_entries;
CREATE POLICY gas_financial_entries_owner ON public.gas_financial_entries
 FOR SELECT TO authenticated USING (gaspos_private.current_role()='OWNER');
DROP POLICY IF EXISTS gas_payments_owner ON public.gas_payments;
CREATE POLICY gas_payments_owner ON public.gas_payments
 FOR SELECT TO authenticated USING (gaspos_private.current_role()='OWNER');
CREATE UNIQUE INDEX IF NOT EXISTS gas_financial_entries_one_price_per_item ON public.gas_financial_entries(document_item_id);
