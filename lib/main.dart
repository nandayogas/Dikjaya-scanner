import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_blue_classic/flutter_blue_classic.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dtc_db.dart';
import 'elm327.dart';
import 'updater.dart';

void main() => runApp(const ScanMotorApp());

class ScanMotorApp extends StatelessWidget {
  const ScanMotorApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'DIKJAYA Scanner',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorSchemeSeed: Colors.red,
          useMaterial3: true,
          brightness: Brightness.dark,
        ),
        home: const ConnectPage(),
      );
}

// ---------------------------------------------------------------- Koneksi

class ConnectPage extends StatefulWidget {
  const ConnectPage({super.key});
  @override
  State<ConnectPage> createState() => _ConnectPageState();
}

class _ConnectPageState extends State<ConnectPage> {
  final _bt = FlutterBlueClassic();
  final Map<String, BluetoothDevice> _bonded = {};
  final Map<String, BluetoothDevice> _found = {};
  StreamSubscription<dynamic>? _scanSub;
  Timer? _scanTimer;
  bool _scanning = false;
  String _protocol = '0';
  String _brand = 'Honda';
  String _status = '';
  bool _busy = false;

  static const _brands = ['Honda', 'Yamaha', 'Kawasaki', 'Lainnya'];

  static const _protocols = {
    '0': 'Otomatis',
    '3': 'ISO 9141-2',
    '4': 'ISO 14230-4 (5 baud)',
    '5': 'ISO 14230-4 (fast init)',
  };

  /// Nama yang umum dipakai adaptor ELM327 Bluetooth.
  static const _elmHints = ['obd', 'elm', 'vlink', 'v-link', 'vgate', 'icar'];

  static bool _likelyElm(String? name) {
    final n = (name ?? '').toLowerCase();
    return _elmHints.any(n.contains);
  }

  @override
  void initState() {
    super.initState();
    _load();
    _checkUpdate();
  }

  @override
  void dispose() {
    _stopScan(update: false);
    super.dispose();
  }

