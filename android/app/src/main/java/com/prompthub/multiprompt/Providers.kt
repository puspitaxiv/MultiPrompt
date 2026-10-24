package com.prompthub.multiprompt

import org.json.JSONArray
import org.json.JSONObject
import java.io.BufferedReader
import java.io.InputStream
import java.io.InputStreamReader
import java.net.HttpURLConnection
import java.net.URL
import java.net.URLEncoder
import java.util.UUID

class AiException(message: String) : Exception(message)

object Http {
    private const val UA =
        "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36"

    fun open(method: String, url: String, headers: Map<String, String> = emptyMap(), body: String? = null): HttpURLConnection {
        val conn = URL(url).openConnection() as HttpURLConnection
        conn.requestMethod = method
        conn.connectTimeout = 20000
        conn.readTimeout = 120000
        conn.setRequestProperty("User-Agent", UA)
        conn.setRequestProperty("Accept", "*/*")
        for ((k, v) in headers) conn.setRequestProperty(k, v)
        if (body != null) {
            conn.doOutput = true
            conn.outputStream.use { it.write(body.toByteArray(Charsets.UTF_8)) }
        }
        return conn
    }

    fun readAll(stream: InputStream): String {
        BufferedReader(InputStreamReader(stream, Charsets.UTF_8)).use { return it.readText() }
    }

    fun text(method: String, url: String, headers: Map<String, String> = emptyMap(), body: String? = null): String {
        val conn = open(method, url, headers, body)
        try {
            val code = conn.responseCode
            val stream = if (code in 200..299) conn.inputStream else conn.errorStream
            val txt = if (stream != null) readAll(stream) else ""
            if (code !in 200..299) throw AiException("HTTP $code: ${txt.take(200)}")
            return txt
        } finally {
            conn.disconnect()
        }
    }
}

data class Provider(
    val id: String,
    val name: String,
    val web: Boolean = false // true = butuh login manual via WebView
)

object Providers {
    val ALL = listOf(
        Provider("chatgpt", "ChatGPT (login sendiri)", web = true),
        Provider("claude", "Claude (login sendiri)", web = true),
        Provider("gemini", "Google Gemini (login sendiri)", web = true),
        Provider("copilot", "Microsoft Copilot (login sendiri)", web = true),
        Provider("grok", "Grok (login sendiri)", web = true),
        Provider("deepseek", "DeepSeek (login sendiri)", web = true),
        Provider("ddg-gpt", "DuckDuckGo · GPT-4o mini"),
        Provider("ddg-claude", "DuckDuckGo · Claude Sonnet"),
        Provider("ddg-llama", "DuckDuckGo · Llama 3.1 70B"),
        Provider("ddg-qwen", "DuckDuckGo · Qwen 2.5 72B"),
        Provider("pollination", "Pollinations (gratis)")
    )

    val DDG_MODELS = mapOf(
        "ddg-gpt" to "gpt-4o-mini",
        "ddg-claude" to "claude-sonnet-4",
        "ddg-llama" to "meta-llama/Meta-Llama-3.1-70B-Instruct",
        "ddg-qwen" to "qwen/qwen-2.5-72b-instruct"
    )

    /** Hanya untuk penyedia HTTP (bukan web:true). */
    fun ask(id: String, prompt: String): String = when (id) {
        in DDG_MODELS.keys -> duckDuckGo(DDG_MODELS[id]!!, prompt)
        "pollination" -> pollinations(prompt)
        else -> throw AiException("Provider tidak dikenal: $id")
    }

    // ---- DuckDuckGo AI chat (tanpa akun, tidak resmi, bisa berubah sewaktu-waktu) ----
    private fun duckDuckGo(model: String, prompt: String): String {
        // ambil token vqd + cookie dari halaman /models
        val conn = Http.open("GET", "https://duck.ai/models", mapOf("Accept" to "application/json"))
        val cookie = (conn.headerFields["Set-Cookie"] ?: emptyList())
            .firstOrNull { it.contains("llm=") }?.substringBefore(";") ?: "llm=1"
        val modelsJson = try { Http.readAll(conn.inputStream) } catch (e: Exception) { "" } finally { conn.disconnect() }
        val vqd = Regex("vqd=([0-9a-zA-Z_-]+)").find(modelsJson)?.groupValues?.get(1)
            ?: throw AiException("Gagal ambil token DuckDuckGo (layanan mungkin berubah/diblokir)")

        val uuid = UUID.randomUUID().toString()
        val sid = (0 until 52).map { (('a'..'z') + ('A'..'Z') + ('0'..'9')).random() }.joinToString("")
        val body = JSONObject().apply {
            put("searchParams", JSONObject().put("qd", prompt).put("vqd", vqd))
            put("messages", JSONArray().put(JSONObject().apply {
                put("action_type", "next")
                put("content", prompt)
                put("context", JSONObject())
                put("role", "user")
                put("id", uuid)
            }))
            put("tools", JSONArray())
            put("title", prompt.take(48))
            put("model", model)
            put("chatSessionId", sid)
            put("deepSearch", false)
            put("isGenerated", false)
            put("parentMessageId", uuid)
            put("temperature", 0.7)
            put("topP", 0.9)
        }.toString()

        val chat = Http.open(
            "POST", "https://duck.ai/chat/?chat_version=2",
            mapOf(
                "Content-Type" to "application/x-www-form-urlencoded",
                "Accept" to "text/event-stream",
                "x-vqd-4" to uuid,
                "Origin" to "https://duck.ai",
                "Cookie" to cookie
            ),
            "body=$body"
        )
        try {
            if (chat.responseCode != 200) {
                val err = try { Http.readAll(chat.errorStream ?: chat.inputStream) } catch (e: Exception) { "" }
                throw AiException("DuckDuckGo HTTP ${chat.responseCode}: ${err.take(160)}")
            }
            val answer = StringBuilder()
            BufferedReader(InputStreamReader(chat.inputStream, Charsets.UTF_8)).use { r ->
                while (true) {
                    val line = r.readLine() ?: break
                    if (!line.startsWith("data:")) continue
                    val payload = line.substring(5).trim()
                    if (payload.isEmpty() || payload == "[DONE]") continue
                    try {
                        val o = JSONObject(payload)
                        if (o.optString("role") == "assistant" && o.has("content") && !o.isNull("content")) {
                            answer.append(o.getString("content"))
                        }
                    } catch (e: Exception) { /* baris non-JSON: lewati */ }
                }
            }
            val out = answer.toString().trim()
            if (out.isEmpty()) throw AiException("DuckDuckGo tidak mengirim jawaban")
            return out
        } finally {
            chat.disconnect()
        }
    }

    // ---- Pollinations (gratis, tanpa akun) ----
    private fun pollinations(prompt: String): String {
        val url = "https://text.pollinations.ai/" + URLEncoder.encode(prompt, "UTF-8") + "?model=openai&nolog=true"
        val txt = Http.text("GET", url)
        if (txt.isBlank()) throw AiException("Pollinations mengirim balasan kosong")
        return txt.trim()
    }
}
