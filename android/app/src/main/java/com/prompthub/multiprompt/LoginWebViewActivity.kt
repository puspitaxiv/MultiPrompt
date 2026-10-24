package com.prompthub.multiprompt

import android.annotation.SuppressLint
import android.app.Activity
import android.os.Bundle
import android.view.Gravity
import android.webkit.CookieManager
import android.webkit.WebView
import android.webkit.WebViewClient
import android.widget.Button
import android.widget.LinearLayout

/** Jendela login manual: masuk ke akun AI di sini; sesi (cookie) tersimpan di aplikasi. */
class LoginWebViewActivity : Activity() {

    @SuppressLint("SetJavaScriptEnabled")
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        val cfg = WebChat.byId(intent.getStringExtra("platform") ?: "") ?: run { finish(); return }

        val root = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
        }
        val webView = WebView(this).apply {
            layoutParams = LinearLayout.LayoutParams(LinearLayout.LayoutParams.MATCH_PARENT, 0, 4f)
            settings.javaScriptEnabled = true
            settings.domStorageEnabled = true
            settings.userAgentString =
                "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36"
            webViewClient = WebViewClient()
        }
        val bar = LinearLayout(this).apply { orientation = LinearLayout.HORIZONTAL }
        bar.addView(Button(this).apply {
            text = "Tutup setelah login selesai"
            layoutParams = LinearLayout.LayoutParams(0, LinearLayout.LayoutParams.WRAP_CONTENT, 1f)
            setOnClickListener {
                CookieManager.getInstance().flush()
                finish()
            }
        })
        bar.addView(Button(this).apply {
            text = "Muat ulang"
            layoutParams = LinearLayout.LayoutParams(0, LinearLayout.LayoutParams.WRAP_CONTENT, 1f)
            setOnClickListener { webView.loadUrl(cfg.homeUrl) }
        })
        CookieManager.getInstance().setAcceptCookie(true)
        CookieManager.getInstance().setAcceptThirdPartyCookies(webView, true)
        root.addView(bar)
        root.addView(webView)
        root.addView(android.widget.TextView(this).apply {
            text = "Login ${cfg.name}: masukkan email/password/OTP sampai halaman chat terbuka, lalu tekan Tutup."
            textSize = 12f
            gravity = Gravity.CENTER
            setPadding(16, 8, 16, 8)
        })
        setContentView(root)
        webView.loadUrl(cfg.homeUrl)
    }

    override fun onDestroy() {
        CookieManager.getInstance().flush()
        super.onDestroy()
    }
}