  Future<void> _checkUpdate({bool manual = false}) async {
    try {
      final u = await Updater.check();
      if (!mounted) return;
      if (u == null) {
        if (manual) {
          ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Aplikasi sudah versi terbaru.')));
        }
        return;
      }
      await showDialog(
        context: context,
        builder: (c) => AlertDialog(
          title: Text('Pembaruan tersedia (${u.version})'),
          content: Text(u.notes.isEmpty
              ? 'Versi baru DIKJAYA Scanner sudah tersedia.'
              : u.notes),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(c),
                child: const Text('Nanti')),
            FilledButton(
              onPressed: () {
                final url = u.apkUrl.isNotEmpty ? u.apkUrl : u.pageUrl;
                launchUrl(Uri.parse(url),
                    mode: LaunchMode.externalApplication);
                Navigator.pop(c);
              },
              child: const Text('Unduh'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (manual && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Gagal cek pembaruan: $e')));
      }
    }
  }

  Future<void> _load() async {
    await [
      Permission.bluetoothConnect,
      Permission.bluetoothScan,
      Permission.locationWhenInUse,
    ].request();
    await _loadBonded();
    _startScan();
  }

  Future<void> _loadBonded() async {
    try {
      final list = await _bt.bondedDevices;
      if (!mounted) return;
      setState(() {
        _bonded
          ..clear()
          ..addEntries((list ?? []).map((d) => MapEntry(d.address, d)));
      });
    } catch (e) {
      if (mounted) setState(() => _status = 'Gagal membaca perangkat: $e');
    }
  }

  void _startScan() {
    if (_scanning) return;
    try {
      _scanSub?.cancel();
      _scanSub = _bt.scanResults.listen((d) {
        if (!mounted) return;
        setState(() => _found[d.address] = d);
      });
      _bt.startScan();
      setState(() => _scanning = true);
      _scanTimer?.cancel();
      _scanTimer = Timer(const Duration(seconds: 15), _stopScan);
    } catch (e) {
      setState(() {
        _scanning = false;
        _status = 'Gagal mencari perangkat: $e';
      });
    }
  }

  void _stopScan({bool update = true}) {
    _scanTimer?.cancel();
    _scanSub?.cancel();
    _scanSub = null;
    try {
      _bt.stopScan();
    } catch (_) {}
    if (update && mounted && _scanning) setState(() => _scanning = false);
  }

  /// Gabungan perangkat terpasang dan hasil pencarian, ELM327 di atas.
  List<BluetoothDevice> get _devices {
    final all = <String, BluetoothDevice>{..._found, ..._bonded};
    final list = all.values.toList();
    list.sort((a, b) {
      final la = _likelyElm(a.name) ? 0 : 1;
      final lb = _likelyElm(b.name) ? 0 : 1;
      if (la != lb) return la.compareTo(lb);
      final ba = _bonded.containsKey(a.address) ? 0 : 1;
      final bb = _bonded.containsKey(b.address) ? 0 : 1;
      if (ba != bb) return ba.compareTo(bb);
      return (a.name ?? '').compareTo(b.name ?? '');
    });
    return list;
  }

  List<BluetoothDevice> get _candidates =>
      _devices.where((d) => _likelyElm(d.name)).toList();

  Future<void> _connect(BluetoothDevice d) async {
    _stopScan();
    setState(() {
      _busy = true;
      _status = _bonded.containsKey(d.address)
          ? 'Menyambung ke ${d.name ?? d.address}...'
          : 'Memasangkan dan menyambung ke ${d.name ?? d.address}... '
              'Masukkan PIN (1234 atau 0000) bila diminta.';
    });
    try {
      final conn = await _bt.connect(d.address);
      if (conn == null) throw 'Koneksi gagal';
      final elm = Elm327(conn);
      final info = await elm.init(_protocol);
      if (!mounted) return;
      setState(() => _status = '');
      await Navigator.push(
        context,
        MaterialPageRoute(
            builder: (_) =>
                DashPage(elm: elm, initInfo: info, brand: _brand)),
      );
      elm.close();
    } catch (e) {
      if (mounted) setState(() => _status = 'Gagal: $e');
    } finally {
      await _loadBonded();
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final devices = _devices;
    final candidates = _candidates;
    return Scaffold(
      appBar: AppBar(
        title: const Text('DIKJAYA Scanner'),
        actions: [
          IconButton(
            tooltip: 'Cek pembaruan',
            icon: const Icon(Icons.system_update),
            onPressed: () => _checkUpdate(manual: true),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: DropdownButtonFormField<String>(
              value: _brand,
              decoration: const InputDecoration(
                  labelText: 'Merek motor', border: OutlineInputBorder()),
              items: _brands
                  .map((b) => DropdownMenuItem(value: b, child: Text(b)))
                  .toList(),
              onChanged: (v) => setState(() => _brand = v ?? 'Honda'),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: DropdownButtonFormField<String>(
              value: _protocol,
              decoration: const InputDecoration(
                  labelText: 'Protokol ECU', border: OutlineInputBorder()),
              items: _protocols.entries
                  .map((e) =>
                      DropdownMenuItem(value: e.key, child: Text(e.value)))
                  .toList(),
              onChanged: (v) => setState(() => _protocol = v ?? '0'),
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              'Colokkan ELM327 ke motor dan nyalakan kunci kontak, lalu cari '
              'perangkat. Ketuk perangkat untuk menyambung. Jika belum '
              'dipasangkan, Android akan meminta PIN (1234 atau 0000).',
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Row(children: [
              Expanded(
                child: FilledButton.tonalIcon(
                  onPressed: _busy
                      ? null
                      : (_scanning ? _stopScan : _startScan),
                  icon: Icon(_scanning ? Icons.stop : Icons.bluetooth_searching),
                  label: Text(_scanning ? 'Berhenti mencari' : 'Cari perangkat'),
                ),
              ),
              if (candidates.length == 1) ...[
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _busy ? null : () => _connect(candidates.first),
                    icon: const Icon(Icons.flash_on),
                    label: const Text('Sambung otomatis'),
                  ),
                ),
              ],
            ]),
          ),
          if (_busy || _scanning) const Padding(
              padding: EdgeInsets.only(top: 12),
              child: LinearProgressIndicator()),
          if (_status.isNotEmpty)
            Padding(padding: const EdgeInsets.all(16), child: Text(_status)),
          Expanded(
            child: devices.isEmpty
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Text(
                        'Belum ada perangkat. Pastikan Bluetooth HP menyala '
                        'dan ELM327 sudah dicolok, lalu ketuk Cari perangkat.',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  )
                : ListView(
                    children: [
                      for (final d in devices)
                        ListTile(
                          leading: Icon(_bonded.containsKey(d.address)
                              ? Icons.bluetooth_connected
                              : Icons.bluetooth),
                          title: Text(d.name ?? 'Tanpa nama'),
                          subtitle: Text(
                              '${d.address} · ${_bonded.containsKey(d.address) ? 'sudah dipasangkan' : 'belum dipasangkan'}'),
                          trailing: _likelyElm(d.name)
                              ? const Chip(label: Text('ELM327?'))
                              : null,
                          onTap: _busy ? null : () => _connect(d),
                        ),
                    ],
                  ),
          ),
          TextButton.icon(
            onPressed: _busy
                ? null
                : () async {
                    await _loadBonded();
                  },
            icon: const Icon(Icons.refresh),
            label: const Text('Muat ulang perangkat terpasang'),
          ),
        ],
      ),
    );
  }
}

// -------------------------------------------------------------- Dashboard

class DashPage extends StatefulWidget {
  const DashPage(
      {super.key,
      required this.elm,
      required this.initInfo,
      required this.brand});
  final Elm327 elm;
  final String initInfo;
  final String brand;
  @override
  State<DashPage> createState() => _DashPageState();
}

class _DashPageState extends State<DashPage> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    final tabs = [
      DtcTab(elm: widget.elm, brand: widget.brand),
      LiveTab(elm: widget.elm),
      TerminalTab(elm: widget.elm, initInfo: widget.initInfo),
    ];
    return Scaffold(
      appBar: AppBar(title: const Text('Diagnostik')),
      body: IndexedStack(index: _tab, children: tabs),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        destinations: const [
          NavigationDestination(
              icon: Icon(Icons.warning_amber), label: 'Kode Error'),
          NavigationDestination(
              icon: Icon(Icons.speed), label: 'Data Langsung'),
          NavigationDestination(icon: Icon(Icons.terminal), label: 'Terminal'),
        ],
      ),
    );
  }
}

// -------------------------------------------------------------- Kode error

class DtcTab extends StatefulWidget {
  const DtcTab({super.key, required this.elm, required this.brand});
  final Elm327 elm;
  final String brand;
  @override
  State<DtcTab> createState() => _DtcTabState();
}

class _DtcTabState extends State<DtcTab> {
  List<String>? _codes;
  String _raw = '';
  bool _busy = false;

