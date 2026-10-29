// Small, local SVG illustrations: identical shapes on desktop and phones.
const icons = {
  ringkasan: ['#5fcdd4', '<path d="m3 11 9-8 9 8"/><path d="M5 10v10h14V10" fill="currentColor" fill-opacity=".22"/><path d="M10 20v-7h4v7"/>'],
  gas_products: ['#ee90c5', '<path d="M9 5V3h6v2M10 3V2h4v1"/><rect x="6" y="5" width="12" height="16" rx="4" fill="currentColor" fill-opacity=".32"/><path d="M6 10h12M6 17h12M10 21v1m4-1v1"/><path d="M12 11c-3 3-2 5 0 5s3-2 0-5" fill="#ffd48a" stroke="#ffd48a"/>'],
  gas_partners: ['#f1b76b', '<path d="M3 8h18v13H3z" fill="currentColor" fill-opacity=".2"/><path d="m2 8 10-6 10 6M8 21v-8h8v8M6 10h1m10 0h1"/><path d="M11 16h2" stroke="#8ce2d3"/>'],
  customers: ['#78b9f6', '<circle cx="12" cy="7" r="4" fill="currentColor" fill-opacity=".35"/><path d="M4 21v-3a8 8 0 0 1 16 0v3Z" fill="currentColor" fill-opacity=".22"/><path d="m9 15 3 3 3-3" stroke="#ffd28f"/>'],
  purchases: ['#f3b66f', '<path d="M2 3h3l2 12h12l3-9H6" fill="currentColor" fill-opacity=".22"/><circle cx="9" cy="20" r="1.5" fill="currentColor"/><circle cx="18" cy="20" r="1.5" fill="currentColor"/><path d="M13 3v8m-3-3 3 3 3-3" stroke="#9ee6dc"/>'],
  sales: ['#7ed7b4', '<path d="M6 2h12v20l-3-2-3 2-3-2-3 2Z" fill="currentColor" fill-opacity=".22"/><path d="M9 6h6M9 10h3m-3 4h6"/><path d="m14 9 2-2 2 2m-2-2v7" stroke="#ffd48a"/>'],
  logistics: ['#9ab3fa', '<path d="m3 7 9-5 9 5v11l-9 4-9-4Z" fill="currentColor" fill-opacity=".24"/><path d="m3 7 9 5 9-5M12 12v10M8 4l9 5v5"/><path d="m5 15 4 2" stroke="#ffd48a"/>'],
  trips: ['#78bff5', '<path d="M2 5h12v12H2Z" fill="currentColor" fill-opacity=".35"/><path d="M14 9h4l4 5v3h-8Z" fill="#efae76" stroke="#efae76"/><path d="M15 10h3l2 3h-5Z" fill="#192d3b" stroke="none"/><circle cx="6" cy="18" r="2.5" fill="#192d3b"/><circle cx="18" cy="18" r="2.5" fill="#192d3b"/><path d="M5 8h6m-6 3h4" stroke="#d4efff"/>'],
  gas_stock_movements: ['#6bd4cc', '<path d="M4 4h16v17H4Z" fill="currentColor" fill-opacity=".2"/><path d="M8 2v4m8-4v4M4 9h16"/><path d="M7 13h9m-3-2 3 2-3 2M17 18H8m3-2-3 2 3 2" stroke="#ffd48a"/>'],
  gas_payments: ['#7bd8a8', '<rect x="2" y="5" width="20" height="15" rx="3" fill="currentColor" fill-opacity=".25"/><path d="M3 5V3h15v2"/><path d="M16 10h6v6h-6a3 3 0 0 1 0-6Z" fill="#f0c371" stroke="#f0c371"/><circle cx="17" cy="13" r=".8" fill="#192d3b" stroke="none"/>'],
  gas_financial_entries: ['#b6a1f4', '<path d="M4 3v18h17"/><rect x="7" y="12" width="3" height="6" rx="1" fill="currentColor"/><rect x="12" y="8" width="3" height="10" rx="1" fill="#79d5c0" stroke="#79d5c0"/><rect x="17" y="4" width="3" height="14" rx="1" fill="#efc47b" stroke="#efc47b"/>'],
  operational: ['#f4aa84', '<path d="M5 2h14v20l-3-2-4 2-4-2-3 2Z" fill="currentColor" fill-opacity=".2"/><path d="M8 6h8M8 10h5"/><circle cx="13" cy="16" r="3" fill="#f0ce7b" stroke="#f0ce7b"/><path d="M12 16h2" stroke="#493c28"/>'],
  gas_customer_prices: ['#f2cf7c', '<path d="M3 3h8l10 10-8 8L3 11Z" fill="currentColor" fill-opacity=".3"/><circle cx="7.5" cy="7.5" r="1.5" fill="#192d3b"/><path d="m11 11 5 5m0-5-5 5" stroke="#a1e1d5"/>'],
  gas_members: ['#bea1f1', '<circle cx="9" cy="7" r="3" fill="currentColor" fill-opacity=".4"/><path d="M2 21v-3a7 7 0 0 1 14 0v3Z" fill="currentColor" fill-opacity=".24"/><circle cx="18" cy="8" r="2.5" fill="#7cc9df" stroke="#7cc9df"/><path d="M18 14a5 5 0 0 1 4 5v2" stroke="#7cc9df"/>'],
  master_data: ['#86baf6', '<rect x="3" y="3" width="7" height="7" rx="2" fill="currentColor" fill-opacity=".45"/><rect x="14" y="3" width="7" height="7" rx="2" fill="#dfa1cc" stroke="#dfa1cc"/><rect x="3" y="14" width="7" height="7" rx="2" fill="#83d5c4" stroke="#83d5c4"/><rect x="14" y="14" width="7" height="7" rx="2" fill="#edc57b" stroke="#edc57b"/>'],
  reports: ['#87c8f3', '<path d="M5 2h10l4 4v16H5Z" fill="currentColor" fill-opacity=".22"/><path d="M14 2v5h5M8 17v-4m4 4v-7m4 7v-3" stroke="#edd18c"/>'],
  transactions: ['#86d6c8', '<path d="M3 7h17m-4-4 4 4-4 4"/><path d="M21 17H4m4-4-4 4 4 4" stroke="#edbc83"/>']
};
export function menuIcon(id) {
  const [color, drawing] = icons[id] || icons.master_data;
  return '<svg class="menu-illustration" viewBox="0 0 24 24" width="28" height="28" fill="none" stroke="currentColor" stroke-width="1.6" stroke-linecap="round" stroke-linejoin="round" style="color:'+color+'" aria-hidden="true" focusable="false">'+drawing+'</svg>';
}
