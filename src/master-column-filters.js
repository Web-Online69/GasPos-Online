// BMS-style per-column filtering for GASPOS master tables.
// Presentation and client-side filtering only; database queries and permissions stay intact.
export function attachMasterColumnFilters({toolbar,fields,onFilter}){
  if(!toolbar || !Array.isArray(fields))return () => true;
  const wrap=document.createElement('div');
  wrap.className='master-column-controls';
  const toggle=document.createElement('button');
  toggle.type='button';
  toggle.className='master-filter-toggle';
  toggle.textContent='Filter Kolom';
  toggle.setAttribute('aria-expanded','false');
  const panel=document.createElement('div');
  panel.className='master-filter-panel';
  panel.hidden=true;
  const values=Object.create(null);
  for(const field of fields){
    const label=document.createElement('label');
    const title=document.createElement('span');
    title.textContent=field.label;
    const input=document.createElement('input');
    input.type='search';
    input.placeholder='Cari '+field.label.toLowerCase();
    input.setAttribute('aria-label','Filter '+field.label);
    input.addEventListener('input',()=>{values[field.key]=input.value.trim().toLocaleLowerCase('id-ID');onFilter();});
    label.append(title,input);
    panel.append(label);
  }
  const reset=document.createElement('button');
  reset.type='button';
  reset.className='master-filter-reset';
  reset.textContent='Reset Filter';
  reset.addEventListener('click',()=>{panel.querySelectorAll('input').forEach(input=>{input.value='';});for(const field of fields)values[field.key]='';onFilter();});
  panel.append(reset);
  toggle.addEventListener('click',()=>{
    panel.hidden=!panel.hidden;
    toggle.setAttribute('aria-expanded',String(!panel.hidden));
    if(!panel.hidden)panel.querySelector('input')?.focus();
  });
  wrap.append(toggle,panel);
  toolbar.insertAdjacentElement('afterend',wrap);
  return record=>fields.every(field=>!values[field.key]||String(record[field.key]??'').toLocaleLowerCase('id-ID').includes(values[field.key]));
}
