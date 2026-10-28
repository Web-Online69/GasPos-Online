-- One form submission can be retried after a lost response without posting twice.
ALTER TABLE public.gas_payments ADD COLUMN IF NOT EXISTS request_id uuid;
ALTER TABLE public.gas_payments ADD COLUMN IF NOT EXISTS created_by uuid REFERENCES auth.users(id);
CREATE UNIQUE INDEX IF NOT EXISTS gas_payments_request_unique ON public.gas_payments(request_id) WHERE request_id IS NOT NULL;

CREATE OR REPLACE FUNCTION public.gaspos_record_payment_once(p_document_id uuid,p_amount numeric,p_request uuid)
RETURNS uuid LANGUAGE plpgsql SECURITY DEFINER SET search_path=''
AS $$
DECLARE previous public.gas_payments%rowtype; result uuid;
BEGIN
 IF auth.uid() IS NULL OR coalesce(gaspos_private.current_role(),'') NOT IN ('OWNER','KEUANGAN') THEN
  RAISE EXCEPTION 'Hanya Owner dan Keuangan dapat mencatat pembayaran';
 END IF;
 IF p_request IS NULL THEN RAISE EXCEPTION 'ID permintaan pembayaran wajib diisi'; END IF;
 -- Serialize the same key even across different invoice rows.
 PERFORM pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(p_request::text,0));
 SELECT * INTO previous FROM public.gas_payments WHERE request_id=p_request;
 IF FOUND THEN
  IF previous.document_id IS DISTINCT FROM p_document_id OR previous.amount IS DISTINCT FROM p_amount
     OR previous.created_by IS DISTINCT FROM auth.uid() THEN
   RAISE EXCEPTION 'ID permintaan pembayaran sudah digunakan untuk data atau petugas berbeda';
  END IF;
  RETURN previous.id;
 END IF;
 -- Reuse the existing document lock, approved status and net balance checks.
 result:=gaspos_private.record_payment(p_document_id,p_amount);
 UPDATE public.gas_payments SET request_id=p_request,created_by=auth.uid() WHERE id=result;
 RETURN result;
END;
$$;
REVOKE ALL ON FUNCTION public.gaspos_record_payment_once(uuid,numeric,uuid) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.gaspos_record_payment_once(uuid,numeric,uuid) TO authenticated;
