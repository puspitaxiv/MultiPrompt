$ErrorActionPreference = 'Stop'
$env:JAVA_HOME = 'C:\Program Files\Microsoft\jdk-17.0.20.101-hotspot'
$env:Path = "$env:JAVA_HOME\bin;$env:Path"
$sdk = 'D:\Android\sdk'

Write-Host '== Unduh Android cmdline-tools =='
New-Item -ItemType Directory -Force -Path "$sdk\cmdline-tools" | Out-Null
$zip = "$env:TEMP\cmdline-tools.zip"
Invoke-WebRequest 'https://dl.google.com/android/repository/commandlinetools-win-11076708_latest.zip' -OutFile $zip
Expand-Archive $zip -DestinationPath "$env:TEMP\cmdline-extract" -Force
if (Test-Path "$sdk\cmdline-tools\latest") { Remove-Item -Recurse -Force "$sdk\cmdline-tools\latest" }
Move-Item "$env:TEMP\cmdline-extract\cmdline-tools" "$sdk\cmdline-tools\latest"

$sdkmanager = "$sdk\cmdline-tools\latest\bin\sdkmanager.bat"

Write-Host '== Terima lisensi =='
$yes = ('y' + "`n") * 20
$yes | & $sdkmanager --sdk_root=$sdk --licenses | Out-Null

Write-Host '== Instal platform-tools, android-34, build-tools =='
& $sdkmanager --sdk_root=$sdk "platform-tools" "platforms;android-34" "build-tools;34.0.0"

Write-Host '== Unduh Gradle =='
$gver = '8.7'
$gzip = "$env:TEMP\gradle.zip"
Invoke-WebRequest "https://services.gradle.org/distributions/gradle-$gver-bin.zip" -OutFile $gzip
Expand-Archive $gzip -DestinationPath 'D:\gradle' -Force

Write-Host '== Generate wrapper di proyek Android =='
Set-Location 'D:\MultiPrompt\android'
& "D:\gradle\gradle-$gver\bin\gradle.bat" wrapper --gradle-version $gver --no-daemon

Write-Host 'SELESAI_SDK'
