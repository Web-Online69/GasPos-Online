-- Private invoice identity. No account number or signature assets belong in public source code.
CREATE TABLE public.gas_invoice_profile (
 singleton boolean PRIMARY KEY DEFAULT true CHECK(singleton),
 data jsonb NOT NULL DEFAULT '{}'::jsonb CHECK(jsonb_typeof(data)='object' AND octet_length(data::text)<=350000),
 updated_by uuid REFERENCES auth.users(id),updated_at timestamptz NOT NULL DEFAULT now()
);
ALTER TABLE public.gas_invoice_profile ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.gas_invoice_profile FROM PUBLIC,anon,authenticated;
GRANT SELECT ON public.gas_invoice_profile TO authenticated;
CREATE POLICY invoice_profile_owner_read ON public.gas_invoice_profile FOR SELECT TO authenticated USING(gaspos_private.current_role()='OWNER');
CREATE OR REPLACE FUNCTION public.gaspos_save_invoice_profile(p_data jsonb)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE name text;value text;
BEGIN
 IF auth.uid() IS NULL OR coalesce(gaspos_private.current_role(),'')<>'OWNER' THEN RAISE EXCEPTION 'Hanya Owner mengatur identitas invoice';END IF;
 IF p_data IS NULL OR jsonb_typeof(p_data)<>'object' OR octet_length(p_data::text)>350000 THEN RAISE EXCEPTION 'Data identitas invoice tidak valid';END IF;
 FOR name,value IN SELECT j.key,j.value#>>'{}' FROM jsonb_each(p_data) j LOOP
  IF name NOT IN ('agency_label','agency_name','store_name','address','city','phone','bank_name','bank_account','account_name','signer_name','footer_agency_name','stamp_image','signature_image') THEN RAISE EXCEPTION 'Kolom identitas tidak dikenal';END IF;
  IF jsonb_typeof(p_data->name)<>'string' THEN RAISE EXCEPTION 'Isi identitas harus teks';END IF;
  IF name IN ('stamp_image','signature_image') THEN
   IF length(value)>150000 OR (value<>'' AND value !~ '^data:image/png;base64,[A-Za-z0-9+/=]+$') THEN RAISE EXCEPTION 'Gambar tanda tangan atau stempel tidak valid';END IF;
  ELSIF length(value)>500 THEN RAISE EXCEPTION 'Teks identitas terlalu panjang';END IF;
 END LOOP;
 IF length(btrim(coalesce(p_data->>'agency_name','')))<3 OR length(btrim(coalesce(p_data->>'store_name','')))<3 THEN RAISE EXCEPTION 'Nama agen dan toko wajib diisi';END IF;
 INSERT INTO public.gas_invoice_profile(singleton,data,updated_by,updated_at) VALUES(true,p_data,auth.uid(),now())
 ON CONFLICT(singleton) DO UPDATE SET data=excluded.data,updated_by=excluded.updated_by,updated_at=excluded.updated_at;
END $$;
REVOKE ALL ON FUNCTION public.gaspos_save_invoice_profile(jsonb) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.gaspos_save_invoice_profile(jsonb) TO authenticated;
