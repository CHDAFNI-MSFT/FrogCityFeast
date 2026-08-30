[CmdletBinding()]
param()

$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent $PSScriptRoot
$manifestPath = Join-Path $repoRoot "tools\toolchain.json"
$manifest = Get-Content -Raw $manifestPath | ConvertFrom-Json

function Find-GodotConsoleExecutable {
    $command = Get-Command "godot-console" -ErrorAction SilentlyContinue
    if ($command) {
        return $command.Source
    }

    $version = [string]$manifest.godot.version
    $packagesRoot = Join-Path $env:LOCALAPPDATA "Microsoft\WinGet\Packages"
    $expectedPattern = "Godot_v$version-stable_*_console.exe"
    $candidates = @(
        Get-ChildItem `
            -Path $packagesRoot `
            -Filter $expectedPattern `
            -File `
            -Recurse `
            -ErrorAction SilentlyContinue
    )

    if ($candidates.Count -ne 1) {
        throw (
            "Expected one $expectedPattern under $packagesRoot; found " +
            "$($candidates.Count). Run scripts\setup-windows.ps1 first."
        )
    }

    return $candidates[0].FullName
}

$env:Path = @(
    [Environment]::GetEnvironmentVariable("Path", "Machine")
    [Environment]::GetEnvironmentVariable("Path", "User")
) -join ";"

$godotConsole = Find-GodotConsoleExecutable
$output = @(
    & $godotConsole `
        "--path" $repoRoot `
        "--resolution" "1280x960" `
        "--script" "res://tests/performance_smoke.gd" `
        "--" "--measure" 2>&1
)
$exitCode = $LASTEXITCODE
$output | ForEach-Object { Write-Host $_ }

if ($exitCode -ne 0) {
    throw "Godot performance measurement exited with code $exitCode."
}

$errorPattern = "SCRIPT ERROR:|Parse Error:|Failed to load script"
if ($output -match $errorPattern) {
    throw "Godot reported project errors during performance measurement."
}

Write-Host (
    "Local rendered measurements completed. " +
    "Use an A16 iPad release build for target acceptance."
)
