# Several cylinder types on one visible Surat Jalan

The warehouse form previously supported one product only. It now offers add/remove load rows and submits all products atomically. The existing per-product dispatch and trip procedures remain responsible for stock, driver authorization, deliveries, invoices, and returns. `sj_group_id` groups these records under the first request. Warehouse history and driver trip lists display one group and SJ printing lists every product. Driver detail has a product selector; warehouse group return submits every product together. Existing single-product trips remain supported.

Local isolated database test verifies two products, stock deduction once, unchanged retry with reversed row order, duplicate-product rejection, rollback for insufficient stock on any product, role rejection, per-product delivery capacity, signed deliveries, atomic return rejection, repeated return idempotence, and invoice creation without a second stock movement. All 52 workflow tests passed; final targeted test and build passed after final validation refinements.

Live migration `multiple_product_delivery_sj` applied successfully. Anonymous execution of both new RPCs is denied. Existing live trip count remains 1; warehouse physical total remains 184 and customer custody remains 230. No new production trial dispatch or invoice was created. Security advisors report no new errors; the authenticated security-definer warning for guarded RPCs is expected. Existing unrelated advisor findings remain.

Public signed-in browser operation and physical printing of a multi-load SJ remain to be verified; isolated tests are not a live transaction claim.
