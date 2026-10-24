package com.prompthub.multiprompt

import android.annotation.SuppressLint
import android.app.Activity
import android.os.Handler
import android.os.Looper
import android.view.ViewGroup
import android.webkit.CookieManager
import android.webkit.WebView
import android.webkit.WebViewClient
import android.widget.FrameLayout
import org.json.JSONArray
import org.json.JSONObject

data class WebCfg(
    val id: String,
    val name: String,
    val homeUrl: String,
    val startUrl: String,
    val composer: List<String>,
    val send: List<String>,
    val reply: List<String>
)

object WebChat {

    // Selector bisa berubah bila situs memperbarui tampilan; sama dengan daftar di PromptHub.
    val PLATFORMS = listOf(
        WebCfg(
            "chatgpt", "ChatGPT", "https://chatgpt.com/", "https://chatgpt.com/c/",
            listOf("#prompt-textarea", "div[contenteditable=\"true\"][role=\"textbox\"]", "textarea#chat-input"),
            listOf("button[aria-label=\"Send message\"]", "button[aria-label=\"Kirim pesan\"]"),
            listOf("div[data-message-author-role=\"assistant\"] .markdown", "div[data-message-id] .markdown")
        ),
        WebCfg(
            "claude", "Claude", "https://claude.ai/login", "https://claude.ai/new",
            listOf("div[role=\"textbox\"][contenteditable=\"true\"]", "div[contenteditable=\"true\"]"),
            listOf("button[aria-label=\"Send message\"]", "button[data-testid=\"send-button\"]"),
            listOf("div[data-testid=\"assistant-message-text\"]", ".font-claude-message", "article .message-content")
        ),
        WebCfg(
            "gemini", "Google Gemini", "https://gemini.google.com/", "https://gemini.google.com/app",
            listOf("rich-textarea .ql-editor", "div.ql-editor[contenteditable=\"true\"]"),
            listOf("button.send-button", "button[aria-label=\"kirim pesan\"]"),
            listOf("message-content .ql-editor", "message-content", ".model-response-text")
        ),
        WebCfg(
            "copilot", "Microsoft Copilot", "https://copilot.microsoft.com/", "https://copilot.microsoft.com/",
            listOf("#searchbox", "div[role=\"textbox\"][contenteditable=\"true\"]", "div.ql-editor"),
            listOf("button[aria-label=\"Send\"]", "button[data-testid=\"sendButton\"]"),
            listOf(".turn[data-role=\"assistant\"]", ".markdown-content")
        ),
        WebCfg(
            "grok", "Grok", "https://grok.com/", "https://grok.com/",
            listOf("textarea[placeholder]", "div[contenteditable=\"true\"][role=\"textbox\"]", "div.ql-editor"),
            listOf("button[type=\"submit\"]", "button[aria-label*=\"Send\"]"),
            listOf("div[class*=\"prose\"]", ".markdown")
        ),
        WebCfg(
            "deepseek", "DeepSeek", "https://chat.deepseek.com/", "https://chat.deepseek.com/",
            listOf("textarea", "div[contenteditable=\"true\"]"),
            listOf("button[aria-label=\"Send\"]"),
            listOf(".ds-markdown", "div[class*=\"message-content\"]")
        )
    )

    fun byId(id: String): WebCfg? = PLATFORMS.firstOrNull { it.id == id }

    interface Callback {
        fun onDone(text: String)
        fun onFail(msg: String)
    }

    private const val DESKTOP_UA =
        "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36"

