# GASPOS Online

Aplikasi operasional tabung gas dengan empat peran: Owner, Logistik, Sales/Sopir, Keuangan.

Alur: Owner membeli/menetapkan harga → Logistik menerima fisik → Logistik membuat SJ dan muatan → Sopir mencatat Faktur Barang/tanda tangan per pelanggan → Owner menerbitkan INV → Keuangan mencatat uang masuk. Logistik mencocokkan tabung kembali sebelum menutup perjalanan. Formulir disusun satu kolom.

[Aplikasi](https://web-online69.github.io/GasPos-Online/) · [Audit terbaru dan batas verifikasi](docs/audit/final-end-to-end-20261029.md)

Validasi lokal: `npm run test:flow`, `npm run test:audit`, `npm run test:members`, `npm run test:workflow-ui`, `npm run build`.

Perbaikan retry pengiriman/biaya/refund: `supabase/audit_form_retry.sql` dan `supabase/audit_refund_replay.sql` (sudah diterapkan ke GASPOS). Laporan laba rugi masih estimasi rata-rata tertimbang seluruh data. Trial browser INV/pembayaran final dan verifikasi HP fisik belum selesai; aplikasi belum dinyatakan100%.

Tata letak desktop/HP: [perubahan dan batas verifikasi](docs/audit/ui-layout-20261029.md).

Filter riwayat per menu dan **Laporan Transaksi** yang bisa dicetak: [panduan, hak akses dan batas perhitungan](docs/audit/history-filters-reports-20261029.md).

Pencatatan angka mengikuti Indonesia (`1.000.000`; desimal memakai koma pada kolom yang mendukung): [detail dan validasi](docs/audit/indonesian-number-format-20261030.md).

Nomor dokumen singkat dan berurutan (`INV 00001`, `BEL 00001`, `SJ 00001`, `FK 00001`): [rincian dan integritas data](docs/audit/short-document-numbers-20261030.md).

Pengguna dapat memiliki beberapa tugas (Logistik/Keuangan/Sopir) dengan satu tugas aktif: [panduan dan pengujian](docs/audit/multi-job-users-20261030.md).

Transaksi gudang kini dipisah menjadi Penerimaan Pembelian, Surat Jalan Keluar dan Penerimaan Kembali Sopir. Pinjaman serta pengembalian tabung pelanggan dicatat terpisah, termasuk pengembalian tanpa penjualan baru. SJ tetap menyimpan muatan awal. [Alur, pengujian dan batas fitur](docs/audit/cylinder-custody-20261030.md).

Cetak transaksi tersedia sebagai A4/PDF, Excel `.xlsx` dan format termal 58/80 mm. Printer Bluetooth dipilih melalui layanan cetak HP/komputer yang sudah dipasangkan. [Panduan dan batas perangkat](docs/audit/transaction-output-20261030.md).

Format INV mengikuti contoh PDF pengguna: identitas agen, tabel merah, terbilang, pinjaman, rekening dan tanda tangan. Owner mengelola identitas melalui **Identitas Invoice**; data rekening dan aset tanda tangan disimpan privat di database. [Detail format dan pengujian](docs/audit/invoice-reference-20261030.md).

Menu samping dikelompokkan dalam Master Data, Pembelian & Penjualan, Gudang / Logistik, Sales / Sopir, Keuangan, Laporan, dan Pengaturan. Kelompok dapat dibuka/tutup, hanya muncul jika akun memiliki menu di dalamnya, dan tidak menambah hak akses. Transaksi Gudang tetap tersedia melalui halaman gudang; menu samping langsung menampilkan proses penerimaan, Surat Jalan, dan penerimaan kembali tanpa pintasan yang berulang.

Menu **Total Rincian Tabung** tersedia untuk Owner dan Logistik di kelompok Gudang / Logistik. Ringkasan per jenis memisahkan Gudang, Pelanggan, Agen, dan Kendaraan; rincian isi/kosong ditampilkan untuk gudang dan kendaraan. Titipan memakai saldo kewajiban pelanggan saat ini, sedangkan kendaraan memakai muatan aktif dikurangi pengiriman terkonfirmasi ditambah kosong yang dikumpulkan. Perjalanan yang sudah diterima gudang tidak dihitung kembali sebagai kendaraan. Tampilan menyediakan cetak/Excel melalui kontrol keluaran transaksi bersama. Kegagalan sumber data menampilkan pesan, bukan total parsial.

Pembuatan petugas menerima username 3–30 karakter atau email lengkap, dinormalisasi menjadi huruf kecil. Email dikonfirmasi oleh layanan admin tanpa undangan; login menggunakan ID/email yang sama. ID Owner tetap dicadangkan dan hanya Owner aktif dapat membuat petugas dengan tugas Logistik, Sales/Sopir, dan/atau Keuangan.

Surat Jalan mendukung **+ Tambah Muatan** dan **Hapus Muatan** untuk beberapa jenis tabung. Satu SJ/perjalanan tampil sebagai kelompok; masing-masing jenis tetap memiliki catatan stok dan pengiriman sendiri. Sopir memilih jenis muatan sebelum mencatat faktur pelanggan. Penerimaan kembali kelompok memeriksa semua jenis dalam satu transaksi. Cetak SJ mencakup seluruh muatan. Jenis duplikat, stok kurang, klik ulang, dan hitungan pulang yang tidak cocok ditolak atau diproses sekali tanpa menggandakan stok.

GASPOS dapat dipasang sebagai aplikasi web melalui **Pasang** atau menu browser **Instal aplikasi** pada browser yang mendukungnya. Manifest memakai scope `/GasPos-Online/`, mode standalone, dan ikon PNG 192/512. Service worker tidak menyimpan cache atau mencegat permintaan; login, stok, dan transaksi tetap memerlukan internet. Pemasangan harus disetujui pengguna pada perangkatnya. Pintasan browser lama mungkin perlu diganti dengan pemasangan aplikasi yang baru.

Pada faktur Sopir, pilihan **Jenis Tabung** berada langsung setelah Pelanggan, dengan sisa muatan per jenis. Penggantian jenis mempertahankan pelanggan dan catatan, lalu menghitung ulang batas pengiriman. Daftar Sopir dan penerimaan kembali menampilkan tugas aktif secara default; perjalanan selesai tersedia melalui tombol riwayat. Jumlah tugas perjalanan dihitung per kelompok SJ, sehingga dua jenis muatan dalam satu SJ tetap satu perjalanan.
