# Audit hulu ke hilir — 29 Oktober 2026

Status keseluruhan: **belum 100%**. Data uji dipisahkan; transaksi produksi tidak dihapus. BMS tidak disentuh. Password tidak dicatat.

## Peran dan alur

Owner membeli serta menetapkan harga → Logistik menerima fisik (stok sekali) → Logistik membuat SJ/muatan/Sopir → Sopir mencatat Faktur Barang per pelanggan dan tanda tangan → Owner menetapkan harga dan menerbitkan INV tanpa mengurangi stok lagi → Keuangan mengonfirmasi pembayaran. Logistik menghitung pengembalian sebelum menutup perjalanan. Empat peran tetap dipertahankan; formulir satu kolom.

| Peran | Bukti langsung browser | Status |
|---|---|---|
| Owner | Login, antrean faktur, bukti tanda tangan, formulir harga/INV | PASS; penerbitan final BLOCKED |
| Logistik | Login, SJ2 penuh, cetak tanpa harga, validasi selisih, pengembalian1/1 oleh operator berbeda | PASS |
| Sales/Sopir | Login, tugas sendiri, kirim1/1, batas muatan, tanda tangan, cetak tanpa harga | PASS |
| Keuangan | Login, menu sesuai peran, laporan HPP/laba rugi dan aritmetika | PASS; pembayaran browser belum dilakukan |

Trial browser terakhir: stok awal55 penuh/38 kosong → muat2 →53/38 → kirim1 penuh/terima1 kosong → kembali1/1 → **54 penuh/39 kosong**, perjalanan RETURNED. INV faktur trial belum diterbitkan. Bukti: [trial browser](browser-role-trial-20261028.md).

## Bug dan perbaikan

| Masalah/reproduksi | Akar masalah | Perbaikan dan uji ulang |
|---|---|---|
| Ulangi simpan pengiriman setelah respons hilang: kuantitas bisa tercatat dua kali | RPC lama tanpa identitas permintaan | FIXED: UUID stabil di form; RPC mengunci UUID dan membandingkan seluruh payload/peran; retry menghasilkan ID sama; payload berbeda ditolak |
| Ulangi simpan biaya: biaya/laba dapat terhitung dua kali | RPC biaya tanpa idempotensi | FIXED: UUID stabil, kunci transaksi, pemeriksaan payload dan presisi; retry hanya satu biaya |
| Ulangi refund dengan UUID sama tetapi dokumen/nominal berbeda: respons sukses palsu | Fungsi mengembalikan ID sebelum membandingkan payload | FIXED: kunci UUID dan pemeriksaan dokumen/nominal sebelum pengakuan retry; batas saldo tetap berlaku |

Migrasi server `final_hulu_hilir_retry_guards` diterapkan. Fungsi baru tidak dapat dieksekusi anon. Uji server memakai klaim empat identitas trial dan transaksi rollback; ini bukan pengujian login password baru. Fixture server baru tidak tersisa. Tidak menerbitkan INV server untuk melewati blokir browser.

## Skenario penuh terisolasi

Skenario lokal PostgreSQL/PGlite: beli100@17.000; terima100; muat60; kirim20/15/10 dan terima kosong15/15/8; konfirmasi penerima; INV45@18.500; pembayaran pelanggan sebagian lalu lunas, supplier lunas; biaya20.000; kembali15 penuh/38 kosong. Seluruh tahap dan larangan diuji melalui fungsi/peran.

| Hasil fixture lokal | Nilai |
|---|---:|
| Stok awal penuh/kosong | 0/0 |
| Stok akhir penuh/kosong | 55/38 |
| Pendapatan | Rp832.500 |
| HPP | Rp765.000 |
| Laba kotor | Rp67.500 |
| Biaya operasional | Rp20.000 |
| Laba bersih | Rp47.500 |
| Piutang/utang akhir | Rp0/Rp0 |
| Kekurangan kosong A/B/C | 5/0/2 |

Angka tersebut khusus fixture, bukan saldo bisnis produksi. Laporan aplikasi saat ini merupakan estimasi rata-rata tertimbang seluruh data, belum laporan periode/FIFO.

## Validasi dan deployment

**187 PASS**: alur86, database76, akun16, antarmuka/alur9. Build PASS. Source perbaikan `80fa486fb8a4cb2f02b123c952bebc4d646edf20`; CI40794547750 dan Pages40794547735 sukses; aset JS `index-CrJGZeih.js`. Tambahan assertion saldo utang supplier dan laporan ini diterbitkan dalam commit dokumentasi berikutnya.

Audit integritas sebelum penutupan trial: nol stok negatif, harga master ganda, muatan berlebih, selisih hitung perjalanan RETURNED, INV tanpa tanda tangan, atau INV perjalanan tanpa pengiriman sah. Setelah rekonsiliasi browser, status RETURNED serta saldo54/39 diperiksa langsung melalui database.

## BLOCKED dan pekerjaan tersisa

Automatic approval review menolak klik final INV Rp18.500 karena menghasilkan catatan keuangan permanen dan mewajibkan handoff pengguna. INV serta pembayaran browser belum diuji sampai selesai; tidak diakali melalui API/SQL. Setelah pengguna menjalankan aksi final, perlu pemeriksaan cetak INV, pembayaran, saldo dan laporan ulang. Verifikasi perangkat HP fisik dan pemeriksaan setiap halaman secara menyeluruh juga belum selesai. Temuan advisor keamanan yang sudah ada tidak dinyatakan seluruhnya bersih.

[Bukti terstruktur](final-end-to-end-20261029.json)
