create or replace view public.gaspos_purchase_receipt_progress as SELECT i.document_id,
    i.id AS item_id,
    i.product_id,
    i.quantity_full AS ordered_full,
    i.quantity_empty AS ordered_empty,
    COALESCE(( SELECT sum(m.delta_full) AS sum
           FROM gas_stock_movements m
          WHERE m.document_item_id = i.id), 0::bigint)::integer AS received_full,
    COALESCE(( SELECT sum(case when i.purchase_mode='EMPTY_ONLY' then m.delta_empty else -m.delta_empty end) AS sum
           FROM gas_stock_movements m
          WHERE m.document_item_id = i.id), 0::bigint)::integer AS sent_empty
   FROM gas_document_items i
     JOIN gas_documents d ON d.id = i.document_id
  WHERE d.document_type = 'PURCHASE'::text;
CREATE OR REPLACE FUNCTION public.gaspos_edit_purchase_receipt(p_request uuid, p_product uuid, p_full integer, p_empty integer, p_delete boolean DEFAULT false)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
 v_role text:=gaspos_private.current_role();
 v_request public.gas_logistics_requests%rowtype;
 v_doc public.gas_documents%rowtype;
 v_old_item public.gas_document_items%rowtype;
 v_new_item public.gas_document_items%rowtype;
 v_move public.gas_stock_movements%rowtype;
 v_item_count integer;
 v_other_full bigint;
 v_other_empty bigint;
 v_total_full bigint;
 v_total_empty bigint;
 v_owed bigint;
 v_returned bigint;
 v_has_later boolean;
 v_new_product uuid;
 v_new_full integer;
 v_new_empty integer;
 v_complete boolean:=true;
 v_row record;
