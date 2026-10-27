# GASPOS live trial — 27 Oktober 2026

## Hasil utama

**PASS: empat akun trial nyata berhasil login Supabase Auth dan menjalankan satu transaksi hulu ke hilir melalui REST/RPC aplikasi dengan JWT masing-masing.** Ini bukan simulasi role SQL lokal. Browser desktop Owner juga memperlihatkan perjalanan RETURNED, tiga pelanggan terkonfirmasi/sudah invoice, dan saldo kosong A5/C2. Penggunaan browser/HP sebagai ketiga petugas belum diverifikasi; jangan menyatakan seluruh aplikasi 100% selesai.

Data khusus `GASPOS-TRIAL-20261027`, produk `GAS-002`, supplier/pelanggan trial. Data operasional lama tidak diedit atau dihapus. Data trial saat ini masih tercatat sehingga ikut memengaruhi total laporan keseluruhan; nilai trial di bawah diverifikasi sebagai selisih sebelum/sesudah serta dari ID dokumen terkait. Tidak ada pembayaran uang sebenarnya, email undangan, foto, atau tanda tangan pelanggan asli.

## Akun

| Peran | ID login | Status |
|---|---|---|
| OWNER/ADMIN | trial_owner_1027 | PASS login nyata, anggota OWNER aktif |
| LOGISTIK | trial_logistik_1027 | PASS login nyata, anggota LOGISTIK aktif |
| SALES/SOPIR | trial_sales_sopir_1027 | PASS login nyata, anggota SALES_SOPIR aktif |
| KEUANGAN | trial_keuangan_1027 | PASS login nyata, anggota KEUANGAN aktif |

Tidak ada peran kelima. Owner trial tambahan diprovisi melalui konektor administrator dengan hash password dan identitas email terkonfirmasi; tiga petugas dibuat melalui Edge Function resmi `gaspos-invite-member` oleh sesi Owner trial. Semua password dibuat acak dan hanya dipakai runner privat; tidak dimasukkan ke repo, laporan, respons, atau log pengujian. Daftar akun diverifikasi kembali dari database setelah pengujian. Akun Keuangan sempat dinonaktifkan untuk pengujian token lama, lalu diaktifkan kembali.

## Tahap transaksi

| Tahap | Pelaksana | Hasil |
|---|---|---|
| Pembelian 100 × Rp17.000 | Owner | PASS, pembelian trial tersimpan |
| Pengajuan penerimaan terkait pembelian | Logistik | PASS |
| ACC penerimaan | Owner | PASS, pembelian APPROVED, stok 100/0 |
| Pengeluaran muatan 60 penuh | Logistik → Owner ACC | PASS, stok gudang 40/0 |
| Penugasan perjalanan TRIAL-1027 | Logistik | PASS, Sopir trial ditugaskan |
| A: 20 penuh/15 kosong; B: 15/15; C: 10/8 | Sopir | PASS, 45 penuh terkirim/38 kosong |
| Nama penerima dan tanda tangan simulasi | Sopir | PASS tersimpan server; bukan verifikasi identitas pelanggan nyata |
| Pulang 15 penuh/38 kosong | Logistik | PASS, perjalanan RETURNED |
| Invoice A/B/C × Rp18.500 | Owner | PASS, tanpa mutasi stok tambahan |
| Pembayaran pelanggan parsial dan lunas | Keuangan | PASS |
| Pembayaran supplier Rp1.700.000 | Keuangan | PASS |
| Biaya BBM simulasi Rp20.000 | Keuangan | PASS |

## Saldo dan perhitungan

| Titik | Penuh gudang | Kosong gudang |
|---|---:|---:|
| Sebelum trial produk baru | 0 | 0 |
| Sesudah ACC penerimaan | 100 | 0 |
| Sesudah muat | 40 | 0 |
| Sesudah pulang | 55 | 38 |
| Sesudah invoice dan pembayaran | 55 | 38 |

Piutang A/B/C dan utang supplier: **Rp0** sesudah pembayaran, diperiksa dari view saldo dengan akun Keuangan. A dibayar Rp100.000 lalu Rp270.000; B Rp277.500; C Rp185.000. Saldo kosong pelanggan terverifikasi dari RPC: A5, B0, C2. Pembelian fixture menggunakan REFILL_NO_EXCHANGE (isi tanpa menyerahkan kosong), sehingga kewajiban kosong supplier berbeda dari pembelian tabung baru dan tetap perlu diperhatikan.

| Laporan | Selisih akibat trial |
|---|---:|
| Pendapatan | Rp832.500 |
| HPP | Rp765.000 |
| Laba kotor | Rp67.500 |
| Biaya operasional | Rp20.000 |
| Laba bersih estimasi | Rp47.500 |
| Nilai sisa penuh berdasarkan biaya fixture | Rp935.000 |

