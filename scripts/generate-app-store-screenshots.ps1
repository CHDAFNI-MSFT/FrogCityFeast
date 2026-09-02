[CmdletBinding()]
param(
    [string]$OutputDirectory
)

$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent $PSScriptRoot
$manifestPath = Join-Path $repoRoot "tools\app-store-screenshot-manifest.json"
$toolchainPath = Join-Path $repoRoot "tools\toolchain.json"
$manifest = Get-Content -Raw $manifestPath | ConvertFrom-Json
$toolchain = Get-Content -Raw $toolchainPath | ConvertFrom-Json
$outputRoot = if ($OutputDirectory) {
    if ([IO.Path]::IsPathRooted($OutputDirectory)) {
        [IO.Path]::GetFullPath($OutputDirectory)
    } else {
        [IO.Path]::GetFullPath((Join-Path $repoRoot $OutputDirectory))
    }
} else {
    Join-Path $repoRoot "build\app-store\screenshots"
}
$imageDirectory = Join-Path $outputRoot "ipad-13-inch"
$packageManifestPath = Join-Path $outputRoot "release-package.json"
$godotIgnorePath = Join-Path $outputRoot ".gdignore"
$logsDirectory = Join-Path $repoRoot "build\logs"
$stdoutPath = Join-Path $logsDirectory "app-store-screenshots.stdout.log"
$stderrPath = Join-Path $logsDirectory "app-store-screenshots.stderr.log"

function Find-GodotConsoleExecutable {
    $command = Get-Command "godot-console" -ErrorAction SilentlyContinue
    if ($command) {
        return $command.Source
    }

    $version = [string]$toolchain.godot.version
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

function Write-Utf8NoBom {
    param(
        [Parameter(Mandatory)]
        [string]$Path,

        [Parameter(Mandatory)]
        [AllowEmptyString()]
        [string]$Content
    )

    [IO.File]::WriteAllText(
        $Path,
        $Content,
        [Text.UTF8Encoding]::new($false)
    )
}

$env:Path = @(
    [Environment]::GetEnvironmentVariable("Path", "Machine")
    [Environment]::GetEnvironmentVariable("Path", "User")
) -join ";"

$godotConsole = Find-GodotConsoleExecutable
$magick = Get-Command "magick" -ErrorAction SilentlyContinue
if (-not $magick) {
    throw "ImageMagick is required. Run scripts\setup-windows.ps1 first."
}
$git = Get-Command "git" -ErrorAction SilentlyContinue
if (-not $git) {
    throw "Git is required to identify the exact screenshot source commit."
}
$sourceCommit = (
    & $git.Source -C $repoRoot rev-parse --verify HEAD
).Trim()
if ($LASTEXITCODE -ne 0 -or -not $sourceCommit) {
    throw "Could not identify the screenshot source commit."
}
$trackedChanges = @(
    & $git.Source -C $repoRoot status --porcelain --untracked-files=no
)
if ($LASTEXITCODE -ne 0) {
    throw "Could not inspect the screenshot source worktree."
}
if ($trackedChanges.Count -ne 0) {
    throw (
        "Screenshot generation requires a clean tracked worktree so every " +
        "image can be tied to one exact source commit."
    )
}

if (Test-Path -LiteralPath $imageDirectory) {
    Remove-Item -LiteralPath $imageDirectory -Recurse -Force
}
if (Test-Path -LiteralPath $packageManifestPath) {
    Remove-Item -LiteralPath $packageManifestPath -Force
}
New-Item -ItemType Directory -Force -Path $outputRoot | Out-Null
New-Item -ItemType Directory -Force -Path $logsDirectory | Out-Null
Write-Utf8NoBom -Path $godotIgnorePath -Content ""

$godotArguments = (
    '--path "{0}" --resolution 2752x2064 ' +
    '--script res://tools/app_store_screenshot_harness.gd -- ' +
    '--app-store-screenshot-harness --output "{1}"'
) -f @(
    $repoRoot.Replace('"', '\"'),
    $outputRoot.Replace('"', '\"')
)
$process = Start-Process `
    -FilePath $godotConsole `
    -ArgumentList $godotArguments `
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
    throw "Godot screenshot generation exited with code $($process.ExitCode)."
}
$errorPattern = "SCRIPT ERROR:|Parse Error:|Failed to load script|ERROR:"
if ($output -match $errorPattern) {
    throw "Godot reported errors during App Store screenshot generation."
}

$expectedNames = @($manifest.screenshots | ForEach-Object { $_.filename })
$actualNames = @(
    Get-ChildItem -LiteralPath $imageDirectory -Filter "*.png" -File |
        Sort-Object Name |
        ForEach-Object { $_.Name }
)
$nameDifference = @(
    Compare-Object `
        -ReferenceObject $expectedNames `
        -DifferenceObject $actualNames
)
if ($nameDifference.Count -ne 0) {
    throw "Generated PNG names do not match the committed screenshot manifest."
}

$validatedFiles = @()
foreach ($entry in $manifest.screenshots) {
    $path = Join-Path $imageDirectory ([string]$entry.filename)
    $identify = (
        & $magick.Source identify `
            -quiet `
            -format "%w|%h|%[colorspace]|%[type]|%[opaque]|%k" `
            $path
    ) -join ""
    if ($LASTEXITCODE -ne 0) {
        throw "ImageMagick could not inspect $path."
    }
    $parts = $identify -split "\|"
    if ($parts.Count -ne 6) {
        throw "Unexpected ImageMagick result for ${path}: $identify"
    }
    $width = [int]$parts[0]
    $height = [int]$parts[1]
    $colorSpace = [string]$parts[2]
    $imageType = [string]$parts[3]
    $opaque = [string]$parts[4]
    $colors = [long]$parts[5]
    if (
        $width -ne [int]$manifest.target.width -or
        $height -ne [int]$manifest.target.height
    ) {
        throw "$path is ${width}x${height}, not 2752x2064."
    }
    if (
        $colorSpace -notmatch "^(?i:srgb)$" -or
        $imageType -match "(?i)alpha" -or
        $opaque -notmatch "^(?i:true)$"
    ) {
        throw (
            "$path is not an opaque RGB image " +
            "(colorspace=$colorSpace, type=$imageType, opaque=$opaque)."
        )
    }
    if ($colors -lt 64) {
        throw "$path has only $colors colors and appears blank or incomplete."
    }
    $hash = (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash.ToLowerInvariant()
    $validatedFiles += [ordered]@{
        id = [string]$entry.id
        filename = [string]$entry.filename
        width = $width
        height = $height
        colorSpace = $colorSpace
        imageType = $imageType
        opaque = $true
        colors = $colors
        sha256 = $hash
    }
    Write-Host (
        "[ok] {0} {1}x{2} {3} {4} opaque, {5} colors" -f
        $entry.filename,
        $width,
        $height,
        $colorSpace,
        $imageType,
        $colors
    )
}

$releasePackage = [ordered]@{
    schemaVersion = 1
    sourceManifest = "tools/app-store-screenshot-manifest.json"
    sourceCommit = $sourceCommit
    cleanTrackedWorktree = $true
    engine = "Godot $($toolchain.godot.version)"
    renderer = [string]$manifest.engine.renderer
    target = $manifest.target
    files = $validatedFiles
}
Write-Utf8NoBom `
    -Path $packageManifestPath `
    -Content ($releasePackage | ConvertTo-Json -Depth 8)

Write-Host (
    "Validated {0} final App Store screenshots in {1}" -f
    $validatedFiles.Count,
    $imageDirectory
)
Write-Host "Package manifest: $packageManifestPath"
