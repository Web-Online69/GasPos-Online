import test from 'node:test';
import assert from 'node:assert/strict';
import {createMemberRequest} from '../../src/member-requests.js';
const http=(status,payload)=>({data:null,error:{context:new Response(JSON.stringify(payload),{status})}});
function setup({responses=[{data:{ok:true},error:null}],refreshError=null,session=true}={}) {
 const calls=[],expired=[],signouts=[];let refreshes=0;
 const api={auth:{getSession:async()=>({data:{session:session?{access_token:'initial-fixture-token'}:null}}),refreshSession:async()=>{refreshes++;return {data:{session:refreshError?null:{access_token:'refreshed-fixture-token'}},error:refreshError}},signOut:async options=>signouts.push(options)},functions:{invoke:async(name,options)=>{calls.push({name,options});return responses.shift()}}};
 return {invoke:createMemberRequest(api,{onSessionExpired:message=>expired.push(message)}),calls,expired,signouts,get refreshes(){return refreshes}};
}
test('valid Owner session submits account operation once',async()=>{
 const s=setup();assert.equal((await s.invoke({body:{action:'list'}})).data.ok,true);assert.equal(s.calls.length,1);assert.equal(s.refreshes,0);
});
test('401 refreshes once and retries using the new token with the same request',async()=>{
 const s=setup({responses:[http(401,{error:'Token tidak sah'}),{data:{ok:true},error:null}]});
 const body={action:'edit',role:'LOGISTIK',password:'fixture-only-password'};
 assert.equal((await s.invoke({body})).data.ok,true);assert.equal(s.refreshes,1);assert.equal(s.calls.length,2);
 assert.equal(s.calls[0].options.headers.Authorization,'Bearer initial-fixture-token');assert.equal(s.calls[1].options.headers.Authorization,'Bearer refreshed-fixture-token');assert.equal(s.calls[1].options.body,body);assert.equal(s.expired.length,0);
});
test('deleted session redirects to login without repeating the mutation',async()=>{
 const s=setup({responses:[http(401,{error:'Token tidak sah'})],refreshError:new Error('fixture session missing')});
 const result=await s.invoke({body:{action:'edit'}});assert.match(result.error.message,/masuk kembali/);assert.equal(s.calls.length,1);assert.deepEqual(s.signouts,[{scope:'local'}]);assert.equal(s.expired.length,1);
});
test('second 401 stops instead of retrying in a loop',async()=>{
 const s=setup({responses:[http(401,{}),http(401,{})]});await s.invoke({body:{action:'edit'}});assert.equal(s.calls.length,2);assert.equal(s.refreshes,1);assert.equal(s.expired.length,1);
});
test('backend validation message is visible; rejected password is never reported saved',async()=>{
 const s=setup({responses:[http(400,{error:'Password baru tidak memenuhi ketentuan'})]});const r=await s.invoke({body:{action:'edit'}});assert.equal(r.error.message,'Password baru tidak memenuhi ketentuan');assert.equal(s.refreshes,0);
});
test('server failure is not retried because the mutation result could be uncertain',async()=>{
 const s=setup({responses:[http(502,{error:'Gagal mengganti password'})]});const r=await s.invoke({body:{action:'edit'}});assert.equal(r.error.message,'Gagal mengganti password');assert.equal(s.calls.length,1);assert.equal(s.refreshes,0);
});
test('inactive/non-owner denial stays denied and does not refresh into more privileges',async()=>{
 const s=setup({responses:[http(403,{error:'Hanya Owner aktif berwenang'})]});assert.equal((await s.invoke({body:{action:'edit'}})).error.message,'Hanya Owner aktif berwenang');assert.equal(s.refreshes,0);assert.equal(s.expired.length,0);
});
test('missing local session never invokes the account service',async()=>{
 const s=setup({session:false});await s.invoke({body:{action:'edit'}});assert.equal(s.calls.length,0);assert.equal(s.expired.length,1);
});
