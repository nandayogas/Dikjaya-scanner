# DIKJAYA Scanner (Flutter + ELM327 Bluetooth)

Aplikasi diagnostik motor Honda, Yamaha, dan Kawasaki lewat ELM327 Bluetooth klasik.

## Build otomatis (GitHub Actions)
Push ke GitHub, build berjalan di tab Actions (artifact: dikjaya-scanner-apk).

## Tanda tangan tetap (wajib agar APK bisa diinstal sebagai pembaruan)
Simpan tiga secret di Settings > Secrets and variables > Actions:
KEYSTORE_BASE64, KEYSTORE_PASSWORD, KEY_ALIAS.
Simpan file keystore asli di tempat aman. Kalau hilang, pembaruan tidak bisa diinstal.

## Rilis versi baru (memicu notifikasi di aplikasi)
1. Naikkan version di pubspec.yaml, mis. 0.2.0+2 (angka setelah + harus naik).
2. Commit dan push, lalu buat tag: git tag v0.2.0 && git push origin v0.2.0
3. Workflow membuat Release berisi DIKJAYA-Scanner.apk.
Aplikasi mengecek Release terbaru saat dibuka dan lewat tombol Cek pembaruan.
Repo harus publik agar pengecekan bisa jalan.

## Catatan
- Pasangkan ELM327 dulu di pengaturan Bluetooth HP (PIN 1234 atau 0000).
- Banyak ECU motor tidak menjawab perintah OBD2 standar; pakai tab Terminal.
- Kamus kode di lib/dtc_db.dart perlu dicocokkan dengan manual servis motor.