Metode laporan tetap rata-rata tertimbang keseluruhan, bukan HPP per tanggal. Hasil trial sederhana ini tidak menyelesaikan audit akuntansi historis, biaya perolehan, FIFO, atau concurrency.

## Uji negatif yang lulus langsung

- Password salah ditolak Auth.
- ACC ganda, muatan 61 dari 60, pelanggan tidak valid, pulang tanpa konfirmasi, dan jumlah pulang salah ditolak.
- Invoice ganda dan koreksi sesudah invoice ditolak.
- Pembayaran di atas saldo dan refund pelanggan/supplier tanpa kredit ditolak.
- Logistik/Sopir tidak mendapatkan data harga dari financial entries; Sopir dapat membaca SJ yang ditugaskan.
- Keuangan tidak dapat mengubah nama produk trial, mengajukan stok, atau menyesuaikan stok.
- Sopir tidak dapat membuat invoice.
- Pengeluaran 56 saat stok 55 ditolak pada ACC; pengajuannya kemudian ditolak secara resmi agar tidak tertinggal pending.
- Setelah Keuangan nonaktif, JWT yang sudah terbit tidak dapat menambah biaya atau membaca saldo. Keuangan kemudian diaktifkan kembali.

Trace berisi 60 checkpoint PASS, bukan klaim 60 skenario browser terpisah: [live-trial-20261027.json](live-trial-20261027.json). Pengujian dilakukan pada entitas trial yang ditandai; tidak menargetkan transaksi operasional.

## Bug tambahan dan pengujian ulang

1. **FIXED — validasi tanda tangan:** satu goresan valid ditolak sebelumnya, sementara struktur koordinat salah diterima. Patch `supabase/audit_signature.sql` memvalidasi goresan/titik, angka, batas kanvas, ukuran payload dan minimal tiga titik. Diterapkan sebagai migrasi `audit_validate_canvas_signature_strokes`. Uji database remote dalam transaksi ROLLBACK membuktikan satu goresan valid diterima dan struktur salah ditolak, tanpa perubahan stok permanen. Suite lokal kini 76 regresi PASS, ditambah 8 tes fungsi akun PASS.
2. **Cetak SJ:** pemeriksaan browser menunjukkan dokumen 60 penuh/0 kosong tanpa harga, tetapi belum mencantumkan Sopir/kendaraan. Kode diperbarui untuk mengambil penugasan terkait dan menampilkan ID Sopir serta kendaraan; build berhasil; pengujian publik setelah deployment dicatat pada pembaruan akhir.
3. **Retur invoice perjalanan:** ditemukan kegagalan ketika retur sah mencari mutasi pada invoice; invoice perjalanan tidak memposting stok. **FIXED** melalui patch audit_trip_invoice_returns.sql dan migrasi audit_trip_invoice_return_provenance_and_empty_balances. Sumber kuantitas sekarang pengiriman yang terverifikasi atau mutasi SALE langsung, dipilih salah satu. View tetap security_invoker=true. Saldo kosong memperhitungkan retur penuh/kosong satu kali. Uji remote ROLLBACK: retur 1 penuh/0 kosong menghasilkan stok56/38, kewajiban A4, pendapatan turun Rp18.500, HPP turun Rp17.000, laba turun Rp1.500. Keuangan berhasil refund Rp18.500, replay request mengembalikan ID sama, refund tambahan Rp1 ditolak, saldo invoice bersih351500/terbayar351500. Tidak ada perubahan permanen dari probe ini. Invoice gabungan, jalur SALE langsung, saldo kredit kosong negatif, larangan peran dan data provenance salah ikut diuji pada suite terisolasi.

## Kode dan deployment

Live trial utama menggunakan commit `f9fea6aa1ecd08454dd3e95ce8b7c612c1aaeacb`, dengan perbaikan signature diterapkan selama audit lanjutan. Commit terakhir yang menyimpan laporan ini mencakup kode/SQL lanjutan; hash dan run build/deployment dilaporkan setelah publikasi. Build lokal, pemeriksaan sintaks, dan diff dijalankan. BMS tidak diubah.

## Pembersihan nanti

Akun dan data trial **belum dihapus**, sesuai permintaan untuk bisa dihapus nanti. [trial-cleanup-20261027.sql](trial-cleanup-20261027.sql) mencatat ID tepat dan penjagaan produk/dokumen terkait. Skrip belum dijalankan. Jangan menghapus berdasarkan awalan nama saja. Penambahan relasi baru harus ditinjau agar tidak menghapus data di luar trial; foreign key akan membatalkan penghapusan bila ada ketergantungan yang tidak tercakup. Sequence produk tidak direset.

## Belum diverifikasi

- Login browser dan seluruh halaman sebagai Logistik, Sopir, Keuangan.
- Layar HP sebenarnya, goresan sentuh, dan dialog cetak/PDF.
- Seluruh skenario retur/historis/biaya dan konkurensi transaksi.
- Penilaian persediaan dan laba bersih akuntansi final.
