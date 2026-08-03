package com.noctilune.duitges

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.content.ComponentName
import android.content.ContentValues
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.database.sqlite.SQLiteDatabase
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.LinearGradient
import android.graphics.Paint
import android.graphics.Shader
import android.graphics.Typeface
import android.net.Uri
import android.view.View
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetPlugin
import es.antonborri.home_widget.HomeWidgetProvider
import java.text.NumberFormat
import java.time.LocalDate
import java.time.LocalDateTime
import java.time.format.DateTimeFormatter
import java.util.LinkedHashMap
import java.util.Locale
import kotlin.math.max

/** Widget interaktif: pilih tipe/kategori/dompet, ketik nominal, lalu simpan. */
open class SaldoWidgetProvider : HomeWidgetProvider() {
    /** Layout per varian widget. Subclass menimpa buat versi 3-tile / 1-tile. */
    protected open val layoutRes: Int get() = R.layout.saldo_widget

    /** Nominal diisi lewat dialog keyboard, bukan numpad widget. */
    protected open val amountPopup: Boolean get() = false

    /** Ringkasan 1 baris tidak punya kontrol form. */
    protected open val compact: Boolean get() = false

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences,
    ) {
        appWidgetIds.forEach { render(context, appWidgetManager, it, widgetData) }
    }

    override fun onReceive(context: Context, intent: Intent) {
        val action = intent.action.orEmpty()
        if (!action.startsWith(ACTION_PREFIX)) {
            super.onReceive(context, intent)
            return
        }
        val widgetId = intent.getIntExtra(
            AppWidgetManager.EXTRA_APPWIDGET_ID,
            AppWidgetManager.INVALID_APPWIDGET_ID,
        )
        if (widgetId == AppWidgetManager.INVALID_APPWIDGET_ID) return

        val prefs = HomeWidgetPlugin.getData(context)
        val editor = prefs.edit().putString(state(widgetId, "status"), "")
        when (action.removePrefix(ACTION_PREFIX)) {
            "type" -> {
                val type = intent.getStringExtra(EXTRA_VALUE) ?: "expense"
                val first = categories(prefs, type).firstOrNull()?.id.orEmpty()
                editor
                    .putString(state(widgetId, "type"), type)
                    .putString(state(widgetId, "category"), first)
                    .putInt(state(widgetId, "page"), 0)
            }
            "category" -> editor.putString(
                state(widgetId, "category"),
                intent.getStringExtra(EXTRA_VALUE).orEmpty(),
            )
            "next" -> {
                val type = prefs.getString(state(widgetId, "type"), "expense")!!
                val pages = max(1, (categories(prefs, type).size + PAGE_SIZE - 1) / PAGE_SIZE)
                val page = (prefs.getInt(state(widgetId, "page"), 0) + 1) % pages
                editor.putInt(state(widgetId, "page"), page)
            }
            "wallet" -> {
                val wallets = wallets(prefs)
                val current = prefs.getInt(state(widgetId, "wallet"), wallets.first().id.toInt())
                val index = wallets.indexOfFirst { it.id.toInt() == current }
                editor.putInt(
                    state(widgetId, "wallet"),
                    wallets[(index + 1).mod(wallets.size)].id.toInt(),
                )
            }
            "digit" -> {
                val value = intent.getStringExtra(EXTRA_VALUE).orEmpty()
                val current = prefs.getString(state(widgetId, "amount"), "").orEmpty()
                val next = if (current.isEmpty() && value == "000") current else current + value
                if (next.length <= 12) editor.putString(state(widgetId, "amount"), next)
            }
            "back" -> {
                val current = prefs.getString(state(widgetId, "amount"), "").orEmpty()
                editor.putString(state(widgetId, "amount"), current.dropLast(1))
            }
            "clear" -> editor.putString(state(widgetId, "amount"), "")
            "save" -> {
                editor.apply()
                save(context, widgetId, prefs)
                val manager = AppWidgetManager.getInstance(context)
                manager.getAppWidgetIds(ComponentName(context, javaClass)).forEach {
                    render(context, manager, it, prefs)
                }
                return
            }
        }
        editor.apply()
        render(context, AppWidgetManager.getInstance(context), widgetId, prefs)
    }

    private fun save(context: Context, widgetId: Int, prefs: SharedPreferences) {
        fun status(message: String) {
            prefs.edit().putString(state(widgetId, "status"), message).apply()
        }
        val appPrefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
        if (appPrefs.contains("flutter.pinHash") ||
            !prefs.getBoolean("widget_quick_add_enabled", true)
        ) {
            status("PIN aktif • simpan lewat app")
            return
        }
        val amount = prefs.getString(state(widgetId, "amount"), "").orEmpty().toLongOrNull() ?: 0
        if (amount <= 0) {
            status("Isi nominal dulu")
            return
        }
        val file = context.getDatabasePath("duit_ges.db")
        if (!file.exists()) {
            status("Buka aplikasi sekali dulu")
            return
        }

        val type = prefs.getString(state(widgetId, "type"), "expense")!!
        val options = categories(prefs, type)
        val selected = prefs.getString(state(widgetId, "category"), null)
        val category = options.firstOrNull { it.id == selected } ?: options.first()
        val walletOptions = wallets(prefs)
        val requestedWallet = prefs.getInt(
            state(widgetId, "wallet"),
            walletOptions.first().id.toInt(),
        )

        var db: SQLiteDatabase? = null
        try {
            db = SQLiteDatabase.openDatabase(file.path, null, SQLiteDatabase.OPEN_READWRITE)
            val walletId = validWallet(db, requestedWallet)
            val values = ContentValues().apply {
                put("amount", amount)
                put("category_id", category.id)
                put("note", "")
                put("date", LocalDateTime.now().format(DateTimeFormatter.ISO_LOCAL_DATE_TIME))
                put("type", type)
                put("wallet_id", walletId)
                putNull("receipt_path")
            }
            db.insertOrThrow("transactions", null, values)
            prefs.edit()
                .putString(state(widgetId, "amount"), "")
                .putString(state(widgetId, "status"), "Tersimpan ✓")
                .apply()
            refreshSummary(db, prefs)
        } catch (_: Exception) {
            status("Gagal menyimpan")
        } finally {
            db?.close()
        }
    }

    private fun validWallet(db: SQLiteDatabase, requested: Int): Int {
        db.rawQuery("SELECT id FROM wallets WHERE id = ? LIMIT 1", arrayOf(requested.toString())).use {
            if (it.moveToFirst()) return it.getInt(0)
        }
        db.rawQuery("SELECT id FROM wallets ORDER BY id LIMIT 1", null).use {
            if (it.moveToFirst()) return it.getInt(0)
        }
        return 1
    }

    private fun refreshSummary(db: SQLiteDatabase, prefs: SharedPreferences) {
        val startDay = prefs.getInt("widget_month_start_day", 1).coerceIn(1, 28)
        val today = LocalDate.now()
        val period = if (today.dayOfMonth >= startDay) {
            today.withDayOfMonth(startDay)
        } else {
            today.minusMonths(1).withDayOfMonth(startDay)
        }
        val end = period.plusMonths(1)
        val args = arrayOf(
            "income",
            period.toString(),
            end.toString(),
            "income",
            "transfer_keluar",
            "transfer_masuk",
            period.toString(),
            end.toString(),
            "expense",
            "transfer_keluar",
            "transfer_masuk",
        )
        db.rawQuery(
            "SELECT " +
                "COALESCE((SELECT SUM(initial_balance) FROM wallets), 0) + " +
                "COALESCE(SUM(CASE WHEN type = ? THEN amount ELSE -amount END), 0), " +
                "COALESCE(SUM(CASE WHEN date >= ? AND date < ? AND type = ? " +
                "AND category_id NOT IN (?, ?) THEN amount ELSE 0 END), 0), " +
                "COALESCE(SUM(CASE WHEN date >= ? AND date < ? AND type = ? " +
                "AND category_id NOT IN (?, ?) THEN amount ELSE 0 END), 0) " +
                "FROM transactions",
            args,
        ).use { cursor ->
            if (!cursor.moveToFirst()) return
            val hide = prefs.getBoolean("widget_hide_balance", false)
            fun money(value: Long) = if (hide) "Rp ••••" else rupiah(value)
            val month = period.format(DateTimeFormatter.ofPattern("MMMM yyyy", ID_LOCALE))
                .replaceFirstChar { it.uppercase(ID_LOCALE) }
            prefs.edit()
                .putString("widget_saldo", money(cursor.getLong(0)))
                .putString("widget_masuk", money(cursor.getLong(1)))
                .putString("widget_keluar", money(cursor.getLong(2)))
                .putString("widget_bulan", month)
                .apply()
        }
    }

    private fun render(
        context: Context,
        manager: AppWidgetManager,
        widgetId: Int,
        prefs: SharedPreferences,
    ) {
        val accent = color(prefs.getString("widget_accent", "#FF2E5BFF"), Color.rgb(46, 91, 255))
        val foreground = color(prefs.getString("widget_foreground", "#FFFFFFFF"), Color.WHITE)
        val start = color(prefs.getString("widget_bg_start", "#FF1C2540"), Color.rgb(28, 37, 64))
        val end = color(prefs.getString("widget_bg_end", "#FF10162B"), Color.rgb(16, 22, 43))
        val type = prefs.getString(state(widgetId, "type"), "expense")!!
        val categoryOptions = categories(prefs, type)
        val pageCount = max(1, (categoryOptions.size + PAGE_SIZE - 1) / PAGE_SIZE)
        val page = prefs.getInt(state(widgetId, "page"), 0).mod(pageCount)
        val selected = prefs.getString(state(widgetId, "category"), null)
            ?: categoryOptions.first().id
        val walletOptions = wallets(prefs)
        val walletId = prefs.getInt(state(widgetId, "wallet"), walletOptions.first().id.toInt())
        val wallet = walletOptions.firstOrNull { it.id.toInt() == walletId } ?: walletOptions.first()
        val amount = prefs.getString(state(widgetId, "amount"), "").orEmpty()
        val launch = HomeWidgetLaunchIntent.getActivity(
            context,
            AppActivity::class.java,
            Uri.parse("duitges://home"),
        )
        val amountInput = PendingIntent.getActivity(
            context,
            widgetId,
            Intent(context, WidgetAmountActivity::class.java).putExtra(
                AppWidgetManager.EXTRA_APPWIDGET_ID,
                widgetId,
            ),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        val history = PendingIntent.getActivity(
            context,
            widgetId,
            Intent(context, WidgetHistoryActivity::class.java),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        val views = RemoteViews(context.packageName, layoutRes).apply {
            setImageViewBitmap(
                R.id.widget_background,
                gradientBitmap(context, manager, widgetId, start, end),
            )
            if (compact) {
                setTextViewText(R.id.widget_bulan_big, prefs.getString("widget_bulan", "Duit Ges"))
                setTextViewText(R.id.widget_saldo_big, prefs.getString("widget_saldo", "Rp 0"))
                setTextViewText(R.id.widget_masuk, prefs.getString("widget_masuk", "Rp 0"))
                setTextViewText(R.id.widget_keluar, prefs.getString("widget_keluar", "Rp 0"))
                COMPACT_FOREGROUND_IDS.forEach { setTextColor(it, foreground) }
                setTextColor(R.id.widget_masuk, INCOME_COLOR)
                setTextColor(R.id.widget_keluar, EXPENSE_COLOR)
                setInt(R.id.widget_add, "setColorFilter", accent)
                setTextColor(R.id.widget_history, accent)
                setOnClickPendingIntent(R.id.widget_root, launch)
                setOnClickPendingIntent(R.id.widget_history, history)
                setOnClickPendingIntent(R.id.widget_add, launch)
                return@apply
            }

            val saveSize = if (layoutRes == R.layout.saldo_widget) 160 to 320 else 640 to 96
            setImageViewBitmap(
                R.id.widget_save_background,
                roundedBitmap(accent, saveSize.first, saveSize.second),
            )
            setTextViewText(R.id.widget_bulan, prefs.getString("widget_bulan", "Duit Ges"))
            setTextViewText(R.id.widget_saldo, prefs.getString("widget_saldo", "Rp 0"))
            if (amountPopup) setOnClickPendingIntent(R.id.widget_nominal, amountInput)
            setTextViewText(R.id.widget_status, prefs.getString(state(widgetId, "status"), ""))
            setTextViewText(R.id.widget_amount, if (amount.isEmpty()) "0" else number(amount.toLong()))
            setTextViewText(R.id.widget_wallet_label, wallet.name)
            setImageViewBitmap(
                R.id.widget_wallet_icon,
                categoryBitmap(context, wallet, false, accent),
            )
            setTextViewText(R.id.widget_category_page, "${page + 1}/$pageCount")

            FOREGROUND_IDS.forEach { setTextColor(it, foreground) }
            if (!amountPopup) KEYPAD_FOREGROUND_IDS.forEach { setTextColor(it, foreground) }
            setTextColor(R.id.widget_save, contrastingText(accent))
            setTextColor(R.id.widget_status, accent)
            setTextColor(R.id.widget_type_expense, if (type == "expense") accent else foreground)
            setTextColor(R.id.widget_type_income, if (type == "income") accent else foreground)
            setInt(
                R.id.widget_type_expense,
                "setBackgroundResource",
                if (type == "expense") R.drawable.widget_tab_selected else android.R.color.transparent,
            )
            setInt(
                R.id.widget_type_income,
                "setBackgroundResource",
                if (type == "income") R.drawable.widget_tab_selected else android.R.color.transparent,
            )

            CATEGORY_IDS.forEachIndexed { slot, viewId ->
                val index = page * PAGE_SIZE + slot
                val item = categoryOptions.getOrNull(index)
                setViewVisibility(viewId, if (item == null) View.INVISIBLE else View.VISIBLE)
                if (item != null) {
                    setImageViewBitmap(
                        CATEGORY_ICON_IDS[slot],
                        categoryBitmap(context, item, item.id == selected, accent),
                    )
                    setTextViewText(CATEGORY_LABEL_IDS[slot], item.name)
                    setTextColor(
                        CATEGORY_LABEL_IDS[slot],
                        if (item.id == selected) accent else foreground,
                    )
                    setOnClickPendingIntent(
                        viewId,
                        broadcast(context, widgetId, "category", item.id),
                    )
                }
            }
            setViewVisibility(
                R.id.widget_category_next,
                if (categoryOptions.size > PAGE_SIZE) View.VISIBLE else View.INVISIBLE,
            )
            setImageViewBitmap(
                R.id.widget_category_next_icon,
                categoryBitmap(
                    context,
                    Option("next", "Lainnya", ICON_ARROW, accent),
                    false,
                    accent,
                ),
            )
            setTextColor(R.id.widget_category_next_label, accent)

            setOnClickPendingIntent(R.id.widget_root, launch)
            setOnClickPendingIntent(
                R.id.widget_type_expense,
                broadcast(context, widgetId, "type", "expense"),
            )
            setOnClickPendingIntent(
                R.id.widget_type_income,
                broadcast(context, widgetId, "type", "income"),
            )
            setOnClickPendingIntent(
                R.id.widget_category_next,
                broadcast(context, widgetId, "next"),
            )
            setOnClickPendingIntent(R.id.widget_wallet, broadcast(context, widgetId, "wallet"))
            if (!amountPopup) {
                DIGIT_IDS.forEach { (viewId, digit) ->
                    setOnClickPendingIntent(viewId, broadcast(context, widgetId, "digit", digit))
                }
                setOnClickPendingIntent(R.id.widget_key_back, broadcast(context, widgetId, "back"))
                setOnClickPendingIntent(R.id.widget_key_clear, broadcast(context, widgetId, "clear"))
            }
            setOnClickPendingIntent(R.id.widget_save, broadcast(context, widgetId, "save"))
        }
        manager.updateAppWidget(widgetId, views)
    }

    private fun broadcast(
        context: Context,
        widgetId: Int,
        action: String,
        value: String = "",
    ): PendingIntent {
        val intent = Intent(context, javaClass).apply {
            this.action = ACTION_PREFIX + action
            putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, widgetId)
            putExtra(EXTRA_VALUE, value)
        }
        return PendingIntent.getBroadcast(
            context,
            "$widgetId:$action:$value".hashCode(),
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
    }

    private fun categories(prefs: SharedPreferences, type: String): List<Option> {
        val key = if (type == "income") "widget_income_categories" else "widget_expense_categories"
        return parseOptions(prefs.getString(key, null)).ifEmpty {
            if (type == "income") {
                listOf(
                    Option("gaji", "Gaji", 0xe482, Color.rgb(38, 166, 154)),
                    Option("freelance", "Freelance", 0xe367, Color.rgb(92, 107, 192)),
                    Option("bonus", "Bonus", 0xe13e, Color.rgb(102, 187, 106)),
                    Option("lainnya_masuk", "Lainnya", 0xe402, Color.rgb(120, 144, 156)),
                )
            } else {
                listOf(
                    Option("makanan", "Makanan", 0xe532, Color.rgb(255, 112, 67)),
                    Option("transportasi", "Transport", 0xe1d5, Color.rgb(66, 165, 245)),
                    Option("tagihan", "Tagihan", 0xe50d, Color.rgb(255, 167, 38)),
                    Option("lainnya_keluar", "Lainnya", 0xe402, Color.rgb(120, 144, 156)),
                )
            }
        }
    }

    private fun wallets(prefs: SharedPreferences): List<Option> =
        parseOptions(prefs.getString("widget_wallets", null))
            .ifEmpty {
                listOf(Option("1", "Tunai", 0xe482, Color.rgb(38, 166, 154)))
            }

    private fun parseOptions(raw: String?): List<Option> {
        if (raw.isNullOrBlank()) return emptyList()
        return try {
            val array = org.json.JSONArray(raw)
            List(array.length()) { index ->
                val item = array.getJSONObject(index)
                Option(
                    item.get("id").toString(),
                    item.getString("name"),
                    item.optInt("icon", ICON_CATEGORY),
                    item.optLong("color", 0xFF78909C).toInt(),
                    item.optString("emoji").takeIf { it.isNotBlank() },
                )
            }
        } catch (_: Exception) {
            emptyList()
        }
    }

    private fun gradientBitmap(
        context: Context,
        manager: AppWidgetManager,
        widgetId: Int,
        start: Int,
        end: Int,
    ): Bitmap {
        val density = context.resources.displayMetrics.density
        val options = manager.getAppWidgetOptions(widgetId)
        val fallbackHeight = when (layoutRes) {
            R.layout.saldo_widget_compact -> 48
            R.layout.saldo_widget_medium -> 180
            else -> 430
        }
        val width = (options.getInt(AppWidgetManager.OPTION_APPWIDGET_MAX_WIDTH)
            .takeIf { it > 0 } ?: 320) * density
        val height = (options.getInt(AppWidgetManager.OPTION_APPWIDGET_MAX_HEIGHT)
            .takeIf { it > 0 } ?: fallbackHeight) * density
        val bitmapWidth = width.toInt()
        val bitmapHeight = height.toInt()
        val key = "$bitmapWidth:$bitmapHeight:$start:$end"
        if (key == cachedBackgroundKey) cachedBackground?.let { return it }
        return Bitmap.createBitmap(bitmapWidth, bitmapHeight, Bitmap.Config.ARGB_8888).also { bitmap ->
            val paint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
                shader = LinearGradient(0f, 0f, width, height, start, end, Shader.TileMode.CLAMP)
            }
            Canvas(bitmap).drawRoundRect(
                0f,
                0f,
                width,
                height,
                24f * density,
                24f * density,
                paint,
            )
            cachedBackgroundKey = key
            cachedBackground = bitmap
        }
    }

    private fun roundedBitmap(color: Int, width: Int, height: Int): Bitmap {
        val key = "$color:$width:$height"
        if (key == cachedSaveKey) cachedSave?.let { return it }
        return Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888).also { bitmap ->
            Canvas(bitmap).drawRoundRect(
                0f,
                0f,
                width.toFloat(),
                height.toFloat(),
                20f.coerceAtMost(width / 4f),
                20f.coerceAtMost(width / 4f),
                Paint(Paint.ANTI_ALIAS_FLAG).apply { this.color = color },
            )
            cachedSaveKey = key
            cachedSave = bitmap
        }
    }

    private fun categoryBitmap(
        context: Context,
        item: Option,
        selected: Boolean,
        accent: Int,
    ): Bitmap {
        val key = "${item.icon}:${item.emoji}:${item.color}:$selected:$accent"
        iconCache[key]?.let { return it }
        val size = 96
        val center = size / 2f
        val bitmap = Bitmap.createBitmap(size, size, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(bitmap)
        if (selected) {
            canvas.drawCircle(
                center,
                center,
                47f,
                Paint(Paint.ANTI_ALIAS_FLAG).apply { color = accent },
            )
        }
        val radius = if (selected) 40f else 44f
        val circle = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            shader = LinearGradient(
                12f,
                12f,
                84f,
                84f,
                adjustBrightness(item.color, 0.08f),
                adjustBrightness(item.color, -0.12f),
                Shader.TileMode.CLAMP,
            )
        }
        canvas.drawCircle(center, center, radius, circle)

        val iconPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = Color.WHITE
            textAlign = Paint.Align.CENTER
            textSize = if (item.emoji == null) 43f else 48f
            typeface = if (item.emoji == null) materialIcons(context) else Typeface.DEFAULT
        }
        val glyph = item.emoji ?: String(Character.toChars(item.icon))
        val baseline = center - (iconPaint.ascent() + iconPaint.descent()) / 2
        canvas.drawText(glyph, center, baseline, iconPaint)
        iconCache[key] = bitmap
        return bitmap
    }

    private fun materialIcons(context: Context): Typeface =
        materialTypeface ?: Typeface.createFromAsset(
            context.assets,
            "flutter_assets/fonts/MaterialIcons-Regular.otf",
        ).also { materialTypeface = it }

    private fun adjustBrightness(color: Int, amount: Float): Int {
        val hsv = FloatArray(3)
        Color.colorToHSV(color, hsv)
        hsv[2] = (hsv[2] + amount).coerceIn(0f, 1f)
        return Color.HSVToColor(Color.alpha(color), hsv)
    }

    private fun color(value: String?, fallback: Int): Int = try {
        Color.parseColor(value)
    } catch (_: IllegalArgumentException) {
        fallback
    }

    private fun contrastingText(background: Int): Int {
        val brightness =
            (Color.red(background) * 299 + Color.green(background) * 587 +
                Color.blue(background) * 114) / 1000
        return if (brightness >= 160) Color.BLACK else Color.WHITE
    }

    private fun rupiah(value: Long) = "Rp ${number(value)}"
    private fun number(value: Long) = NumberFormat.getIntegerInstance(ID_LOCALE).format(value)
    private fun state(widgetId: Int, name: String) = "widget_state_${widgetId}_$name"

    private data class Option(
        val id: String,
        val name: String,
        val icon: Int = ICON_CATEGORY,
        val color: Int = 0xFF78909C.toInt(),
        val emoji: String? = null,
    )

    companion object {
        private const val ACTION_PREFIX = "com.noctilune.duitges.WIDGET_"
        private const val EXTRA_VALUE = "value"
        private const val PAGE_SIZE = 4
        private val INCOME_COLOR = Color.rgb(67, 217, 122)
        private val EXPENSE_COLOR = Color.rgb(229, 72, 77)
        private const val ICON_CATEGORY = 0xe148
        private const val ICON_ARROW = 0xe09b
        private val ID_LOCALE = Locale("id", "ID")
        private val CATEGORY_IDS = intArrayOf(
            R.id.widget_category_0,
            R.id.widget_category_1,
            R.id.widget_category_2,
            R.id.widget_category_3,
        )
        private val CATEGORY_ICON_IDS = intArrayOf(
            R.id.widget_category_icon_0,
            R.id.widget_category_icon_1,
            R.id.widget_category_icon_2,
            R.id.widget_category_icon_3,
        )
        private val CATEGORY_LABEL_IDS = intArrayOf(
            R.id.widget_category_label_0,
            R.id.widget_category_label_1,
            R.id.widget_category_label_2,
            R.id.widget_category_label_3,
        )
        private val DIGIT_IDS = mapOf(
            R.id.widget_key_0 to "0",
            R.id.widget_key_000 to "000",
            R.id.widget_key_1 to "1",
            R.id.widget_key_2 to "2",
            R.id.widget_key_3 to "3",
            R.id.widget_key_4 to "4",
            R.id.widget_key_5 to "5",
            R.id.widget_key_6 to "6",
            R.id.widget_key_7 to "7",
            R.id.widget_key_8 to "8",
            R.id.widget_key_9 to "9",
        )
        private val FOREGROUND_IDS = intArrayOf(
            R.id.widget_bulan,
            R.id.widget_saldo,
            R.id.widget_wallet_label,
            R.id.widget_wallet_arrow,
            R.id.widget_amount,
            R.id.widget_amount_label,
            R.id.widget_category_title,
            R.id.widget_category_page,
            R.id.widget_type_expense,
            R.id.widget_type_income,
        )
        private val KEYPAD_FOREGROUND_IDS = intArrayOf(
            R.id.widget_key_0,
            R.id.widget_key_000,
            R.id.widget_key_1,
            R.id.widget_key_2,
            R.id.widget_key_3,
            R.id.widget_key_4,
            R.id.widget_key_5,
            R.id.widget_key_6,
            R.id.widget_key_7,
            R.id.widget_key_8,
            R.id.widget_key_9,
            R.id.widget_key_back,
            R.id.widget_key_clear,
        )
        private val COMPACT_FOREGROUND_IDS = intArrayOf(
            R.id.widget_bulan_big,
            R.id.widget_saldo_big,
            R.id.widget_masuk_label,
            R.id.widget_keluar_label,
        )
        private var cachedBackgroundKey = ""
        private var cachedBackground: Bitmap? = null
        private var cachedSaveKey = ""
        private var cachedSave: Bitmap? = null
        private var materialTypeface: Typeface? = null
        private val iconCache = object : LinkedHashMap<String, Bitmap>(96, 0.75f, true) {
            override fun removeEldestEntry(eldest: MutableMap.MutableEntry<String, Bitmap>?): Boolean =
                size > 96
        }
    }
}

/** Varian 3-tile: form penuh tanpa numpad, cuma tombol simpan. */
class SaldoWidgetMediumProvider : SaldoWidgetProvider() {
    override val layoutRes: Int get() = R.layout.saldo_widget_medium
    override val amountPopup: Boolean get() = true
}

/** Varian 1-tile: ringkasan saldo + masuk/keluar dan tombol tambah. */
class SaldoWidgetCompactProvider : SaldoWidgetProvider() {
    override val layoutRes: Int get() = R.layout.saldo_widget_compact
    override val compact: Boolean get() = true
}
