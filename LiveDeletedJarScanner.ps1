# ===== Improved LiveDeletedJarScanner.ps1 =====

# Discord Webhook
$Webhook = "https://discord.com/api/webhooks/1446644357904994315/cXurGC-8skL34cqX5VRbFjx1Sgu7IfXVjY5wRGnbvV31j-6Nwb6mI0nmzuvAqAbVWDtZ"

# Table to keep track of deleted files
$DeletedFiles = @()

# Colors
$green = "Green"
$red = "Red"
$cyan = "Cyan"
$yellow = "Yellow"

# Header
Write-Host "`n=== Live Deleted JAR Scanner ===`n" -ForegroundColor $cyan
Write-Host "Monitoring all drives..." -ForegroundColor $green
Write-Host "Discord Webhook: $Webhook`n" -ForegroundColor $yellow

# --------------------------
# Function: Send Discord Webhook
# --------------------------
function Send-DiscordAlert {
    param([string]$FileName, [string]$Path)

    if (-not $Webhook) { return }

    $json = @{
        username = "JAR Scanner"
        embeds = @(
            @{
                title = "Deleted JAR Detected"
                description = "**File:** $FileName`n**Path:** $Path"
                color = 16711680
                timestamp = (Get-Date).ToString("o")
            }
        )
    } | ConvertTo-Json -Depth 5

    try {
        Invoke-RestMethod -Uri $Webhook -Method POST -ContentType 'application/json' -Body $json
    } catch {
        Write-Warning "Failed to send webhook."
    }
}

# --------------------------
# Function: Start Watcher
# --------------------------
function Start-Watcher {
    param([string]$folder)

    Write-Host "Watching drive $folder ..." -ForegroundColor $cyan

    $watcher = New-Object System.IO.FileSystemWatcher
    $watcher.Path = $folder
    $watcher.Filter = "*.jar"
    $watcher.IncludeSubdirectories = $true
    $watcher.EnableRaisingEvents = $true

    Register-ObjectEvent $watcher Deleted -SourceIdentifier "JarDeleted_$folder" -Action {
        $file = $Event.SourceEventArgs.Name
        $path = $Event.SourceEventArgs.FullPath
        $time = Get-Date -Format "yyyy-MM-dd HH:mm:ss"

        # Add to deleted files array
        $DeletedFiles += [PSCustomObject]@{
            Time = $time
            FileName = $file
            Path = $path
        }

        # Clean output
        Write-Host "[DELETED] $file at $path ($time)" -ForegroundColor $red

        # Send Discord alert
        Send-DiscordAlert -FileName $file -Path $path
    }
}

# --------------------------
# Monitor all filesystem drives
# --------------------------
$drives = Get-PSDrive | Where-Object { $_.Provider.Name -eq "FileSystem" }

foreach ($drive in $drives) {
    if (Test-Path $drive.Root) {
        Start-Watcher -folder $drive.Root
    }
}

# --------------------------
# Keep script running
# --------------------------
Write-Host "`nLive scanner is running... Press CTRL + C to stop.`n" -ForegroundColor $green

while ($true) {
    Start-Sleep -Seconds 1
}
