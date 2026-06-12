# One-time: create upload-keystore.jks and android/key.properties for Google Play
# Run: cd app; .\scripts\setup-play-signing.ps1

$ErrorActionPreference = "Stop"
$appRoot = Split-Path $PSScriptRoot -Parent
$androidDir = Join-Path $appRoot "android"
$keystorePath = Join-Path $androidDir "upload-keystore.jks"
$keyPropsPath = Join-Path $androidDir "key.properties"

if (Test-Path $keyPropsPath) {
    Write-Host "android\key.properties already exists. Delete it first to recreate." -ForegroundColor Yellow
    exit 1
}

Write-Host "=== Kharid.tj - Google Play signing setup ===" -ForegroundColor Cyan
Write-Host "Application ID: tj.kharid.app"
Write-Host ""

$storePass = Read-Host "Keystore password (storePassword, min 6 chars)"
$keyPass = Read-Host "Key password for alias upload (Enter = same as keystore)"
if ([string]::IsNullOrWhiteSpace($keyPass)) { $keyPass = $storePass }

$cn = Read-Host "Company / project name [Kharid.tj]"
if ([string]::IsNullOrWhiteSpace($cn)) { $cn = "Kharid.tj" }

$dname = "CN=$cn, OU=Mobile, O=Kharid.tj, L=Dushanbe, ST=Dushanbe, C=TJ"

Write-Host ""
Write-Host "Creating keystore: $keystorePath" -ForegroundColor Green

$keytool = Get-Command keytool -ErrorAction SilentlyContinue
if (-not $keytool) {
    Write-Host "keytool not found. Install JDK and add it to PATH." -ForegroundColor Red
    exit 1
}

& keytool -genkeypair -v `
    -storetype JKS `
    -keyalg RSA `
    -keysize 2048 `
    -validity 10000 `
    -alias upload `
    -keystore $keystorePath `
    -storepass $storePass `
    -keypass $keyPass `
    -dname $dname

$lines = @(
    "storePassword=$storePass"
    "keyPassword=$keyPass"
    "keyAlias=upload"
    "storeFile=../upload-keystore.jks"
)
Set-Content -Path $keyPropsPath -Value $lines -Encoding ASCII

Write-Host ""
Write-Host "Done:" -ForegroundColor Green
Write-Host "  android\upload-keystore.jks"
Write-Host "  android\key.properties"
Write-Host ""
Write-Host "BACK UP keystore and passwords! You cannot update the app in Play without them." -ForegroundColor Yellow
Write-Host ""
Write-Host "Next: flutter build appbundle --release"
