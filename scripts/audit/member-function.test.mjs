import { test } from 'node:test';
import assert from 'node:assert/strict';
import { createHandler } from '../../supabase/functions/gaspos-invite-member/index.ts';
const ownerId = '00000000-0000-4000-8000-000000000001';
const staffId = '00000000-0000-4000-8000-000000000002';
// Deliberately fake credentials: no real secrets are used in this suite.
const secret = 'mock-server-key';
const json = (value, status = 200) => new Response(JSON.stringify(value), { status, headers: { 'content-type': 'application/json' } });
function setup(afterAuth = () => { throw Error('Unexpected backend call'); }, owner = { user_id: ownerId, role: 'OWNER', active: true }) {
  const calls = [];
  const handler = createHandler({ url: 'https://mock.supabase.test', serviceRoleKey: secret, fetchImpl: async (url, init) => {
    const path = new URL(url).pathname + new URL(url).search;
    calls.push({ path, ...init });
    if (path === '/auth/v1/user') {
      assert.equal(init.headers.Authorization, 'Bearer mock-caller-token');
      return json({ id: ownerId });
    }
    assert.equal(init.headers.Authorization, 'Bearer ' + secret);
    if (path.includes('user_id=eq.' + ownerId) && !init.method) return json(owner ? [owner] : []);
    return afterAuth(path, init, calls);
  } });
  const request = body => handler(new Request('https://function.test', { method: 'POST', headers: { Authorization: 'Bearer mock-caller-token', 'content-type': 'application/json' }, body: JSON.stringify(body) }));
  return { handler, request, calls };
}
test('preflight allows Supabase client headers; missing login never contacts backend', async () => {
  const { handler, calls } = setup();
  const options = await handler(new Request('https://function.test', { method: 'OPTIONS' }));
  assert.equal(options.status, 200);
  assert.match(options.headers.get('access-control-allow-headers'), /x-client-info/);
  assert.equal(options.headers.get('access-control-allow-methods'), 'POST, OPTIONS');
  assert.equal((await handler(new Request('https://function.test', { method: 'GET' }))).status, 405);
  assert.equal((await handler(new Request('https://function.test', { method: 'POST' }))).status, 401);
  assert.equal(calls.length, 0);
});
test('inactive Owner and all staff roles are rejected before privileged operations', async () => {
  for (const role of ['OWNER', 'LOGISTIK', 'SALES_SOPIR', 'KEUANGAN']) {
    const { request, calls } = setup(undefined, { user_id: ownerId, role, active: role !== 'OWNER' });
    assert.equal((await request({ action: 'list' })).status, 403);
    assert.equal(calls.length, 2);
  }
});
test('manual create confirms email, accepts staff only and never returns password/key', async () => {
  for (const role of ['LOGISTIK', 'SALES_SOPIR', 'KEUANGAN']) {
    const { request, calls } = setup((path, init) => {
      if (path === '/auth/v1/admin/users') {
        assert.deepEqual(JSON.parse(init.body), { email: 'trial01@users.gaspos.local', password: 'mock-password', email_confirm: true, user_metadata: { username: 'trial01' } });
        return json({ id: staffId, encrypted_password: 'must-not-leak' });
      }
      assert.equal(path, '/rest/v1/gas_members');
      assert.deepEqual(JSON.parse(init.body), { user_id: staffId, role, assigned_roles: [role], active: true });
      return new Response(null, { status: 201 });
    });
    const response = await request({ action: 'create', username: 'Trial01', password: 'mock-password', role });
    assert.equal(response.status, 200);
    assert.deepEqual(await response.json(), { ok: true, username: 'trial01' });
    assert.equal(calls.length, 4);
  }
  const { request, calls } = setup();
  assert.equal((await request({ action: 'create', username: 'trial01', password: 'mock-password', role: 'OWNER' })).status, 400);
  assert.equal(calls.length, 2);
});
test('failed member insert rolls back only the new auth user and sanitizes backend errors', async () => {
  const { request, calls } = setup((path, init) => {
    if (path === '/auth/v1/admin/users') return json({ id: staffId });
    if (path === '/rest/v1/gas_members') return json({ error: 'sensitive mock-password mock-server-key' }, 500);
    assert.equal(path, '/auth/v1/admin/users/' + staffId);
    assert.equal(init.method, 'DELETE');
    return new Response(null, { status: 204 });
  });
  const response = await request({ action: 'create', username: 'trial01', password: 'mock-password', role: 'LOGISTIK' });
  assert.equal(response.status, 502);
  const text = await response.text();
  assert.match(text, /Akun baru dibatalkan/);
  assert.doesNotMatch(text, /mock-password|mock-server-key|sensitive/);
  assert.equal(calls.filter(c => c.method === 'DELETE').length, 1);
});
test('rollback failure is reported without exposing backend details', async () => {
  const { request } = setup(path => path === '/auth/v1/admin/users' ? json({ id: staffId }) : json({ error: secret }, 500));
  const response = await request({ action: 'create', username: 'trial01', password: 'mock-password', role: 'KEUANGAN' });
  assert.equal(response.status, 502);
  const text = await response.text();
  assert.match(text, /dibersihkan administrator/);
  assert.ok(!text.includes(secret));
});
test('set_active validates boolean and refuses Owner target; staff update is filtered', async () => {
  const { request, calls } = setup((path, init) => {
    if (!init.method) return json([{ user_id: staffId, role: 'LOGISTIK', active: true }]);
    assert.equal(init.method, 'PATCH');
    assert.match(path, /role=in\.\(LOGISTIK,SALES_SOPIR,KEUANGAN\)/);
    assert.deepEqual(JSON.parse(init.body), { active: false });
    return json([{ user_id: staffId, role: 'LOGISTIK', active: false }]);
  });
  assert.equal((await request({ action: 'set_active', user_id: staffId, active: 'false' })).status, 400);
  assert.equal((await request({ action: 'set_active', user_id: ownerId, active: false })).status, 403);
  assert.equal((await request({ action: 'set_active', user_id: staffId, active: false })).status, 200);
  assert.equal(calls.filter(c => c.method === 'PATCH').length, 1);
});
test('list paginates Auth and returns only safe membership identity fields', async () => {
  const { request } = setup(path => {
    if (path.startsWith('/rest/v1/gas_members?select=')) return json([{ user_id: staffId, role: 'SALES_SOPIR', active: true }]);
    if (path.endsWith('page=1&per_page=100')) return json({ users: Array.from({ length: 100 }, (_, index) => ({ id: 'filler-' + index, email: 'private@example.test' })) });
    assert.ok(path.endsWith('page=2&per_page=100'));
    return json({ users: [{ id: staffId, email: 'staff@users.gaspos.local', user_metadata: { username: 'staff01' }, encrypted_password: 'must-not-leak' }] });
  });
  const response = await request({ action: 'list' });
  assert.equal(response.status, 200);
  assert.deepEqual(await response.json(), { users: [{ user_id: staffId, role: 'SALES_SOPIR', assigned_roles: ['SALES_SOPIR'], active: true, username: 'staff01' }] });
});
test('invalid JSON and network exceptions are safe failures', async () => {
  const { handler, request } = setup(() => { throw new Error('mock-password ' + secret); });
  const malformed = await handler(new Request('https://function.test', { method: 'POST', headers: { Authorization: 'Bearer mock-caller-token' }, body: '{' }));
  assert.equal(malformed.status, 400);
  const response = await request({ action: 'list' });
  assert.equal(response.status, 502);
  assert.doesNotMatch(await response.text(), /mock-password|mock-server-key/);
});

