package com.prompthub.multiprompt

import android.app.Activity
import android.content.Intent
import android.graphics.Typeface
import android.os.Bundle
import android.view.Gravity
import android.view.ViewGroup
import android.widget.Button
import android.widget.CheckBox
import android.widget.EditText
import android.widget.LinearLayout
import android.widget.ScrollView
import android.widget.TextView
import java.util.concurrent.Executors

class MainActivity : Activity() {

    private lateinit var prompt: EditText
    private lateinit var picksBox: LinearLayout
    private lateinit var resultsBox: LinearLayout
    private lateinit var prefs: Prefs
    private val boxes = LinkedHashMap<String, CheckBox>()
    private val pool = Executors.newFixedThreadPool(6)

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        prefs = Prefs(this)

        val root = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(24, 16, 24, 24)
        }
        root.addView(TextView(this).apply {
            text = "MultiPrompt"
            textSize = 24f
            setTypeface(typeface, Typeface.BOLD)
            gravity = Gravity.CENTER
            setPadding(0, 8, 0, 8)
        })
        root.addView(TextView(this).apply {
            text = "Satu prompt, dikirim serentak ke beberapa AI. Tanpa API key."
            textSize = 13f
            alpha = 0.7f
            gravity = Gravity.CENTER
            setPadding(0, 0, 0, 12)
        })

        prompt = EditText(this).apply {
            hint = "Tulis prompt di sini…"
            minLines = 3
            maxLines = 7
            gravity = Gravity.TOP or Gravity.START
            setTextSize(16f)
        }
        root.addView(prompt)

        val runBtn = Button(this).apply {
            text = "Kirim ke Semua"
            layoutParams = LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.WRAP_CONTENT)
            setOnClickListener { kirim() }
        }
        root.addView(runBtn, LinearLayout.LayoutParams(
            ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.WRAP_CONTENT
        ).apply { topMargin = 12 })

        root.addView(TextView(this).apply {
            text = "Pilih AI tujuan (yang \"login sendiri\" tekan Login dulu):"
            textSize = 14f
            setTypeface(typeface, Typeface.BOLD)
            setPadding(0, 16, 0, 4)
        })
        picksBox = LinearLayout(this).apply { orientation = LinearLayout.VERTICAL }
        for (p in Providers.ALL) {
            val row = LinearLayout(this).apply { orientation = LinearLayout.HORIZONTAL }
            val cb = CheckBox(this).apply {
                text = p.name
                isChecked = prefs.lastChoice(p.id)
                setPadding(0, 4, 4, 4)
            }
            boxes[p.id] = cb
            row.addView(cb, LinearLayout.LayoutParams(0, ViewGroup.LayoutParams.WRAP_CONTENT, 1f))
            if (p.web) {
                row.addView(Button(this).apply {
                    text = "Login"
                    isAllCaps = false
                    textSize = 13f
                    setOnClickListener {
                        startActivity(Intent(this@MainActivity, LoginWebViewActivity::class.java)
                            .putExtra("platform", p.id))
                    }
                }, LinearLayout.LayoutParams(
                    ViewGroup.LayoutParams.WRAP_CONTENT, ViewGroup.LayoutParams.WRAP_CONTENT
                ))
            }
            picksBox.addView(row)
        }
        root.addView(picksBox)

        resultsBox = LinearLayout(this).apply { orientation = LinearLayout.VERTICAL }
        root.addView(TextView(this).apply {
            text = "Hasil:"
            textSize = 14f
            setTypeface(typeface, Typeface.BOLD)
            setPadding(0, 16, 0, 4)
        })
        root.addView(resultsBox)

        setContentView(ScrollView(this).apply { addView(root) })
    }

    private fun kirim() {
        val promptText = prompt.text.toString().trim()
        if (promptText.isEmpty()) {
            prompt.error = "Isi prompt dulu"
            return
        }
        val chosen = boxes.filterValues { it.isChecked }.keys.toList()
        if (chosen.isEmpty()) return
        for ((id, cb) in boxes) prefs.saveChoice(id, cb.isChecked)

        resultsBox.removeAllViews()
        val cards = HashMap<String, Array<TextView>>()
        for (id in chosen) {
            val name = Providers.ALL.first { it.id == id }.name
            val header = TextView(this).apply {
                text = "$name — mengirim…"
                textSize = 14f
                setTypeface(typeface, Typeface.BOLD)
                setPadding(0, 16, 0, 4)
            }
            val body = TextView(this).apply {
                text = ""
                textSize = 15f
                setPadding(0, 0, 0, 8)
                setTextIsSelectable(true)
            }
            resultsBox.addView(header)
            resultsBox.addView(body)
            cards[id] = arrayOf(header, body)
        }

        for (id in chosen) {
            val (header, body) = cards[id]!!
            val name = Providers.ALL.first { it.id == id }.name
            fun finish(ok: Boolean, text: String) {
                runOnUiThread {
                    header.text = if (ok) "$name — selesai" else "$name — GAGAL"
                    body.text = text
                }
            }
            val webCfg = WebChat.byId(id)
            if (webCfg != null) {
                // penyedia berbasis situs: otomasi WebView di thread utama
                WebChat.run(this, webCfg, promptText, object : WebChat.Callback {
                    override fun onDone(text: String) = finish(true, text)
                    override fun onFail(msg: String) = finish(false, msg)
                })
            } else {
                pool.execute {
                    try {
                        finish(true, Providers.ask(id, promptText))
                    } catch (e: Exception) {
                        finish(false, e.message ?: e.toString())
                    }
                }
            }
        }
    }
}
