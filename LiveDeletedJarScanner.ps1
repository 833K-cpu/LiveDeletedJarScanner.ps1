# ===== CompleteDeletedJARScanner.ps1 =====

# --------------------------
# Configuration
# --------------------------
$Webhook = "https://discord.com/api/webhooks/1446644357904994315/cXurGC-8skL34cqX5VRbFjx1Sgu7IfXVjY5wRGnbvV31j-6Nwb6mI0nmzuvAqAbVWDtZ"
$RecoveryFolder = "$env:USERPROFILE\RecoveredJARs"
if (-not (Test-Path $RecoveryFolder)) { New-Item -ItemType Directory -Path $RecoveryFolder | Out-Null }

$Colors = @{
    Cyan   = "Cyan"
    Yellow = "Yellow"
    Green  = "Green"
    Red    = "Red"
}

# --------------------------
# Header
# --------------------------
Write-Host "`n=== Complete Deleted JAR Scanner ===`n" -ForegroundColor $Colors.Cyan
Write-Host "Scanning Recycle Bin and all drives for .jar files..." -ForegroundColor $Colors.Green
Write-Host "Sending results to Discord..." -ForegroundColor $Colors.Yellow

# --------------------------
# Function: Send Discord Alert
# --------------------------
function Send-DiscordAlert {
    param(
        [string]$FileName,
        [string]$OriginalPath,
        [string]$Recoverable
    )

    if (-not $Webhook) { return }

    $payload = @{
        username = "Deleted JAR Scanner"
        embeds   = @(
            @{
                title       = "Deleted JAR Detected"
                description = "**File:** $FileName`n**Original Path:** $OriginalPath`n**Recoverable:** $Recoverable"
                color       = 16711680
                timestamp   = (Get-Date).ToString("o")
            }
        )
    } | ConvertTo-Json -Depth 5

    try {
        Invoke-RestMethod -Uri $Webhook -Method Post -ContentType 'application/json' -Body $payload
    } catch {
        Write-Warning "Failed to send webhook for $FileName at $OriginalPath."
    }
}

# --------------------------
# Function: Restore recoverable .jar files from Recycle Bin (COM)
# --------------------------
function Restore-RecycleBinJARs {
    Write-Host "`nScanning Recycle Bin for recoverable .jar files..." -ForegroundColor $Colors.Cyan
    $shell = New-Object -ComObject Shell.Application
    $recycleBin = $shell.Namespace(0xA)
    $found = $false

    for ($i = 0; $i -lt $recycleBin.Items().Count; $i++) {
        $item = $recycleBin.Items().Item($i)
        $fileName = $item.Name
        $originalPath = $recycleBin.GetDetailsOf($item, 1) # Original location

        if ($fileName -like "*.jar") {
            $found = $true
            $targetPath = Join-Path $RecoveryFolder $fileName
            try {
                # Copy to recovery folder
                Copy-Item $item.Path $targetPath -Force
                Write-Host "[RECOVERED] $fileName -> $targetPath" -ForegroundColor $Colors.Green
                Send-DiscordAlert -FileName $fileName -OriginalPath $originalPath -Recoverable "Yes (copied to $RecoveryFolder)"
            } catch {
                Write-Warning "Failed to recover $fileName"
                Send-DiscordAlert -FileName $fileName -OriginalPath $originalPath -Recoverable "Failed"
            }
        }
    }

    if (-not $found) {
        Write-Host "No recoverable .jar files found in Recycle Bin." -ForegroundColor $Colors.Yellow
    }
}

# --------------------------
# Function: Scan $Recycle.Bin folders on all drives (manual restore)
# --------------------------
function Scan-DrivesRecycleBinManual {
    Write-Host "`nScanning $Recycle.Bin folders on all drives for .jar files..." -ForegroundColor $Colors.Cyan
    $drives = Get-PSDrive -PSProvider FileSystem

    foreach ($drive in $drives) {
        $recyclePath = Join-Path $drive.Root '$Recycle.Bin'
        if (Test-Path $recyclePath) {
            try {
                $files = Get-ChildItem -Path $recyclePath -Recurse -Include *.jar -ErrorAction SilentlyContinue
                foreach ($file in $files) {
                    $originalPath = $file.FullName
                    Write-Host "[MANUAL-RECOVER] $($file.Name) at $originalPath" -ForegroundColor $Colors.Red
                    Send-DiscordAlert -FileName $file.Name -OriginalPath $originalPath -Recoverable "Possibly (manual restore needed)"
                    Write-Host "To restore manually, copy:`nCopy-Item '$originalPath' '$RecoveryFolder\'" -ForegroundColor $Colors.Yellow
                }
            } catch {
                Write-Warning "Cannot access $recyclePath"
            }
        }
    }
}

# --------------------------
# Run scans and restores
# --------------------------
Restore-RecycleBinJARs
Scan-DrivesRecycleBinManual

Write-Host "`nDeleted JAR auto-recovery report completed!" -ForegroundColor $Colors.Green
Write-Host "Recovered files (if any) are in: $RecoveryFolder" -ForegroundColor $Colors.Green
