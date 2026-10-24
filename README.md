# GASPOS Online

Aplikasi pencatatan penjualan, pembelian, dan inventori tabung gas untuk Owner dan Logistik.

## Infrastruktur tujuan
- Repository: GunzLeite/GasPos-Online.
- Database dan autentikasi: Supabase khusus GASPOS, terpisah dari BMS.
- Hosting belum dikonfigurasi.

## Status 24 Oktober 2026
Koneksi GitHub GunzLeite berhasil, dengan akses tulis. Koneksi Supabase Gaspos Online berhasil; organisasi GuzLeiteWebApp terlihat tetapi belum ada proyek yang dapat diakses.

Kode starter sebelumnya disalin dari bagjasindo/GasPos-Online commit 8b1cb1358916465378b42a01a1bad74dd683c511 ke legacy/cloudflare sebagai referensi migrasi. Kode ini belum memakai Supabase, bukan aplikasi produksi, dan tidak dijalankan otomatis. ID database Cloudflare lama sengaja dihapus dari salinan konfigurasi. Jangan gunakan data usaha asli.

## Aturan bisnis
- Owner mengelola master, harga, pembelian, penjualan, invoice, pembayaran dan laporan.
- Logistik mencatat fisik tabung dan mencetak surat jalan tanpa harga. Data harga harus dibatasi di backend/database, bukan hanya disembunyikan di layar.
- Isi dan kosong dicatat terpisah; penerimaan/pengeluaran sebagian harus didukung.
- Posting stok harus atomik, idempoten, dan mencegah stok negatif pada transaksi bersamaan.
- Transaksi selesai dikunci; koreksi stok memerlukan persetujuan Owner.

## Pekerjaan berikutnya
1. Buat atau hubungkan proyek Supabase pada organisasi GASPOS yang dikonfirmasi pengguna.
2. Implementasikan Supabase Auth, peran Owner/Logistik dan RLS; migrasikan skema SQLite ke PostgreSQL dengan pemisahan data finansial.
3. Migrasikan API dan UI, lalu lengkapi penerimaan parsial, harga pelanggan, SJ dan invoice.
4. Uji pembatasan harga, transaksi bersamaan, saldo stok, penolakan dan cetak ulang sebelum deployment.

BMS dan sumber GASPOS lama tidak diubah.
