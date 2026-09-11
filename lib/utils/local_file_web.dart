import 'dart:typed_data';

import 'package:flutter/widgets.dart';

Future<bool> localPathExists(String path) async => false;

Future<Uint8List> readLocalBytes(String path) async =>
    throw UnsupportedError('Archivos locales no disponibles en web');

Future<String> copyPickedToSupport(String pickedPath, String fileName) async =>
    throw UnsupportedError('Guardar fondos personalizados no disponible en web');

ImageProvider localFileImageProvider(String path) =>
    throw UnsupportedError('Archivos locales no disponibles en web');

Future<String> writeTempBytes(String fileName, Uint8List bytes) async =>
    throw UnsupportedError('Temp files no disponibles en web');

Future<void> deleteOldFavoritoBgs({String? keepPath}) async {}
