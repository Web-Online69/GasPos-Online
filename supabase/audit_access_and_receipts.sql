CREATE OR REPLACE FUNCTION gaspos_private."current_role"()
RETURNS text LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO ''
AS $$ SELECT coalesce((SELECT m.role FROM public.gas_members m WHERE m.user_id=(SELECT auth.uid()) AND m.active=true),'') $$;
ALTER POLICY gas_logistics_sopir_trip_read ON public.gas_logistics_requests
USING (gaspos_private.current_role()='SALES_SOPIR' AND EXISTS
(SELECT 1 FROM public.gas_trips t WHERE t.request_id=gas_logistics_requests.id AND t.driver_user_id=(SELECT auth.uid())));

ALTER TABLE public.gas_logistics_requests ADD COLUMN IF NOT EXISTS purchase_document_id uuid REFERENCES public.gas_documents(id);
CREATE OR REPLACE FUNCTION public.gaspos_pending_purchase_lines()
RETURNS TABLE(document_id uuid,document_no text,supplier_id uuid,product_id uuid,product_name text,remaining_full bigint,remaining_empty bigint)
LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO '' AS $$
select d.id,d.document_no,d.partner_id,i.product_id,p.name,
(i.quantity_full-coalesce(m.full_qty,0)-coalesce(pending.full_qty,0))::bigint,
(i.quantity_empty-coalesce(m.empty_qty,0)-coalesce(pending.empty_qty,0))::bigint
from public.gas_documents d join public.gas_document_items i on i.document_id=d.id join public.gas_products p on p.id=i.product_id
left join lateral(select sum(delta_full) full_qty,sum(-delta_empty) empty_qty from public.gas_stock_movements where document_item_id=i.id) m on true
left join lateral(select sum(full_qty) full_qty,sum(empty_qty) empty_qty from public.gas_logistics_requests r where r.purchase_document_id=d.id and r.product_id=i.product_id and r.status='PENDING') pending on true
where d.document_type='PURCHASE' and d.status in ('DRAFT','PARTIAL')
and gaspos_private.current_role() in ('OWNER','LOGISTIK')
and 1=(select count(*) from public.gas_document_items x where x.document_id=d.id and x.product_id=i.product_id)
and (i.quantity_full>coalesce(m.full_qty,0)+coalesce(pending.full_qty,0) or i.quantity_empty>coalesce(m.empty_qty,0)+coalesce(pending.empty_qty,0))
$$;
REVOKE ALL ON FUNCTION public.gaspos_pending_purchase_lines() FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.gaspos_pending_purchase_lines() TO authenticated;

CREATE OR REPLACE FUNCTION public.gaspos_submit_purchase_receipt(p_purchase uuid,p_product uuid,p_full integer,p_empty integer,p_notes text)
RETURNS uuid LANGUAGE plpgsql SECURITY DEFINER SET search_path TO '' AS $$
declare d public.gas_documents%rowtype; line record; result uuid;
begin
 if auth.uid() is null or gaspos_private.current_role() not in ('OWNER','LOGISTIK') then raise exception 'Akses ditolak'; end if;
 perform pg_advisory_xact_lock(948621);
 select * into d from public.gas_documents where id=p_purchase for update;
 if not found or d.document_type<>'PURCHASE' or d.status not in ('DRAFT','PARTIAL') then raise exception 'Pembelian tidak dapat diterima'; end if;
 select * into line from public.gaspos_pending_purchase_lines() x where x.document_id=p_purchase and x.product_id=p_product;
 if not found or p_full is null or p_empty is null or p_full<0 or p_empty<0 or p_full+p_empty=0 or p_full>line.remaining_full or p_empty>line.remaining_empty then raise exception 'Jumlah melebihi sisa pembelian atau item tidak unik'; end if;
 insert into public.gas_logistics_requests(direction,partner_id,product_id,full_qty,empty_qty,notes,created_by,purchase_document_id)
 values('IN',d.partner_id,p_product,p_full,p_empty,nullif(left(btrim(p_notes),500),''),auth.uid(),p_purchase) returning id into result;
 return result;
end $$;
REVOKE ALL ON FUNCTION public.gaspos_submit_purchase_receipt(uuid,uuid,integer,integer,text) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.gaspos_submit_purchase_receipt(uuid,uuid,integer,integer,text) TO authenticated;
CREATE OR REPLACE FUNCTION public.gaspos_review_logistics(p_id uuid, p_approve boolean, p_reason text)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare req public.gas_logistics_requests%rowtype;v_doc uuid;v_item uuid;v_full bigint;v_empty bigint;
begin
if auth.uid() is null or gaspos_private.current_role()<>'OWNER' then raise exception 'ACC hanya untuk Owner';end if;
perform pg_advisory_xact_lock(948621);
select * into req from public.gas_logistics_requests where id=p_id for update;
if not found or req.status<>'PENDING' then raise exception 'Dokumen sudah diproses atau tidak ditemukan';end if;
if p_approve is null then raise exception 'Keputusan harus diisi';end if;
if not p_approve then
 if length(btrim(coalesce(p_reason,'')))<5 then raise exception 'Alasan penolakan minimal 5 karakter';end if;
 update public.gas_logistics_requests set status='REJECTED',reviewed_by=auth.uid(),reviewed_at=now(),rejection_reason=btrim(p_reason) where id=p_id;
 return null;
end if;
if req.purchase_document_id is not null then
 if req.direction<>'IN' then raise exception 'Penerimaan pembelian harus masuk'; end if;
 select id into v_item from public.gas_document_items where document_id=req.purchase_document_id and product_id=req.product_id;
 if v_item is null then raise exception 'Item pembelian tidak ditemukan'; end if;
 perform gaspos_private.receive_purchase(req.purchase_document_id,jsonb_build_array(jsonb_build_object('item_id',v_item,'quantity_full',req.full_qty,'quantity_empty',req.empty_qty)),req.id);
 update public.gas_logistics_requests set status='APPROVED',reviewed_by=auth.uid(),reviewed_at=now(),document_id=req.purchase_document_id where id=p_id;
 return req.purchase_document_id;
end if;
if req.direction='OUT' then
 select coalesce(sum(m.delta_full),0),coalesce(sum(m.delta_empty),0) into v_full,v_empty from public.gas_stock_movements m join public.gas_document_items i on i.id=m.document_item_id where i.product_id=req.product_id;
 if v_full<req.full_qty or v_empty<req.empty_qty then raise exception 'Stok penuh atau kosong tidak cukup';end if;
end if;
insert into public.gas_documents(document_no,document_type,partner_id,status,created_by,approved_by,notes) values('LOG-'||req.id::text,case when req.direction='IN' then 'RECEIPT' else 'DISPATCH' end,req.partner_id,'APPROVED',req.created_by,auth.uid(),req.notes) returning id into v_doc;
insert into public.gas_document_items(document_id,product_id,quantity_full,quantity_empty) values(v_doc,req.product_id,req.full_qty,req.empty_qty) returning id into v_item;
insert into public.gas_stock_movements(document_item_id,movement_key,delta_full,delta_empty) values(v_item,'LOG-'||req.id::text,case when req.direction='IN' then req.full_qty else -req.full_qty end,case when req.direction='IN' then req.empty_qty else -req.empty_qty end);
update public.gas_logistics_requests set status='APPROVED',reviewed_by=auth.uid(),reviewed_at=now(),document_id=v_doc where id=p_id;
return v_doc;
end;$function$
;

