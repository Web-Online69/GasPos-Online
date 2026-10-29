import {PGlite} from '@electric-sql/pglite';
import fs from 'node:fs';
import assert from 'node:assert/strict';
const root=new URL('../../',import.meta.url),read=p=>fs.readFileSync(new URL(p,root),'utf8');
const db=new PGlite(),results=[];
await db.exec(read('scripts/audit/fixtures/baseline-schema.sql'));
await db.exec(read('scripts/audit/fixtures/baseline-policies.sql'));
await db.exec(read('scripts/audit/fixtures/baseline-integrity.sql'));
await db.exec('GRANT USAGE ON SCHEMA public,auth,gaspos_private TO authenticated; GRANT ALL ON ALL TABLES IN SCHEMA public TO authenticated;');
for(const p of ['audit_access_and_receipts.sql','audit_finance.sql','audit_signature.sql','audit_trip_invoice_returns.sql','audit_ledger_rpc_only.sql','simple_role_workflow.sql','audit_finance_partner_names.sql','audit_payment_retry.sql','audit_logistics_shared_read.sql','audit_form_retry.sql'])await db.exec(read('supabase/'+p));
const q=async(sql,p=[])=> (await db.query(sql,p)).rows;
const scalar=async(sql,p=[])=>Object.values((await q(sql,p))[0])[0];
const pass=(test,detail)=>results.push({test,status:'PASS',detail});
const denied=async(test,sql,p=[])=>{try{await q(sql,p);}catch(e){pass(test,e.message);return;}throw Error(test+' unexpectedly accepted');};
const deniedInTransaction=async(test,sql,p=[])=>{await db.exec('SAVEPOINT expected_rejection');try{await q(sql,p);}catch(e){await db.exec('ROLLBACK TO SAVEPOINT expected_rejection');await db.exec('RELEASE SAVEPOINT expected_rejection');pass(test,e.message);return;}await db.exec('RELEASE SAVEPOINT expected_rejection');throw Error(test+' unexpectedly accepted');};
const ids=Object.fromEntries(['OWNER','LOGISTIK','SALES_SOPIR','KEUANGAN'].map(role=>[role,crypto.randomUUID()]));
for(const [role,id] of Object.entries(ids)){await q('insert into auth.users(id) values($1)',[id]);await q('insert into gas_members(user_id,role,active) values($1,$2,true)',[id,role]);}
const reliefLogistics=crypto.randomUUID(),unassignedDriver=crypto.randomUUID();for(const [user,role] of [[reliefLogistics,'LOGISTIK'],[unassignedDriver,'SALES_SOPIR']]){await q('insert into auth.users(id) values($1)',[user]);await q('insert into gas_members(user_id,role,active) values($1,$2,true)',[user,role]);}
const product=crypto.randomUUID(),supplier=crypto.randomUUID(),customers=[crypto.randomUUID(),crypto.randomUUID(),crypto.randomUUID()];
await q("insert into gas_products(id,name) values($1,'SIMPLE FLOW TEST')",[product]);
await q("insert into gas_partners(id,name,partner_type) values($1,'TEST supplier','SUPPLIER')",[supplier]);
for(const [i,id] of customers.entries())await q("insert into gas_partners(id,name,partner_type) values($1,$2,'CUSTOMER')",[id,'TEST customer '+i]);
for(const row of await q("select tablename from pg_tables where schemaname='public'"))await db.exec('alter table public.'+row.tablename+' enable row level security');
await db.exec('SET ROLE authenticated');
const as=async role=>q("select set_config('request.jwt.claim.sub',$1,false)",[ids[role]]);
await as('OWNER');
const purchase=await scalar("select gaspos_create_purchase($1,'test',$2,'',current_date,null,0,0)",[supplier,JSON.stringify([{product_id:product,quantity_full:100,quantity_empty:0,unit_price:17000,purchase_mode:'REFILL_NO_EXCHANGE'}])]);pass('Owner membuat pembelian');
await as('LOGISTIK');
const receipt=crypto.randomUUID();
assert.equal(await scalar("select gaspos_confirm_purchase_arrival($1,$2,100,0,'test',$3)",[purchase,product,receipt]),purchase);
assert.equal(await scalar("select gaspos_confirm_purchase_arrival($1,$2,100,0,'test',$3)",[purchase,product,receipt]),purchase);pass('Logistik konfirmasi datang sekali tanpa ACC Owner; replay aman');
await denied('Penerimaan kedua melebihi pesanan ditolak',"select gaspos_confirm_purchase_arrival($1,$2,1,0,'test',$3)",[purchase,product,crypto.randomUUID()]);
const stock=async()=> (await q('select full_balance,empty_balance from gaspos_logistics_balances() where product_id=$1',[product]))[0];
assert.deepEqual(await stock(),{full_balance:100,empty_balance:0});pass('Stok setelah datang 100/0');
const sj=crypto.randomUUID();
assert.equal(await scalar("select gaspos_create_delivery_sj($1,60,$2,'trial 001','test',$3)",[product,ids.SALES_SOPIR,sj]),sj);
assert.equal(await scalar("select gaspos_create_delivery_sj($1,60,$2,'trial 001','test',$3)",[product,ids.SALES_SOPIR,sj]),sj);
assert.deepEqual(await stock(),{full_balance:40,empty_balance:0});pass('Logistik membuat SJ + muatan + Sopir + kendaraan satu langkah; replay tidak mengurangi stok lagi');
await denied('ID SJ sama dengan muatan berbeda ditolak',"select gaspos_create_delivery_sj($1,59,$2,'trial 001','test',$3)",[product,ids.SALES_SOPIR,sj]);
const trip=await scalar('select id from gas_trips where request_id=$1',[sj]);
await q("select set_config('request.jwt.claim.sub',$1,false)",[reliefLogistics]);
assert.equal(Number(await scalar('select count(*) from gas_logistics_requests where id=$1',[sj])),1);
assert.equal(Number(await scalar('select full_qty from gas_logistics_requests where id=$1',[sj])),60);
assert.equal(Number(await scalar('select count(*) from gas_trips where id=$1',[trip])),1);pass('Petugas Logistik pengganti membaca SJ dan muatan untuk rekonsiliasi bersama');
assert.equal(Number(await scalar('select count(*) from gas_financial_entries')),0);pass('Akses gudang bersama tidak membuka harga ke Logistik');
await q("select set_config('request.jwt.claim.sub',$1,false)",[unassignedDriver]);
assert.equal(Number(await scalar('select count(*) from gas_logistics_requests where id=$1',[sj])),0);
assert.equal(Number(await scalar('select count(*) from gas_trips where id=$1',[trip])),0);pass('Sopir lain tetap tidak membaca SJ/perjalanan yang tidak ditugaskan');
await as('KEUANGAN');assert.equal(Number(await scalar('select count(*) from gas_logistics_requests where id=$1',[sj])),0);pass('Keuangan tetap tidak memiliki akses dokumen gudang');
await as('LOGISTIK');

