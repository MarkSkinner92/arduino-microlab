$dest = $PSScriptRoot
$arduinoParent = "C:\Users\markh\AppData\Local\Arduino15\packages\ISS300\hardware\rp2040"

# Find current version directory
$versionDir = Get-ChildItem -Path $arduinoParent -Directory | Where-Object { $_.Name -match '^\d+\.\d+\.\d+$' } | Select-Object -First 1
if (-not $versionDir) {
    Write-Host "Could not find a version directory in $arduinoParent"
    exit 1
}

$scriptDir = $versionDir.FullName
$currentVersion = $versionDir.Name

Write-Host "The current version is $currentVersion. What is the new version? (A.B.C format): " -NoNewline
$newVersion = Read-Host

Rename-Item -Path $scriptDir -NewName $newVersion
$scriptDir = Join-Path $arduinoParent $newVersion
Write-Host "Renamed directory to $newVersion"

# Step 1: Copy selected files to github repo
Write-Host ""
Write-Host "Copying selected changed files to the local github repo at $dest"
Write-Host "Enter 'w' to proceed, or 's' to skip: " -NoNewline
$choice1 = Read-Host
if ($choice1 -eq 'w') {
    Get-ChildItem -Path $scriptDir -File | Where-Object { $_.Extension -in '.ld','.json','.txt','.md','.py' } | ForEach-Object {
        Copy-Item -Path $_.FullName -Destination $dest -Force
        Write-Host "Copied $($_.Name)"
    }
} else {
    Write-Host "Skipped."
}

# Step 2: Create zip file
Write-Host ""
Write-Host "About to create microlab-$newVersion.zip. Enter 'w' to proceed, or 's' to skip: " -NoNewline
$choice2 = Read-Host
if ($choice2 -eq 'w') {
    $zipSourceDir = Join-Path $arduinoParent "microlab-$newVersion"
    if (-not (Test-Path $zipSourceDir)) {
        New-Item -ItemType Directory -Path $zipSourceDir | Out-Null
    }
    Get-ChildItem -Path $scriptDir -File | ForEach-Object {
        Copy-Item -Path $_.FullName -Destination $zipSourceDir -Force
    }
    $zipPath = Join-Path $arduinoParent "microlab-$newVersion.zip"
    Compress-Archive -Path $zipSourceDir -DestinationPath $zipPath -Force
    Write-Host "Created $zipPath"
} else {
    Write-Host "Skipped."
}

# Step 3: Recalculate package index
Write-Host ""
Write-Host "About to recalculate package index. Enter 'w' to proceed, or 's' to skip: " -NoNewline
$choice3 = Read-Host
if ($choice3 -eq 'w') {
    $runIndex = $true
    if (-not $zipPath) {
        Write-Host "Warning: zip file was not created (step 2 was skipped). Enter 'w' to proceed anyway, or 's' to skip: " -NoNewline
        $choice3b = Read-Host
        if ($choice3b -ne 'w') {
            $runIndex = $false
            Write-Host "Skipped."
        }
    }
    if ($runIndex) {
        $indexScript = Join-Path $dest "update-package-index.ps1"
        $jsonFile = Join-Path $dest "package_ISS300_index.json"
        if (Test-Path $indexScript) {
            & $indexScript -ZipFile $zipPath -JsonFile $jsonFile
        } else {
            Write-Host "update-package-index.ps1 not found in $dest"
        }
    }
} else {
    Write-Host "Skipped."
}

# Step 4: Git add, commit, and push
Write-Host ""
Write-Host "About to run git add, commit, and push in $dest. Enter 'w' to proceed, or 's' to skip: " -NoNewline
$choice4 = Read-Host
if ($choice4 -eq 'w') {
    Write-Host "Commit message: " -NoNewline
    $commitMessage = Read-Host
    Push-Location $dest
    git add .
    git commit -m $commitMessage
    git push
    Pop-Location
} else {
    Write-Host "Skipped."
}

# Step 5: Create GitHub release
Write-Host ""
Write-Host "About to create GitHub release 'MicroLab $newVersion' tagged $newVersion. Enter 'w' to proceed, or 's' to skip: " -NoNewline
$choice5 = Read-Host
if ($choice5 -eq 'w') {
    if (-not $zipPath) {
        Write-Host "Warning: zip file was not created (step 2 was skipped). Enter 'w' to proceed anyway, or 's' to skip: " -NoNewline
        $choice5b = Read-Host
        if ($choice5b -ne 'w') {
            Write-Host "Skipped."
            $choice5 = 's'
        }
    }
}
if ($choice5 -eq 'w') {
    Write-Host "Release notes (optional, press Enter to leave blank): " -NoNewline
    $releaseNotes = Read-Host
    Push-Location $dest
    gh release create $newVersion $zipPath --title "MicroLab $newVersion" --notes $releaseNotes
    Pop-Location
}
