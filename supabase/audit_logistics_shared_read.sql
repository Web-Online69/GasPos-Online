-- Warehouse work is shared across active logistics staff. Price/finance tables
-- and all write permissions remain governed by their existing policies/RPCs.
ALTER POLICY logistics_request_read ON public.gas_logistics_requests
TO authenticated
USING (gaspos_private.current_role() IN ('OWNER','LOGISTIK'));
