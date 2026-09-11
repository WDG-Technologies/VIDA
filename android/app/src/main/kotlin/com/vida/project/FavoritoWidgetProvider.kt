package com.vida.project

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Color
import android.net.Uri
import android.util.TypedValue
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetProvider
import java.io.File
import kotlin.math.max
import kotlin.math.min

class FavoritoWidgetProvider : HomeWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences
    ) {
        val isEnabled = widgetData.getBoolean("favorito", false)
        val ref = widgetData.getString("fav_ref", null) ?: ""
        val verse = widgetData.getString("fav_verse", null) ?: ""
        val bgPath = widgetData.getString("fav_bg_path", null) ?: ""

        val views = RemoteViews(context.packageName, R.layout.favorito_widget)

        val openFavorito = HomeWidgetLaunchIntent.getActivity(
            context,
            MainActivity::class.java,
            Uri.parse("vida://favorito")
        )
        views.setOnClickPendingIntent(R.id.widget_root, openFavorito)
        views.setOnClickPendingIntent(R.id.widget_background, openFavorito)
        views.setOnClickPendingIntent(R.id.widget_content, openFavorito)

        if (isEnabled && (verse.isNotEmpty() || ref.isNotEmpty())) {
            val customFile = if (bgPath.isNotEmpty()) File(bgPath) else null
            val customBmp =
                if (customFile != null && customFile.exists()) {
                    loadScaledBitmap(customFile)
                } else {
                    null
                }

            // Detect from the actual pixels shown (more reliable than Dart prefs).
            val darkBg = if (customBmp != null) {
                isBitmapDark(customBmp)
            } else {
                false
            }

            if (customBmp != null) {
                views.setImageViewBitmap(R.id.widget_background, customBmp)
            } else {
                views.setImageViewResource(R.id.widget_background, R.drawable.widget_fav)
            }

            val verseColor =
                if (darkBg) Color.parseColor("#F2FFFFFF") else Color.parseColor("#DD000000")
            val refColor =
                if (darkBg) Color.parseColor("#CCFFFFFF") else Color.parseColor("#8A000000")
            views.setTextColor(R.id.widget_verse, verseColor)
            views.setTextColor(R.id.widget_ref, refColor)

            val verseText = if (verse.isNotEmpty()) "\u201C$verse\u201D" else ""
            views.setTextViewText(R.id.widget_verse, verseText)
            val sizeSp = when {
                verse.length > 120 -> 11f
                verse.length > 80 -> 12f
                else -> 13f
            }
            views.setTextViewTextSize(R.id.widget_verse, TypedValue.COMPLEX_UNIT_SP, sizeSp)
            views.setTextViewText(R.id.widget_ref, ref)
        } else {
            views.setImageViewResource(R.id.widget_background, 0)
            views.setTextViewText(R.id.widget_verse, "")
            views.setTextViewText(R.id.widget_ref, "")
        }

        for (id in appWidgetIds) {
            appWidgetManager.updateAppWidget(id, views)
        }
    }

    /** Decode and downscale so the parcel stays under the Binder ~1 MB limit. */
    private fun loadScaledBitmap(file: File): Bitmap? {
        return try {
            val bounds = BitmapFactory.Options().apply { inJustDecodeBounds = true }
            BitmapFactory.decodeFile(file.absolutePath, bounds)
            if (bounds.outWidth <= 0 || bounds.outHeight <= 0) return null

            val maxSide = max(bounds.outWidth, bounds.outHeight)
            var sample = 1
            while (maxSide / sample > 480) {
                sample *= 2
            }

            val opts = BitmapFactory.Options().apply {
                inSampleSize = sample
                inPreferredConfig = Bitmap.Config.RGB_565
            }
            val decoded = BitmapFactory.decodeFile(file.absolutePath, opts) ?: return null
            val w = decoded.width
            val h = decoded.height
            val maxW = 480
            if (w <= maxW) return decoded

            val nh = (h.toLong() * maxW / w).toInt().coerceAtLeast(1)
            val scaled = Bitmap.createScaledBitmap(decoded, maxW, nh, true)
            if (scaled != decoded) decoded.recycle()
            scaled
        } catch (_: Exception) {
            null
        }
    }

    /**
     * Dark if average center luminance is low, or if most sampled pixels are dark.
     * Threshold is intentionally generous so near-black photos get white text.
     */
    private fun isBitmapDark(bitmap: Bitmap): Boolean {
        val w = bitmap.width
        val h = bitmap.height
        if (w <= 0 || h <= 0) return false

        val x0 = w / 5
        val y0 = h / 5
        val x1 = w - x0
        val y1 = h - y0
        val step = max(1, min(w, h) / 32)

        var sum = 0.0
        var darkPixels = 0
        var n = 0

        var y = y0
        while (y < y1) {
            var x = x0
            while (x < x1) {
                val c = bitmap.getPixel(x, y)
                val r = Color.red(c) / 255.0
                val g = Color.green(c) / 255.0
                val b = Color.blue(c) / 255.0
                val lum = 0.2126 * r + 0.7152 * g + 0.0722 * b
                sum += lum
                if (lum < 0.55) darkPixels++
                n++
                x += step
            }
            y += step
        }

        if (n == 0) return false
        val avg = sum / n
        return avg < 0.58 || darkPixels >= (n * 0.55).toInt()
    }
}
