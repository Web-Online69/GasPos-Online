# Trial nyata empat akun dan perbaikan — 28 Oktober 2026

## Ruang lingkup dan bukti

Trial `GASPOS-TRIAL-20261028-9E0B8F` memakai empat login password Supabase Auth nyata, lalu REST/RPC dengan JWT masing-masing akun. Bukan pergantian claim SQL. Dua akun trial lama menolak password tersimpan; dibuat akun Logistik dan Keuangan pengganti melalui fungsi akun resmi menggunakan Owner. Password akun lama tidak diubah. Kredensial hanya pada file login pribadi, tidak pada laporan, kode atau log.

**PASS: 25 pemeriksaan live**, lihat [bukti terstruktur](live-four-role-20261028.json).

| Peran | Trial yang benar-benar dilakukan | Status |
|---|---|---|
| OWNER | Login, buat pembelian100 @17000; INV sebelum tanda tangan ditolak; buat3 INV @18500 saat kendaraan ON_ROUTE; INV ganda ditolak; saldo kosong dan laba rugi sesuai | PASS API |
| LOGISTIK | Login, terima100, retry penerimaan aman; SJ60 dan retry aman; penutupan tanpa konfirmasi dan selisih fisik ditolak; kembali15 penuh/38 kosong | PASS API |
| SALES_SOPIR | Login, baca perjalanan penugasan; pengiriman61 dari muatan60 ditolak; faktur20/15/10, kosong15/15/8; tanda tangan sintetis bertanda TEST; larangan baca harga/membuat INV | PASS API |
| KEUANGAN | Login, bayar pelanggan parsial/lunas; supplier1700000; biayaBBM20000; overpay ditolak; nama mitra terbaca; tidak dapat mengubah stok; saldo tagihan nol | PASS API |

Tidak ada uang nyata dipindahkan. Seluruh transaksi adalah pencatatan fiktif pada produk/mitra berlabel trial yang baru. Data produksi yang sudah ada tidak diedit/dihapus. Data trial belum dibersihkan, sesuai arahan dapat dihapus kemudian; nilainya masih ikut laporan keseluruhan sampai dibersihkan.

## Rekonsiliasi trial

| Tahap | Penuh di gudang | Kosong di gudang |
|---|---:|---:|
| Sebelum | 0 | 0 |
| Diterima100 | 100 | 0 |
| Muatan60 | 40 | 0 |
| Terbit INV45 | 40 | 0 |
| Kembali15/38 | 55 | 38 |

Pendapatan Rp832.500; HPP Rp765.000; laba kotor Rp67.500; biaya Rp20.000; laba bersih Rp47.500. Angka diverifikasi melalui selisih laporan database sebelum/sesudah, bukan mengganti laporan keseluruhan dengan hitungan manual. Utang supplier dan piutang pelanggan trial nol. Utang kosong A5/B0/C2.

## Kekurangan dan perbaikan

| Peran | Kekurangan | Perbaikan |
|---|---|---|
| Owner | Setelah membuat INV tidak ada petunjuk langkah cetak | Pesan berhasil dan tombol Lihat & Cetak INV menuju Penjualan |
| Logistik | Form SJ belum menunjukkan stok yang boleh dimuat | Tampilkan stok penuh gudang per produk dan batas maksimum isian; RPC tetap memvalidasi stok terkini |
| Sopir | Form jumlah pengiriman belum menunjukkan batas sisa muatan | Batas maksimum sesuai sisa dan tombol simpan dinonaktifkan bila muatan habis; RPC tetap menolak overdelivery |
| Keuangan | Form pembayaran/refund tertutup tanpa konfirmasi hasil yang jelas | Pesan berhasil mencantumkan dokumen dan nominal pembayaran; konfirmasi refund terpisah |
| Semua akun | Keluar menunggu respons tanpa indikator dan memakai signout semua sesi | Indikator Sedang keluar, cegah klik ganda, pesan kegagalan, signout hanya sesi lokal |
| Semua akun | Saat reload, form login muncul sebelum pemeriksaan sesi lama selesai | Tampilkan Memeriksa sesi akun; login baru hanya muncul setelah pemeriksaan selesai. Uji deferred promise membuktikan login tidak dibuka selama restore tertunda |
| Owner | Judul faktur gabungan tetap tampil walau tidak ada faktur tertunda | Judul hanya muncul bila ada faktur yang dapat digabung |

## Batas verifikasi browser

- PASS Owner pada website publik: login, daftar/form Pembelian vertikal, rincian perjalanan, tiga faktur trial berstatus sudah invoice, gambar tanda tangan, dan popup Faktur Barang20/15 tanpa harga.
- PASS indikator keluar pada versi450acf4: tombol menjadi disabled dan bertuliskan Sedang keluar.
- Formulir login aman untuk berpindah Logistik masih menghasilkan dashboard OWNER. Tidak dianggap PASS layar Logistik dan tidak langsung disimpulkan sebagai kebocoran hak, karena identitas akun yang dipilih tidak dikembalikan oleh mekanisme login aman.
- BLOCKED: trial klik layar terpisah Logistik, Sopir, Keuangan dan seluruh HP fisik. Pengujian API empat peran sudah dilakukan; hasil ini tidak disamakan dengan empat sesi browser.
- Perbaikan UI tidak berarti seluruh tampilan sudah lulus uji ulang. Tombol sukses invoice/pembayaran dan form Sopir baru belum dioperasikan melalui sesi browser peran terkait.

## Build dan deployment

Perbaikan awal450acf44b88ff4fe248a062792ffb67888951fda: CI40621377419 dan Pages40621377306 sukses. Perbaikan pemulihan sesi serta laporan diterbitkan pada commit berikutnya; status akhirnya diverifikasi sebelum laporan akhir kepada pengguna. Pengujian lokal workflow UI9 lulus; build lulus. CI juga menjalankan regresi database76, alur24, dan akun16.
