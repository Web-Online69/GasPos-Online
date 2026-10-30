# Cetak, PDF, Excel dan printer termal

Tanggal: 30 Oktober 2026, WIB.

## Penggunaan

- Halaman riwayat transaksi menyediakan **Cetak / PDF**, **Excel (.xlsx)** dan **Struk Termal / Bluetooth**. Hasil mengambil baris yang terlihat setelah filter. Formulir, tombol aksi dan data tersembunyi di balik hak akses tidak ikut diekspor.
- Baris riwayat yang memiliki kolom Aksi juga menyediakan **Cetak / Ekspor** untuk satu ringkasan transaksi. Ringkasan bukan pengganti rincian dokumen: INV, pembelian, SJ, faktur barang Sopir dan bukti pengembalian memiliki cetak rincian masing-masing.
- Halaman cetak rincian menyediakan pilihan kertas **A4**, **58 mm** dan **80 mm**, tombol cetak/PDF, Excel dan cetak printer Bluetooth.
- PDF memakai dialog cetak browser: pilih **Simpan sebagai PDF**. Tidak ada layanan PDF berbayar atau pengiriman dokumen ke server lain.
- Bluetooth memakai layanan cetak sistem operasi. Pasangkan printer melalui pengaturan HP/komputer, aktifkan driver/layanan cetak yang mendukung printer tersebut, kemudian pilih printer pada dialog cetak. Sesuaikan kertas 58/80 mm pada driver. Ini tidak menjanjikan koneksi langsung ke semua printer Bluetooth; printer yang hanya didukung aplikasi vendor memerlukan layanan/driver yang sesuai. Tidak ada pemindaian perangkat atau pemasangan Bluetooth otomatis oleh aplikasi.
- Format termal mengubah tabel lebar menjadi rincian vertikal per baris, sehingga label, jumlah dan nominal tetap terbaca. Tanda tangan tetap muncul pada dokumen bukti asli.

## Cakupan dan integritas

Pembelian (termasuk status draft yang dinyatakan jelas), INV penjualan yang disetujui, SJ, faktur barang Sopir, perjalanan/penerimaan kembali, pinjaman/pengembalian pelanggan, kewajiban/pengembalian supplier, pembayaran, biaya, mutasi/saldo stok, retur yang terlihat dalam riwayat, rincian keuangan dan ringkasan laba rugi. Riwayat/laporan tetap mengikuti hak akses empat peran. Harga tidak ditambahkan ke keluaran Logistik atau Sopir.

Ringkasan HPP/laba rugi mempertahankan metode, periode seluruh data dan status Belum valid; ekspor tidak mengubah estimasi menjadi angka laba final. Filter rincian transaksi tidak mengubah ringkasan seluruh periode.

File Excel adalah ZIP Open XML asli, bukan HTML/CSV dengan ekstensi Excel. Nomor dokumen/telepon tetap teks; nilai uang dan kuantitas berupa angka. Isi yang diawali `=` disimpan sebagai teks, bukan formula aktif. Metadata filter dan catatan dokumen disertakan. Isi ekspor tidak menulis transaksi, memotong stok, membuat INV atau mencatat pembayaran.

## Verifikasi

- PASS lokal: ZIP/CRC dan semua XML valid; angka 1.000.000 menjadi nilai numerik 1000000, angka negatif dan desimal tetap, identifier nol awal tetap teks, teks formula tidak menjadi formula, filter lembar sesuai baris.
- PASS lokal: HTML cetak menghindari injeksi isi tersimpan; kertas A4/58/80 dibedakan; pengujian regresi workflow dan build.
- Verifikasi web publik dan CI dilakukan setelah deployment.
- Belum diverifikasi: cetak fisik pada printer Bluetooth milik pengguna, dialog printer/driver Android/iOS/Windows tertentu, dan membuka hasil di Microsoft Excel desktop.

Rujukan batas API browser: https://developer.mozilla.org/en-US/docs/Web/API/Window/print dan https://developer.mozilla.org/en-US/docs/Web/API/Web_Bluetooth_API . Web Bluetooth mencakup BLE dan dukungannya terbatas; jalur cetak aplikasi menggunakan layanan cetak perangkat agar tidak menganggap semua printer memakai profil BLE yang sama.
