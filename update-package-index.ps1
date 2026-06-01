<#
.SYNOPSIS
    Updates package_ISS300_index.json with metadata from a MicroLab release zip.

.PARAMETER ZipFile
    Path to the release zip, e.g. microlab-v1.2.3.zip

.PARAMETER JsonFile
    Path to package_ISS300_index.json to update.

.EXAMPLE
    .\update-package-index.ps1 -ZipFile .\microlab-v1.2.3.zip -JsonFile .\package_ISS300_index.json
#>
param(
    [string]$ZipFile,
    [string]$JsonFile
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if (-not $ZipFile -or -not $JsonFile) {
    Write-Host ""
    Write-Host "USAGE"
    Write-Host "  .\update-package-index.ps1 -ZipFile <path> -JsonFile <path>"
    Write-Host ""
    Write-Host "PARAMETERS"
    Write-Host "  -ZipFile   Path to the release zip.  Must be named microlab-vX.X.X.zip"
    Write-Host "  -JsonFile  Path to package_ISS300_index.json to update"
    Write-Host ""
    Write-Host "EXAMPLE"
    Write-Host "  .\update-package-index.ps1 -ZipFile .\microlab-v1.2.3.zip -JsonFile .\package_ISS300_index.json"
    Write-Host ""
    exit 1
}

# Resolve to absolute paths
$ZipFile = Resolve-Path $ZipFile
$JsonFile = Resolve-Path $JsonFile

$zipName = [System.IO.Path]::GetFileName($ZipFile)

# Extract version from filename like microlab-v1.2.3.zip or microlab-1.2.3.zip
if ($zipName -notmatch '^microlab-v?(\d+\.\d+\.\d+)\.zip$') {
    Write-Error "Zip filename '$zipName' does not match expected pattern 'microlab-vX.X.X.zip'."
    exit 1
}
$version = $Matches[1]

# Compute SHA-256 checksum
Write-Host "Computing SHA-256 checksum..."
$hash = (Get-FileHash -Path $ZipFile -Algorithm SHA256).Hash.ToLower()
$checksum = "SHA-256:$hash"

# Get file size in bytes
$size = (Get-Item $ZipFile).Length.ToString()

# Build the new URL using the same GitHub release pattern
$url = "https://github.com/MarkSkinner92/arduino-microlab/releases/download/$version/$zipName"

Write-Host "Version:  $version"
Write-Host "File:     $zipName"
Write-Host "Size:     $size bytes"
Write-Host "Checksum: $checksum"
Write-Host "URL:      $url"

# Load JSON (preserve formatting as much as possible via raw text replacement isn't reliable;
# use ConvertFrom-Json / ConvertTo-Json with sufficient depth)
$raw = Get-Content -Path $JsonFile -Raw -Encoding UTF8
$json = $raw | ConvertFrom-Json

$platform = $json.packages[0].platforms[0]
$platform.version         = $version
$platform.archiveFileName = $zipName
$platform.url             = $url
$platform.size            = $size
$platform.checksum        = $checksum

# ConvertTo-Json defaults depth to 2, which truncates nested objects — use a high depth
$updated = $json | ConvertTo-Json -Depth 20

# Write back with UTF-8 (no BOM)
[System.IO.File]::WriteAllText($JsonFile, $updated, [System.Text.UTF8Encoding]::new($false))

Write-Host "`npackage_ISS300_index.json updated successfully."
