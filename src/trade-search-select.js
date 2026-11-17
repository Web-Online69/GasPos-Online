// Searchable, accessible trade select modeled after BMS.
// Keep the native select as the sole source of truth for validation and submission.
export function enhanceTradeSelect(select, label='Cari pilihan'){
  if(!select || select.dataset.tradeEnhanced==='1')return;
  select.dataset.tradeEnhanced='1';
  select.classList.add('trade-native-select');
  const box=document.createElement('div');
  box.className='trade-search-select';
  const input=document.createElement('input');
  input.type='search';
  input.className='trade-search-input';
  input.autocomplete='off';
  input.setAttribute('role','combobox');
  input.setAttribute('aria-autocomplete','list');
  input.setAttribute('aria-expanded','false');
  input.setAttribute('aria-label',label);
  input.placeholder=label;
  const list=document.createElement('div');
  list.className='trade-search-options';
  list.setAttribute('role','listbox');
  list.hidden=true;
  box.append(input,list);
  select.insertAdjacentElement('afterend',box);
  let open=false;
  const sync=()=>{
    const selected=select.selectedOptions[0];
    input.value=select.value && selected?selected.textContent.trim():'';
    input.placeholder=select.options[0]?.textContent.trim()||label;
    input.disabled=select.disabled;
    input.required=select.required;
    input.setAttribute('aria-invalid',select.validity.valid?'false':'true');
  };
  const close=()=>{open=false;list.hidden=true;input.setAttribute('aria-expanded','false');};
  const draw=(query='')=>{
    list.replaceChildren();
    const options=Array.from(select.options).filter(o=>!o.disabled);
    const term=query.toLocaleLowerCase('id-ID').trim();
    const found=options.filter(o=>o.textContent.toLocaleLowerCase('id-ID').includes(term)).slice(0,80);
    if(!found.length){
      const empty=document.createElement('div');
      empty.className='trade-search-empty';
      empty.textContent='Tidak ada pilihan yang cocok';
      list.append(empty);
    }
    for(const option of found){
      const btn=document.createElement('button');
      btn.type='button';
      btn.className='trade-search-option';
      btn.setAttribute('role','option');
      btn.setAttribute('aria-selected',String(option.selected));
      btn.textContent=option.textContent.trim();
      btn.addEventListener('click',()=>{
        select.value=option.value;
        sync();
        close();
        select.dispatchEvent(new Event('input',{bubbles:true}));
        select.dispatchEvent(new Event('change',{bubbles:true}));
      });
      list.append(btn);
    }
    open=true;list.hidden=false;input.setAttribute('aria-expanded','true');
  };
  input.addEventListener('focus',()=>{if(!select.disabled){input.select();draw('');}});
  input.addEventListener('input',()=>{select.value='';select.dispatchEvent(new Event('change',{bubbles:true}));draw(input.value);});
  input.addEventListener('keydown',e=>{
    if(e.key==='Escape'){close();sync();input.blur();}
    if(e.key==='ArrowDown'&&open){e.preventDefault();list.querySelector('button')?.focus();}
    if(e.key==='Enter'&&open){
      const first=list.querySelector('button');
      if(first){e.preventDefault();first.click();}
    }
  });
  list.addEventListener('keydown',e=>{
    if(e.key==='Escape'){close();input.focus();}
  });
  select.addEventListener('change',()=>{if(!open)sync();});
  select.addEventListener('invalid',e=>{e.preventDefault();input.setAttribute('aria-invalid','true');input.focus();draw('');});
  document.addEventListener('pointerdown',e=>{if(!box.isConnected)return;if(!box.contains(e.target))close();});
  // Programmatic selections (editing a draft) update the search label.
  const observer=new MutationObserver(()=>{if(!open)sync();});
  observer.observe(select,{childList:true,subtree:true});
  sync();
}

/** Enhance data selectors across the app, including content inserted asynchronously.
 * Native selects remain the underlying value/validation controls. Simple yes/no
 * and two-option switches retain native browser appearance. */
export function installGlobalSearchableSelects(root){
  if(!root || root.dataset.searchableSelectsInstalled==='1')return;
  root.dataset.searchableSelectsInstalled='1';
  const isDataSelect=select=>{
    if(!(select instanceof HTMLSelectElement))return false;
    if(select.dataset.tradeEnhanced==='1'||select.multiple||select.dataset.nativeSelect==='true')return false;
    if(select.closest('.trade-search-select,.trade-search-options,[role="listbox"]'))return false;
    const opts=[...select.options].filter(option=>!option.disabled);
    if(opts.length<3)return false;
    const values=opts.filter(o=>o.value!=='');
    if(values.length<2)return false;
    // Avoid replacing simple binary toggles and short workflow-state controls.
    if(values.length===2 && !/(partner|supplier|suplayer|pelanggan|customer|produk|product|tabung|barang|kandang|mitra|sopir|driver|perjalanan|trip|invoice|dokumen|document|akun|user|member)/i.test(
      [select.id,select.name,select.getAttribute('aria-label'),select.closest('label')?.textContent?.slice(0,75)].join(' ')
    ))return false;
    return true;
  };
  const enhance=select=>{
    if(!root.contains(select)||!select.closest('.app-shell')||!isDataSelect(select))return;
    const label=select.getAttribute('aria-label')||
      select.closest('label')?.textContent?.trim().slice(0,70)||
      select.previousElementSibling?.tagName==='LABEL'&&select.previousElementSibling.textContent?.trim()||
      'Cari pilihan data';
    enhanceTradeSelect(select,'Cari '+String(label).replace(/^Cari\s+/i,'').slice(0,60));
  };
  const scan=node=>{
    if(node instanceof HTMLSelectElement){enhance(node);return;}
    if(!(node instanceof Element))return;
    node.querySelectorAll('select:not([multiple])').forEach(enhance);
  };
  scan(root);
  const observer=new MutationObserver(records=>{
    for(const record of records){
      if(record.target instanceof HTMLOptionElement)enhance(record.target.closest('select'));
      else if(record.target instanceof HTMLSelectElement)enhance(record.target);
      for(const node of record.addedNodes)scan(node);
    }
  });
  observer.observe(root,{subtree:true,childList:true});
}
