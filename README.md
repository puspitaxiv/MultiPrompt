# MultiPrompt

Aplikasi **standalone di HP** — satu prompt dikirim serentak ke beberapa AI **tanpa PC/server, tanpa API key**.

| Platform | Bentuk | Sumber AI |
|---|---|---|
| Android (7.0+) | APK native (Kotlin) | Otomasi WebView 6 situs (ChatGPT, Claude, Gemini, Copilot, Grok, DeepSeek) dengan **login manual** di dalam aplikasi; + penyedia HTTP tanpa-login (DuckDuckGo AI, Pollinations) |
| iPhone (iOS 18+) | App native Swift, dipasang via AltStore | sama (WKWebView) |

## Tanpa API key — cara kerjanya

1. Centak provider yang diinginkan di layar utama.
2. Untuk 6 situs AI: tekan **Login** di samping nama situs → buka WebView → login akun Anda seperti biasa → tutup. Cookie tersimpan di aplikasi.
3. Tekan **Kirim**: aplikasi mengetik prompt ke kolom input situs lewat JavaScript di WebView tak terlihat, menunggu jawaban, lalu menampilkannya.
4. Provider gratis (DuckDuckGo/Pollinations) tidak butuh login.

> **Catatan (24-10-2026):** endpoint HTTP DuckDuckGo sedang tidak menghasilkan token (`vqd`) —
> penyedia `ddg-*` melaporkan error sampai layanan itu pulih. Jalur WebView dan Pollinations tidak terpengaruh.
> Otomasi antarmuka web bisa melanggar ToS situs; selector dapat berubah sewaktu-waktu — risiko diterima pengguna.
> Login Google (Gemini) sering ditolak WebView Android; pakai browser sistem bila diminta.

## Android

Prasyarat (sudah diotomatiskan `scripts/setup-android.ps1`): JDK 17, Android SDK `D:\Android\sdk`, Gradle 8.7 `D:\gradle`.

Build:

```
cd android
gradlew.bat assembleDebug
```

(jalan `org.gradle.java.home` sudah diset di `gradle.properties`)

APK hasil: `android\app\build\outputs\apk\debug\app-debug.apk` — salinan siap pakai di `release\MultiPrompt-debug.apk`.

## iPhone (iOS 18+) — build cloud + AltStore

Native iOS tidak bisa dikompilasi di Windows, jadi `.ipa` dibangun di macOS cloud (GitHub Actions):

1. Push ke repo GitHub **publik** `puspitaxiv/MultiPrompt` — workflow `Build iOS (unsigned .ipa)` jalan otomatis.
2. Unduh artifact **MultiPrompt-ipa** (`gh run download -n MultiPrompt-ipa`). Salinan terbaru ada di `release\MultiPrompt.ipa`.
3. Di PC: pasang **AltServer** (https://altstore.io), login Apple ID.
4. Di iPhone: pasang **AltStore**, lalu seret `MultiPrompt.ipa` ke AltServer → *Install MultiPrompt*.
5. **Setiap 7 hari** AltServer menandatangani ulang selama PC & HP nyala satu jaringan (batasan Apple ID gratis).

## Struktur

```
android/   proyek Gradle Kotlin (tanpa library pihak ketiga; WebView automation di WebChat.kt)
ios/       proyek Swift/UIKit (project.yml XcodeGen, target iOS 18.0; WebChat.swift)
.github/   workflow build iOS di runner macOS (Xcode 16.4)
scripts/   setup-android.ps1
release/   APK + IPA hasil build terbaru
```

## Keamanan

Tidak ada API key. Cookie/sesi login hanya tersimpan di perangkat (CookieManager / WKWebsiteDataStore) dan hanya dikirim ke situs terkait.
