[CmdletBinding()]
param()

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$sampleRate = 22050
$outputDirectory = Join-Path (Split-Path -Parent $PSScriptRoot) "assets\audio"
New-Item -ItemType Directory -Force -Path $outputDirectory | Out-Null

function New-SampleBuffer {
    param(
        [Parameter(Mandatory)]
        [double]$Duration
    )

    return ,([double[]]::new(
        [Math]::Round($Duration * $script:sampleRate)
    ))
}

function Add-Chirp {
    param(
        [Parameter(Mandatory)]
        [double[]]$Samples,
        [Parameter(Mandatory)]
        [double]$Start,
        [Parameter(Mandatory)]
        [double]$Duration,
        [Parameter(Mandatory)]
        [double]$StartFrequency,
        [Parameter(Mandatory)]
        [double]$EndFrequency,
        [Parameter(Mandatory)]
        [double]$Amplitude,
        [double]$Attack = 0.01,
        [double]$Release = 0.08,
        [ValidateSet("sine", "triangle", "square")]
        [string]$Waveform = "sine"
    )

    $startIndex = [Math]::Round($Start * $script:sampleRate)
    $sampleCount = [Math]::Round($Duration * $script:sampleRate)
    $phase = 0.0
    for ($offset = 0; $offset -lt $sampleCount; $offset++) {
        $index = $startIndex + $offset
        if ($index -ge $Samples.Length) {
            break
        }

        $time = $offset / $script:sampleRate
        $progress = $time / $Duration
        $frequency = $StartFrequency + (
            ($EndFrequency - $StartFrequency) * $progress
        )
        $phase += 2.0 * [Math]::PI * $frequency / $script:sampleRate
        $wave = switch ($Waveform) {
            "triangle" {
                (2.0 / [Math]::PI) * [Math]::Asin([Math]::Sin($phase))
            }
            "square" {
                if ([Math]::Sin($phase) -ge 0.0) { 1.0 } else { -1.0 }
            }
            default {
                [Math]::Sin($phase)
            }
        }
        $envelope = [Math]::Min(
            1.0,
            [Math]::Min(
                $time / [Math]::Max($Attack, 0.0001),
                ($Duration - $time) / [Math]::Max($Release, 0.0001)
            )
        )
        $Samples[$index] += $wave * $Amplitude * [Math]::Max(0.0, $envelope)
    }
}

function Add-Noise {
    param(
        [Parameter(Mandatory)]
        [double[]]$Samples,
        [Parameter(Mandatory)]
        [double]$Start,
        [Parameter(Mandatory)]
        [double]$Duration,
        [Parameter(Mandatory)]
        [double]$Amplitude,
        [Parameter(Mandatory)]
        [uint32]$Seed,
        [double]$Release = 0.08
    )

    $startIndex = [Math]::Round($Start * $script:sampleRate)
    $sampleCount = [Math]::Round($Duration * $script:sampleRate)
    $state = [uint64]$Seed
    $smoothed = 0.0
    for ($offset = 0; $offset -lt $sampleCount; $offset++) {
        $index = $startIndex + $offset
        if ($index -ge $Samples.Length) {
            break
        }

        $state = (($state * 1664525) + 1013904223) -band 0xffffffffL
        $raw = ([double]$state / 2147483647.5) - 1.0
        $smoothed = ($smoothed * 0.72) + ($raw * 0.28)
        $time = $offset / $script:sampleRate
        $envelope = [Math]::Min(
            1.0,
            ($Duration - $time) / [Math]::Max($Release, 0.0001)
        )
        $Samples[$index] += (
            $smoothed * $Amplitude * [Math]::Max(0.0, $envelope)
        )
    }
}

function Add-PadTone {
    param(
        [Parameter(Mandatory)]
        [double[]]$Samples,
        [Parameter(Mandatory)]
        [double]$Frequency,
        [Parameter(Mandatory)]
        [double]$Amplitude,
        [double]$PhaseOffset = 0.0
    )

    $duration = $Samples.Length / $script:sampleRate
    $loopFrequency = [Math]::Round($Frequency * $duration) / $duration
    for ($index = 0; $index -lt $Samples.Length; $index++) {
        $time = $index / $script:sampleRate
        $Samples[$index] += (
            [Math]::Sin(
                2.0 * [Math]::PI * $loopFrequency * $time + $PhaseOffset
            ) * $Amplitude
        )
    }
}

