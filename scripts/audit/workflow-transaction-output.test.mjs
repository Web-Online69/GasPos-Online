import test from 'node:test';import assert from 'node:assert/strict';import {execFileSync} from 'node:child_process';import fs from 'node:fs';import os from 'node:os';import path from 'node:path';
import {workbookBytes,cellValue,outputHtml,paperCss,filename} from '../../src/transaction-output.js';
test('Excel quantities and currency preserve Indonesian values; identifiers remain text',()=>{assert.equal(cellValue('Rp 1.000.000','Nilai'),1000000);assert.equal(cellValue('-1.250','Kosong'),-1250);assert.equal(cellValue('1.234,50','Harga'),1234.5);for(const [value,label]of [['INV 00001','Dokumen'],['00123','No. Dokumen'],['08123456','Telepon'],['=HYPERLINK("bad")','Mitra'],['Belum valid','HPP']])assert.equal(cellValue(value,label),value);});
test('Native XLSX opens as a valid ZIP and stores typed numbers, safe text, metadata and filters',()=>{const dir=fs.mkdtempSync(path.join(os.tmpdir(),'gaspos-xlsx-'));try{const file=path.join(dir,'export.xlsx');fs.writeFileSync(file,workbookBytes({title:'INV 00001',context:['Filter: Pelanggan A','Total Rp 1.000.000'],headers:['Dokumen','Jumlah','Nilai','Mitra'],rows:[['INV 00001',45,1000000,'=HYPERLINK("https://example.invalid")'],['00001',-4,1234.5,'<script>& Uji']] }));const result=execFileSync('python',['-c',`import zipfile,sys,xml.etree.ElementTree as E
with zipfile.ZipFile(sys.argv[1]) as z:
 assert z.testzip() is None
 for name in z.namelist(): E.fromstring(z.read(name))
 ns={'s':'http://schemas.openxmlformats.org/spreadsheetml/2006/main'}
 root=E.fromstring(z.read('xl/worksheets/sheet1.xml'))
 assert len(root.findall('.//s:f',ns))==0
 cells={c.attrib['r']:c for c in root.findall('.//s:c',ns)}
 assert cells['B6'].find('s:v',ns).text=='45'
 assert cells['C6'].find('s:v',ns).text=='1000000'
 assert cells['C7'].find('s:v',ns).text=='1234.5'
 assert cells['A7'].attrib['t']=='inlineStr'
 assert cells['D6'].find('.//s:t',ns).text.startswith('=HYPERLINK')
 assert root.find('s:autoFilter',ns).attrib['ref']=='A5:D7'
 print('PASS')`,file],{encoding:'utf8'});assert.equal(result.trim(),'PASS');}finally{fs.rmSync(dir,{recursive:true,force:true});}});
test('Print escapes stored content and keeps paper widths distinct',()=>{const html=outputHtml({title:'<script>bad</script>',headers:['Pelanggan','Kosong'],rows:[['<img onerror="bad">',1000]],context:['Filter & catatan']});assert.ok(!html.includes('<script>'));assert.ok(!html.includes('<img'));assert.ok(html.includes('1.000'));assert.ok(paperCss('58').includes('width:58mm'));assert.ok(paperCss('80').includes('width:80mm'));assert.ok(paperCss('A4',true).includes('A4 landscape'));assert.ok(paperCss('58').includes('thead{display:none'));assert.throws(()=>paperCss('bad'));assert.ok(filename('INV / 00001').endsWith('.xlsx'));assert.ok(!filename('INV / 00001').includes('/'));});
