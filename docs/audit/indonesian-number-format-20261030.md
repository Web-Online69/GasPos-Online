# Pencatatan angka Indonesia — 30 Oktober 2026

Kolom angka menampilkan pemisah ribuan titik (1.000.000), dan koma untuk desimal pada kolom yang memang mengizinkannya (1.000,50). Angka tanpa pemisah tetap dapat diketik. Kolom jumlah tabung tetap bilangan bulat; penyesuaian stok tetap dapat bernilai negatif.

Pemisahan tampilan dan nilai mencegah 1.000.000 terbaca sebagai1 atau NaN. Form mengirim angka numerik, bukan teks berformat. Nilai dari database diubah ke format Indonesia saat dimasukkan ke editor. Batas min/max/step, required dan pemeriksaan server dipertahankan. Nomor telepon, ID, password, tanggal dan kode tidak diformat sebagai angka.

Input memakai papan ketik numeric/decimal pada HP dan pengelompokan saat mengetik. Tabel kuantitas, laporan, total laporan dan cetaknya menggunakan format Indonesia. Tidak ada perubahan skema database atau transaksi produksi.

Validasi baru: pengelompokan jutaan, desimal, negatif, masukan ambigu/format internasional yang salah, batas muatan/nominal, step bilangan bulat/desimal, pengisian editor dari nilai API, serta pengecualian ID/tanggal. Pengujian alur antarmuka otomatis28 PASS dan build lokal PASS sebelum publikasi; verifikasi browser serta deployment dilakukan sesudahnya. Uji HP fisik belum dilakukan.
