# ============================================================================
# 🔧 AUTO-RECOVERY SCRIPT — run on startup to fix common issues
# ============================================================================
$logFile = "$env:USERPROFILE\maintenance.log"
$ts = Get-Date -Format "yyyy-MM-dd HH:mm:ss"

function Log($m) { "$ts $m" | Out-File $logFile -Encoding UTF8 -Append; Write-Host $m -ForegroundColor Cyan }

Log "=== Auto-Recovery Run ==="

# 1. Check Docker
$dockerOk = docker version --format "{{.Server.Version}}" 2>$null
if (-not $dockerOk) {
    Log "Docker daemon not responding. Restarting..."
    Get-Process -Name "*docker*" -ErrorAction SilentlyContinue | Stop-Process -Force 2>$null
    Start-Sleep -Seconds 3
    Start-Process "C:\Program Files\Docker\Docker\Docker Desktop.exe" 2>$null
    Log "Docker Desktop launched"
} else {
    Log "Docker OK (v$dockerOk)"
}

# 2. Check containers
if ($dockerOk) {
    $containers = docker ps --filter "status=exited" --format "{{.Names}}" 2>$null
    foreach ($c in $containers) {
        docker start $c 2>$null
        Log "Restarted container: $c"
    }
    
    # Check WSL integration
    $wslOk = wsl -l -v 2>$null | Select-String "Running"
    if (-not $wslOk) {
        Log "WSL not running. Starting..."
        wsl -d Ubuntu-24.04 -e echo "WSL started" 2>$null
    } else {
        Log "WSL OK"
    }
}

# 3. Disk space check
$disk = Get-PSDrive C
$freeGB = [math]::Round($disk.Free / 1GB, 1)
if ($freeGB -lt 100) {
    Log "WARNING: Only ${freeGB}GB free on C:"
} else {
    Log "Disk OK: ${freeGB}GB free"
}

# 4. npm cache check
if (Test-Path "$env:LOCALAPPDATA\npm-cache\_cacache") {
    $cacheSize = (Get-ChildItem "$env:LOCALAPPDATA\npm-cache\_cacache" -Recurse -ErrorAction SilentlyContinue | Measure-Object Length -Sum).Sum
    $cacheGB = [math]::Round($cacheSize / 1GB, 2)
    if ($cacheGB -gt 5) {
        Log "npm cache large (${cacheGB}GB). Cleaning..."
        npm cache clean --force 2>$null
    }
}

Log "=== Auto-Recovery Complete ==="
