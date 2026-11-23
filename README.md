# Scan Motor Honda (Flutter + ELM327 Bluetooth)

## Cara menjalankan
1. Pasang Flutter SDK, lalu di folder ini jalankan:
   flutter create --platforms=android --project-name scan_motor_honda .
   (file lib/ dan pubspec.yaml milik Anda tidak ditimpa; kalau ditanya, pertahankan)
2. flutter pub get
3. Edit android/app/src/main/AndroidManifest.xml, tambahkan di dalam <manifest>:

   <uses-permission android:name="android.permission.BLUETOOTH" android:maxSdkVersion="30"/>
   <uses-permission android:name="android.permission.BLUETOOTH_ADMIN" android:maxSdkVersion="30"/>
   <uses-permission android:name="android.permission.BLUETOOTH_CONNECT"/>
   <uses-permission android:name="android.permission.BLUETOOTH_SCAN"/>
   <uses-permission android:name="android.permission.ACCESS_FINE_LOCATION"/>

4. Di android/app/build.gradle(.kts) pastikan minSdk minimal 21.
5. flutter run (HP tersambung USB) atau flutter build apk.

## Catatan penting
- Pasangkan ELM327 dulu di pengaturan Bluetooth HP (PIN 1234 / 0000).
- Motor Honda memakai konektor diagnostik 4-pin, bukan OBD2 16-pin. Perlu kabel
  konverter ke OBD2, atau sambung langsung ke pin K-line sesuai skema motor.
- Banyak ECU motor tidak menjawab perintah OBD2 standar. Gunakan tab Terminal
  untuk mencoba protokol (ATSP3/4/5) dan melihat balasan mentah.
- Kamus kode di lib/dtc_db.dart perlu dicocokkan dengan manual servis motor Anda.
- API paket flutter_blue_classic bisa sedikit berbeda antarversi; kalau ada
  error kompilasi di bagian koneksi, sesuaikan nama method di lib/main.dart
  dan lib/elm327.dart.
