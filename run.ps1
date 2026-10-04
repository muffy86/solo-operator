#!/usr/bin/env pwsh
# ============================================================================
# SOLO OPERATOR MASTER PIPELINE
# One command to: test, lint, build, deploy all projects
# Usage: .\run.ps1 [command]
#   .\run.ps1        - Run everything (default)
#   .\run.ps1 status - Show project health
#   .\run.ps1 watch  - Start file watchers
#   .\run.ps1 deploy - Build & deploy
# ============================================================================

param(
    [ValidateSet('all','status','watch','deploy','test','lint','build','help')]
    [string]$Command = 'all'
)

$PROJECTS = "C:\Users\mufftop\projects"

function Write-Step($msg) { Write-Host "`n[>] $msg" -ForegroundColor Yellow }
function Write-Ok($msg)   { Write-Host "  v $msg" -ForegroundColor Green }
function Write-Fail($msg) { Write-Host "  x $msg" -ForegroundColor Red }

function Test-NodeApp {
    Write-Step "Testing my-node-app..."
    Push-Location (Join-Path $PROJECTS "my-node-app")

    if (-not (Test-Path "node_modules")) {
        npm install 2>&1 | Out-Null
        Write-Ok "npm install"
    }

    npm run lint 2>$null
    if ($LASTEXITCODE -eq 0) { Write-Ok "Lint passed" } else { Write-Fail "Lint failed" }

    $testResult = npm test 2>&1
    if ($LASTEXITCODE -eq 0) { Write-Ok "Tests passed" } else { Write-Fail "Tests failed" }

    Pop-Location
}

function Test-CsvPipeline {
    Write-Step "Testing csv-pipeline..."
    Push-Location (Join-Path $PROJECTS "csv-pipeline")

    python pipeline.py 2>&1 | Out-Null
    if ($LASTEXITCODE -eq 0) { Write-Ok "Pipeline run OK" } else { Write-Fail "Pipeline run failed" }

    Pop-Location
}

function Show-Status {
    Write-Host "`n===========================================" -ForegroundColor Cyan
    Write-Host "     SOLO OPERATOR SYSTEM STATUS" -ForegroundColor Cyan
    Write-Host "===========================================" -ForegroundColor Cyan

    Write-Step "Git Status"
    Push-Location (Join-Path $PROJECTS "my-node-app")
    $branch = git branch --show-current 2>$null
    $status = git status --porcelain 2>$null
    $dirtyCount = if ($status) { ($status -split "`n").Count } else { 0 }
    Write-Ok "my-node-app ($branch): $dirtyCount uncommitted changes"
    Pop-Location

    Push-Location (Join-Path $PROJECTS "csv-pipeline")
    $branch = git branch --show-current 2>$null
    $status = git status --porcelain 2>$null
    $dirtyCount = if ($status) { ($status -split "`n").Count } else { 0 }
    Write-Ok "csv-pipeline ($branch): $dirtyCount uncommitted changes"
    Pop-Location

    Write-Step "Docker Status"
    $containers = docker ps --format "{{.Names}}" 2>$null
    if ($containers) {
        foreach ($c in $containers) { Write-Ok "Container running: $c" }
    } else {
        Write-Ok "No containers running"
    }

    $disk = Get-PSDrive C
    $freeGB = [math]::Round($disk.Free / 1GB, 1)
    Write-Ok "Disk: ${freeGB}GB free on C:"
}

function Start-Watchers {
    Write-Step "Starting project watchers..."

    $csvJob = Start-Job -Name "csv-watcher" -ScriptBlock {
        param($dir)
        Set-Location $dir
        while ($true) {
            python pipeline.py --watch --interval 10
            Start-Sleep -Seconds 5
        }
    } -ArgumentList (Join-Path $PROJECTS "csv-pipeline")
    Write-Ok "CSV watcher started (Job ID: $($csvJob.Id))"

    $nodeJob = Start-Job -Name "node-dev" -ScriptBlock {
        param($dir)
        Set-Location $dir
        npm run dev
    } -ArgumentList (Join-Path $PROJECTS "my-node-app")
    Write-Ok "Node dev server started (Job ID: $($nodeJob.Id))"

    Write-Host "`n  Stop watchers with: Get-Job | Stop-Job" -ForegroundColor Gray
}

switch ($Command) {
    'status'  { Show-Status }
    'watch'   { Start-Watchers }
    'test'    { Test-NodeApp; Test-CsvPipeline }
    'lint'    {
        Write-Step "Running linters..."
        Push-Location (Join-Path $PROJECTS "my-node-app"); npm run lint; Pop-Location
    }
    'build'   {
        Write-Step "Building Docker images..."
        Push-Location (Join-Path $PROJECTS "my-node-app"); docker compose build; Pop-Location
        Push-Location (Join-Path $PROJECTS "csv-pipeline"); docker compose build; Pop-Location
    }
    'deploy'  {
        Write-Step "Deploying all services..."
        Push-Location (Join-Path $PROJECTS "my-node-app"); docker compose up -d; Pop-Location
        Push-Location (Join-Path $PROJECTS "csv-pipeline"); docker compose up -d; Pop-Location
        Write-Ok "Deployment complete. Run 'docker ps' to verify."
    }
    'all'     { Show-Status; Test-NodeApp; Test-CsvPipeline }
    'help'    {
        Write-Host "Usage: .\run.ps1 [command]" -ForegroundColor Yellow
        Write-Host "  status   - Show project health" -ForegroundColor Gray
        Write-Host "  watch    - Start file watchers" -ForegroundColor Gray
        Write-Host "  test     - Run all tests" -ForegroundColor Gray
        Write-Host "  lint     - Run linters" -ForegroundColor Gray
        Write-Host "  build    - Build Docker images" -ForegroundColor Gray
        Write-Host "  deploy   - Deploy containers" -ForegroundColor Gray
        Write-Host "  all      - Status + tests (default)" -ForegroundColor Gray
    }
    default   { Write-Host "Unknown command: $Command. Use 'help'." -ForegroundColor Yellow }
}
