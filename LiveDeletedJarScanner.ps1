# ===== LiveDeletedJarScanner.ps1 =====

# Your Discord Webhook
$Webhook = "https://discord.com/api/webhooks/1446644357904994315/cXurGC-8skL34cqX5VRbFjx1Sgu7IfXVjY5wRGnbvV31j-6Nwb6mI0nmzuvAqAbVWDtZ"

Write-Host "=== Live Deleted JAR Scanner Started ==="
Write-Host "Monitoring all drives..."
Write-Host "Discord Webhook: $Webhook`n"

# ---------------------------------------------------------
# Function: Send Discord Webhook Alert
# ---------------------------------------------------------
function Send-DiscordAlert {
    param(
        [string]$FileName,
        [string]$Path
    )

    if (-not $Webhook) { return }

    $json = @{
        username = "JAR Scanner"
        embeds = @(
            @{
                title = "Deleted JAR File Detected"
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

# ---------------------------------------------------------
# Function: Start FileSystemWatcher
# ---------------------------------------------------------
function Start-Watcher {
    param([string]$folder)

    Write-Host "Watching: $folder"

    $watcher = New-Object System.IO.FileSystemWatcher
    $watcher.Path = $folder
    $watcher.Filter = "*.jar"
    $watcher.IncludeSubdirectories = $true
    $watcher.EnableRaisingEvents = $true

    Register-ObjectEvent $watcher Deleted -SourceIdentifier "JarDeleted_$folder" -Action {
        $file = $Event.SourceEventArgs.Name
        $path = $Event.SourceEventArgs.FullPath

        Write-Host "[DELETED] $path"
        Send-DiscordAlert -FileName $file -Path $path
    }
}

# ---------------------------------------------------------
# Monitor all filesystem drives
# ---------------------------------------------------------
$drives = Get-PSDrive | Where-Object { $_.Provider.Name -eq "FileSystem" }

foreach ($drive in $drives) {
    if (Test-Path $drive.Root) {
        Start-Watcher -folder $drive.Root
    }
}

Write-Host "`nLive scanner is running... Press CTRL + C to stop."

while ($true) { Start-Sleep -Seconds 1 }
