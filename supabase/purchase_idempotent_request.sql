-- Idempotent purchase requests: prevents duplicates on client retry after network failure.
alter table public.gas_documents add column if not exists purchase_request_id uuid;
create unique index if not exists gas_documents_purchase_request_id_key on public.gas_documents (purchase_request_id) where purchase_request_id is not null;
CREATE OR REPLACE FUNCTION public.gaspos_create_purchase_once(p_partner_id uuid, p_notes text, p_items jsonb, p_reference text, p_invoice_date date, p_due_date date, p_freight numeric, p_other numeric, p_request uuid)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
 v_doc uuid;
 v_author uuid;
begin
 if auth.uid() is null or gaspos_private.current_role()<>'OWNER' then
   raise exception 'Khusus Owner';
 end if;
 if p_request is null then
   raise exception 'Nomor permintaan wajib diisi';
 end if;
 perform pg_catalog.pg_advisory_xact_lock(948621);
 select id,created_by into v_doc,v_author
   from public.gas_documents where purchase_request_id=p_request for update;
 if found then
   if v_author is distinct from auth.uid() then
     raise exception 'Nomor permintaan milik pengguna lain';
   end if;
   return v_doc;
 end if;
 v_doc:=gaspos_private.create_purchase(
   p_partner_id,p_notes,p_items,p_reference,p_invoice_date,p_due_date,p_freight,p_other
 );
 update public.gas_documents set purchase_request_id=p_request where id=v_doc;
 return v_doc;
end
$function$;
revoke all on function public.gaspos_create_purchase_once(uuid,text,jsonb,text,date,date,numeric,numeric,uuid) from public,anon;
grant execute on function public.gaspos_create_purchase_once(uuid,text,jsonb,text,date,date,numeric,numeric,uuid) to authenticated;
