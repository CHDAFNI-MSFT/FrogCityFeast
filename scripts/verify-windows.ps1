[CmdletBinding()]
param(
    [switch]$RequireGuiEditors
)

$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent $PSScriptRoot
$manifestPath = Join-Path $repoRoot "tools\toolchain.json"
$manifest = Get-Content -Raw $manifestPath | ConvertFrom-Json
$failures = [System.Collections.Generic.List[string]]::new()

$nativeArchitecture = if ($env:PROCESSOR_ARCHITEW6432) {
    $env:PROCESSOR_ARCHITEW6432
} else {
    $env:PROCESSOR_ARCHITECTURE
}
$actualArchitecture = switch ($nativeArchitecture.ToUpperInvariant()) {
    "AMD64" { "x64" }
    "ARM64" { "arm64" }
    "X86" { "x86" }
    default { $nativeArchitecture.ToLowerInvariant() }
}
$expectedArchitecture = [string]$manifest.windowsPackages.architecture
if ($actualArchitecture -ne $expectedArchitecture) {
    throw (
        "This toolchain supports Windows $expectedArchitecture; detected " +
        "$actualArchitecture."
    )
}

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

function Test-GodotCommandVersion {
    param(
        [Parameter(Mandatory)]
        [string]$Name,

        [Parameter(Mandatory)]
        [string]$ExpectedPattern
    )

    $command = Get-Command $Name -ErrorAction SilentlyContinue
    if (-not $command) {
        $script:failures.Add("$Name is not available on PATH.")
        return
    }

    if ([IO.Path]::GetExtension($command.Source) -ieq ".exe") {
        $output = (Get-Item -LiteralPath $command.Source).VersionInfo.ProductVersion
    } else {
        $output = (& $command.Source --version 2>&1 | Select-Object -First 1) -join ""
    }

    if ($output -notmatch $ExpectedPattern) {
        $script:failures.Add(
            "$Name at '$($command.Source)' is '$output'; expected a version " +
            "matching '$ExpectedPattern'."
        )
        return
    }

    Write-Host "[ok] $Name $output"
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
        return $false
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
        return $false
    }

    Write-Host "[ok] $($Package.name) $($Package.version)"
    return $true
}

function Test-PortablePackage {
    param(
        [Parameter(Mandatory)]
        [pscustomobject]$Package
    )

    if ($Package.PSObject.Properties.Name -notcontains "portableWindows") {
        return $false
    }

    $portable = $Package.portableWindows
    $executable = Join-Path `
        $repoRoot `
        (($portable.installDirectory + "/" + $portable.relativeExecutable) -replace "/", "\")
    if (-not (Test-Path -LiteralPath $executable -PathType Leaf)) {
        return $false
    }

    $actualVersion = (Get-Item -LiteralPath $executable).VersionInfo.ProductVersion
    $expectedVersion = [string]$portable.commandVersion
    if ($actualVersion -notmatch "^$([regex]::Escape($expectedVersion))(?:\s|$)") {
        return $false
    }

    Write-Host "[ok] $($Package.name) $expectedVersion portable"
    return $true
}

$godotVersion = [regex]::Escape($manifest.godot.version)
$gitLfsPackage = $manifest.windowsPackages.core |
    Where-Object { $_.id -eq "GitHub.GitLFS" }
$imageMagickPackage = $manifest.windowsPackages.core |
    Where-Object { $_.id -eq "ImageMagick.ImageMagick" }
$ffmpegPackage = $manifest.windowsPackages.core |
    Where-Object { $_.id -eq "Gyan.FFmpeg" }

Test-GodotCommandVersion `
    -Name "godot" `
    -ExpectedPattern "^$godotVersion\.stable(?:\.|\s|$)"

Test-GodotCommandVersion `
    -Name "godot-console" `
    -ExpectedPattern "^$godotVersion\.stable(?:\.|\s|$)"

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
            if (
                -not (Test-WingetPackage -Package $package) -and
                -not (Test-PortablePackage -Package $package)
            ) {
                $failures.Add(
                    "$($package.name) $($package.version) is not available " +
                    "through WinGet or its configured portable path."
                )
            }
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
