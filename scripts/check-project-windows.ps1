[CmdletBinding()]
param()

$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent $PSScriptRoot
$manifestPath = Join-Path $repoRoot "tools\toolchain.json"
$manifest = Get-Content -Raw $manifestPath | ConvertFrom-Json
$logsDirectory = Join-Path $repoRoot "build\logs"

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

function Invoke-GodotCheck {
    param(
        [Parameter(Mandatory)]
        [string]$Label,

        [Parameter(Mandatory)]
        [string]$Arguments
    )

    $stdoutPath = Join-Path $logsDirectory "godot-$Label.stdout.log"
    $stderrPath = Join-Path $logsDirectory "godot-$Label.stderr.log"
    $process = Start-Process `
        -FilePath $script:godotConsole `
        -ArgumentList $Arguments `
        -WorkingDirectory $repoRoot `
        -Wait `
        -PassThru `
        -NoNewWindow `
        -RedirectStandardOutput $stdoutPath `
        -RedirectStandardError $stderrPath

    $output = @(
        Get-Content -LiteralPath $stdoutPath -ErrorAction SilentlyContinue
        Get-Content -LiteralPath $stderrPath -ErrorAction SilentlyContinue
    )
    $output | ForEach-Object { Write-Host $_ }

    if ($process.ExitCode -ne 0) {
        throw "Godot exited with code $($process.ExitCode) during $Label."
    }

    $errorPattern = "SCRIPT ERROR:|Parse Error:|Failed to load script"
    if ($output -match $errorPattern) {
        throw "Godot reported project errors during $Label."
    }
}

$env:Path = @(
    [Environment]::GetEnvironmentVariable("Path", "Machine")
    [Environment]::GetEnvironmentVariable("Path", "User")
) -join ";"

$godotConsole = Find-GodotConsoleExecutable
New-Item -ItemType Directory -Force -Path $logsDirectory | Out-Null

Invoke-GodotCheck `
    -Label "import" `
    -Arguments "--headless --path `"$repoRoot`" --import"
Invoke-GodotCheck `
    -Label "startup" `
    -Arguments "--headless --path `"$repoRoot`" --quit-after 2"

Write-Host "Godot project checks passed."
