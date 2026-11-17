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