await as('KEUANGAN');await denied('Keuangan tidak membuat SJ',"select gaspos_create_delivery_sj($1,1,$2,'trial 001','test',$3)",[product,ids.SALES_SOPIR,crypto.randomUUID()]);
await as('SALES_SOPIR');await denied('Sopir tidak mengonfirmasi pembelian',"select gaspos_confirm_purchase_arrival($1,$2,1,0,'test',$3)",[purchase,product,crypto.randomUUID()]);
await denied('Sopir tidak mengirim di atas muatan',"select gaspos_record_stop($1,$2,61,0,'test')",[trip,customers[0]]);
// Lost-response delivery retries must never reserve the customer's goods twice.
await db.exec('BEGIN');
await q("select gaspos_record_stop($1,$2,1,0,'retry baseline')",[trip,customers[0]]);await q("select gaspos_record_stop($1,$2,1,0,'retry baseline')",[trip,customers[0]]);
assert.equal(Number(await scalar('select sum(full_qty) from gas_trip_stops where trip_id=$1',[trip])),2);pass('Baseline reproduces duplicate delivery on an old form retry');await db.exec('ROLLBACK');await as('SALES_SOPIR');
await db.exec('BEGIN');const stopRequest=crypto.randomUUID();
const onceStop=await scalar("select gaspos_record_stop_once($1,$2,1,0,'retry test',$3)",[trip,customers[0],stopRequest]);
assert.equal(await scalar("select gaspos_record_stop_once($1,$2,1,0,'retry test',$3)",[trip,customers[0],stopRequest]),onceStop);
assert.equal(Number(await scalar('select sum(full_qty) from gas_trip_stops where trip_id=$1',[trip])),1);pass('Driver retry returns same Faktur ID and reserves one quantity only');
for(const [test,sql,args] of [
 ['Delivery key rejects changed full quantity',"select gaspos_record_stop_once($1,$2,2,0,'retry test',$3)",[trip,customers[0],stopRequest]],
 ['Delivery key rejects changed empty quantity',"select gaspos_record_stop_once($1,$2,1,1,'retry test',$3)",[trip,customers[0],stopRequest]],
 ['Delivery key rejects changed customer',"select gaspos_record_stop_once($1,$2,1,0,'retry test',$3)",[trip,customers[1],stopRequest]],
 ['Delivery key rejects changed notes',"select gaspos_record_stop_once($1,$2,1,0,'changed',$3)",[trip,customers[0],stopRequest]],
 ['Delivery key is required',"select gaspos_record_stop_once($1,$2,1,0,'retry test',null)",[trip,customers[0]]],
 ['Retry procedure still rejects excessive load',"select gaspos_record_stop_once($1,$2,60,0,'retry test',$3)",[trip,customers[0],crypto.randomUUID()]],
 ['Retry procedure rejects invalid customer',"select gaspos_record_stop_once($1,$2,1,0,'retry test',$3)",[trip,supplier,crypto.randomUUID()]],
])await deniedInTransaction(test,sql,args);
await as('OWNER');await deniedInTransaction('Delivery replay rejects different submitting staff',"select gaspos_record_stop_once($1,$2,1,0,'retry test',$3)",[trip,customers[0],stopRequest]);
for(const role of ['LOGISTIK','KEUANGAN']){await as(role);await deniedInTransaction(role+' cannot record a driver delivery',"select gaspos_record_stop_once($1,$2,1,0,'retry test',$3)",[trip,customers[0],crypto.randomUUID()]);}
await q("select set_config('request.jwt.claim.sub',$1,false)",[unassignedDriver]);await deniedInTransaction('Unassigned driver cannot replay another driver request',"select gaspos_record_stop_once($1,$2,1,0,'retry test',$3)",[trip,customers[0],stopRequest]);
await as('SALES_SOPIR');await q("select gaspos_confirm_stop_signed($1,'TEST retry receiver',$2)",[onceStop,JSON.stringify([[[1,1],[2,2],[3,3]]])]);
await as('LOGISTIK');await q('select gaspos_return_trip($1,59,0)',[trip]);
await as('SALES_SOPIR');assert.equal(await scalar("select gaspos_record_stop_once($1,$2,1,0,'retry test',$3)",[trip,customers[0],stopRequest]),onceStop);pass('Known delivery replay after closing acknowledges old result without new posting');
await deniedInTransaction('New delivery after closing remains rejected',"select gaspos_record_stop_once($1,$2,1,0,'retry test',$3)",[trip,customers[0],crypto.randomUUID()]);
await db.exec('ROLLBACK');await as('SALES_SOPIR');
const stops=[];
for(const [i,full,empty] of [[0,20,15],[1,15,15],[2,10,8]]){
 const stop=await scalar("select gaspos_record_stop_once($1,$2,$3,$4,'Faktur barang tanpa harga',$5)",[trip,customers[i],full,empty,crypto.randomUUID()]);stops.push(stop);
 await q('select gaspos_confirm_stop_signed($1,$2,$3)',[stop,'TEST receiver '+i,JSON.stringify([[[10,10],[20,20],[30,10]]])]);
}
assert.equal(Number(await scalar('select count(*) from gas_financial_entries')),0);pass('Sopir membuat 3 faktur barang; harga tidak terbaca');
await denied('Sopir tidak menentukan tagihan','select gaspos_invoice_trip_stop($1,18500,current_date,null)',[stops[0]]);
await as('OWNER');
assert.equal(await scalar('select status from gas_trips where id=$1',[trip]),'ON_ROUTE');
const invoices=[];for(const stop of stops)invoices.push(await scalar('select gaspos_invoice_trip_stop($1,18500,current_date,null)',[stop]));
assert.deepEqual(await stock(),{full_balance:40,empty_balance:0});pass('Owner konfirmasi faktur dan tetapkan harga sebelum kendaraan pulang; invoice tidak mutasi stok');
await denied('Invoice ganda ditolak','select gaspos_invoice_trip_stop($1,18500,current_date,null)',[stops[0]]);
const debt=await q('select customer_id,owed_qty from gaspos_customer_empty_all_balances() where product_id=$1',[product]);
assert.deepEqual(customers.map(id=>Number(debt.find(x=>x.customer_id===id).owed_qty)),[5,0,2]);pass('Saldo kosong A5/B0/C2 tersedia saat faktur dikonfirmasi');
await as('KEUANGAN');
// Reproduce the previous lost-response retry defect without retaining its payments.
await db.exec('BEGIN');
await q('select gaspos_record_payment($1,100000)',[invoices[0]]);await q('select gaspos_record_payment($1,100000)',[invoices[0]]);
assert.equal(Number(await scalar('select paid_total from gaspos_trade_balances where id=$1',[invoices[0]])),200000);pass('Baseline reproduces duplicate partial payment when an old client retries');await db.exec('ROLLBACK');await as('KEUANGAN');
await db.exec('BEGIN');const payRequest=crypto.randomUUID();
const payId=await scalar('select gaspos_record_payment_once($1,100000,$2)',[invoices[0],payRequest]);
assert.equal(await scalar('select gaspos_record_payment_once($1,100000,$2)',[invoices[0],payRequest]),payId);
assert.equal(Number(await scalar('select paid_total from gaspos_trade_balances where id=$1',[invoices[0]])),100000);pass('Payment retry returns same ID and posts once');
assert.equal(await scalar('select created_by from gas_payments where id=$1',[payId]),ids.KEUANGAN);pass('Payment records the submitting staff account');
await deniedInTransaction('Payment retry rejects a changed amount','select gaspos_record_payment_once($1,99999,$2)',[invoices[0],payRequest]);
await deniedInTransaction('Payment retry rejects a changed invoice','select gaspos_record_payment_once($1,100000,$2)',[invoices[1],payRequest]);
await deniedInTransaction('Payment request key is required','select gaspos_record_payment_once($1,100000,null)',[invoices[0]]);
await as('OWNER');await deniedInTransaction('Payment retry rejects a different submitting staff account','select gaspos_record_payment_once($1,100000,$2)',[invoices[0],payRequest]);
await as('LOGISTIK');await deniedInTransaction('Logistics cannot record a payment','select gaspos_record_payment_once($1,100000,$2)',[invoices[0],crypto.randomUUID()]);
await as('SALES_SOPIR');await deniedInTransaction('Driver cannot record a payment','select gaspos_record_payment_once($1,100000,$2)',[invoices[0],crypto.randomUUID()]);
await as('KEUANGAN');await q('select gaspos_record_payment_once($1,100000,$2)',[invoices[0],crypto.randomUUID()]);
assert.equal(Number(await scalar('select paid_total from gaspos_trade_balances where id=$1',[invoices[0]])),200000);pass('A distinct intentional payment with the same amount remains allowed');
await deniedInTransaction('Idempotent payment still rejects overpayment','select gaspos_record_payment_once($1,170001,$2)',[invoices[0],crypto.randomUUID()]);
await db.exec('ROLLBACK');await as('KEUANGAN');
await q('select gaspos_record_payment_once($1,100000,$2)',[invoices[0],crypto.randomUUID()]);await q('select gaspos_record_payment_once($1,270000,$2)',[invoices[0],crypto.randomUUID()]);
await q('select gaspos_record_payment_once($1,277500,$2)',[invoices[1],crypto.randomUUID()]);await q('select gaspos_record_payment_once($1,185000,$2)',[invoices[2],crypto.randomUUID()]);
await q('select gaspos_record_payment_once($1,1700000,$2)',[purchase,crypto.randomUUID()]);
const fuelRequest=crypto.randomUUID(),fuel=await scalar("select gaspos_add_operating_expense_once(current_date,'BBM','E2E fuel',20000,$1)",[fuelRequest]);
assert.equal(await scalar("select gaspos_add_operating_expense_once(current_date,'BBM','E2E fuel',20000,$1)",[fuelRequest]),fuel);pass('Keuangan membayar supplier dan biayaBBM20000 sekali walau retry');
await denied('Uang masuk melebihi tagihan ditolak','select gaspos_record_payment($1,1)',[invoices[0]]);pass('Keuangan konfirmasi uang masuk parsial dan lunas');
const balance=await q('select document_total,paid_total from gaspos_trade_balances where id=any($1::uuid[])',[[...invoices,purchase]]);assert.equal(balance.length,4);for(const row of balance)assert.equal(row.document_total,row.paid_total);pass('Seluruh piutang pelanggan dan utang supplier fixture bernilai nol');
await as('OWNER');await denied('Edit harga invoice langsung ditolak',"update gas_financial_entries set unit_price=1 where document_item_id in(select id from gas_document_items where document_id=$1)",[invoices[0]]);
await denied('Pembayaran langsung melewati prosedur ditolak','insert into gas_payments(document_id,amount) values($1,999999)',[invoices[0]]);
await as('LOGISTIK');await q('select gaspos_return_trip($1,15,38)',[trip]);assert.deepEqual(await stock(),{full_balance:55,empty_balance:38});pass('Rekonsiliasi gudang terpisah tetap benar setelah invoice/pembayaran');
await as('OWNER');const report=(await q('select * from gaspos_profit_loss_summary()'))[0];assert.equal(Number(report.revenue),832500);assert.equal(Number(report.hpp),765000);assert.equal(Number(report.gross_profit),67500);assert.equal(Number(report.operating_expenses),20000);assert.equal(Number(report.net_profit),47500);pass('Pendapatan/HPP/laba bersih sesuai alur hulu ke hilir',report);

