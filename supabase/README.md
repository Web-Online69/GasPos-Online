# Supabase GASPOS

Project: `gaspos-online` (`lflnbaqpmkjjyxpznozg`)
Organization: GuzLeiteWebApp
Region: ap-southeast-1 (Singapore)
Dashboard: https://supabase.com/dashboard/project/lflnbaqpmkjjyxpznozg

## Database changes already applied

1. `initialize_gaspos_private_core`: 9 public tables created with RLS enabled.
2. `gaspos_role_based_access_policies`: role lookup using private database function and separate access for Owner and Logistik. 13 RLS policies verified on 9 tables.

Existing tables:
`gas_products`, `gas_partners`, `gas_members`, `gas_customer_prices`, `gas_documents`, `gas_document_items`, `gas_stock_movements`, `gas_financial_entries`, `gas_payments`.

## Security model

- Auth identities are supplied by Supabase Auth. Roles are stored in `gas_members`, not editable user metadata.
- Owner and Logistik have read access to products, partners, documents, items and stock movement records.
- Logistik **cannot select** the financial tables (`gas_customer_prices`, `gas_financial_entries`, `gas_payments`).
- Users may create only own draft/pending documents and add items only to own draft documents.
- Direct mutation of stock events and direct approval of documents is currently blocked for all client roles pending secure transactional RPC implementation.
- No admin/service-role credential should be placed in browser code or committed to GitHub.

## Remaining before live use

- Provision Owner and Logistik users securely; validate ownership and session claims.
- Implement transactional, idempotent approval, partial receipts, reserved stock, empty cylinders in transit and invoice numbering in server-side functions.
- Implement UI with Supabase Auth; verify row and column access by signing in as each role.
- Print Surat Jalan (no prices) and Owner-only Invoice; test totals and report.
- Backups, security advisors, index / capacity review.
- Hosting/domain remains undecided.

This is not production ready. BMS is not modified.
