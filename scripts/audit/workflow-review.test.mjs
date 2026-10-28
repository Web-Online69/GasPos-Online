import test from 'node:test';
import assert from 'node:assert/strict';
import {signatureSvg,loadWorkQueue} from '../../src/workflow-review.js';
test('Stored receipt evidence rejects script strings, invalid coordinates and malformed strokes',()=>{
 for(const input of [null,[],[[['"><script>alert(1)</script>',1],[1,2],[3,4]]],[[[0,0],[321,1],[2,2]]],[[[0,0],[1,-1],[2,2]]],[[[1,1],[2,2]]]])assert.equal(signatureSvg(input),'');
 assert.match(signatureSvg([[[0,0],[320,160],[2,2]]]),/points="0,0 320,160 2,2"/);
});
function client({error=false}={}){
 const calls=[];
 return {calls,rpc:async name=>{calls.push(name);return {data:[{document_id:'same'},{document_id:'same'},{document_id:'second'}],error:error?{}:null}},from(table){calls.push(table);const query={select(){return this},eq(){return this},is(){return this},then(resolve){return Promise.resolve({count:3,data:[{document_type:'SALE',document_total:100,paid_total:50},{document_type:'SALE',document_total:100,paid_total:100},{document_type:'PURCHASE',document_total:100,paid_total:0}],error:error?{}:null}).then(resolve)}};return query}};
}
test('Driver queue never queries prices, payments, purchase or all-driver data',async()=>{
 const api=client(),jobs=await loadWorkQueue(api,'SALES_SOPIR');assert.deepEqual(api.calls.sort(),['gas_trip_stops','gas_trips']);assert.equal(jobs.length,2);assert(jobs.every(x=>x.view==='trips'));
});
test('Logistics receives distinct pending purchases and physical return work only',async()=>{
 const api=client(),jobs=await loadWorkQueue(api,'LOGISTIK');assert.equal(jobs[0].count,2);assert.deepEqual(api.calls.sort(),['gas_trips','gaspos_pending_purchase_lines']);
});
test('Finance work excludes settled invoices, includes unpaid supplier, and exposes no warehouse action',async()=>{
 const api=client(),jobs=await loadWorkQueue(api,'KEUANGAN');assert.deepEqual(jobs.map(x=>x.count),[1,1]);assert(jobs.every(x=>x.view==='gas_payments'));assert.deepEqual(api.calls,['gaspos_trade_balances']);
});
test('Owner can follow all six work queues',async()=>{
 const jobs=await loadWorkQueue(client(),'OWNER');assert.equal(jobs.length,6);assert(jobs.some(x=>x.label==='Faktur siap dikonfirmasi menjadi INV'));
});
test('Query failure is unavailable, never a misleading zero pending work',async()=>{
 for(const role of ['OWNER','LOGISTIK','SALES_SOPIR','KEUANGAN'])assert((await loadWorkQueue(client({error:true}),role)).every(x=>x.count===null));
});