await db.exec('BEGIN');await as('LOGISTIK');
const groupedSJ=await scalar("select gaspos_create_delivery_sj($1,2,$2,'group 01','test',$3)",[product,ids.SALES_SOPIR,crypto.randomUUID()]);
const groupedTrip=await scalar('select id from gas_trips where request_id=$1',[groupedSJ]);
await as('SALES_SOPIR');for(let i=0;i<2;i++){const stop=await scalar("select gaspos_record_stop($1,$2,1,0,'Faktur gabungan')",[groupedTrip,customers[0]]);await q("select gaspos_confirm_stop_signed($1,'TEST receiver',$2)",[stop,JSON.stringify([[[1,1],[2,2],[3,3]]])]);}
await as('OWNER');const groupedInvoice=await scalar('select gaspos_invoice_trip_customer($1,$2,18500,current_date,null)',[groupedTrip,customers[0]]);
assert.equal(Number(await scalar('select quantity_full from gas_document_items where document_id=$1',[groupedInvoice])),2);assert.equal(await scalar('select status from gas_trips where id=$1',[groupedTrip]),'ON_ROUTE');pass('Owner konfirmasi faktur gabungan sebelum kendaraan pulang');await db.exec('ROLLBACK');await as('LOGISTIK');assert.deepEqual(await stock(),{full_balance:55,empty_balance:38});

