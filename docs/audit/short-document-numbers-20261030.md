# Nomor dokumen singkat — 30 Oktober 2026

| Dokumen | Contoh |
|---|---|
| Invoice penjualan | INV 00001 |
| Pembelian | BEL 00001 |
| Surat Jalan | SJ 00001 |
| Terima barang | TBM 00001 |
| Faktur Barang Sopir | FK 00001 |
| Perjalanan | TRP 00001 |
| Koreksi stok | KOR 00001 |
| Retur penjualan/pembelian | RETJ 00001 / RETB 00001 |
| Pengembalian kosong | TKM 00001 |

Nomor tampilan unik dan tetap disimpan dalam `display_no`. Dokumen lama diberi nomor singkat menurut urutan tanggal input dan ID; nomor teknis asli tidak ditimpa. Catatan, relasi UUID, idempotency key, stok, nilai finansial, pembayaran, dan tanda tangan dipertahankan. Perbandingan digest delapan tabel inti sebelum/sesudah migrasi membuktikan seluruh isi lama identik setelah mengecualikan kolom nomor tampilan yang baru.

Counter privat melakukan alokasi atomik per awalan, sehingga permintaan bersamaan memperoleh nomor berbeda. Nomor tidak diulang saat dokumen dibatalkan/dihapus; setelah99999 nomor bertambah menjadi100000 tanpa terpotong. Counter dan fungsi generator tidak dapat diakses langsung oleh anon/authenticated. Trigger menjaga nomor tidak diubah manual. SJ yang terkait dokumen gudang memakai nomor yang sama, termasuk persetujuan pengajuan lama.

Nomor singkat digunakan pada daftar transaksi, pilihan penerimaan, saldo tagihan/pembayaran, mutasi stok, faktur barang, Surat Jalan, laporan dan cetak. Rincian Pembelian/Penjualan menyediakan Referensi Lama yang dilipat. Pencarian tabel transaksi tetap dapat memakai nomor teknis lama.

Pengujian lokal mencakup backfill semua jenis, pemeliharaan nomor lama/tanda tangan,20 permintaan insert dengan label unik, pencegahan pengubahan nomor/jenis, pemakaian ulang label SJ terkait, batas99999, penerapan migrasi ulang, serta guard keuangan Logistik/Sopir. Skenario penuh empat peran86 PASS dengan migrasi baru. Suite UI/filter/format/penomoran29 PASS; build PASS. Nomor tampilan tidak dijadikan bukti trial penerbitan invoice atau pembayaran baru lewat browser.

Migrations diterapkan melalui konektor Supabase; CLI dengan telemetry yang sebelumnya ditolak tidak dijalankan ulang. Advisor keamanan yang telah ada tetap dicatat, termasuk guarded definer view dan fungsi RPC, bukan dinyatakan semuanya bersih. Uji HP fisik belum dilakukan.

Validasi server sesudah penerapan: seluruh dokumen, pengajuan gudang, perjalanan dan faktur barang memiliki nomor tampilan unik dan tidak kosong. Tidak ada perubahan isi lama pada delapan tabel inti (termasuk stok, keuangan dan tanda tangan). Advisor sesudah penambahan policy deny eksplisit kembali sama dengan sebelum migrasi: [guarded definer view](https://supabase.com/docs/guides/database/database-linter?lint=0010_security_definer_view), RPC definer yang diizinkan, serta pengaturan pemeriksaan password yang sudah ada.

Uji browser publik melalui Owner: daftar Penjualan menampilkan INV00001–INV00008; rincian dan pratinjau cetak memakai INV00008, dengan Referensi Lama dilipat. Gudang menampilkan SJ dan TBM singkat; pratinjau SJ00003 memakai nomor yang sama. Kedua pratinjau adalah pembacaan dokumen yang sudah ada, tanpa penerbitan invoice, pembayaran atau perubahan stok baru. Source implementasi `3375f040a4b008cae9c7e71ea71522069a68aa7d`; CI40983437904 dan Pages40983437908 sukses sebelum penyesuaian cetak kuantitas akhir. Aset publik versi tersebut `index-4J6wTrsK.js` terverifikasi.
