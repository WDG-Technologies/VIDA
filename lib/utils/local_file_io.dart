import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/widgets.dart';
import 'package:path_provider/path_provider.dart';

Future<bool> localPathExists(String path) async {
  try {
    return File(path).existsSync();
  } catch (_) {
    return false;
  }
}

Future<Uint8List> readLocalBytes(String path) => File(path).readAsBytes();

Future<String> copyPickedToSupport(String pickedPath, String fileName) async {
  final dir = await getApplicationSupportDirectory();
  final dest = File('${dir.path}/$fileName');
  await File(pickedPath).copy(dest.path);
  return dest.path;
}

ImageProvider localFileImageProvider(String path) => FileImage(File(path));

Future<String> writeTempBytes(String fileName, Uint8List bytes) async {
  final dir = await getTemporaryDirectory();
  final file = File('${dir.path}/$fileName');
  await file.writeAsBytes(bytes);
  return file.path;
}

Future<void> deleteOldFavoritoBgs({String? keepPath}) async {
  try {
    final dir = await getApplicationSupportDirectory();
    await for (final entity in dir.list()) {
      if (entity is! File) continue;
      final name = entity.uri.pathSegments.isNotEmpty
          ? entity.uri.pathSegments.last
          : entity.path;
      if (!name.startsWith('favorito_bg')) continue;
      if (keepPath != null && entity.path == keepPath) continue;
      try {
        await entity.delete();
      } catch (_) {}
    }
  } catch (_) {}
}
