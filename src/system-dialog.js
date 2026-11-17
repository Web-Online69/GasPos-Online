// Shared GASPOS notifications. No browser-origin titles or native alert/confirm/prompt.
const dialogQueue=[];
let active=false;
export function systemDialog(message,mode='notice',initial=''){
  return new Promise(resolve=>{
    dialogQueue.push({message:String(message??''),mode,initial:String(initial??''),resolve});
    if(!active)nextDialog();
  });
}
function nextDialog(){
  const job=dialogQueue.shift();
  if(!job){active=false;return;}
  active=true;
  const backdrop=document.createElement('div');backdrop.className='gaspos-confirm-backdrop';
  const dialog=document.createElement('section');dialog.className='gaspos-confirm-dialog';
  dialog.setAttribute('role',job.mode==='notice'?'alertdialog':'dialog');
  dialog.setAttribute('aria-modal','true');
  dialog.setAttribute('aria-labelledby','gaspos-system-title');
  dialog.setAttribute('aria-describedby','gaspos-system-message');
  const title=document.createElement('h2');title.id='gaspos-system-title';title.textContent='Sistem Menyatakan';
  const description=document.createElement('p');description.id='gaspos-system-message';description.textContent=job.message;
  dialog.append(title,description);
  let input=null;
  if(job.mode==='prompt'){
    input=document.createElement('textarea');input.className='gaspos-system-input';
    input.rows=3;input.value=job.initial;
    input.setAttribute('aria-label','Isi keterangan');dialog.append(input);
  }
  const actions=document.createElement('div');actions.className='gaspos-confirm-actions';
  const cancel=document.createElement('button');cancel.type='button';cancel.textContent='Batal';
  const okay=document.createElement('button');okay.type='button';
  okay.className='gaspos-confirm-continue';
  okay.textContent=job.mode==='notice'?'Tutup':job.mode==='prompt'?'Simpan':'Lanjutkan';
  if(job.mode!=='notice')actions.append(cancel);
  actions.append(okay);dialog.append(actions);backdrop.append(dialog);
  const previouslyFocused=document.activeElement;
  let complete=false;
  const done=value=>{
    if(complete)return;complete=true;
    document.removeEventListener('keydown',handleKey,true);
    backdrop.remove();
    job.resolve(value);
    if(previouslyFocused?.isConnected)previouslyFocused.focus();
    nextDialog();
  };
  const handleKey=e=>{
    if(e.key==='Escape'){e.preventDefault();done(job.mode==='prompt'?null:false);}
    if(e.key==='Tab'){
      const focusables=job.mode==='notice'?[okay]:job.mode==='prompt'?[input,cancel,okay]:[cancel,okay];
      const i=focusables.indexOf(document.activeElement);
      if((e.shiftKey&&i===0)||(!e.shiftKey&&i===focusables.length-1)){
        e.preventDefault();(e.shiftKey?focusables.at(-1):focusables[0]).focus();
      }
    }
    if(e.key==='Enter'&&job.mode!=='prompt'&&document.activeElement===okay){e.preventDefault();okay.click();}
  };
  document.addEventListener('keydown',handleKey,true);
  cancel.onclick=()=>done(job.mode==='prompt'?null:false);
  okay.onclick=()=>done(job.mode==='prompt'?input.value:true);
  backdrop.onclick=e=>{if(e.target===backdrop&&job.mode!=='notice')done(job.mode==='prompt'?null:false);};
  document.body.append(backdrop);
  (input|| (job.mode==='notice'?okay:cancel)).focus();
}
export const confirmGaspos=message=>systemDialog(message,'confirm');
export const notifyGaspos=message=>systemDialog(message,'notice');
export const promptGaspos=(message,initial='')=>systemDialog(message,'prompt',initial);
