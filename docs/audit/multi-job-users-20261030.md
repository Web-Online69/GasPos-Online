# Akun dengan beberapa tugas — 30 Oktober 2026

Owner dapat mencentang lebih dari satu tugas ketika membuat atau mengedit petugas: Logistik, Sales/Sopir, dan Keuangan. Contoh: Logistik + Keuangan atau Logistik + Sopir. Owner tetap terpisah; tidak ada jenis peran kelima. ID login dan password tetap satu untuk akun tersebut.

Petugas memilih **Tugas Aktif** di bagian atas aplikasi. Menu, laporan, RLS dan RPC mengikuti tugas aktif. Saat Logistik aktif, harga/keuangan tetap tidak dapat dibaca walaupun akun juga ditugaskan Keuangan; pilih Keuangan untuk mengerjakan pembayaran/laporan. Pilihan aktif disimpan pada akun, sehingga perangkat lain yang memakai akun yang sama perlu memuat ulang agar menu mengikuti tugas aktif terbaru.

Daftar Sopir dan validasi penugasan memperhitungkan semua tugas yang diberikan Owner; akun Logistik + Sopir dapat ditugaskan kendaraan walaupun sedang memakai tugas Logistik. Setelah beralih ke Sales/Sopir, akun hanya dapat mengerjakan perjalanan yang ditugaskan kepadanya.

## Implementasi dan keamanan

`gas_members.assigned_roles` menyimpan daftar tugas; `role` tetap tugas aktif agar kebijakan transaksi yang sudah ada tetap berlaku. Migrasi mengisi akun lama hanya dengan peran lamanya; tidak memberikan tugas tambahan kepada akun yang sudah ada. RPC pergantian tugas hanya memproses akun sendiri yang aktif, dan menolak Owner/jenis tugas lain yang tidak diberikan. Penugasan/pengubahan daftar tugas tetap melalui layanan akun Owner; rollback password gagal memulihkan tugas aktif dan seluruh daftar tugas sebelumnya.

Backend `gaspos-invite-member` versi8 telah diterapkan dengan verifikasi JWT tetap aktif. Tidak ada akun baru, password baru, perubahan transaksi, atau reset database dalam pekerjaan ini. Reset data sebelumnya tetap belum dijalankan karena konfirmasi konektor ditolak.

## Pengujian

-18 tes akun PASS, termasuk pembuatan dua tugas, penolakan Owner/jenis tidak valid, dan rollback seluruh penugasan bila penggantian password gagal.
-31 tes antarmuka/filter/format/penomoran/tugas PASS, termasuk backfill satu peran, pergantian tugas di database, daftar Sopir bertugas ganda, membuat SJ untuk diri sendiri sebagai Sopir, mencatat faktur pada mode Sopir, penolakan pencatatan pada mode Keuangan, perlindungan data finansial pada mode Logistik, akun nonaktif, tugas dicabut, dan pencegahan peningkatan akses sendiri.
-Alur penuh empat peran86 PASS setelah migrasi baru; build lokal PASS. CI juga menjalankan suite database76 tes.

Penerapan database pertama mengalami requestState kedaluwarsa dan tidak mengubah skema. Percobaan baru berhasil, lalu diverifikasi bahwa seluruh akun lama masih memiliki hanya tugas semula. Advisor menambahkan satu RPC definer yang memang diizinkan untuk pengguna login dengan pemeriksaan akun sendiri; [panduan advisor](https://supabase.com/docs/guides/database/database-linter?lint=0029_authenticated_security_definer_function_executable). Temuan advisor lain yang sudah ada tidak dinyatakan bersih.

Belum memberikan tugas tambahan pada akun nyata. Owner memilihnya melalui menu Pengguna. Verifikasi HP fisik belum dilakukan.
