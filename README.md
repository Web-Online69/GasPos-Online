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
