# Format INV mengikuti PDF contoh

Cetakan INV resmi menggunakan struktur contoh yang disediakan pengguna: identitas subagen/toko di kiri, judul INVOICE dan periode/nomor/tanggal pengiriman di kanan, MITRA KAMI dan alamat, tabel merah NAMA ITEM/HARGA PERUNIT/JUMLAH/TAXED/TOTAL, subtotal, TERBILANG, KETERANGAN pinjaman, rekening, serta stempel/tanda tangan dan nama penandatangan.

Kertas default Letter portrait mengikuti ukuran PDF contoh. A4 dan struk 58/80 mm tetap tersedia. Header merah, garis tabel, baris selang-seling, ruang baris kosong, nominal Indonesia dan terbilang dihitung dari rincian transaksi. Baris kosong tidak diekspor sebagai barang. Tidak menambahkan pajak yang belum tercatat: TAXED tetap kosong sebagaimana contoh.

## Identitas dan keamanan

Nama agen/toko, alamat, telepon, bank, nomor rekening, pemilik rekening, penandatangan serta gambar stempel/tanda tangan diimpor dari PDF ke tabel privat GASPOS dengan RLS Owner-only. Tidak menyimpan angka rekening atau aset tanda tangan dalam repositori publik. Nama perusahaan pada kepala dan bagian tanda tangan diseragamkan menggunakan nama agen pada kepala contoh. Semua nilai identitas dirender sebagai teks aman; gambar hanya PNG data URI tervalidasi.

Owner dapat memperbarui teks pada menu **Identitas Invoice**, dengan formulir vertikal. Logistik, Sopir dan Keuangan tidak dapat membaca atau mengubah tabel konfigurasi tersebut. Akun nonaktif dan anon ditolak. Form ini tidak mengubah stok, harga, rekening transaksi pembayaran, atau nilai penjualan.

## Data transaksi tetap benar

Nomor INV memakai nomor singkat dokumen yang sudah ada; bukan menyalin nomor contoh ke seluruh invoice. Nama/alamat pelanggan berasal dari master pelanggan. Produk, kuantitas, harga dan jumlah berasal dari rincian dan harga tersimpan pada invoice yang disetujui. Periode/tanggal pengiriman memakai stop terverifikasi terkait; transaksi lama tanpa stop memakai tanggal invoice. Beberapa tanggal diringkas sebagai rentang.

Pinjaman memakai saldo pelanggan per jenis tabung saat dicetak, termasuk transaksi yang belum menjadi invoice. Waktu saldo dicetak ditampilkan agar tidak dianggap sebagai saldo historis pada tanggal invoice. Saldo positif ditampilkan sebagai tabung dipinjam; tidak mengubah mutasi stok saat mencetak. Kegagalan memuat identitas, pelanggan, harga atau pinjaman menghentikan cetakan, bukan membuat angka nol pengganti.

## Verifikasi

- PASS lokal: terbilang, rupiah, multi tanggal/bulan, nominal tidak valid, transaksi belum disetujui dan HTML berbahaya.
- PASS lokal: RLS/privilege empat peran, Owner-only save, bank dengan nol awal tetap teks, anon/nonaktif ditolak, URI selain PNG dan kolom tidak dikenal ditolak.
- PASS visual: pratinjau PDF satu halaman Letter dibandingkan dengan contoh; teks, tabel, subtotal, terbilang, rekening serta stempel/tanda tangan terbaca tanpa tumpang tindih.
- Build/CI/deployment dan pemeriksaan web publik diverifikasi setelah perubahan dipublikasikan. Verifikasi printer termal fisik tetap memerlukan perangkat pengguna.
