package com.prompthub.multiprompt

import android.content.Context

class Prefs(context: Context) {
    private val sp = context.getSharedPreferences("multiprompt", Context.MODE_PRIVATE)

    fun lastChoice(id: String): Boolean =
        sp.getBoolean("pick_$id", !id.startsWith("ddg") && id != "pollination")

    fun saveChoice(id: String, on: Boolean) { sp.edit().putBoolean("pick_$id", on).apply() }
}