  Future<void> _read() async {
    setState(() => _busy = true);
    final r = await widget.elm.send('03');
    if (!mounted) return;
    setState(() {
      _raw = r;
      _codes = Obd.parseDtc(r);
      _busy = false;
    });
  }

  Future<void> _clear() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Hapus kode error?'),
        content: const Text(
            'Kode tersimpan di ECU akan dihapus. Pastikan masalahnya sudah '
            'diperbaiki.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: const Text('Batal')),
          FilledButton(
              onPressed: () => Navigator.pop(c, true),
              child: const Text('Hapus')),
        ],
      ),
    );
    if (ok != true) return;
    setState(() => _busy = true);
    final r = await widget.elm.send('04');
    if (!mounted) return;
    setState(() {
      _raw = r;
      _codes = null;
      _busy = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(children: [
          Expanded(
            child: FilledButton.icon(
              onPressed: _busy ? null : _read,
              icon: const Icon(Icons.search),
              label: const Text('Baca kode'),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: OutlinedButton.icon(
              onPressed: _busy ? null : _clear,
              icon: const Icon(Icons.delete_outline),
              label: const Text('Hapus kode'),
            ),
          ),
        ]),
        if (_busy) const Padding(
            padding: EdgeInsets.only(top: 12), child: LinearProgressIndicator()),
        const SizedBox(height: 16),
        if (_codes != null && _codes!.isEmpty)
          const Card(
              child: ListTile(
                  leading: Icon(Icons.check_circle, color: Colors.green),
                  title: Text('Tidak ada kode error terbaca'))),
        for (final c in _codes ?? <String>[])
          Card(
            child: ListTile(
              leading: const Icon(Icons.error_outline, color: Colors.orange),
              title: Text(c),
              subtitle: Text(DtcDb.standard[c] ?? 'Kode belum ada di kamus.'),
            ),
          ),
        if (_raw.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text('Balasan mentah:\n$_raw',
              style: const TextStyle(fontFamily: 'monospace', fontSize: 12)),
        ],
        if (DtcDb.forBrand(widget.brand).isNotEmpty) ...[
          const Divider(height: 32),
          Text('Kamus kode gangguan ${widget.brand}',
              style: const TextStyle(fontWeight: FontWeight.bold)),
          const Text('Verifikasi dengan manual servis tipe motor Anda.',
              style: TextStyle(fontSize: 12)),
          for (final e in DtcDb.forBrand(widget.brand).entries)
            ListTile(
              dense: true,
              leading: CircleAvatar(radius: 14, child: Text(e.key)),
              title: Text(e.value),
            ),
        ],
      ],
    );
  }
}

