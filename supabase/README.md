# Supabase GASPOS

Proyek gaspos-online (`lflnbaqpmkjjyxpznozg`), terpisah dari BMS.

Empat peran: OWNER, LOGISTIK, SALES_SOPIR, KEUANGAN. Otorisasi memakai keanggotaan aktif di gas_members, RLS dan RPC. Akun petugas dibuat Owner melalui Edge Function gaspos-invite-member tanpa undangan email.

Audit 27 Oktober 2026: lihat [laporan dan batas verifikasi](../docs/audit/2026-10-27.md). SQL audit sudah diterapkan ke proyek melalui migrasi Supabase dan disimpan di audit_access_and_receipts.sql serta audit_finance.sql. File ini merupakan patch terhadap skema yang sudah ada, bukan installer database kosong. Fixture skema tanpa data produksi untuk pengujian ada di scripts/audit/fixtures.

Penerimaan pembelian harus menggunakan pengajuan pembelian terkait agar ACC memperbarui pembelian dan stok tepat satu kali. Jalur mutasi umum terpisah dari pembelian. Jangan menerima pembelian yang sama lagi melalui jalur lain.

Login Owner aman sudah diuji. Live trial empat akun masih memerlukan pembuatan credential petugas dan pengujian. Edge Function gaspos-invite-member versi 5 menggunakan native fetch; sumber disimpan di functions/gaspos-invite-member/index.ts. Build dan uji lokal bukan pengganti pengujian tersebut. Jangan menyimpan service-role key atau password di frontend/repository.
