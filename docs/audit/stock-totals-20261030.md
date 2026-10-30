# Total Mutasi Stok — 30 Oktober 2026

Saldo Tabung menampilkan total penuh, kosong, dan seluruh tabung (penuh + kosong). Riwayat Mutasi menampilkan perubahan bersih penuh/kosong/total, dengan rincian masuk dan keluar. Total riwayat diberi penjelasan bahwa angka tersebut bukan saldo akhir.

Total mengikuti hanya baris yang sesuai pencarian, produk dan tanggal masing-masing tabel. Reset mengembalikan total seluruh baris; hasil kosong bernilai0. Tanggal terbalik menyembunyikan hasil dan menjumlahkan0 baris. Jumlah dijumlahkan dari nilai numerik asli pada data baris, sehingga pemisah ribuan Indonesia tidak mengubah hitungan. Saldo dan riwayat sama-sama dimuat per halaman sampai selesai agar total tidak terpotong pada batas respons API.

Data gagal dimuat tidak ditampilkan sebagai stok0; total diberi status tidak tersedia. Tidak ada perubahan stok, transaksi, database atau hak akses. Tetap hanya Owner/Logistik yang memiliki menu Mutasi Stok.

34 tes antarmuka/alur PASS dan build lokal PASS sebelum publikasi. Tiga tes baru mencakup pengelompokan ribuan, angka negatif/masuk/keluar, subset filter dan hasil kosong. CI menjalankan seluruh suite. Uji browser dilakukan setelah deployment; HP fisik belum diverifikasi.
