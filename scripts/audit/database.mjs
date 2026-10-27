import {PGlite} from '@electric-sql/pglite';
import fs from 'node:fs';
import assert from 'node:assert/strict';
const root=new URL('../../',import.meta.url);
const read=p=>fs.readFileSync(new URL(p,root),'utf8');
const db=new PGlite();await db.exec(read('scripts/audit/fixtures/baseline-schema.sql'));
await db.exec(read('scripts/audit/fixtures/baseline-policies.sql'));
await db.exec(read('scripts/audit/fixtures/baseline-integrity.sql'));
const results=[];
const signatureBaseline=[];
const q=async(sql,params=[])=> (await db.query(sql,params)).rows;
const scalar=async(sql,p=[])=>Object.values((await q(sql,p))[0])[0];
const uid=()=>crypto.randomUUID();
const ids=Object.fromEntries(['OWNER','LOGISTIK','SALES_SOPIR','KEUANGAN','INACTIVE','OUTSIDER','SECOND_DRIVER'].map(r=>[r,uid()]));
for(const [role,id] of Object.entries(ids)){await q('insert into auth.users(id) values($1)',[id]);if(role!=='OUTSIDER')await q('insert into gas_members(user_id,role,active) values($1,$2,$3)',[id,role==='INACTIVE'?'OWNER':role==='SECOND_DRIVER'?'SALES_SOPIR':role,role!=='INACTIVE']);}
const as=async role=>{await q("select set_config('request.jwt.claim.sub',$1,false)",[ids[role]]);};
const ok=(name,detail)=>results.push({name,status:'PASS',detail});
const reject=async(name,sql,p=[])=>{try{await q(sql,p);results.push({name,status:'FAIL',detail:'Operation accepted'});}catch(e){ok(name,e.message);}};
await as('OUTSIDER');await reject('Unregistered authenticated user cannot add expense',"select gaspos_add_operating_expense(current_date,'BBM','isolated test',1000)");
await as('INACTIVE');await reject('Inactive user cannot add expense',"select gaspos_add_operating_expense(current_date,'BBM','isolated test',1000)");
if(process.env.FIX==='1'){await db.exec(read('supabase/audit_access_and_receipts.sql'));await db.exec(read('supabase/audit_finance.sql'));}
await as('OUTSIDER');await reject('Retest unregistered user',"select gaspos_add_operating_expense(current_date,'BBM','isolated test',1000)");
await as('INACTIVE');await reject('Retest inactive user',"select gaspos_add_operating_expense(current_date,'BBM','isolated test',1000)");
await q('delete from gas_operating_expenses');
const product=uid(),supplier=uid(),customers=[uid(),uid(),uid()];
await q("insert into gas_products(id,name) values($1,'Isolated test cylinder')",[product]);
await q("insert into gas_partners(id,name,partner_type) values($1,'TEST supplier','SUPPLIER')",[supplier]);
for(let i=0;i<3;i++)await q("insert into gas_partners(id,name,partner_type) values($1,$2,'CUSTOMER')",[customers[i],'TEST '+i]);
await as('OWNER');
const purchase=await scalar("select gaspos_create_purchase($1,'Isolated audit',$2,'TEST',current_date,current_date,0,0)",[supplier,JSON.stringify([{product_id:product,quantity_full:100,quantity_empty:0,unit_price:17000,purchase_mode:'REFILL_NO_EXCHANGE'}])]);
const item=await scalar('select id from gas_document_items where document_id=$1',[purchase]);
await as('LOGISTIK');const receipt=process.env.FIX==='1'?await scalar("select gaspos_submit_purchase_receipt($1,$2,100,0,'Audit receipt')",[purchase,product]):await scalar("select gaspos_submit_logistics('IN',$1,$2,100,0,'Audit receipt')",[supplier,product]);
await as('OWNER');await q("select gaspos_review_logistics($1,true,'')",[receipt]);
await reject('Double ACC rejected',"select gaspos_review_logistics($1,true,'')",[receipt]);
const stock=async()=>q('select coalesce(sum(m.delta_full),0)::int full,coalesce(sum(m.delta_empty),0)::int empty from gas_stock_movements m join gas_document_items i on i.id=m.document_item_id where i.product_id=$1',[product]);
assert.equal((await stock())[0].full,100);ok('ACC receipt stock exactly 100');
const status=await scalar('select status from gas_documents where id=$1',[purchase]);
results.push({name:'Logistics receipt posts linked purchase/HPP',status:status==='APPROVED'?'PASS':'FAIL',detail:'Purchase status after ACC: '+status});
// Continue with existing Owner receipt RPC only after removing the isolated independent receipt movement.
if(status!=='APPROVED'){await q("delete from gas_stock_movements where movement_key=$1",['LOG-'+receipt]);
await q('select gaspos_receive_purchase($1,$2,$3)',[purchase,JSON.stringify([{item_id:item,quantity_full:100,quantity_empty:0}]),uid()]);
assert.equal((await stock())[0].full,100);}
await as('LOGISTIK');const dispatch=await scalar("select gaspos_submit_logistics('OUT',null,$1,60,0,'Isolated dispatch')",[product]);
await as('OWNER');await q("select gaspos_review_logistics($1,true,'')",[dispatch]);
await as('LOGISTIK');const trip=await scalar("select gaspos_start_trip($1,$2,'TEST 001')",[dispatch,ids.SALES_SOPIR]);
await as('SALES_SOPIR');await reject('Overload rejected','select gaspos_record_stop($1,$2,61,0,\'\')',[trip,customers[0]]);
await reject('Invalid customer rejected',"select gaspos_record_stop($1,$2,1,0,'')",[trip,uid()]);
const stops=[];for(const [i,full,empty] of [[0,20,15],[1,15,15],[2,10,8]])stops.push(await scalar("select gaspos_record_stop($1,$2,$3,$4,'')",[trip,customers[i],full,empty]));
await as('SECOND_DRIVER');await reject('Other driver cannot record stop',"select gaspos_record_stop($1,$2,1,0,'')",[trip,customers[0]]);await reject('Other driver cannot confirm stop',"select gaspos_confirm_stop_signed($1,'Other receiver',$2)",[stops[0],JSON.stringify([[[1,1],[2,2],[3,3]]])]);
await as('LOGISTIK');await reject('Unconfirmed return rejected','select gaspos_return_trip($1,15,38)',[trip]);
await as('SALES_SOPIR');
// Reproduce both old failures without changing fixture SQL or leaving a confirmed stop.
for(const [name,signature,shouldAccept] of [
 ['Single canvas stroke rejected by baseline',[[[1,1],[2,2],[3,3]]],true],
 ['Malformed flat coordinates accepted by baseline',[[1,1],[2,2]],false],
]){
 await db.exec('BEGIN');let accepted=false,error='';
 try{await q("select gaspos_confirm_stop_signed($1,'TEST receiver',$2)",[stops[0],JSON.stringify(signature)]);accepted=true;}catch(e){error=e.message;}
 await db.exec('ROLLBACK');
 signatureBaseline.push({name,reproduced:accepted!==shouldAccept,accepted,error});
 assert.notEqual(accepted,shouldAccept,'Expected original signature defect: '+name);
}
if(process.env.FIX==='1'){
 await db.exec(read('supabase/audit_signature.sql'));
 for(const [name,signature] of [
  ['Empty signature',[]],['Wrong nesting',[[1,1],[2,2]]],['Non-array stroke',[1]],
  ['Empty stroke',[[]]],['Scalar point',[[1,2,3]]],['Wrong point dimension',[[[1,2,3],[2,3],[3,4]]]],
  ['String coordinate',[[['1',1],[2,2],[3,3]]]],['Null coordinate',[[[null,1],[2,2],[3,3]]]],
  ['Nonfinite coordinate',[[['NaN',1],[2,2],[3,3]]]],['Negative coordinate',[[[-1,1],[2,2],[3,3]]]],
  ['X outside canvas',[[[321,1],[2,2],[3,3]]]],['Y outside canvas',[[[1,161],[2,2],[3,3]]]],
  ['Insufficient samples',[[[1,1],[2,2]]]],['Oversize signature',[Array.from({length:2000},()=>[320,160])]],
 ]) await reject('Signature rejects '+name,"select gaspos_confirm_stop_signed($1,'TEST receiver',$2)",[stops[0],JSON.stringify(signature)]);
 await reject('Signature rejects JSON null',"select gaspos_confirm_stop_signed($1,'TEST receiver','null'::jsonb)",[stops[0]]);
 await reject('Signature rejects SQL null',"select gaspos_confirm_stop_signed($1,'TEST receiver',null)",[stops[0]]);
 // A valid multi-stroke signature and inclusive canvas boundaries are supported too.
 await db.exec('BEGIN');await q("select gaspos_confirm_stop_signed($1,'TEST receiver',$2)",[stops[0],JSON.stringify([[[0,0],[320,160]],[[12.5,20.25]]])]);await db.exec('ROLLBACK');ok('Signature accepts multiple strokes and canvas bounds');
}
for(const stop of stops)await q("select gaspos_confirm_stop_signed($1,'TEST receiver',$2)",[stop,JSON.stringify(process.env.FIX==='1'?[[[1,1],[2,2],[3,3]]]:[[1,1],[2,2]])]);
if(process.env.FIX==='1')ok('Single-stroke signatures accepted for all three stops');
await as('LOGISTIK');await reject('Wrong return count rejected','select gaspos_return_trip($1,14,38)',[trip]);await q('select gaspos_return_trip($1,15,38)',[trip]);
assert.deepEqual((await stock())[0],{full:55,empty:38});ok('Return stock 55 full / 38 empty');
await as('OWNER');await reject('Invoice without valid stop rejected','select gaspos_invoice_trip_stop($1,18500,current_date,current_date)',[uid()]);const invoices=[];for(const stop of stops)invoices.push(await scalar('select gaspos_invoice_trip_stop($1,18500,current_date,current_date)',[stop]));
await reject('Duplicate invoice rejected','select gaspos_invoice_trip_stop($1,18500,current_date,current_date)',[stops[0]]);
assert.deepEqual((await stock())[0],{full:55,empty:38});ok('Invoice does not mutate stock');
await as('KEUANGAN');await reject('Finance cannot adjust stock',"select gaspos_adjust_stock($1,1,0,'audit',$2)",[product,uid()]);
await reject('Overpayment rejected','select gaspos_record_payment($1,370001)',[invoices[0]]);
await q('select gaspos_record_payment($1,100000)',[invoices[0]]);await q('select gaspos_record_payment($1,270000)',[invoices[0]]);
await q('select gaspos_record_payment($1,277500)',[invoices[1]]);await q('select gaspos_record_payment($1,185000)',[invoices[2]]);
await q('select gaspos_record_payment($1,1700000)',[purchase]);await q("select gaspos_add_operating_expense(current_date,'BBM','Isolated audit fuel',20000)");
const report=(await q('select * from gaspos_profit_loss_summary()'))[0];assert.equal(Number(report.revenue),832500);assert.equal(Number(report.hpp),765000);assert.equal(Number(report.gross_profit),67500);assert.equal(Number(report.net_profit),47500);ok('HPP and P&L',report);

