import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Política de privacidad y términos de uso (en la app, sin URL externa).
class PrivacyScreen extends StatelessWidget {
  const PrivacyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Privacidad y términos')),
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
            'Solo si usas Comunidad o el Mapa de iglesias: cuenta (correo/nombre), '
            'publicaciones, comentarios, likes y datos de iglesias (nombre, ciudad, '
            'ubicación, asistentes). La autenticación anónima puede usarse para '
            'funciones básicas de Firebase.',
          ),
          _heading('Mapas y ubicación'),
          _p(
            'La ubicación se usa para centrar el mapa y buscar direcciones '
            '(Nominatim / OpenStreetMap). Los fondos de mapa se cargan desde '
            'servidores de tiles (p. ej. Carto). No vendemos tu ubicación.',
          ),
          _heading('Actualizaciones'),
          _p(
            'La app puede consultar GitHub Releases para avisar de versiones nuevas. '
            'Eso solo lee metadatos públicos del repositorio.',
          ),
          _heading('Publicidad y venta de datos'),
          _p(
            'No mostramos publicidad ni vendemos datos personales a terceros.',
          ),
          _heading('Tus controles'),
          _p(
            'Puedes cerrar sesión de Comunidad desde esa pantalla, desactivar '
            'notificaciones en Perfil y borrar datos locales desinstalando la app '
            'o limpiando el almacenamiento de VIDA.',
          ),
          _heading('Términos de uso'),
          _p(
            'VIDA se ofrece «tal cual», bajo licencia MIT del código abierto del proyecto. '
            'El contenido bíblico citado (p. ej. RVR1909) y el material de terceros '
            'conservan sus respectivas atribuciones. Úsala para edificación; no la uses '
            'para acosar, spam o contenido ilegal en Comunidad.',
          ),
          _heading('Contacto'),
          _p(
            'Proyecto: github.com/WDG-Technologies/VIDA — WDG Technologies.',
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
