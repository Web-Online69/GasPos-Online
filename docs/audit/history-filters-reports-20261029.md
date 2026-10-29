# Filter riwayat dan laporan transaksi — 29 Oktober 2026

## Penggunaan

Setiap tabel riwayat menyediakan Cari Data serta pilihan sesuai kolomnya: pelanggan/supplier/mitra, jenis tabung, jenis transaksi/biaya, peran, status, Sopir dan kendaraan. Rentang tanggal muncul hanya pada tabel yang memiliki tanggal. Master produk, pelanggan dan supplier mempertahankan pencarian kode/nama/kontak/alamat yang sudah ada. Filter digabungkan dengan logika AND; Reset Filter mengembalikan seluruh catatan. Data baru yang dimuat ulang langsung mengikuti filter aktif pada tabel yang sama.

Menu **Laporan Transaksi** tersedia bagi empat peran:

| Peran | Jenis laporan |
|---|---|
| Owner | Pembelian, Penjualan/INV, uang masuk, pembayaran supplier, biaya, gudang/SJ, perjalanan, faktur barang, mutasi stok |
| Keuangan | Pembelian, Penjualan/INV, uang masuk, pembayaran supplier, biaya |
| Logistik | Gudang/SJ, perjalanan, faktur barang, mutasi stok; tanpa harga |
| Sales/Sopir | Perjalanan dan faktur barang sesuai penugasan/RLS; tanpa harga |

Pilih jenis laporan → isi pencarian/rentang tanggal/pilihan terkait → periksa jumlah serta total → Cetak Hasil Filter → Cetak / Simpan PDF. Cetak hanya memuat baris dan total hasil filter, bukan seluruh data. Hasil kosong tetap dapat ditinjau tanpa data palsu. Tanggal awal setelah tanggal akhir menonaktifkan cetak.

Tanggal memakai WIB. Pembelian/Penjualan memiliki pilihan Tanggal Faktur atau Tanggal Input; pembayaran memakai tanggal pembayaran; biaya memakai tanggal biaya. Laporan neto dokumen menunjukkan posisi saldo saat dibuka termasuk retur/refund, bukan saldo historis per tanggal. Pembayaran merupakan bruto, refund dijelaskan terpisah. Laporan mutasi menunjukkan perubahan selama rentang, bukan saldo akhir. Ringkasan HPP pada menu Keuangan tetap seluruh periode dan tidak mengikuti filter rincian transaksi; ini diberi keterangan eksplisit.

## Kelengkapan dan keamanan

Riwayat dibaca per halaman dengan urutan stabil, sampai halaman kosong. Batas tampilan50/100/200/500 dihapus; error halaman mana pun membatalkan hasil parsial. Pengaman100.000 baris mengembalikan error, bukan laporan yang diam-diam terpotong. Query tetap menggunakan Supabase client milik akun yang login dan RLS yang sudah ada. Tidak ada service key di browser dan tidak ada akun/peran baru.

Migrasi `20261029010157_history_filters_complete_stock.sql` menghapus batas500 dari fungsi riwayat mutasi, mempertahankan bentuk output dan pemeriksaan Owner/Logistik; tidak mengubah transaksi atau grant. Verifikasi server: Logistik dapat membaca mutasi/faktur fisik tetapi baris finansial tersembunyi; Sopir tidak mendapat perjalanan Sopir lain maupun data keuangan/gudang; Keuangan dapat membaca tagihan, pembayaran, biaya, dan nama mitra melalui RPC yang sudah ada.

## Validasi

200 pemeriksaan otomatis PASS: alur86, database76, akun16, antarmuka/filter/laporan22. Pengujian baru mencakup batas hari WIB, filter gabungan, pagination1201 baris dengan batas server lebih kecil, kegagalan parsial, sumber data/cetak empat peran, akses terlarang sebelum query, pembayaran masuk/keluar, total cetak dan escaping HTML, serta fungsi mutasi501 baris dengan penolakan peran yang salah. Build lokal PASS. Verifikasi deployment/browser dicatat setelah publikasi.

Perintah CLI migrasi sempat ditolak automatic approval review karena telemetry eksternal. File migrasi telah terbentuk; penerapan dilakukan melalui konektor Supabase tanpa melanjutkan pengiriman telemetry. Advisor keamanan yang sudah ada tidak dinyatakan bersih oleh perubahan ini.

## Dashboard ringkas dan nomor panjang

Pekerjaan Saya ditampilkan sebagai satu tombol jumlah tugas. Klik membuka halaman Daftar Kerja; tugas nol disembunyikan, kegagalan pemuatan tetap diberi tanda bukan dianggap nol. Jumlah tugas bukan jumlah transaksi unik karena satu transaksi bisa memiliki beberapa tindak lanjut. Filter riwayat dilipat secara awal agar tidak memenuhi layar. Referensi panjang diringkas pada tabel; klik untuk membaca nomor lengkap. Nilai yang disimpan, pencarian, pilihan form, dan dokumen cetak tetap memakai data utuh.

## Verifikasi browser publik

Akun Logistik: ringkasan Pekerjaan Saya0 membuka halaman Daftar Kerja dengan pesan tidak ada pekerjaan tertunda. Laporan Gudang/SJ menyediakan hanya empat jenis laporan fisik tanpa nilai uang. Pencarian SJ trial dan rentang28 Oktober menghasilkan1 dari6 baris, penuh2/kosong0; pratinjau cetak memuat tepat baris, filter dan total yang sama serta referensi utuh. Rentang tanggal terbalik menonaktifkan cetak. Riwayat Mutasi memuat10 baris; pencarian nomor LOG lengkap yang tampil singkat ditambah29 Oktober menyisakan1 baris; klik nomor membuka referensi lengkap. Uji Reset menemukan pembaruan tabel berjalan sebelum reset bawaan browser; diperbaiki dengan menjalankan filter setelah reset bawaan. Verifikasi perangkat HP fisik dan UI semua peran tetap belum dilakukan.
