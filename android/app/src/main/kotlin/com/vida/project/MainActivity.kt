package com.vida.project

import android.content.Intent
import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity() {
    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
    }

    companion object {
        /**
         * Referencia estática para que el resource shrinker de release
         * no elimine el icono de notificaciones (solo se usa desde Dart).
         */
        @Suppress("unused")
        private val keepNotificationDrawables = intArrayOf(
            R.drawable.ic_stat_vida,
        )
    }
}
