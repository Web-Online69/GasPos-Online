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
  input.addEventListener('input',()=>{select.value='';draw(input.value);});
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
  select.addEventListener('change',sync);
  select.addEventListener('invalid',e=>{e.preventDefault();input.setAttribute('aria-invalid','true');input.focus();draw('');});
  document.addEventListener('pointerdown',e=>{if(!box.isConnected)return;if(!box.contains(e.target))close();});
  // Programmatic selections (editing a draft) update the search label.
  const observer=new MutationObserver(()=>{if(!open)sync();});
  observer.observe(select,{childList:true,subtree:true});
  sync();
}
