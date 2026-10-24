const send=(body,status=200,headers={})=>new Response(JSON.stringify(body),{status,headers:{'content-type':'application/json','cache-control':'no-store',...headers}});
const bad=(message,status=400)=>send({error:message},status);
const bytes=x=>new TextEncoder().encode(x);
const hex=a=>[...new Uint8Array(a)].map(x=>x.toString(16).padStart(2,'0')).join('');
const hash=async x=>hex(await crypto.subtle.digest('SHA-256',bytes(x)));
const hashPass=async(p,s)=>{const key=await crypto.subtle.importKey('raw',bytes(p),'PBKDF2',false,['deriveBits']);return hex(await crypto.subtle.deriveBits({name:'PBKDF2',salt:bytes(s),iterations:210000,hash:'SHA-256'},key,256));};
const tokenCookie=(token,maxAge)=>'gaspos_session='+token+'; Path=/; HttpOnly; Secure; SameSite=Strict; Max-Age='+maxAge;
async function session(req,db){let token=(req.headers.get('Cookie')||'').match(/(?:^|;\s*)gaspos_session=([^;]+)/)?.[1];if(!token)return null;return await db.prepare('SELECT u.id,u.role FROM sessions s JOIN users u ON u.id=s.user_id WHERE s.token_hash=? AND s.expires_at>? AND u.active=1').bind(await hash(token),Date.now()).first();}
const uid=()=>crypto.randomUUID();
const whole=v=>Number.isSafeInteger(Number(v))&&Number(v)>=0;
export default {async fetch(req,env){
 const path=new URL(req.url).pathname;
 if(!path.startsWith('/api/'))return env.ASSETS.fetch(req);
 try{
  if(req.method==='POST'&&req.headers.get('origin')&&new URL(req.headers.get('origin')).origin!==new URL(req.url).origin)return bad('Origin tidak sesuai',403);
  const db=env.DB;
  if(path==='/api/login'&&req.method==='POST'){
   const b=await req.json(),u=await db.prepare('SELECT * FROM users WHERE username=? AND active=1').bind(String(b.username||'')).first();
   if(!u||await hashPass(String(b.password||''),u.salt)!==u.password_hash)return bad('Akun atau password salah',401);
   const token=uid()+uid();await db.prepare('INSERT INTO sessions(token_hash,user_id,expires_at) VALUES(?,?,?)').bind(await hash(token),u.id,Date.now()+86400000).run();
   return send({role:u.role},200,{'set-cookie':tokenCookie(token,86400)});
  }
  if(path==='/api/logout'&&req.method==='POST'){
   const token=(req.headers.get('Cookie')||'').match(/(?:^|;\s*)gaspos_session=([^;]+)/)?.[1];
   if(token)await db.prepare('DELETE FROM sessions WHERE token_hash=?').bind(await hash(token)).run();
   return send({ok:true},200,{'set-cookie':tokenCookie('',0)});
  }
  const user=await session(req,db);if(!user)return bad('Silakan login',401);
  const owner=user.role==='OWNER';
  if(path==='/api/me')return send({role:user.role});
  if(path==='/api/data'){
   const [p,d]=await Promise.all([db.prepare('SELECT id,code,name FROM products ORDER BY name').all(),db.prepare('SELECT id,number,kind,product_id,qty,empty_qty,status,reference,created_at FROM documents ORDER BY created_at DESC LIMIT 150').all()]);
   return send({products:p.results,documents:d.results});
  }
  if(path==='/api/stock'){
   const r=await db.prepare('SELECT p.id,p.name,p.stock_full_open+COALESCE((SELECT SUM(e.delta_full) FROM stock_events e JOIN documents d ON d.id=e.document_id WHERE d.product_id=p.id),0) full,p.stock_empty_open+COALESCE((SELECT SUM(e.delta_empty) FROM stock_events e JOIN documents d ON d.id=e.document_id WHERE d.product_id=p.id),0) empty FROM products p ORDER BY p.name').all();
   return send({rows:r.results});
  }
  if(path==='/api/products'&&req.method==='POST'&&owner){
   const b=await req.json(),code=String(b.code||'').trim(),name=String(b.name||'').trim();
   if(!code||!name)return bad('Kode dan nama wajib diisi');
   await db.prepare('INSERT INTO products(id,code,name) VALUES(?,?,?)').bind(uid(),code,name).run();return send({ok:true});
  }
  if(path==='/api/documents'&&req.method==='POST'&&user.role==='LOGISTIK'){
   const b=await req.json(),qty=Number(b.qty),empty=Number(b.emptyQty||0);
   if(!['IN_FULL','OUT_FULL'].includes(b.kind)||!Number.isSafeInteger(qty)||qty<1||!whole(empty))return bad('Jumlah atau jenis pergerakan salah');
   const item=await db.prepare('SELECT id FROM products WHERE id=?').bind(b.productId).first();if(!item)return bad('Gas tidak ditemukan');
   const id=uid();await db.prepare("INSERT INTO documents(id,number,kind,origin,product_id,qty,empty_qty,status,reference,created_by) VALUES(?,?,?,?,?,?,?,'PENDING',?,?)").bind(id,'LOG-'+Date.now()+'-'+id.slice(0,6),b.kind,'LOGISTIK',item.id,qty,empty,String(b.reference||''),user.id).run();
   return send({id});
  }
  const m=path.match(/^\/api\/documents\/([a-f0-9-]+)\/approve$/i);
  if(m&&req.method==='POST'&&owner){
   const b=await req.json(),price=Number(b.price);
   if(!whole(price))return bad('Harga tidak valid');
   const d=await db.prepare('SELECT * FROM documents WHERE id=?').bind(m[1]).first();
   if(!d||d.status!=='PENDING')return bad('Pengajuan tidak tersedia');
   const full=d.kind==='OUT_FULL'?-d.qty:d.qty,empty=d.kind==='OUT_FULL'?d.empty_qty:-d.empty_qty;
   const stock=await db.prepare('SELECT p.stock_full_open+COALESCE((SELECT SUM(e.delta_full) FROM stock_events e JOIN documents z ON z.id=e.document_id WHERE z.product_id=p.id),0) full,p.stock_empty_open+COALESCE((SELECT SUM(e.delta_empty) FROM stock_events e JOIN documents z ON z.id=e.document_id WHERE z.product_id=p.id),0) empty FROM products p WHERE p.id=?').bind(d.product_id).first();
   if(!stock||stock.full+full<0||stock.empty+empty<0)return bad('Stok tidak mencukupi');
   const unique=uid();
   const result=await db.batch([
     db.prepare("UPDATE documents SET status='APPROVED',received_qty=qty WHERE id=? AND status='PENDING'").bind(d.id),
     db.prepare("INSERT INTO stock_events(id,document_id,delta_full,delta_empty,qty) SELECT ?,id,?,?,qty FROM documents WHERE id=? AND status='APPROVED'").bind(uid(),full,empty,d.id),
     db.prepare("INSERT INTO financials(document_id,price,total,paid,invoice_number) SELECT id,?,qty*?,0,? FROM documents WHERE id=? AND status='APPROVED'").bind(price,price,'INV-'+unique.slice(0,8),d.id)
   ]);
   if(result[0]?.meta?.changes!==1)return bad('Dokumen sudah diproses',409);return send({ok:true});
  }
  return bad('Akses atau fitur tidak tersedia',403);
 }catch(e){return bad('Operasi gagal: '+(e.message||'kesalahan'),500);}
}};
