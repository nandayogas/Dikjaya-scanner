/// Kamus kode. PENTING: verifikasi dengan buku manual servis motor Anda.
/// Tambahkan atau koreksi entri sesuai tipe motor.
class DtcDb {
  /// Kode OBD-II standar (hasil perintah 03).
  static const Map<String, String> standard = {
    'P0105': 'Sirkuit sensor MAP bermasalah. Cek kabel/konektor dan sensor MAP.',
    'P0110': 'Sirkuit sensor suhu udara masuk (IAT) bermasalah.',
    'P0115': 'Sirkuit sensor suhu mesin (ECT) bermasalah.',
    'P0120': 'Sirkuit sensor posisi throttle (TPS) bermasalah.',
    'P0130': 'Sirkuit sensor oksigen (O2) bermasalah.',
    'P0201': 'Sirkuit injektor silinder 1 bermasalah.',
    'P0335': 'Sirkuit sensor posisi crankshaft (CKP) bermasalah.',
    'P0505': 'Sistem kontrol idle (IACV/ISC) bermasalah.',
    'P0560': 'Tegangan sistem/aki tidak normal.',
  };

  /// Kode kedip (blink code) PGM-FI Honda. Isi awal terbatas dan perlu
  /// diverifikasi terhadap manual servis tipe motor Anda.
  static const Map<String, String> hondaBlink = {
    '1': 'Sensor MAP: tegangan rendah / sirkuit terbuka.',
    '2': 'Sensor MAP: tegangan tinggi / hubung singkat.',
    '7': 'Sensor suhu mesin (ECT): tegangan rendah.',
    '12': 'Injektor: sirkuit bermasalah.',
    '21': 'Sensor oksigen (O2): bermasalah.',
    '29': 'IACV/katup idle: bermasalah.',
    '33': 'EEPROM ECU: bermasalah.',
  };

  /// Kode gangguan sistem FI Yamaha. Isi awal terbatas, perlu diverifikasi.
  static const Map<String, String> yamahaFault = {
    '12': 'Sensor posisi crankshaft: sinyal tidak masuk.',
    '13': 'Sensor tekanan udara masuk: sirkuit terbuka/hubung singkat.',
    '14': 'Sensor tekanan udara masuk: selang atau sensor bermasalah.',
    '15': 'Sensor posisi throttle (TPS): sirkuit terbuka/hubung singkat.',
    '21': 'Sensor suhu mesin: sirkuit terbuka/hubung singkat.',
    '22': 'Sensor suhu udara masuk: sirkuit terbuka/hubung singkat.',
    '24': 'Sensor oksigen (O2): bermasalah.',
    '30': 'Sensor kemiringan (lean angle): bermasalah.',
    '33': 'Koil pengapian: sirkuit bermasalah.',
    '42': 'Sensor kecepatan: bermasalah.',
    '50': 'Memori ECU: bermasalah.',
  };

  /// Kode gangguan sistem FI Kawasaki. Isi awal terbatas, perlu diverifikasi.
  static const Map<String, String> kawasakiFault = {
    '11': 'Sensor throttle utama: bermasalah.',
    '12': 'Sensor tekanan udara masuk: bermasalah.',
    '13': 'Sensor suhu udara masuk: bermasalah.',
    '14': 'Sensor suhu air/mesin: bermasalah.',
    '21': 'Sensor crankshaft: bermasalah.',
    '24': 'Sensor kecepatan: bermasalah.',
    '31': 'Sensor motor jatuh (vehicle-down): bermasalah.',
  };

  /// Pilih kamus sesuai merek yang dipilih di layar koneksi.
  static Map<String, String> forBrand(String brand) {
    switch (brand) {
      case 'Honda':
        return hondaBlink;
      case 'Yamaha':
        return yamahaFault;
      case 'Kawasaki':
        return kawasakiFault;
      default:
        return const {};
    }
  }
}
