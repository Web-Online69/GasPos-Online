# GASPOS Online

**Sistem pencatatan pembelian, penjualan, inventori, pengiriman, dan keuangan tabung gas** berbasis web, dirancang mobile-first untuk operasional gudang dan pengantaran.

- **Aplikasi:** https://web-online69.github.io/GasPos-Online/
- **Repository:** https://github.com/Web-Online69/GasPos-Online
- **Frontend:** Vite / JavaScript, satu halaman utama (SPA).
- **Hosting:** GitHub Pages melalui GitHub Actions.
- **Database dan autentikasi:** Supabase PostgreSQL / Supabase Auth, khusus GASPOS dan terpisah dari BMS.
- **Biaya infrastruktur:** memanfaatkan layanan free tier; tetap mengikuti batas/ketentuan penyedia.

## Audit terbaru

Lihat [hasil live trial 27 Oktober 2026](docs/audit/live-trial-20261027.md) dan [audit tahap sebelumnya](docs/audit/2026-10-27.md). **Empat akun trial nyata berhasil login dan menyelesaikan alur melalui API dengan hak masing-masing.** Stok akhir produk trial 55 penuh/38 kosong, piutang/utang fixture lunas, laba bersih estimasi Rp47.500 setelah biaya Rp20.000. Browser/HP untuk ketiga peran petugas dan audit akuntansi historis belum lengkap; aplikasi belum dinyatakan 100% selesai. Data trial masih tercatat dan memengaruhi total laporan hingga dibersihkan.

Verifikasi lokal: `npm ci`, `npm run test:audit`, `npm run test:members`, `npm run test:flow`, `npm run build`.

## Hak akses — empat peran final

| Peran | Tugas dan menu |
| --- | --- |
| **OWNER** (Owner/Admin) | Akses pengelolaan tertinggi: master, pembelian, penjualan, konfirmasi faktur Sopir, perjalanan, harga, invoice, mutasi stok, pembayaran, biaya operasional, laporan, dan pengguna. |
| **LOGISTIK** | Mengonfirmasi pembelian datang, melihat produk/supplier/stok, membuat serta mencetak Surat Jalan dan menugaskan kendaraan/Sopir, serta merekonsiliasi tabung yang kembali. Tidak mengelola harga. |
| **SALES_SOPIR** (Sales/Sopir) | Melihat perjalanan yang ditugaskan, membuat Faktur Penjualan per pelanggan tanpa harga, mencatat penuh diserahkan dan kosong diterima, serta konfirmasi penerimaan. Tidak melihat harga, invoice, atau pembayaran. |
| **KEUANGAN** | Melihat tagihan dan laporan, mencatat pembayaran/refund sesuai validasi server, serta biaya operasional. Tidak mengubah stok. |

Tidak direncanakan peran kelima. Owner membuat akun petugas menggunakan **ID login dan password manual**, tanpa pengiriman undangan email. Kata sandi dikelola Supabase Auth dan tidak ditampilkan kembali dalam daftar pengguna.

**Penting:** akses tidak hanya dibatasi dari daftar menu, tetapi perlu ditegakkan melalui RLS dan fungsi database. Pengujian keamanan lintas peran tetap wajib dilakukan sebelum operasional penuh.

## Alur kerja hulu ke hilir — diperbarui 28 Oktober 2026

1. **Owner membuat pembelian:** supplier, tabung, jumlah, dan harga beli. Data tambahan bersifat opsional.
2. **Logistik mengonfirmasi barang datang:** pilih pembelian, cocokkan jumlah fisik, lalu Terima Pembelian. Stok bertambah sekali tanpa menunggu ACC Owner.
3. **Logistik membuat Surat Jalan:** pilih tabung, muatan, Sopir dan kendaraan. SJ serta perjalanan dibuat sekaligus; stok keluar dari gudang sekali.
4. **Sopir membuat Faktur Penjualan per pelanggan:** pelanggan, penuh dikirim, kosong diterima, catatan opsional; nama dan tanda tangan penerima dicatat pada satu formulir. Faktur ini tidak menampilkan harga.
5. **Owner mengonfirmasi penjualan:** periksa faktur, isi harga jual, lihat total otomatis, lalu Konfirmasi & Buat INV. Dapat dilakukan saat perjalanan berlangsung atau setelah kembali. INV tidak mengurangi stok lagi.
6. **Keuangan mengonfirmasi uang masuk:** pilih INV dan nominal yang benar-benar diterima. Pembayaran sebagian didukung; saldo piutang diperbarui. Pembayaran supplier tetap tersedia.