await as('KEUANGAN');await reject('Customer refund above credit rejected','select gaspos_customer_refund($1,999999,$2)',[invoices[0],uid()]);
await reject('Supplier refund above credit rejected','select gaspos_record_supplier_refund($1,999999,$2)',[purchase,uid()]);
await as('OWNER');await reject('Correction after invoice rejected',"select gaspos_correct_stop($1,$2,20,15,'isolated correction')",[stops[0],customers[0]]);
await as('LOGISTIK');const tooMuch=await scalar("select gaspos_submit_logistics('OUT',null,$1,56,0,'negative stock test')",[product]);
await as('OWNER');await reject('Negative stock prevented',"select gaspos_review_logistics($1,true,'')",[tooMuch]);
if(process.env.FIX==='1'){
 const saleItem=await scalar('select id from gas_document_items where document_id=$1',[invoices[0]]);
 const priorProgress=(await q('select * from gaspos_sales_delivery_progress where item_id=$1',[saleItem]))[0];
 assert.equal(priorProgress.delivered_full,0);assert.equal(priorProgress.received_empty,0);
 await reject('Baseline trip invoice return defect reproduced',"select gaspos_return_sale_v2($1,1,0,'Baseline trip return',$2)",[saleItem,uid()]);
 await db.exec(read('supabase/audit_trip_invoice_returns.sql'));
 assert.ok((await scalar("select reloptions from pg_class where oid='public.gaspos_sales_delivery_progress'::regclass")).includes('security_invoker=true'));ok('Delivery progress view preserves security_invoker');
 const progress=(await q('select * from gaspos_sales_delivery_progress where item_id=$1',[saleItem]))[0];
 assert.equal(progress.delivered_full,20);assert.equal(progress.received_empty,15);ok('Trip delivery progress reflects verified 20 full / 15 empty');
 const owed=async()=>Number(await scalar('select owed_qty from gaspos_customer_empty_all_balances() where customer_id=$1 and product_id=$2',[customers[0],product]));
 const returnReject=async(name,sql,params=[])=>{await db.exec('SAVEPOINT return_negative');let accepted=false,message='';try{await q(sql,params);accepted=true;}catch(e){message=e.message;}await db.exec('ROLLBACK TO SAVEPOINT return_negative; RELEASE SAVEPOINT return_negative');assert.equal(accepted,false,name);ok(name,message);};
 for(const role of ['LOGISTIK','SALES_SOPIR','KEUANGAN','INACTIVE','OUTSIDER']){await as(role);await reject(role+' cannot return trip invoice',"select gaspos_return_sale_v2($1,1,0,'No permission return',$2)",[saleItem,uid()]);}
 await as('OWNER');
 // Every branch rolls back so the original 55/38 E2E fixture remains unchanged.
 await db.exec('BEGIN');
 await returnReject('Trip over-return rejected',"select gaspos_return_sale_v2($1,21,0,'Too many full',$2)",[saleItem,uid()]);
 await returnReject('Trip excessive empty reissue rejected',"select gaspos_return_sale_v2($1,16,16,'Too many empty',$2)",[saleItem,uid()]);
 const req=uid(),returned=await scalar("select gaspos_return_sale_v2($1,1,0,'One full returned',$2)",[saleItem,req]);
 assert.equal(await scalar("select gaspos_return_sale_v2($1,1,0,'One full returned',$2)",[saleItem,req]),returned);
 assert.equal(Number(await scalar('select count(*) from gas_sale_returns where sale_item_id=$1',[saleItem])),1);ok('Trip return request replay is idempotent');
 assert.deepEqual((await stock())[0],{full:56,empty:38});assert.equal(await owed(),4);ok('Trip return without empty: stock56/38, customer owes4');
 const returnProfit=(await q('select * from gaspos_profit_loss_summary()'))[0];
 assert.equal(Number(returnProfit.revenue),814000);assert.equal(Number(returnProfit.hpp),748000);assert.equal(Number(returnProfit.gross_profit),66000);assert.equal(Number(returnProfit.net_profit),46000);ok('Trip return P&L consistent',returnProfit);
 await as('KEUANGAN');await returnReject('Refund above trip return credit rejected','select gaspos_customer_refund($1,18501,$2)',[invoices[0],uid()]);
 await q('select gaspos_customer_refund($1,18500,$2)',[invoices[0],uid()]);
 const refunded=(await q('select document_total,paid_total from gaspos_trade_balances where id=$1',[invoices[0]]))[0];
 assert.equal(Number(refunded.document_total),351500);assert.equal(Number(refunded.paid_total),351500);ok('Valid finance refund18500 clears trip return credit');
 await returnReject('Second refund exceeds remaining credit','select gaspos_customer_refund($1,1,$2)',[invoices[0],uid()]);
 await db.exec('ROLLBACK');await as('OWNER');
 await db.exec('BEGIN');await q("select gaspos_return_sale_v2($1,1,1,'Full plus empty return',$2)",[saleItem,uid()]);
 assert.deepEqual((await stock())[0],{full:56,empty:37});assert.equal(await owed(),5);ok('Trip return with empty: stock56/37, customer still owes5');await db.exec('ROLLBACK');
 await db.exec('BEGIN');await q("select gaspos_return_sale($1,1,'Old RPC compatible',$2)",[saleItem,uid()]);assert.deepEqual((await stock())[0],{full:56,empty:38});assert.equal(await owed(),4);ok('Old sale-return RPC delegates safely');await db.exec('ROLLBACK');
 // Invalid provenance must not fall back to an unrelated SALE stock event.
 for(const [name,sql,params] of [
 ['mismatched customer','update gas_documents set partner_id=$1 where id=$2',[customers[1],invoices[0]]],
 ['mismatched full quantity','update gas_document_items set quantity_full=19 where id=$1',[saleItem]],
 ['mismatched empty quantity','update gas_document_items set quantity_empty=14 where id=$1',[saleItem]],
 ['unreconciled trip',"update gas_trips set status='ON_ROUTE' where id=$1",[trip]],
 ['unconfirmed receiver','update gas_trip_stops set receiver_confirmed=false where id=$1',[stops[0]]],
 ]){await db.exec('BEGIN');await q(sql,params);await returnReject('Return rejects '+name,"select gaspos_return_sale_v2($1,1,0,'Invalid provenance',$2)",[saleItem,uid()]);await db.exec('ROLLBACK');}
 await db.exec('BEGIN');const otherProduct=uid();await q("insert into gas_products(id,name) values($1,'Other isolated product')",[otherProduct]);await q('update gas_document_items set product_id=$1 where id=$2',[otherProduct,saleItem]);await returnReject('Return rejects mismatched product',"select gaspos_return_sale_v2($1,1,0,'Invalid provenance',$2)",[saleItem,uid()]);await db.exec('ROLLBACK');
 await db.exec('BEGIN');await q("insert into gas_stock_movements(document_item_id,movement_key,delta_full,delta_empty) values($1,'Isolated duplicate provenance',-20,15)",[saleItem]);
 assert.equal(Number(await scalar('select delivered_full from gaspos_sales_delivery_progress where item_id=$1',[saleItem])),20);await returnReject('Mixed trip+SALE provenance cannot double return',"select gaspos_return_sale_v2($1,21,0,'No double counting',$2)",[saleItem,uid()]);await db.exec('ROLLBACK');
 await db.exec('BEGIN');await q("select gaspos_adjust_stock($1,0,-38,'Empty stock deficit test',$2)",[product,uid()]);await returnReject('Trip return prevents negative empty stock',"select gaspos_return_sale_v2($1,1,1,'No empty stock left',$2)",[saleItem,uid()]);await db.exec('ROLLBACK');
 await db.exec('BEGIN');
 const direct=await scalar("select gaspos_create_sale($1,'Direct sale regression',$2,current_date,current_date,'Test receiver')",[customers[0],JSON.stringify([{product_id:product,quantity_full:2,quantity_empty:1,unit_price:18500,sale_mode:'EXCHANGE'}])]);
 const directItem=await scalar('select id from gas_document_items where document_id=$1',[direct]);
 await q('select gaspos_deliver_sale($1,$2,$3)',[direct,JSON.stringify([{item_id:directItem,quantity_full:2,quantity_empty:1}]),uid()]);
 assert.equal(Number(await scalar('select delivered_full from gaspos_sales_delivery_progress where item_id=$1',[directItem])),2);assert.equal(await owed(),6);
 await q("select gaspos_return_sale_v2($1,1,1,'Direct full plus empty',$2)",[directItem,uid()]);assert.equal(await owed(),6);
 await q("select gaspos_return_sale($1,1,'Direct full without empty',$2)",[directItem,uid()]);assert.equal(await owed(),5);assert.deepEqual((await stock())[0],{full:55,empty:38});
 await returnReject('Direct sale over-return still rejected',"select gaspos_return_sale_v2($1,1,0,'Too much direct return',$2)",[directItem,uid()]);ok('Direct-sale return and legacy empty balance preserved');await db.exec('ROLLBACK');
 await db.exec('BEGIN');
 const creditSale=await scalar("select gaspos_create_sale($1,'Signed empty credit regression',$2,current_date,current_date,'Test receiver')",[customers[0],JSON.stringify([{product_id:product,quantity_full:2,quantity_empty:1,unit_price:18500,sale_mode:'EXCHANGE'}])]);
 const creditItem=await scalar('select id from gas_document_items where document_id=$1',[creditSale]);await q('select gaspos_deliver_sale($1,$2,$3)',[creditSale,JSON.stringify([{item_id:creditItem,quantity_full:2,quantity_empty:1}]),uid()]);
 await q("select gaspos_return_sale_v2($1,2,0,'Full return keeps signed empty credit',$2)",[creditItem,uid()]);assert.equal(await owed(),4);assert.deepEqual((await stock())[0],{full:55,empty:39});ok('Legacy return preserves signed customer empty credit');await db.exec('ROLLBACK');
 await db.exec('BEGIN');await as('LOGISTIK');
 const groupedDispatch=await scalar("select gaspos_submit_logistics('OUT',null,$1,4,0,'Grouped invoice regression')",[product]);
 await as('OWNER');await q("select gaspos_review_logistics($1,true,'')",[groupedDispatch]);await as('LOGISTIK');
 const groupedTrip=await scalar("select gaspos_start_trip($1,$2,'TEST GROUP')",[groupedDispatch,ids.SALES_SOPIR]);await as('SALES_SOPIR');
 for(const empty of [0,1]){const stop=await scalar("select gaspos_record_stop($1,$2,1,$3,'Grouped same customer')",[groupedTrip,customers[0],empty]);await q("select gaspos_confirm_stop_signed($1,'TEST receiver',$2)",[stop,JSON.stringify([[[1,1],[2,2],[3,3]]])]);}
 await as('LOGISTIK');await q('select gaspos_return_trip($1,2,1)',[groupedTrip]);await as('OWNER');
 const groupedInvoice=await scalar('select gaspos_invoice_trip_customer($1,$2,18500,current_date,current_date)',[groupedTrip,customers[0]]);
 const groupedItem=await scalar('select id from gas_document_items where document_id=$1',[groupedInvoice]);
 const groupedProgress=(await q('select delivered_full,received_empty from gaspos_sales_delivery_progress where item_id=$1',[groupedItem]))[0];assert.deepEqual(groupedProgress,{delivered_full:2,received_empty:1});assert.equal(await owed(),6);
 await q("select gaspos_return_sale_v2($1,1,0,'Grouped one full return',$2)",[groupedItem,uid()]);assert.equal(await owed(),5);assert.deepEqual((await stock())[0],{full:54,empty:39});ok('Grouped same-customer invoice return counted once across two stops');await db.exec('ROLLBACK');await as('OWNER');
 assert.deepEqual((await stock())[0],{full:55,empty:38});assert.equal(await owed(),5);ok('Rollback restores original stock55/38 and customer obligation5');
}
await db.exec('GRANT USAGE ON SCHEMA public,auth,gaspos_private TO authenticated; GRANT SELECT ON ALL TABLES IN SCHEMA public TO authenticated;');
for(const t of ['gas_members','gas_logistics_requests','gas_trips','gas_trip_stops','gas_financial_entries','gas_payments','gas_products','gas_partners'])await db.exec('ALTER TABLE '+t+' ENABLE ROW LEVEL SECURITY');
await as('SALES_SOPIR');await db.exec('SET ROLE authenticated');
assert.equal(Number(await scalar('select count(*) from gas_logistics_requests where id=$1',[dispatch])),1);ok('Driver sees assigned SJ through RLS');
assert.equal(Number(await scalar('select count(*) from gas_financial_entries')),0);ok('Driver cannot select prices');
await db.exec('RESET ROLE');await as('SECOND_DRIVER');await db.exec('SET ROLE authenticated');assert.equal(Number(await scalar('select count(*) from gas_logistics_requests where id=$1',[dispatch])),0);ok('Other driver cannot select SJ');await db.exec('RESET ROLE');await as('LOGISTIK');await db.exec('SET ROLE authenticated');
assert.equal(Number(await scalar('select count(*) from gas_financial_entries')),0);ok('Logistics cannot select prices');
await db.exec('RESET ROLE');await as('OUTSIDER');await db.exec('SET ROLE authenticated');
assert.equal(Number(await scalar('select count(*) from gas_trips')),0);ok('Unregistered member cannot see trips');await db.exec('RESET ROLE');

console.log(JSON.stringify({environment:'Isolated local PGlite PostgreSQL; no production data; auth.uid simulated, not login test',baseline_reproductions:results.slice(0,2),signature_baseline_reproductions:signatureBaseline,results:results.slice(2),stock:(await stock())[0]},null,2));
await db.close();
if(process.env.FIX==='1')assert.equal(results.slice(2).filter(x=>x.status==='FAIL').length,0,'Regression failures');
