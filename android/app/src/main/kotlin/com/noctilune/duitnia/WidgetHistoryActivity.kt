package com.noctilune.duitnia

import android.app.Activity
import android.app.Dialog
import android.database.sqlite.SQLiteDatabase
import android.graphics.Color
import android.graphics.Typeface
import android.graphics.drawable.GradientDrawable
import android.os.Bundle
import android.view.ViewGroup
import android.view.Window
import android.widget.Button
import android.widget.LinearLayout
import android.widget.TextView
import es.antonborri.home_widget.HomeWidgetPlugin
import org.json.JSONArray
import java.text.NumberFormat
import java.time.LocalDateTime
import java.time.format.DateTimeFormatter
import java.util.Locale

class WidgetHistoryActivity : Activity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        val prefs = HomeWidgetPlugin.getData(this)
        val foreground = color(prefs.getString("widget_foreground", null), Color.WHITE)
        val start = color(prefs.getString("widget_bg_start", null), Color.rgb(28, 37, 64))
        val end = color(prefs.getString("widget_bg_end", null), Color.rgb(16, 22, 43))
        val accent = color(prefs.getString("widget_accent", null), Color.rgb(46, 91, 255))
        val density = resources.displayMetrics.density
        fun dp(value: Int) = (value * density).toInt()
        fun muted(color: Int) = Color.argb(180, Color.red(color), Color.green(color), Color.blue(color))

        val transactions = latestTransactions()

        val dialog = Dialog(this).apply {
            requestWindowFeature(Window.FEATURE_NO_TITLE)
            setContentView(
                LinearLayout(this@WidgetHistoryActivity).apply {
                    orientation = LinearLayout.VERTICAL
                    setPadding(dp(20), dp(18), dp(20), dp(16))
                    background = GradientDrawable(
                        GradientDrawable.Orientation.TL_BR,
                        intArrayOf(start, end),
                    ).apply { cornerRadius = dp(24).toFloat() }
                    addView(label("Transaksi Terakhir", 18f, foreground, true))
                    if (transactions.isEmpty()) {
                        addView(label("Belum ada transaksi.", 13f, muted(foreground)))
                    } else {
                        transactions.forEach { row ->
                            val income = row.type == "income"
                            val statusColor = if (income) Color.rgb(67, 217, 122) else Color.rgb(229, 72, 77)
                            val category = optionName(
                                prefs.getString(
                                    if (income) "widget_income_categories" else "widget_expense_categories",
                                    null,
                                ),
                                row.category,
                            )
                            val date = runCatching {
                                LocalDateTime.parse(row.date).format(
                                    DateTimeFormatter.ofPattern("d MMM • HH:mm", Locale("id", "ID")),
                                )
                            }.getOrDefault(row.date)
                            addView(LinearLayout(context).apply {
                                orientation = LinearLayout.HORIZONTAL
                                setPadding(dp(12), dp(10), dp(12), dp(10))
                                background = GradientDrawable().apply {
                                    cornerRadius = dp(14).toFloat()
                                    setColor(Color.argb(24, 255, 255, 255))
                                }
                                addView(label(if (income) "+" else "−", 20f, statusColor, true),
                                    LinearLayout.LayoutParams(dp(24), -2))
                                addView(LinearLayout(context).apply {
                                    orientation = LinearLayout.VERTICAL
                                    addView(label(
                                        row.note.takeIf { it.isNotBlank() } ?: category,
                                        13f,
                                        foreground,
                                        true,
                                    ))
                                    addView(label("$category • ${row.wallet} • $date", 10f, muted(foreground)))
                                }, LinearLayout.LayoutParams(0, -2, 1f))
                                addView(label(
                                    "${if (income) "+" else "−"}Rp ${NumberFormat.getIntegerInstance(Locale("id", "ID")).format(row.amount)}",
                                    12f,
                                    statusColor,
                                    true,
                                ))
                            }, LinearLayout.LayoutParams(-1, -2).apply { topMargin = dp(8) })
                        }
                    }
                    addView(Button(context).apply {
                        text = "Tutup"
                        setTextColor(foreground)
                        background = GradientDrawable().apply {
                            cornerRadius = dp(18).toFloat()
                            setColor(Color.argb(28, 255, 255, 255))
                        }
                        setOnClickListener { this@WidgetHistoryActivity.finish() }
                    }, LinearLayout.LayoutParams(-1, dp(44)).apply { topMargin = dp(16) })
                },
            )
            setOnCancelListener { this@WidgetHistoryActivity.finish() }
        }
        dialog.show()
        dialog.window?.apply {
            setBackgroundDrawableResource(android.R.color.transparent)
            setLayout(
                (resources.displayMetrics.widthPixels * 0.88).toInt(),
                ViewGroup.LayoutParams.WRAP_CONTENT,
            )
        }
    }

    private fun label(text: String, size: Float, color: Int, bold: Boolean = false) =
        TextView(this).apply {
            this.text = text
            textSize = size
            setTextColor(color)
            if (bold) setTypeface(typeface, Typeface.BOLD)
        }

    private fun latestTransactions(): List<TransactionRow> {
        val file = getDatabasePath("duit_ges.db")
        if (!file.exists()) return emptyList()
        return SQLiteDatabase.openDatabase(file.path, null, SQLiteDatabase.OPEN_READONLY).use { db ->
            db.rawQuery(
                "SELECT t.amount, t.category_id, t.note, t.date, t.type, " +
                    "COALESCE(w.name, 'Dompet') FROM transactions t " +
                    "LEFT JOIN wallets w ON w.id = t.wallet_id " +
                    "ORDER BY t.date DESC, t.id DESC LIMIT 5",
                null,
            ).use { cursor ->
                buildList {
                    while (cursor.moveToNext()) {
                        add(TransactionRow(
                            cursor.getLong(0), cursor.getString(1), cursor.getString(2),
                            cursor.getString(3), cursor.getString(4), cursor.getString(5),
                        ))
                    }
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

    private fun color(value: String?, fallback: Int) = runCatching {
        Color.parseColor(value)
    }.getOrDefault(fallback)

    private data class TransactionRow(
        val amount: Long,
        val category: String,
        val note: String,
        val date: String,
        val type: String,
        val wallet: String,
    )
}
