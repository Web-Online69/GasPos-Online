# Stock totals for Logistics

The Total Rincian Tabung page read gaspos_stock_balances, a security-invoker view joining document items. Logistics cannot read document items containing trade-related data, so the query returned no rows and warehouse totals incorrectly showed zero. Actual stock was intact.

Changed the page to the existing gaspos_logistics_balances RPC, already used by the stock screen. It returns product IDs and physical full/empty quantities only to Owner and Logistics. No stock, pricing, or RLS policies were changed.

Verified against the live database under authenticated Logistics: the old view returned zero rows; the RPC returned 12 kg full 15 / empty 157, 5.5 kg full 4, 50 kg full 8. Financial entries remained inaccessible (0 rows). Under authenticated Owner the RPC returned warehouse total 184 and customer custody 230, combined 414. Build and three cylinder overview tests passed locally. Public signed-in browser verification remains outstanding.
