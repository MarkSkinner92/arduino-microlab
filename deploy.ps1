$dest = $PSScriptRoot
$arduinoParent = "C:\Users\markh\AppData\Local\Arduino15\packages\ISS300\hardware\rp2040"

# Show stage list and ask where to start
Write-Host "Deploy Script Stages:"
Write-Host "  1. Copy selected files to local GitHub repo"
Write-Host "  2. Create zip file"
Write-Host "  3. Recalculate package index"
Write-Host "  4. Git add, commit, and push"
Write-Host "  5. Create GitHub release"
Write-Host ""
Write-Host "Enter stage number to start from (or press Enter for stage 1): " -NoNewline
$startStageInput = Read-Host
$startStage = if ($startStageInput -match '^\d+$') { [int]$startStageInput } else { 1 }
Write-Host ""

# Find current version directory
$versionDir = Get-ChildItem -Path $arduinoParent -Directory | Where-Object { $_.Name -match '^\d+\.\d+\.\d+$' } | Select-Object -First 1
if (-not $versionDir) {
    Write-Host "Could not find a version directory in $arduinoParent"
    exit 1
}

$scriptDir = $versionDir.FullName
$currentVersion = $versionDir.Name

if ($startStage -le 1) {
    Write-Host "The current version is $currentVersion. What is the new version? (A.B.C format): " -NoNewline
    $newVersion = Read-Host
    Rename-Item -Path $scriptDir -NewName $newVersion
    $scriptDir = Join-Path $arduinoParent $newVersion
    Write-Host "Renamed directory to $newVersion"
} else {
    $newVersion = $currentVersion
    Write-Host "Resuming from stage $startStage with version $newVersion"
}

$zipPath = Join-Path $arduinoParent "microlab-$newVersion.zip"

# Stage 1: Copy selected files to GitHub repo
if ($startStage -le 1) {
    Write-Host ""
    Write-Host "Stage 1: Copying selected files to local GitHub repo at $dest"
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
}

# Stage 2: Create zip file
if ($startStage -le 2) {
    Write-Host ""
    Write-Host "Stage 2: Create microlab-$newVersion.zip"
    Write-Host "Enter 'w' to proceed, or 's' to skip: " -NoNewline
    $choice2 = Read-Host
    if ($choice2 -eq 'w') {
        $zipSourceDir = Join-Path $arduinoParent "microlab-$newVersion"
        if (-not (Test-Path $zipSourceDir)) {
            New-Item -ItemType Directory -Path $zipSourceDir | Out-Null
        }
        Copy-Item -Path (Join-Path $scriptDir '*') -Destination $zipSourceDir -Recurse -Force
        Compress-Archive -Path $zipSourceDir -DestinationPath $zipPath -Force
        Write-Host "Created $zipPath"
    } else {
        Write-Host "Skipped."
    }
}

# Stage 3: Recalculate package index
if ($startStage -le 3) {
    Write-Host ""
    Write-Host "Stage 3: Recalculate package index"
    Write-Host "Enter 'w' to proceed, or 's' to skip: " -NoNewline
    $choice3 = Read-Host
    if ($choice3 -eq 'w') {
        $runIndex = $true
        if (-not (Test-Path $zipPath)) {
            Write-Host "Warning: zip file not found at $zipPath. Enter 'w' to proceed anyway, or 's' to skip: " -NoNewline
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
}

# Stage 4: Git add, commit, and push
if ($startStage -le 4) {
    Write-Host ""
    Write-Host "Stage 4: Git add, commit, and push in $dest"
    Write-Host "Enter 'w' to proceed, or 's' to skip: " -NoNewline
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
}

# Stage 5: Create GitHub release
if ($startStage -le 5) {
    Write-Host ""
    Write-Host "Stage 5: Create GitHub release 'MicroLab $newVersion' tagged $newVersion"
    Write-Host "Enter 'w' to proceed, or 's' to skip: " -NoNewline
    $choice5 = Read-Host
    if ($choice5 -eq 'w') {
        if (-not (Test-Path $zipPath)) {
            Write-Host "Warning: zip file not found at $zipPath. Enter 'w' to proceed anyway, or 's' to skip: " -NoNewline
            $choice5b = Read-Host
            if ($choice5b -ne 'w') {
                Write-Host "Skipped."
                $choice5 = 's'
            }
        }
    }
    if ($choice5 -eq 'w') {
        # Detect GitHub repo from git remote so gh CLI knows which repo to target
        Push-Location $dest
        $remoteUrl = git remote get-url origin 2>$null
        Pop-Location
        $repoSlug = $null
        if ($remoteUrl -match '[:/]([^/:]+/[^/]+?)(?:\.git)?$') {
            $repoSlug = $Matches[1]
        }

        Write-Host "Release notes (optional, press Enter to leave blank): " -NoNewline
        $releaseNotes = Read-Host
        Push-Location $dest
        if ($repoSlug) {
            gh release create $newVersion $zipPath --title "MicroLab $newVersion" --notes "$releaseNotes" --repo $repoSlug
        } else {
            Write-Host "Warning: could not detect GitHub repo from remote URL '$remoteUrl'. Trying without --repo flag."
            gh release create $newVersion $zipPath --title "MicroLab $newVersion" --notes "$releaseNotes"
        }
        Pop-Location
    }
}
