# Google Play — release AAB (нужен android/key.properties + upload-keystore.jks)
$ErrorActionPreference = "Stop"
Set-Location (Join-Path $PSScriptRoot "..")

if (-not (Test-Path "android\key.properties")) {
    Write-Host "Создайте android\key.properties из key.properties.example" -ForegroundColor Yellow
    exit 1
}

flutter pub get
flutter build appbundle --release
Write-Host ""
Write-Host "AAB: build\app\outputs\bundle\release\app-release.aab" -ForegroundColor Green
