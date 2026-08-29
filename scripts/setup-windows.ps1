[CmdletBinding()]
param(
    [switch]$IncludeGuiEditors
)

$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent $PSScriptRoot
$manifestPath = Join-Path $repoRoot "tools\toolchain.json"
$manifest = Get-Content -Raw $manifestPath | ConvertFrom-Json

if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
    throw "WinGet is required. Install App Installer from Microsoft before continuing."
}

function Install-ToolPackage {
    param(
        [Parameter(Mandatory)]
        [pscustomobject]$Package
    )

    if ($Package.id -eq "GitHub.GitLFS") {
        $gitLfs = Get-Command git-lfs -ErrorAction SilentlyContinue
        if ($gitLfs) {
            $currentVersion = (& $gitLfs.Source version 2>&1) -join ""
            $expectedVersion = [regex]::Escape($Package.commandVersion)
            if ($currentVersion -match "^git-lfs/$expectedVersion(?:\s|$)") {
                Write-Host "Git LFS $($Package.commandVersion) is already available."
                return
            }
        }
    }

    Write-Host "Installing $($Package.name) $($Package.version)..."
    & winget install `
        --id $Package.id `
        --version $Package.version `
        --exact `
        --source winget `
        --accept-package-agreements `
        --accept-source-agreements `
        --silent `
        --disable-interactivity

    $exitCode = $LASTEXITCODE
    if ($exitCode -notin @(0, -1978335189)) {
        throw "WinGet failed to install $($Package.name) with exit code $exitCode."
    }
}

foreach ($package in $manifest.windowsPackages.core) {
    Install-ToolPackage -Package $package
}

if ($IncludeGuiEditors) {
    foreach ($package in $manifest.windowsPackages.guiEditors) {
        Install-ToolPackage -Package $package
    }
}

$env:Path = @(
    [Environment]::GetEnvironmentVariable("Path", "Machine")
    [Environment]::GetEnvironmentVariable("Path", "User")
) -join ";"

& git lfs install
if ($LASTEXITCODE -ne 0) {
    throw "Git LFS initialization failed with exit code $LASTEXITCODE."
}

Write-Host ""
Write-Host "Tool installation complete."
Write-Host "Open a new terminal, then run scripts\verify-windows.ps1."
