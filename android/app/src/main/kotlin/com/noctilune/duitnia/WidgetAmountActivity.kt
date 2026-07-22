package com.noctilune.duitnia

import android.app.Activity
import android.app.Dialog
import android.appwidget.AppWidgetManager
import android.content.Intent
import android.graphics.Color
import android.graphics.drawable.GradientDrawable
import android.os.Bundle
import android.text.Editable
import android.text.InputType
import android.text.TextWatcher
import android.view.Gravity
import android.view.ViewGroup
import android.view.Window
import android.view.WindowManager
import android.widget.Button
import android.widget.EditText
import android.widget.LinearLayout
import android.widget.TextView
import es.antonborri.home_widget.HomeWidgetPlugin

internal fun formatWidgetAmount(value: String): String = value
    .filter { it.isDigit() }
    .take(12)
    .reversed()
    .chunked(3)
    .joinToString(".")
    .reversed()

class WidgetAmountActivity : Activity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        val widgetId = intent.getIntExtra(
            AppWidgetManager.EXTRA_APPWIDGET_ID,
            AppWidgetManager.INVALID_APPWIDGET_ID,
        )
        if (widgetId == AppWidgetManager.INVALID_APPWIDGET_ID) return finish()

        val prefs = HomeWidgetPlugin.getData(this)
        val accent = prefs.color("widget_accent", Color.rgb(46, 91, 255))
        val foreground = prefs.color("widget_foreground", Color.WHITE)
        val backgroundStart = prefs.color("widget_bg_start", Color.rgb(28, 37, 64))
        val backgroundEnd = prefs.color("widget_bg_end", Color.rgb(16, 22, 43))
        val density = resources.displayMetrics.density
        fun dp(value: Int) = (value * density).toInt()
        fun alpha(color: Int, value: Int) =
            Color.argb(value, Color.red(color), Color.green(color), Color.blue(color))
        fun textOn(color: Int) = if (
            Color.red(color) * 299 + Color.green(color) * 587 + Color.blue(color) * 114 > 186000
        ) Color.BLACK else Color.WHITE

        val input = EditText(this).apply {
            inputType = InputType.TYPE_CLASS_NUMBER
            setText(formatWidgetAmount(prefs.getString("widget_state_${widgetId}_amount", "").orEmpty()))
            setTextColor(foreground)
            setHintTextColor(alpha(foreground, 140))
            hint = "0"
            textSize = 28f
            gravity = Gravity.CENTER_VERTICAL
            setSelectAllOnFocus(true)
            setPadding(dp(16), 0, dp(16), 0)
            background = GradientDrawable().apply {
                cornerRadius = dp(16).toFloat()
                setColor(Color.argb(38, 0, 0, 0))
                setStroke(dp(1), alpha(accent, 150))
            }
            addTextChangedListener(object : TextWatcher {
                private var formatting = false

                override fun beforeTextChanged(s: CharSequence?, start: Int, count: Int, after: Int) = Unit
                override fun onTextChanged(s: CharSequence?, start: Int, before: Int, count: Int) = Unit
                override fun afterTextChanged(editable: Editable?) {
                    if (formatting) return
                    val formatted = formatWidgetAmount(editable.toString())
                    if (formatted == editable.toString()) return
                    formatting = true
                    setText(formatted)
                    setSelection(formatted.length)
                    formatting = false
                }
            })
        }

        val dialog = Dialog(this).apply {
            requestWindowFeature(Window.FEATURE_NO_TITLE)
            setContentView(
                LinearLayout(this@WidgetAmountActivity).apply {
                    orientation = LinearLayout.VERTICAL
                    setPadding(dp(20), dp(18), dp(20), dp(16))
                    background = GradientDrawable(
                        GradientDrawable.Orientation.TL_BR,
                        intArrayOf(backgroundStart, backgroundEnd),
                    ).apply { cornerRadius = dp(24).toFloat() }

                    addView(TextView(context).apply {
                        text = "Masukkan nominal"
                        textSize = 18f
                        setTextColor(foreground)
                        setTypeface(typeface, android.graphics.Typeface.BOLD)
                    })
                    addView(TextView(context).apply {
                        text = "Nilai akan langsung dipakai di widget"
                        textSize = 12f
                        setTextColor(alpha(foreground, 180))
                    }, LinearLayout.LayoutParams(-1, -2).apply { bottomMargin = dp(14) })
                    addView(input, LinearLayout.LayoutParams(-1, dp(58)))
                    addView(LinearLayout(context).apply {
                        gravity = Gravity.END
                        orientation = LinearLayout.HORIZONTAL
                        addView(Button(context).apply {
                            text = "Batal"
                            setTextColor(foreground)
                            background = GradientDrawable().apply {
                                cornerRadius = dp(18).toFloat()
                                setColor(alpha(foreground, 24))
                                setStroke(dp(1), alpha(foreground, 70))
                            }
                            setPadding(dp(18), 0, dp(18), 0)
                            setOnClickListener { this@WidgetAmountActivity.finish() }
                        }, LinearLayout.LayoutParams(-2, dp(44)))
                        addView(Button(context).apply {
                            text = "Pakai"
                            setTextColor(textOn(accent))
                            background = GradientDrawable().apply {
                                cornerRadius = dp(18).toFloat()
                                setColor(accent)
                            }
                            setPadding(dp(20), 0, dp(20), 0)
                            setOnClickListener {
                                prefs.edit()
                                    .putString(
                                        "widget_state_${widgetId}_amount",
                                        input.text.toString().filter { it.isDigit() }.take(12),
                                    )
                                    .apply()
                                sendBroadcast(
                                    Intent(this@WidgetAmountActivity, SaldoWidgetMediumProvider::class.java).apply {
                                        action = AppWidgetManager.ACTION_APPWIDGET_UPDATE
                                        putExtra(AppWidgetManager.EXTRA_APPWIDGET_IDS, intArrayOf(widgetId))
                                    },
                                )
                                this@WidgetAmountActivity.finish()
                            }
                        }, LinearLayout.LayoutParams(-2, dp(44)).apply { marginStart = dp(8) })
                    }, LinearLayout.LayoutParams(-1, -2).apply { topMargin = dp(12) })
                },
            )
            setOnCancelListener { this@WidgetAmountActivity.finish() }
        }
        dialog.setOnShowListener {
            input.requestFocus()
            dialog.window?.setSoftInputMode(WindowManager.LayoutParams.SOFT_INPUT_STATE_ALWAYS_VISIBLE)
        }
        dialog.show()
        dialog.window?.apply {
            setBackgroundDrawableResource(android.R.color.transparent)
            setLayout((resources.displayMetrics.widthPixels * 0.88).toInt(), ViewGroup.LayoutParams.WRAP_CONTENT)
        }
    }

    private fun android.content.SharedPreferences.color(key: String, fallback: Int): Int = try {
        Color.parseColor(getString(key, null))
    } catch (_: Exception) {
        fallback
    }
}
