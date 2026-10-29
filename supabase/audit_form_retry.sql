-- Stable form request keys protect quantity and profit from lost-response retries.
ALTER TABLE public.gas_trip_stops ADD COLUMN IF NOT EXISTS request_id uuid;
CREATE UNIQUE INDEX IF NOT EXISTS gas_trip_stops_request_unique ON public.gas_trip_stops(request_id) WHERE request_id IS NOT NULL;
ALTER TABLE public.gas_operating_expenses ADD COLUMN IF NOT EXISTS request_id uuid;
CREATE UNIQUE INDEX IF NOT EXISTS gas_operating_expenses_request_unique ON public.gas_operating_expenses(request_id) WHERE request_id IS NOT NULL;

CREATE OR REPLACE FUNCTION public.gaspos_record_stop_once(p_trip uuid,p_customer uuid,p_full integer,p_empty integer,p_notes text,p_request uuid)
RETURNS uuid LANGUAGE plpgsql SECURITY DEFINER SET search_path=''
AS $$
DECLARE previous public.gas_trip_stops%rowtype; result uuid; role_name text:=coalesce(gaspos_private.current_role(),'');
BEGIN
 IF auth.uid() IS NULL OR role_name NOT IN ('OWNER','SALES_SOPIR') THEN RAISE EXCEPTION 'Hanya Owner atau Sopir yang ditugaskan dapat mencatat faktur'; END IF;
 IF role_name='SALES_SOPIR' AND NOT EXISTS(SELECT 1 FROM public.gas_trips t WHERE t.id=p_trip AND t.driver_user_id=auth.uid()) THEN RAISE EXCEPTION 'Bukan sopir perjalanan ini'; END IF;
 IF p_request IS NULL THEN RAISE EXCEPTION 'ID permintaan faktur wajib diisi'; END IF;
 PERFORM pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(p_request::text,0));
 SELECT * INTO previous FROM public.gas_trip_stops WHERE request_id=p_request;
 IF FOUND THEN
  IF previous.trip_id IS DISTINCT FROM p_trip OR previous.customer_id IS DISTINCT FROM p_customer
    OR previous.full_qty IS DISTINCT FROM p_full OR previous.empty_qty IS DISTINCT FROM p_empty
    OR coalesce(previous.notes,'') IS DISTINCT FROM left(coalesce(p_notes,''),300)
    OR previous.created_by IS DISTINCT FROM auth.uid() THEN
   RAISE EXCEPTION 'ID permintaan faktur sudah digunakan untuk data atau petugas berbeda';
  END IF;
  RETURN previous.id;
 END IF;
 -- Original procedure retains trip locks, customer validation and load limits.
 result:=public.gaspos_record_stop(p_trip,p_customer,p_full,p_empty,p_notes);
 UPDATE public.gas_trip_stops SET request_id=p_request WHERE id=result;
 RETURN result;
END;
$$;
REVOKE ALL ON FUNCTION public.gaspos_record_stop_once(uuid,uuid,integer,integer,text,uuid) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.gaspos_record_stop_once(uuid,uuid,integer,integer,text,uuid) TO authenticated;

CREATE OR REPLACE FUNCTION public.gaspos_add_operating_expense_once(p_date date,p_category text,p_description text,p_amount numeric,p_request uuid)
RETURNS uuid LANGUAGE plpgsql SECURITY DEFINER SET search_path=''
AS $$
DECLARE previous public.gas_operating_expenses%rowtype; result uuid;
BEGIN
 IF auth.uid() IS NULL OR coalesce(gaspos_private.current_role(),'') NOT IN ('OWNER','KEUANGAN') THEN RAISE EXCEPTION 'Hanya Owner atau Keuangan dapat mencatat biaya'; END IF;
 IF p_request IS NULL THEN RAISE EXCEPTION 'ID permintaan biaya wajib diisi'; END IF;
 IF p_amount IS NULL OR p_amount<>pg_catalog.round(p_amount,2) THEN RAISE EXCEPTION 'Nominal biaya tidak valid'; END IF;
 PERFORM pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(p_request::text,0));
 SELECT * INTO previous FROM public.gas_operating_expenses WHERE request_id=p_request;
 IF FOUND THEN
  IF previous.expense_date IS DISTINCT FROM p_date OR previous.category IS DISTINCT FROM p_category
    OR previous.description IS DISTINCT FROM btrim(coalesce(p_description,'')) OR previous.amount IS DISTINCT FROM p_amount
    OR previous.created_by IS DISTINCT FROM auth.uid() THEN
   RAISE EXCEPTION 'ID permintaan biaya sudah digunakan untuk data atau petugas berbeda';
  END IF;
  RETURN previous.id;
 END IF;
 result:=public.gaspos_add_operating_expense(p_date,p_category,p_description,p_amount);
 UPDATE public.gas_operating_expenses SET request_id=p_request WHERE id=result;
 RETURN result;
END;
$$;
REVOKE ALL ON FUNCTION public.gaspos_add_operating_expense_once(date,text,text,numeric,uuid) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.gaspos_add_operating_expense_once(date,text,text,numeric,uuid) TO authenticated;
