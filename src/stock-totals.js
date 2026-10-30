import {formatNumberId} from './indonesian-numbers.js';
export function summarizeStock(rows){
 const sums={full:0,empty:0,fullIn:0,fullOut:0,emptyIn:0,emptyOut:0};
 for(const row of rows){const full=Number(row.full),empty=Number(row.empty);if(!Number.isSafeInteger(full)||!Number.isSafeInteger(empty))throw Error('Data jumlah stok tidak valid');sums.full+=full;sums.empty+=empty;sums.fullIn+=Math.max(full,0);sums.fullOut+=Math.max(-full,0);sums.emptyIn+=Math.max(empty,0);sums.emptyOut+=Math.max(-empty,0);}
 return {...sums,total:sums.full+sums.empty};
}
export function stockTotalsHtml(rows,movement=false){
 const s=summarizeStock(rows),number=n=>(movement&&n>0?'+':'')+formatNumberId(n);
 const cards=[['Tabung Penuh',s.full,movement?'Masuk '+formatNumberId(s.fullIn)+' · Keluar '+formatNumberId(s.fullOut):'Saldo penuh'],['Tabung Kosong',s.empty,movement?'Masuk '+formatNumberId(s.emptyIn)+' · Keluar '+formatNumberId(s.emptyOut):'Saldo kosong'],[movement?'Total Perubahan':'Total Tabung',s.total,movement?'Penuh + kosong (bersih)':'Penuh + kosong']];
 return '<p class="stock-total-caption">'+(movement?'Total mutasi sesuai filter — perubahan bersih, bukan saldo akhir.':'Total saldo gudang sesuai filter.')+'</p><div class="stock-total-grid">'+cards.map(([label,value,note])=>'<div><span>'+label+'</span><strong>'+number(value)+'</strong><small>'+note+'</small></div>').join('')+'</div>';
}