function Write-MonoWav {
    param(
        [Parameter(Mandatory)]
        [string]$Name,
        [Parameter(Mandatory)]
        [double[]]$Samples
    )

    $peak = 0.0
    foreach ($sample in $Samples) {
        $peak = [Math]::Max($peak, [Math]::Abs($sample))
    }
    $normalization = if ($peak -gt 0.88) { 0.88 / $peak } else { 1.0 }
    $path = Join-Path $script:outputDirectory $Name
    $stream = [IO.File]::Open(
        $path,
        [IO.FileMode]::Create,
        [IO.FileAccess]::Write,
        [IO.FileShare]::None
    )
    try {
        $writer = [IO.BinaryWriter]::new($stream)
        $dataSize = $Samples.Length * 2
        $writer.Write([Text.Encoding]::ASCII.GetBytes("RIFF"))
        $writer.Write([int](36 + $dataSize))
        $writer.Write([Text.Encoding]::ASCII.GetBytes("WAVE"))
        $writer.Write([Text.Encoding]::ASCII.GetBytes("fmt "))
        $writer.Write([int]16)
        $writer.Write([int16]1)
        $writer.Write([int16]1)
        $writer.Write([int]$script:sampleRate)
        $writer.Write([int]($script:sampleRate * 2))
        $writer.Write([int16]2)
        $writer.Write([int16]16)
        $writer.Write([Text.Encoding]::ASCII.GetBytes("data"))
        $writer.Write([int]$dataSize)
        foreach ($sample in $Samples) {
            $scaled = [Math]::Round(
                [Math]::Max(
                    -1.0,
                    [Math]::Min(1.0, $sample * $normalization)
                ) * 32767.0
            )
            $writer.Write([int16]$scaled)
        }
        $writer.Flush()
    }
    finally {
        $stream.Dispose()
    }
}

