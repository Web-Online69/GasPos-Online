// Group only menus already authorized by the active role; never add permissions.
export function navigationGroups(menus, role) {
  const warehouseReturns = role === 'SALES_SOPIR' ? [] : ['cylinder_returns'];
  const definitions = [
    ['master', 'Master Data', ['gas_products', 'gas_partners', 'customers', 'gas_customer_prices']],
    ['trade', 'Pembelian & Penjualan', ['purchases', 'sales']],
    ['warehouse', 'Gudang / Logistik', ['cylinder_overview', 'warehouse_receipts', 'warehouse_dispatch', 'trip_returns', ...warehouseReturns, 'gas_stock_movements']],
    ['driver', 'Sales / Sopir', ['trips', ...(role === 'SALES_SOPIR' ? ['cylinder_returns'] : [])]],
    ['finance', 'Keuangan', ['gas_payments', 'operational', 'gas_financial_entries']],
    ['reports', 'Laporan', ['reports']],
    ['settings', 'Pengaturan', ['gas_members', 'invoice_profile']],
  ];
  // One feature belongs to only one section. The "logistics" landing page
  // repeats links to receipt/dispatch/returns, so hide it when those direct
  // links are present; keep the underlying route for backwards compatibility.
  const used = new Set();
  return definitions.map(([id,label,ids])=>{
    const entries = ids.filter(key=>!(key==='logistics'&&menus.some(item=>['warehouse_receipts','warehouse_dispatch','trip_returns'].includes(item[0]))))
      .map(key=>menus.find(item=>item[0]===key))
      .filter(item=>item&&!used.has(item[0]));
    for(const item of entries)used.add(item[0]);
    return {id,label,menus:entries};
  }).filter(group=>group.menus.length);
}
export function renderNavigation(menus, role, icon, escape) {
  const link = ([id, , label]) => '<button type="button" data-view="' + escape(id) + '" class="app-side-link app-nav-child"><span aria-hidden="true">' + icon(id) + '</span><span class="nav-item-label">' + escape(label) + '</span></button>';
  const home = menus.find(menu => menu[0] === 'ringkasan');
  return (home ? link(home) : '') + '<button type="button" data-view="work_queue" class="app-side-link app-nav-child"><span aria-hidden="true">▣</span><span class="nav-item-label">Pekerjaan Saya</span></button>' + navigationGroups(menus, role).map(group => '<details class="app-nav-group" data-nav-group="' + group.id + '"><summary class="app-nav-group-title">' + group.label + '<span class="nav-group-count">' + group.menus.length + '</span></summary><div class="app-nav-children">' + group.menus.map(link).join('') + '</div></details>').join('');
}

/** Compact home dashboard groups. Show only menus belonging to the current workspace. */
export function dashboardMenuGroups(menus) {
 const groups=[
  {id:'trade',label:'Pembelian & Penjualan',icon:'⇄',ids:['purchases','sales']},
  {id:'warehouse',label:'Logistik',icon:'▤',ids:['warehouse_receipts','warehouse_dispatch','trip_returns','cylinder_returns','cylinder_overview','gas_stock_movements','logistics']},
  {id:'driver',label:'Sopir',icon:'🚚',ids:['trips']},
  {id:'finance',label:'Keuangan',icon:'▣',ids:['gas_payments','gas_financial_entries','operational']},
  {id:'master',label:'Master Data',icon:'▦',ids:['gas_products','gas_partners','customers','gas_customer_prices']},
  {id:'report',label:'Laporan',icon:'▥',ids:['reports']},
  {id:'settings',label:'Pengaturan',icon:'⚙',ids:['gas_members','invoice_profile']}
 ];
 const used=new Set(['ringkasan']);
 const result=groups.map(group=>{
  const hasWarehouseActions=group.id==='warehouse'&&group.ids.some(id=>['warehouse_receipts','warehouse_dispatch','trip_returns'].includes(id)&&menus.some(item=>item[0]===id));
  if(hasWarehouseActions)used.add('logistics');
  const entries=group.ids
   .filter(key=>!(hasWarehouseActions&&key==='logistics'))
   .map(key=>menus.find(item=>item[0]===key))
   .filter(item=>item&&!used.has(item[0]));
  for(const entry of entries)used.add(entry[0]);
  return {...group,menus:entries};
 }).filter(group=>group.menus.length);
 const extra=menus.filter(item=>!used.has(item[0]));
 if(extra.length)result.push({id:'other',label:'Menu Lainnya',icon:'▤',menus:extra});
 return result;
}
