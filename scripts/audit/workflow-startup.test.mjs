import test from 'node:test';
import assert from 'node:assert/strict';
import {restoreStartupSession} from '../../src/startup-session.js';
test('No interactive login can race an in-flight session restoration',async()=>{
 const events=[];let resolve;
 const task=restoreStartupSession({auth:{getUser:()=>new Promise(r=>resolve=r)}},{showLoading:()=>events.push('loading'),showLogin:()=>events.push('login'),enter:async user=>events.push(user.id)});
 assert.deepEqual(events,['loading']);resolve({data:{user:{id:'existing-user'}}});await task;assert.deepEqual(events,['loading','existing-user']);
});
test('Expired session reveals login only after the session check',async()=>{
 const events=[];await restoreStartupSession({auth:{getUser:async()=>({data:{user:null},error:{}})}},{showLoading:()=>events.push('loading'),showLogin:()=>events.push('login'),enter:()=>events.push('enter')});assert.deepEqual(events,['loading','login']);
});
test('Network failure recovers to login without assuming an authenticated user',async()=>{
 const events=[];await restoreStartupSession({auth:{getUser:async()=>{throw Error('network')}}},{showLoading:()=>events.push('loading'),showLogin:()=>events.push('login'),enter:()=>events.push('enter')});assert.deepEqual(events,['loading','login']);
});
