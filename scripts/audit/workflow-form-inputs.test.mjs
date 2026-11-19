import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import {readNumber,parseNumberId,numberConstraintError} from '../../src/indonesian-numbers.js';

const read=path=>fs.readFileSync(new URL('../../'+path,import.meta.url),'utf8');

test('Buat Surat Jalan always reads the numeric quantity field, not injected searchable input',()=>{
 const src=read('src/multi-load.js');
 assert.match(src,/class="sj-load-quantity" type="number"/);
 assert.match(src,/readNumber\(row\.querySelector\('\.sj-load-quantity'\)\)/);
 assert.match(src,/quantity=row\.querySelector\('\.sj-load-quantity'\)/);
 assert.doesNotMatch(src,/row\.querySelector\(['"]input['"]\)/);
 const searchInput={value:'LPG 12 kg — sisa 55 tabung isi',dataset:{}};
 const quantity={value:'55',dataset:{numberLocale:'id'}};
 const row={querySelector(selector){if(selector==='.sj-load-quantity')return quantity;if(selector==='input')return searchInput;throw Error('Unexpected selector '+selector);}};
 assert.equal(readNumber(row.querySelector('.sj-load-quantity')),55);
 assert.ok(Number.isNaN(parseNumberId(searchInput.value)));
 assert.equal(numberConstraintError(55,{min:'1',max:'55'}),'');
 assert.match(numberConstraintError(56,{min:'1',max:'55'}),/55/);
});
test('Edit Surat Jalan uses a dedicated quantity field as well',()=>{
 const src=read('src/main.js');
 const start=src.indexOf('const openSJEditor='),end=src.indexOf('const deleteSJ=',start);
 assert.ok(start>0&&end>start,'Edit SJ handler exists');
 const edit=src.slice(start,end);
 assert.match(edit,/class="sj-edit-quantity" type="number"/);
 assert.match(edit,/readNumber\(row\.querySelector\('\.sj-edit-quantity'\)\)/);
 assert.doesNotMatch(edit,/row\.querySelector\(['"]input['"]\)/);
});
test('All transactional form numeric values keep the Indonesian-number parser',()=>{
 const files=['src/main.js','src/multi-load.js','src/cylinder-returns.js','src/invoice-profile.js','src/transaction-reports.js'];
 for(const path of files){
   const src=read(path);
   assert.doesNotMatch(src,/readNumber\(\s*\w+\.querySelector\(['"]input['"]\)\s*\)/,path);
 }
});

test('Pembelian tabung kosong uses one visible quantity field, with correct stock payload',()=>{
 const src=read('src/main.js');
 assert.match(src,/qtyInput\.closest\('label'\)\.querySelector\('span'\)\.textContent=emptyOnly\?'Jumlah Tabung Kosong Dibeli':'Jumlah Tabung Isi'/);
 assert.match(src,/qtyInput\.readOnly=false/);
 assert.match(src,/emptyField\.style\.display=mode\.value==='EXCHANGE'\?'':'none'/);
 assert.match(src,/quantity_full:purchase&&line\.querySelector\('\.trade-mode'\)\.value==='EMPTY_ONLY'\?0:readNumber\(line\.querySelector\('\.trade-qty'\)\)/);
 assert.match(src,/quantity_empty:purchase&&line\.querySelector\('\.trade-mode'\)\.value==='EMPTY_ONLY'\?readNumber\(line\.querySelector\('\.trade-qty'\)\)/);
 assert.doesNotMatch(src,/if\(mode\?\.value==='EMPTY_ONLY'\)\{setFieldValue\(emptyInput,'0'\)/);
});

test('Pembelian retry reuses one request ID to prevent duplicate documents on network errors',()=>{
 const src=read('src/main.js');
 assert.match(src,/const createPurchase=purchase&&!editing/);
 assert.match(src,/pendingPurchaseRequest=crypto\.randomUUID\(\)/);
 assert.match(src,/rpcArgs\.p_request=pendingPurchaseRequest/);
 assert.match(src,/purchase\?'gaspos_create_purchase_once':'gaspos_create_sale'/);
 assert.match(src,/if\(createPurchase&&networkFailure\(result\.error\)&&navigator\.onLine!==false\)/);
 assert.match(src,/result=await api\.rpc\(rpcName,rpcArgs\)/);
 assert.match(src,/Periksa Riwayat Pembelian/);
});
test('Idempotent purchase procedure serializes retries and checks ownership',()=>{
 const sql=read('supabase/purchase_idempotent_request.sql');
 assert.match(sql,/purchase_request_id uuid/);
 assert.match(sql,/unique index if not exists gas_documents_purchase_request_id_key/);
 assert.match(sql,/pg_advisory_xact_lock\(948621\)/);
 assert.match(sql,/v_author is distinct from auth\.uid\(\)/);
 assert.match(sql,/return v_doc;/);
 assert.match(sql,/grant execute on function public\.gaspos_create_purchase_once/);
});
