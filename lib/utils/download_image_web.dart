import 'dart:convert';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

Future<void> downloadPngBytes(Uint8List bytes, String filename) async {
  final dataUrl = 'data:image/png;base64,${base64Encode(bytes)}';
  final anchor = web.document.createElement('a') as web.HTMLAnchorElement;
  anchor.href = dataUrl;
  anchor.download = filename;
  web.document.body?.appendChild(anchor);
  anchor.click();
  anchor.remove();
}