await as('KEUANGAN');const names=await q('select * from gaspos_finance_partner_names()');assert(names.some(x=>x.id===customers[0]));assert(names.every(x=>Object.keys(x).sort().join(',')==='id,name'));pass('Keuangan membaca nama mitra tagihan saja tanpa akses master');
await as('LOGISTIK');await denied('Logistik tidak memakai RPC mitra keuangan','select * from gaspos_finance_partner_names()');
await as('SALES_SOPIR');await denied('Sopir tidak memakai RPC mitra keuangan','select * from gaspos_finance_partner_names()');
await as('KEUANGAN');const baseExpenseTotal=Number(await scalar('select coalesce(sum(amount),0) from gas_operating_expenses')),baseNetProfit=Number((await q('select * from gaspos_profit_loss_summary()'))[0].net_profit);await db.exec('BEGIN');
await q("select gaspos_add_operating_expense(current_date,'BBM','retry baseline',20000)");await q("select gaspos_add_operating_expense(current_date,'BBM','retry baseline',20000)");
assert.equal(Number(await scalar('select sum(amount) from gas_operating_expenses')),baseExpenseTotal+40000);pass('Baseline reproduces duplicate operating expense on an old form retry');await db.exec('ROLLBACK');await as('KEUANGAN');
await db.exec('BEGIN');const expenseRequest=crypto.randomUUID();
const expense=await scalar("select gaspos_add_operating_expense_once(current_date,'BBM','retry expense',20000,$1)",[expenseRequest]);
assert.equal(await scalar("select gaspos_add_operating_expense_once(current_date,'BBM',' retry expense ',20000,$1)",[expenseRequest]),expense);
assert.equal(Number(await scalar('select sum(amount) from gas_operating_expenses')),baseExpenseTotal+20000);pass('Expense retry records one cost, normalizes whitespace and returns same ID');
const onceReport=(await q('select * from gaspos_profit_loss_summary()'))[0];assert.equal(Number(onceReport.operating_expenses),baseExpenseTotal+20000);assert.equal(Number(onceReport.net_profit),baseNetProfit-20000);pass('Expense retry reduces net profit by one cost only');
for(const [test,sql,args] of [
 ['Expense key rejects changed amount',"select gaspos_add_operating_expense_once(current_date,'BBM','retry expense',20001,$1)",[expenseRequest]],
 ['Expense key rejects changed description',"select gaspos_add_operating_expense_once(current_date,'BBM','changed',20000,$1)",[expenseRequest]],
 ['Expense key rejects changed category',"select gaspos_add_operating_expense_once(current_date,'MAKAN','retry expense',20000,$1)",[expenseRequest]],
 ['Expense key rejects changed date',"select gaspos_add_operating_expense_once(current_date+1,'BBM','retry expense',20000,$1)",[expenseRequest]],
 ['Expense key is required',"select gaspos_add_operating_expense_once(current_date,'BBM','retry expense',20000,null)",[]],
 ['Expense rejects non-cent precision',"select gaspos_add_operating_expense_once(current_date,'BBM','retry expense',0.001,$1)",[crypto.randomUUID()]],
 ['Expense still rejects nonpositive amount',"select gaspos_add_operating_expense_once(current_date,'BBM','retry expense',0,$1)",[crypto.randomUUID()]],
])await deniedInTransaction(test,sql,args);
await as('OWNER');await deniedInTransaction('Expense replay rejects different staff',"select gaspos_add_operating_expense_once(current_date,'BBM','retry expense',20000,$1)",[expenseRequest]);
for(const role of ['LOGISTIK','SALES_SOPIR']){await as(role);await deniedInTransaction(role+' cannot add expenses',"select gaspos_add_operating_expense_once(current_date,'BBM','retry expense',20000,$1)",[crypto.randomUUID()]);}
await as('KEUANGAN');await q("select gaspos_add_operating_expense_once(current_date,'BBM','retry expense',20000,$1)",[crypto.randomUUID()]);assert.equal(Number(await scalar('select sum(amount) from gas_operating_expenses')),baseExpenseTotal+40000);pass('Separate intentional expense remains allowed with a new request ID');
await db.exec('ROLLBACK');await as('OWNER');assert.equal(Number((await q('select * from gaspos_profit_loss_summary()'))[0].operating_expenses),baseExpenseTotal);pass('Retry test fixtures rolled back; original scenario totals restored');
const refundable=async()=>{
 await as('KEUANGAN');const remaining=Number(await scalar('select document_total-paid_total from gaspos_trade_balances where id=$1',[purchase]));if(remaining>0)await q('select gaspos_record_payment_once($1,$2,$3)',[purchase,remaining,crypto.randomUUID()]);
 await as('OWNER');const saleItem=await scalar('select id from gas_document_items where document_id=$1',[invoices[0]]),purchaseItem=await scalar('select id from gas_document_items where document_id=$1',[purchase]);
 await q("select gaspos_return_sale_v2($1,1,0,'TEST refund credit',$2)",[saleItem,crypto.randomUUID()]);
 await q("select gaspos_return_purchase($1,1,'TEST supplier refund credit',$2)",[purchaseItem,crypto.randomUUID()]);await as('KEUANGAN');
};
await db.exec('BEGIN');await refundable();
const oldCustomerKey=crypto.randomUUID(),oldSupplierKey=crypto.randomUUID();
const oldCustomerRefund=await scalar('select gaspos_customer_refund($1,18500,$2)',[invoices[0],oldCustomerKey]);
assert.equal(await scalar('select gaspos_customer_refund($1,1,$2)',[purchase,oldCustomerKey]),oldCustomerRefund);
const oldSupplierRefund=await scalar('select gaspos_record_supplier_refund($1,17000,$2)',[purchase,oldSupplierKey]);
assert.equal(await scalar('select gaspos_record_supplier_refund($1,1,$2)',[invoices[0],oldSupplierKey]),oldSupplierRefund);pass('Baseline reproduces false success for a reused refund key with changed document/amount');
await db.exec('ROLLBACK');await db.exec('RESET ROLE');await db.exec(read('supabase/audit_refund_replay.sql'));await db.exec('SET ROLE authenticated');await as('KEUANGAN');
await db.exec('BEGIN');await refundable();
for(const [rpc,document,credit,other] of [['gaspos_customer_refund',invoices[0],18500,purchase],['gaspos_record_supplier_refund',purchase,17000,invoices[0]]]){
 const key=crypto.randomUUID(),refund=await scalar('select '+rpc+'($1,$2,$3)',[document,credit,key]);
 assert.equal(await scalar('select '+rpc+'($1,$2,$3)',[document,credit,key]),refund);pass(rpc+' identical replay returns one original refund');
 await deniedInTransaction(rpc+' rejects changed amount','select '+rpc+'($1,1,$2)',[document,key]);
 await deniedInTransaction(rpc+' rejects changed document','select '+rpc+'($1,$2,$3)',[other,credit,key]);
 await deniedInTransaction(rpc+' rejects refund beyond remaining credit','select '+rpc+'($1,1,$2)',[document,crypto.randomUUID()]);
 for(const role of ['LOGISTIK','SALES_SOPIR']){await as(role);await deniedInTransaction(rpc+' rejects '+role,'select '+rpc+'($1,$2,$3)',[document,credit,key]);}await as('KEUANGAN');
}
await as('OWNER');assert.equal(Number(await scalar('select count(*) from gas_customer_refunds')),1);assert.equal(Number(await scalar('select count(*) from gas_supplier_refunds')),1);pass('Refund replay never inserts a second refund');
await db.exec('ROLLBACK');await as('LOGISTIK');assert.deepEqual(await stock(),{full_balance:55,empty_balance:38});pass('Refund test fixtures rolled back and final stock remains55/38');
console.log(JSON.stringify({scope:'isolated PostgreSQL with authenticated role + production policies/RPCs',results},null,2));await db.close();
