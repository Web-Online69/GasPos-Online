import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import {PGlite} from '@electric-sql/pglite';

const migration=fs.readFileSync(new URL('../../supabase/allow_multiple_purchase_receipts_per_document.sql',import.meta.url),'utf8');

test('A purchase supports two product receipts, while outbound document IDs stay unique',async()=>{
 const db=new PGlite();
 try{
  await db.exec(`
   create schema auth;
   create table public.gas_documents(id uuid primary key);
   create table public.gas_logistics_requests(
     id uuid primary key,
     direction text not null check(direction in ('IN','OUT')),
     document_id uuid references public.gas_documents(id),
     purchase_document_id uuid references public.gas_documents(id)
   );
   alter table public.gas_logistics_requests
     add constraint gas_logistics_requests_document_id_key unique(document_id);
  `);
  const purchase='00000000-0000-4000-8000-000000000001';
  const dispatch='00000000-0000-4000-8000-000000000002';
  await db.query('insert into public.gas_documents(id) values ($1),($2)',[purchase,dispatch]);
  await db.query("insert into public.gas_logistics_requests(id,direction,document_id,purchase_document_id) values ($1,'IN',$2,$2)",['00000000-0000-4000-8000-000000000011',purchase]);
  await assert.rejects(db.query("insert into public.gas_logistics_requests(id,direction,document_id,purchase_document_id) values ($1,'IN',$2,$2)",['00000000-0000-4000-8000-000000000012',purchase]),/duplicate key value/);
  await db.exec(migration);
  await db.query("insert into public.gas_logistics_requests(id,direction,document_id,purchase_document_id) values ($1,'IN',$2,$2)",['00000000-0000-4000-8000-000000000012',purchase]);
  const receipts=await db.query("select count(*)::int count from public.gas_logistics_requests where direction='IN' and purchase_document_id=$1",[purchase]);
  assert.equal(receipts.rows[0].count,2);
  await db.query("insert into public.gas_logistics_requests(id,direction,document_id) values ($1,'OUT',$2)",['00000000-0000-4000-8000-000000000021',dispatch]);
  await assert.rejects(db.query("insert into public.gas_logistics_requests(id,direction,document_id) values ($1,'OUT',$2)",['00000000-0000-4000-8000-000000000022',dispatch]),/duplicate key value/);
  const count=await db.query('select count(*)::int count from public.gas_logistics_requests');
  assert.equal(count.rows[0].count,3,'Rejected outbound should not create an extra request');
 }finally{await db.close()}
});

test('Regression: empty-only purchases must add empty stock and never charge against full quantity',()=>{
 const purchase=fs.readFileSync(new URL('../../supabase/purchase_empty_cylinders_mode.sql',import.meta.url),'utf8');
 assert.match(purchase,/case when v\.purchase_mode='EMPTY_ONLY' then v_empty else -v_empty end/);
 assert.match(purchase,/case when coalesce\(v_item->>'purchase_mode','EXCHANGE'\)='EMPTY_ONLY' then v_empty else v_qty end/);
 assert.match(purchase,/v_mode='EMPTY_ONLY' and \(v_qty<>0 or v_empty<1\)/);
 assert.match(purchase,/gaspos_private\.receive_purchase/);
});
