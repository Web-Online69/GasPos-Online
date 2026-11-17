import {stockTotalsHtml} from './stock-totals.js';
import {formatNumberId} from './indonesian-numbers.js';
import {compactTableReferences} from './compact-ui.js';
export const escapeText = v => String(v ?? '').replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
export function dateKey(value) {
 const s=String(value||'').trim();
 if(/^\d{4}-\d{2}-\d{2}$/.test(s))return s;
 const local=s.match(/^(\d{1,2})\/(\d{1,2})\/(\d{4})/);
 if(local)return `${local[3]}-${local[2].padStart(2,'0')}-${local[1].padStart(2,'0')}`;
 const d=new Date(s);if(!s||!Number.isFinite(d.getTime()))return '';
 return new Intl.DateTimeFormat('sv-SE',{timeZone:'Asia/Jakarta',year:'numeric',month:'2-digit',day:'2-digit'}).format(d);
}
export function matchesFilter(row,{search='',from='',to='',values={}}={}) {
 const text=(row.search ?? Object.values(row).join(' ')).toLocaleLowerCase('id-ID');
 if(search.trim().toLocaleLowerCase('id-ID').split(/\s+/).some(q=>!text.includes(q)))return false;
 if(from||to){const day=dateKey(row.date);if(!day||(from&&day<from)||(to&&day>to))return false;}
 return Object.entries(values).every(([key,value])=>!value||String(row[key]??'')===value);
}
// Continue to an empty page, including when the server caps responses below batchSize.
// Fail closed on errors: a partial fetch must never look like a complete report.
export async function readAll(query,{batchSize=500,maxRows=100000}={}) {
 const data=[];
 try {
  for(;;){const result=await query.range(data.length,data.length+batchSize-1);if(result.error)return {data:null,error:result.error};
   if(!result.data?.length)return {data,error:null};
   data.push(...result.data.map(row=>row&&row.display_no&&row.document_no?{...row,legacy_document_no:row.legacy_document_no||row.document_no,document_no:row.display_no}:row));if(data.length>maxRows)return {data:null,error:{message:'Data terlalu banyak. Persempit rentang tanggal untuk laporan.'}};
  }
 } catch(error){return {data:null,error:{message:error.message||'Gagal memuat seluruh riwayat.'}};}
}
const numberCells=new WeakSet();
function formatQuantityCells(table){if(table.hasAttribute('data-no-history-filters')||!table.tHead)return;const indices=[...table.tHead.rows[0].cells].flatMap((c,i)=>/penuh|kosong|jumlah|muatan|terutang|kembali|sisa|selisih/i.test(c.textContent)?[i]:[]);for(const body of table.tBodies)for(const row of body.rows)for(const index of indices){const cell=row.cells[index];if(!cell||numberCells.has(cell)||cell.children.length)continue;numberCells.add(cell);const m=cell.textContent.trim().match(/^([+-]?)(\d+(?:\.\d+)?)(\s+(?:penuh|kosong|tabung))?$/);if(m)cell.textContent=(m[1]==='+'?'+':'')+formatNumberId(Number(m[1]+m[2]))+(m[3]||'');}}
const dateHeader=/tanggal|berangkat|jatuh tempo/i;
const selectHeader=/pelanggan|supplier|suplayer|mitra|tabung|produk|jenis|status|peran|sopir|kendaraan/i;
function cellText(cell){if(!cell)return '';const clone=cell.cloneNode(true);clone.querySelectorAll('details.compact-reference').forEach(el=>el.replaceWith(document.createTextNode(el.dataset.full)));clone.querySelectorAll('button,details,small').forEach(el=>el.remove());return clone.textContent.trim();}

// Label shared record tables once per refresh; preserve the original table for desktop/export.
export function prepareMobileRecords(table) {
 if(!table.tHead||!table.tBodies.length||table.matches('.cylinder-balance-table,.cylinder-overview-table,.users-table')||table.querySelector('#trip-list,#log-rows')||table.closest('#trip-detail'))return;
 if(!table.matches('.product-table,.supplier-table,.customer-table,.trade-table,.report-table'))return;
 table.classList.add('mobile-records');
 const headers=[...table.tHead.rows[0].cells].map(cell=>cell.textContent.trim());
 for(const body of table.tBodies)for(const row of body.rows)for(const [index,cell] of [...row.cells].entries()){
  if(cell.hasAttribute('colspan'))continue;
  const label=headers[index]||'Keterangan';cell.dataset.mobileLabel=label;
  cell.classList.toggle('mobile-wide',/tanggal|berangkat|dokumen|pelanggan|supplier|suplayer|mitra|produk|tabung|catatan|alamat|keterangan|penerima|aksi|nama/i.test(label));
  cell.classList.toggle('mobile-actions',/aksi/i.test(label));
 }
}