begin
 if auth.uid() is null or v_role not in ('OWNER','LOGISTIK') then
  raise exception 'Hanya Owner atau Logistik yang dapat mengedit penerimaan';
 end if;
 perform pg_catalog.pg_advisory_xact_lock(948621);
 select * into v_request from public.gas_logistics_requests where id=p_request for update;
 if not found or v_request.direction<>'IN' or v_request.status<>'APPROVED'
   or v_request.purchase_document_id is null then
  raise exception 'Penerimaan pembelian tidak ditemukan atau belum tercatat';
 end if;
 select * into v_doc from public.gas_documents where id=v_request.purchase_document_id for update;
 if not found or v_doc.document_type<>'PURCHASE' then raise exception 'Dokumen pembelian tidak ditemukan';end if;
 select * into v_old_item from public.gas_document_items
  where document_id=v_doc.id and product_id=v_request.product_id;
 if not found then raise exception 'Rincian pembelian tidak cocok dengan penerimaan';end if;
 select * into v_move from public.gas_stock_movements
  where movement_key='RECEIPT-'||p_request::text||'-'||v_old_item.id::text for update;
 if not found then raise exception 'Mutasi penerimaan tidak ditemukan';end if;
 select exists(
   select 1 from public.gas_stock_movements m
   join public.gas_document_items i on i.id=m.document_item_id
   where i.product_id=v_request.product_id and m.id<>v_move.id
     and (m.created_at,m.id)>(v_move.created_at,v_move.id)
 ) into v_has_later;
 if v_has_later and v_role<>'OWNER' then
  raise exception 'Tabung ini sudah memiliki transaksi berikutnya. Hanya Owner boleh mengedit atau menghapus.';
 end if;
 if p_delete then
   v_new_product:=v_request.product_id;
   v_new_full:=0;
   v_new_empty:=0;
 else
   if p_product is null or p_full is null or p_empty is null
      or p_full<0 or p_empty<0 or p_full>1000000 or p_empty>1000000
      or p_full+p_empty=0 then
      raise exception 'Jenis tabung dan jumlah penerimaan tidak valid';
   end if;
   v_new_product:=p_product;v_new_full:=p_full;v_new_empty:=p_empty;
 end if;
 if not p_delete and v_new_product<>v_request.product_id then
    select * into v_new_item from public.gas_document_items
      where document_id=v_doc.id and product_id=v_new_product for update;
    if not found then
      select count(*) into v_item_count from public.gas_document_items where document_id=v_doc.id;
      if v_item_count<>1 then
        raise exception 'Jenis tabung harus sesuai rincian pembelian untuk dokumen dengan banyak barang';
      end if;
      if exists(select 1 from public.gas_stock_movements where document_item_id=v_old_item.id and id<>v_move.id) then
        raise exception 'Jenis tabung tidak dapat diganti karena ada transaksi lain di rincian pembelian ini';
      end if;
      if v_role<>'OWNER' and v_has_later then
        raise exception 'Jenis tabung terkunci. Hanya Owner yang bisa mengubah';
      end if;
      update public.gas_document_items set product_id=v_new_product where id=v_old_item.id;
      v_new_item:=v_old_item;
      v_new_item.product_id:=v_new_product;
    end if;
 end if;
 if not p_delete then
  if v_new_product=v_request.product_id then v_new_item:=v_old_item;end if;
  select coalesce(sum(m.delta_full),0),coalesce(sum(case when v_new_item.purchase_mode='EMPTY_ONLY' then m.delta_empty else -m.delta_empty end),0)
  into v_other_full,v_other_empty
  from public.gas_stock_movements m where m.document_item_id=v_new_item.id and m.id<>v_move.id;
  if v_other_full+v_new_full>v_new_item.quantity_full
       or v_other_empty+v_new_empty>v_new_item.quantity_empty then
    raise exception 'Jumlah melebihi rincian pembelian. Periksa jumlah pada faktur.';
  end if;
 end if;
 if p_delete then
   delete from public.gas_stock_movements where id=v_move.id;
   delete from public.gas_logistics_requests where id=v_request.id;
 else
   update public.gas_stock_movements
     set document_item_id=v_new_item.id,
         movement_key='RECEIPT-'||p_request::text||'-'||v_new_item.id::text,
         delta_full=v_new_full,delta_empty=case when v_new_item.purchase_mode='EMPTY_ONLY' then v_new_empty else -v_new_empty end
     where id=v_move.id;
   update public.gas_logistics_requests
     set product_id=v_new_product, full_qty=v_new_full,empty_qty=v_new_empty
     where id=v_request.id;
 end if;
 -- The stock running total must stay nonnegative at every subsequent movement
 -- of both the old and new gas cylinder types.
 if exists (
  with sequence as (
    select i.product_id,m.id,m.created_at,
       sum(m.delta_full) over(partition by i.product_id order by m.created_at,m.id) as full_stock,
       sum(m.delta_empty) over(partition by i.product_id order by m.created_at,m.id) as empty_stock
    from public.gas_stock_movements m
    join public.gas_document_items i on i.id=m.document_item_id
    where i.product_id in (v_request.product_id,v_new_product)
  )
  select 1 from sequence
  where (created_at,id)>=(v_move.created_at,v_move.id)
    and (full_stock<0 or empty_stock<0)
 ) then
  raise exception 'Edit tidak dapat disimpan karena stok setelah transaksi menjadi negatif. Periksa transaksi berikutnya.';
 end if;
 -- Recalculate empty-cylinder obligation from all receipts of affected items.
 for v_row in
   select distinct i.id,i.purchase_mode,d.partner_id
   from public.gas_document_items i
   join public.gas_documents d on d.id=i.document_id
   where i.id in (v_old_item.id,v_new_item.id)
 loop
   if v_row.purchase_mode not in ('NEW_CYLINDER','EMPTY_ONLY') then
     select greatest(0,coalesce(sum(m.delta_full+m.delta_empty),0))
       into v_owed from public.gas_stock_movements m
       where m.document_item_id=v_row.id;
     select coalesce(sum(quantity),0) into v_returned
       from public.gas_empty_returns where obligation_item_id=v_row.id;
     if v_owed<v_returned then
       raise exception 'Edit akan mengurangi kewajiban kosong di bawah jumlah yang sudah dikembalikan';
     end if;
     insert into public.gas_empty_obligations(document_item_id,supplier_id,owed_qty)
       values(v_row.id,v_row.partner_id,v_owed)
       on conflict(document_item_id) do update set owed_qty=excluded.owed_qty;
   end if;
 end loop;
 -- Recalculate document status without altering ordered quantities or finance data.
 for v_row in select id,quantity_full,quantity_empty,purchase_mode from public.gas_document_items
   where document_id=v_doc.id loop
   select coalesce(sum(delta_full),0),coalesce(sum(case when v_row.purchase_mode='EMPTY_ONLY' then delta_empty else -delta_empty end),0)
     into v_total_full,v_total_empty from public.gas_stock_movements
     where document_item_id=v_row.id;
   if v_total_full<v_row.quantity_full or v_total_empty<v_row.quantity_empty then
     v_complete:=false;
   end if;
 end loop;
 update public.gas_documents set
   status=case when v_complete then 'APPROVED'
          when exists(select 1 from public.gas_stock_movements m
              join public.gas_document_items i on i.id=m.document_item_id
              where i.document_id=v_doc.id and m.movement_key like 'RECEIPT-%')
            then 'PARTIAL' else 'DRAFT' end,
   approved_by=case when v_complete then auth.uid() else null end
   where id=v_doc.id;
 insert into gaspos_private.receipt_edit_history
 (request_id,document_id,actor_id,action,old_product_id,new_product_id,
 old_full,new_full,old_empty,new_empty)
 values(p_request,v_doc.id,auth.uid(),case when p_delete then 'DELETE' else 'EDIT' end,
 v_request.product_id,case when p_delete then null else v_new_product end,
 v_request.full_qty,case when p_delete then null else v_new_full end,
 v_request.empty_qty,case when p_delete then null else v_new_empty end);
end;
$function$;
