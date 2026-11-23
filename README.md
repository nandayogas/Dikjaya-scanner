# DIKJAYA Scanner (Flutter + ELM327 Bluetooth)

Aplikasi diagnostik motor Honda, Yamaha, dan Kawasaki lewat ELM327 Bluetooth klasik.

## Build otomatis (GitHub Actions)
Push proyek ini ke GitHub. Workflow di .github/workflows/build-apk.yml membuat
folder Android, menambah izin Bluetooth, lalu membangun APK. Hasilnya ada di
tab Actions > Artifacts > dikjaya-scanner-apk.

## Build manual
1. flutter create --platforms=android --project-name dikjaya_scanner .
2. Tambah izin Bluetooth di android/app/src/main/AndroidManifest.xml
   (BLUETOOTH_CONNECT, BLUETOOTH_SCAN, ACCESS_FINE_LOCATION, dan BLUETOOTH
   serta BLUETOOTH_ADMIN dengan maxSdkVersion 30).
3. flutter pub get, lalu flutter build apk --release

## Catatan
- Pasangkan ELM327 dulu di pengaturan Bluetooth HP (PIN 1234 atau 0000).
- Pakai konektor sesuai merek motor. Banyak ECU motor tidak menjawab perintah
  OBD2 standar; gunakan tab Terminal untuk mencoba protokol dan melihat balasan.
- Kamus kode di lib/dtc_db.dart perlu dicocokkan dengan manual servis motor.
