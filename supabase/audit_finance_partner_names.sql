-- Finance needs counterpart names for invoice/payment selection, not contact/master access.
CREATE OR REPLACE FUNCTION public.gaspos_finance_partner_names()
RETURNS TABLE(id uuid,name text)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=''
AS $$
BEGIN
 IF auth.uid() IS NULL OR coalesce(gaspos_private.current_role(),'') NOT IN ('OWNER','KEUANGAN') THEN
  RAISE EXCEPTION 'Hanya Owner dan Keuangan dapat membaca mitra tagihan';
 END IF;
 RETURN QUERY SELECT p.id,p.name FROM public.gas_partners p
 WHERE EXISTS (SELECT 1 FROM public.gas_documents d WHERE d.partner_id=p.id)
 ORDER BY p.name;
END;
$$;
REVOKE ALL ON FUNCTION public.gaspos_finance_partner_names() FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.gaspos_finance_partner_names() TO authenticated;
