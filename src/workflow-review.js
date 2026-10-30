// Read-only work queues. Every query uses the signed-in client and existing RLS.
export async function loadWorkQueue(api, role) {
 const count=async(table,filters)=>{
  let query=api.from(table).select('id',{count:'exact',head:true});
  for(const [method,...args] of filters)query=query[method](...args);
  const result=await query;
  return result.error?null:result.count;
 };
 const trips=()=>count('gas_trips',[['eq','status','ON_ROUTE']]);
 const signatures=()=>count('gas_trip_stops',[['eq','receiver_confirmed',false]]);
 const tasks=[];
 if(['OWNER','LOGISTIK'].includes(role))tasks.push({label:'Pembelian menunggu barang',view:'warehouse_receipts',run:async()=>{const r=await api.rpc('gaspos_pending_purchase_lines');return r.error?null:new Set((r.data||[]).map(x=>x.document_id)).size}});
 if(role==='OWNER')tasks.push({label:'Faktur siap dikonfirmasi menjadi INV',view:'trips',run:()=>count('gas_trip_stops',[['eq','receiver_confirmed',true],['is','invoice_document_id',null]])});
 if(['OWNER','LOGISTIK','SALES_SOPIR'].includes(role))tasks.push({label:role==='SALES_SOPIR'?'Perjalanan saya belum selesai':'Perjalanan menunggu kembali',view:role==='SALES_SOPIR'?'trips':'trip_returns',run:trips});
 if(['OWNER','SALES_SOPIR'].includes(role))tasks.push({label:'Faktur belum ditandatangani',view:'trips',run:signatures});
 if(['OWNER','KEUANGAN'].includes(role)){
  const r=await api.from('gaspos_trade_balances').select('document_type,document_total,paid_total').eq('status','APPROVED');
  for(const [type,label] of [['SALE','INV menunggu uang masuk'],['PURCHASE','Pembelian belum lunas']])tasks.push({label,view:'gas_payments',run:async()=>r.error?null:(r.data||[]).filter(x=>x.document_type===type&&Number(x.document_total)>Number(x.paid_total)).length});
 }
 return Promise.all(tasks.map(async({label,view,run})=>({label,view,count:await run()})));
}

// Never interpolate stored signature values into SVG without numeric validation.
export function signatureSvg(strokes) {
 if(!Array.isArray(strokes)||JSON.stringify(strokes).length>12000)return '';
 const valid=strokes.length>0&&strokes.every(s=>Array.isArray(s)&&s.length>0&&s.every(p=>Array.isArray(p)&&p.length===2&&p.every(Number.isFinite)&&p[0]>=0&&p[0]<=320&&p[1]>=0&&p[1]<=160));
 if(!valid||strokes.reduce((n,s)=>n+s.length,0)<3)return '';
 return '<svg class="receipt-preview" xmlns="http://www.w3.org/2000/svg" viewBox="0 0 320 160" role="img" aria-label="Tanda tangan penerima">'+strokes.map(s=>'<polyline points="'+s.map(p=>p.join(',')).join(' ')+'" fill="none" stroke="#111" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/>').join('')+'</svg>';
}