    @SuppressLint("SetJavaScriptEnabled")
    fun run(activity: Activity, cfg: WebCfg, prompt: String, cb: Callback) {
        Handler(Looper.getMainLooper()).post {
            var wv: WebView? = null
            var finished = false
            val handler = Handler(Looper.getMainLooper())
            val root = activity.findViewById<ViewGroup>(android.R.id.content)

            fun cleanup() {
                if (finished) return
                finished = true
                try {
                    root.removeView(wv)
                    wv?.destroy()
                } catch (e: Exception) { /* sudah tertutup */ }
            }
            fun fail(msg: String) {
                if (finished) return
                cleanup()
                cb.onFail(msg)
            }
            fun ok(text: String) {
                if (finished) return
                cleanup()
                cb.onDone(text)
            }

            try {
                val view = WebView(activity)
                wv = view
                view.settings.javaScriptEnabled = true
                view.settings.domStorageEnabled = true
                view.settings.userAgentString = DESKTOP_UA
                CookieManager.getInstance().setAcceptCookie(true)
                CookieManager.getInstance().setAcceptThirdPartyCookies(view, true)
                val params = FrameLayout.LayoutParams(1100, 1600)
                view.layoutParams = params
                view.alpha = 0f
                view.translationX = 100000f
                root.addView(view)

                val quote = JSONObject.quote(prompt)
                val inputJs = """
                    (function(){
                      var sels = ${JSONArray(cfg.composer)};
                      var el = null;
                      for (var i=0;i<sels.length;i++){ try{ el=document.querySelector(sels[i]); }catch(e){ el=null; } if(el) break; }
                      if(!el) return 'NO_COMPOSER';
                      window.__mp_el = el;
                      try{ el.scrollIntoView(); el.click(); el.focus(); }catch(e){}
                      var text = $quote;
                      if(el.isContentEditable){
                        var okInsert=false;
                        try{ okInsert=document.execCommand('insertText',false,text); }catch(e){}
                        if(!okInsert || (el.textContent||'').trim().length===0){
                          el.textContent = text;
                          try{ el.dispatchEvent(new InputEvent('input',{bubbles:true,inputType:'insertText'})); }catch(e){}
                        }
                      } else {
                        var proto = el.tagName==='TEXTAREA' ? HTMLTextAreaElement.prototype : HTMLInputElement.prototype;
                        var setter = Object.getOwnPropertyDescriptor(proto,'value').set;
                        setter.call(el, text);
                        try{ el.dispatchEvent(new Event('input',{bubbles:true})); }catch(e){}
                      }
                      return 'OK';
                    })()
                """.trimIndent()

                val sendJs = """
                    (function(){
                      var el = window.__mp_el; if(!el) return 'NO_EL';
                      var opts = {key:'Enter',code:'Enter',keyCode:13,which:13,bubbles:true,cancelable:true};
                      try{
                        el.dispatchEvent(new KeyboardEvent('keydown',opts));
                        el.dispatchEvent(new KeyboardEvent('keypress',opts));
                        el.dispatchEvent(new KeyboardEvent('keyup',opts));
                      }catch(e){}
                      var sends = ${JSONArray(cfg.send)};
                      for(var i=0;i<sends.length;i++){ try{ var b=document.querySelector(sends[i]); if(b){ b.click(); break; } }catch(e){} }
                      return 'SENT';
                    })()
                """.trimIndent()

                val replyJs = """
                    (function(){
                      var sels = ${JSONArray(cfg.reply)};
                      for(var i=0;i<sels.length;i++){
                        try{
                          var ns=document.querySelectorAll(sels[i]);
                          if(ns.length){ var t=ns[ns.length-1].innerText||''; if(t.trim()) return t; }
                        }catch(e){}
                      }
                      return '';
                    })()
                """.trimIndent()

                fun unquote(result: String?): String {
                    if (result.isNullOrEmpty()) return ""
                    return try { JSONObject("{\"v\":$result}").getString("v") } catch (e: Exception) { result }
                }

                var last = ""
                var stable = 0
                val deadline = System.currentTimeMillis() + 180000
                fun startPolling() {
                    if (finished) return
                    view.evaluateJavascript(replyJs) { res ->
                        if (finished) return@evaluateJavascript
                        val txt = unquote(res).trim()
                        if (txt.isNotEmpty() && txt == last) {
                            stable += 1
                            if (stable >= 3) { ok(txt); return@evaluateJavascript }
                        } else {
                            stable = 0
                            last = txt
                        }
                        if (System.currentTimeMillis() > deadline) {
                            if (last.isNotEmpty()) ok(last) else fail("${cfg.name}: tidak ada respons dalam 3 menit.")
                            return@evaluateJavascript
                        }
                        handler.postDelayed({ startPolling() }, 1500)
                    }
                }

                var loadedOnce = false
                view.webViewClient = object : WebViewClient() {
                    override fun onPageFinished(wv: WebView?, urlStr: String?) {
                        if (loadedOnce || finished) return
                        loadedOnce = true
                        handler.postDelayed({
                            if (finished) return@postDelayed
                            view.evaluateJavascript(inputJs) { res ->
                                if (finished) return@evaluateJavascript
                                val v = unquote(res)
                                if (!v.contains("OK")) {
                                    fail("${cfg.name}: kolom input tidak ditemukan — tekan tombol Login, masuk ke akun Anda, tutup, lalu coba Kirim lagi.")
                                    return@evaluateJavascript
                                }
                                handler.postDelayed({
                                    if (finished) return@postDelayed
                                    view.evaluateJavascript(sendJs) {
                                        startPolling()
                                    }
                                }, 600)
                            }
                        }, 5000)
                    }
                }

                view.loadUrl(cfg.startUrl)
            } catch (e: Exception) {
                fail("${cfg.name}: ${e.message}")
            }
        }
    }
}
