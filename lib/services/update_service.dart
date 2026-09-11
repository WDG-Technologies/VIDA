import 'dart:convert';
import 'dart:io';

/// Consulta releases de GitHub para detectar versiones nuevas.
class UpdateService {
  static const repo = 'WDG-Technologies/VIDA';
  static const releasesUrl =
      'https://github.com/WDG-Technologies/VIDA/releases';
  static const apiLatest =
      'https://api.github.com/repos/WDG-Technologies/VIDA/releases/latest';

  /// Versión embebida (mantener alineada con pubspec.yaml).
  static const currentVersion = '0.9.2';
  static const currentBuild = 14;
  static const currentLabel = '0.9.2 (Beta)';
  static String get currentFull => '$currentVersion+$currentBuild';

  static Future<AppUpdateInfo?> checkLatest() async {
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 12)
      ..idleTimeout = const Duration(seconds: 12);
    try {
      return await () async {
        final req = await client.getUrl(Uri.parse(apiLatest));
        req.headers.set(HttpHeaders.userAgentHeader, 'VIDA-App/$currentVersion');
        req.headers.set(HttpHeaders.acceptHeader, 'application/vnd.github+json');
        final res = await req.close();
        if (res.statusCode != 200) return null;
        final body = await res.transform(utf8.decoder).join();
        final json = jsonDecode(body) as Map<String, dynamic>;
        final tag = (json['tag_name'] as String? ?? '').trim();
        final name = (json['name'] as String? ?? tag).trim();
        final htmlUrl = json['html_url'] as String? ?? releasesUrl;
        final remote = _parseVersion(tag.isNotEmpty ? tag : name);
        if (remote == null) return null;

        String? apkUrl;
        final assets = json['assets'] as List? ?? const [];
        for (final a in assets) {
          if (a is! Map) continue;
          final n = (a['name'] as String? ?? '').toLowerCase();
          final u = a['browser_download_url'] as String?;
          if (u != null && n.endsWith('.apk')) {
            apkUrl = u;
            if (n.contains('vida')) break;
          }
        }

        final newer = _isNewer(remote, currentVersion);
        return AppUpdateInfo(
          tag: tag,
          title: name,
          htmlUrl: htmlUrl,
          apkUrl: apkUrl,
          remoteVersion: remote,
          isNewer: newer,
        );
      }()
          .timeout(const Duration(seconds: 15));
    } catch (_) {
      return null;
    } finally {
      client.close(force: true);
    }
  }

  /// Extrae `1.2.3` de tags tipo `v0.8.0`, `0.8-beta`, `VIDA-v0.8`.
  static String? _parseVersion(String raw) {
    final m = RegExp(r'(\d+\.\d+(?:\.\d+)?)').firstMatch(raw);
    return m?.group(1);
  }

  static bool _isNewer(String remote, String local) {
    List<int> parts(String v) {
      final p = v.split('.').map((e) => int.tryParse(e) ?? 0).toList();
      while (p.length < 3) {
        p.add(0);
      }
      return p;
    }

    final a = parts(remote);
    final b = parts(local);
    for (var i = 0; i < 3; i++) {
      if (a[i] > b[i]) return true;
      if (a[i] < b[i]) return false;
    }
    return false;
  }
}

class AppUpdateInfo {
  final String tag;
  final String title;
  final String htmlUrl;
  final String? apkUrl;
  final String remoteVersion;
  final bool isNewer;

  const AppUpdateInfo({
    required this.tag,
    required this.title,
    required this.htmlUrl,
    required this.apkUrl,
    required this.remoteVersion,
    required this.isNewer,
  });
}
