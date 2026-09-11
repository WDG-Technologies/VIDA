import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/update_service.dart';
import '../theme/app_theme.dart';

/// Política de privacidad y términos (in-app + enlace público en GitHub).
class PrivacyScreen extends StatelessWidget {
  const PrivacyScreen({super.key});

  static const publicUrl =
      'https://github.com/WDG-Technologies/VIDA/blob/main/PRIVACY.md';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Privacidad y términos'),
        actions: [
          IconButton(
            tooltip: 'Ver en la web',
            icon: const Icon(Icons.open_in_new_rounded),
            onPressed: () => launchUrl(
              Uri.parse(publicUrl),
              mode: LaunchMode.externalApplication,
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          _heading('Privacidad'),
          _p(
            'VIDA es una app cristiana de WDG Technologies. '
            'Priorizamos que tu fe y tus datos personales no se conviertan en negocio.',
          ),
          _heading('Qué guardamos en tu dispositivo'),
          _p(
            'Nombre, racha espiritual, preferencias de apariencia, estudios bíblicos, '
            'resaltados, widgets, progreso de juegos locales y señales del versículo VIDA. '
            'Eso permanece en el teléfono salvo que tú lo borres o desinstales la app.',
          ),
          _heading('Qué se envía a la nube (Firebase)'),
          _p(
            'Si usas Comunidad, Mapa de iglesias o Testimonios: cuenta (correo/nombre), '
            'publicaciones, comentarios, likes, iglesias y reportes de contenido. '
            'La autenticación anónima puede usarse para funciones básicas de Firebase.',
          ),
          _heading('Mapas y ubicación'),
          _p(
            'La ubicación se usa para centrar el mapa y buscar direcciones '
            '(Nominatim / OpenStreetMap). Los fondos de mapa se cargan desde '
            'servidores de tiles de OpenStreetMap. No vendemos tu ubicación.',
          ),
          _heading('Actualizaciones y estabilidad'),
          _p(
            'La app puede consultar GitHub Releases para avisar de versiones nuevas. '
            'Usamos Firebase Analytics y Crashlytics (sin publicidad) para mejorar estabilidad.',
          ),
          _heading('Formita (avatar)'),
          _p(
            'Si activas Formita en Apariencia, se genera un avatar en blobatar.dev '
            'usando tu nombre (u otro texto) como semilla. Es opcional; con la opción '
            'apagada solo se muestra tu inicial en el dispositivo.',
          ),
          _heading('Avisos de Comunidad'),
          _p(
            'Si activas avisos en Comunidad → cuenta, se guarda un aviso en tu '
            'bandeja (Firestore) cuando alguien da like o responde. La app te lo '
            'muestra con una notificación local al abrirla o si ya está en uso. '
            'Puedes desactivarlos cuando quieras. No es publicidad ni requiere '
            'servidores de pago.',
          ),
          _heading('Términos de uso'),
          _p(
            'VIDA se ofrece «tal cual», bajo licencia MIT del código abierto del proyecto. '
            'El contenido bíblico citado (p. ej. RVR1909) y el material de terceros '
            'conservan sus respectivas atribuciones. Úsala para edificación; no la uses '
            'para acosar, spam o contenido ilegal en Comunidad.',
          ),
          _heading('Versión pública'),
          _p(
            'También publicada en:\n$publicUrl\n\n'
            'Releases: ${UpdateService.releasesUrl}',
          ),
          const SizedBox(height: 12),
          Text(
            'Última actualización: septiembre 2026 · VIDA 0.9',
            style: TextStyle(
              fontFamily: 'DM Sans',
              fontSize: 12,
              color: AppColors.emerald400,
            ),
          ),
        ],
      ),
    );
  }

  Widget _heading(String t) => Padding(
        padding: const EdgeInsets.only(top: 18, bottom: 8),
        child: Text(
          t,
          style: TextStyle(
            fontFamily: 'DM Sans',
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: AppColors.emerald800,
          ),
        ),
      );

  Widget _p(String t) => Text(
        t,
        style: TextStyle(
          fontFamily: 'DM Sans',
          fontSize: 14,
          height: 1.5,
          color: AppColors.emerald700,
        ),
      );
}
