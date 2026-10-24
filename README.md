# MultiPrompt

Aplikasi **standalone di HP** — satu prompt dikirim serentak ke beberapa AI **tanpa perlu PC/server**.

| Platform | Bentuk | Sumber AI |
|---|---|---|
| Android (5.0+) | APK native (Kotlin) | DuckDuckGo AI (GPT-4o mini, Claude, Llama, Qwen — tanpa akun), Pollinations, + OpenAI/Gemini/OpenRouter bila Anda isi API key |
| iPhone iOS 12.5.8 | App native Swift, dipasang via AltStore | sama |

> **Catatan penting:** DuckDuckGo AI dan Pollinations adalah layanan publik gratis **tidak resmi**;
> model/kuota bisa berubah sewaktu-waktu. Untuk hasil paling stabil, isi API key di menu **Pengaturan / Kunci**.
> Ini bukan akun ChatGPT/Claude/Gemini pribadi Anda — untuk jalur akun resmi, pakai proyek PromptHub (butuh PC).

## Android

Prasyarat (sudah diotomatiskan oleh `scripts/setup-android.ps1`):
JDK 17, Android SDK di `D:\Android\sdk`, Gradle 8.7 di `D:\gradle`.

Build:

```
cd android
gradlew.bat assembleDebug -Dorg.gradle.java.home="C:\Program Files\Microsoft\jdk-17.0.20.101-hotspot"
```

APK hasil: `android\app\build\outputs\apk\debug\app-debug.apk` → salin ke HP → pasang (izin "instal dari sumber tidak dikenal").

## iPhone (iOS 12.5.8) — build cloud + AltStore

Native iOS tidak bisa dikompilasi di Windows, jadi `.ipa` dibangun di macOS cloud (GitHub Actions):

1. Buat repo GitHub **publik** dari folder ini (publik = runner macOS gratis), lalu push.
2. Buka tab **Actions** → *Build iOS (unsigned .ipa)* → **Run workflow** (atau push ke `ios/` memicu otomatis).
3. Unduh artifact **MultiPrompt-ipa**, ekstrak `MultiPrompt.ipa`.
4. Di PC ini: pasang **AltServer** (bagian dari AltStore: https://altstore.io), login Apple ID Anda.
5. Di iPhone: pasang **AltStore** (ikuti wizard AltServer, butuh iTunes/Apple Devices + USB atau Wi-Fi sama).
6. Seret `MultiPrompt.ipa` ke AltServer (ikon di system tray) → *Install MultiPrompt* → pilih iPhone.
7. **Setiap 7 hari** AltServer menandatangani ulang otomatis selama PC & HP nyala satu jaringan;
   tanpa itu aplikasi berhenti bekerja (batasan akun Apple ID gratis).

## Struktur

```
android/   proyek Gradle Kotlin (tanpa library pihak ketiga)
ios/       proyek Swift/UIKit (project.yml untuk XcodeGen, target iOS 12.0)
.github/   workflow build iOS di runner macOS
scripts/   setup-android.ps1 (unduh SDK + Gradle + wrapper)
```

## Keamanan

API key disimpan hanya di perangkat (SharedPreferences / UserDefaults), tidak dikirim ke mana pun
selain ke server penyedia AI terkait.
