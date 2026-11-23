import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_blue_classic/flutter_blue_classic.dart';

/// Pembungkus komunikasi serial dengan adaptor ELM327 (Bluetooth klasik).
class Elm327 {
  Elm327(this._conn) {
    _sub = _conn.input?.listen(_onData, onDone: () => connected = false);
  }

  final BluetoothConnection _conn;
  StreamSubscription<Uint8List>? _sub;
  final StringBuffer _buf = StringBuffer();
  Completer<String>? _pending;
  bool connected = true;

  /// Log semua perintah dan balasan (dipakai tab Terminal).
  final StreamController<String> log = StreamController<String>.broadcast();

  void _onData(Uint8List data) {
    _buf.write(utf8.decode(data, allowMalformed: true));
    final s = _buf.toString();
    final idx = s.indexOf('>');
    if (idx < 0) return;
    _buf.clear();
    final resp = s
        .substring(0, idx)
        .replaceAll('\r', '\n')
        .split('\n')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .join('\n');
    final c = _pending;
    if (c != null && !c.isCompleted) c.complete(resp);
  }

  Future<String> send(String cmd,
      {Duration timeout = const Duration(seconds: 6)}) async {
    while (_pending != null) {
      await Future.delayed(const Duration(milliseconds: 20));
    }
    final c = Completer<String>();
    _pending = c;
    _buf.clear();
    log.add('> $cmd');
    try {
      _conn.output.add(Uint8List.fromList(ascii.encode('$cmd\r')));
      final r = await c.future.timeout(timeout);
      log.add(r);
      return r;
    } on TimeoutException {
      log.add('(timeout)');
      return 'TIMEOUT';
    } catch (e) {
      log.add('(error: $e)');
      return 'ERROR';
    } finally {
      _pending = null;
    }
  }

  /// Inisialisasi adaptor. [protocol]: 0=otomatis, 3=ISO 9141-2,
  /// 4=ISO 14230-4 (5 baud init), 5=ISO 14230-4 (fast init).
  Future<String> init(String protocol) async {
    final out = StringBuffer();
    for (final cmd in ['ATZ', 'ATE0', 'ATL0', 'ATH0', 'ATS0', 'ATSP$protocol']) {
      final r = await send(cmd, timeout: const Duration(seconds: 8));
      out.writeln('$cmd -> $r');
    }
    return out.toString();
  }

  void close() {
    connected = false;
    _sub?.cancel();
    try {
      (_conn as dynamic).close();
    } catch (_) {}
  }
}

/// Parser balasan OBD-II standar.
class Obd {
  static final _hex = RegExp(r'^[0-9A-F]+$');

  /// Ambil byte data dari balasan mode 01. Contoh balasan "41 0C 1A F8".
  static List<int>? parse(String resp, String mode, String pid) {
    final clean = resp.replaceAll(RegExp(r'\s'), '').toUpperCase();
    final head = '4${mode.substring(1)}$pid';
    final i = clean.indexOf(head);
    if (i < 0) return null;
    final rest = clean.substring(i + head.length);
    final bytes = <int>[];
    for (var k = 0; k + 1 < rest.length; k += 2) {
      final pair = rest.substring(k, k + 2);
      if (!_hex.hasMatch(pair)) break;
      bytes.add(int.parse(pair, radix: 16));
    }
    return bytes.isEmpty ? null : bytes;
  }

  /// Ubah balasan mode 03 menjadi daftar kode, mis. P0105.
  static List<String> parseDtc(String resp) {
    final codes = <String>[];
    for (final line in resp.split('\n')) {
      final l = line.replaceAll(RegExp(r'\s'), '').toUpperCase();
      if (!l.startsWith('43')) continue;
      final body = l.substring(2);
      for (var k = 0; k + 3 < body.length; k += 4) {
        final chunk = body.substring(k, k + 4);
        if (!_hex.hasMatch(chunk) || chunk == '0000') continue;
        final first = int.parse(chunk[0], radix: 16);
        const letters = ['P', 'C', 'B', 'U'];
        final letter = letters[first >> 2];
        final digit = first & 3;
        codes.add('$letter$digit${chunk.substring(1)}');
      }
    }
    return codes;
  }
}
