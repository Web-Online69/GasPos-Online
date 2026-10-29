# Trial browser empat peran — 28–29 Oktober 2026

Trial dilakukan pada website publik GASPOS menggunakan login peran nyata. Dokumen/produk/pelanggan uji dipisahkan dengan label GASPOS-UI-TRIAL-20261028 dan GASPOS-TRIAL-20261028-9E0B8F. Tidak ada password dalam laporan. BMS tidak disentuh.

## Hasil yang telah diverifikasi langsung

| Peran | Pekerjaan | Status |
|---|---|---|
| LOGISTIK | Login peran benar, tanpa menu harga/keuangan; stok tersedia55; membuat SJ2 penuh, Sopir trial_sales_sopir_1027, kendaraan UI TRIAL1028 | PASS |
| LOGISTIK | Popup cetak SJ memuat kendaraan/Sopir, penuh2/kosong0, tanpa harga | PASS |
| SALES_SOPIR | Login peran benar; membaca perjalanan yang ditugaskan | PASS |
| SALES_SOPIR | Pengiriman3 dari muatan2 ditolak validasi browser sebelum simpan | PASS |
| SALES_SOPIR | Menyimpan faktur1 penuh/1 kosong, FK-4C20A204 | PASS |
| SALES_SOPIR | Konfirmasi tanpa tanda tangan ditolak; tanda tangan sintetis atas nama PENERIMA UJI GASPOS UI TRIAL tersimpan | PASS |
| SALES_SOPIR | Cetak Faktur Barang memuat1/1, penerima dan tanda tangan, tanpa harga/nilai uang | PASS |
| OWNER | Login; antrean menunjukkan1 faktur siap INV; bukti nama/waktu/tanda tangan diperiksa | PASS |
| OWNER | Form konfirmasi satu kolom menghitung1 x Rp18.500 = Rp18.500 | PASS |
| OWNER | Klik final Konfirmasi & Buat INV | BLOCKED: automatic approval review menolak aksi sebagai penerbitan catatan keuangan permanen; membutuhkan handoff pengguna |
| KEUANGAN | Trial layar setelah penerbitan INV ini | BLOCKED: tahap INV belum diselesaikan |
| LOGISTIK | Terima kembali1 penuh/1 kosong dan tutup perjalanan | Belum dilakukan; perjalanan masih ON_ROUTE |

Bukti terstruktur: [browser-role-trial-20261028.json](browser-role-trial-20261028.json). Tanda tangan adalah data sintetis khusus trial, bukan klaim penerimaan barang nyata.

## Kekurangan yang ditemukan dan diperbaiki

1. **Logistik tidak dapat serah tugas SJ antarpetugas.** RLS hanya menampilkan dokumen buatan akun sendiri: direproduksi3 terlihat dari6 dokumen gudang. Patch audit_logistics_shared_read.sql memberi SELECT kepada Owner/Logistik aktif. Uji ulang database:6 dari6 terbaca,0 baris harga terbaca. Tidak menambah hak tulis; transaksi tetap RPC resmi. Keuangan tetap tidak membaca gudang; Sopir lain tetap tidak membaca SJ yang tidak ditugaskan.
2. **Menu Sopir memuat judul kosong Master Data/Transaksi, angka supplier0 yang tidak relevan, dan UUID Sopir.** Kelompok kosong dihapus, KPI master disembunyikan untuk Sopir/Keuangan, identitas pengemudi pada layar Sopir menjadi Saya. Uji ulang langsung setelah deployment: Beranda hanya pekerjaan dan Faktur Penjualan; baris perjalanan menampilkan Saya.

Perbaikan berada pada commit d382b7b52864efd35750e4f9bc294ab947ae9465. CI40676649284 dan deployment Pages40676649206 sukses. Build lokal lulus; test:flow39 pemeriksaan lulus. CI menjalankan juga regresi database76, akun16, dan workflow UI9, total140 pemeriksaan. Aset JS publik index-BCetULbA.js.

## Rekonsiliasi sementara

| Kondisi produk uji | Penuh | Kosong |
|---|---:|---:|
| Sebelum SJ UI | 55 | 38 |
| Gudang setelah muatan2 | 53 | 38 |
| Pengiriman pelanggan | 1 terkirim | 1 dikumpulkan |
| Sisa pada kendaraan | 1 | 1 |
| Gudang saat form INV disiapkan | 53 | 38 |

INV belum diterbitkan, pembayaran browser belum dicatat, dan kendaraan belum diterima kembali. Setelah penyelesaian sesuai angka uji, gudang diharapkan54 penuh/39 kosong; ini belum dinyatakan sebagai saldo akhir aktual. Data uji belum dibersihkan sesuai arahan dapat dihapus kemudian.

## Perbedaan dengan trial API

Trial API empat akun100 datang/60 muatan/45 terjual sebelumnya sudah PASS dan dilaporkan pada live-four-role-20261028.md. Hasil itu tidak disamakan dengan penyelesaian trial klik browser ini. Seluruh pengujian HP fisik dan semua halaman seluruh akun juga belum dinyatakan selesai. GASPOS belum dinyatakan100% selesai.
