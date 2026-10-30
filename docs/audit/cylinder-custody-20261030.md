# Transaksi gudang dan pengembalian tabung pelanggan — 30 Oktober 2026

## Alur aplikasi

Empat peran tetap OWNER, LOGISTIK, SALES_SOPIR, KEUANGAN. Tugas aktif menentukan hak akses.

- Penerimaan Pembelian: halaman daftar/riwayat dengan tombol transaksi baru. Owner menetapkan pembelian/harga; Logistik mencatat barang datang.
- Surat Jalan Keluar: halaman daftar/riwayat terpisah dengan tombol SJ baru. Muatan awal tidak diedit untuk menyamakan sisa perjalanan.
- Penerimaan Kembali Sopir: Logistik menghitung sisa penuh dan seluruh kosong; sistem mencocokkan dengan SJ, pengiriman dan pengumpulan kosong terpisah. Perjalanan tidak ditutup bila ada pengiriman belum ditandatangani atau jumlah berbeda.
- Pinjaman & Pengembalian Tabung: halaman fisik terpisah dari penjualan, piutang uang dan stok gudang. Saldo per pelanggan/per jenis tabung mencakup pengiriman terkonfirmasi, transaksi lama, retur dan pengembalian kosong tersendiri. Saldo negatif ditampilkan sebagai kelebihan kosong, tidak dipaksa nol.
- Sopir memilih perjalanan aktif yang ditugaskan, pelanggan, jenis tabung, jumlah, nama penyerah dan tanda tangan. Tidak membuat INV atau mengisi harga. Pengumpulan mengurangi pinjaman sekali dan berstatus Dibawa Sopir. Gudang belum bertambah.
- Logistik/Owner juga dapat menerima langsung di gudang. Pinjaman berkurang dan stok kosong bertambah sekali.
- Saat kendaraan kembali, Logistik menerima seluruh muatan pulang termasuk pengumpulan terpisah. Status menjadi Diterima Gudang tanpa mengurangi pinjaman lagi. Klik ulang dengan jumlah sama tidak memposting stok kembali.
- Owner dapat membatalkan catatan yang salah dengan alasan; riwayat tetap ada. Jika sudah diterima gudang, sistem membuat dokumen pembalik KOR dan mutasi negatif kosong, memulihkan pinjaman sekali, serta menolak pembalikan bila stok kosong tidak cukup. SJ dan penerimaan perjalanan awal tetap menjadi riwayat asli.
- Bukti pengembalian dapat dicetak; Laporan Transaksi menyediakan pengembalian pelanggan dan penerimaan kembali Sopir dengan filter. Jangan menjumlahkan pengumpulan pelanggan dan penerimaan kendaraan sebagai dua kali arus gudang.

Contoh terisolasi: berangkat 100 penuh, terkirim 70, menerima 60 kosong pada pengiriman. Pinjaman 10. Sopir mengumpulkan 4 kosong tanpa penjualan: pinjaman 6, kosong kendaraan 64. Kembali 30 penuh/64 kosong: gudang 30/64, pinjaman tetap 6, SJ tetap 100. Pengembalian langsung berikutnya 2: gudang 30/66, pinjaman 4. INV setelah itu tidak mengubah saldo fisik atau pinjaman.

## Implementasi

`supabase/audit_customer_cylinder_returns.sql` menambahkan tabel pengembalian dengan RLS dan RPC tervalidasi. Tidak mengubah data transaksi lama atau mengisi saldo awal fiktif. Tidak ada INSERT/UPDATE/DELETE langsung dari browser. Finance tidak membaca atau menulis pengembalian; Sopir membaca catatan pada perjalanan yang ditugaskan. RPC menolak akun nonaktif melalui current_role, perjalanan Sopir lain, jenis tabung berbeda, jumlah melebihi pinjaman, tanda tangan tidak valid dan replay dengan data berbeda. Kunci transaksi menyelaraskan penerimaan, koreksi, tanda tangan dan pengumpulan. Koreksi sumber pinjaman yang sudah dikembalikan ditolak bila membuat saldo negatif.

Nomor TKM memakai penghitung dokumen yang sama, bukan UUID panjang. Pengembalian langsung menggunakan satu nomor TKM untuk catatan dan dokumen stok. Pengumpulan di kendaraan mempunyai TKM sendiri, lalu terhubung ke dokumen SJ saat diterima gudang. Tidak menambah jenis peran.

## Pengujian dan batas

- PASS: PostgreSQL terisolasi, skenario di atas, replay, pembatasan jumlah, tanda tangan, peran salah, perjalanan lain, produk salah, penerimaan fisik berbeda, perjalanan belum ditandatangani, pembatalan Owner dan penguncian setelah diterima.
- PASS: pembuatan INV terisolasi tidak mengubah stok/pinjaman; SJ awal tetap 100.
- PASS: RLS baru aktif, browser hanya SELECT, anon tidak boleh mengeksekusi RPC, fungsi agregasi privat tidak bisa dipanggil langsung.
- PASS: build lokal, regresi workflow UI, anggota, alur transaksi dan audit database.
- Database GASPOS: migrasi berhasil diterapkan. Tabel pengembalian baru kosong; data produksi tidak dipakai sebagai trial transaksi baru.
- PASS: GitHub Check GASPOS build dan GitHub Pages untuk commit implementasi `e9888b04057fd73411db4cba6e8e804f95b90403`.
- PASS: browser publik dengan sesi Owner — halaman Penerimaan Pembelian/SJ terpisah, tombol transaksi baru, pembatalan tanpa simpan, saldo pinjaman dimuat, batas 6 ditolak saat saldo 5, tanda tangan kosong ditolak.
- PASS: halaman penerimaan kembali menampilkan SJ awal 60, terkirim 45, sisa penuh 15, kosong 38 dari perjalanan uji lama. Tidak mengedit atau mengulang penerimaan.
- PASS: laporan penerimaan kembali difilter 28 Oktober 2026 menjadi satu baris, total 15 penuh/38 kosong. Halaman cetak menampilkan baris, tanggal dan total yang sama.
- PASS: fingerprint dokumen, item, mutasi stok, perjalanan, pengiriman dan pembayaran produksi tetap sama sebelum/sesudah migrasi. Tabel pengembalian baru masih kosong; uji simpan berhasil dilakukan di PostgreSQL terisolasi, bukan membuat data bisnis produksi.
- Regresi lokal: 36 tes workflow UI, 18 tes akun, 86 pemeriksaan alur dan 76 pemeriksaan audit database; build berhasil. Pengujian lama memuat reproduksi FAIL baseline yang dilanjutkan pengujian ulang PASS; itu bukan kegagalan hasil perbaikan.
- Bukti antarmuka: tangkapan layar Transaksi Gudang terpisah disampaikan kepada pengguna. Verifikasi browser sesi Owner tidak menggantikan trial seluruh peran atau pengujian HP fisik.

Batas: pengumpulan Sopir memakai perjalanan aktif dengan jenis tabung sesuai SJ; penugasan perjalanan khusus penjemputan tanpa muatan awal belum dibuat. Verifikasi HP fisik dan seluruh akun lewat browser belum dinyatakan selesai. Temuan advisor lama (view gaspos_trade_balances dan leaked-password protection) tetap perlu tindak lanjut; endpoint SECURITY DEFINER yang baru memang disengaja, dilindungi pemeriksaan peran/penugasan dan hak EXECUTE.
