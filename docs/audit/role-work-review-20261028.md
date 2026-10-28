# Audit pekerjaan empat akun — 28 Oktober 2026

Acuan: Owner pembelian → Logistik datang → Logistik SJ → Sopir faktur barang → Owner harga dan INV → Keuangan uang masuk. Rekonsiliasi kendaraan dilakukan Logistik secara terpisah. Harga hanya ditetapkan Owner.

## Temuan dan perbaikan

| Peran | Kekurangan yang direproduksi dari kode | Perbaikan | Bukti/status |
|---|---|---|---|
| Owner | Beranda hanya jumlah master; faktur yang perlu diproses tidak terlihat | Antrian faktur bertanda tangan belum INV, penerimaan, perjalanan dan tagihan | FIXED: pengujian antrian sesuai peran; transaksi database regresi lulus |
| Owner | Nama penerima terlihat tetapi tanda tangan tersimpan tidak dapat diperiksa | Bukti Penerimaan menampilkan nama, waktu dan gambar tanda tangan tervalidasi | FIXED pada kode; unit validasi SVG termasuk penolakan injeksi lulus; pemeriksaan browser dilakukan setelah publikasi |
| Logistik | Tidak ada ringkasan pekerjaan datang/kendaraan kembali | Antrian pembelian menunggu penerimaan dan perjalanan belum kembali | FIXED: pembelian dihitung unik per dokumen; query tidak membaca keuangan |
| Sales/Sopir | Faktur barang tidak memiliki keluaran cetak | Cetak Faktur Barang per pelanggan, nomor FK, penuh/kosong, penerima, tanda tangan; tanpa nilai uang | FIXED pada kode; keluaran cetak browser diperiksa setelah publikasi |
| Sales/Sopir | Beranda tidak menunjukkan tugas sendiri/tanda tangan tertunda | Antrian perjalanan dan faktur belum ditandatangani melalui RLS akun berjalan | PASS pengujian pembatasan query; tidak ada query harga/pembayaran |
| Keuangan | Pembayaran hanya terlihat total kumulatif, tanpa riwayat per pencatatan | Riwayat 500 pembayaran terakhir; tanggal, jenis, dokumen, mitra dan nominal | FIXED pada kode; pencatatan tetap RPC resmi |
| Keuangan | RLS master mitra menyembunyikan nama pelanggan/supplier sehingga dokumen sulit dikenali | RPC baca terbatas id/nama mitra yang memiliki dokumen; Owner/Keuangan aktif saja | FIXED: database GASPOS Owner/Keuangan masing-masing membaca 6 nama; Logistik/Sopir ditolak |

Tidak ada perubahan hak membuat harga, stok, invoice atau pembayaran. Tidak ada password dibaca/disimpan/dicantumkan. Tidak ada transaksi produksi diubah selama audit ini.

## Validasi

- PASS: 6 pengujian antrian per peran, kegagalan query tidak menjadi angka nol, validasi tanda tangan tersimpan dan penolakan injeksi.
- PASS: test:flow termasuk skenario 100 datang, 60 dimuat, 45 terjual, kembali 15 penuh/38 kosong; invoice sebelum kendaraan pulang tidak memutasi stok. Ditambah uji nama mitra Keuangan dan larangan Logistik/Sopir.
- PASS: test:audit (76 pemeriksaan), test:members (16 pemeriksaan), build lokal.
- PASS: verifikasi RPC baru pada database GASPOS dengan claim empat akun trial aktif dan role authenticated. Ini pemeriksaan hak database, bukan empat login browser baru. Transaksi pemeriksaan dibatalkan.
- Saldo skenario terisolasi: sebelum 0/0, akhir 55 penuh/38 kosong. Pendapatan Rp832.500; HPP Rp765.000; laba kotor Rp67.500. Dengan biaya Rp20.000, laba bersih Rp47.500. Saldo trial produksi tidak dimutasi ulang.

## Pekerjaan belum terverifikasi

- BLOCKED untuk klaim semua layar empat akun pada HP fisik: sesi ini belum melakukan empat login browser/HP baru. Jangan menyebut sistem 100% selesai.
- Laporan HPP aplikasi masih keseluruhan data dengan metode rata-rata tertimbang; validitas historis bergantung kelengkapan stok awal, retur dan biaya. Belum tersedia filter periode laporan.
- Antrian menunjukkan jumlah pekerjaan dan membuka menu terkait, belum otomatis membuka satu dokumen tertentu.
- Riwayat pembayaran menampilkan maksimal 500 pembayaran, daftar tagihan mengikuti batas respons API; refund tercermin dalam saldo namun belum menjadi baris pada riwayat pembayaran.
- Advisor masih menandai view trade_balances sebagai security definer; view ini memiliki filter eksplisit Owner/Keuangan dan diuji regresi. Fungsi RPC security definer yang memang dibutuhkan memakai pemeriksaan peran. Ini bukan klaim semua rekomendasi advisor selesai.

Patch database: supabase/audit_finance_partner_names.sql, migrasi server finance_invoice_partner_names. Reproduksi: npm run test:workflow-ui; npm run test:flow; npm run test:audit; npm run test:members; npm run build.
