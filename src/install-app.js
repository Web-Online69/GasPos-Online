// Installation never creates accounts or reads credentials.
let installPrompt=null,banner=null;
const installed=()=>window.matchMedia('(display-mode: standalone)').matches||window.navigator.standalone===true;
const remove=()=>{banner?.remove();banner=null;installPrompt=null;};
window.addEventListener('appinstalled',remove);
window.addEventListener('beforeinstallprompt',event=>{
 if(installed())return;
 event.preventDefault();installPrompt=event;
 if(banner)return;
 banner=document.createElement('aside');banner.className='gaspos-install';banner.setAttribute('aria-label','Pasang aplikasi GASPOS');
 banner.innerHTML='<span><strong>GASPOS</strong><small>Pasang di layar utama</small></span><button type="button" data-install>Pasang</button><button type="button" data-dismiss aria-label="Tutup tawaran pemasangan">×</button>';
 const style=document.createElement('style');style.textContent='.gaspos-install{display:flex;align-items:center;gap:12px;padding:10px max(14px,env(safe-area-inset-right)) 10px max(14px,env(safe-area-inset-left));background:#193441;color:#eff9fa;border-bottom:1px solid #3c6274;font:13px system-ui}.gaspos-install>span{flex:1;min-width:0}.gaspos-install strong,.gaspos-install small{display:block}.gaspos-install small{color:#b9d2dd;margin-top:2px}.gaspos-install button{width:auto;flex:none;min-height:44px;padding:8px 14px;border:1px solid #5aa9a6;border-radius:8px;background:#138d92;color:white;font:600 13px system-ui;cursor:pointer}.gaspos-install button[data-dismiss]{background:transparent;border-color:transparent;font-size:20px;padding:6px 12px}.gaspos-install button:focus-visible{outline:3px solid #9aeee0;outline-offset:2px}';banner.append(style);document.body.prepend(banner);
 banner.querySelector('[data-dismiss]').onclick=remove;
 banner.querySelector('[data-install]').onclick=async()=>{if(!installPrompt)return;const button=banner.querySelector('[data-install]'),prompt=installPrompt;installPrompt=null;button.disabled=true;try{await prompt.prompt();await prompt.userChoice;}catch{}finally{remove();}};
});
if('serviceWorker' in navigator){const register=()=>navigator.serviceWorker.register(import.meta.env.BASE_URL+'sw.js',{scope:import.meta.env.BASE_URL,updateViaCache:'none'}).catch(()=>{});if(document.readyState==='complete')register();else window.addEventListener('load',register,{once:true});}