test('Owner can create multiple staff jobs while Owner and unknown jobs are rejected',async()=>{
 const {request}=setup((path,init)=>{if(path==='/auth/v1/admin/users')return json({id:staffId});assert.deepEqual(JSON.parse(init.body),{user_id:staffId,role:'LOGISTIK',assigned_roles:['LOGISTIK','KEUANGAN'],active:true});return new Response(null,{status:201});});
 assert.equal((await request({action:'create',username:'multi01',password:'mock-password',role:'LOGISTIK',assigned_roles:['LOGISTIK','KEUANGAN']})).status,200);
 for(const assigned_roles of [[],['OWNER'],['LOGISTIK','ADMIN'],['KEUANGAN']]){const {request,calls}=setup();assert.equal((await request({action:'create',username:'multi01',password:'mock-password',role:'LOGISTIK',assigned_roles})).status,400);assert.equal(calls.length,2);}
});
test('Failed password change rolls back both assigned jobs and active job',async()=>{
 const old={user_id:staffId,role:'LOGISTIK',assigned_roles:['LOGISTIK','SALES_SOPIR'],active:true};const patches=[];
 const {request}=setup((path,init)=>{if(!init.method)return json([old]);if(init.method==='PATCH'){patches.push(JSON.parse(init.body));return json([old]);}return json({error:'private mock-password'},500);});
 const response=await request({action:'edit',user_id:staffId,role:'KEUANGAN',assigned_roles:['LOGISTIK','KEUANGAN'],password:'mock-password'});assert.equal(response.status,502);assert.deepEqual(patches,[{role:'KEUANGAN',assigned_roles:['LOGISTIK','KEUANGAN']},{role:'LOGISTIK',assigned_roles:['LOGISTIK','SALES_SOPIR']}]);assert.ok(!(await response.text()).includes('mock-password'));
});
