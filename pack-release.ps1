#Requires -Version 5.1
[CmdletBinding()]
param(
  [string]$OutDir = ""
)

$ErrorActionPreference = "Stop"
$Root = Split-Path -Parent $MyInvocation.MyCommand.Path
$Version = (Get-Content (Join-Path $Root "VERSION") -Raw).Trim()
if (-not $OutDir) { $OutDir = Join-Path $Root "dist" }

$FolderName = "LMU_Rank_Percent_v$Version"
$Stage = Join-Path $OutDir $FolderName
$ZipPath = Join-Path $OutDir "$FolderName.zip"

if (Test-Path $Stage) { Remove-Item $Stage -Recurse -Force }
New-Item -ItemType Directory -Path $Stage -Force | Out-Null

$files = @(
  "install.ps1",
  "uninstall.ps1",
  "README.md",
  "VERSION"
)
foreach ($f in $files) {
  $src = Join-Path $Root $f
  if (-not (Test-Path $src)) { throw "Missing: $f" }
  Copy-Item $src (Join-Path $Stage $f)
}

if (Test-Path $ZipPath) { Remove-Item $ZipPath -Force }
Compress-Archive -Path $Stage -DestinationPath $ZipPath -CompressionLevel Optimal

Write-Host "Packaged: $ZipPath"
Write-Host "Upload that zip to OverTake (Misc mods)."
