[CmdletBinding()]
param(
    [switch]$RequireGuiEditors
)

$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent $PSScriptRoot
$manifestPath = Join-Path $repoRoot "tools\toolchain.json"
$manifest = Get-Content -Raw $manifestPath | ConvertFrom-Json
$failures = [System.Collections.Generic.List[string]]::new()

$env:Path = @(
    [Environment]::GetEnvironmentVariable("Path", "Machine")
    [Environment]::GetEnvironmentVariable("Path", "User")
) -join ";"

function Test-CommandVersion {
    param(
        [Parameter(Mandatory)]
        [string]$Name,

        [Parameter(Mandatory)]
        [string[]]$Arguments,

        [Parameter(Mandatory)]
        [string]$ExpectedPattern
    )

    $command = Get-Command $Name -ErrorAction SilentlyContinue
    if (-not $command) {
        $script:failures.Add("$Name is not available on PATH.")
        return
    }

    $output = (& $command.Source @Arguments 2>&1 | Select-Object -First 1) -join ""
    if ($output -notmatch $ExpectedPattern) {
        $script:failures.Add(
            "$Name returned '$output'; expected a version matching '$ExpectedPattern'."
        )
        return
    }

    Write-Host "[ok] $output"
}

function Test-WingetPackage {
    param(
        [Parameter(Mandatory)]
        [pscustomobject]$Package
    )

    $output = (& winget list `
        --id $Package.id `
        --exact `
        --accept-source-agreements 2>&1) -join "`n"

    $packageLine = $output -split "`n" |
        Where-Object { $_ -match "\s$([regex]::Escape($Package.id))\s" } |
        Select-Object -First 1

    if ($LASTEXITCODE -ne 0 -or -not $packageLine) {
        $script:failures.Add(
            "$($Package.name) $($Package.version) is not registered with WinGet."
        )
        return
    }

    $versionMatch = [regex]::Match(
        $packageLine,
        "\s$([regex]::Escape($Package.id))\s+(?<version>\S+)"
    )
    $installedVersion = if ($versionMatch.Success) {
        $versionMatch.Groups["version"].Value
    } else {
        "unknown"
    }

    if ($installedVersion -ne $Package.version) {
        $script:failures.Add(
            "$($Package.name) is version $installedVersion; expected $($Package.version)."
        )
        return
    }

    Write-Host "[ok] $($Package.name) $($Package.version)"
}

$godotVersion = [regex]::Escape($manifest.godot.version)
$gitLfsPackage = $manifest.windowsPackages.core |
    Where-Object { $_.id -eq "GitHub.GitLFS" }
$imageMagickPackage = $manifest.windowsPackages.core |
    Where-Object { $_.id -eq "ImageMagick.ImageMagick" }
$ffmpegPackage = $manifest.windowsPackages.core |
    Where-Object { $_.id -eq "Gyan.FFmpeg" }

Test-CommandVersion `
    -Name "godot" `
    -Arguments @("--version") `
    -ExpectedPattern "^$godotVersion\.stable\."

Test-CommandVersion `
    -Name "git-lfs" `
    -Arguments @("version") `
    -ExpectedPattern (
        "^git-lfs/$([regex]::Escape($gitLfsPackage.commandVersion))(?:\s|$)"
    )

Test-CommandVersion `
    -Name "magick" `
    -Arguments @("-version") `
    -ExpectedPattern (
        "\b$([regex]::Escape($imageMagickPackage.commandVersion))(?:\s|$)"
    )

Test-CommandVersion `
    -Name "ffmpeg" `
    -Arguments @("-version") `
    -ExpectedPattern (
        "^ffmpeg version $([regex]::Escape($ffmpegPackage.commandVersion))(?:[-\s]|$)"
    )

if ($RequireGuiEditors) {
    if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
        $failures.Add("WinGet is required to verify the graphical editors.")
    } else {
        foreach ($package in $manifest.windowsPackages.guiEditors) {
            Test-WingetPackage -Package $package
        }
    }
}

if ($failures.Count -gt 0) {
    foreach ($failure in $failures) {
        Write-Error $failure
    }
    exit 1
}

Write-Host "Toolchain verification passed."