**Kendaraan kembali:** Logistik tetap wajib mencocokkan sisa penuh dan kosong secara fisik sebelum menutup perjalanan. Rekonsiliasi tidak menjadi syarat tambahan penerbitan INV. Retur fisik invoice perjalanan tetap memerlukan pengiriman yang sudah direkonsiliasi.

Semua formulir memakai **satu kolom vertikal di desktop dan HP**, label di atas isian, tombol di bawah. Tanggal, referensi, biaya tambahan dan pilihan jarang digunakan dikelompokkan dalam Data tambahan (opsional). Penjualan manual/SJ lama hanya tersedia dalam bagian pemulihan tertutup; data lama tidak dihapus.

Lihat [catatan perubahan dan pengujian](docs/audit/simple-flow-20261028.md).

## Menu utama saat ini

- **Owner/Admin:** Beranda, Tabung Gas, Supplier, Pelanggan, Pembelian, Penjualan, Gudang & Surat Jalan, Perjalanan Sopir, Mutasi Stok, Pembayaran, Keuangan, Biaya Operasional, Harga Pelanggan, Pengguna.
- **Logistik:** Beranda, Tabung Gas, Supplier, Gudang & Surat Jalan, Perjalanan Sopir, Mutasi Stok.
- **Sales/Sopir:** Beranda, Faktur Penjualan.
- **Keuangan:** Beranda, Pembayaran, Keuangan, Biaya Operasional.

## Aturan integritas data

- Tabung **penuh** dan **kosong** dicatat terpisah.
- Pergerakan gudang dan pergerakan kendaraan tidak boleh dihitung dua kali.
- Konfirmasi barang datang dan penerbitan SJ oleh Logistik langsung mencatat mutasi resmi satu kali.
- Transaksi pengiriman tidak boleh melampaui muatan kendaraan.
- Koreksi pengiriman dibatasi ke Owner, disertai alasan dan rekam audit; konfirmasi penerima harus diulang setelah koreksi.
- Saldo tabung kosong pelanggan mencakup kewajiban historis, pengembalian yang terkait, dan pengiriman yang telah dikonfirmasi penerima.
- Invoice dibentuk dari hasil pengiriman yang terverifikasi, tanpa posting stok ulang.
- Harga dan data biaya harus tetap terlindungi di sisi database, bukan sekadar disembunyikan pada UI.

## HPP dan laba rugi

Laporan saat ini memakai pendekatan **rata-rata tertimbang pembelian yang disetujui sepanjang data tersedia**. Terdapat fungsi laporan yang menampilkan penjualan, HPP, laba kotor, biaya operasional, dan laba bersih **estimasi**. Dasar stok awal bernilai juga telah mulai disediakan pada database.

**Jangan perlakukan laporan ini sebagai laba bersih akuntansi final:** penanganan stok awal, retur pembelian/penjualan, biaya perolehan, urutan waktu penilaian persediaan, dan rekonsiliasi historis masih memerlukan penyempurnaan/pengujian. Jangan menggunakan seluruh nilai pembelian sebagai HPP periode berjalan.

## Status implementasi dan pengujian (28 Oktober 2026)

