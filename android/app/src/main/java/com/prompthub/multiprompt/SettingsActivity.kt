package com.prompthub.multiprompt

import android.app.Activity
import android.os.Bundle
import android.view.Gravity
import android.widget.Button
import android.widget.EditText
import android.widget.LinearLayout
import android.widget.ScrollView
import android.widget.TextView
import android.widget.Toast

class SettingsActivity : Activity() {

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        val prefs = Prefs(this)

        val content = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(24, 16, 24, 24)
        }

        fun addField(label: String, value: String): EditText {
            content.addView(TextView(this).apply {
                text = label
                textSize = 14f
                setPadding(0, 16, 0, 4)
            })
            val e = EditText(this).apply {
                setText(value)
                hint = "kosongkan jika tidak dipakai"
                minLines = 1
                maxLines = 3
                gravity = Gravity.TOP or Gravity.START
            }
            content.addView(e)
            return e
        }

        content.addView(TextView(this).apply {
            text = "Pengaturan API key (opsional)"
            textSize = 20f
            setTypeface(typeface, android.graphics.Typeface.BOLD)
            gravity = Gravity.CENTER
        })
        content.addView(TextView(this).apply {
            text = "Isi key bila punya. Provider DuckDuckGo & Pollinations tidak butuh key."
            textSize = 13f
            alpha = 0.7f
        })

        val openai = addField("OpenAI API key", prefs.openaiKey)
        val gemini = addField("Google Gemini API key", prefs.geminiKey)
        val orKey = addField("OpenRouter API key", prefs.openRouterKey)
        val orModel = addField("OpenRouter model (kosong = llama free)", prefs.openRouterModel)

        content.addView(Button(this).apply {
            text = "Simpan"
            setPadding(0, 24, 0, 24)
            setOnClickListener {
                prefs.openaiKey = openai.text.toString().trim()
                prefs.geminiKey = gemini.text.toString().trim()
                prefs.openRouterKey = orKey.text.toString().trim()
                prefs.openRouterModel = orModel.text.toString().trim()
                Toast.makeText(this@SettingsActivity, "Tersimpan", Toast.LENGTH_SHORT).show()
                finish()
            }
        })

        setContentView(ScrollView(this).apply { addView(content) })
    }
}
