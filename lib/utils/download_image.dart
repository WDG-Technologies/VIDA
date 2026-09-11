import 'dart:typed_data';

import 'download_image_stub.dart'
    if (dart.library.html) 'download_image_web.dart'
    if (dart.library.io) 'download_image_io.dart' as impl;

/// Descarga PNG (web: archivo; móvil: hoja para guardar/compartir).
Future<void> downloadPngBytes(Uint8List bytes, String filename) =>
    impl.downloadPngBytes(bytes, filename);
