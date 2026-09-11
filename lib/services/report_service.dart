import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Reportes de contenido (Comunidad / Testimonios) + ocultar en el dispositivo.
class ReportService {
  static const _hiddenKey = 'hidden_content_ids_v1';

  static Future<Set<String>> hiddenIds() async {
    final prefs = await SharedPreferences.getInstance();
    return (prefs.getStringList(_hiddenKey) ?? const []).toSet();
  }

  static Future<void> hideLocally(String id) async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(_hiddenKey) ?? <String>[];
    if (!list.contains(id)) {
      list.add(id);
      await prefs.setStringList(_hiddenKey, list);
    }
  }

  /// Guarda en Firestore `reports` y oculta localmente.
  static Future<void> submit({
    required String targetType, // post | comment | testimonio
    required String targetId,
    String? parentId,
    String reason = 'inapropiado',
  }) async {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    try {
      await FirebaseFirestore.instance.collection('reports').add({
        'targetType': targetType,
        'targetId': targetId,
        if (parentId != null) 'parentId': parentId,
        'reason': reason,
        'reporterId': uid,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (_) {
      // Aún ocultamos en el dispositivo si falla la red.
    }
    await hideLocally(
      parentId != null ? '$targetType:$parentId/$targetId' : '$targetType:$targetId',
    );
  }

  static String keyFor(String type, String id, {String? parentId}) =>
      parentId != null ? '$type:$parentId/$id' : '$type:$id';
}
