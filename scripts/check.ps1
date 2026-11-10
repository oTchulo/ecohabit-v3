param([switch]$BuildApk)
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path $PSScriptRoot -Parent
Push-Location $projectRoot
try {
    $flutterCommand = Join-Path $projectRoot '.tools/flutter/bin/flutter.bat'
    if (!(Test-Path -LiteralPath $flutterCommand)) { $flutterCommand = 'flutter' }
    $localAndroid = Join-Path $projectRoot '.tools/android-sdk'
    if (Test-Path -LiteralPath $localAndroid) { $env:ANDROID_HOME = $localAndroid }
    $env:GRADLE_USER_HOME = Join-Path $projectRoot '.tools/gradle-cache'
    & $flutterCommand pub get
    if ($LASTEXITCODE -ne 0) { throw 'Falha em pub get' }
    & $flutterCommand analyze
    if ($LASTEXITCODE -ne 0) { throw 'Falha em analyze' }
    & $flutterCommand test
    if ($LASTEXITCODE -ne 0) { throw 'Falha em test' }
    if ($BuildApk) {
        & $flutterCommand build apk --debug
        if ($LASTEXITCODE -ne 0) { throw 'Falha no build APK' }
    }
} finally { Pop-Location }
