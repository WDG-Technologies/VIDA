import 'dart:typed_data';

import 'package:share_plus/share_plus.dart';

import 'local_file.dart';

Future<void> downloadPngBytes(Uint8List bytes, String filename) async {
  final path = await writeTempBytes(filename, bytes);
  await Share.shareXFiles([XFile(path)]);
}
