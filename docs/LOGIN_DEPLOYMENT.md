# Penerbitan halaman login GASPOS

## Status
Frontend GASPOS menggunakan Vite + Supabase Auth. Backend Supabase khusus GASPOS ada di proyek `lflnbaqpmkjjyxpznozg`. Website belum terbit; jangan bagikan tautan yang belum diverifikasi.

## Konfigurasi build (publik)
- `VITE_SUPABASE_URL=https://lflnbaqpmkjjyxpznozg.supabase.co`
- `VITE_SUPABASE_PUBLISHABLE_KEY`: ambil dari Supabase → Project Settings → API Keys → Publishable key, bukan secret key / service_role.
- Tidak pernah menyimpan password administrator, JWT pengguna atau secret key di repository.

## Jalur Firebase Hosting
1. Sambungkan akun Firebase yang dikhususkan untuk GASPOS; tetap gunakan paket Spark bila kuota mendukung.
2. Buat proyek Hosting dan pilih nama domain web.app yang tersedia.
3. Build: `npm install && npm run build`. Direktori publik hasil build: `dist`. File `firebase.json` sudah disiapkan untuk SPA.
4. Deploy Hosting melalui akun Firebase yang terhubung.
5. Uji URL HTTPS sebenarnya; masukkan URL sah dalam daftar redirect/origin Auth bila diperlukan.
6. Buat pengguna melalui Supabase Auth dengan cara aman dan tetapkan peran pada `public.gas_members` melalui admin yang berwenang.
7. Uji akun Owner, Logistik dan akun tanpa hak akses secara terpisah sebelum digunakan.

## Catatan penting
GitHub Pages dan Vercel Hobby tidak digunakan sebagai hosting operasional bisnis gratis karena batasan penggunaan komersial. Supabase Edge Functions juga tidak dapat dijadikan host HTML biasa tanpa domain kustom.

Aplikasi masih versi awal: halaman login berfungsi secara kode, tetapi tidak siap transaksi sebelum pengujian identitas dan aturan RLS.