**Sudah terpasang di kode/database:**
- Struktur empat peran dan menu sesuai peran.
- Pembuatan akun petugas manual tanpa undangan.
- Master produk/mitra, transaksi pembelian/penjualan, pembayaran, dan biaya operasional.
- Konfirmasi datang oleh Logistik, SJ dan perjalanan satu langkah, mutasi stok, cetak SJ.
- Perjalanan Sopir dengan banyak pelanggan, penerimaan kembali, pembatasan muatan.
- Pencatatan penerima dan tanda tangan, koreksi dengan audit trail.
- Invoice per kunjungan / gabungan per pelanggan dalam satu perjalanan.
- Ringkasan saldo tabung kosong dan estimasi HPP/laba rugi.

**Belum dinyatakan lulus sepenuhnya:**
- Uji seluruh halaman browser/HP sebagai **Owner, Logistik, Sales/Sopir, dan Keuangan**; alur API dengan empat akun nyata sudah lulus pada data trial.
- Uji transaksi bersamaan dan seluruh variasi retur/koreksi historis; stok negatif, ACC/invoice ganda dan koreksi sesudah invoice telah diuji pada data trial.
- Verifikasi penilaian persediaan dan laba bersih final termasuk stok awal, biaya tambahan, serta retur.
- Uji tanda tangan pelanggan pada berbagai HP/browser dan prosedur verifikasi pelanggan.

Status build/deployment terbaru sebaiknya dilihat di tab **Actions** repository; build sukses saja tidak menggantikan uji operasional.

## Menjalankan pengembangan

Gunakan Node.js dan npm:

```bash
npm install
npm run dev
```

Kredensial Supabase dikonfigurasikan sesuai variabel lingkungan frontend yang dipakai proyek. **Jangan pernah menyimpan service-role key, password, atau rahasia lain dalam repo/frontend.**

## Catatan migrasi

Folder aplikasi lama `legacy/cloudflare` sudah dihapus dari branch `main` (commit `069bfcb1cfc9ba2e326347f9e5fae94545c52d75`). Sumber aplikasi aktif berada di `src/`, dengan satu build Vite yang diterbitkan melalui GitHub Pages. Jangan membuat kembali folder aplikasi lama. GASPOS menggunakan proyek/database sendiri. **Repositori dan database BMS tidak boleh diubah sebagai bagian dari pekerjaan GASPOS.**

---

Copyright Gunz Leite@2026.

Audit pekerjaan per akun (28 Oktober 2026): Beranda menampilkan antrian sesuai peran; Faktur Barang tanpa harga dapat dicetak dan bukti tanda tangan diperiksa; menu Keuangan menampilkan riwayat pembayaran serta nama mitra tagihan. Rincian hasil dan batas verifikasi: [audit per akun](docs/audit/role-work-review-20261028.md). Patch `supabase/audit_finance_partner_names.sql` menyediakan nama mitra bagi Owner/Keuangan tanpa membuka akses master kepada Keuangan. Jalankan juga `npm run test:workflow-ui`.

Trial empat login nyata dan catatan kekurangan/perbaikan setiap peran: [laporan live 28 Oktober](docs/audit/live-four-role-20261028.md). Data trial diberi label terpisah dan belum dihapus. Form SJ menampilkan stok tersedia, Faktur Sopir dibatasi sisa muatan, dan hasil INV/pembayaran diberi konfirmasi.

Perlindungan ulang Simpan pembayaran saat respons koneksi hilang: [audit pembayaran](docs/audit/payment-retry-20261028.md). Jalankan patch `supabase/audit_payment_retry.sql` sebelum frontend terbaru. Form pembayaran memakai `gaspos_record_payment_once`; muat ulang tab lama setelah pembaruan.

Serah tugas gudang: patch `supabase/audit_logistics_shared_read.sql` memungkinkan semua petugas Logistik aktif membaca SJ/penerimaan gudang untuk rekonsiliasi bersama. Akses harga, keuangan, dan mutasi tetap mengikuti hak serta RPC resmi; Sopir tetap hanya melihat penugasannya sendiri.

Hasil [trial browser empat peran](docs/audit/browser-role-trial-20261028.md) (28–29 Oktober2026) mencatat trial Logistik/Sopir yang sudah dijalankan serta tahap INV yang masih memerlukan konfirmasi pengguna. Hasil browser dibedakan dari trial API.
