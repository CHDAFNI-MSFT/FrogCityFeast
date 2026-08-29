[CmdletBinding()]
param(
    [switch]$IncludeGuiEditors
)

$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent $PSScriptRoot
$manifestPath = Join-Path $repoRoot "tools\toolchain.json"
$manifest = Get-Content -Raw $manifestPath | ConvertFrom-Json

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
        "$actualArchitecture. Do not install architecture-incompatible packages."
    )
}

if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
    throw "WinGet is required. Install App Installer from Microsoft before continuing."
}

function Add-UserPathEntry {
    param(
        [Parameter(Mandatory)]
        [string]$Path
    )

    $normalizedPath = $Path.TrimEnd("\")
    $userPath = [Environment]::GetEnvironmentVariable("Path", "User")
    $entries = @($userPath -split ";" | Where-Object { $_ })
    $normalizedEntries = @(
        $entries | ForEach-Object { $_.TrimEnd("\") }
    )
    if ($normalizedEntries -notcontains $normalizedPath) {
        $updatedPath = (@($normalizedPath) + @($entries)) -join ";"
        [Environment]::SetEnvironmentVariable("Path", $updatedPath, "User")
        Write-Host "Added $normalizedPath to the user PATH."
    }
}

function Get-PortableExecutablePath {
    param(
        [Parameter(Mandatory)]
        [pscustomobject]$Package
    )

    if ($Package.PSObject.Properties.Name -notcontains "portableWindows") {
        return $null
    }

    $installDirectory = Join-Path `
        $repoRoot `
        ($Package.portableWindows.installDirectory -replace "/", "\")
    return Join-Path `
        $installDirectory `
        ($Package.portableWindows.relativeExecutable -replace "/", "\")
}

function Test-PortablePackage {
    param(
        [Parameter(Mandatory)]
        [pscustomobject]$Package
    )

    $executable = Get-PortableExecutablePath -Package $Package
    if (-not $executable -or -not (Test-Path -LiteralPath $executable -PathType Leaf)) {
        return $false
    }

    $expectedVersion = [string]$Package.portableWindows.commandVersion
    $actualVersion = (Get-Item -LiteralPath $executable).VersionInfo.ProductVersion
    if ($actualVersion -notmatch "^$([regex]::Escape($expectedVersion))(?:\s|$)") {
        throw (
            "$($Package.name) portable executable is version '$actualVersion'; " +
            "expected $expectedVersion."
        )
    }

    Add-UserPathEntry -Path (Split-Path -Parent $executable)
    Write-Host (
        "$($Package.name) $expectedVersion portable is already available at " +
        "$executable."
    )
    return $true
}

function Install-PortablePackage {
    param(
        [Parameter(Mandatory)]
        [pscustomobject]$Package
    )

    $portable = $Package.portableWindows
    $downloadsDirectory = Join-Path $repoRoot ".tools\downloads"
    $archivePath = Join-Path $downloadsDirectory $portable.asset
    $partialPath = "$archivePath.partial"
    $installDirectory = Join-Path `
        $repoRoot `
        ($portable.installDirectory -replace "/", "\")
    $executable = Get-PortableExecutablePath -Package $Package

    New-Item -ItemType Directory -Force -Path $downloadsDirectory | Out-Null

    if (Test-Path -LiteralPath $archivePath -PathType Leaf) {
        $actualHash = (Get-FileHash $archivePath -Algorithm SHA256).Hash.ToLowerInvariant()
        if ($actualHash -ne $portable.sha256) {
            Remove-Item -LiteralPath $archivePath -Force
        }
    }

    if (-not (Test-Path -LiteralPath $archivePath -PathType Leaf)) {
        Remove-Item -LiteralPath $partialPath -Force -ErrorAction SilentlyContinue
        Write-Host "Downloading official $($Package.name) portable archive..."
        Invoke-WebRequest `
            -UseBasicParsing `
            -Uri $portable.url `
            -OutFile $partialPath

        $actualHash = (Get-FileHash $partialPath -Algorithm SHA256).Hash.ToLowerInvariant()
        if ($actualHash -ne $portable.sha256) {
            Remove-Item -LiteralPath $partialPath -Force
            throw "Checksum verification failed for $($portable.url)."
        }
        Move-Item -LiteralPath $partialPath -Destination $archivePath
    }

    if (Test-Path -LiteralPath $installDirectory) {
        throw (
            "Portable install directory exists but is not valid: $installDirectory. " +
            "Inspect it before retrying."
        )
    }

    New-Item -ItemType Directory -Force -Path $installDirectory | Out-Null
    Expand-Archive -LiteralPath $archivePath -DestinationPath $installDirectory

    if (-not (Test-Path -LiteralPath $executable -PathType Leaf)) {
        throw "Portable installation did not create the expected executable: $executable"
    }

    $actualVersion = (Get-Item -LiteralPath $executable).VersionInfo.ProductVersion
    $expectedVersion = [string]$portable.commandVersion
    if ($actualVersion -notmatch "^$([regex]::Escape($expectedVersion))(?:\s|$)") {
        throw (
            "$($Package.name) portable executable is version '$actualVersion'; " +
            "expected $expectedVersion."
        )
    }

    Add-UserPathEntry -Path (Split-Path -Parent $executable)
    Write-Host "Installed $($Package.name) $expectedVersion portable."
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

function Find-GodotConsoleExecutable {
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
            "$($candidates.Count)."
        )
    }

    return $candidates[0].FullName
}

function Assert-PinnedGodotCommand {
    $command = Get-Command "godot" -ErrorAction SilentlyContinue
    if (-not $command) {
        throw "The user-local Godot command shim was not created successfully."
    }

    $expectedVersion = [string]$manifest.godot.version
    if ([IO.Path]::GetExtension($command.Source) -ieq ".exe") {
        $actualVersion = (Get-Item -LiteralPath $command.Source).VersionInfo.ProductVersion
    } else {
        $actualVersion = (& $command.Source --version 2>&1 | Select-Object -First 1) -join ""
    }

    if ($actualVersion -notmatch "^$([regex]::Escape($expectedVersion))\.stable(?:\.|\s|$)") {
        throw (
            "The godot command resolves to '$($command.Source)' with version " +
            "'$actualVersion'; expected $expectedVersion. Remove or reorder the " +
            "conflicting command before using this project."
        )
    }

    Write-Host "Godot command resolves to pinned version $expectedVersion."
}

function Install-GodotCommandShims {
    $consoleExecutable = Find-GodotConsoleExecutable
    $userBin = Join-Path $HOME ".local\bin"
    $consoleShim = Join-Path $userBin "godot-console.cmd"

    if (-not $consoleExecutable.StartsWith(
        $env:LOCALAPPDATA,
        [StringComparison]::OrdinalIgnoreCase
    )) {
        throw "The Godot console executable is outside LOCALAPPDATA: $consoleExecutable"
    }
    $relativeConsolePath = $consoleExecutable.Substring(
        $env:LOCALAPPDATA.Length
    ).TrimStart("\")

    New-Item -ItemType Directory -Force -Path $userBin | Out-Null
    $shimContent = (
        "@echo off`r`n`"%LOCALAPPDATA%\$relativeConsolePath`" %*`r`n"
    )
    Set-Content -LiteralPath $consoleShim -Value $shimContent -Encoding Ascii -NoNewline
    Add-UserPathEntry -Path $userBin

    $env:Path = @(
        [Environment]::GetEnvironmentVariable("Path", "Machine")
        [Environment]::GetEnvironmentVariable("Path", "User")
    ) -join ";"

    if (-not (Get-Command godot -ErrorAction SilentlyContinue)) {
        $godotShim = Join-Path $userBin "godot.cmd"
        Set-Content `
            -LiteralPath $godotShim `
            -Value $shimContent `
            -Encoding Ascii `
            -NoNewline
        Write-Host "Created user-local Godot command shim: $godotShim"
    }

    Assert-PinnedGodotCommand
    Write-Host "Created user-local Godot console shim: $consoleShim"
}

foreach ($package in $manifest.windowsPackages.core) {
    Install-ToolPackage -Package $package
}

if ($IncludeGuiEditors) {
    foreach ($package in $manifest.windowsPackages.guiEditors) {
        if (Test-PortablePackage -Package $package) {
            continue
        }

        try {
            Install-ToolPackage -Package $package
        } catch {
            if ($package.PSObject.Properties.Name -notcontains "portableWindows") {
                throw
            }
            Write-Warning (
                "WinGet installation failed for $($package.name); " +
                "using the pinned official portable archive. $($_.Exception.Message)"
            )
            Install-PortablePackage -Package $package
        }
    }
}

$env:Path = @(
    [Environment]::GetEnvironmentVariable("Path", "Machine")
    [Environment]::GetEnvironmentVariable("Path", "User")
) -join ";"

Install-GodotCommandShims

& git lfs install
if ($LASTEXITCODE -ne 0) {
    throw "Git LFS initialization failed with exit code $LASTEXITCODE."
}

Write-Host ""
Write-Host "Tool installation complete."
Write-Host "Open a new terminal, then run scripts\verify-windows.ps1."
