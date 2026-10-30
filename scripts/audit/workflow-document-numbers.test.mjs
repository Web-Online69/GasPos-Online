import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import {PGlite} from '@electric-sql/pglite';
const read=p=>fs.readFileSync(new URL('../../'+p,import.meta.url),'utf8');
test('Short document labels backfill every type without changing technical IDs or financial data',async()=>{
 const db=new PGlite();const q=async(s,p=[])=> (await db.query(s,p)).rows;const scalar=async(s,p=[])=>Object.values((await q(s,p))[0])[0];
 try{
 await db.exec(read('scripts/audit/fixtures/baseline-schema.sql'));await db.exec(read('scripts/audit/fixtures/baseline-policies.sql'));await db.exec(read('scripts/audit/fixtures/baseline-integrity.sql'));
 await db.exec(read('supabase/audit_access_and_receipts.sql'));await db.exec(read('supabase/audit_finance.sql'));
 const user=crypto.randomUUID();await q('insert into auth.users(id) values($1)',[user]);await q("insert into gas_members(user_id,role,active)values($1,'OWNER',true)",[user]);await q("select set_config('request.jwt.claim.sub',$1,false)",[user]);
 const product=await scalar("insert into gas_products(name)values('Test')returning id");const customer=await scalar("insert into gas_partners(name,partner_type)values('Test','CUSTOMER')returning id");
 const old=[];for(const type of ['SALE','PURCHASE','DISPATCH','RECEIPT','EMPTY_RETURN','STOCK_ADJUSTMENT'])old.push((await q('insert into gas_documents(document_no,document_type,status)values($1,$2,\'APPROVED\')returning id,document_no',[type+'-very-long-technical-reference',type]))[0]);
 const request=await scalar("insert into gas_logistics_requests(direction,product_id,full_qty,created_by,document_id,status)values('OUT',$1,2,$2,$3,'APPROVED')returning id",[product,user,old[2].id]);
 const trip=await scalar("insert into gas_trips(request_id,driver_user_id,vehicle_plate)values($1,$2,'TEST')returning id",[request,user]);
 const stop=await scalar("insert into gas_trip_stops(trip_id,customer_id,full_qty,empty_qty,created_by,receiver_confirmed,receiver_name,receiver_signature)values($1,$2,1,1,$3,true,'TEST','[[[1,1],[2,2],[3,3]]]')returning id",[trip,customer,user]);
 const signature=await scalar('select receiver_signature from gas_trip_stops where id=$1',[stop]);
 await db.exec('begin;'+read('supabase/audit_short_document_numbers.sql')+'commit;');
 const docs=await q('select id,document_no,display_no,document_type from gas_documents order by document_type');for(const d of docs){assert.equal(d.document_no,old.find(x=>x.id===d.id).document_no);assert.match(d.display_no,/^[A-Z]+ \d{5}$/);}
 assert.equal(await scalar('select display_no from gas_documents where id=$1',[old[0].id]),'INV 00001');assert.equal(await scalar('select display_no from gas_documents where id=$1',[old[1].id]),'BEL 00001');
 assert.equal(await scalar('select display_no from gas_logistics_requests where id=$1',[request]),await scalar('select display_no from gas_documents where id=$1',[old[2].id]));assert.equal(await scalar('select display_no from gas_trip_stops where id=$1',[stop]),'FK 00001');assert.deepEqual(await scalar('select receiver_signature from gas_trip_stops where id=$1',[stop]),signature);
 const labels=await Promise.all(Array.from({length:20},(_,i)=>scalar("insert into gas_documents(document_no,document_type,display_no)values($1,'SALE','INV 00001')returning display_no",['NEW-'+i])));assert.equal(new Set(labels).size,20);assert.ok(labels.includes('INV 00002'));assert.ok(labels.includes('INV 00021'));
 await assert.rejects(q("update gas_documents set display_no='INV 12345' where id=$1",[old[0].id]),/tidak dapat diubah/);
 const pending=(await q("insert into gas_logistics_requests(direction,product_id,full_qty,created_by)values('OUT',$1,1,$2)returning id,display_no",[product,user]))[0];
 const linked=(await q("insert into gas_documents(document_no,document_type)values($1,'DISPATCH')returning id,display_no",['LOG-'+pending.id]))[0];assert.equal(linked.display_no,pending.display_no);await q('update gas_logistics_requests set document_id=$1 where id=$2',[linked.id,pending.id]);
 const arrival=await scalar("insert into gas_logistics_requests(direction,product_id,full_qty,created_by,document_id)values('IN',$1,1,$2,$3)returning display_no",[product,user,old[1].id]);assert.match(arrival,/^TBM /);
 for(const [prefix,technical]of [['RETJ','SR-return'],['RETB','PR-return']])assert.match(await scalar("insert into gas_documents(document_no,document_type)values($1,'STOCK_ADJUSTMENT')returning display_no",[technical]),new RegExp('^'+prefix+' '));
 await assert.rejects(q("update gas_documents set document_type='PURCHASE' where id=$1",[old[0].id]),/tidak dapat diubah/);
 const before=await q('select id,display_no from gas_documents order by id');await db.exec('begin;'+read('supabase/audit_short_document_numbers.sql')+'commit;');assert.deepEqual(await q('select id,display_no from gas_documents order by id'),before);
 assert.equal(await scalar("select document_no from gaspos_trade_balances where id=$1",[old[0].id]),'INV 00001');
 assert.equal(await scalar("select has_function_privilege('authenticated','gaspos_private.next_document_label(text)','execute')"),false);assert.equal(await scalar("select has_table_privilege('authenticated','gaspos_private.document_number_counters','select')"),false);
 await q("update gaspos_private.document_number_counters set value=99999 where prefix='INV'");assert.equal(await scalar("insert into gas_documents(document_no,document_type)values('LARGE','SALE')returning display_no"),'INV 100000');
 for(const role of ['LOGISTIK','SALES_SOPIR']){await q('update gas_members set role=$1 where user_id=$2',[role,user]);assert.equal(Number(await scalar('select count(*) from gaspos_trade_balances')),0);}
 }catch(error){throw new Error(error.message)}finally{await db.close();}
});
