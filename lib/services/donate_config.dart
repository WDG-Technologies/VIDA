/// Donaciones vía Stripe Payment Link.
///
/// Para desactivar y volver al mensaje "aún no…": [enabled] = false.
class DonateConfig {
  /// true = abre Stripe; false = mensaje de no disponible.
  /// Reactivar en 1.0 con el Payment Link de producción.
  static const enabled = false;

  /// Link de Test (Stripe Dashboard → Test mode).
  /// En live, sustituir por el Payment Link de producción.
  static const paymentLinkUrl =
      'https://donate.stripe.com/test_3cI4gr2TJ3A4dX1gbBco000';

  static bool get isTestLink => paymentLinkUrl.contains('test_');
}
