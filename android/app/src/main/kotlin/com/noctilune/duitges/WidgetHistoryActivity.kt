package com.noctilune.duitges

import android.app.Activity
import android.app.Dialog
import android.database.sqlite.SQLiteDatabase
import android.graphics.Color
import android.graphics.Typeface
import android.graphics.drawable.GradientDrawable
import android.os.Bundle
import android.view.View
import android.view.ViewGroup
import android.view.Window
import android.widget.BaseAdapter
import android.widget.Button
import android.widget.LinearLayout
import android.widget.ListView
import android.widget.TextView
import es.antonborri.home_widget.HomeWidgetPlugin
import org.json.JSONArray
import java.text.NumberFormat
import java.time.LocalDate
import java.time.LocalDateTime
import java.time.format.DateTimeFormatter
import java.util.Locale

class WidgetHistoryActivity : Activity() {
    private val density by lazy { resources.displayMetrics.density }
    private fun dp(value: Int) = (value * density).toInt()
    private fun muted(color: Int) = Color.argb(180, Color.red(color), Color.green(color), Color.blue(color))

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        val prefs = HomeWidgetPlugin.getData(this)
        val foreground = color(prefs.getString("widget_foreground", null), Color.WHITE)
        val start = color(prefs.getString("widget_bg_start", null), Color.rgb(28, 37, 64))
        val end = color(prefs.getString("widget_bg_end", null), Color.rgb(16, 22, 43))
        val day = prefs.getInt("widget_month_start_day", 1).coerceIn(1, 28)
        var offset = 0

        val periodText = label("", 13f, foreground, true).apply { gravity = android.view.Gravity.CENTER }
        val adapter = TransactionAdapter(emptyList(), foreground, prefs)
        val next = Button(this).apply { text = "›" }
        fun refresh() {
            periodText.text = periodLabel(day, offset)
            adapter.replace(latestTransactions(day, offset))
            next.isEnabled = offset < 0
            next.alpha = if (next.isEnabled) 1f else .35f
        }

