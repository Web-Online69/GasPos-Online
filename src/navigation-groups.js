// Group only menus already authorized by the active role; never add permissions.
export function navigationGroups(menus, role) {
  const warehouseReturns = role === 'SALES_SOPIR' ? [] : ['cylinder_returns'];
  const definitions = [
    ['master', 'Master Data', ['gas_products', 'gas_partners', 'customers', 'gas_customer_prices']],
    ['trade', 'Pembelian & Penjualan', ['purchases', 'sales']],
    ['warehouse', 'Gudang / Logistik', ['warehouse_receipts', 'warehouse_dispatch', 'trip_returns', ...warehouseReturns, 'gas_stock_movements']],
    ['driver', 'Sales / Sopir', ['trips', ...(role === 'SALES_SOPIR' ? ['cylinder_returns'] : [])]],
    ['finance', 'Keuangan', ['gas_payments', 'operational', 'gas_financial_entries']],
    ['reports', 'Laporan', ['reports']],
    ['settings', 'Pengaturan', ['gas_members', 'invoice_profile']],
  ];
  return definitions.map(([id, label, ids]) => ({id, label, menus: ids.map(key => menus.find(menu => menu[0] === key)).filter(Boolean)})).filter(group => group.menus.length);
}
export function renderNavigation(menus, role, icon, escape) {
  const link = ([id, , label]) => '<button type="button" data-view="' + escape(id) + '" class="app-side-link app-nav-child"><span aria-hidden="true">' + icon(id) + '</span><span class="nav-item-label">' + escape(label) + '</span></button>';
  const home = menus.find(menu => menu[0] === 'ringkasan');
  return (home ? link(home) : '') + navigationGroups(menus, role).map(group => '<details class="app-nav-group" data-nav-group="' + group.id + '"><summary class="app-nav-group-title">' + group.label + '<span class="nav-group-count">' + group.menus.length + '</span></summary><div class="app-nav-children">' + group.menus.map(link).join('') + '</div></details>').join('');
}
