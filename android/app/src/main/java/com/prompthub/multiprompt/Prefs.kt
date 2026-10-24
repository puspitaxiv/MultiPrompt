package com.prompthub.multiprompt

import android.content.Context

class Prefs(context: Context) {
    private val sp = context.getSharedPreferences("multiprompt", Context.MODE_PRIVATE)

    var openaiKey: String
        get() = sp.getString("openai_key", "") ?: ""
        set(v) { sp.edit().putString("openai_key", v).apply() }

    var geminiKey: String
        get() = sp.getString("gemini_key", "") ?: ""
        set(v) { sp.edit().putString("gemini_key", v).apply() }

    var openRouterKey: String
        get() = sp.getString("openrouter_key", "") ?: ""
        set(v) { sp.edit().putString("openrouter_key", v).apply() }

    var openRouterModel: String
        get() = sp.getString("openrouter_model", "") ?: ""
        set(v) { sp.edit().putString("openrouter_model", v).apply() }

    fun lastChoice(id: String): Boolean = sp.getBoolean("pick_$id", id.startsWith("ddg") || id == "pollination")
    fun saveChoice(id: String, on: Boolean) { sp.edit().putBoolean("pick_$id", on).apply() }
}
