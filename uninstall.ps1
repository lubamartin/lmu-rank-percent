#Requires -Version 5.1
[CmdletBinding()]
param()

$ErrorActionPreference = "Stop"
$PluginRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$BackupDir = Join-Path $PluginRoot "backup"
$MetaPath = Join-Path $BackupDir "install-meta.json"

if (-not (Test-Path $MetaPath)) {
  throw "No install-meta.json in backup\. Run install.ps1 first, or restore UI.zip via Steam Verify."
}

$meta = Get-Content $MetaPath -Raw | ConvertFrom-Json
$uiZip = $meta.uiZip
$jsEntry = $meta.jsEntry
$backupJs = Join-Path $BackupDir (($jsEntry -replace '[\\/]', '_') + ".bak")

if (-not (Test-Path $backupJs)) {
  throw "Backup JS missing: $backupJs"
}
if (-not (Test-Path $uiZip)) {
  throw "UI.zip not found: $uiZip"
}

if (Get-Process -Name "Le Mans Ultimate","LeMansUltimate","rFactor2" -ErrorAction SilentlyContinue) {
  throw "LMU appears to be running. Close it, then run uninstall again."
}

Add-Type -AssemblyName System.IO.Compression
Add-Type -AssemblyName System.IO.Compression.FileSystem

$bytes = [System.IO.File]::ReadAllBytes($backupJs)
Write-Host "Restoring $jsEntry into $uiZip ..."

$zip = [System.IO.Compression.ZipFile]::Open($uiZip, [System.IO.Compression.ZipArchiveMode]::Update)
try {
  $entry = $zip.GetEntry($jsEntry)
  if ($entry) { $entry.Delete() }
  $newEntry = $zip.CreateEntry($jsEntry, [System.IO.Compression.CompressionLevel]::Optimal)
  $stream = $newEntry.Open()
  try {
    $stream.Write($bytes, 0, $bytes.Length)
  } finally {
    $stream.Dispose()
  }
} finally {
  $zip.Dispose()
}

Write-Host "Uninstalled. Rank percentages removed."
