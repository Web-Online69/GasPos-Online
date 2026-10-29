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
   data.push(...result.data);if(data.length>maxRows)return {data:null,error:{message:'Data terlalu banyak. Persempit rentang tanggal untuk laporan.'}};
  }
 } catch(error){return {data:null,error:{message:error.message||'Gagal memuat seluruh riwayat.'}};}
}
const dateHeader=/tanggal|berangkat|jatuh tempo/i;
const selectHeader=/pelanggan|supplier|suplayer|mitra|tabung|produk|jenis|status|peran|sopir|kendaraan/i;
function cellText(cell){if(!cell)return '';const clone=cell.cloneNode(true);clone.querySelectorAll('details.compact-reference').forEach(el=>el.replaceWith(document.createTextNode(el.dataset.full)));clone.querySelectorAll('button,details,small').forEach(el=>el.remove());return clone.textContent.trim();}
export function watchHistoryFilters(root) {
 const controls=new WeakMap();
 function setup(table){compactTableReferences(table);
  if(table.hasAttribute('data-no-history-filters')||!table.tHead||!table.tBodies.length)return;
  // Master lists already provide a search box. No artificial date filter for undated data.
  if(['product-list','supplier-rows','customer-rows'].includes(table.tBodies[0].id))return;
  let refresh=controls.get(table);if(refresh){refresh();return;}
  const headers=[...table.tHead.rows[0].cells].map(c=>c.textContent.trim());
  const dateIndex=headers.findIndex(h=>dateHeader.test(h));
  const fields=headers.flatMap((label,index)=>selectHeader.test(label)?[{label,index}]:[]);
  const box=document.createElement('details');box.className='history-filters';box.open=false;
  const summary=document.createElement('summary');summary.textContent='Filter & Cari Riwayat';box.append(summary);
  const form=document.createElement('form');form.className='history-filter-form';form.innerHTML='<label>Cari data<input type="search" name="search" placeholder="Nomor dokumen, nama, catatan…"></label>'+(dateIndex>=0?'<label>Dari '+escapeText(headers[dateIndex].toLowerCase())+'<input type="date" name="from"></label><label>Sampai '+escapeText(headers[dateIndex].toLowerCase())+'<input type="date" name="to"></label>':'')+fields.map(f=>'<label>'+escapeText(f.label)+'<select name="col'+f.index+'"><option value="">Semua</option></select></label>').join('')+'<button type="reset" class="trade-secondary">Reset Filter</button><p class="filter-result" role="status" aria-live="polite"></p>';
  box.append(form);table.parentElement.before(box);
  const status=form.querySelector('.filter-result');let rows=[];
  const apply=()=>{const data=new FormData(form),from=data.get('from')||'',to=data.get('to')||'';if(from&&to&&from>to){status.textContent='Tanggal awal tidak boleh melewati tanggal akhir.';rows.forEach(r=>{r.element.hidden=true});return;}
   let visible=0;for(const row of rows){const values=Object.fromEntries(fields.map(f=>['col'+f.index,data.get('col'+f.index)||'']));const show=matchesFilter(row,{search:data.get('search'),from,to,values});row.element.hidden=!show;if(show)visible++;}
   summary.textContent='Filter & Cari Riwayat ('+visible+'/'+rows.length+')';status.textContent=visible+' dari '+rows.length+' catatan'+(rows.length&&visible===0?' — tidak ada data sesuai filter.':'.');
   // Totals describe the visible expense rows, not the unfiltered list.
   if(table.tBodies[0].id==='expense-rows'){const sum=rows.filter(r=>!r.element.hidden).reduce((n,r)=>n+Number(r.element.dataset.amount||0),0);const label=root.querySelector('#expense-sum');if(label)label.textContent='Total hasil filter: Rp '+sum.toLocaleString('id-ID');}
  };
  refresh=()=>{rows=[...table.tBodies[0].rows].filter(r=>!r.cells[0]?.hasAttribute('colspan')).map(element=>{const cells=[...element.cells].map(cellText);const search=element.cloneNode(true);search.querySelectorAll('details.compact-reference').forEach(el=>el.replaceWith(document.createTextNode(el.dataset.full)));search.querySelectorAll('button,details').forEach(el=>el.remove());return {element,date:dateIndex<0?'':cells[dateIndex],search:search.textContent,...Object.fromEntries(fields.map(f=>['col'+f.index,cells[f.index]]))};});
   for(const f of fields){const select=form.elements.namedItem('col'+f.index),old=select.value;const opts=[...new Set(rows.map(r=>r['col'+f.index]).filter(Boolean))].sort((a,b)=>a.localeCompare(b,'id'));select.replaceChildren(new Option('Semua',''),...opts.map(v=>new Option(v,v)));select.value=opts.includes(old)?old:'';}
   apply();
  };
  form.onsubmit=e=>e.preventDefault();form.oninput=apply;form.onchange=apply;form.onreset=()=>queueMicrotask(apply);controls.set(table,refresh);refresh();
 }
 const scan=()=>root.querySelectorAll('table').forEach(setup);
 const observer=new MutationObserver(changes=>{const tables=new Set();for(const m of changes){const body=m.target.closest?.('tbody');if(body&&[...m.addedNodes,...m.removedNodes].some(n=>n.nodeName==='TR'))tables.add(body.closest('table'));else if([...m.addedNodes].some(n=>n.nodeType===1&&(n.matches('table')||n.querySelector('table'))))scan();}tables.forEach(t=>t?.isConnected&&setup(t));});
 observer.observe(root,{childList:true,subtree:true});scan();return ()=>observer.disconnect();
}