        val dialog = Dialog(this).apply {
            requestWindowFeature(Window.FEATURE_NO_TITLE)
            setContentView(LinearLayout(this@WidgetHistoryActivity).apply {
                orientation = LinearLayout.VERTICAL
                setPadding(dp(20), dp(18), dp(20), dp(16))
                background = GradientDrawable(
                    GradientDrawable.Orientation.TL_BR,
                    intArrayOf(start, end),
                ).apply { cornerRadius = dp(24).toFloat() }
                addView(label("Riwayat Transaksi", 18f, foreground, true))
                addView(LinearLayout(context).apply {
                    orientation = LinearLayout.HORIZONTAL
                    gravity = android.view.Gravity.CENTER_VERTICAL
                    addView(Button(context).apply {
                        text = "‹"
                        setOnClickListener { offset--; refresh() }
                    }, LinearLayout.LayoutParams(dp(48), dp(44)))
                    addView(periodText, LinearLayout.LayoutParams(0, dp(44), 1f))
                    addView(next.apply {
                        setOnClickListener { if (offset < 0) { offset++; refresh() } }
                    }, LinearLayout.LayoutParams(dp(48), dp(44)))
                })
                addView(ListView(context).apply {
                    this.adapter = adapter
                    divider = null
                    clipToPadding = false
                    setPadding(0, dp(4), 0, dp(4))
                }, LinearLayout.LayoutParams(-1, 0, 1f))
                addView(Button(context).apply {
                    text = "Tutup"
                    setTextColor(foreground)
                    background = GradientDrawable().apply {
                        cornerRadius = dp(18).toFloat()
                        setColor(Color.argb(28, 255, 255, 255))
                    }
                    setOnClickListener { this@WidgetHistoryActivity.finish() }
                }, LinearLayout.LayoutParams(-1, dp(44)).apply { topMargin = dp(12) })
            })
            setOnCancelListener { this@WidgetHistoryActivity.finish() }
        }
        refresh()
        dialog.show()
        dialog.window?.apply {
            setBackgroundDrawableResource(android.R.color.transparent)
            setLayout(
                (resources.displayMetrics.widthPixels * 0.88).toInt(),
                (resources.displayMetrics.heightPixels * 0.78).toInt(),
            )
        }
    }

    private inner class TransactionAdapter(
        private var rows: List<TransactionRow>,
        private val foreground: Int,
        private val prefs: android.content.SharedPreferences,
    ) : BaseAdapter() {
        fun replace(value: List<TransactionRow>) { rows = value; notifyDataSetChanged() }
        override fun getCount() = rows.size
        override fun getItem(position: Int) = rows[position]
        override fun getItemId(position: Int) = position.toLong()
        override fun getView(position: Int, convertView: View?, parent: ViewGroup): View {
            val row = rows[position]
            val income = row.type == "income"
            val status = if (income) Color.rgb(67, 217, 122) else Color.rgb(229, 72, 77)
            val category = optionName(
                prefs.getString(if (income) "widget_income_categories" else "widget_expense_categories", null),
                row.category,
            )
            val date = runCatching {
                LocalDateTime.parse(row.date).format(DateTimeFormatter.ofPattern("d MMM • HH:mm", Locale("id", "ID")))
            }.getOrDefault(row.date)
            return LinearLayout(this@WidgetHistoryActivity).apply {
                orientation = LinearLayout.HORIZONTAL
                gravity = android.view.Gravity.CENTER_VERTICAL
                setPadding(dp(12), dp(10), dp(12), dp(10))
                background = GradientDrawable().apply {
                    cornerRadius = dp(14).toFloat()
                    setColor(Color.argb(24, 255, 255, 255))
                }
                addView(label(if (income) "+" else "−", 20f, status, true), LinearLayout.LayoutParams(dp(24), -2))
                addView(LinearLayout(context).apply {
                    orientation = LinearLayout.VERTICAL
                    addView(label(row.note.takeIf { it.isNotBlank() } ?: category, 13f, this@TransactionAdapter.foreground, true))
                    addView(label("$category • ${row.wallet} • $date", 10f, muted(this@TransactionAdapter.foreground)))
                }, LinearLayout.LayoutParams(0, -2, 1f))
                addView(label(
                    "${if (income) "+" else "−"}Rp ${NumberFormat.getIntegerInstance(Locale("id", "ID")).format(row.amount)}",
                    12f, status, true,
                ))
                layoutParams = ViewGroup.LayoutParams(-1, -2)
            }
        }
    }

    private fun label(text: String, size: Float, color: Int, bold: Boolean = false) = TextView(this).apply {
        this.text = text
        textSize = size
        setTextColor(color)
        if (bold) setTypeface(typeface, Typeface.BOLD)
    }

    private fun periodStart(monthStartDay: Int, offset: Int): LocalDateTime {
        val today = LocalDate.now()
        val current = (if (today.dayOfMonth >= monthStartDay) today else today.minusMonths(1))
            .withDayOfMonth(monthStartDay)
        return current.plusMonths(offset.toLong()).atStartOfDay()
    }

    private fun periodLabel(monthStartDay: Int, offset: Int): String {
        val start = periodStart(monthStartDay, offset)
        val end = start.plusMonths(1).minusDays(1)
        val format = DateTimeFormatter.ofPattern("d MMM yyyy", Locale("id", "ID"))
        return "${start.format(format)} – ${end.format(format)}"
    }

    private fun latestTransactions(monthStartDay: Int, offset: Int): List<TransactionRow> {
        val file = getDatabasePath("duit_ges.db")
        if (!file.exists()) return emptyList()
        val start = periodStart(monthStartDay, offset)
        val end = start.plusMonths(1)
        return SQLiteDatabase.openDatabase(file.path, null, SQLiteDatabase.OPEN_READONLY).use { db ->
            db.rawQuery(
                "SELECT t.amount, t.category_id, t.note, t.date, t.type, " +
                    "COALESCE(w.name, 'Dompet') FROM transactions t " +
                    "LEFT JOIN wallets w ON w.id = t.wallet_id " +
                    "WHERE t.date >= ? AND t.date < ? ORDER BY t.date DESC, t.id DESC",
                arrayOf(start.toString(), end.toString()),
            ).use { cursor ->
                buildList {
                    while (cursor.moveToNext()) add(TransactionRow(
                        cursor.getLong(0), cursor.getString(1), cursor.getString(2),
                        cursor.getString(3), cursor.getString(4), cursor.getString(5),
                    ))
                }
            }
        }
    }

    private fun optionName(raw: String?, id: String): String = runCatching {
        val items = JSONArray(raw ?: "[]")
        (0 until items.length()).firstNotNullOfOrNull { index ->
            items.getJSONObject(index).takeIf { it.getString("id") == id }?.getString("name")
        } ?: id
    }.getOrDefault(id)

    private fun color(value: String?, fallback: Int) = runCatching { Color.parseColor(value) }.getOrDefault(fallback)

    private data class TransactionRow(
        val amount: Long, val category: String, val note: String,
        val date: String, val type: String, val wallet: String,
    )
}
