import 'dart:convert';
import 'dart:io';
import 'package:package_info_plus/package_info_plus.dart';

class UpdateInfo {
  UpdateInfo(this.version, this.apkUrl, this.pageUrl, this.notes);
  final String version, apkUrl, pageUrl, notes;
}

/// Cek versi terbaru di GitHub Releases. Repo harus publik.
class Updater {
  static const repo = 'nandayogas/Dikjaya-scanner';

  static List<int> _parts(String v) {
    final clean = v
        .trim()
        .replaceFirst(RegExp(r'^[vV]'), '')
        .split('+')
        .first
        .split('-')
        .first;
    return clean.split('.').map((e) => int.tryParse(e) ?? 0).toList();
  }

  static bool isNewer(String latest, String current) {
    final a = _parts(latest), b = _parts(current);
    for (var i = 0; i < 3; i++) {
      final x = i < a.length ? a[i] : 0;
      final y = i < b.length ? b[i] : 0;
      if (x != y) return x > y;
    }
    return false;
  }

  /// Mengembalikan info bila ada versi lebih baru, null bila sudah terbaru.
  /// Melempar error bila gagal (tanpa internet, repo privat, dll).
  static Future<UpdateInfo?> check() async {
    final info = await PackageInfo.fromPlatform();
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 8);
    try {
      final req = await client.getUrl(
          Uri.parse('https://api.github.com/repos/$repo/releases/latest'));
      req.headers.set('User-Agent', 'dikjaya-scanner');
      req.headers.set('Accept', 'application/vnd.github+json');
      final res = await req.close().timeout(const Duration(seconds: 10));
      if (res.statusCode != 200) {
        throw 'GitHub membalas ${res.statusCode}';
      }
      final body = await res.transform(utf8.decoder).join();
      final j = jsonDecode(body) as Map<String, dynamic>;
      final tag = (j['tag_name'] ?? '') as String;
      if (!isNewer(tag, info.version)) return null;
      var apk = '';
      for (final a in (j['assets'] as List? ?? [])) {
        final name = (a['name'] ?? '') as String;
        if (name.endsWith('.apk')) {
          apk = a['browser_download_url'] as String;
          break;
        }
      }
      return UpdateInfo(
          tag, apk, (j['html_url'] ?? '') as String, (j['body'] ?? '') as String);
    } finally {
      client.close();
    }
  }
}