export function watchHistoryFilters(root) {
 const controls=new WeakMap();
 function setup(table){prepareMobileRecords(table);compactTableReferences(table);formatQuantityCells(table);
  if(table.hasAttribute('data-no-history-filters')||!table.tHead||!table.tBodies.length)return;
  // Master lists already provide a search box. No artificial date filter for undated data.
  if(['product-list','supplier-rows','customer-rows'].includes(table.tBodies[0].id))return;
  let refresh=controls.get(table);if(refresh){refresh();return;}
  const headers=[...table.tHead.rows[0].cells].map(c=>c.textContent.trim());
  const dateIndex=headers.findIndex(h=>dateHeader.test(h));
  const isSJ=table.classList.contains('sj-history-records');
  const isPaged=!table.matches('.report-table,.users-table,.cylinder-balance-table,.cylinder-overview-table')&&!['stock-list','product-list','supplier-rows','customer-rows','user-rows','users-list','price-rows','price-list'].includes(table.tBodies[0].id)&&!table.closest('#trip-detail');
  const pageSize=5;
  if(isPaged)table.dataset.filterPaging='5';
  let page=0;
  const fields=headers.flatMap((label,index)=>(isSJ?/produk|status/i.test(label):selectHeader.test(label))?[{label,index}]:[]);
  const box=document.createElement('details');box.className='history-filters'+(isSJ?' sj-history-filters':'');box.open=isSJ;
  const summary=document.createElement('summary');summary.textContent=isSJ?'Filter Surat Jalan':'Filter & Cari Riwayat';box.append(summary);
  const form=document.createElement('form');form.className='history-filter-form';form.innerHTML='<label>Cari data<input type="search" name="search" placeholder="Nomor dokumen, nama, catatan…"></label>'+(dateIndex>=0?'<label>Dari '+escapeText(headers[dateIndex].toLowerCase())+'<input type="date" name="from"></label><label>Sampai '+escapeText(headers[dateIndex].toLowerCase())+'<input type="date" name="to"></label>':'')+fields.map(f=>'<label>'+escapeText(f.label)+'<select name="col'+f.index+'"><option value="">Semua</option></select></label>').join('')+'<button type="reset" class="trade-secondary">Reset Filter</button><p class="filter-result" role="status" aria-live="polite"></p>';
  box.append(form);table.parentElement.before(box);
  const pager=isPaged?document.createElement('nav'):null;
  if(pager){pager.className='transaction-pagination';pager.setAttribute('aria-label','Halaman transaksi');pager.innerHTML='<button type="button" class="trade-secondary" data-page="prev">Sebelumnya</button><span class="page-summary" aria-live="polite"></span><button type="button" class="trade-secondary" data-page="next">Berikutnya</button>';table.parentElement.after(pager);}
  const quick=isPaged?document.createElement('div'):null;
  if(quick){
   quick.className='transaction-quick-search';
   quick.innerHTML='<label><span class="sr-only">Cari transaksi</span><input type="search" placeholder="Cari nomor / nama / transaksi..." aria-label="Cari transaksi"></label>';
   box.before(quick);
  }
  const status=form.querySelector('.filter-result');let rows=[];
  const updateTotals=()=>{
   const id=table.tBodies[0].id,visible=rows.filter(r=>r.element.dataset.filterMatch==='true');
   table.dispatchEvent(new Event('history-filter-change'));
   if(id==='expense-rows'){const sum=visible.reduce((n,r)=>n+Number(r.element.dataset.amount||0),0);const label=root.querySelector('#expense-sum');if(label)label.textContent='Total hasil filter: Rp '+sum.toLocaleString('id-ID');}
   if(id==='stock-list'||id==='stock-history-list'){const host=root.querySelector(id==='stock-list'?'#stock-balance-total':'#stock-movement-total');if(!host)return;
    const message=table.tBodies[0].querySelector('td[colspan]')?.textContent||'';
    if(table.dataset.loadFailed||/gagal|tidak dapat|error/i.test(message)){host.textContent='Total tidak tersedia.';return;}
    if(/memuat/i.test(message)){host.textContent='Memuat total…';return;}
    try{host.innerHTML=stockTotalsHtml(visible.map(r=>({full:r.element.dataset.stockFull,empty:r.element.dataset.stockEmpty})),id==='stock-history-list');}catch{host.textContent='Total tidak tersedia: data jumlah tidak valid.';}
   }
  };
  const apply=()=>{const data=new FormData(form),from=data.get('from')||'',to=data.get('to')||'';
   const invalidRange=Boolean(from&&to&&from>to),values=Object.fromEntries(fields.map(f=>['col'+f.index,data.get('col'+f.index)||'']));
   const matching=[];
   for(const row of rows){const match=!invalidRange&&matchesFilter(row,{search:data.get('search')||'',from,to,values});row.element.dataset.filterMatch=String(match);if(match)matching.push(row);}
   const pages=Math.max(1,Math.ceil(matching.length/pageSize));page=Math.min(Math.max(0,page),pages-1);
   for(const row of rows)row.element.hidden=true;
   const display=isPaged?matching.slice(page*pageSize,(page+1)*pageSize):matching;
   for(const row of display)row.element.hidden=false;
   const base=isSJ?'Filter Surat Jalan':'Filter & Cari Riwayat';
   summary.textContent=base+' ('+matching.length+'/'+rows.length+')';
   status.textContent=invalidRange?'Tanggal awal tidak boleh melewati tanggal akhir.':matching.length+' dari '+rows.length+' catatan sesuai filter'+(matching.length===0?' — tidak ada data.':'.');
   if(pager){pager.hidden=matching.length<=pageSize;pager.querySelector('.page-summary').textContent='Halaman '+(page+1)+' / '+pages+' · '+matching.length+' transaksi';pager.querySelector('[data-page=prev]').disabled=page===0;pager.querySelector('[data-page=next]').disabled=page>=pages-1;}
   updateTotals();
  };
  if(pager)pager.onclick=e=>{const direction=e.target.closest('button[data-page]')?.dataset.page;if(!direction)return;page+=direction==='next'?1:-1;apply();};
  if(quick){
   const q=quick.querySelector('input');
   const source=form.querySelector('input[name="search"]');
   q.addEventListener('input',()=>{source.value=q.value;page=0;apply()});
   source.addEventListener('input',()=>{q.value=source.value});
   form.addEventListener('reset',()=>{q.value=''});
  }
  refresh=()=>{rows=[...table.tBodies[0].rows].filter(r=>!r.cells[0]?.hasAttribute('colspan')).map(element=>{const cells=[...element.cells].map(cellText);const search=element.cloneNode(true);search.querySelectorAll('details.compact-reference').forEach(el=>el.replaceWith(document.createTextNode(el.dataset.full)));search.querySelectorAll('button,details').forEach(el=>el.remove());return {element,date:dateIndex<0?'':cells[dateIndex],search:search.textContent+' '+(element.dataset.legacyReference||''),...Object.fromEntries(fields.map(f=>['col'+f.index,cells[f.index]]))};});
   for(const f of fields){const select=form.elements.namedItem('col'+f.index),old=select.value;const opts=[...new Set(rows.map(r=>r['col'+f.index]).filter(Boolean))].sort((a,b)=>a.localeCompare(b,'id'));select.replaceChildren(new Option('Semua',''),...opts.map(v=>new Option(v,v)));select.value=opts.includes(old)?old:'';}
   apply();
  };
  form.onsubmit=e=>e.preventDefault();form.oninput=()=>{page=0;apply();};form.onchange=()=>{page=0;apply();};form.onreset=()=>setTimeout(()=>{page=0;apply();},0);controls.set(table,refresh);refresh();
 }
 const scan=()=>root.querySelectorAll('table').forEach(setup);
 const observer=new MutationObserver(changes=>{const tables=new Set();for(const m of changes){const body=m.target.closest?.('tbody');if(body&&[...m.addedNodes,...m.removedNodes].some(n=>n.nodeName==='TR'))tables.add(body.closest('table'));else if([...m.addedNodes].some(n=>n.nodeType===1&&(n.matches('table')||n.querySelector('table'))))scan();}tables.forEach(t=>t?.isConnected&&setup(t));});
 observer.observe(root,{childList:true,subtree:true});scan();return ()=>observer.disconnect();
}