// ------------------------------------------------------------ Data langsung

class Pid {
  Pid(this.name, this.code, this.unit, this.calc);
  final String name, code, unit;
  final double Function(List<int> b) calc;
}

final _pids = <Pid>[
  Pid('RPM', '0C', 'rpm', (b) => ((b[0] * 256) + b[1]) / 4),
  Pid('Suhu mesin', '05', '°C', (b) => b[0] - 40.0),
  Pid('Suhu udara masuk', '0F', '°C', (b) => b[0] - 40.0),
  Pid('Tekanan MAP', '0B', 'kPa', (b) => b[0].toDouble()),
  Pid('Throttle', '11', '%', (b) => b[0] * 100 / 255),
  Pid('Kecepatan', '0D', 'km/h', (b) => b[0].toDouble()),
  Pid('Tegangan modul', '42', 'V', (b) => ((b[0] * 256) + b[1]) / 1000),
];

class LiveTab extends StatefulWidget {
  const LiveTab({super.key, required this.elm});
  final Elm327 elm;
  @override
  State<LiveTab> createState() => _LiveTabState();
}

class _LiveTabState extends State<LiveTab> {
  final Map<String, String> _vals = {};
  bool _running = false;

  Future<void> _loop() async {
    while (_running && mounted) {
      for (final p in _pids) {
        if (!_running || !mounted) break;
        final r = await widget.elm
            .send('01${p.code}', timeout: const Duration(seconds: 3));
        final b = Obd.parse(r, '01', p.code);
        var v = 'N/A';
        if (b != null) {
          try {
            v = p.calc(b).toStringAsFixed(p.unit == 'V' ? 2 : 0);
          } catch (_) {}
        }
        if (mounted) setState(() => _vals[p.code] = v);
      }
    }
  }

  void _toggle() {
    setState(() => _running = !_running);
    if (_running) _loop();
  }

  @override
  void dispose() {
    _running = false;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Padding(
        padding: const EdgeInsets.all(16),
        child: FilledButton.icon(
          onPressed: _toggle,
          icon: Icon(_running ? Icons.stop : Icons.play_arrow),
          label: Text(_running ? 'Berhenti' : 'Mulai baca data'),
        ),
      ),
      Expanded(
        child: GridView.count(
          crossAxisCount: 2,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 1.5,
          children: [
            for (final p in _pids)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(p.name, style: const TextStyle(fontSize: 12)),
                      Text(_vals[p.code] ?? '-',
                          style: const TextStyle(
                              fontSize: 28, fontWeight: FontWeight.bold)),
                      Text(p.unit, style: const TextStyle(fontSize: 12)),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
      const Padding(
        padding: EdgeInsets.all(12),
        child: Text('N/A = ECU motor tidak menjawab PID tersebut.',
            style: TextStyle(fontSize: 12)),
      ),
    ]);
  }
}

// ----------------------------------------------------------------- Terminal

class TerminalTab extends StatefulWidget {
  const TerminalTab({super.key, required this.elm, required this.initInfo});
  final Elm327 elm;
  final String initInfo;
  @override
  State<TerminalTab> createState() => _TerminalTabState();
}

class _TerminalTabState extends State<TerminalTab> {
  final _ctl = TextEditingController();
  final _lines = <String>[];
  StreamSubscription<String>? _sub;

  @override
  void initState() {
    super.initState();
    _lines.addAll(widget.initInfo.split('\n'));
    _sub = widget.elm.log.stream.listen((l) {
      if (mounted) setState(() => _lines.add(l));
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    _ctl.dispose();
    super.dispose();
  }

  void _send() {
    final c = _ctl.text.trim();
    if (c.isEmpty) return;
    _ctl.clear();
    widget.elm.send(c);
  }

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Expanded(
        child: ListView.builder(
          reverse: true,
          padding: const EdgeInsets.all(12),
          itemCount: _lines.length,
          itemBuilder: (_, i) => Text(_lines[_lines.length - 1 - i],
              style: const TextStyle(fontFamily: 'monospace', fontSize: 12)),
        ),
      ),
      Padding(
        padding: const EdgeInsets.all(12),
        child: Row(children: [
          Expanded(
            child: TextField(
              controller: _ctl,
              textCapitalization: TextCapitalization.characters,
              decoration: const InputDecoration(
                  hintText: 'Perintah, mis. ATDP atau 0100',
                  border: OutlineInputBorder()),
              onSubmitted: (_) => _send(),
            ),
          ),
          IconButton(onPressed: _send, icon: const Icon(Icons.send)),
        ]),
      ),
    ]);
  }
}
