# Perbaikan pembayaran saat koneksi terputus — 28 Oktober 2026

## Temuan

FAIL sebelum perbaikan: dua pengiriman pembayaran sebagian Rp100.000 menggunakan RPC lama menghasilkan dua baris pembayaran dan saldo terbayar Rp200.000, selama sisa tagihan masih cukup. Ini dapat terjadi ketika hasil permintaan pertama tidak sampai ke browser dan petugas mencoba Simpan kembali. Direproduksi pada PostgreSQL terisolasi; tidak menggandakan pembayaran produksi untuk pembuktian.

## Perbaikan

FIXED: formulir pembayaran terbaru membuat satu UUID permintaan yang tetap dipakai sampai formulir ditutup. Endpoint baru gaspos_record_payment_once mengunci ID permintaan, menjalankan validasi status/saldo dari prosedur lama, dan menyimpan ID permintaan serta akun pencatat. Pengiriman ulang identik mengembalikan ID pembayaran yang sama. Perubahan dokumen, nominal, atau petugas dengan ID yang sudah dipakai ditolak. Pembayaran sengaja berikutnya dengan ID baru tetap diperbolehkan walaupun nominal sama.

Kolom tambahan pada gas_payments bersifat nullable untuk riwayat lama. Tidak ada pembayaran lama diubah/dihapus. Hak akses stok, harga dan tagihan tidak diperluas. Logistik/Sopir tetap ditolak oleh server. Endpoint lama dipertahankan untuk kompatibilitas; tab aplikasi lama perlu dimuat ulang agar formulir memakai endpoint dengan perlindungan retry.

## Verifikasi

- PASS: test:flow 35 pemeriksaan, termasuk 11 tambahan reproduksi/perbaikan pembayaran. Bukti terstruktur: [payment-retry-20261028.json](payment-retry-20261028.json).
- PASS: database GASPOS, role authenticated dengan identitas empat akun trial aktif. Retry dua kali menyimpan satu baris dan Rp100.000; akun pencatat sesuai; perubahan nominal/petugas, overpayment dan peran salah ditolak; pembayaran berbeda yang disengaja menghasilkan Rp200.000. Semua fixture audit dibatalkan melalui ROLLBACK. Ini uji hak database, bukan empat login browser baru.
- PASS: build lokal. CI dan deployment diperiksa sebelum laporan akhir.
- Uji ulang endpoint melalui login password nyata dicatat pada laporan akhir sesuai hasil yang benar-benar diterima.

Patch SQL: supabase/audit_payment_retry.sql. Migrasi server: idempotent_payment_form_retry. Tidak ada perubahan BMS.

## Batas trial layar

BLOCKED: login Logistik pada browser menampilkan akun/kata sandi tidak cocok. Setelah koreksi melalui formulir aman, permintaan login berakhir karena timeout dan tab tidak lagi tersedia, sehingga hasil autentikasi tidak diketahui. Tidak dilakukan pengisian password lewat jalur lain atau perubahan password akun. Layar Logistik/Sopir/Keuangan belum dinyatakan PASS. Trial end-to-end API empat akun sebelumnya tetap tercatat terpisah dalam live-four-role-20261028.md.
