import {readAll} from './history-filters.js';
// Read-only work queues. Every query uses the signed-in client and existing RLS.
export const workRoleNames={OWNER:'Owner',LOGISTIK:'Logistik',SALES_SOPIR:'Sopir',KEUANGAN:'Keuangan'};
export async function loadWorkQueue(api,role,options={}){
 const overview=options.ownerOverview===true;
 const count=async(table,filters)=>{
  let query=api.from(table).select('id',{count:'exact',head:true});
  for(const [method,...args] of filters)query=query[method](...args);
  const result=await query;
  return result.error?null:result.count;
 };
 const tasks=[];
 const add=(label,view,run,category='action')=>tasks.push({label,view,run,category});
 const pendingPurchases=async()=>{
  const result=await api.rpc('gaspos_pending_purchase_lines');
  return result.error?null:new Set((result.data||[]).map(x=>x.document_id)).size;
 };
 const trips=async(driverOnly=false)=>{
  let query=api.from('gas_trips').select('id,request_id,status,driver_user_id,gas_logistics_requests(sj_group_id)').eq('status','ON_ROUTE').order('id');
  if(driverOnly){
   const user=await api.auth.getUser();
   if(user.error||!user.data?.user)return null;
   query=query.eq('driver_user_id',user.data.user.id);
  }
  const result=await readAll(query);
  return result.error?null:new Set((result.data||[]).map(t=>t.gas_logistics_requests?.sj_group_id||t.request_id||t.id)).size;
 };
 const unsignedStops=async(driverOnly=false)=>{
  if(!driverOnly)return count('gas_trip_stops',[['eq','receiver_confirmed',false]]);
  const user=await api.auth.getUser();
  if(user.error||!user.data?.user)return null;
  const tripResult=await readAll(api.from('gas_trips').select('id').eq('driver_user_id',user.data.user.id));
  if(tripResult.error)return null;
  const ids=(tripResult.data||[]).map(x=>x.id);
  if(!ids.length)return 0;
  return count('gas_trip_stops',[['eq','receiver_confirmed',false],['in','trip_id',ids]]);
 };
 if(role==='OWNER'){
  add('Draft Pembelian perlu ditinjau','purchases',()=>count('gas_documents',[['eq','document_type','PURCHASE'],['eq','status','DRAFT']]));
  add('Draft Penjualan perlu ditinjau','sales',()=>count('gas_documents',[['eq','document_type','SALE'],['eq','status','DRAFT']]));
  add('Faktur Sopir menunggu pembuatan INV','trips',()=>count('gas_trip_stops',[['eq','receiver_confirmed',true],['is','invoice_document_id',null]]));
  add('Pembelian menunggu penerimaan Gudang','purchases',pendingPurchases,'monitor');
  add('Perjalanan masih berlangsung','trips',()=>trips(false),'monitor');
 }
 if(role==='LOGISTIK'){
  add('Pembelian menunggu penerimaan','warehouse_receipts',pendingPurchases);
  add('Perjalanan menunggu kembali','trip_returns',()=>trips(false));
  add('Tabung kosong menunggu penerimaan Gudang','cylinder_returns',()=>count('gas_customer_cylinder_returns',[['eq','status','IN_VEHICLE'],['is','trip_id',null]]));
 }
 if(role==='SALES_SOPIR'){
  add(overview?'Perjalanan Sopir belum selesai':'Perjalanan saya belum selesai','trips',()=>trips(!overview));
  add(overview?'Faktur Sopir belum ditandatangani':'Faktur perjalanan saya belum ditandatangani','trips',()=>unsignedStops(!overview));
 }
 if(role==='KEUANGAN'||role==='OWNER'){
  const r=await api.from('gaspos_trade_balances').select('document_type,document_total,paid_total').eq('status','APPROVED');
  for(const [type,label] of [['SALE','Penjualan menunggu pembayaran'],['PURCHASE','Pembelian belum lunas']]){
   add(label,'gas_payments',async()=>r.error?null:(r.data||[]).filter(x=>x.document_type===type&&Number(x.document_total)>Number(x.paid_total)).length,role==='OWNER'?'monitor':'action');
  }
 }
 const results=await Promise.all(tasks.map(async({label,view,run,category})=>{
  try{return {label,view,category,count:await run()};}
  catch{return {label,view,category,count:null};}
 }));
 return results;
}

// Never interpolate stored signature values into SVG without numeric validation.
export function signatureSvg(strokes) {
 if(!Array.isArray(strokes)||JSON.stringify(strokes).length>12000)return '';
 const valid=strokes.length>0&&strokes.every(s=>Array.isArray(s)&&s.length>0&&s.every(p=>Array.isArray(p)&&p.length===2&&p.every(Number.isFinite)&&p[0]>=0&&p[0]<=320&&p[1]>=0&&p[1]<=160));
 if(!valid||strokes.reduce((n,s)=>n+s.length,0)<3)return '';
 return '<svg class="receipt-preview" xmlns="http://www.w3.org/2000/svg" viewBox="0 0 320 160" role="img" aria-label="Tanda tangan penerima">'+strokes.map(s=>'<polyline points="'+s.map(p=>p.join(',')).join(' ')+'" fill="none" stroke="#111" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/>').join('')+'</svg>';
}
