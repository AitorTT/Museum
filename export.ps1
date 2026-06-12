$ProjectDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$Godot = "C:\Users\User\Documents\Godot_v4.6.2-stable_win64.exe\Godot_v4.6.2-stable_win64.exe"
$ExportDir = Join-Path $ProjectDir "EXPORT"
$ZipPath = Join-Path $ProjectDir "EXPORT.zip"

Write-Host "=== Compressing images >600KB ===" -ForegroundColor Cyan
python "$ProjectDir\tools\compress_images.py"

Write-Host "=== Exporting Web build ===" -ForegroundColor Cyan
& $Godot --headless --path $ProjectDir --export-release "Web"

if ($LASTEXITCODE -and $LASTEXITCODE -ne 0) {
    Write-Host "Export failed (exit code $LASTEXITCODE)" -ForegroundColor Red
    exit $LASTEXITCODE
}

Write-Host "=== Compressing EXPORT -> EXPORT.zip ===" -ForegroundColor Cyan
if (Test-Path $ZipPath) {
    Remove-Item $ZipPath -Force
}
Compress-Archive -Path "$ExportDir\*" -DestinationPath $ZipPath

$SizeMB = (Get-Item $ZipPath).Length / 1MB -as [int]
Write-Host "Done: EXPORT.zip ($SizeMB MB)" -ForegroundColor Green
Write-Host "Deploy: butler push EXPORT.zip user/museum:web" -ForegroundColor Yellow
