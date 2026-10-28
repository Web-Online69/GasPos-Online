# Alur sederhana dan form vertikal — 28 Oktober 2026

Acuan pengguna: Owner pembelian → Logistik konfirmasi datang → Logistik SJ untuk Sopir → Sopir Faktur Penjualan per pelanggan tanpa harga → Owner harga/konfirmasi/cetak INV → Keuangan konfirmasi uang masuk.

## Perubahan
- Konfirmasi penerimaan oleh Logistik langsung memperbarui pembelian dan stok, tanpa ACC Owner tambahan.
- Pembuatan SJ, pengeluaran stok, penugasan Sopir dan kendaraan satu transaksi.
- Kedua formulir mengirim ID permintaan tetap; pengulangan aman tidak memposting stok lagi.
- Owner dapat mengonfirmasi faktur penerima yang sah saat perjalanan ON_ROUTE atau RETURNED. Harga tetap Owner; INV tidak memposting stok.
- Penguncian trip/stop selaras untuk mencegah invoice per kunjungan dan gabungan saling bertabrakan.
- Keuangan hanya mencatat uang masuk terhadap INV yang sudah dikonfirmasi. Jalur pembayaran supplier tetap ada.
- Semua isian vertikal satu kolom, label di atas; termasuk login, master, pembelian, gudang, SJ, faktur, tanda tangan, konfirmasi INV, pembayaran, biaya dan akun.
- Data tambahan pembelian dan tanggal INV opsional tertutup; form utama ringkas. Nomor faktur FK otomatis, bukan isian tambahan.
- Penulisan ledger keuangan langsung dari client ditutup; prosedur resmi dan akses baca Owner/Keuangan tetap bekerja. Satu baris harga per item dijaga indeks unik.
- Data lama tidak dihapus; jalur pemulihan transaksi manual/SJ lama ada pada bagian tertutup.

## Pengujian
- PASS suite terisolasi scripts/audit/simple-flow.mjs dengan role authenticated, RLS dan RPC.
- PASS regresi lama test:audit serta fungsi akun test:members.
- PASS uji pada database GASPOS dalam transaksi ROLLBACK: datang100/0, SJ60 membuat stok40/0, tiga faktur20/15/10 dan kosong15/15/8, Owner menerbitkan INV saat kendaraan belum pulang, Keuangan menerima370000/277500/185000, pulang15/38 menghasilkan stok55/38. Retry penerimaan/SJ tidak menggandakan stok.
- Uji database tersebut memakai claim dari empat akun trial aktif pada konektor SQL; bukan klaim empat sesi browser/HP baru. Seluruh data uji baru dibatalkan, tidak menambah transaksi produksi.
- Bentuk visual deployment diperiksa terpisah setelah build. Verifikasi seluruh perangkat HP fisik dan audit akuntansi historis belum dinyatakan selesai.

SQL: supabase/simple_role_workflow.sql dan supabase/audit_ledger_rpc_only.sql. Diterapkan melalui migrasi simple_owner_logistics_driver_finance_workflow.

Reproduksi: npm ci; npm run test:flow; npm run test:audit; npm run test:members; npm run build.