function New-Effect {
    param(
        [Parameter(Mandatory)]
        [string]$Name,
        [Parameter(Mandatory)]
        [double]$Duration,
        [Parameter(Mandatory)]
        [array]$Tones,
        [array]$Noises = @()
    )

    $samples = New-SampleBuffer -Duration $Duration
    foreach ($tone in $Tones) {
        Add-Chirp -Samples $samples `
            -Start $tone.Start `
            -Duration $tone.Duration `
            -StartFrequency $tone.StartFrequency `
            -EndFrequency $tone.EndFrequency `
            -Amplitude $tone.Amplitude `
            -Attack $tone.Attack `
            -Release $tone.Release `
            -Waveform $tone.Waveform
    }
    foreach ($noise in $Noises) {
        Add-Noise -Samples $samples `
            -Start $noise.Start `
            -Duration $noise.Duration `
            -Amplitude $noise.Amplitude `
            -Seed $noise.Seed `
            -Release $noise.Release
    }
    Write-MonoWav -Name $Name -Samples $samples
}

$effects = @(
    @{
        Name = "ui_feedback.wav"
        Duration = 0.18
        Tones = @(
            @{
                Start = 0.0; Duration = 0.16
                StartFrequency = 620.0; EndFrequency = 860.0
                Amplitude = 0.34; Attack = 0.005; Release = 0.08
                Waveform = "triangle"
            }
        )
    },
    @{
        Name = "tongue_launch.wav"
        Duration = 0.28
        Tones = @(
            @{
                Start = 0.0; Duration = 0.24
                StartFrequency = 190.0; EndFrequency = 520.0
                Amplitude = 0.42; Attack = 0.004; Release = 0.09
                Waveform = "sine"
            },
            @{
                Start = 0.02; Duration = 0.17
                StartFrequency = 430.0; EndFrequency = 760.0
                Amplitude = 0.16; Attack = 0.004; Release = 0.07
                Waveform = "triangle"
            }
        )
        Noises = @(
            @{
                Start = 0.0; Duration = 0.14; Amplitude = 0.08
                Seed = 101; Release = 0.1
            }
        )
    },
    @{
        Name = "tongue_hit.wav"
        Duration = 0.24
        Tones = @(
            @{
                Start = 0.0; Duration = 0.20
                StartFrequency = 330.0; EndFrequency = 260.0
                Amplitude = 0.46; Attack = 0.002; Release = 0.11
                Waveform = "triangle"
            },
            @{
                Start = 0.015; Duration = 0.13
                StartFrequency = 720.0; EndFrequency = 520.0
                Amplitude = 0.16; Attack = 0.002; Release = 0.08
                Waveform = "sine"
            }
        )
    },
    @{
        Name = "tongue_miss.wav"
        Duration = 0.38
        Tones = @(
            @{
                Start = 0.0; Duration = 0.34
                StartFrequency = 390.0; EndFrequency = 130.0
                Amplitude = 0.28; Attack = 0.008; Release = 0.12
                Waveform = "sine"
            }
        )
        Noises = @(
            @{
                Start = 0.02; Duration = 0.26; Amplitude = 0.11
                Seed = 202; Release = 0.13
            }
        )
    },
    @{
        Name = "struggle_tap.wav"
        Duration = 0.12
        Tones = @(
            @{
                Start = 0.0; Duration = 0.10
                StartFrequency = 185.0; EndFrequency = 245.0
                Amplitude = 0.30; Attack = 0.002; Release = 0.055
                Waveform = "square"
            }
        )
    },
    @{
        Name = "swallow.wav"
        Duration = 0.46
        Tones = @(
            @{
                Start = 0.0; Duration = 0.40
                StartFrequency = 310.0; EndFrequency = 92.0
                Amplitude = 0.50; Attack = 0.004; Release = 0.16
                Waveform = "sine"
            },
            @{
                Start = 0.08; Duration = 0.26
                StartFrequency = 160.0; EndFrequency = 230.0
                Amplitude = 0.22; Attack = 0.01; Release = 0.12
                Waveform = "triangle"
            }
        )
    },
    @{
        Name = "digest.wav"
        Duration = 0.58
        Tones = @(
            @{
                Start = 0.00; Duration = 0.22
                StartFrequency = 262.0; EndFrequency = 262.0
                Amplitude = 0.25; Attack = 0.005; Release = 0.12
                Waveform = "triangle"
            },
            @{
                Start = 0.13; Duration = 0.25
                StartFrequency = 330.0; EndFrequency = 330.0
                Amplitude = 0.27; Attack = 0.005; Release = 0.13
                Waveform = "triangle"
            },
            @{
                Start = 0.28; Duration = 0.27
                StartFrequency = 440.0; EndFrequency = 440.0
                Amplitude = 0.29; Attack = 0.005; Release = 0.16
                Waveform = "triangle"
            }
        )
    },
    @{
        Name = "spit.wav"
        Duration = 0.42
        Tones = @(
            @{
                Start = 0.0; Duration = 0.36
                StartFrequency = 140.0; EndFrequency = 430.0
                Amplitude = 0.38; Attack = 0.004; Release = 0.11
                Waveform = "sine"
            }
        )
        Noises = @(
            @{
                Start = 0.0; Duration = 0.22; Amplitude = 0.09
                Seed = 303; Release = 0.12
            }
        )
    },
    @{
        Name = "growth.wav"
        Duration = 0.88
        Tones = @(
            @{
                Start = 0.00; Duration = 0.35
                StartFrequency = 220.0; EndFrequency = 330.0
                Amplitude = 0.26; Attack = 0.01; Release = 0.18
                Waveform = "sine"
            },
            @{
                Start = 0.20; Duration = 0.40
                StartFrequency = 330.0; EndFrequency = 440.0
                Amplitude = 0.29; Attack = 0.01; Release = 0.20
                Waveform = "sine"
            },
            @{
                Start = 0.43; Duration = 0.42
                StartFrequency = 440.0; EndFrequency = 660.0
                Amplitude = 0.31; Attack = 0.01; Release = 0.22
                Waveform = "triangle"
            }
        )
    },
    @{
        Name = "damage.wav"
        Duration = 0.48
        Tones = @(
            @{
                Start = 0.0; Duration = 0.43
                StartFrequency = 135.0; EndFrequency = 72.0
                Amplitude = 0.52; Attack = 0.002; Release = 0.18
                Waveform = "square"
            }
        )
        Noises = @(
            @{
                Start = 0.0; Duration = 0.25; Amplitude = 0.16
                Seed = 404; Release = 0.15
            }
        )
    },
    @{
        Name = "discovery.wav"
        Duration = 0.78
        Tones = @(
            @{
                Start = 0.00; Duration = 0.31
                StartFrequency = 523.0; EndFrequency = 659.0
                Amplitude = 0.24; Attack = 0.008; Release = 0.17
                Waveform = "triangle"
            },
            @{
                Start = 0.18; Duration = 0.34
                StartFrequency = 659.0; EndFrequency = 784.0
                Amplitude = 0.26; Attack = 0.008; Release = 0.18
                Waveform = "triangle"
            },
            @{
                Start = 0.38; Duration = 0.37
                StartFrequency = 784.0; EndFrequency = 1046.0
                Amplitude = 0.23; Attack = 0.008; Release = 0.20
                Waveform = "sine"
            }
        )
    },
    @{
        Name = "challenge_complete.wav"
        Duration = 0.92
        Tones = @(
            @{
                Start = 0.00; Duration = 0.28
                StartFrequency = 294.0; EndFrequency = 370.0
                Amplitude = 0.23; Attack = 0.006; Release = 0.14
                Waveform = "triangle"
            },
            @{
                Start = 0.17; Duration = 0.30
                StartFrequency = 370.0; EndFrequency = 440.0
                Amplitude = 0.25; Attack = 0.006; Release = 0.15
                Waveform = "triangle"
            },
            @{
                Start = 0.35; Duration = 0.33
                StartFrequency = 440.0; EndFrequency = 587.0
                Amplitude = 0.27; Attack = 0.006; Release = 0.17
                Waveform = "triangle"
            },
            @{
                Start = 0.55; Duration = 0.34
                StartFrequency = 587.0; EndFrequency = 740.0
                Amplitude = 0.25; Attack = 0.006; Release = 0.19
                Waveform = "sine"
            }
        )
    }
)

foreach ($effect in $effects) {
    New-Effect @effect
}

function New-MusicLoop {
    param(
        [Parameter(Mandatory)]
        [string]$Name,
        [Parameter(Mandatory)]
        [array]$Chords,
        [Parameter(Mandatory)]
        [array]$Arpeggio,
        [Parameter(Mandatory)]
        [double]$PulseFrequency
    )

    $duration = 8.0
    $samples = New-SampleBuffer -Duration $duration
    for ($chordIndex = 0; $chordIndex -lt $Chords.Count; $chordIndex++) {
        $chordStart = $chordIndex * 2.0
        foreach ($frequency in $Chords[$chordIndex]) {
            Add-Chirp -Samples $samples `
                -Start $chordStart `
                -Duration 2.0 `
                -StartFrequency $frequency `
                -EndFrequency $frequency `
                -Amplitude 0.055 `
                -Attack 0.18 `
                -Release 0.32 `
                -Waveform "sine"
        }
    }
    for ($step = 0; $step -lt 16; $step++) {
        $frequency = $Arpeggio[$step % $Arpeggio.Count]
        Add-Chirp -Samples $samples `
            -Start ($step * 0.5) `
            -Duration 0.42 `
            -StartFrequency $frequency `
            -EndFrequency ($frequency * 1.006) `
            -Amplitude 0.12 `
            -Attack 0.008 `
            -Release 0.26 `
            -Waveform "triangle"
    }
    for ($pulse = 0; $pulse -lt 4; $pulse++) {
        Add-Chirp -Samples $samples `
            -Start ($pulse * 2.0) `
            -Duration 0.34 `
            -StartFrequency $PulseFrequency `
            -EndFrequency ($PulseFrequency * 0.68) `
            -Amplitude 0.10 `
            -Attack 0.004 `
            -Release 0.23 `
            -Waveform "sine"
    }
    Write-MonoWav -Name $Name -Samples $samples
}

New-MusicLoop `
    -Name "menu_music.wav" `
    -Chords @(
        @(130.81, 164.81, 196.00),
        @(110.00, 130.81, 164.81),
        @(87.31, 110.00, 130.81),
        @(98.00, 123.47, 146.83)
    ) `
    -Arpeggio @(261.63, 329.63, 392.00, 493.88, 392.00, 329.63) `
    -PulseFrequency 98.0

New-MusicLoop `
    -Name "gameplay_music.wav" `
    -Chords @(
        @(110.00, 146.83, 174.61),
        @(98.00, 130.81, 164.81),
        @(87.31, 130.81, 174.61),
        @(98.00, 146.83, 196.00)
    ) `
    -Arpeggio @(220.00, 293.66, 349.23, 440.00, 349.23, 293.66) `
    -PulseFrequency 82.41

function New-AmbienceLoop {
    param(
        [Parameter(Mandatory)]
        [string]$Name,
        [Parameter(Mandatory)]
        [bool]$Night
    )

    $duration = 8.0
    $samples = New-SampleBuffer -Duration $duration
    Add-PadTone -Samples $samples -Frequency 49.0 -Amplitude 0.035
    Add-PadTone `
        -Samples $samples `
        -Frequency $(if ($Night) { 73.5 } else { 65.5 }) `
        -Amplitude 0.022 `
        -PhaseOffset 1.2
    Add-PadTone -Samples $samples -Frequency 0.5 -Amplitude 0.018

    $passes = if ($Night) {
        @(
            @{ Start = 1.1; From = 82.0; To = 115.0; Amplitude = 0.045 },
            @{ Start = 5.2; From = 98.0; To = 70.0; Amplitude = 0.038 }
        )
    }
    else {
        @(
            @{ Start = 0.7; From = 92.0; To = 142.0; Amplitude = 0.052 },
            @{ Start = 3.4; From = 128.0; To = 78.0; Amplitude = 0.048 },
            @{ Start = 6.0; From = 84.0; To = 126.0; Amplitude = 0.044 }
        )
    }
    foreach ($pass in $passes) {
        Add-Chirp -Samples $samples `
            -Start $pass.Start `
            -Duration 1.15 `
            -StartFrequency $pass.From `
            -EndFrequency $pass.To `
            -Amplitude $pass.Amplitude `
            -Attack 0.25 `
            -Release 0.34 `
            -Waveform "sine"
    }

    if ($Night) {
        foreach ($start in @(0.9, 1.15, 3.8, 4.05, 6.45, 6.7)) {
            Add-Chirp -Samples $samples `
                -Start $start `
                -Duration 0.12 `
                -StartFrequency 1680.0 `
                -EndFrequency 1840.0 `
                -Amplitude 0.035 `
                -Attack 0.006 `
                -Release 0.06 `
                -Waveform "triangle"
        }
    }
    else {
        foreach ($start in @(1.8, 4.7)) {
            Add-Chirp -Samples $samples `
                -Start $start `
                -Duration 0.34 `
                -StartFrequency 880.0 `
                -EndFrequency 1210.0 `
                -Amplitude 0.038 `
                -Attack 0.02 `
                -Release 0.16 `
                -Waveform "sine"
        }
    }
    Write-MonoWav -Name $Name -Samples $samples
}

New-AmbienceLoop -Name "city_day.wav" -Night $false
New-AmbienceLoop -Name "city_night.wav" -Night $true

$generatedFiles = Get-ChildItem -LiteralPath $outputDirectory -Filter "*.wav"
$totalBytes = ($generatedFiles | Measure-Object -Property Length -Sum).Sum
Write-Host (
    "Generated {0} original audio files ({1:N1} KiB) in {2}." -f
    $generatedFiles.Count,
    ($totalBytes / 1KB),
    $outputDirectory
)
