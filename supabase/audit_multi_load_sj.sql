-- A visible SJ groups independently reconciled product loads. Existing single loads remain valid.
ALTER TABLE public.gas_logistics_requests ADD COLUMN IF NOT EXISTS sj_group_id uuid REFERENCES public.gas_logistics_requests(id);
CREATE INDEX IF NOT EXISTS gas_logistics_sj_group_idx ON public.gas_logistics_requests(sj_group_id);
CREATE OR REPLACE FUNCTION public.gaspos_create_delivery_sj_multi(p_lines jsonb,p_driver uuid,p_plate text,p_notes text,p_request uuid)
RETURNS uuid LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE x record; root uuid:=p_request; child uuid; old_count integer; line_count integer; first_line boolean:=true; old public.gas_logistics_requests%rowtype; t public.gas_trips%rowtype;
BEGIN
 IF auth.uid() IS NULL OR coalesce(gaspos_private.current_role(),'') NOT IN('OWNER','LOGISTIK') THEN RAISE EXCEPTION 'Hanya Owner atau Logistik membuat SJ'; END IF;
 IF root IS NULL OR p_lines IS NULL OR jsonb_typeof(p_lines)<>'array' OR jsonb_array_length(p_lines) NOT BETWEEN 1 AND 20 THEN RAISE EXCEPTION 'Isi 1–20 jenis muatan'; END IF;
 IF EXISTS(SELECT 1 FROM jsonb_array_elements(p_lines) v WHERE jsonb_typeof(v)<>'object' OR NOT (v ? 'product_id' AND v ? 'full_qty') OR jsonb_typeof(v->'full_qty')<>'number' OR (v->>'full_qty') !~ '^[0-9]+$') THEN RAISE EXCEPTION 'Jenis dan jumlah muatan tidak valid'; END IF;
 SELECT count(*) INTO line_count FROM jsonb_to_recordset(p_lines) AS l(product_id uuid,full_qty integer);
 IF EXISTS(SELECT 1 FROM jsonb_to_recordset(p_lines) AS l(product_id uuid,full_qty integer) WHERE product_id IS NULL OR full_qty NOT BETWEEN 1 AND 1000000) OR line_count<>(SELECT count(DISTINCT product_id) FROM jsonb_to_recordset(p_lines) AS l(product_id uuid,full_qty integer)) THEN RAISE EXCEPTION 'Jenis muatan harus berbeda dan jumlah lebih dari 0';END IF;
 PERFORM pg_advisory_xact_lock(948621);
 SELECT count(*) INTO old_count FROM public.gas_logistics_requests WHERE sj_group_id=root;
 IF old_count>0 THEN
  IF old_count<>line_count THEN RAISE EXCEPTION 'Permintaan SJ sudah digunakan';END IF;
  FOR x IN SELECT * FROM jsonb_to_recordset(p_lines) AS l(product_id uuid,full_qty integer) LOOP
   SELECT * INTO old FROM public.gas_logistics_requests WHERE sj_group_id=root AND product_id=x.product_id;
   IF NOT FOUND OR old.full_qty<>x.full_qty OR old.created_by<>auth.uid() OR old.status<>'APPROVED' OR old.direction<>'OUT' THEN RAISE EXCEPTION 'Permintaan SJ sudah digunakan'; END IF;
   SELECT * INTO t FROM public.gas_trips WHERE request_id=old.id;
   IF NOT FOUND OR t.driver_user_id IS DISTINCT FROM p_driver OR t.vehicle_plate IS DISTINCT FROM upper(left(btrim(coalesce(p_plate,'')),24)) THEN RAISE EXCEPTION 'Penugasan SJ berbeda';END IF;
  END LOOP;RETURN root;
 END IF;
 IF EXISTS(SELECT 1 FROM public.gas_logistics_requests WHERE id=root) THEN RAISE EXCEPTION 'Permintaan SJ sudah digunakan';END IF;
 FOR x IN SELECT * FROM jsonb_to_recordset(p_lines) AS l(product_id uuid,full_qty integer) ORDER BY product_id LOOP
  child:=CASE WHEN first_line THEN root ELSE gen_random_uuid() END;
  PERFORM public.gaspos_create_delivery_sj(x.product_id,x.full_qty,p_driver,p_plate,p_notes,child);
  UPDATE public.gas_logistics_requests SET sj_group_id=root WHERE id=child;
  first_line:=false;
 END LOOP;
 RETURN root;
END $$;
REVOKE ALL ON FUNCTION public.gaspos_create_delivery_sj_multi(jsonb,uuid,text,text,uuid) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.gaspos_create_delivery_sj_multi(jsonb,uuid,text,text,uuid) TO authenticated;
CREATE OR REPLACE FUNCTION public.gaspos_return_delivery_group(p_group uuid,p_counts jsonb)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE x record; expected integer;
BEGIN
 IF auth.uid() IS NULL OR coalesce(gaspos_private.current_role(),'') NOT IN('OWNER','LOGISTIK') THEN RAISE EXCEPTION 'Hanya Logistik atau Owner menerima kembali';END IF;
 PERFORM pg_advisory_xact_lock(948621);
 IF p_counts IS NULL OR jsonb_typeof(p_counts)<>'array' OR jsonb_array_length(p_counts) NOT BETWEEN 1 AND 20 THEN RAISE EXCEPTION 'Isi hitungan seluruh jenis tabung';END IF;
 IF EXISTS(SELECT 1 FROM jsonb_array_elements(p_counts) v WHERE jsonb_typeof(v)<>'object' OR NOT(v ? 'trip_id' AND v ? 'full_qty' AND v ? 'empty_qty') OR (v->>'full_qty') !~ '^[0-9]+$' OR (v->>'empty_qty') !~ '^[0-9]+$') THEN RAISE EXCEPTION 'Hitungan fisik tidak valid';END IF;
 SELECT count(*) INTO expected FROM public.gas_logistics_requests r JOIN public.gas_trips t ON t.request_id=r.id WHERE r.sj_group_id=p_group;
 IF expected=0 OR expected<>jsonb_array_length(p_counts) OR expected<>(SELECT count(DISTINCT trip_id) FROM jsonb_to_recordset(p_counts) AS c(trip_id uuid,full_qty integer,empty_qty integer)) THEN RAISE EXCEPTION 'Semua jenis muatan wajib dihitung sekali';END IF;
 FOR x IN SELECT * FROM jsonb_to_recordset(p_counts) AS c(trip_id uuid,full_qty integer,empty_qty integer) ORDER BY trip_id LOOP
  IF x.trip_id IS NULL OR x.full_qty IS NULL OR x.empty_qty IS NULL OR x.full_qty<0 OR x.empty_qty<0 OR NOT EXISTS(SELECT 1 FROM public.gas_trips t JOIN public.gas_logistics_requests r ON r.id=t.request_id WHERE t.id=x.trip_id AND r.sj_group_id=p_group) THEN RAISE EXCEPTION 'Perjalanan atau hitungan tidak sesuai SJ';END IF;
  PERFORM public.gaspos_return_trip(x.trip_id,x.full_qty,x.empty_qty);
 END LOOP;
END $$;
REVOKE ALL ON FUNCTION public.gaspos_return_delivery_group(uuid,jsonb) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.gaspos_return_delivery_group(uuid,jsonb) TO authenticated;
