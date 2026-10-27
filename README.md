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

Verifikasi lokal: `npm ci`, `npm run test:audit`, `npm run test:members`, `npm run build`.

## Hak akses — empat peran final

| Peran | Tugas dan menu |
| --- | --- |
| **OWNER** (Owner/Admin) | Akses pengelolaan tertinggi: master, pembelian, penjualan, ACC Logistik, perjalanan, harga, invoice, mutasi stok, pembayaran, biaya operasional, laporan, dan pengguna. |
| **LOGISTIK** | Mengajukan barang fisik masuk/keluar, melihat produk/supplier/stok, mencetak Surat Jalan setelah ACC, membuat perjalanan kendaraan, serta merekonsiliasi tabung yang kembali. Tidak mengelola harga. |
| **SALES_SOPIR** (Sales/Sopir) | Melihat perjalanan yang ditugaskan, memilih pelanggan per kunjungan, mencatat tabung penuh diserahkan dan kosong diterima, serta konfirmasi penerimaan. Tidak melihat harga, invoice, atau pembayaran. |
| **KEUANGAN** | Melihat tagihan dan laporan, mencatat pembayaran/refund sesuai validasi server, serta biaya operasional. Tidak mengubah stok. |

Tidak direncanakan peran kelima. Owner membuat akun petugas menggunakan **ID login dan password manual**, tanpa pengiriman undangan email. Kata sandi dikelola Supabase Auth dan tidak ditampilkan kembali dalam daftar pengguna.

**Penting:** akses tidak hanya dibatasi dari daftar menu, tetapi perlu ditegakkan melalui RLS dan fungsi database. Pengujian keamanan lintas peran tetap wajib dilakukan sebelum operasional penuh.

## Alur kerja hulu ke hilir

1. **Master data:** Owner mengelola jenis tabung, supplier, pelanggan, dan harga terkait.
2. **Pembelian:** Owner mencatat transaksi pembelian dari supplier; tabung penuh dan kosong dipisahkan.
3. **Penerimaan fisik:** Logistik memilih **Pembelian terkait** pada Barang Masuk/Keluar; **ACC Owner** menyelesaikan penerimaan pembelian dan memposting mutasi stok sekali. Mutasi umum tidak menyelesaikan tagihan pembelian.
4. **Surat Jalan (SJ):** Pengeluaran yang disetujui dapat dicetak; Logistik menetapkan Sopir dan nomor kendaraan berdasarkan SJ keluar yang sudah ACC.
5. **Pengiriman:** Satu perjalanan dapat melayani banyak pelanggan. Sopir mencatat setiap kunjungan: pelanggan, jumlah tabung penuh dikirim, jumlah kosong diterima, dan catatan. Jumlah penuh tidak boleh melebihi muatan.
6. **Bukti serah terima:** Konfirmasi mencakup nama penerima, waktu, dan gambar tanda tangan yang digores langsung pada layar (disimpan sebagai data koordinat; tanpa upload foto). Ini tetap perlu verifikasi praktik lapangan, bukan autentikasi identitas pelanggan secara independen.
7. **Pulang gudang:** Logistik menghitung sisa penuh dan kosong. Perjalanan tidak dapat ditutup bila masih ada pengiriman belum dikonfirmasi atau angka fisik tidak cocok; stok kembali dicatat terpisah.
8. **Invoice:** Owner membuat invoice dari pengiriman terkonfirmasi setelah perjalanan ditutup, termasuk opsi **invoice gabungan per pelanggan dalam satu perjalanan**. Pembuatan invoice dari perjalanan **tidak boleh memposting pengurangan stok lagi**.
9. **Pembayaran:** Owner/Keuangan menangani pembayaran dan refund sesuai pemeriksaan status dokumen dan batas nominal.
10. **Laporan:** Ringkasan pembelian, penjualan, piutang, utang, biaya operasional, HPP, laba kotor, dan laba bersih estimasi.

## Menu utama saat ini

- **Owner/Admin:** Beranda, Tabung Gas, Supplier, Pelanggan, Pembelian, Penjualan, Logistik & ACC, Perjalanan Sopir, Mutasi Stok, Pembayaran, Keuangan, Biaya Operasional, Harga Pelanggan, Pengguna.
- **Logistik:** Beranda, Tabung Gas, Supplier, Barang Masuk/Keluar, Perjalanan Sopir, Mutasi Stok.
- **Sales/Sopir:** Beranda, Pengiriman Pelanggan.
- **Keuangan:** Beranda, Pembayaran, Keuangan, Biaya Operasional.

## Aturan integritas data

- Tabung **penuh** dan **kosong** dicatat terpisah.
- Pergerakan gudang dan pergerakan kendaraan tidak boleh dihitung dua kali.
- Pengajuan Logistik tidak langsung mengubah stok sebelum disetujui.
- Transaksi pengiriman tidak boleh melampaui muatan kendaraan.
- Koreksi pengiriman dibatasi ke Owner, disertai alasan dan rekam audit; konfirmasi penerima harus diulang setelah koreksi.
- Saldo tabung kosong pelanggan mencakup kewajiban historis, pengembalian yang terkait, dan pengiriman yang telah selesai.
- Invoice dibentuk dari hasil pengiriman yang terverifikasi, tanpa posting stok ulang.
- Harga dan data biaya harus tetap terlindungi di sisi database, bukan sekadar disembunyikan pada UI.

## HPP dan laba rugi

Laporan saat ini memakai pendekatan **rata-rata tertimbang pembelian yang disetujui sepanjang data tersedia**. Terdapat fungsi laporan yang menampilkan penjualan, HPP, laba kotor, biaya operasional, dan laba bersih **estimasi**. Dasar stok awal bernilai juga telah mulai disediakan pada database.

**Jangan perlakukan laporan ini sebagai laba bersih akuntansi final:** penanganan stok awal, retur pembelian/penjualan, biaya perolehan, urutan waktu penilaian persediaan, dan rekonsiliasi historis masih memerlukan penyempurnaan/pengujian. Jangan menggunakan seluruh nilai pembelian sebagai HPP periode berjalan.

## Status implementasi dan pengujian (27 Oktober 2026)

**Sudah terpasang di kode/database:**
- Struktur empat peran dan menu sesuai peran.
- Pembuatan akun petugas manual tanpa undangan.
- Master produk/mitra, transaksi pembelian/penjualan, pembayaran, dan biaya operasional.
- Pengajuan Logistik, ACC Owner, mutasi stok, cetak SJ.
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

Folder `legacy/cloudflare` hanya referensi kode lama; bukan aplikasi yang dideploy. GASPOS menggunakan proyek/database sendiri. **Repositori dan database BMS tidak boleh diubah sebagai bagian dari pekerjaan GASPOS.**

---

Copyright Gunz Leite@2026.
